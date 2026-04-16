import os
import secrets
import string
import time as time_std
from datetime import date, datetime, timedelta, timezone, time as dt_time
from pathlib import Path
from uuid import uuid4

from fastapi import Depends, FastAPI, HTTPException, UploadFile, File, Form, Query, status
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import func, inspect, select, text
from sqlalchemy.orm import Session
from sqlalchemy.exc import OperationalError

from app.db import Base, engine, get_db
from app.models import (
    Case,
    CaseAssignment,
    CaseFile,
    CaseSession,
    CaseTransaction,
    Client,
    CustodyAccount,
    CustodyAdvance,
    CustodyReceiptFile,
    CustodySpend,
    CustodySpendStatus,
    MoneyDirection,
    OfficeExpense,
    OfficeExpenseReceiptFile,
    Office,
    OfficeActivityDaily,
    OfficeStatus,
    Plan,
    PaymentProof,
    ProofStatus,
    Subscription,
    SubscriptionStatus,
    User,
    UserPermission,
    UserRole,
)
from app.schemas import (
    AdminUpdateTrialRequest,
    AdminSuperAdminCreate,
    AdminSuperAdminOut,
    AdminUpdateMyCredentials,
    AdminReviewPaymentProofRequest,
    AdminTrialAnalyticsOut,
    AdminTrialOfficeUsersOut,
    AdminSubscriptionsAnalyticsOut,
    AdminSubscriptionsSeriesOut,
    AdminSubscriptionsSeriesPointOut,
    AdminActivePlanSummaryOut,
    AdminAlertsOut,
    PlanCreate,
    PlanOut,
    PlanUpdate,
    CaseCreate,
    CaseFileOut,
    CaseOut,
    CaseTransactionCreate,
    CaseTransactionOut,
    ClientCreate,
    ClientOut,
    LoginRequest,
    CustodyAccountCreate,
    CustodyAccountOut,
    CustodyAdvanceCreate,
    CustodyReceiptOut,
    CustodyLedgerEntryOut,
    CustodyReviewRequest,
    CustodySpendCreate,
    CustodySpendOut,
    OfficeExpenseCreate,
    OfficeExpenseOut,
    OfficeExpenseReceiptOut,
    ClientAccountReportOut,
    ClientCaseAccountReportItem,
    CustodyReportItem,
    OfficeUserCreate,
    OfficeUserCreateOut,
    PermissionCatalogItem,
    OfficeUserOut,
    OfficeOut,
    SignupRequest,
    SignupResponse,
    SubscriptionOut,
    TokenPair,
    UserOut,
    UserPermissionsOut,
    UserPermissionsUpdate,
    SessionCreate,
    SessionOut,
    SessionUpdate,
    PaymentProofOut,
)
from app.security import create_access_token, create_refresh_token, decode_token, hash_password, verify_password
from app.settings import settings


app = FastAPI(title=settings.app_name)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

PERMISSIONS: dict[str, str] = {
    "dashboard.view": "عرض لوحة التحكم",
    "clients.read": "عرض الموكلين",
    "clients.create": "إضافة موكل",
    "cases.read": "عرض القضايا",
    "cases.create": "إضافة قضية",
    "cases.upload": "رفع مرفقات للقضية",
    "sessions.update": "ترحيل/تعديل مواعيد الجلسات",
    "accounts.read": "عرض الحسابات",
    "employees.read": "عرض الموظفين",
    "employees.manage": "إدارة الموظفين والصلاحيات",
    "custody.me": "عرض عهدي (موظف)",
    "custody.spend.create": "إضافة مصروف من العهدة (موظف)",
    "custody.admin.view": "عرض العهد (أدمن)",
    "custody.admin.advance": "إضافة عهدة/سلفة (أدمن)",
    "custody.admin.approve": "مراجعة/اعتماد المصروفات (أدمن)",
    "settings.view": "عرض الإعدادات",
}

# وحدات القائمة الجانبية للمستأجر (٧ عناصر): لوحة، موكلين، قضايا، جلسات، حسابات، موظفين، إعدادات.
# «الاشتراك» يظهر لمالك المكتب فقط ولا يُحسب ضمن حد الصلاحيات في الباقة.
PLAN_SIDEBAR_MODULE_PERM_KEYS: tuple[str, ...] = (
    "dashboard.view",
    "clients.read",
    "cases.read",
    "sessions.update",
    "accounts.read",
    "employees.read",
    "settings.view",
)


def _tighten_plan_permissions_to_sidebar_modules() -> None:
    """إن كانت الباقة تتضمن كل صلاحيات الكتالوج صراحةً، اضبطها على ال٧ وحدات القائمة."""
    full = frozenset(PERMISSIONS.keys())
    target_csv = ",".join(sorted(PLAN_SIDEBAR_MODULE_PERM_KEYS))
    try:
        with Session(engine) as db:
            changed = False
            for p in db.scalars(select(Plan)).all():
                raw = getattr(p, "allowed_perm_keys_csv", None)
                if not raw:
                    continue
                keys = frozenset(k.strip() for k in raw.split(",") if k.strip() and k.strip() in PERMISSIONS)
                if keys == full:
                    p.allowed_perm_keys_csv = target_csv
                    changed = True
            if changed:
                db.commit()
    except Exception:
        pass


# Track office activity (used by super admin analytics).
TRACKED_ACTIVITY_PREFIXES: tuple[str, ...] = (
    "/me",
    "/office",
    "/clients",
    "/cases",
    "/sessions",
    "/transactions",
    "/custody",
    "/office-expenses",
    "/reports",
)


@app.middleware("http")
async def _track_office_activity(request, call_next):  # type: ignore[no-untyped-def]
    # Only track tenant (office) traffic, not admin endpoints or file downloads.
    path = request.url.path or ""
    if path.startswith("/admin") or path.startswith("/health") or path.startswith("/auth"):
        return await call_next(request)
    if not path.startswith(TRACKED_ACTIVITY_PREFIXES):
        return await call_next(request)

    auth = request.headers.get("authorization") or request.headers.get("Authorization") or ""
    token = ""
    if auth.lower().startswith("bearer "):
        token = auth.split(" ", 1)[1].strip()

    office_id: int | None = None
    role: str | None = None
    if token:
        try:
            payload = decode_token(token)
            if payload.get("type") == "access":
                office_id = int(payload.get("office_id")) if payload.get("office_id") else None
                role = payload.get("role")
        except Exception:
            office_id = None

    if office_id and role in (UserRole.office_owner, UserRole.staff):
        today = _now().date()
        try:
            with Session(engine) as db:
                rec = db.scalar(
                    select(OfficeActivityDaily).where(
                        OfficeActivityDaily.office_id == office_id, OfficeActivityDaily.activity_date == today
                    )
                )
                if rec:
                    rec.hits = int(getattr(rec, "hits", 0) or 0) + 1
                else:
                    db.add(OfficeActivityDaily(office_id=office_id, activity_date=today, hits=1))
                db.commit()
        except Exception:
            # Analytics tracking must never break the request.
            pass

    return await call_next(request)


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _gen_office_code(length: int = 10) -> str:
    alphabet = string.ascii_lowercase + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(length))


def init_db(max_wait_seconds: int = 30) -> None:
    """
    Ensure DB is reachable before trying to create tables.
    On fresh starts, Postgres may not accept connections immediately.
    """
    deadline = time_std.time() + max_wait_seconds
    last_err: Exception | None = None

    while time_std.time() < deadline:
        try:
            Base.metadata.create_all(bind=engine)
            # Lightweight migration for existing DBs (create_all won't add columns).
            with engine.begin() as conn:
                insp = inspect(conn)
                table_names = set(insp.get_table_names())
                cols = {c["name"] for c in insp.get_columns("users")}
                if "full_name" not in cols:
                    conn.execute(text('ALTER TABLE users ADD COLUMN full_name VARCHAR(200)'))
                if "is_active" not in cols:
                    conn.execute(text("ALTER TABLE users ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT TRUE"))
                # Keep is_active indexed for quick auth checks.
                try:
                    conn.execute(text("CREATE INDEX IF NOT EXISTS ix_users_is_active ON users (is_active)"))
                except Exception:
                    pass

                # Plans: per-plan InstaPay link + soft disable
                if "plans" in table_names:
                    plan_cols = {c["name"] for c in insp.get_columns("plans")}
                    if "instapay_link" not in plan_cols:
                        conn.execute(text("ALTER TABLE plans ADD COLUMN instapay_link VARCHAR(800)"))
                    if "promo_image_path" not in plan_cols:
                        conn.execute(text("ALTER TABLE plans ADD COLUMN promo_image_path VARCHAR(500)"))
                    if "package_key" not in plan_cols:
                        conn.execute(text("ALTER TABLE plans ADD COLUMN package_key VARCHAR(80)"))
                    if "package_name" not in plan_cols:
                        conn.execute(text("ALTER TABLE plans ADD COLUMN package_name VARCHAR(200)"))
                    if "max_users" not in plan_cols:
                        conn.execute(text("ALTER TABLE plans ADD COLUMN max_users INTEGER"))
                    if "allowed_perm_keys_csv" not in plan_cols:
                        conn.execute(text("ALTER TABLE plans ADD COLUMN allowed_perm_keys_csv TEXT"))
                    if "is_active" not in plan_cols:
                        conn.execute(text("ALTER TABLE plans ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT TRUE"))
                    try:
                        conn.execute(text("CREATE INDEX IF NOT EXISTS ix_plans_is_active ON plans (is_active)"))
                    except Exception:
                        pass

                # Subscriptions: reference plan_id for module/user cap restrictions.
                if "subscriptions" in table_names:
                    sub_cols = {c["name"] for c in insp.get_columns("subscriptions")}
                    if "plan_id" not in sub_cols:
                        conn.execute(text("ALTER TABLE subscriptions ADD COLUMN plan_id INTEGER"))
                        try:
                            conn.execute(text("CREATE INDEX IF NOT EXISTS ix_subscriptions_plan_id ON subscriptions (plan_id)"))
                        except Exception:
                            pass

                # Payment proofs: link to plan + review fields + snapshots
                if "payment_proofs" in table_names:
                    proof_cols = {c["name"] for c in insp.get_columns("payment_proofs")}
                    if "plan_id" not in proof_cols:
                        conn.execute(text("ALTER TABLE payment_proofs ADD COLUMN plan_id INTEGER"))
                        # Best-effort FK (may fail if plans table missing/permissions).
                        try:
                            conn.execute(
                                text(
                                    "ALTER TABLE payment_proofs "
                                    "ADD CONSTRAINT fk_payment_proofs_plan_id "
                                    "FOREIGN KEY (plan_id) REFERENCES plans (id)"
                                )
                            )
                        except Exception:
                            pass
                        try:
                            conn.execute(text("CREATE INDEX IF NOT EXISTS ix_payment_proofs_plan_id ON payment_proofs (plan_id)"))
                        except Exception:
                            pass
                    if "amount_snapshot_cents" not in proof_cols:
                        conn.execute(text("ALTER TABLE payment_proofs ADD COLUMN amount_snapshot_cents INTEGER"))
                    if "instapay_link_snapshot" not in proof_cols:
                        conn.execute(text("ALTER TABLE payment_proofs ADD COLUMN instapay_link_snapshot VARCHAR(800)"))
                    if "reference_code" not in proof_cols:
                        conn.execute(text("ALTER TABLE payment_proofs ADD COLUMN reference_code VARCHAR(120)"))
                    if "reviewed_by_user_id" not in proof_cols:
                        conn.execute(text("ALTER TABLE payment_proofs ADD COLUMN reviewed_by_user_id INTEGER"))
                        try:
                            conn.execute(
                                text("CREATE INDEX IF NOT EXISTS ix_payment_proofs_reviewed_by_user_id ON payment_proofs (reviewed_by_user_id)")
                            )
                        except Exception:
                            pass
                    if "reviewed_at" not in proof_cols:
                        conn.execute(text("ALTER TABLE payment_proofs ADD COLUMN reviewed_at TIMESTAMPTZ"))
                        try:
                            conn.execute(text("CREATE INDEX IF NOT EXISTS ix_payment_proofs_reviewed_at ON payment_proofs (reviewed_at)"))
                        except Exception:
                            pass
                    if "decision_notes" not in proof_cols:
                        conn.execute(text("ALTER TABLE payment_proofs ADD COLUMN decision_notes TEXT"))
                    # Helpful index for admin queue
                    try:
                        conn.execute(text("CREATE INDEX IF NOT EXISTS idx_payment_proofs_status_uploaded ON payment_proofs (status, uploaded_at)"))
                    except Exception:
                        pass

                # Office activity daily (analytics)
                if "office_activity_daily" in table_names:
                    act_cols = {c["name"] for c in insp.get_columns("office_activity_daily")}
                    if "hits" not in act_cols:
                        try:
                            conn.execute(text("ALTER TABLE office_activity_daily ADD COLUMN hits INTEGER NOT NULL DEFAULT 0"))
                        except Exception:
                            pass
                else:
                    # create_all should create it, but keep best-effort for older DBs
                    pass
            return
        except OperationalError as e:
            last_err = e
            time_std.sleep(1)

    raise RuntimeError("DB not ready after retries") from last_err


def _ensure_upload_dir() -> None:
    Path(settings.upload_dir).mkdir(parents=True, exist_ok=True)


@app.on_event("startup")
def _startup():
    init_db()
    _tighten_plan_permissions_to_sidebar_modules()
    _ensure_upload_dir()
    # Ensure super admin exists
    with Session(engine) as db:
        existing = db.scalar(select(User).where(User.email == settings.super_admin_email))
        if existing and existing.role != UserRole.super_admin:
            # Email is already taken by a non-super-admin user.
            # Keep current behavior: do not override silently.
            return

        if not existing:
            existing = User(
                email=settings.super_admin_email,
                password_hash=hash_password(settings.super_admin_password),
                role=UserRole.super_admin,
                office_id=None,
                is_active=True,
            )
            db.add(existing)
            db.commit()
            return

        # If requested, force-reset credentials (first-time access helper).
        if settings.super_admin_force_reset:
            existing.password_hash = hash_password(settings.super_admin_password)
            existing.is_active = True
            if settings.super_admin_disable_others_on_reset:
                db.query(User).where(User.role == UserRole.super_admin, User.id != existing.id).update({"is_active": False})
            db.commit()


def _token_to_user(db: Session, token: str) -> User:
    try:
        payload = decode_token(token)
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    if payload.get("type") != "access":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token type")
    user_id = payload.get("uid")
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token payload")
    user = db.get(User, int(user_id))
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    if getattr(user, "is_active", True) is False:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User disabled")
    return user


def current_user(db: Session = Depends(get_db), token: str = Depends(oauth2_scheme)) -> User:
    return _token_to_user(db, token)


def require_super_admin(user: User = Depends(current_user)) -> User:
    if user.role != UserRole.super_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Super admin required")
    return user


def require_office_user(user: User = Depends(current_user)) -> User:
    if user.role not in (UserRole.office_owner, UserRole.staff):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Office user required")
    if not user.office_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Office context required")
    return user


def require_active_subscription(db: Session = Depends(get_db), user: User = Depends(require_office_user)) -> User:
    sub = db.scalar(select(Subscription).where(Subscription.office_id == user.office_id).order_by(Subscription.id.desc()))
    if not sub:
        raise HTTPException(status_code=status.HTTP_402_PAYMENT_REQUIRED, detail="No subscription")
    if sub.end_at <= _now():
        raise HTTPException(status_code=status.HTTP_402_PAYMENT_REQUIRED, detail="Subscription expired")

    now = _now()

    # Enforce user limit by subscription plan.
    # include `office_owner` in the user limit count.
    max_users_total: int | None = None
    if sub.status == SubscriptionStatus.trial:
        max_users_total = 3
    else:
        plan: Plan | None = None
        if getattr(sub, "plan_id", None):
            plan = db.get(Plan, int(sub.plan_id))
        if not plan and sub.plan_name_snapshot:
            plan = db.scalar(select(Plan).where(Plan.name == sub.plan_name_snapshot))
        max_users_total = int(getattr(plan, "max_users", None) or 0) or None

    if not max_users_total:
        # Backwards compatibility: if legacy plans don't have limits.
        max_users_total = 10_000

    # Only disable when actual limit exceeded.
    active_count = db.scalar(
        select(func.count()).select_from(User).where(User.office_id == user.office_id, User.is_active == True)
    )
    if active_count is not None and int(active_count) > max_users_total:
        allowed_staff_count = max(max_users_total - 1, 0)
        staff_users = db.scalars(
            select(User).where(
                User.office_id == user.office_id,
                User.role == UserRole.staff,
                User.is_active == True,
            ).order_by(User.id.asc())
        ).all()
        if len(staff_users) > allowed_staff_count:
            to_disable = [u.id for u in staff_users[allowed_staff_count:]]
            db.query(User).where(User.id.in_(to_disable)).update({"is_active": False}, synchronize_session=False)
            db.query(UserPermission).where(UserPermission.office_id == user.office_id, UserPermission.user_id.in_(to_disable)).delete(
                synchronize_session=False
            )
            db.commit()

    # If trial is expiring soon, block protected endpoints to prevent data loss.
    # This affects all users inside the office while they are in `trial`.
    TRIAL_BLOCK_DAYS_BEFORE = 3
    if sub.status == SubscriptionStatus.trial:
        if (sub.end_at - now) <= timedelta(days=TRIAL_BLOCK_DAYS_BEFORE):
            raise HTTPException(
                status_code=status.HTTP_402_PAYMENT_REQUIRED,
                detail="Trial expiring. Please upgrade subscription to avoid data loss.",
            )
    if sub.status not in (SubscriptionStatus.trial, SubscriptionStatus.active):
        raise HTTPException(status_code=status.HTTP_402_PAYMENT_REQUIRED, detail="Subscription inactive")
    return user


def require_office_admin(user: User = Depends(require_office_user)) -> User:
    if user.role != UserRole.office_owner:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Office admin required")
    return user


def _user_perm_keys(db: Session, user: User) -> set[str]:
    rows = db.scalars(select(UserPermission.perm_key).where(UserPermission.office_id == user.office_id, UserPermission.user_id == user.id)).all()
    return set(rows)


def require_perm(perm_key: str):
    def _dep(db: Session = Depends(get_db), user: User = Depends(require_active_subscription)) -> User:
        if perm_key not in PERMISSIONS:
            raise HTTPException(status_code=500, detail="Unknown permission key")

        # Trial: open all modules, but still require a valid subscription.
        latest = db.scalar(
            select(Subscription).where(Subscription.office_id == user.office_id).order_by(Subscription.id.desc())
        )
        if latest and latest.status == SubscriptionStatus.trial:
            return user

        # مالك المكتب غير مقيّد بحد وحدات الباقة على الـ API؛ حد الباقة يطبق على الموظفين عبر صلاحياتهم.
        if user.role == UserRole.office_owner:
            return user

        plan: Plan | None = None
        if latest:
            if getattr(latest, "plan_id", None):
                plan = db.get(Plan, int(latest.plan_id))
            if not plan and latest.plan_name_snapshot:
                plan = db.scalar(select(Plan).where(Plan.name == latest.plan_name_snapshot))

        # Backwards compatibility: if plan doesn't define allowed modules, allow everything.
        if not plan or not getattr(plan, "allowed_perm_keys_csv", None):
            allowed_perm_keys = set(PERMISSIONS.keys())
        else:
            allowed_perm_keys = {k.strip() for k in plan.allowed_perm_keys_csv.split(",") if k.strip() and k.strip() in PERMISSIONS}

        if perm_key not in allowed_perm_keys:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden by plan")

        keys = _user_perm_keys(db, user)
        if perm_key not in keys:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")
        return user

    return _dep


@app.get("/health")
def health():
    return {"ok": True, "name": settings.app_name}


@app.post("/auth/signup", response_model=SignupResponse)
def signup(payload: SignupRequest, db: Session = Depends(get_db)):
    # email must be unique globally
    existing = db.scalar(select(User).where(User.email == payload.email))
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    code = _gen_office_code()
    # Rare collision check
    while db.scalar(select(Office).where(Office.code == code)):
        code = _gen_office_code()

    office = Office(code=code, name=payload.office_name, status=OfficeStatus.active)
    db.add(office)
    db.flush()

    user = User(
        office_id=office.id,
        email=payload.email,
        password_hash=hash_password(payload.password),
        role=UserRole.office_owner,
    )
    db.add(user)
    db.flush()

    start_at = _now()
    end_at = start_at + timedelta(days=settings.trial_days_default)
    sub = Subscription(
        office_id=office.id,
        status=SubscriptionStatus.trial,
        start_at=start_at,
        end_at=end_at,
        notes="auto trial",
    )
    db.add(sub)
    db.commit()

    access = create_access_token(subject=str(user.id), extra={"uid": user.id, "role": user.role, "office_id": user.office_id})
    refresh = create_refresh_token(subject=str(user.id), extra={"uid": user.id, "role": user.role, "office_id": user.office_id})

    link = f"{settings.app_base_url.rstrip('/')}/o/{office.code}"
    return SignupResponse(
        office_code=office.code,
        office_link=link,
        trial_end_at=end_at,
        tokens=TokenPair(access_token=access, refresh_token=refresh),
    )


@app.post("/auth/login", response_model=TokenPair)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == payload.email))
    if not user or getattr(user, "is_active", True) is False or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=400, detail="Invalid credentials")

    access = create_access_token(subject=str(user.id), extra={"uid": user.id, "role": user.role, "office_id": user.office_id})
    refresh = create_refresh_token(subject=str(user.id), extra={"uid": user.id, "role": user.role, "office_id": user.office_id})
    return TokenPair(access_token=access, refresh_token=refresh)


@app.get("/me", response_model=UserOut)
def me(user: User = Depends(current_user)):
    return UserOut(
        id=user.id,
        email=user.email,
        full_name=getattr(user, "full_name", None),
        is_active=getattr(user, "is_active", True),
        role=user.role,
        office_id=user.office_id,
        created_at=user.created_at,
    )


@app.get("/me/permissions", response_model=UserPermissionsOut)
def me_permissions(db: Session = Depends(get_db), user: User = Depends(require_office_user)):
    if user.role == UserRole.office_owner:
        # المالك يرى كل مفاتيح الكتالوج في الواجهة؛ حدود الباقة تظهر للموظفين وتُفرض عند منح الصلاحيات.
        return UserPermissionsOut(user_id=user.id, permissions=sorted(PERMISSIONS.keys()))
    keys = db.scalars(
        select(UserPermission.perm_key).where(UserPermission.office_id == user.office_id, UserPermission.user_id == user.id).order_by(UserPermission.perm_key.asc())
    ).all()
    return UserPermissionsOut(user_id=user.id, permissions=list(keys))


@app.get("/office", response_model=OfficeOut)
def my_office(db: Session = Depends(get_db), user: User = Depends(require_office_user)):
    office = db.get(Office, user.office_id)
    if not office:
        raise HTTPException(status_code=404, detail="Office not found")
    return OfficeOut(id=office.id, code=office.code, name=office.name, status=office.status, created_at=office.created_at)


@app.get("/office/users", response_model=list[OfficeUserOut])
def office_users(db: Session = Depends(get_db), user: User = Depends(require_perm("employees.read"))):
    users = db.scalars(select(User).where(User.office_id == user.office_id).order_by(User.id.asc())).all()
    return [
        OfficeUserOut(
            id=u.id,
            email=u.email,
            full_name=getattr(u, "full_name", None),
            is_active=getattr(u, "is_active", True),
            role=u.role,
            created_at=u.created_at,
        )
        for u in users
    ]


@app.post("/office/users", response_model=OfficeUserCreateOut)
def office_create_user(payload: OfficeUserCreate, db: Session = Depends(get_db), user: User = Depends(require_office_admin)):
    existing = db.scalar(select(User).where(User.email == payload.email))
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    # Enforce subscription + trial protection and user limit.
    sub = db.scalar(select(Subscription).where(Subscription.office_id == user.office_id).order_by(Subscription.id.desc()))
    if not sub:
        raise HTTPException(status_code=status.HTTP_402_PAYMENT_REQUIRED, detail="No subscription")
    now = _now()
    if sub.end_at <= now:
        raise HTTPException(status_code=status.HTTP_402_PAYMENT_REQUIRED, detail="Subscription expired")
    if sub.status == SubscriptionStatus.trial:
        TRIAL_BLOCK_DAYS_BEFORE = 3
        if (sub.end_at - now) <= timedelta(days=TRIAL_BLOCK_DAYS_BEFORE):
            raise HTTPException(status_code=status.HTTP_402_PAYMENT_REQUIRED, detail="Trial expiring. Upgrade subscription.")
        max_users_total = 3
        allowed_perm_keys = set(PERMISSIONS.keys())
    else:
        plan: Plan | None = None
        if getattr(sub, "plan_id", None):
            plan = db.get(Plan, int(sub.plan_id))
        if not plan and sub.plan_name_snapshot:
            plan = db.scalar(select(Plan).where(Plan.name == sub.plan_name_snapshot))
        max_users_total = int(getattr(plan, "max_users", None) or 0) or 10_000
        if not plan or not getattr(plan, "allowed_perm_keys_csv", None):
            allowed_perm_keys = set(PERMISSIONS.keys())
        else:
            allowed_perm_keys = {k.strip() for k in plan.allowed_perm_keys_csv.split(",") if k.strip() and k.strip() in PERMISSIONS}

    active_count = db.scalar(
        select(func.count()).select_from(User).where(User.office_id == user.office_id, User.is_active == True)
    )
    if active_count is not None and int(active_count) >= int(max_users_total):
        raise HTTPException(status_code=status.HTTP_402_PAYMENT_REQUIRED, detail="User limit reached for this subscription")

    u = User(
        office_id=user.office_id,
        email=payload.email.strip(),
        full_name=payload.full_name.strip(),
        password_hash=hash_password(payload.password),
        is_active=True,
        role=UserRole.staff,
    )
    db.add(u)

    db.flush()

    # Auto-assign the plan modules permissions for the new staff.
    for key in allowed_perm_keys:
        db.add(UserPermission(office_id=u.office_id, user_id=u.id, perm_key=key))

    db.commit()
    db.refresh(u)
    return OfficeUserCreateOut(
        id=u.id,
        email=u.email,
        full_name=getattr(u, "full_name", None),
        is_active=getattr(u, "is_active", True),
        role=u.role,
    )


@app.delete("/office/users/{user_id}")
def office_disable_user(user_id: int, db: Session = Depends(get_db), admin: User = Depends(require_office_admin)):
    target = db.get(User, user_id)
    if not target or target.office_id != admin.office_id:
        raise HTTPException(status_code=404, detail="User not found")
    if target.id == admin.id:
        raise HTTPException(status_code=400, detail="Cannot disable yourself")
    if target.role in (UserRole.office_owner, UserRole.super_admin):
        raise HTTPException(status_code=400, detail="Cannot disable this user")
    target.is_active = False
    # Optional cleanup: remove their permissions
    db.query(UserPermission).where(UserPermission.office_id == admin.office_id, UserPermission.user_id == user_id).delete()
    db.commit()
    return {"ok": True}


@app.get("/office/permissions", response_model=list[PermissionCatalogItem])
def office_permission_catalog(_: User = Depends(require_office_user)):
    return [PermissionCatalogItem(key=k, label=v) for k, v in PERMISSIONS.items()]


@app.get("/office/users/{user_id}/permissions", response_model=UserPermissionsOut)
def get_user_permissions(user_id: int, db: Session = Depends(get_db), user: User = Depends(require_perm("employees.read"))):
    target = db.get(User, user_id)
    if not target or target.office_id != user.office_id:
        raise HTTPException(status_code=404, detail="User not found")
    keys = db.scalars(
        select(UserPermission.perm_key).where(UserPermission.office_id == user.office_id, UserPermission.user_id == user_id).order_by(UserPermission.perm_key.asc())
    ).all()
    return UserPermissionsOut(user_id=user_id, permissions=list(keys))


@app.put("/office/users/{user_id}/permissions", response_model=UserPermissionsOut)
def put_user_permissions(
    user_id: int,
    payload: UserPermissionsUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_office_admin),
):
    target = db.get(User, user_id)
    if not target or target.office_id is None:
        raise HTTPException(status_code=404, detail="User not found")
    if target.office_id != _.office_id:
        raise HTTPException(status_code=404, detail="User not found")
    invalid = [k for k in payload.permissions if k not in PERMISSIONS]
    if invalid:
        raise HTTPException(status_code=400, detail=f"Invalid permission keys: {', '.join(invalid)}")

    # Validate against current plan restrictions (staff/owner must not be granted more than the subscription allows).
    sub = db.scalar(
        select(Subscription).where(Subscription.office_id == _.office_id).order_by(Subscription.id.desc())
    )
    if sub and sub.status != SubscriptionStatus.trial:
        plan: Plan | None = None
        if getattr(sub, "plan_id", None):
            plan = db.get(Plan, int(sub.plan_id))
        if not plan and sub.plan_name_snapshot:
            plan = db.scalar(select(Plan).where(Plan.name == sub.plan_name_snapshot))

        allowed_perm_keys: set[str]
        if plan and getattr(plan, "allowed_perm_keys_csv", None):
            allowed_perm_keys = {k.strip() for k in plan.allowed_perm_keys_csv.split(",") if k.strip() and k.strip() in PERMISSIONS}
        else:
            allowed_perm_keys = set(PERMISSIONS.keys())

        disallowed = [k for k in set(payload.permissions) if k not in allowed_perm_keys]
        if disallowed:
            raise HTTPException(
                status_code=400,
                detail=f"These permissions are not allowed by current subscription: {', '.join(sorted(disallowed))}",
            )

    db.query(UserPermission).where(UserPermission.office_id == _.office_id, UserPermission.user_id == user_id).delete()
    for key in sorted(set(payload.permissions)):
        db.add(UserPermission(office_id=_.office_id, user_id=user_id, perm_key=key))
    db.commit()
    return UserPermissionsOut(user_id=user_id, permissions=sorted(set(payload.permissions)))


@app.get("/clients", response_model=list[ClientOut])
def list_clients(db: Session = Depends(get_db), user: User = Depends(require_perm("clients.read"))):
    items = db.scalars(select(Client).where(Client.office_id == user.office_id).order_by(Client.id.desc())).all()
    return [
        ClientOut(
            id=c.id,
            full_name=c.full_name,
            phone=c.phone,
            national_id=c.national_id,
            address=c.address,
            notes=c.notes,
            created_at=c.created_at,
        )
        for c in items
    ]


@app.post("/clients", response_model=ClientOut)
def create_client(payload: ClientCreate, db: Session = Depends(get_db), user: User = Depends(require_perm("clients.create"))):
    c = Client(
        office_id=user.office_id,
        full_name=payload.full_name,
        phone=payload.phone,
        national_id=payload.national_id,
        address=payload.address,
        notes=payload.notes,
    )
    db.add(c)
    db.commit()
    db.refresh(c)
    return ClientOut(
        id=c.id,
        full_name=c.full_name,
        phone=c.phone,
        national_id=c.national_id,
        address=c.address,
        notes=c.notes,
        created_at=c.created_at,
    )


def _case_to_out(case: Case, client: Client, primary: User | None) -> CaseOut:
    return CaseOut(
        id=case.id,
        client_id=case.client_id,
        client_name=client.full_name,
        title=case.title,
        kind=case.kind,
        court=case.court,
        case_number=case.case_number,
        case_year=case.case_year,
        first_hearing_at=case.first_hearing_at,
        fee_total=float(case.fee_total) if case.fee_total is not None else None,
        is_active=case.is_active,
        primary_lawyer_user_id=primary.id if primary else None,
        primary_lawyer_email=primary.email if primary else None,
        created_at=case.created_at,
    )


@app.get("/cases", response_model=list[CaseOut])
def list_cases(
    client_id: int | None = Query(default=None),
    db: Session = Depends(get_db),
    user: User = Depends(require_perm("cases.read")),
):
    stmt = select(Case, Client).join(Client, Client.id == Case.client_id).where(Case.office_id == user.office_id)
    if client_id is not None:
        stmt = stmt.where(Case.client_id == client_id)
    rows = db.execute(stmt.order_by(Case.id.desc())).all()

    # Preload primary assignments and users
    case_ids = [c.id for c, _ in rows]
    assigns = {}
    if case_ids:
        arows = db.execute(
            select(CaseAssignment, User)
            .join(User, User.id == CaseAssignment.user_id)
            .where(CaseAssignment.office_id == user.office_id, CaseAssignment.case_id.in_(case_ids), CaseAssignment.is_primary == True)  # noqa: E712
        ).all()
        for a, u in arows:
            assigns[a.case_id] = u

    out: list[CaseOut] = []
    for case, client in rows:
        u = assigns.get(case.id)
        out.append(_case_to_out(case, client, u))
    return out


@app.get("/cases/{case_id}", response_model=CaseOut)
def get_case(
    case_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(require_perm("cases.read")),
):
    row = db.execute(
        select(Case, Client)
        .join(Client, Client.id == Case.client_id)
        .where(Case.office_id == user.office_id, Case.id == case_id)
    ).first()
    if not row:
        raise HTTPException(status_code=404, detail="Case not found")
    case, client = row
    primary = db.scalar(
        select(User)
        .join(CaseAssignment, CaseAssignment.user_id == User.id)
        .where(
            CaseAssignment.office_id == user.office_id,
            CaseAssignment.case_id == case.id,
            CaseAssignment.is_primary == True,  # noqa: E712
        )
    )
    return _case_to_out(case, client, primary)


@app.post("/cases", response_model=CaseOut)
def create_case(payload: CaseCreate, db: Session = Depends(get_db), user: User = Depends(require_perm("cases.create"))):
    client = db.get(Client, payload.client_id)
    if not client or client.office_id != user.office_id:
        raise HTTPException(status_code=404, detail="Client not found")

    case = Case(
        office_id=user.office_id,
        client_id=payload.client_id,
        title=payload.title,
        kind=payload.kind,
        court=payload.court,
        case_number=payload.case_number,
        case_year=payload.case_year,
        first_hearing_at=payload.first_hearing_at,
        fee_total=payload.fee_total,
        is_active=True,
    )
    db.add(case)
    db.flush()

    primary_user: User | None = None
    if payload.primary_lawyer_user_id is not None:
        primary_user = db.get(User, payload.primary_lawyer_user_id)
        if not primary_user or primary_user.office_id != user.office_id:
            raise HTTPException(status_code=404, detail="Lawyer not found")
        db.add(
            CaseAssignment(
                office_id=user.office_id,
                case_id=case.id,
                user_id=primary_user.id,
                is_primary=True,
            )
        )

    if payload.first_hearing_at is not None:
        db.add(
            CaseSession(
                office_id=user.office_id,
                case_id=case.id,
                session_number=payload.first_session_number,
                session_year=payload.first_session_year,
                session_date=payload.first_hearing_at,
                notes=None,
            )
        )

    db.commit()
    db.refresh(case)
    return CaseOut(
        id=case.id,
        client_id=case.client_id,
        client_name=client.full_name,
        title=case.title,
        kind=case.kind,
        court=case.court,
        case_number=case.case_number,
        case_year=case.case_year,
        first_hearing_at=case.first_hearing_at,
        fee_total=float(case.fee_total) if case.fee_total is not None else None,
        is_active=case.is_active,
        primary_lawyer_user_id=primary_user.id if primary_user else None,
        primary_lawyer_email=primary_user.email if primary_user else None,
        created_at=case.created_at,
    )


@app.post("/cases/{case_id}/files")
def upload_case_file(
    case_id: int,
    upload: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(require_perm("cases.upload")),
):
    case = db.get(Case, case_id)
    if not case or case.office_id != user.office_id:
        raise HTTPException(status_code=404, detail="Case not found")

    _ensure_upload_dir()
    safe_name = os.path.basename(upload.filename or "file")
    ext = Path(safe_name).suffix[:10]
    file_id = uuid4().hex
    rel_path = f"{user.office_id}/{case_id}/{file_id}{ext}"
    full_path = Path(settings.upload_dir) / rel_path
    full_path.parent.mkdir(parents=True, exist_ok=True)

    data = upload.file.read()
    full_path.write_bytes(data)

    rec = CaseFile(
        office_id=user.office_id,
        case_id=case_id,
        original_name=safe_name,
        content_type=upload.content_type,
        storage_path=str(full_path),
        size_bytes=len(data),
        uploaded_by_user_id=user.id,
    )
    db.add(rec)
    db.commit()
    return {"ok": True, "id": rec.id, "name": rec.original_name}


@app.get("/cases/{case_id}/files", response_model=list[CaseFileOut])
def list_case_files(case_id: int, db: Session = Depends(get_db), user: User = Depends(require_perm("cases.read"))):
    case = db.get(Case, case_id)
    if not case or case.office_id != user.office_id:
        raise HTTPException(status_code=404, detail="Case not found")
    items = db.scalars(
        select(CaseFile)
        .where(CaseFile.office_id == user.office_id, CaseFile.case_id == case_id)
        .order_by(CaseFile.uploaded_at.desc(), CaseFile.id.desc())
    ).all()
    return [
        CaseFileOut(
            id=f.id,
            case_id=f.case_id,
            original_name=f.original_name,
            content_type=f.content_type,
            size_bytes=f.size_bytes,
            uploaded_at=f.uploaded_at,
        )
        for f in items
    ]


@app.get("/case-files/{file_id}")
def download_case_file(file_id: int, db: Session = Depends(get_db), user: User = Depends(require_perm("cases.read"))):
    f = db.get(CaseFile, file_id)
    if not f or f.office_id != user.office_id:
        raise HTTPException(status_code=404, detail="File not found")
    path = Path(f.storage_path)
    if not path.exists():
        raise HTTPException(status_code=404, detail="File missing")
    return FileResponse(path, media_type=f.content_type or "application/octet-stream", filename=f.original_name)


@app.delete("/case-files/{file_id}")
def delete_case_file(
    file_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(require_perm("cases.upload")),
):
    f = db.get(CaseFile, file_id)
    if not f or f.office_id != user.office_id:
        raise HTTPException(status_code=404, detail="File not found")
    path = Path(f.storage_path)
    db.delete(f)
    db.commit()
    if path.exists():
        try:
            path.unlink()
        except OSError:
            pass
    return {"ok": True}


@app.get("/cases/{case_id}/transactions", response_model=list[CaseTransactionOut])
def list_case_transactions(case_id: int, db: Session = Depends(get_db), user: User = Depends(require_perm("accounts.read"))):
    case = db.get(Case, case_id)
    if not case or case.office_id != user.office_id:
        raise HTTPException(status_code=404, detail="Case not found")
    items = db.scalars(
        select(CaseTransaction)
        .where(CaseTransaction.office_id == user.office_id, CaseTransaction.case_id == case_id)
        .order_by(CaseTransaction.occurred_at.desc(), CaseTransaction.id.desc())
    ).all()
    return [
        CaseTransactionOut(
            id=t.id,
            case_id=t.case_id,
            direction=t.direction,
            amount=float(t.amount),
            description=t.description,
            occurred_at=t.occurred_at,
            created_at=t.created_at,
        )
        for t in items
    ]


@app.get("/sessions", response_model=list[SessionOut])
def list_sessions(db: Session = Depends(get_db), user: User = Depends(require_perm("cases.read"))):
    rows = db.execute(
        select(CaseSession, Case, Client)
        .join(Case, Case.id == CaseSession.case_id)
        .join(Client, Client.id == Case.client_id)
        .where(CaseSession.office_id == user.office_id)
        .order_by(CaseSession.session_date.asc(), CaseSession.id.asc())
    ).all()
    return [
        SessionOut(
            id=s.id,
            case_id=s.case_id,
            case_title=c.title,
            client_name=cl.full_name,
            session_number=s.session_number,
            session_year=s.session_year,
            session_date=s.session_date,
            notes=s.notes,
            created_at=s.created_at,
        )
        for s, c, cl in rows
    ]


@app.post("/sessions", response_model=SessionOut)
def create_session(
    payload: SessionCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_office_admin),
):
    case = db.get(Case, payload.case_id)
    if not case or case.office_id != user.office_id:
        raise HTTPException(status_code=404, detail="Case not found")
    s = CaseSession(
        office_id=user.office_id,
        case_id=payload.case_id,
        session_number=payload.session_number,
        session_year=payload.session_year,
        session_date=payload.session_date,
        notes=payload.notes,
    )
    db.add(s)
    db.commit()
    db.refresh(s)
    c = db.get(Case, s.case_id)
    cl = db.get(Client, c.client_id) if c else None
    if not c or not cl:
        raise HTTPException(status_code=404, detail="Case not found")
    return SessionOut(
        id=s.id,
        case_id=s.case_id,
        case_title=c.title,
        client_name=cl.full_name,
        session_number=s.session_number,
        session_year=s.session_year,
        session_date=s.session_date,
        notes=s.notes,
        created_at=s.created_at,
    )


@app.put("/sessions/{session_id}", response_model=SessionOut)
def update_session(
    session_id: int,
    payload: SessionUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(require_office_admin),
):
    s = db.get(CaseSession, session_id)
    if not s or s.office_id != user.office_id:
        raise HTTPException(status_code=404, detail="Session not found")
    if payload.session_date is not None:
        s.session_date = payload.session_date
    if payload.session_number is not None:
        s.session_number = payload.session_number
    if payload.session_year is not None:
        s.session_year = payload.session_year
    if payload.notes is not None:
        s.notes = payload.notes
    db.commit()
    db.refresh(s)

    c = db.get(Case, s.case_id)
    cl = db.get(Client, c.client_id) if c else None
    if not c or not cl:
        raise HTTPException(status_code=404, detail="Case not found")
    return SessionOut(
        id=s.id,
        case_id=s.case_id,
        case_title=c.title,
        client_name=cl.full_name,
        session_number=s.session_number,
        session_year=s.session_year,
        session_date=s.session_date,
        notes=s.notes,
        created_at=s.created_at,
    )


@app.delete("/sessions/{session_id}")
def delete_session_endpoint(
    session_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(require_office_admin),
):
    s = db.get(CaseSession, session_id)
    if not s or s.office_id != user.office_id:
        raise HTTPException(status_code=404, detail="Session not found")
    db.delete(s)
    db.commit()
    return {"ok": True}


@app.post("/transactions", response_model=CaseTransactionOut)
def create_transaction(payload: CaseTransactionCreate, db: Session = Depends(get_db), user: User = Depends(require_perm("accounts.read"))):
    case = db.get(Case, payload.case_id)
    if not case or case.office_id != user.office_id:
        raise HTTPException(status_code=404, detail="Case not found")
    t = CaseTransaction(
        office_id=user.office_id,
        case_id=payload.case_id,
        direction=payload.direction,
        amount=payload.amount,
        description=payload.description,
        occurred_at=payload.occurred_at or _now(),
        created_by_user_id=user.id,
    )
    db.add(t)
    db.commit()
    db.refresh(t)
    return CaseTransactionOut(
        id=t.id,
        case_id=t.case_id,
        direction=t.direction,
        amount=float(t.amount),
        description=t.description,
        occurred_at=t.occurred_at,
        created_at=t.created_at,
    )


@app.post("/custody/accounts", response_model=CustodyAccountOut)
def custody_create_account(payload: CustodyAccountCreate, db: Session = Depends(get_db), user: User = Depends(require_perm("custody.admin.view"))):
    target = db.get(User, payload.user_id)
    if not target or target.office_id != user.office_id:
        raise HTTPException(status_code=404, detail="User not found")
    existing = db.scalar(select(CustodyAccount).where(CustodyAccount.office_id == user.office_id, CustodyAccount.user_id == payload.user_id))
    if existing:
        # If the account exists, allow setting/adding custody amount in one step.
        if payload.initial_amount is None:
            raise HTTPException(status_code=400, detail="Account already exists")
        adv = CustodyAdvance(
            office_id=user.office_id,
            account_id=existing.id,
            amount=payload.initial_amount,
            occurred_at=_now(),
            notes="custody top-up",
            created_by_user_id=user.id,
        )
        db.add(adv)
        existing.current_balance = float(existing.current_balance) + float(payload.initial_amount)
        db.commit()
        db.refresh(existing)
        return CustodyAccountOut(
            id=existing.id,
            user_id=existing.user_id,
            user_email=target.email,
            current_balance=float(existing.current_balance),
            created_at=existing.created_at,
        )
    acc = CustodyAccount(office_id=user.office_id, user_id=payload.user_id, current_balance=0)
    db.add(acc)
    db.commit()
    db.refresh(acc)

    # If office sets initial custody amount, record it as an advance and update balance.
    if payload.initial_amount is not None:
        adv = CustodyAdvance(
            office_id=user.office_id,
            account_id=acc.id,
            amount=payload.initial_amount,
            occurred_at=_now(),
            notes="initial custody",
            created_by_user_id=user.id,
        )
        db.add(adv)
        acc.current_balance = float(acc.current_balance) + float(payload.initial_amount)
        db.commit()
        db.refresh(acc)
    return CustodyAccountOut(id=acc.id, user_id=acc.user_id, user_email=target.email, current_balance=float(acc.current_balance), created_at=acc.created_at)


@app.get("/custody/accounts", response_model=list[CustodyAccountOut])
def custody_list_accounts(db: Session = Depends(get_db), user: User = Depends(require_perm("custody.admin.view"))):
    rows = db.execute(
        select(CustodyAccount, User).join(User, User.id == CustodyAccount.user_id).where(CustodyAccount.office_id == user.office_id).order_by(CustodyAccount.id.desc())
    ).all()
    return [
        CustodyAccountOut(
            id=acc.id,
            user_id=acc.user_id,
            user_email=u.email,
            current_balance=float(acc.current_balance),
            created_at=acc.created_at,
        )
        for acc, u in rows
    ]


@app.get("/custody/me", response_model=CustodyAccountOut)
def custody_me(db: Session = Depends(get_db), user: User = Depends(require_perm("custody.me"))):
    acc = db.scalar(select(CustodyAccount).where(CustodyAccount.office_id == user.office_id, CustodyAccount.user_id == user.id))
    if not acc:
        raise HTTPException(status_code=404, detail="No custody account")
    return CustodyAccountOut(id=acc.id, user_id=user.id, user_email=user.email, current_balance=float(acc.current_balance), created_at=acc.created_at)


@app.get("/custody/me/ledger", response_model=list[CustodyLedgerEntryOut])
def custody_my_ledger(db: Session = Depends(get_db), user: User = Depends(require_perm("custody.me"))):
    acc = db.scalar(select(CustodyAccount).where(CustodyAccount.office_id == user.office_id, CustodyAccount.user_id == user.id))
    if not acc:
        raise HTTPException(status_code=404, detail="No custody account")
    advances = db.scalars(
        select(CustodyAdvance).where(CustodyAdvance.office_id == user.office_id, CustodyAdvance.account_id == acc.id).order_by(CustodyAdvance.occurred_at.desc(), CustodyAdvance.id.desc())
    ).all()
    spends = db.scalars(
        select(CustodySpend).where(CustodySpend.office_id == user.office_id, CustodySpend.account_id == acc.id).order_by(CustodySpend.occurred_at.desc(), CustodySpend.id.desc())
    ).all()
    items: list[CustodyLedgerEntryOut] = []
    for a in advances:
        items.append(
            CustodyLedgerEntryOut(
                kind="advance",
                amount=float(a.amount),
                occurred_at=a.occurred_at,
                description=a.notes,
                status=None,
                spend_id=None,
            )
        )
    for s in spends:
        items.append(
            CustodyLedgerEntryOut(
                kind="spend",
                amount=float(s.amount),
                occurred_at=s.occurred_at,
                description=s.description,
                status=s.status,
                spend_id=s.id,
            )
        )
    items.sort(key=lambda x: (x.occurred_at, 0 if x.kind == "advance" else 1), reverse=True)
    return items


@app.post("/custody/advances", response_model=CustodyAccountOut)
def custody_add_advance(payload: CustodyAdvanceCreate, db: Session = Depends(get_db), user: User = Depends(require_perm("custody.admin.advance"))):
    target = db.get(User, payload.user_id)
    if not target or target.office_id != user.office_id:
        raise HTTPException(status_code=404, detail="User not found")
    acc = db.scalar(select(CustodyAccount).where(CustodyAccount.office_id == user.office_id, CustodyAccount.user_id == payload.user_id))
    if not acc:
        raise HTTPException(status_code=404, detail="No custody account")
    adv = CustodyAdvance(
        office_id=user.office_id,
        account_id=acc.id,
        amount=payload.amount,
        occurred_at=payload.occurred_at or _now(),
        notes=payload.notes,
        created_by_user_id=user.id,
    )
    db.add(adv)
    acc.current_balance = float(acc.current_balance) + payload.amount
    db.commit()
    db.refresh(acc)
    return CustodyAccountOut(id=acc.id, user_id=target.id, user_email=target.email, current_balance=float(acc.current_balance), created_at=acc.created_at)


@app.post("/custody/spends", response_model=CustodySpendOut)
def custody_create_spend(payload: CustodySpendCreate, db: Session = Depends(get_db), user: User = Depends(require_perm("custody.spend.create"))):
    acc = db.scalar(select(CustodyAccount).where(CustodyAccount.office_id == user.office_id, CustodyAccount.user_id == user.id))
    if not acc:
        raise HTTPException(status_code=404, detail="No custody account")
    if payload.case_id is not None:
        case = db.get(Case, payload.case_id)
        if not case or case.office_id != user.office_id:
            raise HTTPException(status_code=404, detail="Case not found")
    spend = CustodySpend(
        office_id=user.office_id,
        account_id=acc.id,
        amount=payload.amount,
        occurred_at=payload.occurred_at or _now(),
        description=payload.description,
        status=CustodySpendStatus.pending,
        case_id=payload.case_id,
        created_by_user_id=user.id,
    )
    db.add(spend)
    db.commit()
    db.refresh(spend)
    return CustodySpendOut(
        id=spend.id,
        user_id=user.id,
        amount=float(spend.amount),
        occurred_at=spend.occurred_at,
        description=spend.description,
        status=spend.status,
        case_id=spend.case_id,
        reject_reason=spend.reject_reason,
        created_at=spend.created_at,
    )


@app.get("/custody/spends", response_model=list[CustodySpendOut])
def custody_list_spends(db: Session = Depends(get_db), user: User = Depends(require_perm("custody.admin.view"))):
    rows = db.scalars(select(CustodySpend).where(CustodySpend.office_id == user.office_id).order_by(CustodySpend.id.desc())).all()
    # map account->user_id
    accounts = {a.id: a.user_id for a in db.scalars(select(CustodyAccount).where(CustodyAccount.office_id == user.office_id)).all()}
    return [
        CustodySpendOut(
            id=s.id,
            user_id=accounts.get(s.account_id, 0),
            amount=float(s.amount),
            occurred_at=s.occurred_at,
            description=s.description,
            status=s.status,
            case_id=s.case_id,
            reject_reason=s.reject_reason,
            created_at=s.created_at,
        )
        for s in rows
    ]


@app.post("/custody/spends/{spend_id}/approve", response_model=CustodySpendOut)
def custody_approve_spend(spend_id: int, db: Session = Depends(get_db), user: User = Depends(require_perm("custody.admin.approve"))):
    spend = db.get(CustodySpend, spend_id)
    if not spend or spend.office_id != user.office_id:
        raise HTTPException(status_code=404, detail="Spend not found")
    if spend.status != CustodySpendStatus.pending:
        raise HTTPException(status_code=400, detail="Spend already reviewed")
    # Require at least one uploaded receipt before approving.
    has_receipt = db.scalar(
        select(CustodyReceiptFile.id)
        .where(CustodyReceiptFile.office_id == user.office_id, CustodyReceiptFile.spend_id == spend_id)
        .limit(1)
    )
    if not has_receipt:
        raise HTTPException(status_code=400, detail="Receipt required before approval")
    acc = db.get(CustodyAccount, spend.account_id)
    if not acc or acc.office_id != user.office_id:
        raise HTTPException(status_code=404, detail="Account not found")
    if float(acc.current_balance) < float(spend.amount):
        raise HTTPException(status_code=400, detail="Insufficient balance")
    acc.current_balance = float(acc.current_balance) - float(spend.amount)
    spend.status = CustodySpendStatus.approved
    spend.reviewed_by_user_id = user.id
    spend.reviewed_at = _now()
    db.commit()
    db.refresh(spend)
    return CustodySpendOut(
        id=spend.id,
        user_id=acc.user_id,
        amount=float(spend.amount),
        occurred_at=spend.occurred_at,
        description=spend.description,
        status=spend.status,
        case_id=spend.case_id,
        reject_reason=spend.reject_reason,
        created_at=spend.created_at,
    )


@app.post("/custody/spends/{spend_id}/reject", response_model=CustodySpendOut)
def custody_reject_spend(
    spend_id: int,
    payload: CustodyReviewRequest,
    db: Session = Depends(get_db),
    user: User = Depends(require_perm("custody.admin.approve")),
):
    spend = db.get(CustodySpend, spend_id)
    if not spend or spend.office_id != user.office_id:
        raise HTTPException(status_code=404, detail="Spend not found")
    if spend.status != CustodySpendStatus.pending:
        raise HTTPException(status_code=400, detail="Spend already reviewed")
    acc = db.get(CustodyAccount, spend.account_id)
    if not acc or acc.office_id != user.office_id:
        raise HTTPException(status_code=404, detail="Account not found")
    spend.status = CustodySpendStatus.rejected
    spend.reject_reason = payload.reject_reason
    spend.reviewed_by_user_id = user.id
    spend.reviewed_at = _now()
    db.commit()
    db.refresh(spend)
    return CustodySpendOut(
        id=spend.id,
        user_id=acc.user_id,
        amount=float(spend.amount),
        occurred_at=spend.occurred_at,
        description=spend.description,
        status=spend.status,
        case_id=spend.case_id,
        reject_reason=spend.reject_reason,
        created_at=spend.created_at,
    )


@app.post("/custody/spends/{spend_id}/receipts")
def custody_upload_receipt(
    spend_id: int,
    upload: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(require_perm("custody.spend.create")),
):
    spend = db.get(CustodySpend, spend_id)
    if not spend or spend.office_id != user.office_id:
        raise HTTPException(status_code=404, detail="Spend not found")
    acc = db.get(CustodyAccount, spend.account_id)
    if not acc or acc.office_id != user.office_id:
        raise HTTPException(status_code=404, detail="Account not found")
    # only the owner can upload receipts
    if acc.user_id != user.id and user.role != UserRole.office_owner:
        raise HTTPException(status_code=403, detail="Forbidden")

    _ensure_upload_dir()
    safe_name = os.path.basename(upload.filename or "file")
    ext = Path(safe_name).suffix[:10]
    file_id = uuid4().hex
    rel_path = f"custody/{user.office_id}/{spend_id}/{file_id}{ext}"
    full_path = Path(settings.upload_dir) / rel_path
    full_path.parent.mkdir(parents=True, exist_ok=True)

    data = upload.file.read()
    full_path.write_bytes(data)

    rec = CustodyReceiptFile(
        office_id=user.office_id,
        spend_id=spend_id,
        original_name=safe_name,
        content_type=upload.content_type,
        storage_path=str(full_path),
        size_bytes=len(data),
        uploaded_by_user_id=user.id,
    )
    db.add(rec)
    db.commit()
    return {"ok": True, "id": rec.id, "name": rec.original_name}


@app.get("/custody/spends/{spend_id}/receipts", response_model=list[CustodyReceiptOut])
def custody_list_receipts(spend_id: int, db: Session = Depends(get_db), user: User = Depends(require_perm("custody.admin.view"))):
    spend = db.get(CustodySpend, spend_id)
    if not spend or spend.office_id != user.office_id:
        raise HTTPException(status_code=404, detail="Spend not found")
    items = db.scalars(
        select(CustodyReceiptFile)
        .where(CustodyReceiptFile.office_id == user.office_id, CustodyReceiptFile.spend_id == spend_id)
        .order_by(CustodyReceiptFile.id.desc())
    ).all()
    return [
        CustodyReceiptOut(
            id=f.id,
            spend_id=f.spend_id,
            original_name=f.original_name,
            content_type=f.content_type,
            size_bytes=f.size_bytes,
            uploaded_at=f.uploaded_at,
        )
        for f in items
    ]


@app.get("/custody/receipts/{file_id}")
def custody_download_receipt(file_id: int, db: Session = Depends(get_db), user: User = Depends(require_perm("custody.admin.view"))):
    f = db.get(CustodyReceiptFile, file_id)
    if not f or f.office_id != user.office_id:
        raise HTTPException(status_code=404, detail="File not found")
    path = Path(f.storage_path)
    if not path.exists():
        raise HTTPException(status_code=404, detail="File missing")
    return FileResponse(path, media_type=f.content_type or "application/octet-stream", filename=f.original_name)


@app.post("/office-expenses", response_model=OfficeExpenseOut)
def create_office_expense(payload: OfficeExpenseCreate, db: Session = Depends(get_db), user: User = Depends(require_perm("accounts.read"))):
    exp = OfficeExpense(
        office_id=user.office_id,
        amount=payload.amount,
        description=payload.description,
        occurred_at=payload.occurred_at or _now(),
        created_by_user_id=user.id,
    )
    db.add(exp)
    db.commit()
    db.refresh(exp)
    return OfficeExpenseOut(
        id=exp.id,
        amount=float(exp.amount),
        description=exp.description,
        occurred_at=exp.occurred_at,
        created_by_user_id=exp.created_by_user_id,
        created_at=exp.created_at,
    )


@app.get("/office-expenses", response_model=list[OfficeExpenseOut])
def list_office_expenses(db: Session = Depends(get_db), user: User = Depends(require_perm("accounts.read"))):
    items = db.scalars(
        select(OfficeExpense)
        .where(OfficeExpense.office_id == user.office_id)
        .order_by(OfficeExpense.occurred_at.desc(), OfficeExpense.id.desc())
    ).all()
    return [
        OfficeExpenseOut(
            id=e.id,
            amount=float(e.amount),
            description=e.description,
            occurred_at=e.occurred_at,
            created_by_user_id=e.created_by_user_id,
            created_at=e.created_at,
        )
        for e in items
    ]


@app.post("/office-expenses/{expense_id}/receipts")
def upload_office_expense_receipt(
    expense_id: int,
    upload: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(require_perm("accounts.read")),
):
    exp = db.get(OfficeExpense, expense_id)
    if not exp or exp.office_id != user.office_id:
        raise HTTPException(status_code=404, detail="Expense not found")

    _ensure_upload_dir()
    safe_name = os.path.basename(upload.filename or "file")
    ext = Path(safe_name).suffix[:10]
    file_id = uuid4().hex
    rel_path = f"office-expenses/{user.office_id}/{expense_id}/{file_id}{ext}"
    full_path = Path(settings.upload_dir) / rel_path
    full_path.parent.mkdir(parents=True, exist_ok=True)

    data = upload.file.read()
    full_path.write_bytes(data)

    rec = OfficeExpenseReceiptFile(
        office_id=user.office_id,
        expense_id=expense_id,
        original_name=safe_name,
        content_type=upload.content_type,
        storage_path=str(full_path),
        size_bytes=len(data),
        uploaded_by_user_id=user.id,
    )
    db.add(rec)
    db.commit()
    return {"ok": True, "id": rec.id, "name": rec.original_name}


@app.get("/office-expenses/{expense_id}/receipts", response_model=list[OfficeExpenseReceiptOut])
def list_office_expense_receipts(expense_id: int, db: Session = Depends(get_db), user: User = Depends(require_perm("accounts.read"))):
    exp = db.get(OfficeExpense, expense_id)
    if not exp or exp.office_id != user.office_id:
        raise HTTPException(status_code=404, detail="Expense not found")
    items = db.scalars(
        select(OfficeExpenseReceiptFile)
        .where(OfficeExpenseReceiptFile.office_id == user.office_id, OfficeExpenseReceiptFile.expense_id == expense_id)
        .order_by(OfficeExpenseReceiptFile.id.desc())
    ).all()
    return [
        OfficeExpenseReceiptOut(
            id=f.id,
            expense_id=f.expense_id,
            original_name=f.original_name,
            content_type=f.content_type,
            size_bytes=f.size_bytes,
            uploaded_at=f.uploaded_at,
        )
        for f in items
    ]


@app.get("/office-expense-receipts/{file_id}")
def download_office_expense_receipt(file_id: int, db: Session = Depends(get_db), user: User = Depends(require_perm("accounts.read"))):
    f = db.get(OfficeExpenseReceiptFile, file_id)
    if not f or f.office_id != user.office_id:
        raise HTTPException(status_code=404, detail="File not found")
    path = Path(f.storage_path)
    if not path.exists():
        raise HTTPException(status_code=404, detail="File missing")
    return FileResponse(path, media_type=f.content_type or "application/octet-stream", filename=f.original_name)


@app.get("/reports/client/{client_id}", response_model=ClientAccountReportOut)
def report_client_account(client_id: int, db: Session = Depends(get_db), user: User = Depends(require_perm("accounts.read"))):
    client = db.get(Client, client_id)
    if not client or client.office_id != user.office_id:
        raise HTTPException(status_code=404, detail="Client not found")
    cases = db.scalars(select(Case).where(Case.office_id == user.office_id, Case.client_id == client_id).order_by(Case.id.desc())).all()
    case_ids = [c.id for c in cases]
    income_by_case: dict[int, float] = {}
    if case_ids:
        rows = db.execute(
            select(CaseTransaction.case_id, func.coalesce(func.sum(CaseTransaction.amount), 0))
            .where(
                CaseTransaction.office_id == user.office_id,
                CaseTransaction.case_id.in_(case_ids),
                CaseTransaction.direction == MoneyDirection.income,
            )
            .group_by(CaseTransaction.case_id)
        ).all()
        income_by_case = {int(cid): float(total) for cid, total in rows}

    items: list[ClientCaseAccountReportItem] = []
    for c in cases:
        inc = income_by_case.get(c.id, 0.0)
        fee = float(c.fee_total) if c.fee_total is not None else None
        remaining = None if fee is None else float(fee - inc)
        items.append(
            ClientCaseAccountReportItem(
                case_id=c.id,
                case_title=c.title,
                fee_total=fee,
                income_sum=float(inc),
                remaining=remaining,
            )
        )
    return ClientAccountReportOut(client_id=client.id, client_name=client.full_name, cases=items)


@app.get("/reports/custody", response_model=list[CustodyReportItem])
def report_custody(user_id: int | None = None, db: Session = Depends(get_db), user: User = Depends(require_perm("custody.admin.view"))):
    stmt = select(CustodyAccount, User).join(User, User.id == CustodyAccount.user_id).where(CustodyAccount.office_id == user.office_id)
    if user_id is not None:
        stmt = stmt.where(CustodyAccount.user_id == user_id)
    rows = db.execute(stmt.order_by(CustodyAccount.id.desc())).all()
    if not rows:
        return []
    acc_ids = [acc.id for acc, _ in rows]

    adv_rows = db.execute(
        select(CustodyAdvance.account_id, func.coalesce(func.sum(CustodyAdvance.amount), 0))
        .where(CustodyAdvance.office_id == user.office_id, CustodyAdvance.account_id.in_(acc_ids))
        .group_by(CustodyAdvance.account_id)
    ).all()
    advances_sum = {int(aid): float(total) for aid, total in adv_rows}

    approved_rows = db.execute(
        select(CustodySpend.account_id, func.coalesce(func.sum(CustodySpend.amount), 0))
        .where(
            CustodySpend.office_id == user.office_id,
            CustodySpend.account_id.in_(acc_ids),
            CustodySpend.status == CustodySpendStatus.approved,
        )
        .group_by(CustodySpend.account_id)
    ).all()
    approved_sum = {int(aid): float(total) for aid, total in approved_rows}

    pending_rows = db.execute(
        select(CustodySpend.account_id, func.coalesce(func.sum(CustodySpend.amount), 0))
        .where(
            CustodySpend.office_id == user.office_id,
            CustodySpend.account_id.in_(acc_ids),
            CustodySpend.status == CustodySpendStatus.pending,
        )
        .group_by(CustodySpend.account_id)
    ).all()
    pending_sum = {int(aid): float(total) for aid, total in pending_rows}

    return [
        CustodyReportItem(
            user_id=u.id,
            user_email=u.email,
            current_balance=float(acc.current_balance),
            advances_sum=float(advances_sum.get(acc.id, 0.0)),
            approved_spends_sum=float(approved_sum.get(acc.id, 0.0)),
            pending_spends_sum=float(pending_sum.get(acc.id, 0.0)),
        )
        for acc, u in rows
    ]


@app.get("/billing/status", response_model=SubscriptionOut)
def billing_status(db: Session = Depends(get_db), user: User = Depends(require_office_user)):
    sub = db.scalar(select(Subscription).where(Subscription.office_id == user.office_id).order_by(Subscription.id.desc()))
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")
    return SubscriptionOut(
        id=sub.id,
        office_id=sub.office_id,
        status=sub.status,
        start_at=sub.start_at,
        end_at=sub.end_at,
        plan_name_snapshot=sub.plan_name_snapshot,
        plan_id=getattr(sub, "plan_id", None),
        price_snapshot_cents=sub.price_snapshot_cents,
        notes=sub.notes,
    )


@app.get("/subscription/me", response_model=SubscriptionOut)
def subscription_me(db: Session = Depends(get_db), user: User = Depends(require_office_user)):
    return billing_status(db=db, user=user)


@app.get("/plans", response_model=list[PlanOut])
def list_plans(db: Session = Depends(get_db), _: User = Depends(require_office_user)):
    plans = db.scalars(select(Plan).where(Plan.is_active == True).order_by(Plan.id.asc())).all()  # noqa: E712
    return [
        PlanOut(
            id=p.id,
            name=p.name,
            price_cents=p.price_cents,
            duration_days=p.duration_days,
            instapay_link=getattr(p, "instapay_link", None),
            promo_image_path=getattr(p, "promo_image_path", None),
            package_key=getattr(p, "package_key", None),
            package_name=getattr(p, "package_name", None),
            max_users=getattr(p, "max_users", None),
            allowed_perm_keys=(
                [k.strip() for k in p.allowed_perm_keys_csv.split(",") if k.strip() and k.strip() in PERMISSIONS]
                if getattr(p, "allowed_perm_keys_csv", None)
                else None
            ),
            is_active=getattr(p, "is_active", True),
            created_at=p.created_at,
        )
        for p in plans
    ]


@app.get("/plans/{plan_id}/promo-image")
def download_plan_promo_image(plan_id: int, db: Session = Depends(get_db), user: User = Depends(require_office_user)):
    plan = db.get(Plan, plan_id)
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")
    promo_path = getattr(plan, "promo_image_path", None)
    if not promo_path:
        raise HTTPException(status_code=404, detail="Promo image not found")
    path = Path(promo_path)
    if not path.exists():
        raise HTTPException(status_code=404, detail="Promo image missing")
    return FileResponse(path, media_type="application/octet-stream", filename=path.name)


@app.post("/subscription/payment-proofs", response_model=PaymentProofOut)
def create_payment_proof(
    plan_id: int = Form(...),
    upload: UploadFile = File(...),
    reference_code: str | None = Form(default=None),
    notes: str | None = Form(default=None),
    db: Session = Depends(get_db),
    user: User = Depends(require_office_admin),
):
    plan = db.get(Plan, plan_id)
    if not plan or getattr(plan, "is_active", True) is False:
        raise HTTPException(status_code=404, detail="Plan not found")

    _ensure_upload_dir()
    safe_name = os.path.basename(upload.filename or "file")
    ext = Path(safe_name).suffix[:10]
    file_id = uuid4().hex
    rel_path = f"payment-proofs/{user.office_id}/{file_id}{ext}"
    full_path = Path(settings.upload_dir) / rel_path
    full_path.parent.mkdir(parents=True, exist_ok=True)

    data = upload.file.read()
    full_path.write_bytes(data)

    proof = PaymentProof(
        office_id=user.office_id,
        plan_id=plan.id,
        image_path=str(full_path),
        status=ProofStatus.pending,
        notes=notes,
        amount_snapshot_cents=int(plan.price_cents),
        instapay_link_snapshot=getattr(plan, "instapay_link", None),
        reference_code=reference_code,
    )
    db.add(proof)
    db.commit()
    db.refresh(proof)
    return PaymentProofOut(
        id=proof.id,
        office_id=proof.office_id,
        image_path=proof.image_path,
        plan_id=getattr(proof, "plan_id", None),
        status=proof.status,
        notes=proof.notes,
        amount_snapshot_cents=getattr(proof, "amount_snapshot_cents", None),
        instapay_link_snapshot=getattr(proof, "instapay_link_snapshot", None),
        reference_code=getattr(proof, "reference_code", None),
        reviewed_by_user_id=getattr(proof, "reviewed_by_user_id", None),
        reviewed_at=getattr(proof, "reviewed_at", None),
        decision_notes=getattr(proof, "decision_notes", None),
        uploaded_at=proof.uploaded_at,
    )


@app.get("/subscription/payment-proofs", response_model=list[PaymentProofOut])
def list_payment_proofs(db: Session = Depends(get_db), user: User = Depends(require_office_admin)):
    items = db.scalars(select(PaymentProof).where(PaymentProof.office_id == user.office_id).order_by(PaymentProof.id.desc())).all()
    return [
        PaymentProofOut(
            id=p.id,
            office_id=p.office_id,
            image_path=p.image_path,
            plan_id=getattr(p, "plan_id", None),
            status=p.status,
            notes=p.notes,
            amount_snapshot_cents=getattr(p, "amount_snapshot_cents", None),
            instapay_link_snapshot=getattr(p, "instapay_link_snapshot", None),
            reference_code=getattr(p, "reference_code", None),
            reviewed_by_user_id=getattr(p, "reviewed_by_user_id", None),
            reviewed_at=getattr(p, "reviewed_at", None),
            decision_notes=getattr(p, "decision_notes", None),
            uploaded_at=p.uploaded_at,
        )
        for p in items
    ]


@app.get("/subscription/payment-proofs/{proof_id}")
def download_payment_proof(proof_id: int, db: Session = Depends(get_db), user: User = Depends(require_office_admin)):
    p = db.get(PaymentProof, proof_id)
    if not p or p.office_id != user.office_id:
        raise HTTPException(status_code=404, detail="Proof not found")
    path = Path(p.image_path)
    if not path.exists():
        raise HTTPException(status_code=404, detail="File missing")
    return FileResponse(path, media_type="application/octet-stream", filename=f"payment-proof-{p.id}{path.suffix}")


@app.get("/protected-example")
def protected_example(_: User = Depends(require_active_subscription)):
    return {"ok": True, "message": "subscription ok"}


@app.get("/admin/offices", response_model=list[OfficeOut])
def admin_list_offices(db: Session = Depends(get_db), _: User = Depends(require_super_admin)):
    offices = db.scalars(select(Office).order_by(Office.id.desc())).all()
    return [OfficeOut(id=o.id, code=o.code, name=o.name, status=o.status, created_at=o.created_at) for o in offices]


@app.get("/admin/permissions", response_model=list[PermissionCatalogItem])
def admin_permissions_catalog(_: User = Depends(require_super_admin)):
    return [PermissionCatalogItem(key=k, label=v) for k, v in PERMISSIONS.items()]


@app.get("/admin/analytics/trials", response_model=AdminTrialAnalyticsOut)
def admin_trial_analytics(
    days: int = Query(default=30),
    db: Session = Depends(get_db),
    _: User = Depends(require_super_admin),
):
    # Offices that had `trial` overlapping the last `days` window,
    # with the current active user count per office + active days from tracked UI usage.
    now = _now()
    cutoff = now - timedelta(days=int(days))
    cutoff_date: date = cutoff.date()
    today_date: date = now.date()

    trial_subs = db.scalars(
        select(Subscription)
        .where(Subscription.status == SubscriptionStatus.trial)
        .where(Subscription.start_at <= now)
        .where(Subscription.end_at >= cutoff)
        .order_by(Subscription.office_id.asc(), Subscription.end_at.desc(), Subscription.id.desc())
    ).all()

    # Distinct offices (best-effort): keep the trial record with the latest end_at in the window.
    by_office: dict[int, Subscription] = {}
    for s in trial_subs:
        if s.office_id not in by_office:
            by_office[s.office_id] = s

    office_ids = list(by_office.keys())
    if not office_ids:
        return AdminTrialAnalyticsOut(days=int(days), total_trial_offices=0, offices=[])

    offices = db.scalars(select(Office).where(Office.id.in_(office_ids))).all()
    office_map = {o.id: o for o in offices}

    rows: list = []
    for oid, sub in by_office.items():
        office = office_map.get(oid)
        if not office:
            continue
        active_users = db.scalar(select(func.count(User.id)).where(User.office_id == oid, User.is_active == True))
        active_users_count = int(active_users or 0)

        active_days = db.scalar(
            select(func.count(OfficeActivityDaily.id)).where(
                OfficeActivityDaily.office_id == oid,
                OfficeActivityDaily.activity_date >= cutoff_date,
                OfficeActivityDaily.activity_date <= today_date,
                OfficeActivityDaily.hits > 0,
            )
        )
        active_days_count = int(active_days or 0)
        rows.append(
            AdminTrialOfficeUsersOut(
                office_id=oid,
                office_name=office.name,
                trial_start_at=sub.start_at,
                trial_end_at=sub.end_at,
                active_users_count=active_users_count,
                active_days_count=active_days_count,
            )
        )

    rows.sort(key=lambda r: r.active_users_count, reverse=True)
    return AdminTrialAnalyticsOut(days=int(days), total_trial_offices=len(rows), offices=rows)


@app.get("/admin/analytics/subscriptions", response_model=AdminSubscriptionsAnalyticsOut)
def admin_subscriptions_analytics(
    days: int = Query(default=30),
    db: Session = Depends(get_db),
    _: User = Depends(require_super_admin),
):
    # Active subscriptions overview (latest subscription per office).
    now = _now()
    cutoff = now - timedelta(days=int(days))

    # Get latest subscription row per office by id (best-effort).
    subs = db.scalars(select(Subscription).order_by(Subscription.office_id.asc(), Subscription.id.desc())).all()
    latest_by_office: dict[int, Subscription] = {}
    for s in subs:
        if s.office_id not in latest_by_office:
            latest_by_office[s.office_id] = s

    active = [s for s in latest_by_office.values() if s.status == SubscriptionStatus.active and s.end_at > now]
    total_active = len(active)

    # Group by plan (prefer plan_id, fallback to name snapshot).
    plan_map: dict[str, dict] = {}
    for s in active:
        remaining = max(int((s.end_at - now).days), 0)
        plan_id = getattr(s, "plan_id", None)
        plan_name = s.plan_name_snapshot or "—"
        package_key = None
        if plan_id:
            p = db.get(Plan, int(plan_id))
            if p:
                plan_name = p.package_name or p.name
                package_key = getattr(p, "package_key", None)

        key = f"{plan_id or ''}:{package_key or ''}:{plan_name}"
        if key not in plan_map:
            plan_map[key] = {"plan_id": plan_id, "plan_name": plan_name, "package_key": package_key, "count": 0, "sum_remaining": 0}
        plan_map[key]["count"] += 1
        plan_map[key]["sum_remaining"] += remaining

    by_plan = []
    for v in plan_map.values():
        avg_remaining = int(round(v["sum_remaining"] / max(v["count"], 1)))
        by_plan.append(
            AdminActivePlanSummaryOut(
                plan_id=int(v["plan_id"]) if v["plan_id"] else None,
                plan_name=str(v["plan_name"]),
                plan_package_key=v["package_key"],
                office_count=int(v["count"]),
                avg_remaining_days=avg_remaining,
            )
        )
    by_plan.sort(key=lambda x: x.office_count, reverse=True)

    return AdminSubscriptionsAnalyticsOut(days=int(days), total_active_offices=total_active, by_plan=by_plan)


@app.get("/admin/analytics/subscriptions_series", response_model=AdminSubscriptionsSeriesOut)
def admin_subscriptions_series(
    days: int = Query(default=30, ge=1, le=365),
    db: Session = Depends(get_db),
    _: User = Depends(require_super_admin),
):
    now = _now()
    today = now.date()
    start_day = today - timedelta(days=int(days) - 1)
    days_list = [start_day + timedelta(days=i) for i in range(int(days))]

    counts: list[int] = []
    for d in days_list:
        dt = datetime.combine(d, dt_time.min).replace(tzinfo=getattr(now, "tzinfo", None))
        c = db.scalar(
            select(func.count(func.distinct(Subscription.office_id))).where(
                Subscription.status == SubscriptionStatus.active,
                Subscription.start_at <= dt,
                Subscription.end_at > dt,
            )
        )
        counts.append(int(c or 0))

    max_c = max(counts) if counts else 0
    points = [
        AdminSubscriptionsSeriesPointOut(
            day=d,
            active_offices=c,
            pct_of_max=(0 if max_c <= 0 else int(round((c / max_c) * 100))),
        )
        for d, c in zip(days_list, counts)
    ]
    return AdminSubscriptionsSeriesOut(days=int(days), points=points)


@app.get("/admin/alerts", response_model=AdminAlertsOut)
def admin_alerts(
    db: Session = Depends(get_db),
    _: User = Depends(require_super_admin),
):
    now = _now()
    # trial ending within 3 days (still valid)
    trial_expiring = db.scalar(
        select(func.count(Subscription.id)).where(
            Subscription.status == SubscriptionStatus.trial,
            Subscription.end_at > now,
            Subscription.end_at <= (now + timedelta(days=3)),
        )
    )
    active_expiring = db.scalar(
        select(func.count(Subscription.id)).where(
            Subscription.status == SubscriptionStatus.active,
            Subscription.end_at > now,
            Subscription.end_at <= (now + timedelta(days=7)),
        )
    )
    expired_or_inactive = db.scalar(
        select(func.count(Subscription.id)).where(
            (Subscription.end_at <= now) | (Subscription.status.in_([SubscriptionStatus.expired, SubscriptionStatus.cancelled]))
        )
    )
    return AdminAlertsOut(
        trial_expiring_3d=int(trial_expiring or 0),
        active_expiring_7d=int(active_expiring or 0),
        expired_or_inactive=int(expired_or_inactive or 0),
    )


@app.get("/admin/plans", response_model=list[PlanOut])
def admin_list_plans(db: Session = Depends(get_db), _: User = Depends(require_super_admin)):
    plans = db.scalars(select(Plan).order_by(Plan.id.desc())).all()
    return [
        PlanOut(
            id=p.id,
            name=p.name,
            price_cents=p.price_cents,
            duration_days=p.duration_days,
            instapay_link=getattr(p, "instapay_link", None),
            promo_image_path=getattr(p, "promo_image_path", None),
            package_key=getattr(p, "package_key", None),
            package_name=getattr(p, "package_name", None),
            max_users=getattr(p, "max_users", None),
            allowed_perm_keys=(
                [k.strip() for k in p.allowed_perm_keys_csv.split(",") if k.strip() and k.strip() in PERMISSIONS]
                if getattr(p, "allowed_perm_keys_csv", None)
                else None
            ),
            is_active=getattr(p, "is_active", True),
            created_at=p.created_at,
        )
        for p in plans
    ]


@app.post("/admin/plans/{plan_id}/promo-image")
def admin_upload_plan_promo_image(
    plan_id: int,
    upload: UploadFile = File(...),
    db: Session = Depends(get_db),
    _: User = Depends(require_super_admin),
):
    plan = db.get(Plan, plan_id)
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")

    _ensure_upload_dir()
    safe_name = os.path.basename(upload.filename or "file")
    ext = Path(safe_name).suffix[:10]
    file_id = uuid4().hex
    rel_path = f"plan-promos/{plan_id}/{file_id}{ext}"
    full_path = Path(settings.upload_dir) / rel_path
    full_path.parent.mkdir(parents=True, exist_ok=True)

    data = upload.file.read()
    full_path.write_bytes(data)

    plan.promo_image_path = str(full_path)
    db.commit()
    return {"ok": True, "id": plan_id}


@app.get("/admin/plans/{plan_id}/promo-image")
def admin_download_plan_promo_image(
    plan_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_super_admin),
):
    plan = db.get(Plan, plan_id)
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")
    promo_path = getattr(plan, "promo_image_path", None)
    if not promo_path:
        raise HTTPException(status_code=404, detail="Promo image not found")
    path = Path(promo_path)
    if not path.exists():
        raise HTTPException(status_code=404, detail="Promo image missing")
    return FileResponse(path, media_type="application/octet-stream", filename=path.name)


@app.get("/admin/payment-proofs", response_model=list[PaymentProofOut])
def admin_list_payment_proofs(
    status: ProofStatus | None = Query(default=None),
    office_id: int | None = Query(default=None),
    db: Session = Depends(get_db),
    _: User = Depends(require_super_admin),
):
    stmt = select(PaymentProof)
    if status is not None:
        stmt = stmt.where(PaymentProof.status == status)
    if office_id is not None:
        stmt = stmt.where(PaymentProof.office_id == office_id)
    items = db.scalars(stmt.order_by(PaymentProof.uploaded_at.desc(), PaymentProof.id.desc())).all()
    return [
        PaymentProofOut(
            id=p.id,
            office_id=p.office_id,
            image_path=p.image_path,
            plan_id=getattr(p, "plan_id", None),
            status=p.status,
            notes=p.notes,
            amount_snapshot_cents=getattr(p, "amount_snapshot_cents", None),
            instapay_link_snapshot=getattr(p, "instapay_link_snapshot", None),
            reference_code=getattr(p, "reference_code", None),
            reviewed_by_user_id=getattr(p, "reviewed_by_user_id", None),
            reviewed_at=getattr(p, "reviewed_at", None),
            decision_notes=getattr(p, "decision_notes", None),
            uploaded_at=p.uploaded_at,
        )
        for p in items
    ]


@app.get("/admin/payment-proofs/{proof_id}")
def admin_download_payment_proof(proof_id: int, db: Session = Depends(get_db), _: User = Depends(require_super_admin)):
    p = db.get(PaymentProof, proof_id)
    if not p:
        raise HTTPException(status_code=404, detail="Proof not found")
    path = Path(p.image_path)
    if not path.exists():
        raise HTTPException(status_code=404, detail="File missing")
    return FileResponse(path, media_type="application/octet-stream", filename=f"payment-proof-{p.id}{path.suffix}")


@app.post("/admin/payment-proofs/{proof_id}/approve", response_model=PaymentProofOut)
def admin_approve_payment_proof(
    proof_id: int,
    payload: AdminReviewPaymentProofRequest,
    db: Session = Depends(get_db),
    admin: User = Depends(require_super_admin),
):
    proof = db.get(PaymentProof, proof_id)
    if not proof:
        raise HTTPException(status_code=404, detail="Proof not found")
    if proof.status != ProofStatus.pending:
        raise HTTPException(status_code=400, detail="Proof already reviewed")
    if not getattr(proof, "plan_id", None):
        raise HTTPException(status_code=400, detail="Proof missing plan")
    plan = db.get(Plan, int(proof.plan_id))
    if not plan:
        raise HTTPException(status_code=400, detail="Plan not found")

    now = _now()
    latest = db.scalar(select(Subscription).where(Subscription.office_id == proof.office_id).order_by(Subscription.id.desc()))
    if latest and latest.status in (SubscriptionStatus.trial, SubscriptionStatus.active) and latest.end_at > now:
        start_at = latest.end_at
    else:
        start_at = now
    end_at = start_at + timedelta(days=int(plan.duration_days))

    # Record subscription snapshot.
    sub = Subscription(
        office_id=proof.office_id,
        status=SubscriptionStatus.active,
        start_at=start_at,
        end_at=end_at,
        price_snapshot_cents=int(plan.price_cents),
        plan_name_snapshot=plan.name,
        plan_id=plan.id,
        notes=f"proof:{proof.id}",
    )
    db.add(sub)

    proof.status = ProofStatus.approved
    proof.reviewed_by_user_id = admin.id
    proof.reviewed_at = now
    proof.decision_notes = payload.decision_notes

    # Enforce module/user restrictions immediately after approval.
    max_users_total = int(getattr(plan, "max_users", None) or 0) or 10_000
    allowed_perm_keys: set[str]
    if getattr(plan, "allowed_perm_keys_csv", None):
        allowed_perm_keys = {k.strip() for k in plan.allowed_perm_keys_csv.split(",") if k.strip() and k.strip() in PERMISSIONS}
    else:
        allowed_perm_keys = set(PERMISSIONS.keys())

    allowed_staff_count = max(max_users_total - 1, 0)
    staff_users = db.scalars(
        select(User).where(
            User.office_id == proof.office_id,
            User.role == UserRole.staff,
            User.is_active == True,
        ).order_by(User.id.asc())
    ).all()
    if len(staff_users) > allowed_staff_count:
        to_disable = [u.id for u in staff_users[allowed_staff_count:]]
        db.query(User).where(User.id.in_(to_disable)).update({"is_active": False}, synchronize_session=False)
        db.query(UserPermission).where(
            UserPermission.office_id == proof.office_id,
            UserPermission.user_id.in_(to_disable),
        ).delete(synchronize_session=False)

    # Prune permissions for remaining staff so they can't see/edit disallowed modules in the UI.
    keep_staff_ids = [u.id for u in staff_users[:allowed_staff_count]]
    if keep_staff_ids and allowed_perm_keys != set(PERMISSIONS.keys()):
        db.query(UserPermission).where(
            UserPermission.office_id == proof.office_id,
            UserPermission.user_id.in_(keep_staff_ids),
        ).filter(~UserPermission.perm_key.in_(allowed_perm_keys)).delete(synchronize_session=False)

    db.commit()
    db.refresh(proof)
    return PaymentProofOut(
        id=proof.id,
        office_id=proof.office_id,
        image_path=proof.image_path,
        plan_id=getattr(proof, "plan_id", None),
        status=proof.status,
        notes=proof.notes,
        amount_snapshot_cents=getattr(proof, "amount_snapshot_cents", None),
        instapay_link_snapshot=getattr(proof, "instapay_link_snapshot", None),
        reference_code=getattr(proof, "reference_code", None),
        reviewed_by_user_id=getattr(proof, "reviewed_by_user_id", None),
        reviewed_at=getattr(proof, "reviewed_at", None),
        decision_notes=getattr(proof, "decision_notes", None),
        uploaded_at=proof.uploaded_at,
    )


@app.post("/admin/payment-proofs/{proof_id}/reject", response_model=PaymentProofOut)
def admin_reject_payment_proof(
    proof_id: int,
    payload: AdminReviewPaymentProofRequest,
    db: Session = Depends(get_db),
    admin: User = Depends(require_super_admin),
):
    proof = db.get(PaymentProof, proof_id)
    if not proof:
        raise HTTPException(status_code=404, detail="Proof not found")
    if proof.status != ProofStatus.pending:
        raise HTTPException(status_code=400, detail="Proof already reviewed")
    now = _now()
    proof.status = ProofStatus.rejected
    proof.reviewed_by_user_id = admin.id
    proof.reviewed_at = now
    proof.decision_notes = payload.decision_notes
    db.commit()
    db.refresh(proof)
    return PaymentProofOut(
        id=proof.id,
        office_id=proof.office_id,
        image_path=proof.image_path,
        plan_id=getattr(proof, "plan_id", None),
        status=proof.status,
        notes=proof.notes,
        amount_snapshot_cents=getattr(proof, "amount_snapshot_cents", None),
        instapay_link_snapshot=getattr(proof, "instapay_link_snapshot", None),
        reference_code=getattr(proof, "reference_code", None),
        reviewed_by_user_id=getattr(proof, "reviewed_by_user_id", None),
        reviewed_at=getattr(proof, "reviewed_at", None),
        decision_notes=getattr(proof, "decision_notes", None),
        uploaded_at=proof.uploaded_at,
    )


@app.post("/admin/plans", response_model=PlanOut)
def admin_create_plan(payload: PlanCreate, db: Session = Depends(get_db), _: User = Depends(require_super_admin)):
    existing = db.scalar(select(Plan).where(Plan.name == payload.name.strip()))
    if existing:
        raise HTTPException(status_code=400, detail="Plan name already exists")

    allowed_perm_keys_csv: str | None = None
    if payload.allowed_perm_keys is not None:
        invalid = [k for k in payload.allowed_perm_keys if k not in PERMISSIONS]
        if invalid:
            raise HTTPException(status_code=400, detail=f"Invalid permission keys: {', '.join(invalid)}")
        allowed_perm_keys_csv = ",".join(sorted(set(payload.allowed_perm_keys)))

    p = Plan(
        name=payload.name.strip(),
        price_cents=int(payload.price_cents),
        duration_days=int(payload.duration_days),
        instapay_link=(payload.instapay_link.strip() if payload.instapay_link else None),
        package_key=(payload.package_key.strip() if payload.package_key else None),
        package_name=(payload.package_name.strip() if payload.package_name else None),
        max_users=int(payload.max_users) if payload.max_users is not None else None,
        allowed_perm_keys_csv=allowed_perm_keys_csv,
        is_active=bool(payload.is_active),
    )
    db.add(p)
    db.commit()
    db.refresh(p)
    return PlanOut(
        id=p.id,
        name=p.name,
        price_cents=p.price_cents,
        duration_days=p.duration_days,
        instapay_link=getattr(p, "instapay_link", None),
        package_key=getattr(p, "package_key", None),
        package_name=getattr(p, "package_name", None),
        max_users=getattr(p, "max_users", None),
        allowed_perm_keys=(
            [k.strip() for k in p.allowed_perm_keys_csv.split(",") if k.strip() and k.strip() in PERMISSIONS]
            if getattr(p, "allowed_perm_keys_csv", None)
            else None
        ),
        is_active=getattr(p, "is_active", True),
        created_at=p.created_at,
    )


@app.put("/admin/plans/{plan_id}", response_model=PlanOut)
def admin_update_plan(plan_id: int, payload: PlanUpdate, db: Session = Depends(get_db), _: User = Depends(require_super_admin)):
    p = db.get(Plan, plan_id)
    if not p:
        raise HTTPException(status_code=404, detail="Plan not found")
    if payload.name is not None:
        name = payload.name.strip()
        existing = db.scalar(select(Plan).where(Plan.name == name))
        if existing and existing.id != p.id:
            raise HTTPException(status_code=400, detail="Plan name already exists")
        p.name = name
    if payload.price_cents is not None:
        p.price_cents = int(payload.price_cents)
    if payload.duration_days is not None:
        p.duration_days = int(payload.duration_days)
    if payload.instapay_link is not None:
        p.instapay_link = payload.instapay_link.strip() if payload.instapay_link else None
    if payload.package_key is not None:
        p.package_key = payload.package_key.strip() if payload.package_key else None
    if payload.package_name is not None:
        p.package_name = payload.package_name.strip() if payload.package_name else None
    if payload.max_users is not None:
        p.max_users = int(payload.max_users) if payload.max_users is not None else None
    if payload.allowed_perm_keys is not None:
        invalid = [k for k in payload.allowed_perm_keys if k not in PERMISSIONS]
        if invalid:
            raise HTTPException(status_code=400, detail=f"Invalid permission keys: {', '.join(invalid)}")
        p.allowed_perm_keys_csv = ",".join(sorted(set(payload.allowed_perm_keys)))
    if payload.is_active is not None:
        p.is_active = bool(payload.is_active)
    db.commit()
    db.refresh(p)
    return PlanOut(
        id=p.id,
        name=p.name,
        price_cents=p.price_cents,
        duration_days=p.duration_days,
        instapay_link=getattr(p, "instapay_link", None),
        package_key=getattr(p, "package_key", None),
        package_name=getattr(p, "package_name", None),
        max_users=getattr(p, "max_users", None),
        allowed_perm_keys=(
            [k.strip() for k in p.allowed_perm_keys_csv.split(",") if k.strip() and k.strip() in PERMISSIONS]
            if getattr(p, "allowed_perm_keys_csv", None)
            else None
        ),
        is_active=getattr(p, "is_active", True),
        created_at=p.created_at,
    )


@app.delete("/admin/plans/{plan_id}", response_model=PlanOut)
def admin_delete_plan(plan_id: int, db: Session = Depends(get_db), _: User = Depends(require_super_admin)):
    p = db.get(Plan, plan_id)
    if not p:
        raise HTTPException(status_code=404, detail="Plan not found")
    # Soft delete: keep history stable for existing subscriptions/proofs.
    p.is_active = False
    db.commit()
    db.refresh(p)
    return PlanOut(
        id=p.id,
        name=p.name,
        price_cents=p.price_cents,
        duration_days=p.duration_days,
        instapay_link=getattr(p, "instapay_link", None),
        package_key=getattr(p, "package_key", None),
        package_name=getattr(p, "package_name", None),
        max_users=getattr(p, "max_users", None),
        allowed_perm_keys=(
            [k.strip() for k in p.allowed_perm_keys_csv.split(",") if k.strip() and k.strip() in PERMISSIONS]
            if getattr(p, "allowed_perm_keys_csv", None)
            else None
        ),
        is_active=getattr(p, "is_active", True),
        created_at=p.created_at,
    )


@app.get("/admin/super-admins", response_model=list[AdminSuperAdminOut])
def admin_list_super_admins(db: Session = Depends(get_db), _: User = Depends(require_super_admin)):
    items = db.scalars(select(User).where(User.role == UserRole.super_admin).order_by(User.id.asc())).all()
    return [
        AdminSuperAdminOut(
            id=u.id,
            full_name=getattr(u, "full_name", None),
            email=u.email,
            is_active=getattr(u, "is_active", True),
            created_at=u.created_at,
        )
        for u in items
    ]


@app.post("/admin/super-admins", response_model=AdminSuperAdminOut)
def admin_create_super_admin(payload: AdminSuperAdminCreate, db: Session = Depends(get_db), _: User = Depends(require_super_admin)):
    existing = db.scalar(select(User).where(User.email == payload.email))
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")
    u = User(
        office_id=None,
        email=payload.email.strip(),
        password_hash=hash_password(payload.password),
        full_name=payload.full_name.strip(),
        is_active=True,
        role=UserRole.super_admin,
    )
    db.add(u)
    db.commit()
    db.refresh(u)
    return AdminSuperAdminOut(
        id=u.id,
        full_name=getattr(u, "full_name", None),
        email=u.email,
        is_active=getattr(u, "is_active", True),
        created_at=u.created_at,
    )


@app.delete("/admin/super-admins/{user_id}")
def admin_disable_super_admin(user_id: int, db: Session = Depends(get_db), admin: User = Depends(require_super_admin)):
    target = db.get(User, user_id)
    if not target or target.role != UserRole.super_admin:
        raise HTTPException(status_code=404, detail="User not found")
    if target.id == admin.id:
        raise HTTPException(status_code=400, detail="Cannot disable yourself")
    target.is_active = False
    db.commit()
    return {"ok": True}


@app.put("/admin/me/credentials", response_model=AdminSuperAdminOut)
def admin_update_my_credentials(payload: AdminUpdateMyCredentials, db: Session = Depends(get_db), admin: User = Depends(require_super_admin)):
    if not verify_password(payload.current_password, admin.password_hash):
        raise HTTPException(status_code=400, detail="Invalid credentials")
    if payload.new_email is not None:
        existing = db.scalar(select(User).where(User.email == payload.new_email))
        if existing and existing.id != admin.id:
            raise HTTPException(status_code=400, detail="Email already registered")
        admin.email = payload.new_email.strip()
    if payload.new_password is not None:
        admin.password_hash = hash_password(payload.new_password)
    db.commit()
    db.refresh(admin)
    return AdminSuperAdminOut(
        id=admin.id,
        full_name=getattr(admin, "full_name", None),
        email=admin.email,
        is_active=getattr(admin, "is_active", True),
        created_at=admin.created_at,
    )


@app.get("/admin/offices/{office_id}/subscription", response_model=SubscriptionOut)
def admin_get_subscription(office_id: int, db: Session = Depends(get_db), _: User = Depends(require_super_admin)):
    sub = db.scalar(select(Subscription).where(Subscription.office_id == office_id).order_by(Subscription.id.desc()))
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")
    return SubscriptionOut(
        id=sub.id,
        office_id=sub.office_id,
        status=sub.status,
        start_at=sub.start_at,
        end_at=sub.end_at,
        plan_name_snapshot=sub.plan_name_snapshot,
        plan_id=getattr(sub, "plan_id", None),
        price_snapshot_cents=sub.price_snapshot_cents,
        notes=sub.notes,
    )


@app.put("/admin/offices/{office_id}/trial", response_model=SubscriptionOut)
def admin_update_trial(
    office_id: int,
    payload: AdminUpdateTrialRequest,
    db: Session = Depends(get_db),
    _: User = Depends(require_super_admin),
):
    sub = db.scalar(select(Subscription).where(Subscription.office_id == office_id).order_by(Subscription.id.desc()))
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")
    if sub.status not in (SubscriptionStatus.trial, SubscriptionStatus.active):
        raise HTTPException(status_code=400, detail="Cannot update trial for this subscription state")
    if payload.trial_end_at <= _now():
        raise HTTPException(status_code=400, detail="trial_end_at must be in the future")
    sub.end_at = payload.trial_end_at
    if payload.notes is not None:
        sub.notes = payload.notes
    db.commit()
    db.refresh(sub)
    return SubscriptionOut(
        id=sub.id,
        office_id=sub.office_id,
        status=sub.status,
        start_at=sub.start_at,
        end_at=sub.end_at,
        plan_name_snapshot=sub.plan_name_snapshot,
        plan_id=getattr(sub, "plan_id", None),
        price_snapshot_cents=sub.price_snapshot_cents,
        notes=sub.notes,
    )

