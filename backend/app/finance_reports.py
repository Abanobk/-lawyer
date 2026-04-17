"""تقارير مالية — المرحلة ج: قائمة دخل مبسطة، تدفق نقدي يومي، ملخص قضية."""
from __future__ import annotations

from collections import defaultdict
from datetime import date

from sqlalchemy import Date, cast, func, select
from sqlalchemy.orm import Session

from app.finance_ledger import _utc_bounds, finance_summary
from app.models import (
    Case,
    CaseTransaction,
    CustodyAdvance,
    CustodySpend,
    CustodySpendStatus,
    MoneyDirection,
    OfficeExpense,
    PettyCashTopUp,
)


def build_income_statement(
    db: Session,
    office_id: int,
    from_d: date,
    to_d: date,
    include_custody: bool,
) -> dict:
    s = finance_summary(db, office_id, from_d, to_d, None, include_custody)
    rev = float(s["total_case_income"])
    cexp = float(s["total_case_expense"])
    gross = rev - cexp
    off = float(s["total_office_expense"])
    ptop = float(s["total_petty_top_ups"])
    cadv = float(s["total_custody_advances"]) if include_custody else 0.0
    main_out = off + ptop + (cadv if include_custody else 0.0)
    net = gross - off - ptop - (cadv if include_custody else 0.0)
    return {
        "period_from": from_d,
        "period_to": to_d,
        "revenue_case_income": rev,
        "costs_case_expenses": cexp,
        "gross_margin_cases": gross,
        "expense_office": off,
        "expense_petty_top_ups": ptop,
        "expense_custody_advances": cadv if include_custody else 0.0,
        "total_main_cash_operating_out": main_out,
        "net_after_operating_main_cash": net,
        "includes_custody": include_custody,
        "note_ar": (
            "صافي ما بعد التشغيل يخصم من الخزينة الرئيسية: مصروفات المكتب، تغذية النثرية، "
            + ("وسلف العهد." if include_custody else "دون سلف العهد (صلاحية العهد).")
            + " مصروفات القضايا والنثرية والعهد (معتمد) لا تُعاد خصمها من الخزينة هنا."
        ),
    }


def build_cash_flow_daily(
    db: Session,
    office_id: int,
    from_d: date,
    to_d: date,
) -> list[dict]:
    start, end = _utc_bounds(from_d, to_d)
    inflow: dict[date, float] = defaultdict(float)
    outflow: dict[date, float] = defaultdict(float)

    def ingest_income():
        q = (
            select(cast(CaseTransaction.occurred_at, Date), func.coalesce(func.sum(CaseTransaction.amount), 0))
            .where(
                CaseTransaction.office_id == office_id,
                CaseTransaction.direction == MoneyDirection.income,
                CaseTransaction.occurred_at >= start,
                CaseTransaction.occurred_at <= end,
            )
            .group_by(cast(CaseTransaction.occurred_at, Date))
        )
        for d, amt in db.execute(q).all():
            if d is not None:
                inflow[d] += float(amt or 0)

    def ingest_case_expense():
        q = (
            select(cast(CaseTransaction.occurred_at, Date), func.coalesce(func.sum(CaseTransaction.amount), 0))
            .where(
                CaseTransaction.office_id == office_id,
                CaseTransaction.direction == MoneyDirection.expense,
                CaseTransaction.occurred_at >= start,
                CaseTransaction.occurred_at <= end,
            )
            .group_by(cast(CaseTransaction.occurred_at, Date))
        )
        for d, amt in db.execute(q).all():
            if d is not None:
                outflow[d] += float(amt or 0)

    def ingest_office_expense():
        q = (
            select(cast(OfficeExpense.occurred_at, Date), func.coalesce(func.sum(OfficeExpense.amount), 0))
            .where(
                OfficeExpense.office_id == office_id,
                OfficeExpense.occurred_at >= start,
                OfficeExpense.occurred_at <= end,
            )
            .group_by(cast(OfficeExpense.occurred_at, Date))
        )
        for d, amt in db.execute(q).all():
            if d is not None:
                outflow[d] += float(amt or 0)

    def ingest_custody_advances():
        q = (
            select(cast(CustodyAdvance.occurred_at, Date), func.coalesce(func.sum(CustodyAdvance.amount), 0))
            .where(
                CustodyAdvance.office_id == office_id,
                CustodyAdvance.occurred_at >= start,
                CustodyAdvance.occurred_at <= end,
            )
            .group_by(cast(CustodyAdvance.occurred_at, Date))
        )
        for d, amt in db.execute(q).all():
            if d is not None:
                outflow[d] += float(amt or 0)

    def ingest_petty_topups():
        q = (
            select(cast(PettyCashTopUp.occurred_at, Date), func.coalesce(func.sum(PettyCashTopUp.amount), 0))
            .where(
                PettyCashTopUp.office_id == office_id,
                PettyCashTopUp.occurred_at >= start,
                PettyCashTopUp.occurred_at <= end,
            )
            .group_by(cast(PettyCashTopUp.occurred_at, Date))
        )
        for d, amt in db.execute(q).all():
            if d is not None:
                outflow[d] += float(amt or 0)

    ingest_income()
    ingest_case_expense()
    ingest_office_expense()
    ingest_custody_advances()
    ingest_petty_topups()

    all_days = sorted(set(inflow) | set(outflow))
    return [
        {
            "day": d,
            "inflow": inflow[d],
            "outflow": outflow[d],
            "net": inflow[d] - outflow[d],
        }
        for d in all_days
    ]


def build_case_financial_summary(db: Session, office_id: int, case_id: int) -> dict | None:
    case = db.get(Case, case_id)
    if not case or case.office_id != office_id:
        return None
    inc = db.scalar(
        select(func.coalesce(func.sum(CaseTransaction.amount), 0)).where(
            CaseTransaction.office_id == office_id,
            CaseTransaction.case_id == case_id,
            CaseTransaction.direction == MoneyDirection.income,
        )
    )
    exp = db.scalar(
        select(func.coalesce(func.sum(CaseTransaction.amount), 0)).where(
            CaseTransaction.office_id == office_id,
            CaseTransaction.case_id == case_id,
            CaseTransaction.direction == MoneyDirection.expense,
        )
    )
    inc_f = float(inc or 0)
    exp_f = float(exp or 0)
    fee = float(case.fee_total) if case.fee_total is not None else None
    remaining = None if fee is None else fee - inc_f
    c_app = db.scalar(
        select(func.coalesce(func.sum(CustodySpend.amount), 0)).where(
            CustodySpend.office_id == office_id,
            CustodySpend.case_id == case_id,
            CustodySpend.status == CustodySpendStatus.approved,
        )
    )
    c_pend = db.scalar(
        select(func.coalesce(func.sum(CustodySpend.amount), 0)).where(
            CustodySpend.office_id == office_id,
            CustodySpend.case_id == case_id,
            CustodySpend.status == CustodySpendStatus.pending,
        )
    )
    return {
        "case_id": case.id,
        "case_title": case.title,
        "fee_total": fee,
        "sum_income": inc_f,
        "sum_expense": exp_f,
        "net_cash_case": inc_f - exp_f,
        "remaining_from_fee": remaining,
        "custody_spends_approved": float(c_app or 0),
        "custody_spends_pending": float(c_pend or 0),
    }
