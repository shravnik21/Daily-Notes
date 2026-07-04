import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotes();
  }

  Future<void> _fetchNotes() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('notes')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        _notes = List<Map<String, dynamic>>.from(data);
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

  Future<void> _deleteNote(String id) async {
    try {
      await _supabase.from('notes').delete().eq('id', id);
      _fetchNotes(); // refresh list
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  void _openNoteEditor({Map<String, dynamic>? existingNote}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => NoteEditorSheet(existingNote: existingNote),
    ).then((_) => _fetchNotes()); // refresh after add/edit closes
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _supabase.auth.signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchNotes,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _notes.isEmpty
                ? ListView(
                    // ListView so pull-to-refresh still works on empty state
                    children: const [
                      SizedBox(height: 200),
                      Center(child: Text('No notes yet. Tap + to add one.')),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _notes.length,
                    itemBuilder: (context, index) {
                      final note = _notes[index];
                      return Card(
                        child: ListTile(
                          title: Text(note['title'] ?? ''),
                          subtitle: Text(
                            note['content'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _openNoteEditor(existingNote: note),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteNote(note['id']),
                          ),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openNoteEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Bottom sheet used for both creating a new note and editing an existing one.
class NoteEditorSheet extends StatefulWidget {
  final Map<String, dynamic>? existingNote;

  const NoteEditorSheet({super.key, this.existingNote});

  @override
  State<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<NoteEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  bool _isSaving = false;

  bool get _isEditing => widget.existingNote != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existingNote?['title'] ?? '');
    _contentController = TextEditingController(text: widget.existingNote?['content'] ?? '');
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser!.id;

    try {
      if (_isEditing) {
        await supabase.from('notes').update({
          'title': _titleController.text.trim(),
          'content': _contentController.text.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.existingNote!['id']);
      } else {
        await supabase.from('notes').insert({
          'user_id': userId,
          'title': _titleController.text.trim(),
          'content': _contentController.text.trim(),
        });
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEditing ? 'Edit Note' : 'New Note',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Content',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isEditing ? 'Update' : 'Add Note'),
          ),
        ],
      ),
    );
  }
}