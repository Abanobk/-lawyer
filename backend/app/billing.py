"""Shared subscription activation after manual proof approval or Paymob payment."""

from __future__ import annotations

from datetime import datetime, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Plan, Subscription, SubscriptionStatus, User, UserPermission, UserRole


def activate_office_subscription(
    db: Session,
    *,
    office_id: int,
    plan: Plan,
    notes: str,
    now: datetime,
    permissions_catalog: dict[str, str],
) -> Subscription:
    latest = db.scalar(
        select(Subscription).where(Subscription.office_id == office_id).order_by(Subscription.id.desc())
    )
    if latest and latest.status in (SubscriptionStatus.trial, SubscriptionStatus.active) and latest.end_at > now:
        start_at = latest.end_at
    else:
        start_at = now
    end_at = start_at + timedelta(days=int(plan.duration_days))

    sub = Subscription(
        office_id=office_id,
        status=SubscriptionStatus.active,
        start_at=start_at,
        end_at=end_at,
        price_snapshot_cents=int(plan.price_cents),
        plan_name_snapshot=plan.name,
        plan_id=plan.id,
        notes=notes,
    )
    db.add(sub)

    max_users_total = int(getattr(plan, "max_users", None) or 0) or 10_000
    if getattr(plan, "allowed_perm_keys_csv", None):
        allowed_perm_keys = {
            k.strip()
            for k in plan.allowed_perm_keys_csv.split(",")
            if k.strip() and k.strip() in permissions_catalog
        }
    else:
        allowed_perm_keys = set(permissions_catalog.keys())

    allowed_staff_count = max(max_users_total - 1, 0)
    staff_users = db.scalars(
        select(User).where(
            User.office_id == office_id,
            User.role == UserRole.staff,
            User.is_active == True,  # noqa: E712
        ).order_by(User.id.asc())
    ).all()
    if len(staff_users) > allowed_staff_count:
        to_disable = [u.id for u in staff_users[allowed_staff_count:]]
        db.query(User).where(User.id.in_(to_disable)).update({"is_active": False}, synchronize_session=False)
        db.query(UserPermission).where(
            UserPermission.office_id == office_id,
            UserPermission.user_id.in_(to_disable),
        ).delete(synchronize_session=False)

    keep_staff_ids = [u.id for u in staff_users[:allowed_staff_count]]
    if keep_staff_ids and allowed_perm_keys != set(permissions_catalog.keys()):
        db.query(UserPermission).where(
            UserPermission.office_id == office_id,
            UserPermission.user_id.in_(keep_staff_ids),
        ).filter(~UserPermission.perm_key.in_(allowed_perm_keys)).delete(synchronize_session=False)

    return sub
