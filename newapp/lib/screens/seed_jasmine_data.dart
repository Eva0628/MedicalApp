// DISABLED FOR DEMO/JUDGING: this fictional Jasmine Alvarez seed importer is
// commented out so judges test with their own POD data only. To re-enable it,
// remove the `/*` below and the matching `*/` at the end of the file, and
// restore its import + menu item in `app_scaffold.dart`.
/*
/// TEMPORARY demo-data importer for Jasmine Alvarez (fictional patient).
///
/// Writes a dense health-record history straight to the logged-in user's POD
/// using the exact same `writePod(..., encrypted: true)` call and filename
/// convention as `add_health_record.dart`:
///
///   `health_record_<millisecondsSinceEpoch>_<n>.json.enc.ttl`
///
/// Data layout (all dated the 16th, 09:00):
///   * 2007-2020  -> one record per year (age 11 -> 24), the childhood arc.
///   * 2021-2026  -> one record per MONTH (age 24 -> 30), the recovery arc.
/// ~81 records in total, so the Health Dashboard trend charts show smooth,
/// densely-sampled curves with realistic month-to-month wobble instead of a
/// handful of sparse yearly points.
///
/// The monthly points are generated deterministically: values are linearly
/// interpolated between the yearly "story" anchors and nudged by a few small
/// sine terms (dart:math, no RNG -> fully reproducible). July points land
/// exactly on the anchors, keeping the long-term narrative clean.
///
/// This runs through the app's real encryption pipeline (the security key
/// already unlocked in this session), so the files it creates are genuinely
/// readable by Health Dashboard / Health Timeline afterwards -- nothing here
/// is faked or pre-encrypted outside the app.
///
/// TWO USES
/// A. `jasmineAlvarezRecords` (the data list) is imported by
///    `health_dashboard.dart` as the demo fallback: when the POD has no real
///    records yet, the Home dashboard renders this list in-memory. So do NOT
///    delete the whole file -- the dashboard depends on this list.
/// B. `SeedJasmineData` (the widget below) optionally writes these records to
///    the POD for real, via `writePod(encrypted: true)`, so they persist and
///    show up in View Records / Risk Prediction too.
///
/// HOW TO USE THE IMPORTER (optional)
/// 1. Add a temporary menu item in `app_scaffold.dart` pointing to
///    `SeedJasmineData()`.
/// 2. Log in, tap the menu item, tap "Import Records".
/// 3. Before shipping, remove the `SeedJasmineData` widget + its menu item if
///    you don't want the POD-import path -- but keep `jasmineAlvarezRecords`
///    (or move it out) as long as the dashboard fallback uses it.

library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:solidpod/solidpod.dart';
import 'package:solidui/solidui.dart';

/// Yearly "story" anchors, age 11 -> 30, one entry per July.
/// FICTIONAL DEMO DATA -- not a real patient.
///
/// The narrative: an athletic, well-slept teenager (2007-2013) who stays fit
/// through late adolescence, drifts into a sedentary, sleep-deprived slump at
/// university and in her first office job (2020-2023: weight up, exercise and
/// sleep down), then turns things around from 2024 (weight down, exercise and
/// sleep back up) and holds steady into her thirties.
const List<Map<String, dynamic>> _jasmineYearlyAnchors = [
  // year, age, weightKg, heightCm, systolicBp, diastolicBp, restingHeartRate,
  // sleepHours, exerciseMinutesPerWeek
  {'y': 2007, 'age': 11, 'w': 34.0, 'h': 139.2, 's': 98, 'd': 61, 'hr': 85, 'sl': 9.7, 'ex': 260},
  {'y': 2008, 'age': 12, 'w': 38.9, 'h': 144.3, 's': 103, 'd': 64, 'hr': 83, 'sl': 9.4, 'ex': 259},
  {'y': 2009, 'age': 13, 'w': 42.3, 'h': 147.9, 's': 102, 'd': 65, 'hr': 79, 'sl': 9.2, 'ex': 269},
  {'y': 2010, 'age': 14, 'w': 45.1, 'h': 153.0, 's': 106, 'd': 66, 'hr': 78, 'sl': 9.0, 'ex': 300},
  {'y': 2011, 'age': 15, 'w': 48.7, 'h': 156.8, 's': 104, 'd': 65, 'hr': 77, 'sl': 8.5, 'ex': 288},
  {'y': 2012, 'age': 16, 'w': 54.2, 'h': 161.4, 's': 105, 'd': 66, 'hr': 73, 'sl': 8.4, 'ex': 240},
  {'y': 2013, 'age': 17, 'w': 58.0, 'h': 165.4, 's': 109, 'd': 67, 'hr': 72, 'sl': 8.0, 'ex': 249},
  {'y': 2014, 'age': 18, 'w': 59.4, 'h': 167.4, 's': 112, 'd': 70, 'hr': 67, 'sl': 7.7, 'ex': 154},
  {'y': 2015, 'age': 19, 'w': 59.5, 'h': 166.7, 's': 111, 'd': 73, 'hr': 64, 'sl': 7.5, 'ex': 182},
  {'y': 2016, 'age': 20, 'w': 60.7, 'h': 167.0, 's': 113, 'd': 73, 'hr': 66, 'sl': 7.6, 'ex': 164},
  {'y': 2017, 'age': 21, 'w': 62.2, 'h': 167.4, 's': 113, 'd': 74, 'hr': 68, 'sl': 7.4, 'ex': 167},
  {'y': 2018, 'age': 22, 'w': 61.3, 'h': 167.0, 's': 113, 'd': 72, 'hr': 71, 'sl': 7.4, 'ex': 141},
  {'y': 2019, 'age': 23, 'w': 62.0, 'h': 167.2, 's': 116, 'd': 73, 'hr': 68, 'sl': 7.4, 'ex': 154},
  {'y': 2020, 'age': 24, 'w': 65.1, 'h': 167.0, 's': 117, 'd': 75, 'hr': 71, 'sl': 6.3, 'ex': 72},
  {'y': 2021, 'age': 25, 'w': 66.5, 'h': 166.8, 's': 116, 'd': 74, 'hr': 65, 'sl': 6.2, 'ex': 81},
  {'y': 2022, 'age': 26, 'w': 66.9, 'h': 167.5, 's': 115, 'd': 75, 'hr': 71, 'sl': 6.1, 'ex': 53},
  {'y': 2023, 'age': 27, 'w': 66.7, 'h': 166.6, 's': 115, 'd': 75, 'hr': 67, 'sl': 6.1, 'ex': 51},
  {'y': 2024, 'age': 28, 'w': 62.5, 'h': 167.4, 's': 119, 'd': 77, 'hr': 70, 'sl': 7.2, 'ex': 163},
  {'y': 2025, 'age': 29, 'w': 64.2, 'h': 167.2, 's': 119, 'd': 78, 'hr': 65, 'sl': 7.3, 'ex': 161},
  {'y': 2026, 'age': 30, 'w': 64.7, 'h': 167.0, 's': 120, 'd': 78, 'hr': 65, 'sl': 7.2, 'ex': 161},
];

/// Build the full record list: yearly points for 2007-2020, then one point per
/// month for 2021-01 .. 2026-07 (Jasmine's most recent, most interesting arc).
List<Map<String, dynamic>> _buildJasmineRecords() {
  final anchors = {
    for (final a in _jasmineYearlyAnchors) a['y'] as int: a,
  };

  double round1(double v) => (v * 10).roundToDouble() / 10;
  double bmiOf(double w, double h) => round1(w / pow(h / 100.0, 2));
  String pad2(int n) => n.toString().padLeft(2, '0');

  String stamp(int year, int month) =>
      '$year-${pad2(month)}-16T09:00:00.000';

  Map<String, dynamic> recordFor(int year, int month, int runningMonth) {
    // Interpolate between the two surrounding July anchors. July -> t = 0
    // (lands exactly on the anchor); other months ramp towards the next year.
    final int baseYear = month >= 7 ? year : year - 1;
    final double t = month >= 7 ? (month - 7) / 12.0 : (month + 5) / 12.0;
    final base = anchors[baseYear] ?? anchors[2020]!;
    final next = anchors[baseYear + 1] ?? base;

    double lerp(String key) =>
        (base[key] as num).toDouble() +
        ((next[key] as num).toDouble() - (base[key] as num).toDouble()) * t;

    // Small deterministic monthly wobble; zeroed on July so anchors stay clean.
    final bool onAnchor = month == 7;
    final double m = runningMonth.toDouble();
    double wobble(double amp, double freq, double phase) =>
        onAnchor ? 0 : amp * sin(m * freq + phase);

    final double height = round1(lerp('h') + wobble(0.25, 0.5, 0.4));
    final double weight = round1(lerp('w') + wobble(0.6, 1.7, 0.0));
    final int systolic = (lerp('s') + wobble(2.0, 1.3, 0.5)).round();
    final int diastolic = (lerp('d') + wobble(1.5, 0.8, 1.0)).round();
    final int restingHr = (lerp('hr') + wobble(3.0, 1.1, 2.0)).round();
    final double sleep = round1(lerp('sl') + wobble(0.3, 1.5, 0.3));
    final int exercise =
        (lerp('ex') + wobble(18.0, 0.7, 0.0)).round().clamp(0, 1000);
    final int age = baseYear - 1996; // 2007-07 -> age 11

    return {
      'age': age,
      'weightKg': weight,
      'heightCm': height,
      'systolicBp': systolic,
      'diastolicBp': diastolic,
      'restingHeartRate': restingHr,
      'sleepHours': sleep,
      'exerciseMinutesPerWeek': exercise,
      'smoker': false,
      'familyHistory': true,
      'bmi': bmiOf(weight, height),
      'timestamp': stamp(year, month),
    };
  }

  final records = <Map<String, dynamic>>[];

  // 2007-2020: one record per year, straight from the anchors.
  for (var year = 2007; year <= 2020; year++) {
    final a = anchors[year]!;
    final double w = (a['w'] as num).toDouble();
    final double h = (a['h'] as num).toDouble();
    records.add({
      'age': a['age'],
      'weightKg': w,
      'heightCm': h,
      'systolicBp': a['s'],
      'diastolicBp': a['d'],
      'restingHeartRate': a['hr'],
      'sleepHours': (a['sl'] as num).toDouble(),
      'exerciseMinutesPerWeek': a['ex'],
      'smoker': false,
      'familyHistory': true,
      'bmi': bmiOf(w, h),
      'timestamp': stamp(year, 7),
    });
  }

  // 2021-01 .. 2026-07: one record per month.
  var runningMonth = 0;
  for (var year = 2021; year <= 2026; year++) {
    final lastMonth = year == 2026 ? 7 : 12;
    for (var month = 1; month <= lastMonth; month++) {
      records.add(recordFor(year, month, runningMonth));
      runningMonth++;
    }
  }

  return records;
}

/// Jasmine Alvarez -- childhood yearly points + recent monthly points.
/// FICTIONAL DEMO DATA -- not a real patient.
final List<Map<String, dynamic>> jasmineAlvarezRecords = _buildJasmineRecords();

class SeedJasmineData extends StatefulWidget {
  const SeedJasmineData({super.key});

  @override
  State<SeedJasmineData> createState() => _SeedJasmineDataState();
}

class _SeedJasmineDataState extends State<SeedJasmineData> {
  bool _isRunning = false;
  int _done = 0;
  String? _error;

  Future<void> _importAll() async {
    setState(() {
      _isRunning = true;
      _done = 0;
      _error = null;
    });

    try {
      if (!await isUserLoggedIn()) {
        throw NotLoggedInException('Log in first.');
      }
      if (!mounted) return;
      await getKeyFromUserIfRequired(context, widget);

      for (final record in jasmineAlvarezRecords) {
        final jsonString = jsonEncode(record);
        // Stagger the filename with the running index so each write gets a
        // unique file name even if they land in the same millisecond.
        final fileName =
            'health_record_${DateTime.now().millisecondsSinceEpoch}'
            '_${_done.toString().padLeft(3, '0')}.json.enc.ttl';
        await writePod(fileName, jsonString, encrypted: true);
        setState(() => _done++);
        // Tiny delay so filenames don't collide and the UI visibly progresses.
        await Future.delayed(const Duration(milliseconds: 120));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${jasmineAlvarezRecords.length} records for '
            'Jasmine Alvarez.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } on Exception catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = jasmineAlvarezRecords.length;
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_upload_outlined, size: 56),
              const SizedBox(height: 16),
              const Text(
                'Seed Demo Data: Jasmine Alvarez',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                '$total health records, age 11 -> 30.\n'
                'Yearly 2007-2020, then monthly 2021-2026.\n'
                'Writes for real via writePod(encrypted: true).',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_isRunning) ...[
                LinearProgressIndicator(value: total == 0 ? 0 : _done / total),
                const SizedBox(height: 8),
                Text('$_done / $total written'),
              ] else
                ElevatedButton.icon(
                  onPressed: _importAll,
                  icon: const Icon(Icons.play_arrow),
                  label: Text('Import $total Records'),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
*/
