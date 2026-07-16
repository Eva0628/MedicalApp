/// Support / Resources hub. A single scrollable page that gathers health
/// reference material, external links, in-app tools and a note about how the
/// app stores your data on your own Solid POD.
///
/// The card layout mirrors `health_dashboard.dart`: a `LayoutBuilder` switches
/// between a two-column grid on wide screens and a single column on narrow
/// ones, and cards reuse the same elevation-0 / outlineVariant styling.
///
/// External links open in the browser via `url_launcher`; failures are reported
/// with a red SnackBar following the same pattern as `add_note.dart`.

library;

import 'package:flutter/material.dart';

import 'package:solidpod/solidpod.dart';

import 'package:solidui/solidui.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:newapp/screens/health_score_calculator.dart';

/// A health information topic shown as a card in Section 1. Tapping the card
/// opens a dialog with [dialogTitle], [body] and, optionally, a titled table.
class _InfoTopic {
  const _InfoTopic({
    required this.icon,
    required this.cardTitle,
    required this.dialogTitle,
    required this.body,
    this.tableTitle,
    this.columns,
    this.rows,
  });

  final IconData icon;
  final String cardTitle;
  final String dialogTitle;
  final String body;
  final String? tableTitle;
  final List<String>? columns;
  final List<List<String>>? rows;
}

/// An external website shown as a card in Section 2. Tapping the card opens
/// [url] in the browser.
class _ExternalLink {
  const _ExternalLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.url,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String url;
}

const List<_InfoTopic> _infoTopics = [
  _InfoTopic(
    icon: Icons.favorite,
    cardTitle: 'Blood Pressure Guide',
    dialogTitle: 'Understanding Blood Pressure',
    body: 'Blood pressure is measured using two numbers: Systolic pressure '
        '(top number) and Diastolic pressure (bottom number).',
    tableTitle: 'BP Classifications (AHA)',
    columns: ['Classification', 'Systolic (mmHg)', 'Diastolic (mmHg)'],
    rows: [
      ['Normal', 'Less than 120', 'Less than 80'],
      ['Elevated', '120-129', 'Less than 80'],
      ['Stage 1 High', '130-139', '80-89'],
      ['Stage 2 High', '140 or higher', '90 or higher'],
      ['Crisis', 'Over 180', 'Over 120'],
    ],
  ),
  _InfoTopic(
    icon: Icons.monitor_weight,
    cardTitle: 'Understanding BMI',
    dialogTitle: 'Body Mass Index (BMI)',
    body: "BMI estimates body fat based on height and weight. It's a screening "
        'tool, not a diagnosis.',
    tableTitle: 'BMI Categories (WHO)',
    columns: ['Category', 'BMI Range'],
    rows: [
      ['Underweight', 'Below 18.5'],
      ['Normal', '18.5 - 24.9'],
      ['Overweight', '25.0 - 29.9'],
      ['Obese', '30.0 and above'],
    ],
  ),
  _InfoTopic(
    icon: Icons.monitor_heart,
    cardTitle: 'Understanding Heart Rate',
    dialogTitle: 'Resting Heart Rate',
    body: 'Resting heart rate is the number of heartbeats per minute while at '
        'rest. Lower rates generally indicate more efficient heart function '
        'and better cardiovascular fitness.',
    tableTitle: 'Typical Ranges (AHA)',
    columns: ['Group', 'Range (bpm)'],
    rows: [
      ['Well-trained athletes', '40 - 60'],
      ['Healthy adults', '60 - 100'],
      ['Above 100 (persistent)', 'Consult a healthcare provider'],
    ],
  ),
  _InfoTopic(
    icon: Icons.bedtime,
    cardTitle: 'Sleep Guidelines',
    dialogTitle: 'Recommended Sleep Hours',
    body: 'Sleep needs change across life stages. These are general guidelines '
        'from the CDC and National Sleep Foundation.',
    tableTitle: 'By Age Group',
    columns: ['Age Group', 'Recommended Hours'],
    rows: [
      ['Newborn (0-3 months)', '14-17 hours'],
      ['Infant (4-11 months)', '12-16 hours'],
      ['Toddler (1-2 years)', '11-14 hours'],
      ['Preschool (3-5 years)', '10-13 hours'],
      ['School age (6-12)', '9-12 hours'],
      ['Teen (13-18)', '8-10 hours'],
      ['Adult (18-64)', '7-9 hours'],
      ['Older adult (65+)', '7-8 hours'],
    ],
  ),
  _InfoTopic(
    icon: Icons.insights,
    cardTitle: 'Understanding Your Health Score',
    dialogTitle: 'How Your Health Score Works',
    body: 'Your Health Score combines nine lifestyle factors into a single '
        '0-100 estimate: Physical Activity, Nutrition, Sleep, Hydration, and '
        'Mindfulness contribute positively, while high Stress, Alcohol use, '
        'Smoking, and BMI far from the healthy midpoint reduce the score. This '
        'is a simplified, educational estimate — not a medical diagnosis. For '
        'personalised guidance, speak with a healthcare provider.',
  ),
];

const List<_ExternalLink> _externalLinks = [
  _ExternalLink(
    icon: Icons.public,
    title: 'WHO Health Topics',
    subtitle: 'World Health Organization resources',
    url: 'https://www.who.int/health-topics',
  ),
  _ExternalLink(
    icon: Icons.medical_services,
    title: 'Health Direct',
    subtitle: 'Australian health information and advice',
    url: 'https://www.healthdirect.gov.au',
  ),
  _ExternalLink(
    icon: Icons.psychology,
    title: 'Beyond Blue',
    subtitle: 'Mental health and wellbeing support (Australia)',
    url: 'https://www.beyondblue.org.au',
  ),
  _ExternalLink(
    icon: Icons.support_agent,
    title: 'Lifeline Australia',
    subtitle: '24/7 crisis support — 13 11 14',
    url: 'https://www.lifeline.org.au',
  ),
];

class HealthResources extends StatefulWidget {
  const HealthResources({super.key, this.controller});

  /// The app scaffold controller used to navigate to in-app tool pages in
  /// Section 3. Optional so the page still renders (with those cards disabled)
  /// if it is ever shown outside the scaffold.
  final SolidScaffoldController? controller;

  @override
  State<HealthResources> createState() => _HealthResourcesState();
}

class _HealthResourcesState extends State<HealthResources> {
  /// The logged-in user's WebID, or null if unknown / logged out.
  String? _webId;

  @override
  void initState() {
    super.initState();
    _loadWebId();
  }

  Future<void> _loadWebId() async {
    try {
      if (!await isUserLoggedIn()) return;
      final webId = await getWebId();
      if (!mounted) return;
      setState(() => _webId = webId);
    } on Exception {
      // Silently ignore: the data section simply omits the WebID line when it
      // cannot be resolved.
    }
  }

  Future<void> _openUrl(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Could not open $url'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on Exception catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to open link: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showInfoDialog(BuildContext context, _InfoTopic topic) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(topic.dialogTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topic.body, style: const TextStyle(height: 1.4)),
                if (topic.tableTitle != null &&
                    topic.columns != null &&
                    topic.rows != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    topic.tableTitle!,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Table(
                    border: TableBorder.all(color: scheme.outlineVariant),
                    defaultVerticalAlignment:
                        TableCellVerticalAlignment.middle,
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                        ),
                        children: [
                          for (final header in topic.columns!)
                            _tableCell(header, bold: true),
                        ],
                      ),
                      for (final row in topic.rows!)
                        TableRow(
                          children: [
                            for (final value in row) _tableCell(value),
                          ],
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static Widget _tableCell(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        // Available width inside the 24px page padding.
        final contentW = constraints.maxWidth - 48;
        final cardW = isWide ? (contentW - 16) / 2 : contentW;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.help_outline, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Support & Resources',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // === SECTION 1: Health Information ===
              _sectionHeading(context, 'Health Information'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final topic in _infoTopics)
                    _ResourceCard(
                      width: cardW,
                      icon: topic.icon,
                      title: topic.cardTitle,
                      onTap: () => _showInfoDialog(context, topic),
                    ),
                ],
              ),
              const SizedBox(height: 32),

              // === SECTION 2: External Resources ===
              _sectionHeading(context, 'External Resources'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final link in _externalLinks)
                    _ResourceCard(
                      width: cardW,
                      icon: link.icon,
                      title: link.title,
                      subtitle: link.subtitle,
                      trailingIcon: Icons.open_in_new,
                      onTap: () => _openUrl(link.url),
                    ),
                ],
              ),
              const SizedBox(height: 32),

              // === SECTION 3: Tools & Calculators ===
              _sectionHeading(context, 'Tools & Calculators'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _ResourceCard(
                    width: cardW,
                    icon: Icons.calculate,
                    title: 'Health Score Calculator',
                    subtitle: 'Get your personalised wellness score',
                    onTap: () => widget.controller
                        ?.navigateToSubpage(const HealthScoreCalculator()),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // === SECTION 4: About Your Data ===
              _sectionHeading(context, 'About Your Data'),
              const SizedBox(height: 12),
              _buildAboutDataCard(context),
              const SizedBox(height: 32),

              // === SECTION 5: Feedback ===
              _sectionHeading(context, 'Feedback'),
              const SizedBox(height: 12),
              _buildFeedbackCard(context),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeading(BuildContext context, String title) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }

  Widget _buildAboutDataCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, color: scheme.onPrimaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your Data, Your Control',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Unlike typical health apps, your information in this app is '
              'stored in your own personal Solid POD — not on our servers. We '
              'never hold a copy of your data.\n\n'
              '🔒 Every note you save is encrypted before it leaves your '
              'device.\n'
              "🔑 You can revoke this app's access to your POD at any time.\n"
              '🌐 Your data stays reachable by any Solid-compatible app you '
              'choose to use, not locked into this one.\n\n'
              'This app is built on the Solid protocol — an open web standard '
              'for decentralised, user-owned data. Learn more at '
              'solidproject.org.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    height: 1.5,
                  ),
            ),
            if (_webId != null) ...[
              const SizedBox(height: 16),
              Text(
                'Signed in as',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                _webId!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _openUrl('https://solidproject.org'),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Visit solidproject.org'),
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.onPrimaryContainer,
                side: BorderSide(
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
              children: [
                Icon(Icons.feedback_outlined, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This is a hackathon prototype',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Built to demonstrate personal health tracking on user-owned '
              'data. Feedback welcome!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tappable card used across the resource sections. Shows a leading [icon], a
/// [title] and optional [subtitle], with an optional [trailingIcon] (e.g.
/// `open_in_new`) to signal an action that leaves the app.
class _ResourceCard extends StatelessWidget {
  const _ResourceCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailingIcon,
  });

  final double width;
  final IconData icon;
  final String title;
  final String? subtitle;
  final IconData? trailingIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: scheme.primary, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    trailingIcon,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
