/// View notes functionality. This reads back the notes saved to your Solid Pod
/// by the Add Note page, decrypting each one and listing its title and created
/// time.

library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:newapp/constants/theme.dart';

import 'package:solidpod/solidpod.dart';

import 'package:solidui/solidui.dart';

/// A single note read back from the POD.

class _Note {
  const _Note({
    required this.fileName,
    required this.title,
    required this.description,
    required this.createdAt,
  });

  final String fileName;
  final String title;
  final String description;
  final DateTime? createdAt;
}

class ViewNotes extends StatefulWidget {
  const ViewNotes({super.key});

  @override
  State<ViewNotes> createState() => _ViewNotesState();
}

class _ViewNotesState extends State<ViewNotes> {
  bool _isLoading = true;
  List<_Note> _notes = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  /// Extract the created time encoded in the note file name. The Add Note page
  /// names files `note_<millisecondsSinceEpoch>.json.enc.ttl`.

  DateTime? _createdAtFromFileName(String fileName) {
    final match = RegExp(r'note_(\d+)\.json').firstMatch(fileName);
    if (match == null) return null;
    final millis = int.tryParse(match.group(1)!);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);

    try {
      if (!await isUserLoggedIn()) {
        throw NotLoggedInException('User must be logged in to view notes.');
      }

      if (!mounted) return;
      await getKeyFromUserIfRequired(context, widget);

      // List every file in the app's POD data directory and keep only the
      // notes saved by the Add Note page.
      final fileNames = (await getResources())
          .where((name) => name.startsWith('note_') && name.contains('.json'))
          .toList();

      final notes = <_Note>[];
      for (final fileName in fileNames) {
        // Read and decrypt each note, then parse the JSON string back.
        final jsonString = await readPod(fileName);
        final data = jsonDecode(jsonString) as Map<String, dynamic>;

        notes.add(
          _Note(
            fileName: fileName,
            title: (data['title'] as String?) ?? '(untitled)',
            description: (data['description'] as String?) ?? '',
            createdAt: _createdAtFromFileName(fileName),
          ),
        );
      }

      // Show the most recent notes first.
      notes.sort((a, b) {
        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });

      if (!mounted) return;
      setState(() => _notes = notes);
    } on NotLoggedInException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to be logged in to view notes.'),
          backgroundColor: AppColors.bad,
        ),
      );
    } on AccessForbiddenException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission denied while reading notes.'),
          backgroundColor: AppColors.bad,
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load notes: $e'),
          backgroundColor: AppColors.bad,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showNote(_Note note) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(note.title),
        content: SingleChildScrollView(
          child: Text(note.description),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.note,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text('No notes saved yet.'),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadNotes,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotes,
      child: ListView.builder(
        padding: const EdgeInsets.all(24.0),
        itemCount: _notes.length,
        itemBuilder: (context, index) {
          final note = _notes[index];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.note),
              title: Text(note.title),
              subtitle: Text(
                note.createdAt != null
                    ? 'Created ${note.createdAt}'
                    : note.fileName,
              ),
              onTap: () => _showNote(note),
            ),
          );
        },
      ),
    );
  }
}
