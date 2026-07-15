/// BioPod - the primary application scaffold.
///
/// This file was generated from the `solidui` app template
/// (`dart run solidui:create`). Edit it freely to suit your app.

library;

import 'package:flutter/material.dart';

import 'package:solidui/solidui.dart';

import 'package:newapp/constants/app.dart';
import 'package:newapp/screens/browse_files.dart';
import 'package:newapp/screens/add_note.dart';
import 'package:newapp/screens/add_health_record.dart';
import 'package:newapp/screens/appointments.dart';
import 'package:newapp/screens/dataset_dashboard.dart';
import 'package:newapp/screens/health_dashboard.dart';
import 'package:newapp/screens/health_prediction.dart';
import 'package:newapp/screens/health_score_calculator.dart';
import 'package:newapp/screens/health_timeline.dart';
import 'package:newapp/screens/view_notes.dart';

final _scaffoldController = SolidScaffoldController();

const appScaffold = AppScaffold();

class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return SolidScaffold(
      controller: _scaffoldController,
      hideNavRail: false,
      enableProfile: true,
      onLogout: (context) => SolidAuthHandler.instance.handleLogout(context),

      // The navigation menu drives the side navigation rail (and the drawer on
      // narrow screens). Each entry exposes a top-level page of the app.

      menu: const [
        SolidMenuItem(
          icon: Icons.home,
          title: 'Home',
          tooltip: '''

            **Home**

            Your health dashboard: summary stats, trend graphs and record
            history read from your POD.

            ''',
          child: HealthDashboard(),
        ),
        SolidMenuItem(
          icon: Icons.folder,
          title: 'App Files',
          tooltip: '''

            **Files**

            Tap here to browse the files on your POD for this app.

            ''',
          child: SolidFile(uploadConfig: appUploadConfig),
        ),
        SolidMenuItem(
          icon: Icons.storage,
          title: 'All POD Files',
          tooltip: '''

            **All Files**

            Tap here to browse all folders on your POD from the root.

            ''',
          child: BrowseFiles(),
        ),
        SolidMenuItem(
          icon: Icons.note_add,
          title: 'Add Note',
          tooltip: '''

            **Add Note**

            Tap here to add a titled note to your POD, encrypted.

            ''',
          child: AddNote(),
        ),
        SolidMenuItem(
          icon: Icons.monitor_heart,
          title: 'Add Health Record',
          tooltip: '''

            **Add Health Record**

            Tap here to record health metrics to your POD, encrypted.

            ''',
          child: AddHealthRecord(),
        ),
        SolidMenuItem(
          icon: Icons.timeline,
          title: 'Health Timeline',
          tooltip: '''

            **Health Timeline**

            Tap here to view medications, lab/symptom trends and a medication
            history timeline.

            ''',
          child: HealthTimelineScreen(),
        ),
        SolidMenuItem(
          icon: Icons.calculate,
          title: 'Health Score',
          tooltip: '''

            **Health Score**

            Tap here to calculate a quick 0-100 wellbeing score from your
            recent lifestyle metrics.

            ''',
          child: HealthScoreCalculator(),
        ),
        SolidMenuItem(
          icon: Icons.insights,
          title: 'Risk Prediction',
          tooltip: '''

            **Risk Prediction**

            Tap here to predict a health-risk score from your most recent
            record, grounded against the sample healthcare dataset cohort.

            ''',
          child: HealthPrediction(),
        ),
        SolidMenuItem(
          icon: Icons.bar_chart,
          title: 'Population Insights',
          tooltip: '''

            **Population Insights**

            Tap here to explore the bundled healthcare dataset: patient counts,
            test results, billing and age distributions.

            ''',
          child: DatasetDashboard(),
        ),
        SolidMenuItem(
          icon: Icons.notes,
          title: 'View Notes',
          tooltip: '''

            **View Notes**

            Tap here to read back the notes you have saved to your POD.

            ''',
          child: ViewNotes(),
        ),
        SolidMenuItem(
          icon: Icons.event_available,
          title: 'Appointments',
          tooltip: '''

            **Appointments**

            Tap here to view your upcoming and past medical appointments.

            ''',
          child: AppointmentsScreen(),
        ),
      ],
      appBar: SolidAppBarConfig(
        title: appTitle.split(' - ')[0],
        versionConfig: const SolidVersionConfig(
          changelogUrl: 'https://github.com/example/newapp/blob/dev/'
              'CHANGELOG.md',
          showUpdateButton: true,
          downloadUrl: 'https://solidcommunity.au/installers/',
        ),
        actions: [
          SolidAppBarAction(
            icon: Icons.folder,
            onPressed: () => _scaffoldController.navigateToSubpage(
              const SolidFile(uploadConfig: appUploadConfig),
            ),
            tooltip: 'Files',
          ),
        ],
      ),

      // The status bar runs along the bottom of the window, surfacing the
      // current server, login state and security key status.

      statusBar: const SolidStatusBarConfig(
        serverInfo: SolidServerInfo(serverUri: SolidConfig.defaultServerUrl),
        loginStatus: SolidLoginStatus(),
        securityKeyStatus: SolidSecurityKeyStatus(),
      ),
      aboutConfig: SolidAboutConfig(
        applicationName: appTitle.split(' - ')[0],
        applicationIcon: Image.asset(
          'assets/images/app_icon.png',
          width: 64,
          height: 64,
        ),
        applicationLegalese: '''

        © BioPod

        ''',
        text: '''

        BioPod is a file browser application that allows you to manage
        files on your personal online data store (Pod) hosted on a Solid
        server.

        Key features:

        📂 Browse and manage files on your Solid POD;

        📤 Upload files to your POD;

        📥 Download files from your POD;

        🔐 Security key management for encrypted data;

        🎨 Theme switching (light/dark/system);

        🧭 Responsive navigation (rail ↔ drawer).

        Built with [solidpod](https://pub.dev/packages/solidpod) and
        [solidui](https://pub.dev/packages/solidui) for the
        [Australian Solid Community](https://solidcommunity.au).

        ''',
      ),
      themeToggle: const SolidThemeToggleConfig(
        enabled: true,
        showInAppBarActions: true,
      ),
      inviteConfig: inviteOthersConfig,
      child: const HealthDashboard(),
    );
  }
}
