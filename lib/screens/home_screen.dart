import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../note_colors.dart';
import 'package:notes_app/ theme_notifier.dart';
import '../utils/format_timestamp.dart';
import 'note_editor_screen.dart';

enum NoteSort { newest, oldest, titleAz }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _allNotes = [];
  bool _isLoading = true;
  String _query = '';
  NoteSort _sort = NoteSort.newest;

  @override
  void initState() {
    super.initState();
    _fetchNotes();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchNotes() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('notes')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        _allNotes = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load notes: $e')),
      );
    }
  }

  List<Map<String, dynamic>> get _visibleNotes {
    var notes = _allNotes.where((n) {
      if (_query.isEmpty) return true;
      final title = (n['title'] ?? '').toString().toLowerCase();
      final content = (n['content'] ?? '').toString().toLowerCase();
      return title.contains(_query) || content.contains(_query);
    }).toList();

    switch (_sort) {
      case NoteSort.newest:
        notes.sort((a, b) =>
            (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));
        break;
      case NoteSort.oldest:
        notes.sort((a, b) =>
            (a['created_at'] ?? '').toString().compareTo((b['created_at'] ?? '').toString()));
        break;
      case NoteSort.titleAz:
        notes.sort((a, b) => (a['title'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b['title'] ?? '').toString().toLowerCase()));
        break;
    }

    final pinned = notes.where((n) => n['is_pinned'] == true).toList();
    final rest = notes.where((n) => n['is_pinned'] != true).toList();
    return [...pinned, ...rest];
  }

  Future<void> _togglePin(Map<String, dynamic> note) async {
    final newValue = !(note['is_pinned'] == true);
    setState(() => note['is_pinned'] = newValue);
    try {
      await _supabase.from('notes').update({'is_pinned': newValue}).eq('id', note['id']);
    } catch (e) {
      setState(() => note['is_pinned'] = !newValue);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update pin — did you run the SQL migration? ($e)')),
      );
    }
  }

  Future<bool> _confirmDelete(Map<String, dynamic> note) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete note?'),
            content: Text('"${(note['title'] ?? 'Untitled')}" will be permanently deleted.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteNote(Map<String, dynamic> note) async {
    setState(() => _allNotes.removeWhere((n) => n['id'] == note['id']));
    try {
      await _supabase.from('notes').delete().eq('id', note['id']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note deleted')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _allNotes.insert(0, note));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? existingNote}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => NoteEditorScreen(existingNote: existingNote)),
    );
    if (changed == true) _fetchNotes();
  }

  @override
  Widget build(BuildContext context) {
    final notes = _visibleNotes;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchNotes,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(notes.length)),
              if (_isLoading)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              else if (notes.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  sliver: SliverList.separated(
                    itemCount: notes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return TweenAnimationBuilder<double>(
                        key: ValueKey('anim_${note['id']}'),
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 220 + index * 25),
                        curve: Curves.easeOut,
                        builder: (context, value, child) => Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, (1 - value) * 16),
                            child: child,
                          ),
                        ),
                        child: _NoteCard(
                          note: note,
                          onTap: () => _openEditor(existingNote: note),
                          onPin: () => _togglePin(note),
                          onConfirmDelete: () => _confirmDelete(note),
                          onDismissed: () => _deleteNote(note),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New note'),
      ),
    );
  }

  Widget _buildHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Notes',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      '$count note${count == 1 ? '' : 's'}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Theme.of(context).colorScheme.outline),
                    ),
                  ],
                ),
              ),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeController,
                builder: (context, mode, _) => IconButton(
                  tooltip: 'Toggle theme',
                  onPressed: themeController.toggle,
                  icon: Icon(mode == ThemeMode.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined),
                ),
              ),
              PopupMenuButton<NoteSort>(
                tooltip: 'Sort',
                icon: const Icon(Icons.sort_rounded),
                initialValue: _sort,
                onSelected: (v) => setState(() => _sort = v),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: NoteSort.newest, child: Text('Newest first')),
                  PopupMenuItem(value: NoteSort.oldest, child: Text('Oldest first')),
                  PopupMenuItem(value: NoteSort.titleAz, child: Text('Title A–Z')),
                ],
              ),
              IconButton(
                tooltip: 'Log out',
                onPressed: () => _supabase.auth.signOut(),
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search notes...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => _searchController.clear(),
                    ),
              filled: true,
              fillColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _query.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSearching ? Icons.search_off_rounded : Icons.note_alt_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              isSearching ? 'No notes match "${_searchController.text}"' : 'No notes yet',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (!isSearching)
              Text(
                'Tap "New note" to write your first one.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Map<String, dynamic> note;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final Future<bool> Function() onConfirmDelete;
  final VoidCallback onDismissed;

  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onPin,
    required this.onConfirmDelete,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final isPinned = note['is_pinned'] == true;
    final bg = resolveNoteColor(context, note['color'] as int?);

    return Dismissible(
      key: ValueKey(note['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) => onConfirmDelete(),
      onDismissed: (_) => onDismissed(),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (note['title'] ?? '').toString().isEmpty
                            ? 'Untitled'
                            : note['title'],
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: onPin,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                          size: 20,
                          color: isPinned
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
                if ((note['content'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    note['content'],
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.3),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  formatTimestamp(note['updated_at'] ?? note['created_at']),
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}