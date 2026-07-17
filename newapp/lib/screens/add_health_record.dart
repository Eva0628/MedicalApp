/// Add health record functionality. Records personal health metrics to your
/// Solid Pod (encrypted) and auto-calculates BMI, following the same flow as
/// `add_note.dart`.

library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:solidpod/solidpod.dart';

import 'package:solidui/solidui.dart';

import 'package:newapp/constants/theme.dart';

class AddHealthRecord extends StatefulWidget {
  const AddHealthRecord({super.key});

  @override
  State<AddHealthRecord> createState() => _AddHealthRecordState();
}

class _AddHealthRecordState extends State<AddHealthRecord> {
  final _formKey = GlobalKey<FormState>();

  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _sleepController = TextEditingController();
  final _exerciseController = TextEditingController();

  bool _isSmoker = false;
  bool _hasFamilyHistory = false;

  bool _isSaving = false;
  double? _bmi;

  @override
  void initState() {
    super.initState();
    // Recompute BMI live as the user types into weight or height.
    _weightController.addListener(_recomputeBmi);
    _heightController.addListener(_recomputeBmi);
  }

  @override
  void dispose() {
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _heartRateController.dispose();
    _sleepController.dispose();
    _exerciseController.dispose();
    super.dispose();
  }

  void _recomputeBmi() {
    final weight = double.tryParse(_weightController.text.trim());
    final height = double.tryParse(_heightController.text.trim());

    double? bmi;
    if (weight != null && weight > 0 && height != null && height > 0) {
      final heightM = height / 100;
      bmi = weight / pow(heightM, 2);
    }

    if (bmi != _bmi) setState(() => _bmi = bmi);
  }

  /// Validates a numeric field: required, parseable and within [min, max].
  String? _validateNumber(
    String? value, {
    required String label,
    double? min,
    double? max,
    bool allowDecimal = true,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter $label';

    final number = double.tryParse(text);
    if (number == null) return 'Please enter a valid number for $label';

    if (!allowDecimal && number != number.roundToDouble()) {
      return '$label must be a whole number';
    }
    if (min != null && number < min) return '$label must be at least $min';
    if (max != null && number > max) return '$label must be at most $max';

    return null;
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      if (!await isUserLoggedIn()) return;

      if (!mounted) return;
      await getKeyFromUserIfRequired(context, widget);

      // Encode the data to a JSON string.
      final jsonString = jsonEncode({
        'age': int.parse(_ageController.text.trim()),
        'weightKg': double.parse(_weightController.text.trim()),
        'heightCm': double.parse(_heightController.text.trim()),
        'systolicBp': int.parse(_systolicController.text.trim()),
        'diastolicBp': int.parse(_diastolicController.text.trim()),
        'restingHeartRate': int.parse(_heartRateController.text.trim()),
        'sleepHours': double.parse(_sleepController.text.trim()),
        'exerciseMinutesPerWeek': int.parse(_exerciseController.text.trim()),
        'smoker': _isSmoker,
        'familyHistory': _hasFamilyHistory,
        'bmi': _bmi,
        'timestamp': DateTime.now().toIso8601String(),
      });
      final fileName =
          'health_record_${DateTime.now().millisecondsSinceEpoch}'
          '.json.enc.ttl';

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);

      // Write the data to the POD.
      await writePod(fileName, jsonString, encrypted: true);

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Health record saved to POD.'),
          backgroundColor: AppColors.good,
        ),
      );

      _ageController.clear();
      _weightController.clear();
      _heightController.clear();
      _systolicController.clear();
      _diastolicController.clear();
      _heartRateController.clear();
      _sleepController.clear();
      _exerciseController.clear();
      setState(() {
        _isSmoker = false;
        _hasFamilyHistory = false;
        _bmi = null;
      });
    } on NotLoggedInException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to be logged in to save a health record.'),
          backgroundColor: AppColors.bad,
        ),
      );
    } on AccessForbiddenException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission denied while saving the health record.'),
          backgroundColor: AppColors.bad,
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save health record: $e'),
          backgroundColor: AppColors.bad,
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
                    Icons.monitor_heart,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Add Health Record',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _ageController,
                    decoration: const InputDecoration(labelText: 'Age'),
                    keyboardType: TextInputType.number,
                    validator: (value) => _validateNumber(
                      value,
                      label: 'age',
                      min: 0,
                      max: 120,
                      allowDecimal: false,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _weightController,
                    decoration:
                        const InputDecoration(labelText: 'Weight (kg)'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) => _validateNumber(
                      value,
                      label: 'weight',
                      min: 0.1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _heightController,
                    decoration:
                        const InputDecoration(labelText: 'Height (cm)'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) => _validateNumber(
                      value,
                      label: 'height',
                      min: 0.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _bmi == null ? 'BMI: —' : 'BMI: ${_bmi!.toStringAsFixed(1)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _systolicController,
                    decoration: const InputDecoration(
                      labelText: 'Systolic Blood Pressure',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => _validateNumber(
                      value,
                      label: 'systolic blood pressure',
                      min: 60,
                      max: 250,
                      allowDecimal: false,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _diastolicController,
                    decoration: const InputDecoration(
                      labelText: 'Diastolic Blood Pressure',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => _validateNumber(
                      value,
                      label: 'diastolic blood pressure',
                      min: 40,
                      max: 150,
                      allowDecimal: false,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _heartRateController,
                    decoration: const InputDecoration(
                      labelText: 'Resting Heart Rate (bpm)',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => _validateNumber(
                      value,
                      label: 'resting heart rate',
                      min: 30,
                      max: 220,
                      allowDecimal: false,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _sleepController,
                    decoration: const InputDecoration(
                      labelText: 'Sleep hours/night',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) => _validateNumber(
                      value,
                      label: 'sleep hours',
                      min: 0,
                      max: 24,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _exerciseController,
                    decoration: const InputDecoration(
                      labelText: 'Exercise minutes/week',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => _validateNumber(
                      value,
                      label: 'exercise minutes',
                      min: 0,
                      allowDecimal: false,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Smoking status'),
                    subtitle: Text(_isSmoker ? 'Yes' : 'No'),
                    value: _isSmoker,
                    onChanged: _isSaving
                        ? null
                        : (value) => setState(() => _isSmoker = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Family history of the condition'),
                    subtitle: Text(_hasFamilyHistory ? 'Yes' : 'No'),
                    value: _hasFamilyHistory,
                    onChanged: _isSaving
                        ? null
                        : (value) =>
                            setState(() => _hasFamilyHistory = value),
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
