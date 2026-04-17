from datetime import datetime, date

from pydantic import BaseModel, EmailStr, Field, field_validator

from app.models import CaseKind, CustodySpendStatus, MoneyDirection, OfficeStatus, ProofStatus, SubscriptionStatus, UserRole


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class SignupRequest(BaseModel):
    office_name: str = Field(min_length=2, max_length=200)
    full_name: str = Field(min_length=2, max_length=200, description="اسم صاحب الحساب للترحيب")
    phone: str = Field(min_length=8, max_length=32, description="جوال المكتب — إلزامي")
    email: EmailStr
    password: str = Field(min_length=8, max_length=200)

    @field_validator("phone")
    @classmethod
    def _normalize_phone(cls, v: str) -> str:
        s = v.strip().replace(" ", "")
        if len(s) < 8:
            raise ValueError("phone too short")
        return s


class MeProfilePatch(BaseModel):
    full_name: str | None = Field(default=None, max_length=200)

    @field_validator("full_name")
    @classmethod
    def _full_name_len(cls, v: str | None) -> str | None:
        if v is None:
            return None
        s = v.strip()
        if len(s) < 2:
            raise ValueError("full_name must be at least 2 characters when set")
        return s


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
    phone: str | None = None
    contact_email: str | None = None
    address: str | None = None


class OfficePatch(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=200)
    phone: str | None = Field(default=None, max_length=32)
    contact_email: str | None = Field(default=None, max_length=255)
    address: str | None = Field(default=None, max_length=4000)

    @field_validator("phone")
    @classmethod
    def _phone_optional(cls, v: str | None) -> str | None:
        if v is None:
            return None
        s = v.strip().replace(" ", "")
        if len(s) < 8:
            raise ValueError("phone must be at least 8 digits when set")
        return s

    @field_validator("contact_email")
    @classmethod
    def _email_blank(cls, v: str | None) -> str | None:
        if v is None or not str(v).strip():
            return None
        return str(v).strip()


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
    max_users_override: int | None = None
    max_users_effective: int


class AdminUpdateTrialRequest(BaseModel):
    trial_end_at: datetime
    notes: str | None = None


class AdminPatchSubscriptionRequest(BaseModel):
    """Partial update; only fields present in the JSON body are applied."""

    trial_end_at: datetime | None = None
    max_users_override: int | None = None

    @field_validator("max_users_override")
    @classmethod
    def _max_users_positive(cls, v: int | None) -> int | None:
        if v is not None and v <= 0:
            raise ValueError("max_users_override must be positive when set")
        return v


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


class CasePatch(BaseModel):
    """تحديث جزئي للقضية (مثلاً إجمالي الأتعاب المتفق عليها من صفحة الحساب)."""

    fee_total: float | None = None

    @field_validator("fee_total")
    @classmethod
    def fee_total_positive(cls, v: float | None) -> float | None:
        if v is not None and v <= 0:
            raise ValueError("fee_total must be greater than 0")
        return v


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


class FinancialMovementOut(BaseModel):
    """سطر موحّد في دفتر الحركة المالية."""

    ledger_key: str
    source_type: str
    source_id: int
    kind: str
    kind_label_ar: str
    occurred_at: datetime
    amount: float
    direction: str  # income | expense
    affects_office_cash: bool
    case_id: int | None = None
    case_title: str | None = None
    custody_user_id: int | None = None
    custody_user_email: str | None = None
    description: str | None = None


class FinancialSummaryOut(BaseModel):
    period_from: date | None = None
    period_to: date | None = None
    case_id_filter: int | None = None
    total_case_income: float
    total_case_expense: float
    total_office_expense: float
    total_custody_advances: float
    total_custody_spends_approved: float
    total_custody_spends_pending: float
    total_petty_top_ups: float = 0
    total_petty_spends: float = 0
    total_petty_settlement_net: float = 0
    net_case: float
    net_operating_simple: float
    includes_custody: bool


class PettyCashFundCreate(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    receipt_required_above: float = Field(default=0, ge=0, description="أعلى من هذا المبلغ يتطلب إيصالاً عند الصرف")


class PettyCashFundPatch(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    receipt_required_above: float | None = Field(default=None, ge=0)
    is_active: bool | None = None


class PettyCashFundOut(BaseModel):
    id: int
    name: str
    receipt_required_above: float
    current_balance: float
    is_active: bool
    created_at: datetime


class PettyCashTopUpCreate(BaseModel):
    amount: float = Field(gt=0)
    notes: str | None = Field(default=None, max_length=500)
    occurred_at: datetime | None = None


class PettyCashTopUpOut(BaseModel):
    id: int
    fund_id: int
    amount: float
    notes: str | None
    occurred_at: datetime
    created_by_user_id: int | None
    created_at: datetime


class PettyCashSpendOut(BaseModel):
    id: int
    fund_id: int
    amount: float
    description: str | None
    occurred_at: datetime
    case_id: int | None
    created_by_user_id: int | None
    created_at: datetime


class PettyCashSettlementCreate(BaseModel):
    adjustment_amount: float = Field(description="يُضاف للرصيد (+ فائض، − عجز)")
    notes: str | None = Field(default=None, max_length=500)
    occurred_at: datetime | None = None


class PettyCashSettlementOut(BaseModel):
    id: int
    fund_id: int
    adjustment_amount: float
    notes: str | None
    occurred_at: datetime
    created_by_user_id: int | None
    created_at: datetime


class PettyCashReceiptOut(BaseModel):
    id: int
    spend_id: int
    original_name: str
    content_type: str | None
    size_bytes: int
    uploaded_at: datetime


class PettyCashPeriodReportOut(BaseModel):
    fund_id: int
    fund_name: str
    current_balance: float
    period_from: date
    period_to: date
    sum_top_ups: float
    sum_spends: float
    sum_settlements: float
    net_change: float
    opening_balance: float
    closing_balance_implied: float

