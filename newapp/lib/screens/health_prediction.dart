/// Health Risk Prediction. Reads the most recent personal health record saved
/// to your Solid Pod and turns its metrics into a transparent 0-100% risk
/// score, then grounds that estimate against the bundled healthcare dataset by
/// comparing you with patients in the same age cohort.
///
/// POD read flow mirrors `health_dashboard.dart`:
///   isUserLoggedIn -> getKeyFromUserIfRequired -> getResources -> readPod.
/// The `HealthRecord` model is reused from `health_dashboard.dart`.
///
/// The dataset cohort is parsed off the UI thread with `compute`. The scoring
/// formula is a simple, inspectable rule set (see `_scoreRecord`) — this is a
/// wellbeing indicator, not a medical diagnosis.

library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:newapp/constants/theme.dart';
import 'package:flutter/services.dart';

import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:solidpod/solidpod.dart';
import 'package:solidui/solidui.dart';

import 'package:newapp/screens/health_dashboard.dart' show HealthRecord;

/// Path to the healthcare dataset bundled as an asset (shared with the
/// population dashboard).
const _datasetAsset = 'assets/data/healthcare_dataset.csv';

/// Age cohort bucket labels, matching the population dashboard.
const _ageRangeLabels = ['0-20', '21-40', '41-60', '61-80', '81+'];

class HealthPrediction extends StatefulWidget {
  const HealthPrediction({super.key});

  @override
  State<HealthPrediction> createState() => _HealthPredictionState();
}

class _HealthPredictionState extends State<HealthPrediction> {
  bool _isLoading = true;
  String? _error;
  HealthRecord? _record;
  _Prediction? _prediction;
  _CohortStats? _cohort;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Read the latest personal health record back from the POD.
      if (!await isUserLoggedIn()) {
        throw NotLoggedInException('User must be logged in to predict.');
      }
      if (!mounted) return;
      await getKeyFromUserIfRequired(context, widget);

      final record = await _loadLatestRecord();
      if (record == null) {
        if (!mounted) return;
        setState(() {
          _record = null;
          _isLoading = false;
        });
        return;
      }

      // 2. Score the record with the transparent rule set.
      final prediction = _scoreRecord(record);

      // 3. Ground it against the dataset: load the CSV and aggregate the age
      //    cohort off the UI thread.
      final raw = await rootBundle.loadString(_datasetAsset);
      final cohort = await compute(
        _cohortForAge,
        _CohortRequest(raw: raw, age: record.age),
      );

      if (!mounted) return;
      setState(() {
        _record = record;
        _prediction = prediction;
        _cohort = cohort;
      });
    } on NotLoggedInException {
      if (!mounted) return;
      setState(() => _error = 'You need to be logged in to run a prediction.');
    } on AccessForbiddenException {
      if (!mounted) return;
      setState(() => _error = 'Permission denied while reading your records.');
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Prediction failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Reads every `health_record_*` file from the POD and returns the most
  /// recent one (by timestamp), or null when there are none.
  Future<HealthRecord?> _loadLatestRecord() async {
    final fileNames = (await getResources())
        .where(
          (name) => name.startsWith('health_record_') && name.contains('.json'),
        )
        .toList();

    HealthRecord? latest;
    for (final fileName in fileNames) {
      final jsonString = await readPod(fileName);
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final record = HealthRecord.fromJson(fileName, data);
      if (latest == null ||
          (record.timestamp?.millisecondsSinceEpoch ?? 0) >
              (latest.timestamp?.millisecondsSinceEpoch ?? 0)) {
        latest = record;
      }
    }
    return latest;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _messageView(
        context,
        icon: Icons.error_outline,
        color: Theme.of(context).colorScheme.error,
        title: 'Unable to run prediction',
        body: _error!,
      );
    }
    if (_record == null) {
      return _messageView(
        context,
        icon: Icons.monitor_heart,
        color: Theme.of(context).colorScheme.primary,
        title: 'No health record found',
        body: 'Add a health record first — the prediction runs on your most '
            'recent entry.',
      );
    }

    return RefreshIndicator(
      onRefresh: _run,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(context),
                const SizedBox(height: 20),
                _RiskCard(prediction: _prediction!),
                const SizedBox(height: 20),
                _FactorsCard(factors: _prediction!.factors),
                if (_cohort != null && _cohort!.total > 0) ...[
                  const SizedBox(height: 20),
                  _CohortCard(cohort: _cohort!),
                ],
                const SizedBox(height: 20),
                _disclaimer(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.insights, color: scheme.primary, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Health Risk Prediction',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                'Based on your latest record'
                '${_record?.age != null ? ' • age ${_record!.age}' : ''}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Recalculate',
          onPressed: _run,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _disclaimer(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This score is a transparent wellbeing indicator computed from '
              'your own metrics and compared against the sample dataset. It is '
              'not a medical diagnosis. Consult a healthcare professional for '
              'clinical advice.',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageView(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _run,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Risk scoring ────────────────────────────────────────────────────────────

/// A single scored factor contributing to the overall risk.
class _Factor {
  const _Factor({
    required this.name,
    required this.detail,
    required this.risk,
    required this.weight,
  });

  final String name;
  final String detail;

  /// Normalised risk contribution in 0..1 (higher = worse).
  final double risk;

  /// Relative importance of this factor in the weighted average.
  final double weight;
}

/// The overall prediction result.
class _Prediction {
  const _Prediction({required this.score, required this.factors});

  /// Overall risk in 0..1 (higher = worse).
  final double score;
  final List<_Factor> factors;

  /// Human-readable risk band.
  String get level {
    if (score < 0.34) return 'Low';
    if (score < 0.67) return 'Medium';
    return 'High';
  }
}

/// Turns a [HealthRecord] into a weighted risk score using a simple,
/// inspectable rule set. Only factors that have data contribute.
_Prediction _scoreRecord(HealthRecord r) {
  final factors = <_Factor>[];

  void add(String name, String detail, double risk, double weight) =>
      factors.add(
        _Factor(name: name, detail: detail, risk: risk, weight: weight),
      );

  if (r.bmi != null) {
    final bmi = r.bmi!;
    final double risk;
    final String detail;
    if (bmi < 18.5) {
      risk = 0.4;
      detail = 'Underweight (${bmi.toStringAsFixed(1)})';
    } else if (bmi < 25) {
      risk = 0.0;
      detail = 'Healthy (${bmi.toStringAsFixed(1)})';
    } else if (bmi < 30) {
      risk = 0.45;
      detail = 'Overweight (${bmi.toStringAsFixed(1)})';
    } else if (bmi < 35) {
      risk = 0.75;
      detail = 'Obese (${bmi.toStringAsFixed(1)})';
    } else {
      risk = 1.0;
      detail = 'Severely obese (${bmi.toStringAsFixed(1)})';
    }
    add('BMI', detail, risk, 1.4);
  }

  if (r.systolicBp != null && r.diastolicBp != null) {
    final s = r.systolicBp!;
    final d = r.diastolicBp!;
    final double risk;
    final String detail;
    if (s >= 140 || d >= 90) {
      risk = 1.0;
      detail = 'Stage 2 hypertension ($s/$d)';
    } else if (s >= 130 || d >= 80) {
      risk = 0.6;
      detail = 'Elevated ($s/$d)';
    } else if (s >= 120) {
      risk = 0.3;
      detail = 'Slightly elevated ($s/$d)';
    } else {
      risk = 0.0;
      detail = 'Normal ($s/$d)';
    }
    add('Blood Pressure', detail, risk, 1.5);
  }

  if (r.restingHeartRate != null) {
    final hr = r.restingHeartRate!;
    final double risk;
    final String detail;
    if (hr > 100) {
      risk = 0.8;
      detail = 'High ($hr bpm)';
    } else if (hr > 90) {
      risk = 0.5;
      detail = 'Elevated ($hr bpm)';
    } else if (hr < 50) {
      risk = 0.4;
      detail = 'Low ($hr bpm)';
    } else {
      risk = 0.0;
      detail = 'Normal ($hr bpm)';
    }
    add('Resting Heart Rate', detail, risk, 1.0);
  }

  if (r.sleepHours != null) {
    final h = r.sleepHours!;
    final double risk;
    final String detail;
    if (h < 6) {
      risk = 0.6;
      detail = 'Too little (${h.toStringAsFixed(1)} h)';
    } else if (h < 7) {
      risk = 0.3;
      detail = 'Slightly low (${h.toStringAsFixed(1)} h)';
    } else if (h > 9) {
      risk = 0.3;
      detail = 'High (${h.toStringAsFixed(1)} h)';
    } else {
      risk = 0.0;
      detail = 'Healthy (${h.toStringAsFixed(1)} h)';
    }
    add('Sleep', detail, risk, 0.9);
  }

  if (r.exerciseMinutesPerWeek != null) {
    final m = r.exerciseMinutesPerWeek!;
    final double risk;
    final String detail;
    if (m >= 150) {
      risk = 0.0;
      detail = 'Meets guideline ($m min/wk)';
    } else if (m >= 75) {
      risk = 0.35;
      detail = 'Below guideline ($m min/wk)';
    } else if (m >= 30) {
      risk = 0.6;
      detail = 'Low ($m min/wk)';
    } else {
      risk = 0.9;
      detail = 'Sedentary ($m min/wk)';
    }
    add('Exercise', detail, risk, 1.1);
  }

  if (r.age != null) {
    final age = r.age!;
    final double risk;
    if (age < 40) {
      risk = 0.1;
    } else if (age < 55) {
      risk = 0.35;
    } else if (age < 70) {
      risk = 0.6;
    } else {
      risk = 0.9;
    }
    add('Age', '$age years', risk, 1.0);
  }

  add(
    'Smoking',
    r.smoker ? 'Smoker' : 'Non-smoker',
    r.smoker ? 1.0 : 0.0,
    1.3,
  );
  add(
    'Family History',
    r.familyHistory ? 'Present' : 'None reported',
    r.familyHistory ? 0.6 : 0.0,
    0.9,
  );

  final totalWeight = factors.fold<double>(0, (a, f) => a + f.weight);
  final score = totalWeight == 0
      ? 0.0
      : factors.fold<double>(0, (a, f) => a + f.risk * f.weight) / totalWeight;

  // Show the biggest contributors first.
  factors.sort((a, b) => (b.risk * b.weight).compareTo(a.risk * a.weight));

  return _Prediction(score: score, factors: factors);
}

/// Maps a normalised risk `t` (0..1) onto the shared grade scale, inverted so
/// low risk reads green and high risk reads red (the score gauge uses the same
/// scale the other way round).
Color _riskColor(double t) => AppColors.grade(1 - t);

// ── Dataset cohort (parsed in a background isolate) ──────────────────────────

/// Argument bundle for [_cohortForAge] (compute takes a single argument).
class _CohortRequest {
  const _CohortRequest({required this.raw, required this.age});

  final String raw;
  final int? age;
}

/// Aggregates for patients in the same age cohort as the user.
class _CohortStats {
  const _CohortStats({
    required this.ageLabel,
    required this.total,
    required this.testResults,
    required this.topConditions,
  });

  final String ageLabel;
  final int total;

  /// Count of each Test Results value within the cohort.
  final Map<String, int> testResults;

  /// Top medical conditions in the cohort, most common first.
  final List<MapEntry<String, int>> topConditions;
}

int _ageBucketIndex(int age) {
  if (age <= 20) return 0;
  if (age <= 40) return 1;
  if (age <= 60) return 2;
  if (age <= 80) return 3;
  return 4;
}

/// Parses the CSV and aggregates the age cohort the user belongs to. Top-level
/// so it can run inside a `compute` isolate.
_CohortStats _cohortForAge(_CohortRequest req) {
  final empty = _CohortStats(
    ageLabel: req.age == null ? '—' : _ageRangeLabels[_ageBucketIndex(req.age!)],
    total: 0,
    testResults: const {},
    topConditions: const [],
  );
  if (req.age == null) return empty;

  final rows = Csv(
    autoDetect: true,
    skipEmptyLines: true,
    dynamicTyping: false,
  ).decode(req.raw);
  if (rows.length < 2) return empty;

  final header = [for (final cell in rows.first) cell.toString().trim()];
  final ageIdx = header.indexOf('Age');
  final testIdx = header.indexOf('Test Results');
  final conditionIdx = header.indexOf('Medical Condition');
  final targetBucket = _ageBucketIndex(req.age!);

  String? cell(List<dynamic> row, int index) {
    if (index < 0 || index >= row.length) return null;
    final value = row[index].toString().trim();
    return value.isEmpty ? null : value;
  }

  final testResults = <String, int>{};
  final conditionCounts = <String, int>{};
  var total = 0;

  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    if (row.isEmpty) continue;
    final ageStr = cell(row, ageIdx);
    final age = ageStr == null ? null : int.tryParse(ageStr);
    if (age == null || _ageBucketIndex(age) != targetBucket) continue;

    total++;
    final test = cell(row, testIdx);
    if (test != null) {
      testResults[test] = (testResults[test] ?? 0) + 1;
    }
    final condition = cell(row, conditionIdx);
    if (condition != null) {
      conditionCounts[condition] = (conditionCounts[condition] ?? 0) + 1;
    }
  }

  final topConditions = conditionCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return _CohortStats(
    ageLabel: _ageRangeLabels[targetBucket],
    total: total,
    testResults: testResults,
    topConditions: topConditions.take(5).toList(),
  );
}

// ── Presentation widgets ─────────────────────────────────────────────────────

/// Big risk headline: percentage, level chip and a colour-graded bar.
class _RiskCard extends StatelessWidget {
  const _RiskCard({required this.prediction});

  final _Prediction prediction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = prediction.score;
    final color = _riskColor(t);
    final pct = (t * 100).round();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$pct%',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${prediction.level} risk',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Estimated overall health risk',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: t.clamp(0.0, 1.0),
                minHeight: 12,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Per-factor breakdown showing how much each metric contributes.
class _FactorsCard extends StatelessWidget {
  const _FactorsCard({required this.factors});

  final List<_Factor> factors;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contributing factors',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Ranked by impact on your score.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            for (final f in factors) ...[
              _factorRow(context, f),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _factorRow(BuildContext context, _Factor f) {
    final scheme = Theme.of(context).colorScheme;
    final color = _riskColor(f.risk);
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                f.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                f.detail,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: f.risk.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}

/// Compares the user against the dataset cohort of the same age: test-result
/// split (pie) and the most common medical conditions (bars).
class _CohortCard extends StatelessWidget {
  const _CohortCard({required this.cohort});

  final _CohortStats cohort;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How you compare',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '${cohort.total} patients aged ${cohort.ageLabel} in the dataset.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 560;
                final test = _TestResultsPie(cohort: cohort);
                final conditions = _TopConditionsChart(cohort: cohort);
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: test),
                      const SizedBox(width: 16),
                      Expanded(child: conditions),
                    ],
                  );
                }
                return Column(
                  children: [
                    test,
                    const SizedBox(height: 24),
                    conditions,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TestResultsPie extends StatelessWidget {
  const _TestResultsPie({required this.cohort});

  final _CohortStats cohort;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = cohort.testResults.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (a, e) => a + e.value);
    final palette = [
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      scheme.error,
    ];

    if (total == 0) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('No cohort test data.')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cohort test results',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 32,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value.toDouble(),
                    title: '${(entries[i].value / total * 100).round()}%',
                    color: palette[i % palette.length],
                    radius: 56,
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < entries.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: palette[i % palette.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${entries[i].key} (${entries[i].value})',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TopConditionsChart extends StatelessWidget {
  const _TopConditionsChart({required this.cohort});

  final _CohortStats cohort;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = cohort.topConditions;
    if (entries.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('No cohort condition data.')),
      );
    }
    final maxV =
        entries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Common conditions in your cohort',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxV * 1.15,
              barGroups: [
                for (var i = 0; i < entries.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: entries[i].value.toDouble(),
                        color: scheme.primary,
                        width: 18,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  ),
              ],
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 32),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      final label =
                          i >= 0 && i < entries.length ? entries[i].key : '';
                      return SideTitleWidget(
                        meta: meta,
                        space: 6,
                        child: SizedBox(
                          width: 56,
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                    '${entries[group.x].key}\n',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    children: [
                      TextSpan(
                        text: rod.toY.toStringAsFixed(0),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
