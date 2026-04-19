# بناء APK (white-label) وتسجيله في الخادم

## المتغيرات في الخادم (FastAPI)

في ملف `.env` للـ backend:

```env
MOBILE_BUILD_WEBHOOK_TOKEN=ضع_قيمة_عشوائية_طويلة_سِرّية
```

أعد تشغيل الحاوية بعد التغيير.

## تشغيل البناء محليًا

من جذر المستودع:

```bash
./infra/mobile-build/build_white_label_apk.sh <office_code> <api_base_url> "" <build_number>
```

مثال:

```bash
./infra/mobile-build/build_white_label_apk.sh demo12 https://lawyer.example.com/api "" 99
```

الـ APK الناتج: `app/build/app/outputs/flutter-apk/app-release.apk`

## GitHub Actions

1. في إعدادات المستودع → Secrets → Actions أضف `MOBILE_BUILD_WEBHOOK_TOKEN` (نفس قيمة `.env` أعلاه).
2. نفّذ workflow **Build Android white-label APK** يدويًا وأدخل:
   - `office_code`, `api_base_url`, `backend_api_root`, واختياريًا `app_label`.

الـ workflow ينشئ [GitHub Release](https://docs.github.com/en/repositories/releasing-projects-on-github) بوسم فريد ويرسل رابط التحميل إلى `POST /internal/office-mobile-builds`.

**ملاحظة:** تنزيل أصول الإصدار من GitHub يعمل بشكل مباشر للمستودعات العامة؛ للمستودعات الخاصة استخدم تخزينًا عامًا (S3/رابط CDN) وعدّل خطوة الرفع بدل `gh release create`.

## واجهات الـ API

| الطريقة | المسار | الوصف |
|--------|--------|--------|
| GET | `/office/mobile-download` | للمستخدم المسجّل داخل المكتب (JWT) — آخر إصدار مسجّل |
| GET | `/public/offices/{office_code}/mobile-app` | بدون توثيق — لاستخدام تطبيق أندرويد عند **فحص التحديث** |
| POST | `/internal/office-mobile-builds` | للـ CI فقط — رأس `X-Mobile-Build-Token` |

## فحص التحديث من تطبيق أندرويد (مُستحسن)

1. عند التشغيل (أو من زر «تحقق من التحديث»)، استدعِ:
   `GET {API_BASE_URL}/public/offices/{office_code}/mobile-app`
2. قارِن `version_code` من الاستجابة مع `PackageInfo.fromPlatform().buildNumber` (أو ما يعادله في Flutter).
3. إذا كان الخادم أحدث، اعرض رابط `download_url` أو نزّل الملف برمجيًا ثم اطلب تثبيتًا (صلاحيات `REQUEST_INSTALL_PACKAGES` وسياسات أندرويد 8+).

الحقل `sha256_hex` اختياري للتحقق من سلامة الملف بعد التنزيل.

## Gradle / التسمية

- `-POFFICE_CODE=...` يضيف `applicationIdSuffix` لتمييز حزمة كل مكتب.
- `-PAPP_LABEL=...` يضبط اسم الظهور على أندرويد (يفضّل ASCII في سطر الأوامر).

Dart: `--dart-define=OFFICE_CODE=...` و `--dart-define=API_BASE_URL=...` (عنوان كامل للـ API على أندرويد).
