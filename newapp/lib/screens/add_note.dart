/// Add note functionality. This is a simple example of how to add a note to your Solid Pod using Solidpod

library;

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:solidpod/solidpod.dart';

import 'package:solidui/solidui.dart';

class AddNote extends StatefulWidget {
  const AddNote({super.key});

  @override
  State<AddNote> createState() => _AddNoteState();
}

class _AddNoteState extends State<AddNote> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      if (!await isUserLoggedIn()) return;

      if (!mounted) return;
      await getKeyFromUserIfRequired(context, widget);

      // Encode the data to a JSON string
      final jsonString = jsonEncode({
        'title': _titleController.text,
        'description': _descriptionController.text,
      });
      final fileName = 'note_${DateTime.now().millisecondsSinceEpoch}'
          '.json.enc.ttl';

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);

      // Write the data to the POD
      await writePod(fileName, jsonString, encrypted: true);

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Note saved to POD.'),
          backgroundColor: Colors.green,
        ),
      );

      _titleController.clear();
      _descriptionController.clear();
    } on NotLoggedInException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to be logged in to save a note.'),
          backgroundColor: Colors.red,
        ),
      );
    } on AccessForbiddenException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission denied while saving the note.'),
          backgroundColor: Colors.red,
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save note: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.note_add,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Save Note',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Please enter a title'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 4,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Please enter a description'
                            : null,
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _onSave,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save to POD'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}