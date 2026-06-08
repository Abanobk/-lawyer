import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lawyer_app/core/theme/app_theme.dart';
import 'package:lawyer_app/core/widgets/app_states.dart';
import 'package:lawyer_app/core/widgets/ui_kit.dart';
import 'package:lawyer_app/data/api/paymob_api.dart';

/// يُستدعى بعد العودة من صفحة Paymob (redirection_url).
class SubscriptionPaymobReturnPage extends StatefulWidget {
  const SubscriptionPaymobReturnPage({super.key, required this.queryParams});

  final Map<String, String> queryParams;

  @override
  State<SubscriptionPaymobReturnPage> createState() => _SubscriptionPaymobReturnPageState();
}

class _SubscriptionPaymobReturnPageState extends State<SubscriptionPaymobReturnPage> {
  final _api = SubscriptionPaymobApi();
  String? _status;
  String? _message;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _confirm();
  }

  Future<void> _confirm() async {
    try {
      final payload = <String, dynamic>{};
      widget.queryParams.forEach((k, v) {
        if (k == 'subscription_payment') {
          payload['subscription_payment'] = int.tryParse(v) ?? v;
        } else if (k == 'success' || k == 'pending') {
          payload[k] = v == 'true';
        } else {
          payload[k] = v;
        }
      });
      final res = await _api.confirmReturn(payload);
      if (!mounted) return;
      setState(() {
        _status = res.status;
        _message = res.message;
        _loading = false;
      });
      if (res.status == 'paid') {
        showAppSnack(context, 'تم تفعيل الاشتراك بنجاح', tone: AppStatusTone.success);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'error';
        _message = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('نتيجة الدفع')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _loading
                ? const AppBodyLoading(message: 'جارٍ التحقق من الدفع…')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _status == 'paid' ? Icons.check_circle_outline : Icons.info_outline,
                        size: 56,
                        color: _status == 'paid'
                            ? AppColors.success
                            : Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _status == 'paid'
                            ? 'تم الدفع وتفعيل الاشتراك'
                            : _status == 'waiting_webhook'
                                ? 'بانتظار تأكيد Paymob'
                                : 'حالة الدفع: ${_status ?? '—'}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 8),
                        Text(_message!, textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                        child: const Text('متابعة'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
