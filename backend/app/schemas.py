from datetime import datetime, date

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


class PlanOut(BaseModel):
    id: int
    name: str
    price_cents: int
    duration_days: int
    instapay_link: str | None = None
    promo_image_path: str | None = None
    package_key: str | None = None
    package_name: str | None = None
    max_users: int | None = None
    allowed_perm_keys: list[str] | None = None
    is_active: bool = True
    created_at: datetime


class PlanCreate(BaseModel):
    name: str = Field(min_length=2, max_length=100)
    price_cents: int = Field(gt=0)
    duration_days: int = Field(gt=0)
    instapay_link: str | None = Field(default=None, max_length=800)
    package_key: str | None = Field(default=None, max_length=80)
    package_name: str | None = Field(default=None, max_length=200)
    max_users: int | None = Field(default=None, gt=0)
    allowed_perm_keys: list[str] | None = None
    is_active: bool = True


class PlanUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=100)
    price_cents: int | None = Field(default=None, gt=0)
    duration_days: int | None = Field(default=None, gt=0)
    instapay_link: str | None = Field(default=None, max_length=800)
    package_key: str | None = Field(default=None, max_length=80)
    package_name: str | None = Field(default=None, max_length=200)
    max_users: int | None = Field(default=None, gt=0)
    allowed_perm_keys: list[str] | None = None
    is_active: bool | None = None


class SubscriptionOut(BaseModel):
    id: int
    office_id: int
    status: SubscriptionStatus
    start_at: datetime
    end_at: datetime
    plan_name_snapshot: str | None
    plan_id: int | None = None
    price_snapshot_cents: int | None
    notes: str | None


class AdminUpdateTrialRequest(BaseModel):
    trial_end_at: datetime
    notes: str | None = None


class AdminSuperAdminCreate(BaseModel):
    full_name: str = Field(min_length=2, max_length=200)
    email: EmailStr
    password: str = Field(min_length=8, max_length=200)


class AdminSuperAdminOut(BaseModel):
    id: int
    full_name: str | None
    email: EmailStr
    is_active: bool
    created_at: datetime


class AdminUpdateMyCredentials(BaseModel):
    current_password: str = Field(min_length=1, max_length=200)
    new_email: EmailStr | None = None
    new_password: str | None = Field(default=None, min_length=8, max_length=200)


class AdminReviewPaymentProofRequest(BaseModel):
    decision_notes: str | None = Field(default=None, max_length=2000)


class AdminTrialOfficeUsersOut(BaseModel):
    office_id: int
    office_name: str
    trial_start_at: datetime
    trial_end_at: datetime
    active_users_count: int
    active_days_count: int = 0


class AdminTrialAnalyticsOut(BaseModel):
    days: int
    total_trial_offices: int
    offices: list[AdminTrialOfficeUsersOut]


class AdminActivePlanSummaryOut(BaseModel):
    plan_id: int | None = None
    plan_name: str
    plan_package_key: str | None = None
    office_count: int
    avg_remaining_days: int


class AdminSubscriptionsAnalyticsOut(BaseModel):
    days: int
    total_active_offices: int
    by_plan: list[AdminActivePlanSummaryOut]


class AdminSubscriptionsSeriesPointOut(BaseModel):
    day: date
    active_offices: int
    pct_of_max: int


class AdminSubscriptionsSeriesOut(BaseModel):
    days: int
    points: list[AdminSubscriptionsSeriesPointOut]


class AdminAlertsOut(BaseModel):
    trial_expiring_3d: int
    active_expiring_7d: int
    expired_or_inactive: int


class PaymentProofOut(BaseModel):
    id: int
    office_id: int
    image_path: str
    plan_id: int | None = None
    status: ProofStatus
    notes: str | None
    amount_snapshot_cents: int | None = None
    instapay_link_snapshot: str | None = None
    reference_code: str | None = None
    reviewed_by_user_id: int | None = None
    reviewed_at: datetime | None = None
    decision_notes: str | None = None
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
    occurred_at: datetime | None = None


class CaseTransactionOut(BaseModel):
    id: int
    case_id: int
    direction: MoneyDirection
    amount: float
    description: str | None
    occurred_at: datetime
    created_at: datetime


class CaseTransactionUpdate(BaseModel):
    direction: MoneyDirection | None = None
    amount: float | None = Field(default=None, gt=0)
    description: str | None = Field(default=None, max_length=300)
    occurred_at: datetime | None = None


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


class SessionCreate(BaseModel):
    case_id: int
    session_date: datetime
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
    occurred_at: datetime | None = None
    notes: str | None = Field(default=None, max_length=500)


class CustodySpendCreate(BaseModel):
    amount: float = Field(gt=0)
    occurred_at: datetime | None = None
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


class CustodyLedgerEntryOut(BaseModel):
    kind: str  # "advance" | "spend"
    amount: float
    occurred_at: datetime
    description: str | None = None
    status: CustodySpendStatus | None = None
    spend_id: int | None = None


class OfficeExpenseCreate(BaseModel):
    amount: float = Field(gt=0)
    description: str | None = Field(default=None, max_length=500)
    occurred_at: datetime | None = None


class OfficeExpenseOut(BaseModel):
    id: int
    amount: float
    description: str | None
    occurred_at: datetime
    created_by_user_id: int | None
    created_at: datetime


class OfficeExpenseReceiptOut(BaseModel):
    id: int
    expense_id: int
    original_name: str
    content_type: str | None
    size_bytes: int
    uploaded_at: datetime


class ClientCaseAccountReportItem(BaseModel):
    case_id: int
    case_title: str
    fee_total: float | None
    income_sum: float
    remaining: float | None


class ClientAccountReportOut(BaseModel):
    client_id: int
    client_name: str
    cases: list[ClientCaseAccountReportItem]


class CustodyReportItem(BaseModel):
    user_id: int
    user_email: EmailStr
    current_balance: float
    advances_sum: float
    approved_spends_sum: float
    pending_spends_sum: float

