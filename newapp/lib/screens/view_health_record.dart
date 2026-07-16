/// View health record functionality. This reads back the health records saved
/// to your Solid Pod by the Add Health Record page, decrypting each one and
/// listing its key metrics and created time.
///
/// Each record can be *shared* read-only with a doctor / third-party WebID and
/// the sharing *revoked* again at any time. Sharing works in two layers:
///  1. The real Solid WAC/ACL grant on the resource, performed through
///     solidui's `GrantPermissionUi` (this is what actually lets the recipient
///     read the file).
///  2. An app-level metadata record (`access_grant_*.json.enc.ttl`) we keep so
///     the UI can show who a record is shared with, together with an intended
///     duration. The Solid ACL protocol has no concept of automatic expiry, so
///     "duration" is a promise we track and warn about ourselves — the actual
///     grant is either present or not.

library;

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:solidpod/solidpod.dart';

import 'package:solidui/solidui.dart';

/// How long a grant is intended to last. `null` duration (`noExpiry`) means the
/// grant is not expected to lapse on its own.
enum GrantDuration { oneDay, sevenDays, thirtyDays, noExpiry }

extension GrantDurationX on GrantDuration {
  String get label {
    switch (this) {
      case GrantDuration.oneDay:
        return '24 hours';
      case GrantDuration.sevenDays:
        return '7 days';
      case GrantDuration.thirtyDays:
        return '30 days';
      case GrantDuration.noExpiry:
        return 'No expiry';
    }
  }

  int? get days {
    switch (this) {
      case GrantDuration.oneDay:
        return 1;
      case GrantDuration.sevenDays:
        return 7;
      case GrantDuration.thirtyDays:
        return 30;
      case GrantDuration.noExpiry:
        return null;
    }
  }
}

/// A tracked "I granted read-only access to this WebID for this record"
/// record. This is our own metadata, separate from the real Solid ACL.
class AccessGrant {
  const AccessGrant({
    required this.metaFileName,
    required this.webId,
    required this.resourceFileName,
    required this.grantedAt,
    required this.durationDays,
    required this.revoked,
  });

  final String metaFileName; // the .ttl file this record itself is stored as
  final String webId;
  final String resourceFileName;
  final DateTime grantedAt;
  final int? durationDays; // null = no expiry
  final bool revoked;

  DateTime? get expiresAt =>
      durationDays == null ? null : grantedAt.add(Duration(days: durationDays!));

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  Map<String, dynamic> toJson() => {
        'webId': webId,
        'resourceFileName': resourceFileName,
        'grantedAt': grantedAt.toIso8601String(),
        'durationDays': durationDays,
        'revoked': revoked,
      };

  factory AccessGrant.fromJson(String metaFileName, Map<String, dynamic> j) {
    return AccessGrant(
      metaFileName: metaFileName,
      webId: (j['webId'] as String?) ?? '',
      resourceFileName: (j['resourceFileName'] as String?) ?? '',
      grantedAt: DateTime.tryParse((j['grantedAt'] as String?) ?? '') ??
          DateTime.now(),
      durationDays: j['durationDays'] as int?,
      revoked: j['revoked'] == true,
    );
  }

  AccessGrant copyWith({bool? revoked}) => AccessGrant(
        metaFileName: metaFileName,
        webId: webId,
        resourceFileName: resourceFileName,
        grantedAt: grantedAt,
        durationDays: durationDays,
        revoked: revoked ?? this.revoked,
      );
}

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
  List<AccessGrant> _grants = [];

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

      // List every file in the app's POD data directory once, then pick out
      // both the health records and the sharing metadata we track alongside
      // them.
      final allFiles = await getResources();

      final fileNames = allFiles
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

      // Load the app-level sharing metadata so each record can show who it is
      // currently shared with.
      final metaFiles = allFiles
          .where(
            (name) => name.startsWith('access_grant_') && name.contains('.json'),
          )
          .toList();

      final grants = <AccessGrant>[];
      for (final f in metaFiles) {
        final jsonString = await readPod(f);
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        final grant = AccessGrant.fromJson(f, data);
        if (!grant.revoked) grants.add(grant);
      }
      grants.sort((a, b) => b.grantedAt.compareTo(a.grantedAt));

      if (!mounted) return;
      setState(() {
        _records = records;
        _grants = grants;
      });
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

  /// Active (non-revoked) grants for a specific record file.
  List<AccessGrant> _grantsForRecord(String fileName) =>
      _grants.where((g) => g.resourceFileName == fileName).toList();

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Unknown date';
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  /// Records the grant's intended duration as encrypted metadata, then hands
  /// off to the real Solid ACL screen so the user finishes granting read-only
  /// access to the resource.
  Future<void> _startGrantFlow(
    String webId,
    String resourceFileName,
    GrantDuration duration,
  ) async {
    try {
      if (!await isUserLoggedIn()) return;
      if (!mounted) return;
      await getKeyFromUserIfRequired(context, widget);

      final grant = AccessGrant(
        metaFileName: '',
        webId: webId,
        resourceFileName: resourceFileName,
        grantedAt: DateTime.now(),
        durationDays: duration.days,
        revoked: false,
      );

      final fileName =
          'access_grant_${DateTime.now().millisecondsSinceEpoch}.json.enc.ttl';
      await writePod(fileName, jsonEncode(grant.toJson()), encrypted: true);

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GrantPermissionUi(
            resourceNames: [resourceFileName],
            child: const ViewHealthRecord(),
          ),
        ),
      );

      await _loadRecords();
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start sharing: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Soft-revoke: mark the tracked grant as revoked (writePod overwrite — no
  /// delete API required). To also remove the real Solid ACL grant, use the
  /// "Manage access" button which opens solidui's revoke screen.
  Future<void> _revokeOne(AccessGrant grant) async {
    if (!await isUserLoggedIn()) return;
    if (!mounted) return;
    await getKeyFromUserIfRequired(context, widget);

    final updated = grant.copyWith(revoked: true);
    await writePod(
      grant.metaFileName,
      jsonEncode(updated.toJson()),
      encrypted: true,
    );
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
      builder: (context) {
        // StatefulBuilder lets the sharing section refresh in place after a
        // revoke without closing the whole dialog.
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final grants = _grantsForRecord(record.fileName);

            return AlertDialog(
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
                      record.bmi == null
                          ? '—'
                          : record.bmi!.toStringAsFixed(1),
                    ),
                    row(
                      'Blood pressure',
                      record.systolicBp == null && record.diastolicBp == null
                          ? '—'
                          : '${record.systolicBp ?? '—'}/${record.diastolicBp ?? '—'} mmHg',
                    ),
                    row('Resting heart rate',
                        num(record.restingHeartRate, ' bpm'),),
                    row('Sleep', num(record.sleepHours, ' h/night')),
                    row('Exercise',
                        num(record.exerciseMinutesPerWeek, ' min/week'),),
                    row('Smoker', record.smoker ? 'Yes' : 'No'),
                    row('Family history', record.familyHistory ? 'Yes' : 'No'),
                    const SizedBox(height: 8),
                    const Divider(),
                    _SharingSection(
                      grants: grants,
                      onShare: () async {
                        // Close the detail dialog before deep-linking into the
                        // full-screen Solid ACL grant flow.
                        Navigator.of(context).pop();
                        await _shareRecord(record.fileName);
                      },
                      onRevoke: (grant) async {
                        final messenger = ScaffoldMessenger.of(context);
                        await _revokeOne(grant);
                        await _loadRecords();
                        if (!mounted) return;
                        // Reflect the change in the still-open dialog.
                        setDialogState(() {});
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Access revoked.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      onManageAccess: () async {
                        Navigator.of(context).pop();
                        await _openManageAccess(record.fileName);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Prompt for a recipient WebID + duration, then run the grant flow.
  Future<void> _shareRecord(String resourceFileName) async {
    final result = await showDialog<_NewGrantResult>(
      context: context,
      builder: (_) => const _NewGrantDialog(),
    );
    if (result == null) return;
    await _startGrantFlow(result.webId, resourceFileName, result.duration);
  }

  /// Open solidui's grant/revoke UI for the real Solid ACL of this resource,
  /// so the user can remove read access at the protocol level too.
  Future<void> _openManageAccess(String resourceFileName) async {
    if (!await isUserLoggedIn()) return;
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GrantPermissionUi(
          resourceNames: [resourceFileName],
          child: const ViewHealthRecord(),
        ),
      ),
    );
    await _loadRecords();
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
          final shareCount = _grantsForRecord(record.fileName).length;
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
                  if (shareCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.people_alt, size: 16),
                        label: Text('$shareCount'),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Share record',
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () => _shareRecord(record.fileName),
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

/// The "Shared with" block shown inside a record's detail dialog.
class _SharingSection extends StatelessWidget {
  const _SharingSection({
    required this.grants,
    required this.onShare,
    required this.onRevoke,
    required this.onManageAccess,
  });

  final List<AccessGrant> grants;
  final VoidCallback onShare;
  final ValueChanged<AccessGrant> onRevoke;
  final VoidCallback onManageAccess;

  String _shortWebId(String webId) {
    final withoutScheme = webId.replaceFirst(RegExp(r'^https?://'), '');
    return withoutScheme.length > 42
        ? '${withoutScheme.substring(0, 42)}…'
        : withoutScheme;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.shield_outlined, size: 18, color: scheme.primary),
            const SizedBox(width: 6),
            Text(
              'Sharing',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (grants.isEmpty)
          Text(
            'This record is not shared with anyone.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          )
        else
          ...grants.map((g) {
            String badgeText;
            Color badgeColor;
            if (g.durationDays == null) {
              badgeText = 'No expiry';
              badgeColor = scheme.outline;
            } else if (g.isExpired) {
              badgeText = 'Expired';
              badgeColor = Colors.red;
            } else {
              final remaining = g.expiresAt!.difference(DateTime.now());
              badgeText = remaining.inDays >= 1
                  ? 'Expires in ${remaining.inDays}d'
                  : 'Expires in ${remaining.inHours}h';
              badgeColor = remaining.inHours < 24 ? Colors.orange : Colors.green;
            }

            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _shortWebId(g.webId),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: badgeColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            'Read-only · $badgeText',
                            style: TextStyle(
                              fontSize: 10,
                              color: badgeColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Revoke',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.block, color: Colors.red, size: 20),
                    onPressed: () => onRevoke(g),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: onShare,
              icon: const Icon(Icons.person_add_alt, size: 18),
              label: const Text('Share'),
            ),
            if (grants.isNotEmpty)
              TextButton.icon(
                onPressed: onManageAccess,
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Manage access'),
              ),
          ],
        ),
      ],
    );
  }
}

class _NewGrantResult {
  const _NewGrantResult(this.webId, this.duration);
  final String webId;
  final GrantDuration duration;
}

/// Prompts for a recipient WebID and an intended access duration. The record
/// being shared is fixed by the caller, so there is no record picker here.
class _NewGrantDialog extends StatefulWidget {
  const _NewGrantDialog();

  @override
  State<_NewGrantDialog> createState() => _NewGrantDialogState();
}

class _NewGrantDialogState extends State<_NewGrantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _webIdController = TextEditingController();
  GrantDuration _duration = GrantDuration.sevenDays;

  @override
  void dispose() {
    _webIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Share Record (Read-Only)'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _webIdController,
                decoration: const InputDecoration(
                  labelText: "Doctor / recipient's WebID",
                  hintText: 'https://pods.solidcommunity.au/.../profile/card#me',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<GrantDuration>(
                initialValue: _duration,
                decoration: const InputDecoration(labelText: 'Access expires'),
                items: GrantDuration.values
                    .map(
                      (d) => DropdownMenuItem(value: d, child: Text(d.label)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _duration = v!),
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.visibility_outlined, size: 18),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Access is always granted read-only — the recipient '
                      'can never edit or delete your record.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              _NewGrantResult(
                _webIdController.text.trim(),
                _duration,
              ),
            );
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
