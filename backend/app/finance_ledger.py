"""استعلامات موحّدة للحركات المالية (المرحلة أ — ملخص + دفتر حركة)."""
from __future__ import annotations

from datetime import date, datetime, time, timezone

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import (
    Case,
    CaseTransaction,
    CustodyAccount,
    CustodyAdvance,
    CustodySpend,
    CustodySpendStatus,
    MoneyDirection,
    OfficeExpense,
    PettyCashFund,
    PettyCashSettlement,
    PettyCashSpend,
    PettyCashTopUp,
    User,
)

FINANCE_KINDS_ALL = frozenset(
    {
        "case_income",
        "case_expense",
        "office_expense",
        "custody_advance",
        "custody_spend_approved",
        "custody_spend_pending",
        "petty_top_up",
        "petty_spend",
        "petty_settlement",
    }
)

_KIND_LABELS_AR: dict[str, str] = {
    "case_income": "قضية — إيراد (تحصيل)",
    "case_expense": "قضية — مصروف",
    "office_expense": "مكتب — مصروف تشغيلي",
    "custody_advance": "عهدة — سلفة / تغذية",
    "custody_spend_approved": "عهدة — مصروف معتمد",
    "custody_spend_pending": "عهدة — مصروف قيد المراجعة",
    "petty_top_up": "نثرية — تغذية الصندوق",
    "petty_spend": "نثرية — صرف",
    "petty_settlement": "نثرية — تسوية جرد",
}


def _utc_bounds(from_d: date | None, to_d: date | None) -> tuple[datetime | None, datetime | None]:
    start = datetime.combine(from_d, time.min, tzinfo=timezone.utc) if from_d else None
    end = datetime.combine(to_d, time.max, tzinfo=timezone.utc) if to_d else None
    return start, end


def _case_time_filter(start: datetime | None, end: datetime | None):
    conds = []
    if start is not None:
        conds.append(CaseTransaction.occurred_at >= start)
    if end is not None:
        conds.append(CaseTransaction.occurred_at <= end)
    return conds


def _office_exp_time_filter(start: datetime | None, end: datetime | None):
    conds = []
    if start is not None:
        conds.append(OfficeExpense.occurred_at >= start)
    if end is not None:
        conds.append(OfficeExpense.occurred_at <= end)
    return conds


def _custody_time_filter(col, start: datetime | None, end: datetime | None):
    conds = []
    if start is not None:
        conds.append(col >= start)
    if end is not None:
        conds.append(col <= end)
    return conds


def finance_summary(
    db: Session,
    office_id: int,
    from_d: date | None,
    to_d: date | None,
    case_id: int | None,
    include_custody: bool,
) -> dict:
    start, end = _utc_bounds(from_d, to_d)

    def case_tx_sum(direction: MoneyDirection) -> float:
        q = select(func.coalesce(func.sum(CaseTransaction.amount), 0)).where(CaseTransaction.office_id == office_id)
        q = q.where(CaseTransaction.direction == direction)
        if case_id is not None:
            q = q.where(CaseTransaction.case_id == case_id)
        for c in _case_time_filter(start, end):
            q = q.where(c)
        return float(db.scalar(q) or 0)

    def office_exp_sum() -> float:
        q = select(func.coalesce(func.sum(OfficeExpense.amount), 0)).where(OfficeExpense.office_id == office_id)
        for c in _office_exp_time_filter(start, end):
            q = q.where(c)
        return float(db.scalar(q) or 0)

    total_case_income = case_tx_sum(MoneyDirection.income)
    total_case_expense = case_tx_sum(MoneyDirection.expense)
    total_office_expense = office_exp_sum()

    total_custody_advances = 0.0
    total_custody_spends_approved = 0.0
    total_custody_spends_pending = 0.0
    if include_custody:
        if case_id is None:
            qa = select(func.coalesce(func.sum(CustodyAdvance.amount), 0)).where(CustodyAdvance.office_id == office_id)
            for c in _custody_time_filter(CustodyAdvance.occurred_at, start, end):
                qa = qa.where(c)
            total_custody_advances = float(db.scalar(qa) or 0)
        else:
            total_custody_advances = 0.0

        qs_app = select(func.coalesce(func.sum(CustodySpend.amount), 0)).where(
            CustodySpend.office_id == office_id,
            CustodySpend.status == CustodySpendStatus.approved,
        )
        if case_id is not None:
            qs_app = qs_app.where(CustodySpend.case_id == case_id)
        for c in _custody_time_filter(CustodySpend.occurred_at, start, end):
            qs_app = qs_app.where(c)
        total_custody_spends_approved = float(db.scalar(qs_app) or 0)

        qs_pend = select(func.coalesce(func.sum(CustodySpend.amount), 0)).where(
            CustodySpend.office_id == office_id,
            CustodySpend.status == CustodySpendStatus.pending,
        )
        if case_id is not None:
            qs_pend = qs_pend.where(CustodySpend.case_id == case_id)
        for c in _custody_time_filter(CustodySpend.occurred_at, start, end):
            qs_pend = qs_pend.where(c)
        total_custody_spends_pending = float(db.scalar(qs_pend) or 0)

    total_petty_top_ups = 0.0
    total_petty_spends = 0.0
    total_petty_settlement_net = 0.0
    if case_id is None:
        qpt = select(func.coalesce(func.sum(PettyCashTopUp.amount), 0)).where(PettyCashTopUp.office_id == office_id)
        for c in _custody_time_filter(PettyCashTopUp.occurred_at, start, end):
            qpt = qpt.where(c)
        total_petty_top_ups = float(db.scalar(qpt) or 0)

        qps = select(func.coalesce(func.sum(PettyCashSettlement.adjustment_amount), 0)).where(
            PettyCashSettlement.office_id == office_id
        )
        for c in _custody_time_filter(PettyCashSettlement.occurred_at, start, end):
            qps = qps.where(c)
        total_petty_settlement_net = float(db.scalar(qps) or 0)

    qpsp = select(func.coalesce(func.sum(PettyCashSpend.amount), 0)).where(PettyCashSpend.office_id == office_id)
    if case_id is not None:
        qpsp = qpsp.where(PettyCashSpend.case_id == case_id)
    for c in _custody_time_filter(PettyCashSpend.occurred_at, start, end):
        qpsp = qpsp.where(c)
    total_petty_spends = float(db.scalar(qpsp) or 0)

    net_case = total_case_income - total_case_expense
    net_operating_simple = (
        total_case_income - total_case_expense - total_office_expense - total_petty_top_ups
    )

    return {
        "period_from": from_d,
        "period_to": to_d,
        "case_id_filter": case_id,
        "total_case_income": total_case_income,
        "total_case_expense": total_case_expense,
        "total_office_expense": total_office_expense,
        "total_custody_advances": total_custody_advances,
        "total_custody_spends_approved": total_custody_spends_approved,
        "total_custody_spends_pending": total_custody_spends_pending,
        "total_petty_top_ups": total_petty_top_ups,
        "total_petty_spends": total_petty_spends,
        "total_petty_settlement_net": total_petty_settlement_net,
        "net_case": net_case,
        "net_operating_simple": net_operating_simple,
        "includes_custody": include_custody,
    }


def _load_case_titles(db: Session, office_id: int, ids: set[int]) -> dict[int, str]:
    if not ids:
        return {}
    rows = db.scalars(select(Case).where(Case.office_id == office_id, Case.id.in_(ids))).all()
    return {c.id: c.title for c in rows}


def _load_user_emails(db: Session, ids: set[int]) -> dict[int, str]:
    if not ids:
        return {}
    rows = db.scalars(select(User).where(User.id.in_(ids))).all()
    return {u.id: u.email for u in rows}


def finance_movements(
    db: Session,
    office_id: int,
    from_d: date | None,
    to_d: date | None,
    case_id: int | None,
    include_custody: bool,
    kinds: frozenset[str] | None,
) -> list[dict]:
    start, end = _utc_bounds(from_d, to_d)
    want = kinds if kinds else FINANCE_KINDS_ALL

    rows: list[dict] = []

    if "case_income" in want or "case_expense" in want:
        q = select(CaseTransaction).where(CaseTransaction.office_id == office_id)
        if case_id is not None:
            q = q.where(CaseTransaction.case_id == case_id)
        for c in _case_time_filter(start, end):
            q = q.where(c)
        q = q.order_by(CaseTransaction.occurred_at.desc(), CaseTransaction.id.desc())
        txs = db.scalars(q).all()
        case_ids = {t.case_id for t in txs}
        titles = _load_case_titles(db, office_id, case_ids)
        for t in txs:
            is_income = t.direction == MoneyDirection.income
            kind = "case_income" if is_income else "case_expense"
            if kind not in want:
                continue
            rows.append(
                {
                    "ledger_key": f"ct:{t.id}",
                    "source_type": "case_transaction",
                    "source_id": t.id,
                    "kind": kind,
                    "kind_label_ar": _KIND_LABELS_AR[kind],
                    "occurred_at": t.occurred_at,
                    "amount": float(t.amount),
                    "direction": "income" if is_income else "expense",
                    "affects_office_cash": True,
                    "case_id": t.case_id,
                    "case_title": titles.get(t.case_id),
                    "custody_user_id": None,
                    "custody_user_email": None,
                    "description": t.description,
                }
            )

    if "office_expense" in want:
        q = select(OfficeExpense).where(OfficeExpense.office_id == office_id)
        for c in _office_exp_time_filter(start, end):
            q = q.where(c)
        q = q.order_by(OfficeExpense.occurred_at.desc(), OfficeExpense.id.desc())
        for e in db.scalars(q).all():
            rows.append(
                {
                    "ledger_key": f"oe:{e.id}",
                    "source_type": "office_expense",
                    "source_id": e.id,
                    "kind": "office_expense",
                    "kind_label_ar": _KIND_LABELS_AR["office_expense"],
                    "occurred_at": e.occurred_at,
                    "amount": float(e.amount),
                    "direction": "expense",
                    "affects_office_cash": True,
                    "case_id": None,
                    "case_title": None,
                    "custody_user_id": None,
                    "custody_user_email": None,
                    "description": e.description,
                }
            )

    if include_custody:
        acc_to_user: dict[int, int] = {}
        if any(k in want for k in ("custody_advance", "custody_spend_approved", "custody_spend_pending")):
            accounts = db.scalars(select(CustodyAccount).where(CustodyAccount.office_id == office_id)).all()
            acc_to_user = {a.id: a.user_id for a in accounts}
            user_ids = set(acc_to_user.values())
            emails = _load_user_emails(db, user_ids)
        else:
            emails = {}

        if "custody_advance" in want and case_id is None:
            q = select(CustodyAdvance).where(CustodyAdvance.office_id == office_id)
            for c in _custody_time_filter(CustodyAdvance.occurred_at, start, end):
                q = q.where(c)
            q = q.order_by(CustodyAdvance.occurred_at.desc(), CustodyAdvance.id.desc())
            for a in db.scalars(q).all():
                uid = acc_to_user.get(a.account_id)
                rows.append(
                    {
                        "ledger_key": f"ca:{a.id}",
                        "source_type": "custody_advance",
                        "source_id": a.id,
                        "kind": "custody_advance",
                        "kind_label_ar": _KIND_LABELS_AR["custody_advance"],
                        "occurred_at": a.occurred_at,
                        "amount": float(a.amount),
                        "direction": "expense",
                        "affects_office_cash": True,
                        "case_id": None,
                        "case_title": None,
                        "custody_user_id": uid,
                        "custody_user_email": emails.get(uid) if uid else None,
                        "description": a.notes,
                    }
                )

        for spend_kind, status in (
            ("custody_spend_approved", CustodySpendStatus.approved),
            ("custody_spend_pending", CustodySpendStatus.pending),
        ):
            if spend_kind not in want:
                continue
            q = select(CustodySpend).where(
                CustodySpend.office_id == office_id,
                CustodySpend.status == status,
            )
            if case_id is not None:
                q = q.where(CustodySpend.case_id == case_id)
            for c in _custody_time_filter(CustodySpend.occurred_at, start, end):
                q = q.where(c)
            q = q.order_by(CustodySpend.occurred_at.desc(), CustodySpend.id.desc())
            for s in db.scalars(q).all():
                uid = acc_to_user.get(s.account_id)
                rows.append(
                    {
                        "ledger_key": f"cs:{s.id}",
                        "source_type": "custody_spend",
                        "source_id": s.id,
                        "kind": spend_kind,
                        "kind_label_ar": _KIND_LABELS_AR[spend_kind],
                        "occurred_at": s.occurred_at,
                        "amount": float(s.amount),
                        "direction": "expense",
                        "affects_office_cash": False,
                        "case_id": s.case_id,
                        "case_title": None,
                        "custody_user_id": uid,
                        "custody_user_email": emails.get(uid) if uid else None,
                        "description": s.description,
                    }
                )

    funds = db.scalars(select(PettyCashFund).where(PettyCashFund.office_id == office_id)).all()
    fund_names = {f.id: f.name for f in funds}

    if "petty_top_up" in want and case_id is None:
        q = select(PettyCashTopUp).where(PettyCashTopUp.office_id == office_id)
        for c in _custody_time_filter(PettyCashTopUp.occurred_at, start, end):
            q = q.where(c)
        q = q.order_by(PettyCashTopUp.occurred_at.desc(), PettyCashTopUp.id.desc())
        for t in db.scalars(q).all():
            fname = fund_names.get(t.fund_id, "")
            rows.append(
                {
                    "ledger_key": f"pt:{t.id}",
                    "source_type": "petty_cash_topup",
                    "source_id": t.id,
                    "kind": "petty_top_up",
                    "kind_label_ar": _KIND_LABELS_AR["petty_top_up"],
                    "occurred_at": t.occurred_at,
                    "amount": float(t.amount),
                    "direction": "expense",
                    "affects_office_cash": True,
                    "case_id": None,
                    "case_title": None,
                    "custody_user_id": None,
                    "custody_user_email": None,
                    "description": f"{fname} — {t.notes}" if t.notes else fname,
                }
            )

    if "petty_spend" in want:
        q = select(PettyCashSpend).where(PettyCashSpend.office_id == office_id)
        if case_id is not None:
            q = q.where(PettyCashSpend.case_id == case_id)
        for c in _custody_time_filter(PettyCashSpend.occurred_at, start, end):
            q = q.where(c)
        q = q.order_by(PettyCashSpend.occurred_at.desc(), PettyCashSpend.id.desc())
        for s in db.scalars(q).all():
            fname = fund_names.get(s.fund_id, "")
            desc = s.description or ""
            rows.append(
                {
                    "ledger_key": f"psp:{s.id}",
                    "source_type": "petty_cash_spend",
                    "source_id": s.id,
                    "kind": "petty_spend",
                    "kind_label_ar": _KIND_LABELS_AR["petty_spend"],
                    "occurred_at": s.occurred_at,
                    "amount": float(s.amount),
                    "direction": "expense",
                    "affects_office_cash": False,
                    "case_id": s.case_id,
                    "case_title": None,
                    "custody_user_id": None,
                    "custody_user_email": None,
                    "description": f"{fname} — {desc}".strip(" —") if desc else fname,
                }
            )

    if "petty_settlement" in want and case_id is None:
        q = select(PettyCashSettlement).where(PettyCashSettlement.office_id == office_id)
        for c in _custody_time_filter(PettyCashSettlement.occurred_at, start, end):
            q = q.where(c)
        q = q.order_by(PettyCashSettlement.occurred_at.desc(), PettyCashSettlement.id.desc())
        for st in db.scalars(q).all():
            fname = fund_names.get(st.fund_id, "")
            adj = float(st.adjustment_amount)
            rows.append(
                {
                    "ledger_key": f"pst:{st.id}",
                    "source_type": "petty_cash_settlement",
                    "source_id": st.id,
                    "kind": "petty_settlement",
                    "kind_label_ar": _KIND_LABELS_AR["petty_settlement"],
                    "occurred_at": st.occurred_at,
                    "amount": abs(adj),
                    "direction": "income" if adj > 0 else "expense",
                    "affects_office_cash": False,
                    "case_id": None,
                    "case_title": None,
                    "custody_user_id": None,
                    "custody_user_email": None,
                    "description": f"{fname} — {st.notes}" if st.notes else fname,
                }
            )

    case_ids_spend = {r["case_id"] for r in rows if r.get("case_id")}
    titles_fill = _load_case_titles(db, office_id, case_ids_spend)
    for r in rows:
        cid = r.get("case_id")
        if cid and not r.get("case_title"):
            r["case_title"] = titles_fill.get(cid)

    rows.sort(key=lambda r: (r["occurred_at"], r["ledger_key"]), reverse=True)
    return rows


def movements_to_csv_lines(rows: list[dict]) -> list[str]:
    header = (
        "ledger_key,occurred_at,kind,kind_ar,direction,amount,affects_office_cash,"
        "case_id,case_title,custody_user_email,description,source_type,source_id"
    )
    lines = [header]
    for r in rows:
        def esc(s: str | None) -> str:
            if s is None:
                return ""
            t = str(s).replace('"', '""')
            if "," in t or "\n" in t or '"' in t:
                return f'"{t}"'
            return t

        lines.append(
            ",".join(
                [
                    esc(r["ledger_key"]),
                    esc(r["occurred_at"].isoformat() if r.get("occurred_at") else ""),
                    esc(r["kind"]),
                    esc(r["kind_label_ar"]),
                    esc(r["direction"]),
                    f'{r["amount"]:.2f}',
                    "1" if r.get("affects_office_cash") else "0",
                    str(r["case_id"]) if r.get("case_id") is not None else "",
                    esc(r.get("case_title")),
                    esc(r.get("custody_user_email")),
                    esc(r.get("description")),
                    esc(r.get("source_type")),
                    str(r["source_id"]),
                ]
            )
        )
    return lines
