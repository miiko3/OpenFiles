import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/l10n.dart';
import '../models/fs_node.dart';
enum AppThemeMode { system, light, dark }
class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs) {
    themeMode = AppThemeMode.values[
        _prefs.getInt('themeMode') ?? AppThemeMode.system.index];
    showHidden = _prefs.getBool('showHidden') ?? false;
    sortFoldersFirst = _prefs.getBool('sortFoldersFirst') ?? true;
    sortBy = _prefs.getString('sortBy') ?? 'name';
    gridView = _prefs.getBool('gridView') ?? false;
    confirmDelete = _prefs.getBool('confirmDelete') ?? true;
    supportedOnly = _prefs.getBool('supportedOnly') ?? true;
    defaultZoom = _prefs.getDouble('defaultZoom') ?? 1.0;
    showFormattingMarks = _prefs.getBool('showMarks') ?? false;
    autosaveMinutes = _prefs.getInt('autosaveMinutes') ?? 5;
    pageWidth = _prefs.getDouble('pageWidth') ?? 820;
    textScale = _prefs.getDouble('textScale') ?? 1.0;
    final langIndex = _prefs.getInt('language') ?? AppLanguage.ru.index;
    language = AppLanguage.values[langIndex.clamp(0, AppLanguage.values.length - 1)];
  }
  final SharedPreferences _prefs;
  late AppThemeMode themeMode;
  late bool showHidden;
  late bool sortFoldersFirst;
  late String sortBy;
  late bool gridView;
  late bool confirmDelete;
  late bool supportedOnly;
  late double defaultZoom;
  late bool showFormattingMarks;
  late int autosaveMinutes;
  late double pageWidth;
  late double textScale;
  late AppLanguage language;
  ThemeMode get flutterThemeMode => switch (themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };
  Future<void> setThemeMode(AppThemeMode value) async {
    themeMode = value;
    await _prefs.setInt('themeMode', value.index);
    notifyListeners();
  }
  Future<void> setLanguage(AppLanguage value) async {
    language = value;
    L10n.language = value;
    L10n.notifier.value = value;
    await _prefs.setInt('language', value.index);
    notifyListeners();
  }
  Future<void> setBool(String key, bool value) async {
    switch (key) {
      case 'showHidden':
        showHidden = value;
      case 'sortFoldersFirst':
        sortFoldersFirst = value;
      case 'gridView':
        gridView = value;
      case 'confirmDelete':
        confirmDelete = value;
      case 'showMarks':
        showFormattingMarks = value;
      case 'supportedOnly':
        supportedOnly = value;
    }
    await _prefs.setBool(key, value);
    notifyListeners();
  }
  Future<void> setDouble(String key, double value) async {
    switch (key) {
      case 'defaultZoom':
        defaultZoom = value;
      case 'pageWidth':
        pageWidth = value;
      case 'textScale':
        textScale = value;
    }
    await _prefs.setDouble(key, value);
    notifyListeners();
  }
  Future<void> setSortBy(String value) async {
    sortBy = value;
    await _prefs.setString('sortBy', value);
    notifyListeners();
  }
  Future<void> setAutosaveMinutes(int value) async {
    autosaveMinutes = value;
    await _prefs.setInt('autosaveMinutes', value);
    notifyListeners();
  }
  List<Map<String, dynamic>> get recents {
    final raw = _prefs.getStringList('recents') ?? const <String>[];
    final out = <Map<String, dynamic>>[];
    for (final entry in raw) {
      try {
        final decoded = jsonDecode(entry);
        if (decoded is Map<String, dynamic>) out.add(decoded);
      } catch (_) {}
    }
    return out;
  }
  Future<void> addRecent(FsNode node) async {
    final items = <Map<String, dynamic>>[
      {
        'name': node.name,
        'mime': node.mime,
        'treeUri': node.location.treeUri,
        'docId': node.location.docId,
        'path': node.location.path,
        'size': node.size,
        'modified': node.modified.millisecondsSinceEpoch,
      },
      ...recents.where((e) => e['name'] != node.name),
    ].take(30).toList();
    await _prefs.setStringList(
      'recents',
      items.map(jsonEncode).toList(),
    );
    notifyListeners();
  }
  Future<void> removeRecent(String name) async {
    final items = recents.where((e) => e['name'] != name).toList();
    await _prefs.setStringList('recents', items.map(jsonEncode).toList());
    notifyListeners();
  }
  Future<void> clearRecents() async {
    await _prefs.remove('recents');
    notifyListeners();
  }
  FsNode? recentNode(int index) {
    final r = recents;
    if (index < 0 || index >= r.length) return null;
    final m = r[index];
    final FsLocation location;
    try {
      location = FsLocation.fromMap(m);
    } catch (_) {
      return null;
    }
    return FsNode(
      location: location,
      name: (m['name'] as String?) ?? 'file',
      isDirectory: false,
      mime: (m['mime'] as String?) ?? 'application/octet-stream',
      size: (m['size'] as num?)?.toInt() ?? -1,
      modified: DateTime.fromMillisecondsSinceEpoch(
        (m['modified'] as num?)?.toInt() ?? 0,
      ),
      canWrite: true,
    );
  }
}
