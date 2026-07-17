/// Health dashboard. Reads back the encrypted health records saved to your
/// Solid Pod by the Add Health Record page and shows summary statistics, trend
/// graphs and the individual records, most recent first.
///
/// This follows the same POD read flow as `view_notes.dart`:
/// isUserLoggedIn -> getKeyFromUserIfRequired -> getResources -> readPod.
///
/// Graphs are drawn with a small self-contained CustomPaint line chart, so no
/// extra charting dependency is required.

library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:newapp/constants/theme.dart';

import 'package:solidpod/solidpod.dart';

import 'package:solidui/solidui.dart';

/// A single health record read back from the POD, mirroring the JSON written
/// by `add_health_record.dart`.
class HealthRecord {
  const HealthRecord({
    required this.fileName,
    required this.age,
    required this.weightKg,
    required this.heightCm,
    required this.systolicBp,
    required this.diastolicBp,
    required this.restingHeartRate,
    required this.sleepHours,
    required this.exerciseMinutesPerWeek,
    required this.smoker,
    required this.familyHistory,
    required this.bmi,
    required this.timestamp,
  });

  final String fileName;
  final int? age;
  final double? weightKg;
  final double? heightCm;
  final int? systolicBp;
  final int? diastolicBp;
  final int? restingHeartRate;
  final double? sleepHours;
  final int? exerciseMinutesPerWeek;
  final bool smoker;
  final bool familyHistory;
  final double? bmi;
  final DateTime? timestamp;

  /// Build a record from the decoded JSON map, tolerating missing/typed values.
  factory HealthRecord.fromJson(String fileName, Map<String, dynamic> j) {
    double? toDouble(Object? v) => v == null ? null : (v as num).toDouble();
    int? toInt(Object? v) => v == null ? null : (v as num).toInt();

    return HealthRecord(
      fileName: fileName,
      age: toInt(j['age']),
      weightKg: toDouble(j['weightKg']),
      heightCm: toDouble(j['heightCm']),
      systolicBp: toInt(j['systolicBp']),
      diastolicBp: toInt(j['diastolicBp']),
      restingHeartRate: toInt(j['restingHeartRate']),
      sleepHours: toDouble(j['sleepHours']),
      exerciseMinutesPerWeek: toInt(j['exerciseMinutesPerWeek']),
      smoker: j['smoker'] == true,
      familyHistory: j['familyHistory'] == true,
      bmi: toDouble(j['bmi']),
      timestamp: DateTime.tryParse((j['timestamp'] as String?) ?? ''),
    );
  }
}

class HealthDashboard extends StatefulWidget {
  const HealthDashboard({super.key});

  @override
  State<HealthDashboard> createState() => _HealthDashboardState();
}

class _HealthDashboardState extends State<HealthDashboard> {
  bool _isLoading = true;
  List<HealthRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);

    try {
      if (!await isUserLoggedIn()) {
        throw NotLoggedInException('User must be logged in to view records.');
      }

      if (!mounted) return;
      await getKeyFromUserIfRequired(context, widget);

      // List every file in the app's POD data directory and keep only the
      // health records saved by the Add Health Record page (or imported as
      // `health_record_*.json.enc.ttl` via the file browser).
      final fileNames = (await getResources())
          .where(
            (name) =>
                name.startsWith('health_record_') && name.contains('.json'),
          )
          .toList();

      // Read + decrypt the records in small concurrent batches. Reading a
      // large history one file at a time is the main cause of a slow first
      // load; batching cuts the wait dramatically while keeping the number of
      // simultaneous connections to the Pod server modest.
      const batchSize = 8;
      final jsonStrings = <String>[];
      for (var i = 0; i < fileNames.length; i += batchSize) {
        final batch = fileNames.skip(i).take(batchSize);
        jsonStrings.addAll(await Future.wait(batch.map(readPod)));
      }

      final records = <HealthRecord>[];
      for (var i = 0; i < fileNames.length; i++) {
        // Parse each decrypted JSON string back into a record.
        final data = jsonDecode(jsonStrings[i]) as Map<String, dynamic>;
        records.add(HealthRecord.fromJson(fileNames[i], data));
      }

      // Show the most recent records first.
      records.sort((a, b) {
        final aTime = a.timestamp?.millisecondsSinceEpoch ?? 0;
        final bTime = b.timestamp?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });

      if (!mounted) return;
      setState(() {
        _records = records;
      });
    } on NotLoggedInException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to be logged in to view the dashboard.'),
          backgroundColor: AppColors.bad,
        ),
      );
    } on AccessForbiddenException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission denied while reading records.'),
          backgroundColor: AppColors.bad,
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load records: $e'),
          backgroundColor: AppColors.bad,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static String _shortDate(DateTime? t) {
    if (t == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.month)}-${two(t.day)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_records.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.monitor_heart,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text('No health records saved yet.'),
            const SizedBox(height: 8),
            const Text(
              'Add a record, or upload health_record_*.ttl files\n'
              'via the App Files browser.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadRecords,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final latest = _records.first; // sorted newest first

    // Records in chronological order (oldest -> newest) for the trend charts.
    final chrono = _records.reversed.toList();
    final xLabels = chrono.map((r) => _shortDate(r.timestamp)).toList();

    // Trend-line colours, all drawn from the shared clinical palette so the
    // dashboard matches the rest of the app. Single-series charts use the teal
    // primary; the two-line blood-pressure chart pairs the teal primary with
    // the dark heading tone so systolic and diastolic stay distinct.
    const weightColor = AppColors.primary;
    const systolicColor = AppColors.primary;
    const diastolicColor = AppColors.heading;
    const hrColor = AppColors.primary;
    const sleepColor = AppColors.primary;

    return RefreshIndicator(
      onRefresh: _loadRecords,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;
          // Available width inside the 16px padding.
          final contentW = constraints.maxWidth - 32;
          final chartW = isWide ? (contentW - 12) / 2 : contentW;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.dashboard, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Health Dashboard',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Summary cards computed from the real POD records.
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatCard(
                      label: 'Records',
                      value: '${_records.length}',
                      icon: Icons.folder_outlined,
                    ),
                    _StatCard(
                      label: 'Age',
                      value: latest.age?.toString() ?? '—',
                      icon: Icons.cake_outlined,
                    ),
                    _StatCard(
                      label: 'Weight',
                      value: latest.weightKg == null
                          ? '—'
                          : '${latest.weightKg!.toStringAsFixed(1)} kg',
                      icon: Icons.monitor_weight_outlined,
                    ),
                    _StatCard(
                      label: 'Height',
                      value: latest.heightCm == null
                          ? '—'
                          : '${latest.heightCm!.toStringAsFixed(0)} cm',
                      icon: Icons.height_outlined,
                    ),
                    _StatCard(
                      label: 'BMI',
                      value: latest.bmi?.toStringAsFixed(1) ?? '—',
                      icon: Icons.straighten_outlined,
                    ),
                    _StatCard(
                      label: 'Blood Pressure',
                      value: (latest.systolicBp == null ||
                              latest.diastolicBp == null)
                          ? '—'
                          : '${latest.systolicBp}/${latest.diastolicBp}',
                      icon: Icons.favorite_outline,
                    ),
                    _StatCard(
                      label: 'Resting HR',
                      value: latest.restingHeartRate == null
                          ? '—'
                          : '${latest.restingHeartRate} bpm',
                      icon: Icons.monitor_heart_outlined,
                    ),
                    _StatCard(
                      label: 'Sleep',
                      value: latest.sleepHours == null
                          ? '—'
                          : '${latest.sleepHours} h',
                      icon: Icons.bedtime_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text('Trends', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  _records.length < 2
                      ? 'Add more records to see trends over time.'
                      : 'Metrics over time (oldest → newest).',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),

                // Trend charts for the requested metrics.
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _TrendCard(
                      title: 'Weight',
                      unit: 'kg',
                      width: chartW,
                      xLabels: xLabels,
                      series: [
                        _Series(
                          'Weight',
                          weightColor,
                          chrono.map((r) => r.weightKg).toList(),
                        ),
                      ],
                    ),
                    _TrendCard(
                      title: 'Blood Pressure',
                      unit: 'mmHg',
                      width: chartW,
                      xLabels: xLabels,
                      series: [
                        _Series(
                          'Systolic',
                          systolicColor,
                          chrono.map((r) => r.systolicBp?.toDouble()).toList(),
                        ),
                        _Series(
                          'Diastolic',
                          diastolicColor,
                          chrono.map((r) => r.diastolicBp?.toDouble()).toList(),
                        ),
                      ],
                    ),
                    _TrendCard(
                      title: 'Resting Heart Rate',
                      unit: 'bpm',
                      width: chartW,
                      xLabels: xLabels,
                      series: [
                        _Series(
                          'Resting HR',
                          hrColor,
                          chrono
                              .map((r) => r.restingHeartRate?.toDouble())
                              .toList(),
                        ),
                      ],
                    ),
                    _TrendCard(
                      title: 'Sleep',
                      unit: 'hours/night',
                      width: chartW,
                      xLabels: xLabels,
                      series: [
                        _Series(
                          'Sleep',
                          sleepColor,
                          chrono.map((r) => r.sleepHours).toList(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text('History', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),

                // Records list/grid.
                isWide
                    ? GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _records.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisExtent: 170,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemBuilder: (context, i) =>
                            _RecordCard(record: _records[i]),
                      )
                    : Column(
                        children: _records
                            .map(
                              (r) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _RecordCard(record: r),
                              ),
                            )
                            .toList(),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One named data series for a trend chart. [values] is aligned to the
/// chronological record list; a null entry is treated as a gap (no point).
class _Series {
  const _Series(this.name, this.color, this.values);

  final String name;
  final Color color;
  final List<double?> values;
}

/// A card containing a titled trend chart with a legend.
class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.title,
    required this.unit,
    required this.width,
    required this.series,
    required this.xLabels,
  });

  final String title;
  final String unit;
  final double width;
  final List<_Series> series;
  final List<String> xLabels;

  bool get _hasData => series.any((s) => s.values.any((v) => v != null));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      height: 240,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$title ($unit)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  // Legend for multi-series charts (e.g. blood pressure).
                  if (series.length > 1)
                    Wrap(
                      spacing: 10,
                      children: series
                          .map((s) => _LegendDot(color: s.color, label: s.name))
                          .toList(),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _hasData
                    ? _LineChart(series: series, xLabels: xLabels)
                    : Center(
                        child: Text(
                          'No data',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

/// A minimal multi-series line chart drawn with CustomPaint.
class _LineChart extends StatelessWidget {
  const _LineChart({required this.series, required this.xLabels});

  final List<_Series> series;
  final List<String> xLabels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _LineChartPainter(
        series: series,
        xLabels: xLabels,
        gridColor: scheme.outlineVariant,
        labelColor: scheme.onSurfaceVariant,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.series,
    required this.xLabels,
    required this.gridColor,
    required this.labelColor,
  });

  final List<_Series> series;
  final List<String> xLabels;
  final Color gridColor;
  final Color labelColor;

  TextPainter _label(String text) => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(color: labelColor, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 36.0;
    const rightPad = 8.0;
    const topPad = 8.0;
    const bottomPad = 20.0;
    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;
    if (chartW <= 0 || chartH <= 0) return;

    // Overall min/max across every series.
    final all = <double>[];
    for (final s in series) {
      all.addAll(s.values.whereType<double>());
    }
    if (all.isEmpty) return;

    var minY = all.reduce(min);
    var maxY = all.reduce(max);
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }
    final range = maxY - minY;
    minY -= range * 0.1;
    maxY += range * 0.1;

    final n = series.first.values.length;
    double xFor(int i) =>
        n <= 1 ? leftPad + chartW / 2 : leftPad + chartW * i / (n - 1);
    double yFor(double v) => topPad + chartH * (1 - (v - minY) / (maxY - minY));

    // Horizontal gridlines + y-axis labels (min, mid, max).
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var g = 0; g <= 2; g++) {
      final v = minY + (maxY - minY) * g / 2;
      final y = yFor(v);
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(leftPad + chartW, y),
        gridPaint,
      );
      final tp = _label(v.toStringAsFixed(0));
      tp.paint(canvas, Offset(leftPad - tp.width - 4, y - tp.height / 2));
    }

    // X-axis labels: first and last date.
    if (xLabels.isNotEmpty) {
      final first = _label(xLabels.first);
      first.paint(canvas, Offset(leftPad, topPad + chartH + 4));
      if (xLabels.length > 1) {
        final last = _label(xLabels.last);
        last.paint(
          canvas,
          Offset(leftPad + chartW - last.width, topPad + chartH + 4),
        );
      }
    }

    // Each series as a polyline with dots, breaking the line at null gaps.
    for (final s in series) {
      final linePaint = Paint()
        ..color = s.color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final dotPaint = Paint()
        ..color = s.color
        ..style = PaintingStyle.fill;

      final path = Path();
      var started = false;
      for (var i = 0; i < s.values.length; i++) {
        final v = s.values[i];
        if (v == null) {
          started = false;
          continue;
        }
        final o = Offset(xFor(i), yFor(v));
        if (!started) {
          path.moveTo(o.dx, o.dy);
          started = true;
        } else {
          path.lineTo(o.dx, o.dy);
        }
        canvas.drawCircle(o, 2.5, dotPaint);
      }
      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.series != series ||
      old.xLabels != xLabels ||
      old.gridColor != gridColor ||
      old.labelColor != labelColor;
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final HealthRecord record;

  const _RecordCard({required this.record});

  String get _dateLabel {
    final t = record.timestamp;
    if (t == null) return record.fileName;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetail(context, record),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.event_note, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _dateLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (record.weightKg != null)
                    _InfoChip(label: '${record.weightKg} kg'),
                  if (record.bmi != null)
                    _InfoChip(label: 'BMI ${record.bmi!.toStringAsFixed(1)}'),
                  if (record.systolicBp != null && record.diastolicBp != null)
                    _InfoChip(
                      label: 'BP ${record.systolicBp}/${record.diastolicBp}',
                    ),
                  if (record.restingHeartRate != null)
                    _InfoChip(label: '${record.restingHeartRate} bpm'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, HealthRecord r) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _dateLabel,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _DetailRow('Age', r.age == null ? '—' : '${r.age} years'),
            _DetailRow('Weight', r.weightKg == null ? '—' : '${r.weightKg} kg'),
            _DetailRow('Height', r.heightCm == null ? '—' : '${r.heightCm} cm'),
            _DetailRow('BMI', r.bmi?.toStringAsFixed(1) ?? '—'),
            _DetailRow(
              'Blood Pressure',
              (r.systolicBp == null || r.diastolicBp == null)
                  ? '—'
                  : '${r.systolicBp}/${r.diastolicBp} mmHg',
            ),
            _DetailRow(
              'Resting HR',
              r.restingHeartRate == null ? '—' : '${r.restingHeartRate} bpm',
            ),
            _DetailRow(
              'Sleep',
              r.sleepHours == null ? '—' : '${r.sleepHours} h/night',
            ),
            _DetailRow(
              'Exercise',
              r.exerciseMinutesPerWeek == null
                  ? '—'
                  : '${r.exerciseMinutesPerWeek} min/week',
            ),
            _DetailRow('Smoker', r.smoker ? 'Yes' : 'No'),
            _DetailRow('Family History', r.familyHistory ? 'Yes' : 'No'),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
