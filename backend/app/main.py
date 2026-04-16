import os
import secrets
import string
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from uuid import uuid4

from fastapi import Depends, FastAPI, HTTPException, UploadFile, File, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import select
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
    MoneyDirection,
    Office,
    OfficeStatus,
    Subscription,
    SubscriptionStatus,
    User,
    UserRole,
)
from app.schemas import (
    AdminUpdateTrialRequest,
    CaseCreate,
    CaseOut,
    CaseTransactionCreate,
    CaseTransactionOut,
    ClientCreate,
    ClientOut,
    LoginRequest,
    OfficeUserOut,
    OfficeOut,
    SignupRequest,
    SignupResponse,
    SubscriptionOut,
    TokenPair,
    UserOut,
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
    deadline = time.time() + max_wait_seconds
    last_err: Exception | None = None

    while time.time() < deadline:
        try:
            Base.metadata.create_all(bind=engine)
            return
        except OperationalError as e:
            last_err = e
            time.sleep(1)

    raise RuntimeError("DB not ready after retries") from last_err


def _ensure_upload_dir() -> None:
    Path(settings.upload_dir).mkdir(parents=True, exist_ok=True)


@app.on_event("startup")
def _startup():
    init_db()
    _ensure_upload_dir()
    # Ensure super admin exists
    with Session(engine) as db:
        existing = db.scalar(select(User).where(User.email == settings.super_admin_email))
        if existing:
            return
        db.add(
            User(
                email=settings.super_admin_email,
                password_hash=hash_password(settings.super_admin_password),
                role=UserRole.super_admin,
                office_id=None,
            )
        )
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
    if sub.status not in (SubscriptionStatus.trial, SubscriptionStatus.active):
        raise HTTPException(status_code=status.HTTP_402_PAYMENT_REQUIRED, detail="Subscription inactive")
    return user


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
    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=400, detail="Invalid credentials")

    access = create_access_token(subject=str(user.id), extra={"uid": user.id, "role": user.role, "office_id": user.office_id})
    refresh = create_refresh_token(subject=str(user.id), extra={"uid": user.id, "role": user.role, "office_id": user.office_id})
    return TokenPair(access_token=access, refresh_token=refresh)


@app.get("/me", response_model=UserOut)
def me(user: User = Depends(current_user)):
    return UserOut(id=user.id, email=user.email, role=user.role, office_id=user.office_id, created_at=user.created_at)


@app.get("/office", response_model=OfficeOut)
def my_office(db: Session = Depends(get_db), user: User = Depends(require_office_user)):
    office = db.get(Office, user.office_id)
    if not office:
        raise HTTPException(status_code=404, detail="Office not found")
    return OfficeOut(id=office.id, code=office.code, name=office.name, status=office.status, created_at=office.created_at)


@app.get("/office/users", response_model=list[OfficeUserOut])
def office_users(db: Session = Depends(get_db), user: User = Depends(require_office_user)):
    users = db.scalars(select(User).where(User.office_id == user.office_id).order_by(User.id.asc())).all()
    return [OfficeUserOut(id=u.id, email=u.email, role=u.role, created_at=u.created_at) for u in users]


@app.get("/clients", response_model=list[ClientOut])
def list_clients(db: Session = Depends(get_db), user: User = Depends(require_active_subscription)):
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
def create_client(payload: ClientCreate, db: Session = Depends(get_db), user: User = Depends(require_active_subscription)):
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


@app.get("/cases", response_model=list[CaseOut])
def list_cases(db: Session = Depends(get_db), user: User = Depends(require_active_subscription)):
    rows = db.execute(
        select(Case, Client)
        .join(Client, Client.id == Case.client_id)
        .where(Case.office_id == user.office_id)
        .order_by(Case.id.desc())
    ).all()

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
        out.append(
            CaseOut(
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
                primary_lawyer_user_id=u.id if u else None,
                primary_lawyer_email=u.email if u else None,
                created_at=case.created_at,
            )
        )
    return out


@app.post("/cases", response_model=CaseOut)
def create_case(payload: CaseCreate, db: Session = Depends(get_db), user: User = Depends(require_active_subscription)):
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
    user: User = Depends(require_active_subscription),
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


@app.get("/cases/{case_id}/transactions", response_model=list[CaseTransactionOut])
def list_case_transactions(case_id: int, db: Session = Depends(get_db), user: User = Depends(require_active_subscription)):
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


@app.post("/transactions", response_model=CaseTransactionOut)
def create_transaction(payload: CaseTransactionCreate, db: Session = Depends(get_db), user: User = Depends(require_active_subscription)):
    case = db.get(Case, payload.case_id)
    if not case or case.office_id != user.office_id:
        raise HTTPException(status_code=404, detail="Case not found")
    t = CaseTransaction(
        office_id=user.office_id,
        case_id=payload.case_id,
        direction=payload.direction,
        amount=payload.amount,
        description=payload.description,
        occurred_at=payload.occurred_at,
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
        price_snapshot_cents=sub.price_snapshot_cents,
        notes=sub.notes,
    )


@app.get("/protected-example")
def protected_example(_: User = Depends(require_active_subscription)):
    return {"ok": True, "message": "subscription ok"}


@app.get("/admin/offices", response_model=list[OfficeOut])
def admin_list_offices(db: Session = Depends(get_db), _: User = Depends(require_super_admin)):
    offices = db.scalars(select(Office).order_by(Office.id.desc())).all()
    return [OfficeOut(id=o.id, code=o.code, name=o.name, status=o.status, created_at=o.created_at) for o in offices]


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
        price_snapshot_cents=sub.price_snapshot_cents,
        notes=sub.notes,
    )

