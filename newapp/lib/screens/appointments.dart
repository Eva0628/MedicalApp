/// Appointments page. Lists the user's medical appointments split into
/// "Current" (upcoming) and "Past" tabs.
///
/// This is a menu-item page rendered inside the app's [SolidScaffold], so it
/// returns a body-only widget (no top-level [AppBar]); the scaffold supplies
/// the app bar. A transparent inner [Scaffold] is used only to host the
/// floating action button and the tab bar.
///
/// The [sampleAppointments] list is placeholder data — swap it for records read
/// back from the POD (see `view_notes.dart` / `health_dashboard.dart` for the
/// read flow) or your own API / local DB.

library;

import 'package:flutter/material.dart';
import 'package:newapp/constants/theme.dart';

/// A single appointment record.
class Appointment {
  final String doctorName;
  final String specialty;
  final DateTime dateTime;
  final String location;
  final String reason;
  final AppointmentStatus status;

  const Appointment({
    required this.doctorName,
    required this.specialty,
    required this.dateTime,
    required this.location,
    required this.reason,
    required this.status,
  });
}

enum AppointmentStatus { upcoming, completed, cancelled, missed }

extension AppointmentStatusX on AppointmentStatus {
  String get label {
    switch (this) {
      case AppointmentStatus.upcoming:
        return 'Upcoming';
      case AppointmentStatus.completed:
        return 'Completed';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
      case AppointmentStatus.missed:
        return 'Missed';
    }
  }

  Color color(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (this) {
      case AppointmentStatus.upcoming:
        return scheme.primary;
      case AppointmentStatus.completed:
        return AppColors.good;
      case AppointmentStatus.cancelled:
        return scheme.error;
      case AppointmentStatus.missed:
        return AppColors.warn;
    }
  }
}

/// Sample data — replace with records from your POD / API / local DB.
final List<Appointment> sampleAppointments = [
  Appointment(
    doctorName: 'Dr. Emily Carter',
    specialty: 'General Practitioner',
    dateTime: DateTime(2026, 7, 22, 10, 30),
    location: 'Biopod Clinic, Room 3',
    reason: 'Annual checkup',
    status: AppointmentStatus.upcoming,
  ),
  Appointment(
    doctorName: 'Dr. Marcus Lee',
    specialty: 'Cardiologist',
    dateTime: DateTime(2026, 8, 3, 14, 0),
    location: 'Heart Health Center',
    reason: 'Follow-up on blood pressure',
    status: AppointmentStatus.upcoming,
  ),
  Appointment(
    doctorName: 'Dr. Emily Carter',
    specialty: 'General Practitioner',
    dateTime: DateTime(2026, 5, 12, 9, 0),
    location: 'Biopod Clinic, Room 3',
    reason: 'Flu symptoms',
    status: AppointmentStatus.completed,
  ),
  Appointment(
    doctorName: 'Dr. Priya Nair',
    specialty: 'Dermatologist',
    dateTime: DateTime(2026, 4, 2, 11, 15),
    location: 'Skin & Wellness Clinic',
    reason: 'Skin rash consultation',
    status: AppointmentStatus.completed,
  ),
  Appointment(
    doctorName: 'Dr. Marcus Lee',
    specialty: 'Cardiologist',
    dateTime: DateTime(2026, 2, 18, 13, 30),
    location: 'Heart Health Center',
    reason: 'Routine ECG',
    status: AppointmentStatus.missed,
  ),
  Appointment(
    doctorName: 'Dr. Sofia Reyes',
    specialty: 'Nutritionist',
    dateTime: DateTime(2026, 1, 9, 16, 0),
    location: 'Biopod Clinic, Room 1',
    reason: 'Diet plan review',
    status: AppointmentStatus.cancelled,
  ),
];

class AppointmentsScreen extends StatelessWidget {
  final List<Appointment> appointments;

  const AppointmentsScreen({super.key, this.appointments = const []});

  @override
  Widget build(BuildContext context) {
    // Fall back to the sample data when no records are supplied. (Using a
    // non-const default above keeps the constructor const-friendly.)
    final data = appointments.isEmpty ? sampleAppointments : appointments;

    final now = DateTime.now();

    final current = data
        .where((a) =>
            a.status == AppointmentStatus.upcoming && a.dateTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final past = data
        .where((a) =>
            a.status != AppointmentStatus.upcoming || a.dateTime.isBefore(now))
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    // A transparent inner Scaffold hosts the FAB and tab bar without drawing
    // its own app bar (the surrounding SolidScaffold provides that).
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            // Hook this up to your "book appointment" flow.
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Book new appointment tapped')),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('New'),
        ),
        body: Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: TabBar(
                tabs: [
                  Tab(text: 'Current (${current.length})'),
                  Tab(text: 'Past (${past.length})'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _AppointmentList(
                    appointments: current,
                    emptyMessage: 'No upcoming appointments',
                  ),
                  _AppointmentList(
                    appointments: past,
                    emptyMessage: 'No past appointments',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentList extends StatelessWidget {
  final List<Appointment> appointments;
  final String emptyMessage;

  const _AppointmentList({
    required this.appointments,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (appointments.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: appointments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) =>
          _AppointmentCard(appointment: appointments[i]),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;

  const _AppointmentCard({required this.appointment});

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $hour:$minute $period';
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(Icons.medical_services_outlined,
                      color: scheme.onPrimaryContainer, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(appointment.doctorName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(appointment.specialty,
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                _StatusBadge(status: appointment.status),
              ],
            ),
            const Divider(height: 24),
            _InfoRow(
                icon: Icons.calendar_today_outlined,
                text: _formatDate(appointment.dateTime)),
            const SizedBox(height: 6),
            _InfoRow(
                icon: Icons.location_on_outlined, text: appointment.location),
            const SizedBox(height: 6),
            _InfoRow(icon: Icons.notes_outlined, text: appointment.reason),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final AppointmentStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status.color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.label,
        style:
            TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: scheme.outline),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}
