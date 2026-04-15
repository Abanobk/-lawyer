from datetime import datetime

from pydantic import BaseModel, EmailStr, Field

from app.models import OfficeStatus, ProofStatus, SubscriptionStatus, UserRole


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class SignupRequest(BaseModel):
    office_name: str = Field(min_length=2, max_length=200)
    email: EmailStr
    password: str = Field(min_length=8, max_length=200)


class SignupResponse(BaseModel):
    office_code: str
    office_link: str
    trial_end_at: datetime
    tokens: TokenPair


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1)


class OfficeOut(BaseModel):
    id: int
    code: str
    name: str
    status: OfficeStatus
    created_at: datetime


class UserOut(BaseModel):
    id: int
    email: EmailStr
    role: UserRole
    office_id: int | None
    created_at: datetime


class SubscriptionOut(BaseModel):
    id: int
    office_id: int
    status: SubscriptionStatus
    start_at: datetime
    end_at: datetime
    plan_name_snapshot: str | None
    price_snapshot_cents: int | None
    notes: str | None


class AdminUpdateTrialRequest(BaseModel):
    trial_end_at: datetime
    notes: str | None = None


class PaymentProofOut(BaseModel):
    id: int
    office_id: int
    image_path: str
    status: ProofStatus
    notes: str | None
    uploaded_at: datetime

