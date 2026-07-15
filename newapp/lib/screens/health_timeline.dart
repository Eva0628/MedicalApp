/// Health Timeline page. Displays a patient's medication history and
/// lab/symptom trends as graphs.
///
/// This is a menu-item page rendered inside the app's [SolidScaffold], so it
/// returns a body-only widget (no top-level [AppBar]); the scaffold supplies
/// the app bar.
///
/// The data comes from [samplePatient] in `patient_data.dart` — fictional,
/// in-memory sample data, so this page works without any POD `.ttl` file to
/// import. Swap it for records read back from the POD once you have real data.
///
/// No external chart package required — charts are drawn with CustomPainter.
library;

import 'package:flutter/material.dart';

import 'package:newapp/screens/patient_data.dart';

class HealthTimelineScreen extends StatelessWidget {
  /// The patient to display. When null, falls back to the fictional
  /// [samplePatient] (keeps the constructor const-friendly).
  final PatientProfile? patient;

  const HealthTimelineScreen({super.key, this.patient});

  @override
  Widget build(BuildContext context) {
    final patient = this.patient ?? samplePatient;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PatientHeader(patient: patient),
        const SizedBox(height: 24),
        const _SectionTitle('Current Medications'),
        const SizedBox(height: 8),
        ...patient.currentMedications.map((m) => _MedicationTile(med: m)),
        const SizedBox(height: 24),
        const _SectionTitle('TSH Levels (5-Year Trend)'),
        const SizedBox(height: 8),
        _ChartCard(
          child: _LineChart(
            points: patient.tshHistory
                .map((r) => ChartPoint(r.date, r.value))
                .toList(),
            unit: 'mIU/L',
            lineColor: const Color(0xFF2E7D6B),
            referenceMin: 0.4,
            referenceMax: 4.0,
            referenceLabel: 'Normal range',
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Migraine Frequency (episodes/month)'),
        const SizedBox(height: 8),
        _ChartCard(
          child: _LineChart(
            points: patient.migraineFrequency
                .map((p) => ChartPoint(p.date, p.episodesPerMonth.toDouble()))
                .toList(),
            unit: '/mo',
            lineColor: Colors.deepOrange,
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Medication Timeline'),
        const SizedBox(height: 8),
        _MedicationTimeline(events: patient.medicationTimeline),
      ],
    );
  }
}

class _PatientHeader extends StatelessWidget {
  final PatientProfile patient;
  const _PatientHeader({required this.patient});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.primaryContainer,
                child:
                    Text(patient.name[0], style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text('${patient.age} yrs · ${patient.gender} · '
                        '${patient.heightCm.toStringAsFixed(0)} cm · '
                        '${patient.weightKg.toStringAsFixed(1)} kg'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: patient.conditions
                .map(
                  (c) => Chip(
                    label: Text(c, style: const TextStyle(fontSize: 12)),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }
}

class _MedicationTile extends StatelessWidget {
  final Medication med;
  const _MedicationTile({required this.med});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.medication_outlined,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${med.name} — ${med.dose}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${med.frequency} · ${med.purpose}',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            if (med.maxInstructions != null) ...[
              const SizedBox(height: 4),
              Text(
                med.maxInstructions!,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.error,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final Widget child;
  const _ChartCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(12, 16, 20, 12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class ChartPoint {
  final DateTime date;
  final double value;
  ChartPoint(this.date, this.value);
}

class _LineChart extends StatelessWidget {
  final List<ChartPoint> points;
  final String unit;
  final Color lineColor;
  final double? referenceMin;
  final double? referenceMax;
  final String? referenceLabel;

  const _LineChart({
    required this.points,
    required this.unit,
    required this.lineColor,
    this.referenceMin,
    this.referenceMax,
    this.referenceLabel,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _LineChartPainter(
        points: points,
        lineColor: lineColor,
        gridColor: Theme.of(context).colorScheme.outlineVariant,
        textColor: Theme.of(context).colorScheme.onSurfaceVariant,
        referenceMin: referenceMin,
        referenceMax: referenceMax,
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<ChartPoint> points;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;
  final double? referenceMin;
  final double? referenceMax;

  _LineChartPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
    this.referenceMin,
    this.referenceMax,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final values = points.map((p) => p.value).toList();
    double minY = values.reduce((a, b) => a < b ? a : b);
    double maxY = values.reduce((a, b) => a > b ? a : b);
    if (referenceMin != null) {
      minY = minY < referenceMin! ? minY : referenceMin!;
    }
    if (referenceMax != null) {
      maxY = maxY > referenceMax! ? maxY : referenceMax!;
    }
    final pad = (maxY - minY) * 0.2 + 0.5;
    minY -= pad;
    maxY += pad;

    const leftPad = 32.0;
    const bottomPad = 20.0;
    final chartWidth = size.width - leftPad;
    final chartHeight = size.height - bottomPad;

    double xFor(int i) =>
        leftPad + (i / (points.length - 1).clamp(1, 999)) * chartWidth;
    double yFor(double v) =>
        chartHeight - ((v - minY) / (maxY - minY)) * chartHeight;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    // Horizontal grid lines + Y labels
    for (int i = 0; i <= 3; i++) {
      final v = minY + (maxY - minY) * i / 3;
      final y = yFor(v);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
          text: v.toStringAsFixed(1),
          style: TextStyle(color: textColor, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    // Reference band (e.g. normal range)
    if (referenceMin != null && referenceMax != null) {
      final bandPaint = Paint()..color = lineColor.withValues(alpha: 0.08);
      canvas.drawRect(
        Rect.fromLTRB(
          leftPad,
          yFor(referenceMax!),
          size.width,
          yFor(referenceMin!),
        ),
        bandPaint,
      );
    }

    // Line + points
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = xFor(i);
      final y = yFor(points[i].value);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = lineColor;
    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(Offset(xFor(i), yFor(points[i].value)), 3, dotPaint);
    }

    // X labels (year), sparse to avoid crowding
    for (int i = 0; i < points.length; i++) {
      if (i % 2 != 0 && i != points.length - 1) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: '${points[i].date.year}',
          style: TextStyle(color: textColor, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(xFor(i) - tp.width / 2, chartHeight + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => false;
}

class _MedicationTimeline extends StatelessWidget {
  final List<MedicationEvent> events;
  const _MedicationTimeline({required this.events});

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: List.generate(events.length, (i) {
        final e = events[i];
        final isLast = i == events.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(width: 2, color: scheme.outlineVariant),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(e.date),
                        style: TextStyle(fontSize: 12, color: scheme.outline),
                      ),
                      Text(
                        '${e.medication} — ${e.action}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(e.detail, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
