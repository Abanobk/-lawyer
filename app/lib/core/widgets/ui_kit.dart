import 'package:flutter/material.dart';
import 'package:lawyer_app/core/theme/app_spacing.dart';
import 'package:lawyer_app/core/theme/app_theme.dart';

/// هيدر صفحة موحّد: أيقونة + عنوان + وصف اختياري + إجراءات.
/// يلتفّ الإجراءات لأسفل تلقائيًا على الشاشات الضيقة (يتفادى overflow).
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleBlock = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 560;
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: AlignmentDirectional.centerStart, child: titleBlock),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: actions),
              ],
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: titleBlock),
            ...[
              for (final a in actions) ...[a, const SizedBox(width: AppSpacing.sm)],
            ],
          ],
        );
      },
    );
  }
}

/// حقل كلمة مرور موحّد مع زر إظهار/إخفاء.
class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    super.key,
    required this.controller,
    this.label = 'كلمة المرور',
    this.textInputAction,
    this.onSubmitted,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'إظهار' : 'إخفاء',
          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

/// زر أساسي مع حالة تحميل مدمجة (يتفادى تكرار سنيبت السبينر).
class AppLoadingButton extends StatelessWidget {
  const AppLoadingButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.loading = false,
    this.icon,
    this.expand = true,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool loading;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
          )
        : (icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [Icon(icon, size: 20), const SizedBox(width: 8), Text(label)],
              )
            : Text(label));
    final button = FilledButton(
      onPressed: loading ? null : onPressed,
      child: child,
    );
    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

/// بطاقة قسم موحّدة مع عنوان اختياري.
class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(child: Text(title!, style: theme.textTheme.titleMedium)),
                  ?trailing,
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

enum AppStatusTone { neutral, success, warning, danger, info }

/// شريحة حالة ملوّنة دلاليًا.
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({super.key, required this.label, this.tone = AppStatusTone.neutral, this.icon});

  final String label;
  final AppStatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Color base = switch (tone) {
      AppStatusTone.success => AppColors.success,
      AppStatusTone.warning => AppColors.warning,
      AppStatusTone.danger => AppColors.danger,
      AppStatusTone.info => AppColors.info,
      AppStatusTone.neutral => cs.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 14, color: base),
          if (icon != null) const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: base, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// إشعارات موحّدة (نجاح / خطأ).
void showAppSnack(BuildContext context, String message, {AppStatusTone tone = AppStatusTone.neutral}) {
  final cs = Theme.of(context).colorScheme;
  final Color? bg = switch (tone) {
    AppStatusTone.success => AppColors.success,
    AppStatusTone.danger => AppColors.danger,
    AppStatusTone.warning => AppColors.warning,
    AppStatusTone.info => AppColors.info,
    AppStatusTone.neutral => null,
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: bg == null ? cs.onInverseSurface : Colors.white)),
        backgroundColor: bg,
      ),
    );
}
