import 'package:flutter/material.dart';
import 'package:lawyer_app/core/theme/app_spacing.dart';
import 'package:lawyer_app/core/widgets/ui_kit.dart';
import 'package:lawyer_app/data/api/paymob_api.dart';

class PaymobAdminSettingsCard extends StatefulWidget {
  const PaymobAdminSettingsCard({super.key});

  @override
  State<PaymobAdminSettingsCard> createState() => _PaymobAdminSettingsCardState();
}

class _PaymobAdminSettingsCardState extends State<PaymobAdminSettingsCard> {
  final _api = AdminPaymobApi();
  final _publicKey = TextEditingController();
  final _secretKey = TextEditingController();
  final _hmacSecret = TextEditingController();
  final _cardIntegrationId = TextEditingController();
  final _walletIntegrationId = TextEditingController();
  String _mode = 'test';
  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;
  PaymobProviderDto? _current;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _publicKey.dispose();
    _secretKey.dispose();
    _hmacSecret.dispose();
    _cardIntegrationId.dispose();
    _walletIntegrationId.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await _api.getProvider();
      if (!mounted) return;
      setState(() {
        _current = p;
        _mode = p.mode;
        _enabled = p.isEnabled;
        if (p.cardIntegrationId != null) _cardIntegrationId.text = '${p.cardIntegrationId}';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAppSnack(context, '$e', tone: AppStatusTone.danger);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final p = await _api.saveProvider(
        mode: _mode,
        publicKey: _publicKey.text.trim().isEmpty ? null : _publicKey.text.trim(),
        secretKey: _secretKey.text.trim().isEmpty ? null : _secretKey.text.trim(),
        hmacSecret: _hmacSecret.text.trim().isEmpty ? null : _hmacSecret.text.trim(),
        cardIntegrationId: int.tryParse(_cardIntegrationId.text.trim()),
        walletIntegrationId: int.tryParse(_walletIntegrationId.text.trim()),
        enabled: _enabled,
      );
      if (!mounted) return;
      _publicKey.clear();
      _secretKey.clear();
      _hmacSecret.clear();
      setState(() {
        _current = p;
        _saving = false;
      });
      showAppSnack(context, 'تم حفظ إعدادات Paymob', tone: AppStatusTone.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnack(context, '$e', tone: AppStatusTone.danger);
    }
  }

  Future<void> _test() async {
    try {
      final res = await _api.testConnection();
      if (!mounted) return;
      showAppSnack(context, res['ok'] == true ? 'اتصال Paymob ناجح' : 'فشل الاتصال', tone: AppStatusTone.success);
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, '$e', tone: AppStatusTone.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final webhook = '${Uri.base.origin}/webhooks/paymob';
    final processed = webhook;
    final response = '${Uri.base.origin}/subscription-return';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: _loading
            ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Paymob — دفع اشتراكات المكاتب', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    _current?.isEnabled == true
                        ? 'مفعّل — Public Key …${_current?.publicKeyLast8 ?? ''} — Card ${_current?.cardIntegrationId ?? '—'}'
                        : 'غير مفعّل — أدخل مفاتيح حساب Paymob لتفعيل الدفع الإلكتروني للمكاتب.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Text('Webhook (Processed): $processed', style: Theme.of(context).textTheme.labelSmall),
                  Text('Return URL: $response', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _mode,
                    decoration: const InputDecoration(labelText: 'الوضع'),
                    items: const [
                      DropdownMenuItem(value: 'test', child: Text('Test')),
                      DropdownMenuItem(value: 'live', child: Text('Live')),
                    ],
                    onChanged: _saving ? null : (v) => setState(() => _mode = v ?? 'test'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _publicKey,
                    decoration: const InputDecoration(labelText: 'Public Key (pk…)', helperText: 'اتركه فارغًا للإبقاء على المحفوظ'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _secretKey,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Secret Key', helperText: 'اتركه فارغًا للإبقاء على المحفوظ'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _hmacSecret,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'HMAC Secret (webhook)', helperText: 'مطلوب للتفعيل التلقائي'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _cardIntegrationId,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Card Integration ID'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _walletIntegrationId,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Wallet Integration ID (اختياري)'),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تفعيل Paymob للمكاتب'),
                    value: _enabled,
                    onChanged: _saving ? null : (v) => setState(() => _enabled = v),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('حفظ Paymob'),
                      ),
                      OutlinedButton(onPressed: _test, child: const Text('اختبار الاتصال')),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
