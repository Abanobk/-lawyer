import 'package:flutter/material.dart';

import 'package:lawyer_app/data/api/billing_api.dart';

class SubscriptionTrialBanner extends StatelessWidget {
  const SubscriptionTrialBanner({
    super.key,
    required this.sub,
    required this.onSubscribe,
  });

  final SubscriptionMeDto sub;
  final VoidCallback onSubscribe;

  int _remainingDays() {
    final now = DateTime.now().toUtc();
    final endAt = sub.endAt.toUtc();
    return endAt.difference(now).inDays;
  }

  int _trialTotalDays() {
    final startAt = sub.startAt.toUtc();
    final endAt = sub.endAt.toUtc();
    final days = endAt.difference(startAt).inDays;
    return days > 0 ? days : 30;
  }

  @override
  Widget build(BuildContext context) {
    if (sub.status != 'trial') return const SizedBox.shrink();

    final remaining = _remainingDays();
    final total = _trialTotalDays();
    final isBlocked = remaining <= 3;
    final isStopped = remaining <= 0;

    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);

    return Card(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      color: isStopped
          ? Colors.red.withValues(alpha: 0.08)
          : isBlocked
              ? Colors.orange.withValues(alpha: 0.10)
              : Colors.blue.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isStopped
                  ? 'الحساب متوقف ويجب تجديد الاشتراك ثانيه'
                  : 'مرحبا بك في الفترة التجريبية: $total يوم مجانا',
              style: titleStyle,
            ),
            const SizedBox(height: 8),
            if (!isStopped) Text('باقي: $remaining يوم'),
            if (isBlocked && !isStopped) ...[
              const SizedBox(height: 8),
              const Text('قبل الانتهاء بـ 3 أيام سيتم حظر الوصول. اشترك الآن لتفادي خسارة البيانات.'),
            ],
            if (isBlocked)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FilledButton(
                  onPressed: onSubscribe,
                  child: const Text('اشترك الآن'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

