/// Data models for the Health Timeline page.
///
/// These describe a patient profile — demographics, current medications, a
/// medication-change timeline, and two example trend series (a lab result and a
/// symptom frequency). Instances are persisted to the user's Solid Pod as a
/// single encrypted JSON file by `manage_patient_profile.dart` and read back by
/// `health_timeline.dart`.
///
/// There is NO bundled sample patient any more — the app shows only the data the
/// user has entered and saved to their own POD.
library;

/// Canonical POD file name for the single patient-profile document.
const String kPatientProfileFileName = 'patient_profile.json.enc.ttl';

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

  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
        'gender': gender,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'conditions': conditions,
        'currentMedications':
            currentMedications.map((m) => m.toJson()).toList(),
        'medicationTimeline':
            medicationTimeline.map((e) => e.toJson()).toList(),
        'tshHistory': tshHistory.map((r) => r.toJson()).toList(),
        'migraineFrequency':
            migraineFrequency.map((p) => p.toJson()).toList(),
      };

  factory PatientProfile.fromJson(Map<String, dynamic> j) {
    double toDouble(Object? v) => v == null ? 0 : (v as num).toDouble();
    int toInt(Object? v) => v == null ? 0 : (v as num).toInt();
    List<T> list<T>(Object? v, T Function(Map<String, dynamic>) f) =>
        (v as List<dynamic>? ?? const [])
            .map((e) => f(e as Map<String, dynamic>))
            .toList();

    return PatientProfile(
      name: (j['name'] as String?) ?? '',
      age: toInt(j['age']),
      gender: (j['gender'] as String?) ?? '',
      heightCm: toDouble(j['heightCm']),
      weightKg: toDouble(j['weightKg']),
      conditions: (j['conditions'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      currentMedications: list(j['currentMedications'], Medication.fromJson),
      medicationTimeline:
          list(j['medicationTimeline'], MedicationEvent.fromJson),
      tshHistory: list(j['tshHistory'], LabResult.fromJson),
      migraineFrequency:
          list(j['migraineFrequency'], SymptomFrequencyPoint.fromJson),
    );
  }
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

  Map<String, dynamic> toJson() => {
        'name': name,
        'dose': dose,
        'frequency': frequency,
        'purpose': purpose,
        if (maxInstructions != null && maxInstructions!.isNotEmpty)
          'maxInstructions': maxInstructions,
      };

  factory Medication.fromJson(Map<String, dynamic> j) => Medication(
        name: (j['name'] as String?) ?? '',
        dose: (j['dose'] as String?) ?? '',
        frequency: (j['frequency'] as String?) ?? '',
        purpose: (j['purpose'] as String?) ?? '',
        maxInstructions: j['maxInstructions'] as String?,
      );
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

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'medication': medication,
        'action': action,
        'detail': detail,
      };

  factory MedicationEvent.fromJson(Map<String, dynamic> j) => MedicationEvent(
        date: DateTime.tryParse((j['date'] as String?) ?? '') ?? DateTime(2000),
        medication: (j['medication'] as String?) ?? '',
        action: (j['action'] as String?) ?? '',
        detail: (j['detail'] as String?) ?? '',
      );
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

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'value': value,
        'unit': unit,
      };

  factory LabResult.fromJson(Map<String, dynamic> j) => LabResult(
        date: DateTime.tryParse((j['date'] as String?) ?? '') ?? DateTime(2000),
        value: (j['value'] as num?)?.toDouble() ?? 0,
        unit: (j['unit'] as String?) ?? '',
      );
}

class SymptomFrequencyPoint {
  final DateTime date;
  final int episodesPerMonth;

  const SymptomFrequencyPoint({
    required this.date,
    required this.episodesPerMonth,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'episodesPerMonth': episodesPerMonth,
      };

  factory SymptomFrequencyPoint.fromJson(Map<String, dynamic> j) =>
      SymptomFrequencyPoint(
        date: DateTime.tryParse((j['date'] as String?) ?? '') ?? DateTime(2000),
        episodesPerMonth: (j['episodesPerMonth'] as num?)?.toInt() ?? 0,
      );
}
