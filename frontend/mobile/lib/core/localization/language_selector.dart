import 'package:flutter/material.dart';

import 'app_locale.dart';
import 'app_localizations.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({
    super.key,
    this.accentColor = const Color(0xFF4B3425),
    this.showLabel = true,
  });

  final Color accentColor;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final controller = LocaleScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Text(
            context.t('settings.language'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F4F2),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: AppLocales.supported.map((locale) {
              final selected =
                  controller.locale.languageCode == locale.languageCode;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: selected
                      ? null
                      : () => controller.setLocale(locale),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? accentColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      AppLocales.nativeName(locale),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : accentColor,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
