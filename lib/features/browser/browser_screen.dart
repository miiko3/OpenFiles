import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/fs_node.dart';
import '../../data/providers/app_settings.dart';
import '../../data/services/file_kinds.dart';
import '../../data/services/saf_service.dart';
import '../../widgets/common.dart';
import 'help_screen.dart';
import 'settings_screen.dart';
import 'viewer_host.dart';
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key, this.startLocation});
  final FsLocation? startLocation;
  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}
class _BrowserScreenState extends State<BrowserScreen> {
  final _saf = SafService.instance;
  final _scroll = ScrollController();
  final _searchController = TextEditingController();
  final List<FsLocation> _stack = [];
  List<FsNode> _entries = const [];
  TreeRoot? _currentRoot;
  bool _loading = true;
  String? _error;
  String _query = '';
  bool _searching = false;
  Timer? _searchDebounce;
  FsLocation get _here =>
      _stack.isEmpty ? (widget.startLocation ?? const FsLocation.local('/')) : _stack.last;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }
  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scroll.dispose();
    _searchController.dispose();
    super.dispose();
  }
  Future<void> _bootstrap() async {
    _saf.listenInbox(_onInboxFiles);
    final root = await _showRootIfNeeded();
    if (!mounted) return;
    if (root == null) {
      setState(() {
        _loading = false;
        _error = 'No storage access granted yet.';
      });
      return;
    }
    _currentRoot = root;
    await _open(
      FsLocation.saf(treeUri: root.treeUri, docId: root.docId),
      push: false,
    );
  }
  Future<TreeRoot?> _showRootIfNeeded() async {
    final pending = _consumePendingLocation();
    if (pending != null) return pending;
    final start = widget.startLocation;
    if (start != null) {
      return TreeRoot(
        treeUri: start.treeUri ?? '',
        docId: start.docId ?? '',
        label: 'Хранилище',
      );
    }
    final granted = await BrowserRoots.grantedRoots(_saf);
    if (granted.isEmpty) {
      return BrowserRoots.requestNewRoot(_saf);
    }
    return granted.first;
  }
  TreeRoot? _consumePendingLocation() {
    final pending = BrowserRoots.takePending();
    if (pending == null) return null;
    if (pending.isSaf) {
      return TreeRoot(
        treeUri: pending.treeUri!,
        docId: pending.docId!,
        label: 'Хранилище',
      );
    }
    return TreeRoot(treeUri: '', label: pending.path ?? 'Storage');
  }
  void _onInboxFiles(List<Map<String, dynamic>> files) {
    if (files.isEmpty) return;
    final name = files.first['name'] as String? ?? 'file';
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final mime = files.first['mime'] as String? ?? '';
      final node = FsNode(
        location: FsLocation.transient(files.first['uri'] as String),
        name: name,
        isDirectory: false,
        mime: mime,
        size: (files.first['size'] as num?)?.toInt() ?? -1,
        modified: DateTime.now(),
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ViewerHost(node: node, allowEdit: false),
        ),
      );
    });
  }
  Future<void> _open(FsLocation location, {bool push = true}) async {
    if (push && _stack.isNotEmpty) _stack.add(location);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _saf.listChildren(location);
      if (!mounted) return;
      setState(() {
        _entries = items;
        _cache = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }
  void _goUp() {
    if (_stack.isEmpty) return;
    _stack.removeLast();
    if (_stack.isEmpty) {
      _open(_stackOrRoot(), push: false);
      return;
    }
    _open(_stack.last, push: false);
  }
  void _onQueryChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _query = value.trim().toLowerCase());
    });
  }
  List<FsNode>? _cache;
  List<FsNode> get _visible {
    final settings = context.read<AppSettings>();
    final stamp = Object.hashAll([
      _entries.length,
      _query,
      settings.showHidden,
      settings.supportedOnly,
      settings.sortFoldersFirst,
      settings.sortBy,
      settings.gridView,
      if (_cache != null) _cache!.first.name,
      if (_cache != null) _cache!.last.name,
    ]);
    if (_cache != null && _cacheStamp == stamp) return _cache!;
    var items = _entries.where((e) => settings.showHidden || !e.isHidden).toList();
    if (settings.supportedOnly) {
      items = items.where((e) => e.isDirectory || isSupportedName(e.name)).toList();
    }
    if (_query.isNotEmpty) {
      items = items
          .where((e) =>
              e.name.toLowerCase().contains(_query) ||
              e.extension.contains(_query))
          .toList();
    }
    if (settings.sortFoldersFirst) {
      items.sort((a, b) {
        if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
        return _compare(a, b, settings.sortBy);
      });
    } else {
      items.sort((a, b) => _compare(a, b, settings.sortBy));
    }
    _cache = items;
    _cacheStamp = stamp;
    return items;
  }
  int _cacheStamp = 0;
  int _compare(FsNode a, FsNode b, String by) {
    switch (by) {
      case 'size':
        return b.size.compareTo(a.size);
      case 'modified':
        return b.modified.compareTo(a.modified);
      case 'type':
        final c = a.extension.compareTo(b.extension);
        return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      default:
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }
  }
  Future<void> _openEntry(FsNode node) async {
    if (node.isDirectory) {
      await _open(node.location);
      return;
    }
    await context.read<AppSettings>().addRecent(node);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ViewerHost(node: node)),
    );
    if (mounted) setState(() {});
  }
  Future<void> _createEntry({required bool directory}) async {
    final name = await _askName(
      context,
      title: directory ? 'New folder' : 'New file',
      hint: directory ? 'Folder name' : 'name.docx',
      mimeHint: !directory,
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      if (directory) {
        await _saf.createDirectory(_here, name.trim());
      } else {
        await _saf.createFile(_here, name.trim(), mimeForName(name) ?? 'text/plain');
      }
      await _open(_here, push: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
  Future<void> _rename(FsNode node) async {
    final name = await _askName(
      context,
      title: 'Переименовать',
      initial: node.name,
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await _saf.rename(node, name.trim());
      await _open(_here, push: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
  Future<void> _delete(FsNode node) async {
    final settings = context.read<AppSettings>();
    if (settings.confirmDelete) {
      final ok = await confirmDialog(
        context,
        title: 'Delete ${node.name}?',
        message: 'Это действие нельзя отменить.',
        confirmLabel: 'Удалить',
        destructive: true,
      );
      if (!ok) return;
    }
    try {
      await _saf.delete(node);
      await _open(_here, push: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
  Future<void> _showProperties(FsNode node) async {
    await showRoundedSheet<void>(
      context,
      title: node.name,
      subtitle: kindForName(node.name).label,
      child: ListView(
        shrinkWrap: true,
        children: [
          _property('Type', node.mime),
          _property('Size', formatBytes(node.size)),
          _property('Modified', _formatDate(node.modified)),
          _property('Запись', node.canWrite ? 'yes' : 'no'),
          if (node.location.treeUri != null)
            _property('Tree', node.location.treeUri!),
          if (node.location.docId != null)
            _property('Document id', node.location.docId!),
          if (node.location.path != null)
            _property('Path', node.location.path!),
        ],
      ),
    );
  }
  Widget _property(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(k, style: context.t.bodySmall),
          ),
          Expanded(
            child: SelectableText(v, style: context.t.bodyMedium),
          ),
        ],
      ),
    );
  }
  static String _formatDate(DateTime d) {
    if (d.millisecondsSinceEpoch == 0) return '--';
    final two = (int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
  Future<void> _switchRoot() async {
    final roots = await BrowserRoots.grantedRoots(_saf);
    final picked = await showRoundedSheet<String>(
      context,
      title: 'Папки доступа',
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final r in roots)
            ListTile(
              leading: const Icon(Icons.storage_rounded),
              title: Text(r.label),
              onTap: () => Navigator.of(context).pop(r.treeUri),
            ),
          ListTile(
            leading: const Icon(Icons.add_rounded),
            title: const Text('Добавить папку'),
            onTap: () => Navigator.of(context).pop('__new__'),
          ),
        ],
      ),
    );
    if (picked == null) return;
    if (picked == '__new__') {
      final root = await BrowserRoots.requestNewRoot(_saf);
      if (root == null) return;
      await BrowserRoots.save(_saf, root);
      _currentRoot = root;
      _stack.clear();
      await _open(FsLocation.saf(treeUri: root.treeUri, docId: root.docId));
      return;
    }
    final root = roots.firstWhere(
      (r) => r.treeUri == picked,
      orElse: () => roots.first,
    );
    _currentRoot = root;
    _stack.clear();
    await _open(FsLocation.saf(treeUri: root.treeUri, docId: root.docId));
  }
  Future<void> _openRecents() async {
    final settings = context.read<AppSettings>();
    final recents = settings.recents;
    await showRoundedSheet<void>(
      context,
      title: 'Недавние файлы',
      actions: [
        RoundIconButton(
          icon: Icons.delete_sweep_outlined,
          tooltip: 'Clear',
          onPressed: () async {
            await settings.clearRecents();
            if (mounted) Navigator.of(context).pop();
          },
        ),
      ],
      child: recents.isEmpty
          ? Center(child: Text('Пока ничего не открывали', style: context.t.bodySmall))
          : ListView.builder(
              shrinkWrap: true,
              itemCount: recents.length,
              itemBuilder: (context, i) {
                final node = settings.recentNode(i);
                if (node == null) return const SizedBox.shrink();
                return ListTile(
                  leading: Icon(kindForName(node.name).icon,
                      color: kindForName(node.name).accent(context.scheme)),
                  title: Text(node.name, overflow: TextOverflow.ellipsis),
                  subtitle: Text(formatBytes(node.size)),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ViewerHost(node: node),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
  Future<void> _showSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final settings = context.watch<AppSettings>();
    final items = _visible;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildBar(c, items, settings),
            if (_stack.isNotEmpty) _buildPathBar(c),
            Expanded(child: _buildBody(c, items, settings)),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'newFolder',
            backgroundColor: c.surface,
            foregroundColor: c.primary,
            onPressed: () => _createEntry(directory: true),
            tooltip: 'Новая папка',
            child: const Icon(Icons.create_new_folder_outlined),
          ),
          const SizedBox(height: AppSpace.sm),
          FloatingActionButton(
            heroTag: 'newFile',
            onPressed: () => _createEntry(directory: false),
            tooltip: 'Новый файл',
            child: const Icon(Icons.note_add_outlined),
          ),
        ],
      ),
    );
  }
  Widget _buildBar(AppColors c, List<FsNode> items, AppSettings settings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md,
        AppSpace.sm,
        AppSpace.md,
        AppSpace.sm,
      ),
      child: Row(
        children: [
          if (_stack.isNotEmpty)
            RoundIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: 'Up',
              size: 36,
              iconSize: 16,
              onPressed: _goUp,
            )
          else
            const SizedBox(width: 36),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppDuration.fast,
              child: _searching
                  ? TextField(
                      key: const ValueKey('search'),
                      controller: _searchController,
                      autofocus: true,
                      onChanged: _onQueryChanged,
                      decoration: InputDecoration(
                        hintText: 'Поиск в папке',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        suffixIcon: RoundIconButton(
                          icon: Icons.close_rounded,
                          size: 32,
                          iconSize: 16,
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searching = false;
                              _query = '';
                            });
                          },
                        ),
                      ),
                    )
                  : GestureDetector(
                      key: const ValueKey('title'),
                      onTap: _switchRoot,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  _titleLabel(),
                                  style: context.t.titleLarge,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.expand_more_rounded, size: 18),
                            ],
                          ),
                          Text(
                            '${items.length} items',
                            style: context.t.labelSmall,
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          RoundIconButton(
            icon: Icons.search_rounded,
            tooltip: 'Search',
            active: _searching,
            size: 36,
            iconSize: 18,
            onPressed: () => setState(() => _searching = !_searching),
          ),
          RoundIconButton(
            icon: Icons.history_rounded,
            tooltip: 'Recent',
            size: 36,
            iconSize: 18,
            onPressed: _openRecents,
          ),
          RoundIconButton(
            icon: settings.supportedOnly
                ? Icons.filter_alt_outlined
                : Icons.filter_alt_off_outlined,
            tooltip: settings.supportedOnly ? 'Только поддерживаемые' : 'Все файлы',
            active: settings.supportedOnly,
            size: 36,
            iconSize: 18,
            onPressed: () => setState(
              () => settings.setBool('supportedOnly', !settings.supportedOnly),
            ),
          ),
          RoundIconButton(
            icon: settings.gridView
                ? Icons.view_agenda_outlined
                : Icons.grid_view_rounded,
            tooltip: settings.gridView ? 'List' : 'Grid',
            size: 36,
            iconSize: 18,
            onPressed: () =>
                settings.setBool('gridView', !settings.gridView),
          ),
          RoundIconButton(
            icon: Icons.tune_rounded,
            tooltip: 'Настройки',
            size: 36,
            iconSize: 18,
            onPressed: _showSettings,
          ),
          RoundIconButton(
            icon: Icons.help_outline_rounded,
            tooltip: 'Инструкция',
            size: 36,
            iconSize: 18,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HelpScreen()),
            ),
          ),
        ],
      ),
    );
  }
  String _titleLabel() {
    if (_here.isLocal) return _here.path!.split(RegExp(r'[/\\]')).last;
    final doc = _here.docId ?? '';
    return _currentRoot?.label ?? (doc.isEmpty ? 'Storage' : doc.split('/').last);
  }
  Widget _buildPathBar(AppColors c) {
    return Container(
      height: 34,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _stack.length,
        itemBuilder: (context, i) {
          final label = (_stack[i].docId ?? '').split('/').last;
          final isLast = i == _stack.length - 1;
          return Row(
            children: [
              if (i > 0)
                Text('  /  ', style: context.t.labelSmall)
              else
                Text('${_currentRoot?.label ?? ''}  /  ',
                    style: context.t.labelSmall),
              GestureDetector(
                onTap: () {
                  _stack.removeRange(i, _stack.length);
                  _open(_stack.isEmpty ? _stackOrRoot() : _stack.last,
                      push: false);
                },
                child: Text(
                  label.isEmpty ? 'storage' : label,
                  style: context.t.labelMedium?.copyWith(
                    color: isLast ? c.primary : c.textDim,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  FsLocation _stackOrRoot() {
    final root = _currentRoot;
    return root == null
        ? const FsLocation.local('/')
        : FsLocation.saf(treeUri: root.treeUri, docId: root.docId);
  }
  Widget _buildBody(AppColors c, List<FsNode> items, AppSettings settings) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 3));
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.folder_off_outlined,
        title: 'Не удалось открыть папку',
        message: _error,
        action: PillButton(
          label: 'Выбрать папку',
          icon: Icons.storage_rounded,
          primary: true,
          onPressed: _switchRoot,
        ),
      );
    }
    if (items.isEmpty) {
      return EmptyState(
        icon: _query.isEmpty ? Icons.folder_open_rounded : Icons.search_off_rounded,
        title: _query.isEmpty ? 'Folder is empty' : 'Nothing found',
        message: _query.isEmpty
            ? 'Create a file or folder to get started.'
            : 'Try another search term.',
      );
    }
    if (settings.gridView) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.md,
          AppSpace.sm,
          AppSpace.md,
          120,
        ),
        controller: _scroll,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 150,
          mainAxisSpacing: AppSpace.sm,
          crossAxisSpacing: AppSpace.sm,
          childAspectRatio: 0.88,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) => _gridTile(items[i]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md,
        AppSpace.xs,
        AppSpace.md,
        120,
      ),
      controller: _scroll,
      itemCount: items.length,
      itemBuilder: (context, i) => _listTile(items[i]),
    );
  }
  Widget _gridTile(FsNode node) {
    final c = context.c;
    final kind = node.isDirectory ? null : kindForName(node.name);
    final tint = kind?.accent(context.scheme) ?? c.accent;
    return GestureDetector(
      onTap: () => _openEntry(node),
      onLongPress: () => _showMenu(node),
      child: RoundedPanel(
        padding: const EdgeInsets.all(AppSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 54,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                borderRadius: AppRadius.md,
              ),
              child: Icon(
                node.isDirectory ? Icons.folder_rounded : kind!.icon,
                color: tint,
                size: 28,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              node.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.t.labelMedium?.copyWith(color: c.text),
            ),
            if (!node.isDirectory)
              Text(
                formatBytes(node.size),
                style: context.t.labelSmall?.copyWith(color: c.textFaint),
              ),
          ],
        ),
      ),
    );
  }
  Widget _listTile(FsNode node) {
    final c = context.c;
    final kind = kindForName(node.name);
    final tint = kind.accent(context.scheme);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.md,
        child: InkWell(
          borderRadius: AppRadius.md,
          onTap: () => _openEntry(node),
          onLongPress: () => _showMenu(node),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.sm,
              vertical: AppSpace.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.14),
                    borderRadius: AppRadius.md,
                  ),
                  child: Icon(
                    node.isDirectory ? Icons.folder_rounded : kind.icon,
                    color: tint,
                    size: 21,
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.t.bodyLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        node.isDirectory
                            ? 'Folder'
                            : '${kind.label}  ·  ${formatBytes(node.size)}',
                        style: context.t.labelSmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  _BrowserScreenState._formatDate(node.modified),
                  style: context.t.labelSmall?.copyWith(color: c.textFaint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Future<void> _showMenu(FsNode node) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline_rounded),
              title: const Text('Переименовать'),
              onTap: () {
                Navigator.of(ctx).pop();
                _rename(node);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Удалить'),
              onTap: () {
                Navigator.of(ctx).pop();
                _delete(node);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('Свойства'),
              onTap: () {
                Navigator.of(ctx).pop();
                _showProperties(node);
              },
            ),
            if (!node.isDirectory)
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Поделиться'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final path = await _saf.materialize(node);
                  await _saf.shareLocal(path, node.mime);
                },
              ),
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      ),
    );
  }
}
Future<String?> _askName(
  BuildContext context, {
  required String title,
  String? initial,
  String? hint,
  bool mimeHint = false,
}) {
  final controller = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: hint),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
          if (mimeHint && (initial?.contains('.') ?? false)) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              'OpenFiles will pick the editor by extension.',
              style: ctx.t.bodySmall,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
class BrowserRoots {
  static const _rootsKey = 'treeRoots';
  static FsLocation? _pending;
  static Future<List<TreeRoot>> grantedRoots(SafService saf) async {
    final prefs = await _prefs();
    final raw = prefs.getStringList(_rootsKey) ?? const <String>[];
    final out = <TreeRoot>[];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item) as Map<String, dynamic>;
        final treeUri = decoded['treeUri'] as String;
        if (await saf.hasPermission(treeUri)) {
          out.add(TreeRoot.fromJson(decoded));
        }
      } catch (_) {}
    }
    return out;
  }
  static Future<TreeRoot?> requestNewRoot(SafService saf) async {
    final root = await saf.pickTree();
    if (root != null) await save(saf, root);
    return root;
  }
  static Future<void> save(SafService saf, TreeRoot root) async {
    final prefs = await _prefs();
    final existing = prefs.getStringList(_rootsKey) ?? const <String>[];
    final items = [
      jsonEncode(root.toJson()),
      ...existing.where((e) => !e.contains(root.treeUri)),
    ];
    await prefs.setStringList(_rootsKey, items.take(10).toList());
  }
  static void setPending(FsLocation location) => _pending = location;
  static FsLocation? takePending() {
    final value = _pending;
    _pending = null;
    return value;
  }
  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();
}