import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../note_colors.dart';

class NoteEditorScreen extends StatefulWidget {
  final Map<String, dynamic>? existingNote;

  const NoteEditorScreen({super.key, this.existingNote});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  bool _isSaving = false;
  bool _isPinned = false;
  int _colorIndex = 0;

  bool get _isEditing => widget.existingNote != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existingNote?['title'] ?? '');
    _contentController = TextEditingController(text: widget.existingNote?['content'] ?? '');
    _isPinned = widget.existingNote?['is_pinned'] == true;
    _colorIndex = (widget.existingNote?['color'] as int?) ?? 0;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Give your note a title first')));
      return;
    }

    setState(() => _isSaving = true);
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser!.id;

    try {
      if (_isEditing) {
        await supabase.from('notes').update({
          'title': _titleController.text.trim(),
          'content': _contentController.text.trim(),
          'is_pinned': _isPinned,
          'color': _colorIndex,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.existingNote!['id']);
      } else {
        await supabase.from('notes').insert({
          'user_id': userId,
          'title': _titleController.text.trim(),
          'content': _contentController.text.trim(),
          'is_pinned': _isPinned,
          'color': _colorIndex,
        });
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete note?'),
            content: const Text('This cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton.tonal(
                style: FilledButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    try {
      await Supabase.instance.client
          .from('notes')
          .delete()
          .eq('id', widget.existingNote!['id']);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = resolveNoteColor(context, _colorIndex);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? noteColorsDark : noteColors;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _isPinned ? 'Unpin' : 'Pin',
            onPressed: () => setState(() => _isPinned = !_isPinned),
            icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined),
          ),
          if (_isEditing)
            IconButton(
              tooltip: 'Delete',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(hintText: 'Title', border: InputBorder.none),
              ),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  expands: true,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                  decoration:
                      const InputDecoration(hintText: 'Start writing...', border: InputBorder.none),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: palette.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final selected = i == _colorIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _colorIndex = i),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: palette[i],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.black12,
                            width: selected ? 3 : 1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                child: _isSaving
                    ? const SizedBox(
                        height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEditing ? 'Update note' : 'Save note'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}