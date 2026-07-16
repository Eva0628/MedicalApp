/// View health record functionality. This reads back the health records saved
/// to your Solid Pod by the Add Health Record page, decrypting each one and
/// listing its key metrics and created time.
///
/// Each record can be *shared* with a doctor / third-party WebID and the
/// sharing *revoked* again at any time. Both actions are performed through
/// solidui's `GrantPermissionUi` — the POD's real permission-management
/// screen. Tapping "Share" on a record deep-links straight into it, scoped to
/// that record, where the user chooses the recipient and which access modes to
/// grant (read / write / append / control). The same screen lists everyone who
/// currently has access and lets you revoke any of them.

library;

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:solidpod/solidpod.dart';

import 'package:solidui/solidui.dart';

/// A single health record read back from the POD.

class _HealthRecord {
  const _HealthRecord({
    required this.fileName,
    required this.data,
    required this.createdAt,
  });

  final String fileName;
  final Map<String, dynamic> data;
  final DateTime? createdAt;

  int? get age => (data['age'] as num?)?.toInt();
  double? get weightKg => (data['weightKg'] as num?)?.toDouble();
  double? get heightCm => (data['heightCm'] as num?)?.toDouble();
  int? get systolicBp => (data['systolicBp'] as num?)?.toInt();
  int? get diastolicBp => (data['diastolicBp'] as num?)?.toInt();
  int? get restingHeartRate => (data['restingHeartRate'] as num?)?.toInt();
  double? get sleepHours => (data['sleepHours'] as num?)?.toDouble();
  int? get exerciseMinutesPerWeek =>
      (data['exerciseMinutesPerWeek'] as num?)?.toInt();
  bool get smoker => (data['smoker'] as bool?) ?? false;
  bool get familyHistory => (data['familyHistory'] as bool?) ?? false;
  double? get bmi => (data['bmi'] as num?)?.toDouble();

  /// The recorded timestamp, preferring the value stored inside the record and
  /// falling back to the time encoded in the file name.
  DateTime? get recordedAt {
    final iso = data['timestamp'] as String?;
    if (iso != null) {
      final parsed = DateTime.tryParse(iso);
      if (parsed != null) return parsed;
    }
    return createdAt;
  }
}

class ViewHealthRecord extends StatefulWidget {
  const ViewHealthRecord({super.key});

  @override
  State<ViewHealthRecord> createState() => _ViewHealthRecordState();
}

class _ViewHealthRecordState extends State<ViewHealthRecord> {
  bool _isLoading = true;
  List<_HealthRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  /// Extract the created time encoded in the record file name. The Add Health
  /// Record page names files `health_record_<millisecondsSinceEpoch>.json...`.

  DateTime? _createdAtFromFileName(String fileName) {
    final match = RegExp(r'health_record_(\d+)\.json').firstMatch(fileName);
    if (match == null) return null;
    final millis = int.tryParse(match.group(1)!);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);

    try {
      if (!await isUserLoggedIn()) {
        throw NotLoggedInException(
          'User must be logged in to view health records.',
        );
      }

      if (!mounted) return;
      await getKeyFromUserIfRequired(context, widget);

      // List every file in the app's POD data directory and keep only the
      // health records saved by the Add Health Record page.
      final fileNames = (await getResources())
          .where(
            (name) => name.startsWith('health_record_') && name.contains('.json'),
          )
          .toList();

      final records = <_HealthRecord>[];
      for (final fileName in fileNames) {
        // Read and decrypt each record, then parse the JSON string back.
        final jsonString = await readPod(fileName);
        final data = jsonDecode(jsonString) as Map<String, dynamic>;

        records.add(
          _HealthRecord(
            fileName: fileName,
            data: data,
            createdAt: _createdAtFromFileName(fileName),
          ),
        );
      }

      // Show the most recent records first.
      records.sort((a, b) {
        final aTime = a.recordedAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.recordedAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });

      if (!mounted) return;
      setState(() => _records = records);
    } on NotLoggedInException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to be logged in to view health records.'),
          backgroundColor: Colors.red,
        ),
      );
    } on AccessForbiddenException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission denied while reading health records.'),
          backgroundColor: Colors.red,
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load health records: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Unknown date';
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  /// Open the POD's real permission-management screen (solidui's
  /// `GrantPermissionUi`) scoped to a single record. This is where the user
  /// picks a recipient WebID, chooses which access modes to grant, and where
  /// existing grants are listed and revoked.
  Future<void> _managePermissions(String resourceFileName) async {
    if (!await isUserLoggedIn()) return;
    if (!mounted) return;
    await getKeyFromUserIfRequired(context, widget);
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GrantPermissionUi(
          title: 'Share health record',
          resourceNames: [resourceFileName],
          child: const ViewHealthRecord(),
        ),
      ),
    );

    await _loadRecords();
  }

  void _showRecord(_HealthRecord record) {
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 160,
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(child: Text(value)),
            ],
          ),
        );

    String num(Object? v, [String suffix = '']) =>
        v == null ? '—' : '$v$suffix';

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Record • ${_formatDate(record.recordedAt)}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              row('Age', num(record.age)),
              row('Weight', num(record.weightKg, ' kg')),
              row('Height', num(record.heightCm, ' cm')),
              row(
                'BMI',
                record.bmi == null ? '—' : record.bmi!.toStringAsFixed(1),
              ),
              row(
                'Blood pressure',
                record.systolicBp == null && record.diastolicBp == null
                    ? '—'
                    : '${record.systolicBp ?? '—'}/${record.diastolicBp ?? '—'} mmHg',
              ),
              row('Resting heart rate', num(record.restingHeartRate, ' bpm')),
              row('Sleep', num(record.sleepHours, ' h/night')),
              row('Exercise', num(record.exerciseMinutesPerWeek, ' min/week')),
              row('Smoker', record.smoker ? 'Yes' : 'No'),
              row('Family history', record.familyHistory ? 'Yes' : 'No'),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _managePermissions(record.fileName);
            },
            icon: const Icon(Icons.share_outlined),
            label: const Text('Share / manage access'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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

    return RefreshIndicator(
      onRefresh: _loadRecords,
      child: ListView.builder(
        padding: const EdgeInsets.all(24.0),
        itemCount: _records.length,
        itemBuilder: (context, index) {
          final record = _records[index];
          final subtitleParts = <String>[
            if (record.bmi != null) 'BMI ${record.bmi!.toStringAsFixed(1)}',
            if (record.systolicBp != null && record.diastolicBp != null)
              'BP ${record.systolicBp}/${record.diastolicBp}',
            if (record.weightKg != null) '${record.weightKg} kg',
          ];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.monitor_heart),
              title: Text(_formatDate(record.recordedAt)),
              subtitle: Text(
                subtitleParts.isEmpty
                    ? record.fileName
                    : subtitleParts.join('  •  '),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Share / manage access',
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () => _managePermissions(record.fileName),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => _showRecord(record),
            ),
          );
        },
      ),
    );
  }
}
