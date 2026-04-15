import secrets
import string
import time
from datetime import datetime, timedelta, timezone

from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import select
from sqlalchemy.orm import Session
from sqlalchemy.exc import OperationalError

from app.db import Base, engine, get_db
from app.models import Office, OfficeStatus, Subscription, SubscriptionStatus, User, UserRole
from app.schemas import (
    AdminUpdateTrialRequest,
    LoginRequest,
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


@app.on_event("startup")
def _startup():
    init_db()
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

