import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../data/providers/app_settings.dart';
import '../../data/services/saf_service.dart';
import '../../widgets/common.dart';
import 'browser_screen.dart';
import 'help_screen.dart';
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final c = context.c;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings.title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.sm,
          AppSpace.lg,
          AppSpace.xxl,
        ),
        children: [
          _group(context, context.tr('settings.appearance'), [
            _themeRow(context, settings),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('settings.darkPage')),
              subtitle: Text(context.tr('settings.darkPageHint')),
              value: false,
              onChanged: (_) {},
            ),
            _slider(
              context,
              context.tr('settings.textScale'),
              settings.textScale,
              0.85,
              1.3,
              (v) => settings.setDouble('textScale', v),
            ),
          ]),
          _group(context, context.tr('settings.browser'), [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('settings.showHidden')),
              value: settings.showHidden,
              onChanged: (v) => settings.setBool('showHidden', v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('settings.foldersFirst')),
              value: settings.sortFoldersFirst,
              onChanged: (v) => settings.setBool('sortFoldersFirst', v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('settings.gridLayout')),
              value: settings.gridView,
              onChanged: (v) => settings.setBool('gridView', v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('settings.confirmDelete')),
              value: settings.confirmDelete,
              onChanged: (v) => settings.setBool('confirmDelete', v),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.sort_rounded),
              title: Text(context.tr('settings.sortBy')),
              trailing: DropdownButton<String>(
                value: settings.sortBy,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(
                    value: 'name',
                    child: Text(context.tr('settings.sortName')),
                  ),
                  DropdownMenuItem(
                    value: 'modified',
                    child: Text(context.tr('settings.sortDate')),
                  ),
                  DropdownMenuItem(
                    value: 'size',
                    child: Text(context.tr('settings.sortSize')),
                  ),
                  DropdownMenuItem(
                    value: 'type',
                    child: Text(context.tr('settings.sortType')),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) settings.setSortBy(v);
                },
              ),
            ),
          ]),
          _group(context, context.tr('settings.editor'), [
            _slider(
              context,
              context.tr('settings.pageWidth'),
              settings.pageWidth,
              560,
              1200,
              (v) => settings.setDouble('pageWidth', v),
              suffix: 'px',
            ),
            _slider(
              context,
              context.tr('settings.defaultZoom'),
              settings.defaultZoom,
              0.5,
              2.0,
              (v) => settings.setDouble('defaultZoom', v),
              suffix: 'x',
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('settings.showMarks')),
              value: settings.showFormattingMarks,
              onChanged: (v) => settings.setBool('showMarks', v),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.timer_outlined),
              title: Text(context.tr('settings.autosave')),
              trailing: DropdownButton<int>(
                value: settings.autosaveMinutes,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(
                    value: 0,
                    child: Text(context.tr('settings.autosaveOff')),
                  ),
                  DropdownMenuItem(
                    value: 1,
                    child: Text(context.tr('settings.minutes1')),
                  ),
                  DropdownMenuItem(
                    value: 5,
                    child: Text(context.tr('settings.minutes5')),
                  ),
                  DropdownMenuItem(
                    value: 15,
                    child: Text(context.tr('settings.minutes15')),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) settings.setAutosaveMinutes(v);
                },
              ),
            ),
          ]),
          _group(context, context.tr('settings.storage'), [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.add_link_rounded),
              title: Text(context.tr('settings.addLocation')),
              subtitle: Text(context.tr('settings.addLocationHint')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final root = await BrowserRoots.requestNewRoot(SafService.instance);
                if (root != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.trf('settings.added', {'label': root.label}),
                      ),
                    ),
                  );
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_rounded),
              title: Text(context.tr('settings.clearRecents')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => settings.clearRecents(),
            ),
          ]),
          _group(context, context.tr('settings.language'), [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
              child: SegmentedButton<AppLanguage>(
                segments: [
                  ButtonSegment(
                    value: AppLanguage.ru,
                    label: Text(context.tr('lang.ru')),
                    icon: const Icon(Icons.translate_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: AppLanguage.en,
                    label: Text(context.tr('lang.en')),
                    icon: const Icon(Icons.language_rounded, size: 16),
                  ),
                ],
                selected: {settings.language},
                onSelectionChanged: (s) => settings.setLanguage(s.first),
              ),
            ),
          ]),
          _group(context, context.tr('settings.about'), [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.help_outline_rounded),
              title: Text(context.tr('settings.manual')),
              subtitle: Text(context.tr('settings.manualHint')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HelpScreen()),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('OpenFiles'),
              subtitle: Text(context.tr('settings.version')),
            ),
          ]),
          const SizedBox(height: AppSpace.md),
          const AuthorCard(),
          const SizedBox(height: AppSpace.xl),
          Center(
            child: Text(
              context.tr('settings.builtWith'),
              style: context.t.labelSmall?.copyWith(color: c.textFaint),
            ),
          ),
        ],
      ),
    );
  }
  Widget _group(BuildContext context, String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpace.xs, bottom: AppSpace.sm),
            child: Text(
              title.toUpperCase(),
              style: context.t.labelSmall?.copyWith(
                color: context.c.primary,
                letterSpacing: 1.1,
              ),
            ),
          ),
          RoundedPanel(child: Column(children: children)),
        ],
      ),
    );
  }
  Widget _themeRow(BuildContext context, AppSettings settings) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpace.sm),
          Text('Тема', style: context.t.bodyLarge),
          const SizedBox(height: AppSpace.sm),
          SegmentedButton<AppThemeMode>(
            segments: const [
              ButtonSegment(
                value: AppThemeMode.system,
                label: Text('Авто'),
                icon: Icon(Icons.brightness_auto_rounded, size: 16),
              ),
              ButtonSegment(
                value: AppThemeMode.light,
                label: Text('Светлая'),
                icon: Icon(Icons.light_mode_outlined, size: 16),
              ),
              ButtonSegment(
                value: AppThemeMode.dark,
                label: Text('Тёмная'),
                icon: Icon(Icons.dark_mode_outlined, size: 16),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (s) => settings.setThemeMode(s.first),
          ),
          const SizedBox(height: AppSpace.sm),
        ],
      ),
    );
  }
  Widget _slider(
    BuildContext context,
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChange, {
    String suffix = '',
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: context.t.bodyLarge)),
              Text(
                '${value.toStringAsFixed(value >= 10 ? 0 : 2)}$suffix',
                style: context.t.labelMedium,
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChange,
          ),
        ],
      ),
    );
  }
}
