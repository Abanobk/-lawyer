from datetime import datetime

from pydantic import BaseModel, EmailStr, Field

from app.models import CaseKind, CustodySpendStatus, MoneyDirection, OfficeStatus, ProofStatus, SubscriptionStatus, UserRole


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
    full_name: str | None = None
    is_active: bool = True
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


class OfficeUserOut(BaseModel):
    id: int
    email: EmailStr
    full_name: str | None = None
    is_active: bool = True
    role: UserRole
    created_at: datetime


class OfficeUserCreate(BaseModel):
    full_name: str = Field(min_length=2, max_length=200)
    email: EmailStr
    password: str = Field(min_length=8, max_length=200)


class OfficeUserCreateOut(BaseModel):
    id: int
    email: EmailStr
    full_name: str | None = None
    is_active: bool = True
    role: UserRole


class PermissionCatalogItem(BaseModel):
    key: str
    label: str


class UserPermissionsOut(BaseModel):
    user_id: int
    permissions: list[str]


class UserPermissionsUpdate(BaseModel):
    permissions: list[str]


class ClientCreate(BaseModel):
    full_name: str = Field(min_length=2, max_length=200)
    phone: str | None = Field(default=None, max_length=50)
    national_id: str | None = Field(default=None, max_length=50)
    address: str | None = Field(default=None, max_length=500)
    notes: str | None = None


class ClientOut(BaseModel):
    id: int
    full_name: str
    phone: str | None
    national_id: str | None
    address: str | None
    notes: str | None
    created_at: datetime


class CaseCreate(BaseModel):
    client_id: int
    title: str = Field(min_length=2, max_length=200)
    kind: CaseKind = CaseKind.other
    court: str | None = Field(default=None, max_length=200)
    case_number: str | None = Field(default=None, max_length=100)
    case_year: int | None = None
    first_hearing_at: datetime | None = None
    fee_total: float | None = None
    primary_lawyer_user_id: int | None = None
    first_session_number: str | None = Field(default=None, max_length=50)
    first_session_year: int | None = None


class CaseOut(BaseModel):
    id: int
    client_id: int
    client_name: str
    title: str
    kind: CaseKind
    court: str | None
    case_number: str | None
    case_year: int | None
    first_hearing_at: datetime | None
    fee_total: float | None
    is_active: bool
    primary_lawyer_user_id: int | None
    primary_lawyer_email: str | None
    created_at: datetime


class CaseFileOut(BaseModel):
    id: int
    case_id: int
    original_name: str
    content_type: str | None
    size_bytes: int
    uploaded_at: datetime


class CaseTransactionCreate(BaseModel):
    case_id: int
    direction: MoneyDirection
    amount: float = Field(gt=0)
    description: str | None = Field(default=None, max_length=300)
    occurred_at: datetime


class CaseTransactionOut(BaseModel):
    id: int
    case_id: int
    direction: MoneyDirection
    amount: float
    description: str | None
    occurred_at: datetime
    created_at: datetime


class SessionOut(BaseModel):
    id: int
    case_id: int
    case_title: str
    client_name: str
    session_number: str | None
    session_year: int | None
    session_date: datetime
    notes: str | None
    created_at: datetime


class SessionUpdate(BaseModel):
    session_date: datetime | None = None
    session_number: str | None = Field(default=None, max_length=50)
    session_year: int | None = None
    notes: str | None = None


class CustodyAccountOut(BaseModel):
    id: int
    user_id: int
    user_email: EmailStr
    current_balance: float
    created_at: datetime


class CustodyAccountCreate(BaseModel):
    user_id: int
    # Initial amount that the office sets as the required custody for this employee.
    # If provided, backend will create an advance and increase current_balance.
    initial_amount: float | None = Field(default=None, gt=0)


class CustodyAdvanceCreate(BaseModel):
    user_id: int
    amount: float = Field(gt=0)
    occurred_at: datetime
    notes: str | None = Field(default=None, max_length=500)


class CustodySpendCreate(BaseModel):
    amount: float = Field(gt=0)
    occurred_at: datetime
    description: str | None = Field(default=None, max_length=500)
    case_id: int | None = None


class CustodySpendOut(BaseModel):
    id: int
    user_id: int
    amount: float
    occurred_at: datetime
    description: str | None
    status: CustodySpendStatus
    case_id: int | None
    reject_reason: str | None
    created_at: datetime


class CustodyReviewRequest(BaseModel):
    reject_reason: str | None = Field(default=None, max_length=500)


class CustodyReceiptOut(BaseModel):
    id: int
    spend_id: int
    original_name: str
    content_type: str | None
    size_bytes: int
    uploaded_at: datetime

