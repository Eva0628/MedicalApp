/// FICTIONAL PROTOTYPE DATA — not a real patient. Used to demo the app's
/// medication timeline / trend graphs on the Health Timeline page.
///
/// This is in-memory sample data, so the Health Timeline page works without any
/// POD `.ttl` file to import. Swap [samplePatient] for records read back from
/// the POD (see `health_dashboard.dart` / `view_notes.dart` for the read flow)
/// once you have real data.
library;

class PatientProfile {
  final String name;
  final int age;
  final String gender;
  final double heightCm;
  final double weightKg;
  final List<String> conditions;
  final List<Medication> currentMedications;
  final List<MedicationEvent> medicationTimeline;
  final List<LabResult> tshHistory;
  final List<SymptomFrequencyPoint> migraineFrequency;

  const PatientProfile({
    required this.name,
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.conditions,
    required this.currentMedications,
    required this.medicationTimeline,
    required this.tshHistory,
    required this.migraineFrequency,
  });
}

class Medication {
  final String name;
  final String dose;
  final String frequency;
  final String purpose;
  final String? maxInstructions;

  const Medication({
    required this.name,
    required this.dose,
    required this.frequency,
    required this.purpose,
    this.maxInstructions,
  });
}

/// A single change in the medication regimen — used to build the timeline graph.
class MedicationEvent {
  final DateTime date;
  final String medication;
  final String action; // e.g. "Started", "Dose increased", "Stopped"
  final String detail;

  const MedicationEvent({
    required this.date,
    required this.medication,
    required this.action,
    required this.detail,
  });
}

class LabResult {
  final DateTime date;
  final double value;
  final String unit;

  const LabResult({
    required this.date,
    required this.value,
    required this.unit,
  });
}

class SymptomFrequencyPoint {
  final DateTime date;
  final int episodesPerMonth;

  const SymptomFrequencyPoint({
    required this.date,
    required this.episodesPerMonth,
  });
}

/// Sample fictional patient: 30yo woman with hypothyroidism and chronic migraine.
final PatientProfile samplePatient = PatientProfile(
  name: 'Jasmine Alvarez',
  age: 30,
  gender: 'Female',
  heightCm: 165,
  weightKg: 61.5,
  conditions: const [
    'Hypothyroidism',
    'Chronic Migraine',
    'Iron-deficiency anemia (mild)',
  ],
  currentMedications: const [
    Medication(
      name: 'Levothyroxine',
      dose: '75 mcg',
      frequency: 'Once daily, morning, empty stomach',
      purpose: 'Hypothyroidism',
    ),
    Medication(
      name: 'Sumatriptan',
      dose: '50 mg',
      frequency: 'As needed for migraine',
      purpose: 'Acute migraine relief',
      maxInstructions:
          'Max 2 doses/day, at least 2 hours apart. Max 4 doses/month.',
    ),
    Medication(
      name: 'Propranolol',
      dose: '60 mg',
      frequency: 'Twice daily',
      purpose: 'Migraine prevention (prophylaxis)',
    ),
    Medication(
      name: 'Vitamin D3',
      dose: '1000 IU',
      frequency: 'Once daily',
      purpose: 'Vitamin D deficiency',
    ),
    Medication(
      name: 'Ferrous sulfate',
      dose: '325 mg',
      frequency: 'Once daily, with food',
      purpose: 'Iron-deficiency anemia',
    ),
  ],
  medicationTimeline: [
    MedicationEvent(
      date: DateTime(2021, 3, 10),
      medication: 'Levothyroxine',
      action: 'Started',
      detail: 'Diagnosed with hypothyroidism. Started 50 mcg daily.',
    ),
    MedicationEvent(
      date: DateTime(2021, 9, 15),
      medication: 'Levothyroxine',
      action: 'Dose increased',
      detail:
          'TSH still elevated at 3-month follow-up. Increased to 75 mcg daily.',
    ),
    MedicationEvent(
      date: DateTime(2022, 5, 2),
      medication: 'Sumatriptan',
      action: 'Started',
      detail:
          'Diagnosed with chronic migraine. Started 50 mg PRN for acute attacks.',
    ),
    MedicationEvent(
      date: DateTime(2022, 11, 20),
      medication: 'Vitamin D3',
      action: 'Started',
      detail: 'Bloodwork showed vitamin D deficiency. Started 1000 IU daily.',
    ),
    MedicationEvent(
      date: DateTime(2023, 6, 8),
      medication: 'Propranolol',
      action: 'Started',
      detail:
          'Migraine frequency increasing (10/month). Started 40 mg twice daily for prevention.',
    ),
    MedicationEvent(
      date: DateTime(2024, 2, 14),
      medication: 'Ferrous sulfate',
      action: 'Started',
      detail:
          'Routine labs showed mild iron-deficiency anemia. Started 325 mg daily.',
    ),
    MedicationEvent(
      date: DateTime(2024, 8, 19),
      medication: 'Propranolol',
      action: 'Dose increased',
      detail: 'Migraines still frequent. Increased to 60 mg twice daily.',
    ),
    MedicationEvent(
      date: DateTime(2025, 1, 30),
      medication: 'Levothyroxine',
      action: 'Continued',
      detail:
          'TSH stable and within range. No dose change — remains at 75 mcg daily.',
    ),
    MedicationEvent(
      date: DateTime(2026, 3, 5),
      medication: 'All medications',
      action: 'Annual review',
      detail:
          'All medications continued. Migraine frequency down to 2-3 episodes/month.',
    ),
  ],
  tshHistory: [
    LabResult(date: DateTime(2021, 3, 10), value: 8.2, unit: 'mIU/L'),
    LabResult(date: DateTime(2021, 9, 15), value: 5.1, unit: 'mIU/L'),
    LabResult(date: DateTime(2022, 3, 12), value: 3.2, unit: 'mIU/L'),
    LabResult(date: DateTime(2022, 9, 10), value: 2.8, unit: 'mIU/L'),
    LabResult(date: DateTime(2023, 3, 14), value: 2.5, unit: 'mIU/L'),
    LabResult(date: DateTime(2023, 9, 9), value: 3.0, unit: 'mIU/L'),
    LabResult(date: DateTime(2024, 3, 11), value: 2.7, unit: 'mIU/L'),
    LabResult(date: DateTime(2024, 9, 16), value: 2.9, unit: 'mIU/L'),
    LabResult(date: DateTime(2025, 3, 13), value: 2.6, unit: 'mIU/L'),
    LabResult(date: DateTime(2025, 9, 8), value: 2.8, unit: 'mIU/L'),
    LabResult(date: DateTime(2026, 3, 5), value: 2.5, unit: 'mIU/L'),
  ],
  migraineFrequency: [
    SymptomFrequencyPoint(date: DateTime(2022, 5, 2), episodesPerMonth: 8),
    SymptomFrequencyPoint(date: DateTime(2022, 11, 20), episodesPerMonth: 9),
    SymptomFrequencyPoint(date: DateTime(2023, 6, 8), episodesPerMonth: 10),
    SymptomFrequencyPoint(date: DateTime(2023, 12, 5), episodesPerMonth: 6),
    SymptomFrequencyPoint(date: DateTime(2024, 6, 3), episodesPerMonth: 5),
    SymptomFrequencyPoint(date: DateTime(2024, 12, 1), episodesPerMonth: 4),
    SymptomFrequencyPoint(date: DateTime(2025, 6, 7), episodesPerMonth: 3),
    SymptomFrequencyPoint(date: DateTime(2025, 12, 6), episodesPerMonth: 3),
    SymptomFrequencyPoint(date: DateTime(2026, 6, 4), episodesPerMonth: 2),
  ],
);
