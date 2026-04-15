# Lawyer Office SaaS

برنامج تنظيم عمل المحامين بنظام SaaS (كل مكتب tenant مستقل).

## تشغيل سريع (Backend + Postgres)

1) أنشئ ملف `.env` في جذر الريبو (مثال):

```env
APP_BASE_URL=http://localhost:8080
JWT_SECRET=dev-secret-change-me
SUPER_ADMIN_EMAIL=admin@example.com
SUPER_ADMIN_PASSWORD=admin12345
TRIAL_DAYS_DEFAULT=30
```

2) شغّل الخدمات:

```bash
docker compose -f infra/docker-compose.yml up --build
```

3) جرّب الصحة:
- `GET /health` على `http://localhost:8000/health`

## تدفّق الاشتراك (اللي اتفقنا عليه)
- العميل يعمل **Sign up**: (email + password + اسم المكتب)
- النظام ينشئ `officeCode` تلقائيًا + يفعّل **Trial 30 يوم** + يرجّع لينك المكتب: `/o/<officeCode>`
- أنت كـ **Super Admin** تقدر تعدّل نهاية التجربة/الاشتراك لاحقًا من لوحة الأدمن.

