import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../data/providers/app_settings.dart';
import '../../widgets/common.dart';

class AuthorLink {
  const AuthorLink({
    required this.label,
    required this.url,
    required this.icon,
    required this.tint,
  });

  final String label;
  final String url;
  final IconData icon;
  final Color tint;
}

const List<AuthorLink> authorLinks = [
  AuthorLink(
    label: 'GitHub',
    url: 'https://github.com/miiko3?tab=repositories',
    icon: Icons.code_rounded,
    tint: Color(0xFF5B6B7A),
  ),
  AuthorLink(
    label: 'Telegram',
    url: 'https://t.me/yetilov',
    icon: Icons.send_rounded,
    tint: Color(0xFF4E93C4),
  ),
  AuthorLink(
    label: 'Boosty',
    url: 'https://boosty.to/miilo3',
    icon: Icons.favorite_rounded,
    tint: Color(0xFFC08163),
  ),
  AuthorLink(
    label: 'YooMoney',
    url: 'https://yoomoney.ru/fundraise/1GJCNQ28KCK.260319',
    icon: Icons.volunteer_activism_rounded,
    tint: Color(0xFF7F9079),
  ),
];

Future<void> openAuthorLink(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class AuthorCard extends StatelessWidget {
  const AuthorCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return RoundedPanel(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c.primary, c.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: AppRadius.md,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('author.title'), style: context.t.titleMedium),
                    Text('miiko3', style: context.t.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Text(t('author.about'), style: context.t.bodySmall),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (final link in authorLinks) _chip(context, link),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, AuthorLink link) {
    return Material(
      color: link.tint.withValues(alpha: 0.12),
      borderRadius: AppRadius.pill,
      child: InkWell(
        borderRadius: AppRadius.pill,
        onTap: () => openAuthorLink(link.url),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(link.icon, size: 16, color: link.tint),
              const SizedBox(width: 6),
              Text(
                link.label,
                style: context.t.labelMedium?.copyWith(color: link.tint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const List<(String, String, IconData)> _sections = [
    ('help.accessTitle', 'help.accessText', Icons.folder_special_outlined),
    ('help.browserTitle', 'help.browserText', Icons.folder_open_rounded),
    (
      'help.formatsTitle',
      'help.formatsText',
      Icons.checklist_rtl_rounded,
    ),
    ('help.editingTitle', 'help.editingText', Icons.edit_rounded),
    ('help.pdfTitle', 'help.pdfText', Icons.picture_as_pdf_outlined),
    ('help.slidesTitle', 'help.slidesText', Icons.slideshow_outlined),
    ('help.storageTitle', 'help.storageText', Icons.sd_storage_outlined),
    ('help.themesTitle', 'help.themesText', Icons.palette_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final settings = context.read<AppSettings>();

    return Scaffold(
      appBar: AppBar(
        title: Text(t('help.title')),
        actions: [
          RoundIconButton(
            icon: settings.themeMode == AppThemeMode.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
            tooltip: settings.themeMode == AppThemeMode.dark
                ? t('settings.themeLight')
                : t('settings.themeDark'),
            size: 34,
            iconSize: 18,
            onPressed: () => settings.setThemeMode(
              settings.themeMode == AppThemeMode.dark
                  ? AppThemeMode.light
                  : AppThemeMode.dark,
            ),
          ),
          const SizedBox(width: AppSpace.sm),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.sm,
          AppSpace.lg,
          AppSpace.xxl,
        ),
        children: [
          RoundedPanel(
            color: c.primarySoft,
            border: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: c.primary, size: 20),
                const SizedBox(width: AppSpace.md),
                Expanded(child: Text(t('help.intro'), style: context.t.bodyMedium)),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          for (final section in _sections)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.md),
              child: RoundedPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(section.$3, size: 18, color: c.primary),
                        const SizedBox(width: AppSpace.sm),
                        Expanded(
                          child: Text(
                            t(section.$1),
                            style: context.t.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      t(section.$2),
                      style: context.t.bodySmall?.copyWith(height: 1.55),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpace.lg),
          const AuthorCard(),
        ],
      ),
    );
  }
}