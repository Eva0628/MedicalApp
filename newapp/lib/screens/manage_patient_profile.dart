/// Patient-profile editor for the Health Timeline.
///
/// Lets the user enter their own profile — demographics, current medications, a
/// medication-change timeline, a lab-result trend (e.g. TSH) and a symptom
/// frequency trend (e.g. migraine) — and saves it to their Solid Pod as a single
/// encrypted JSON document (`patient_profile.json.enc.ttl`).
///
/// On open it prefills any profile already saved to the POD, so this doubles as
/// an "edit my timeline" screen. The Health Timeline page then reads this file
/// back and renders the real data — no fictional sample data anywhere.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:newapp/constants/theme.dart';

import 'package:solidpod/solidpod.dart';
import 'package:solidui/solidui.dart';

import 'package:newapp/screens/patient_data.dart';

/// Read the saved [PatientProfile] from the POD, or null if none exists yet.
Future<PatientProfile?> loadPatientProfile(
  BuildContext context,
  Widget parent,
) async {
  if (!await isUserLoggedIn()) {
    throw NotLoggedInException('User must be logged in to load the profile.');
  }
  if (!context.mounted) return null;
  await getKeyFromUserIfRequired(context, parent);

  final exists = (await getResources()).contains(kPatientProfileFileName);
  if (!exists) return null;

  final jsonString = await readPod(kPatientProfileFileName);
  final data = jsonDecode(jsonString) as Map<String, dynamic>;
  return PatientProfile.fromJson(data);
}

class ManagePatientProfile extends StatefulWidget {
  const ManagePatientProfile({super.key});

  @override
  State<ManagePatientProfile> createState() => _ManagePatientProfileState();
}

class _ManagePatientProfileState extends State<ManagePatientProfile> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _genderController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _conditionsController = TextEditingController();

  final List<_MedRow> _meds = [];
  final List<_EventRow> _events = [];
  final List<_LabRow> _labs = [];
  final List<_SymptomRow> _symptoms = [];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _conditionsController.dispose();
    for (final r in _meds) {
      r.dispose();
    }
    for (final r in _events) {
      r.dispose();
    }
    for (final r in _labs) {
      r.dispose();
    }
    for (final r in _symptoms) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _prefill() async {
    try {
      final profile = await loadPatientProfile(context, widget);
      if (!mounted) return;
      if (profile != null) {
        _nameController.text = profile.name;
        _ageController.text = profile.age == 0 ? '' : '${profile.age}';
        _genderController.text = profile.gender;
        _heightController.text =
            profile.heightCm == 0 ? '' : '${profile.heightCm}';
        _weightController.text =
            profile.weightKg == 0 ? '' : '${profile.weightKg}';
        _conditionsController.text = profile.conditions.join(', ');
        for (final m in profile.currentMedications) {
          _meds.add(_MedRow.from(m));
        }
        for (final e in profile.medicationTimeline) {
          _events.add(_EventRow.from(e));
        }
        for (final l in profile.tshHistory) {
          _labs.add(_LabRow.from(l));
        }
        for (final s in profile.migraineFrequency) {
          _symptoms.add(_SymptomRow.from(s));
        }
      }
    } on NotLoggedInException {
      _snack('You need to be logged in to edit your profile.', isError: true);
    } on Exception catch (e) {
      _snack('Failed to load profile: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.bad : AppColors.good,
      ),
    );
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    // Skip any fully-empty repeated rows so users can leave blank rows around.
    final meds = _meds.where((r) => r.name.text.trim().isNotEmpty).toList();
    final events =
        _events.where((r) => r.medication.text.trim().isNotEmpty).toList();
    final labs = _labs.where((r) => r.value.text.trim().isNotEmpty).toList();
    final symptoms =
        _symptoms.where((r) => r.episodes.text.trim().isNotEmpty).toList();

    final profile = PatientProfile(
      name: _nameController.text.trim(),
      age: int.tryParse(_ageController.text.trim()) ?? 0,
      gender: _genderController.text.trim(),
      heightCm: double.tryParse(_heightController.text.trim()) ?? 0,
      weightKg: double.tryParse(_weightController.text.trim()) ?? 0,
      conditions: _conditionsController.text
          .split(',')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList(),
      currentMedications: meds.map((r) => r.toModel()).toList(),
      medicationTimeline: events.map((r) => r.toModel()).toList()
        ..sort((a, b) => a.date.compareTo(b.date)),
      tshHistory: labs.map((r) => r.toModel()).toList()
        ..sort((a, b) => a.date.compareTo(b.date)),
      migraineFrequency: symptoms.map((r) => r.toModel()).toList()
        ..sort((a, b) => a.date.compareTo(b.date)),
    );

    setState(() => _isSaving = true);
    try {
      if (!await isUserLoggedIn()) {
        throw NotLoggedInException('Log in first.');
      }
      if (!mounted) return;
      await getKeyFromUserIfRequired(context, widget);

      await writePod(
        kPatientProfileFileName,
        jsonEncode(profile.toJson()),
        encrypted: true,
        // The profile lives at a fixed filename, so saving again after the
        // first time means updating the existing file, not creating a new one.
        overwrite: true,
      );
      _snack('Profile saved to your POD.');
    } on NotLoggedInException {
      _snack('You need to be logged in to save your profile.', isError: true);
    } on AccessForbiddenException {
      _snack('Permission denied while saving your profile.', isError: true);
    } on Exception catch (e) {
      _snack('Failed to save profile: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'My Health Timeline',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your details below. Everything is encrypted and '
                      'saved to your own Solid Pod.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ---- Profile ----
                    _sectionTitle('Profile'),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _ageController,
                            decoration:
                                const InputDecoration(labelText: 'Age'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _genderController,
                            decoration:
                                const InputDecoration(labelText: 'Gender'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _heightController,
                            decoration: const InputDecoration(
                              labelText: 'Height (cm)',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _weightController,
                            decoration: const InputDecoration(
                              labelText: 'Weight (kg)',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _conditionsController,
                      decoration: const InputDecoration(
                        labelText: 'Conditions (comma separated)',
                        hintText: 'e.g. Hypothyroidism, Chronic Migraine',
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ---- Current medications ----
                    _sectionTitle('Current Medications'),
                    ..._meds.asMap().entries.map(
                          (e) => _medEditor(e.key, e.value),
                        ),
                    _addButton(
                      'Add medication',
                      () => setState(() => _meds.add(_MedRow())),
                    ),
                    const SizedBox(height: 28),

                    // ---- Medication timeline ----
                    _sectionTitle('Medication Timeline'),
                    ..._events.asMap().entries.map(
                          (e) => _eventEditor(e.key, e.value),
                        ),
                    _addButton(
                      'Add timeline event',
                      () => setState(() => _events.add(_EventRow())),
                    ),
                    const SizedBox(height: 28),

                    // ---- Lab trend ----
                    _sectionTitle('Lab Result Trend (e.g. TSH)'),
                    ..._labs.asMap().entries.map(
                          (e) => _labEditor(e.key, e.value),
                        ),
                    _addButton(
                      'Add lab result',
                      () => setState(() => _labs.add(_LabRow())),
                    ),
                    const SizedBox(height: 28),

                    // ---- Symptom frequency ----
                    _sectionTitle('Symptom Frequency (e.g. migraine/month)'),
                    ..._symptoms.asMap().entries.map(
                          (e) => _symptomEditor(e.key, e.value),
                        ),
                    _addButton(
                      'Add symptom point',
                      () => setState(() => _symptoms.add(_SymptomRow())),
                    ),
                    const SizedBox(height: 32),

                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _onSave,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save),
                        label: const Text('Save to POD'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );

  Widget _addButton(String label, VoidCallback onPressed) => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.add),
          label: Text(label),
        ),
      );

  Widget _rowCard({required Widget child, required VoidCallback onRemove}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: child),
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.close),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }

  Widget _medEditor(int index, _MedRow row) => _rowCard(
        onRemove: () => setState(() => _meds.removeAt(index)),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: row.name,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: row.dose,
                    decoration: const InputDecoration(labelText: 'Dose'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: row.frequency,
              decoration: const InputDecoration(labelText: 'Frequency'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: row.purpose,
              decoration: const InputDecoration(labelText: 'Purpose'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: row.maxInstructions,
              decoration: const InputDecoration(
                labelText: 'Special instructions (optional)',
              ),
            ),
          ],
        ),
      );

  Widget _eventEditor(int index, _EventRow row) => _rowCard(
        onRemove: () => setState(() => _events.removeAt(index)),
        child: Column(
          children: [
            _dateField(
              label: 'Date',
              date: row.date,
              onPick: (d) => setState(() => row.date = d),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: row.medication,
                    decoration:
                        const InputDecoration(labelText: 'Medication'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: row.action,
                    decoration: const InputDecoration(
                      labelText: 'Action (e.g. Started)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: row.detail,
              decoration: const InputDecoration(labelText: 'Detail'),
              maxLines: 2,
            ),
          ],
        ),
      );

  Widget _labEditor(int index, _LabRow row) => _rowCard(
        onRemove: () => setState(() => _labs.removeAt(index)),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: _dateField(
                label: 'Date',
                date: row.date,
                onPick: (d) => setState(() => row.date = d),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: row.value,
                decoration: const InputDecoration(labelText: 'Value'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: row.unit,
                decoration: const InputDecoration(labelText: 'Unit'),
              ),
            ),
          ],
        ),
      );

  Widget _symptomEditor(int index, _SymptomRow row) => _rowCard(
        onRemove: () => setState(() => _symptoms.removeAt(index)),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: _dateField(
                label: 'Date',
                date: row.date,
                onPick: (d) => setState(() => row.date = d),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: row.episodes,
                decoration:
                    const InputDecoration(labelText: 'Episodes/month'),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      );

  Widget _dateField({
    required String label,
    required DateTime date,
    required ValueChanged<DateTime> onPick,
  }) {
    String two(int n) => n.toString().padLeft(2, '0');
    final text = '${date.year}-${two(date.month)}-${two(date.day)}';
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(1950),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(text),
      ),
    );
  }
}

// ---- Mutable editor rows (own their controllers) ----

class _MedRow {
  final TextEditingController name;
  final TextEditingController dose;
  final TextEditingController frequency;
  final TextEditingController purpose;
  final TextEditingController maxInstructions;

  _MedRow()
      : name = TextEditingController(),
        dose = TextEditingController(),
        frequency = TextEditingController(),
        purpose = TextEditingController(),
        maxInstructions = TextEditingController();

  _MedRow.from(Medication m)
      : name = TextEditingController(text: m.name),
        dose = TextEditingController(text: m.dose),
        frequency = TextEditingController(text: m.frequency),
        purpose = TextEditingController(text: m.purpose),
        maxInstructions = TextEditingController(text: m.maxInstructions ?? '');

  Medication toModel() => Medication(
        name: name.text.trim(),
        dose: dose.text.trim(),
        frequency: frequency.text.trim(),
        purpose: purpose.text.trim(),
        maxInstructions: maxInstructions.text.trim().isEmpty
            ? null
            : maxInstructions.text.trim(),
      );

  void dispose() {
    name.dispose();
    dose.dispose();
    frequency.dispose();
    purpose.dispose();
    maxInstructions.dispose();
  }
}

class _EventRow {
  DateTime date;
  final TextEditingController medication;
  final TextEditingController action;
  final TextEditingController detail;

  _EventRow()
      : date = DateTime(2020),
        medication = TextEditingController(),
        action = TextEditingController(),
        detail = TextEditingController();

  _EventRow.from(MedicationEvent e)
      : date = e.date,
        medication = TextEditingController(text: e.medication),
        action = TextEditingController(text: e.action),
        detail = TextEditingController(text: e.detail);

  MedicationEvent toModel() => MedicationEvent(
        date: date,
        medication: medication.text.trim(),
        action: action.text.trim(),
        detail: detail.text.trim(),
      );

  void dispose() {
    medication.dispose();
    action.dispose();
    detail.dispose();
  }
}

class _LabRow {
  DateTime date;
  final TextEditingController value;
  final TextEditingController unit;

  _LabRow()
      : date = DateTime(2020),
        value = TextEditingController(),
        unit = TextEditingController();

  _LabRow.from(LabResult l)
      : date = l.date,
        value = TextEditingController(text: '${l.value}'),
        unit = TextEditingController(text: l.unit);

  LabResult toModel() => LabResult(
        date: date,
        value: double.tryParse(value.text.trim()) ?? 0,
        unit: unit.text.trim(),
      );

  void dispose() {
    value.dispose();
    unit.dispose();
  }
}

class _SymptomRow {
  DateTime date;
  final TextEditingController episodes;

  _SymptomRow()
      : date = DateTime(2020),
        episodes = TextEditingController();

  _SymptomRow.from(SymptomFrequencyPoint s)
      : date = s.date,
        episodes = TextEditingController(text: '${s.episodesPerMonth}');

  SymptomFrequencyPoint toModel() => SymptomFrequencyPoint(
        date: date,
        episodesPerMonth: int.tryParse(episodes.text.trim()) ?? 0,
      );

  void dispose() {
    episodes.dispose();
  }
}
