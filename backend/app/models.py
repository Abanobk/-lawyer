import enum
from datetime import date, datetime

from sqlalchemy import Boolean, Date, DateTime, Enum, ForeignKey, Index, Integer, Numeric, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class OfficeStatus(str, enum.Enum):
    active = "active"
    disabled = "disabled"


class UserRole(str, enum.Enum):
    super_admin = "super_admin"
    office_owner = "office_owner"
    staff = "staff"


class SubscriptionStatus(str, enum.Enum):
    trial = "trial"
    active = "active"
    expired = "expired"
    cancelled = "cancelled"


class ProofStatus(str, enum.Enum):
    pending = "pending"
    approved = "approved"
    rejected = "rejected"


class Office(Base):
    __tablename__ = "offices"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    code: Mapped[str] = mapped_column(String(32), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(200))
    phone: Mapped[str | None] = mapped_column(String(50), nullable=True)
    contact_email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    address: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[OfficeStatus] = mapped_column(Enum(OfficeStatus), default=OfficeStatus.active)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    users: Mapped[list["User"]] = relationship(back_populates="office")
    subscriptions: Mapped[list["Subscription"]] = relationship(back_populates="office")


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    office_id: Mapped[int | None] = mapped_column(ForeignKey("offices.id"), nullable=True, index=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    full_name: Mapped[str | None] = mapped_column(String(200), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    role: Mapped[UserRole] = mapped_column(Enum(UserRole), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    office: Mapped["Office"] = relationship(back_populates="users")


class UserPermission(Base):
    __tablename__ = "user_permissions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    office_id: Mapped[int] = mapped_column(ForeignKey("offices.id"), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    perm_key: Mapped[str] = mapped_column(String(120), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, index=True)


Index("uq_user_permissions_office_user_key", UserPermission.office_id, UserPermission.user_id, UserPermission.perm_key, unique=True)


class Plan(Base):
    __tablename__ = "plans"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(100), unique=True)
    price_cents: Mapped[int] = mapped_column(Integer)
    duration_days: Mapped[int] = mapped_column(Integer)
    instapay_link: Mapped[str | None] = mapped_column(String(800), nullable=True)
    promo_image_path: Mapped[str | None] = mapped_column(String(500), nullable=True)
    # Package base fields (used to restrict modules + user count).
    package_key: Mapped[str | None] = mapped_column(String(80), nullable=True, index=True)
    package_name: Mapped[str | None] = mapped_column(String(200), nullable=True)
    max_users: Mapped[int | None] = mapped_column(Integer, nullable=True)
    allowed_perm_keys_csv: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)


class Subscription(Base):
    __tablename__ = "subscriptions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    office_id: Mapped[int] = mapped_column(ForeignKey("offices.id"), index=True)
    status: Mapped[SubscriptionStatus] = mapped_column(Enum(SubscriptionStatus), index=True)
    start_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    end_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    price_snapshot_cents: Mapped[int | None] = mapped_column(Integer, nullable=True)
    plan_name_snapshot: Mapped[str | None] = mapped_column(String(100), nullable=True)
    # Reference to the exact plan option that produced this subscription.
    plan_id: Mapped[int | None] = mapped_column(ForeignKey("plans.id"), nullable=True, index=True)
    # When set, overrides trial default (3) or plan max_users for user-cap enforcement.
    max_users_override: Mapped[int | None] = mapped_column(Integer, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    office: Mapped["Office"] = relationship(back_populates="subscriptions")


class PaymentProof(Base):
    __tablename__ = "payment_proofs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    office_id: Mapped[int] = mapped_column(ForeignKey("offices.id"), index=True)
    plan_id: Mapped[int | None] = mapped_column(ForeignKey("plans.id"), nullable=True, index=True)
    image_path: Mapped[str] = mapped_column(String(500))
    status: Mapped[ProofStatus] = mapped_column(Enum(ProofStatus), default=ProofStatus.pending, index=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    amount_snapshot_cents: Mapped[int | None] = mapped_column(Integer, nullable=True)
    instapay_link_snapshot: Mapped[str | None] = mapped_column(String(800), nullable=True)
    reference_code: Mapped[str | None] = mapped_column(String(120), nullable=True)
    reviewed_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
    decision_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    uploaded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)


Index("idx_payment_proofs_office_status", PaymentProof.office_id, PaymentProof.status)
Index("idx_payment_proofs_status_uploaded", PaymentProof.status, PaymentProof.uploaded_at)


class OfficeActivityDaily(Base):
    __tablename__ = "office_activity_daily"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    office_id: Mapped[int] = mapped_column(ForeignKey("offices.id"), index=True)
    activity_date: Mapped[date] = mapped_column(Date, index=True)
    hits: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, index=True)


Index("uq_office_activity_daily_office_date", OfficeActivityDaily.office_id, OfficeActivityDaily.activity_date, unique=True)


class CaseKind(str, enum.Enum):
    civil = "civil"
    misdemeanor = "misdemeanor"  # جنح
    felony = "felony"  # جنايات
    family = "family"
    other = "other"


class MoneyDirection(str, enum.Enum):
    income = "income"
    expense = "expense"


class CustodySpendStatus(str, enum.Enum):
    pending = "pending"
    approved = "approved"
    rejected = "rejected"


class Client(Base):
    __tablename__ = "clients"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    office_id: Mapped[int] = mapped_column(ForeignKey("offices.id"), index=True)

    full_name: Mapped[str] = mapped_column(String(200), index=True)
    phone: Mapped[str | None] = mapped_column(String(50), nullable=True)
    national_id: Mapped[str | None] = mapped_column(String(50), nullable=True)
    address: Mapped[str | None] = mapped_column(String(500), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, index=True)

    cases: Mapped[list["Case"]] = relationship(back_populates="client")


class Case(Base):
    __tablename__ = "cases"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    office_id: Mapped[int] = mapped_column(ForeignKey("offices.id"), index=True)
    client_id: Mapped[int] = mapped_column(ForeignKey("clients.id"), index=True)

    title: Mapped[str] = mapped_column(String(200))
    kind: Mapped[CaseKind] = mapped_column(Enum(CaseKind), default=CaseKind.other, index=True)

    court: Mapped[str | None] = mapped_column(String(200), nullable=True)  # مثال: الجيزة / القاهرة
    case_number: Mapped[str | None] = mapped_column(String(100), nullable=True)  # رقم القضية
    case_year: Mapped[int | None] = mapped_column(Integer, nullable=True)

    first_hearing_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)

    fee_total: Mapped[float | None] = mapped_column(Numeric(12, 2), nullable=True)  # إجمالي الأتعاب
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, index=True)

    client: Mapped["Client"] = relationship(back_populates="cases")
    assignments: Mapped[list["CaseAssignment"]] = relationship(back_populates="case", cascade="all, delete-orphan")
    sessions: Mapped[list["CaseSession"]] = relationship(back_populates="case", cascade="all, delete-orphan")
    files: Mapped[list["CaseFile"]] = relationship(back_populates="case", cascade="all, delete-orphan")
    transactions: Mapped[list["CaseTransaction"]] = relationship(back_populates="case", cascade="all, delete-orphan")


class CaseAssignment(Base):
    __tablename__ = "case_assignments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    office_id: Mapped[int] = mapped_column(ForeignKey("offices.id"), index=True)
    case_id: Mapped[int] = mapped_column(ForeignKey("cases.id"), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)

    is_primary: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, index=True)

    case: Mapped["Case"] = relationship(back_populates="assignments")
    user: Mapped["User"] = relationship()


class CaseSession(Base):
    __tablename__ = "case_sessions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    office_id: Mapped[int] = mapped_column(ForeignKey("offices.id"), index=True)
    case_id: Mapped[int] = mapped_column(ForeignKey("cases.id"), index=True)

    session_number: Mapped[str | None] = mapped_column(String(50), nullable=True)  # رقم الجلسة
    session_year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    session_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, index=True)

    case: Mapped["Case"] = relationship(back_populates="sessions")


class CaseFile(Base):
    __tablename__ = "case_files"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    office_id: Mapped[int] = mapped_column(ForeignKey("offices.id"), index=True)
    case_id: Mapped[int] = mapped_column(ForeignKey("cases.id"), index=True)

    original_name: Mapped[str] = mapped_column(String(255))
    content_type: Mapped[str | None] = mapped_column(String(200), nullable=True)
    storage_path: Mapped[str] = mapped_column(String(800), unique=True)
    size_bytes: Mapped[int] = mapped_column(Integer)
    uploaded_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    uploaded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, index=True)

    case: Mapped["Case"] = relationship(back_populates="files")


class CaseTransaction(Base):
    __tablename__ = "case_transactions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    office_id: Mapped[int] = mapped_column(ForeignKey("offices.id"), index=True)
    case_id: Mapped[int] = mapped_column(ForeignKey("cases.id"), index=True)

    direction: Mapped[MoneyDirection] = mapped_column(Enum(MoneyDirection), index=True)
    amount: Mapped[float] = mapped_column(Numeric(12, 2))
    description: Mapped[str | None] = mapped_column(String(300), nullable=True)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    created_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, index=True)

    case: Mapped["Case"] = relationship(back_populates="transactions")


class OfficeExpense(Base):
    __tablename__ = "office_expenses"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    office_id: Mapped[int] = mapped_column(ForeignKey("offices.id"), index=True)

    amount: Mapped[float] = mapped_column(Numeric(12, 2))
    description: Mapped[str | None] = mapped_column(String(500), nullable=True)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True, default=datetime.utcnow)
    created_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, index=True)


Index("idx_office_expenses_office_occurred", OfficeExpense.office_id, OfficeExpense.occurred_at)


class OfficeExpenseReceiptFile(Base):
    __tablename__ = "office_expense_receipt_files"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    office_id: Mapped[int] = mapped_column(ForeignKey("offices.id"), index=True)
    expense_id: Mapped[int] = mapped_column(ForeignKey("office_expenses.id"), index=True)

    original_name: Mapped[str] = mapped_column(String(255))
    content_type: Mapped[str | None] = mapped_column(String(200), nullable=True)
    storage_path: Mapped[str] = mapped_column(String(800), unique=True)
    size_bytes: Mapped[int] = mapped_column(Integer)
    uploaded_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    uploaded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, index=True)


class PettyCashFund(Base):
    """صندوق نثرية لكل مكتب (يمكن إنشاء أكثر من صندوق لاحقاً)."""

    __tablename__ = "petty_cash_funds"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    office_id: Mapped[int] = mapped_column(ForeignKey("offices.id"), index=True)
    name: Mapped[str] = mapped_column(String(200))
    # إذا كان المبلغ > هذا الرقم يجب إرفاق إيصال عند الصرف (0 = الإيصال اختياري دائماً)
    receipt_required_above: Mapped[float] = mapped_column(Numeric(12, 2), default=0)
    current_balance: Mapped[float] = mapped_column(Numeric(12, 2), default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, index=True)


Index("idx_petty_cash_funds_office_active", PettyCashFund.office_id, PettyCashFund.is_active)


class PettyCashTopUp(Base):
    __tablename__ = "petty_cash_topups"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    office_id: Mapped[int] = mapped_column(ForeignKey("offices.id"), index=True)
    fund_id: Mapped[int] = mapped_column(ForeignKey("petty_cash_funds.id"), index=True)

    amount: Mapped[float] = mapped_column(Numeric(12, 2))
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    notes: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, index=True)


Index("idx_petty_topups_fund_occurred", PettyCashTopUp.fund_id, PettyCashTopUp.occurred_at)


class PettyCashSpend(Base):
    __tablename__ = "petty_cash_spends"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    office_id: Mapped[int] = mapped_column(ForeignKey("offices.id"), index=True)
    fund_id: Mapped[int] = mapped_column(ForeignKey("petty_cash_funds.id"), index=True)

    amount: Mapped[float] = mapped_column(Numeric(12, 2))
    description: Mapped[str | None] = mapped_column(String(500), nullable=True)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    case_id: Mapped[int | None] = mapped_column(ForeignKey("cases.id"), nullable=True, index=True)
    created_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, index=True)


Index("idx_petty_spends_fund_occurred", PettyCashSpend.fund_id, PettyCashSpend.occurred_at)


class PettyCashSettlement(Base):
    """تسوية جرد: يُضاف المبلغ إلى رصيد الصندوق (سالب إذا عجز)."""

    __tablename__ = "petty_cash_settlements"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    office_id: Mapped[int] = mapped_column(ForeignKey("offices.id"), index=True)
    fund_id: Mapped[int] = mapped_column(ForeignKey("petty_cash_funds.id"), index=True)

    adjustment_amount: Mapped[float] = mapped_column(Numeric(12, 2))
    notes: Mapped[str | None] = mapped_column(String(500), nullable=True)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    created_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, index=True)


Index("idx_petty_settlements_fund_occurred", PettyCashSettlement.fund_id, PettyCashSettlement.occurred_at)


class PettyCashReceiptFile(Base):
    __tablename__ = "petty_cash_receipt_files"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    office_id: Mapped[int] = mapped_column(ForeignKey("offices.id"), index=True)
    spend_id: Mapped[int] = mapped_column(ForeignKey("petty_cash_spends.id"), index=True)

    original_name: Mapped[str] = mapped_column(String(255))
    content_type: Mapped[str | None] = mapped_column(String(200), nullable=True)
    storage_path: Mapped[str] = mapped_column(String(800), unique=True)
    size_bytes: Mapped[int] = mapped_column(Integer)
    uploaded_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    uploaded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, index=True)


class CustodyAccount(Base):
    __tablename__ = "custody_accounts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    office_id: Mapped[int] = mapped_column(ForeignKey("offices.id"), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    current_balance: Mapped[float] = mapped_column(Numeric(12, 2), default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, index=True)


Index("uq_custody_accounts_office_user", CustodyAccount.office_id, CustodyAccount.user_id, unique=True)


class CustodyAdvance(Base):
    __tablename__ = "custody_advances"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    office_id: Mapped[int] = mapped_column(ForeignKey("offices.id"), index=True)
    account_id: Mapped[int] = mapped_column(ForeignKey("custody_accounts.id"), index=True)
    amount: Mapped[float] = mapped_column(Numeric(12, 2))
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    notes: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, index=True)


class CustodySpend(Base):
    __tablename__ = "custody_spends"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    office_id: Mapped[int] = mapped_column(ForeignKey("offices.id"), index=True)
    account_id: Mapped[int] = mapped_column(ForeignKey("custody_accounts.id"), index=True)

    amount: Mapped[float] = mapped_column(Numeric(12, 2))
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    description: Mapped[str | None] = mapped_column(String(500), nullable=True)
    status: Mapped[CustodySpendStatus] = mapped_column(Enum(CustodySpendStatus), default=CustodySpendStatus.pending, index=True)
    case_id: Mapped[int | None] = mapped_column(ForeignKey("cases.id"), nullable=True, index=True)

    created_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    reviewed_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
    reject_reason: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, index=True)


class CustodyReceiptFile(Base):
    __tablename__ = "custody_receipt_files"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    office_id: Mapped[int] = mapped_column(ForeignKey("offices.id"), index=True)
    spend_id: Mapped[int] = mapped_column(ForeignKey("custody_spends.id"), index=True)

    original_name: Mapped[str] = mapped_column(String(255))
    content_type: Mapped[str | None] = mapped_column(String(200), nullable=True)
    storage_path: Mapped[str] = mapped_column(String(800), unique=True)
    size_bytes: Mapped[int] = mapped_column(Integer)
    uploaded_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    uploaded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, index=True)
