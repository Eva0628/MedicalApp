/// Health Score Calculator. A pure client-side, clinical-themed calculator that
/// turns a handful of lifestyle metrics into a single 0-100 wellbeing score and
/// renders it on a colour-graded arc gauge with an encouraging message.
///
/// No POD writes and no external data files: the formula and message table are
/// hardcoded below.

library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:newapp/constants/theme.dart';

/// Specification for a single numeric input on the form.
class _FieldSpec {
  const _FieldSpec({
    required this.label,
    required this.helper,
    required this.min,
    required this.max,
  });

  final String label;
  final String helper;
  final double min;
  final double max;
}

/// The nine lifestyle inputs, in display order. The keys double as map keys for
/// the parsed values used by the scoring formula.
const Map<String, _FieldSpec> _fields = {
  'physicalActivity': _FieldSpec(
    label: 'Physical Activity (minutes/day)',
    helper: 'Valid range: 0 – 120',
    min: 0,
    max: 120,
  ),
  'nutritionScore': _FieldSpec(
    label: 'Nutrition Score',
    helper: 'Valid range: 0 – 10',
    min: 0,
    max: 10,
  ),
  'stressLevel': _FieldSpec(
    label: 'Stress Level',
    helper: 'Valid range: 1 – 10',
    min: 1,
    max: 10,
  ),
  'mindfulness': _FieldSpec(
    label: 'Mindfulness (minutes/day)',
    helper: 'Valid range: 0 – 60',
    min: 0,
    max: 60,
  ),
  'sleepHours': _FieldSpec(
    label: 'Sleep Hours',
    helper: 'Valid range: 3 – 10',
    min: 3,
    max: 10,
  ),
  'hydration': _FieldSpec(
    label: 'Hydration (liters/day)',
    helper: 'Valid range: 0.5 – 5.0',
    min: 0.5,
    max: 5.0,
  ),
  'bmi': _FieldSpec(
    label: 'BMI',
    helper: 'Valid range: 18 – 40',
    min: 18,
    max: 40,
  ),
  'alcohol': _FieldSpec(
    label: 'Alcohol (units/week)',
    helper: 'Valid range: 0 – 20',
    min: 0,
    max: 20,
  ),
  'smoking': _FieldSpec(
    label: 'Smoking (cigarettes/day)',
    helper: 'Valid range: 0 – 30',
    min: 0,
    max: 30,
  ),
};

/// Encouraging messages keyed by 10-point band. Index `i` covers scores in the
/// band `(i*10, (i+1)*10]` (upper bound inclusive), so a clamped score of
/// exactly 50 falls in the "40-50" band at index 4.
const List<String> _bandMessages = [
  "There's real opportunity here for change. Small steps count — consider talking to a healthcare provider about a plan that fits you.",
  "You're at the very start of building healthier routines. Every small habit adds up over time.",
  "You're taking the first steps. Pick one habit to focus on this week — consistency beats intensity.",
  "You're making some positive choices already. Keep building on them.",
  "You're on a steady path. A few tweaks to sleep, activity, or stress could boost things further.",
  "You're doing okay — balanced habits are showing. Keep nurturing them.",
  'Solid work. Your choices are paying off — keep the momentum going.',
  'Great job! Your habits reflect real commitment to your wellbeing.',
  "Excellent! You're modeling a genuinely balanced, healthy lifestyle.",
  'Outstanding! Your habits reflect exceptional care for your wellbeing.',
];

class HealthScoreCalculator extends StatefulWidget {
  const HealthScoreCalculator({super.key});

  @override
  State<HealthScoreCalculator> createState() => _HealthScoreCalculatorState();
}

class _HealthScoreCalculatorState extends State<HealthScoreCalculator> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {
    for (final key in _fields.keys) key: TextEditingController(),
  };

  /// The raw computed score (unclamped), or null before the first calculation.
  double? _rawScore;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validate(String? value, _FieldSpec spec) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a value';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Please enter a valid number';
    }
    if (parsed < spec.min || parsed > spec.max) {
      return 'Must be between ${_trim(spec.min)} and ${_trim(spec.max)}';
    }
    return null;
  }

  void _onCalculate() {
    if (!_formKey.currentState!.validate()) return;

    double value(String key) => double.parse(_controllers[key]!.text.trim());

    final score = 0.2 * value('physicalActivity') +
        5 * value('nutritionScore') +
        3 * value('sleepHours') +
        5 * value('hydration') +
        2 * value('mindfulness') -
        2 * value('stressLevel') -
        1.5 * value('alcohol') -
        1.5 * value('smoking') -
        1.2 * (value('bmi') - 22);

    setState(() => _rawScore = score);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final hasResult = _rawScore != null;

              // Split into two columns — form on the left, result on the right —
              // once there's a result and the window is wide enough. Otherwise
              // fall back to a single stacked column on narrow screens.
              if (hasResult && constraints.maxWidth >= 900) {
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildForm(context)),
                      const SizedBox(width: 24),
                      Expanded(child: _buildResult(context, _rawScore!)),
                    ],
                  ),
                );
              }

              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildForm(context),
                    if (hasResult) ...[
                      const SizedBox(height: 24),
                      _buildResult(context, _rawScore!),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.local_hospital,
                      size: 64,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Health Score Calculator',
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: AppColors.heading,
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your recent lifestyle metrics for a quick '
                      'wellbeing check-up.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.subtle,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              for (final entry in _fields.entries) ...[
                _buildField(context, entry.key, entry.value),
                const SizedBox(height: 20),
              ],
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _onCalculate,
                  icon: const Icon(Icons.favorite),
                  label: const Text('Calculate Score'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(BuildContext context, String key, _FieldSpec spec) {
    return TextFormField(
      controller: _controllers[key],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: spec.label,
        helperText: spec.helper,
        border: const OutlineInputBorder(),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.subtle),
      ),
      validator: (value) => _validate(value, spec),
    );
  }

  Widget _buildResult(BuildContext context, double rawScore) {
    final clamped = rawScore.clamp(0.0, 100.0);
    final color = AppColors.grade(clamped / 100);
    final bandIndex =
        (clamped <= 0 ? 0 : (clamped / 10).ceil() - 1).clamp(0, 9);
    final message = _bandMessages[bandIndex];

    return Column(
      children: [
        Card(
          color: AppColors.card,
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                Text(
                  'Your Health Score',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.heading,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                AspectRatio(
                  aspectRatio: 2,
                  child: CustomPaint(
                    painter: _GaugePainter(
                      value: clamped / 100,
                      color: color,
                      trackColor: AppColors.border,
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              clamped.round().toString(),
                              style: TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.bold,
                                color: color,
                                height: 1,
                              ),
                            ),
                            Text(
                              'out of 100',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.subtle),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Raw computed value: ${rawScore.toStringAsFixed(1)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.subtle,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildMessageCard(context, message, color),
      ],
    );
  }

  Widget _buildMessageCard(BuildContext context, String message, Color color) {
    return Card(
      color: Color.alphaBlend(color.withValues(alpha: 0.10), Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.spa_outlined, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.heading,
                      height: 1.4,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formats a range bound without a trailing `.0` for whole numbers.
String _trim(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

/// Paints a 180° top-semicircle gauge: a soft background track overlaid by a
/// value arc drawn in [color], from the left (0) to the right (100).
class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.value,
    required this.color,
    required this.trackColor,
  });

  /// Fraction of the arc to fill, 0..1.
  final double value;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 22.0;
    final radius = (size.width - stroke) / 2;
    final center = Offset(size.width / 2, size.height - stroke / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;

    // Top semicircle: start at the left (pi) and sweep pi through the top.
    canvas.drawArc(rect, math.pi, math.pi, false, trackPaint);

    final valuePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;

    final sweep = math.pi * value.clamp(0.0, 1.0);
    if (sweep > 0) {
      canvas.drawArc(rect, math.pi, sweep, false, valuePaint);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}
