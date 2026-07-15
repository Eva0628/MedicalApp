/// Healthcare dataset dashboard. Loads the bundled CSV dataset from assets and
/// renders summary charts (patient counts, test results, billing and age
/// distributions) to give population-level context for the personal health
/// prediction feature.

library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';

/// Path to the healthcare dataset bundled as an asset.
const _datasetAsset = 'assets/data/healthcare_dataset.csv';

/// Labels for the age ranges the dashboard groups patients into.
const _ageRangeLabels = ['0-20', '21-40', '41-60', '61-80', '81+'];

class DatasetDashboard extends StatefulWidget {
  const DatasetDashboard({super.key});

  @override
  State<DatasetDashboard> createState() => _DatasetDashboardState();
}

class _DatasetDashboardState extends State<DatasetDashboard> {
  bool _isLoading = true;
  String? _error;
  _DashboardData? _data;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final raw = await rootBundle.loadString(_datasetAsset);

      // The dataset has tens of thousands of rows, so parse and aggregate it
      // off the UI thread to keep the loading indicator responsive.
      final data = await compute(_parseHealthcareCsv, raw);

      if (!mounted) return;
      setState(() => _data = data);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load dashboard data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildError(context);
    }

    return _buildDashboard(context, _data!);
  }

  Widget _buildError(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Unable to load dashboard',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, _DashboardData data) {
    // Conditions are sorted once so the count and billing charts share the
    // same category ordering along the x-axis.
    final conditions = data.conditionCounts.keys.toList()..sort();

    final cards = <Widget>[
      _chartCard(
        context,
        'Patients per Medical Condition',
        _buildConditionCountChart(context, data, conditions),
      ),
      _chartCard(
        context,
        'Test Results Distribution',
        _buildTestResultsChart(context, data),
      ),
      _chartCard(
        context,
        'Average Billing per Medical Condition',
        _buildAvgBillingChart(context, data, conditions),
      ),
      _chartCard(
        context,
        'Age Distribution',
        _buildAgeChart(context, data),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Healthcare Dashboard',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${data.totalRecords} patient records',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              if (isWide)
                Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    for (final card in cards)
                      SizedBox(
                        width: (constraints.maxWidth - 24 - 48) / 2,
                        child: card,
                      ),
                  ],
                )
              else
                Column(
                  children: [
                    for (final card in cards) ...[
                      card,
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _chartCard(BuildContext context, String title, Widget chart) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(height: 260, child: chart),
          ],
        ),
      ),
    );
  }

  Widget _emptyChart(BuildContext context, String message) {
    return Center(
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _buildConditionCountChart(
    BuildContext context,
    _DashboardData data,
    List<String> conditions,
  ) {
    if (conditions.isEmpty) {
      return _emptyChart(context, 'No condition data available.');
    }

    final color = Theme.of(context).colorScheme.primary;
    final values = [
      for (final c in conditions) (data.conditionCounts[c] ?? 0).toDouble(),
    ];
    final maxY = _niceMaxY(values.reduce((a, b) => a > b ? a : b));

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barGroups: [
          for (var i = 0; i < conditions.length; i++)
            _barGroup(i, values[i], color),
        ],
        titlesData: _barTitles(
          context,
          bottomLabel: (i) =>
              i >= 0 && i < conditions.length ? conditions[i] : '',
          leftFormatter: _compactNumber,
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        barTouchData: _barTouchData(context, (i) => conditions[i]),
      ),
    );
  }

  Widget _buildAvgBillingChart(
    BuildContext context,
    _DashboardData data,
    List<String> conditions,
  ) {
    if (conditions.isEmpty) {
      return _emptyChart(context, 'No billing data available.');
    }

    final color = Theme.of(context).colorScheme.tertiary;
    final values = [
      for (final c in conditions) data.avgBillingByCondition[c] ?? 0,
    ];
    final maxY = _niceMaxY(values.reduce((a, b) => a > b ? a : b));

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barGroups: [
          for (var i = 0; i < conditions.length; i++)
            _barGroup(i, values[i], color),
        ],
        titlesData: _barTitles(
          context,
          bottomLabel: (i) =>
              i >= 0 && i < conditions.length ? conditions[i] : '',
          leftFormatter: _currencyCompact,
          leftReservedSize: 48,
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        barTouchData: _barTouchData(
          context,
          (i) => conditions[i],
          valueFormatter: (v) => '\$${v.toStringAsFixed(0)}',
        ),
      ),
    );
  }

  Widget _buildAgeChart(BuildContext context, _DashboardData data) {
    final total = data.ageBuckets.fold<int>(0, (a, b) => a + b);
    if (total == 0) {
      return _emptyChart(context, 'No age data available.');
    }

    final color = Theme.of(context).colorScheme.secondary;
    final values = [for (final b in data.ageBuckets) b.toDouble()];
    final maxY = _niceMaxY(values.reduce((a, b) => a > b ? a : b));

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barGroups: [
          for (var i = 0; i < values.length; i++)
            _barGroup(i, values[i], color),
        ],
        titlesData: _barTitles(
          context,
          bottomLabel: (i) =>
              i >= 0 && i < _ageRangeLabels.length ? _ageRangeLabels[i] : '',
          leftFormatter: _compactNumber,
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        barTouchData: _barTouchData(context, (i) => _ageRangeLabels[i]),
      ),
    );
  }

  Widget _buildTestResultsChart(BuildContext context, _DashboardData data) {
    if (data.testResults.isEmpty) {
      return _emptyChart(context, 'No test result data available.');
    }

    final entries = data.testResults.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (a, e) => a + e.value);
    final palette = _piePalette(context);

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value.toDouble(),
                    title: '${(entries[i].value / total * 100).round()}%',
                    color: palette[i % palette.length],
                    radius: 70,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < entries.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
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
          ),
        ),
      ],
    );
  }

  // Shared chart building blocks. ------------------------------------------

  BarChartGroupData _barGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 18,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
        ),
      ],
    );
  }

  FlTitlesData _barTitles(
    BuildContext context, {
    required String Function(int index) bottomLabel,
    required String Function(double value) leftFormatter,
    double leftReservedSize = 40,
  }) {
    final style = Theme.of(context).textTheme.bodySmall;

    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: leftReservedSize,
          getTitlesWidget: (value, meta) {
            if (value != meta.max && value == meta.min) {
              return const SizedBox.shrink();
            }
            return SideTitleWidget(
              meta: meta,
              child: Text(leftFormatter(value), style: style),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 44,
          getTitlesWidget: (value, meta) {
            return SideTitleWidget(
              meta: meta,
              space: 6,
              child: SizedBox(
                width: 56,
                child: Text(
                  bottomLabel(value.toInt()),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: style?.copyWith(fontSize: 10),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  BarTouchData _barTouchData(
    BuildContext context,
    String Function(int index) label, {
    String Function(double value)? valueFormatter,
  }) {
    return BarTouchData(
      touchTooltipData: BarTouchTooltipData(
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          final value = valueFormatter != null
              ? valueFormatter(rod.toY)
              : rod.toY.toStringAsFixed(0);
          return BarTooltipItem(
            '${label(group.x)}\n',
            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Color> _piePalette(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return [
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      scheme.error,
    ];
  }
}

/// A "nice" upper bound for a bar chart axis: a little headroom above the
/// largest value, rounded up to a readable step.
double _niceMaxY(double maxValue) {
  if (maxValue <= 0) return 1;
  final padded = maxValue * 1.15;
  final magnitude = _pow10(padded.floor().toString().length - 1);
  return (padded / magnitude).ceil() * magnitude;
}

double _pow10(int exponent) {
  var result = 1.0;
  for (var i = 0; i < exponent; i++) {
    result *= 10;
  }
  return result;
}

String _compactNumber(double value) {
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k';
  }
  return value.toStringAsFixed(0);
}

String _currencyCompact(double value) {
  if (value >= 1000) {
    return '\$${(value / 1000).toStringAsFixed(0)}k';
  }
  return '\$${value.toStringAsFixed(0)}';
}

/// Aggregated dashboard figures, computed once from the raw CSV.
class _DashboardData {
  const _DashboardData({
    required this.conditionCounts,
    required this.testResults,
    required this.avgBillingByCondition,
    required this.ageBuckets,
    required this.totalRecords,
  });

  final Map<String, int> conditionCounts;
  final Map<String, int> testResults;
  final Map<String, double> avgBillingByCondition;
  final List<int> ageBuckets;
  final int totalRecords;
}

/// Returns the [_ageRangeLabels] bucket index a patient [age] falls into.
int _ageBucketIndex(int age) {
  if (age <= 20) return 0;
  if (age <= 40) return 1;
  if (age <= 60) return 2;
  if (age <= 80) return 3;
  return 4;
}

/// Parses the healthcare CSV and computes every aggregate the dashboard needs.
///
/// Runs inside a background isolate via [compute], so it must be a top-level
/// function and only touch data passed in through [raw].
_DashboardData _parseHealthcareCsv(String raw) {
  // Keep every field as a string (dynamicTyping: false) and let the decoder
  // auto-detect the delimiter and line endings so both `\n` and `\r\n` work.
  final rows = Csv(
    autoDetect: true,
    skipEmptyLines: true,
    dynamicTyping: false,
  ).decode(raw);

  if (rows.length < 2) {
    return const _DashboardData(
      conditionCounts: {},
      testResults: {},
      avgBillingByCondition: {},
      ageBuckets: [0, 0, 0, 0, 0],
      totalRecords: 0,
    );
  }

  final header = [for (final cell in rows.first) cell.toString().trim()];
  int columnOf(String name) => header.indexOf(name);

  final conditionIdx = columnOf('Medical Condition');
  final testIdx = columnOf('Test Results');
  final billingIdx = columnOf('Billing Amount');
  final ageIdx = columnOf('Age');

  final conditionCounts = <String, int>{};
  final testResults = <String, int>{};
  final billingSum = <String, double>{};
  final billingCount = <String, int>{};
  final ageBuckets = List<int>.filled(_ageRangeLabels.length, 0);

  String? cell(List<dynamic> row, int index) {
    if (index < 0 || index >= row.length) return null;
    final value = row[index].toString().trim();
    return value.isEmpty ? null : value;
  }

  var totalRecords = 0;
  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    if (row.isEmpty) continue;
    totalRecords++;

    final condition = cell(row, conditionIdx);
    if (condition != null) {
      conditionCounts[condition] = (conditionCounts[condition] ?? 0) + 1;
    }

    final test = cell(row, testIdx);
    if (test != null) {
      testResults[test] = (testResults[test] ?? 0) + 1;
    }

    final billingStr = cell(row, billingIdx);
    final billing = billingStr == null ? null : double.tryParse(billingStr);
    if (condition != null && billing != null) {
      billingSum[condition] = (billingSum[condition] ?? 0) + billing;
      billingCount[condition] = (billingCount[condition] ?? 0) + 1;
    }

    final ageStr = cell(row, ageIdx);
    final age = ageStr == null ? null : int.tryParse(ageStr);
    if (age != null) {
      ageBuckets[_ageBucketIndex(age)]++;
    }
  }

  final avgBillingByCondition = <String, double>{
    for (final entry in billingSum.entries)
      entry.key: entry.value / (billingCount[entry.key] ?? 1),
  };

  return _DashboardData(
    conditionCounts: conditionCounts,
    testResults: testResults,
    avgBillingByCondition: avgBillingByCondition,
    ageBuckets: ageBuckets,
    totalRecords: totalRecords,
  );
}
