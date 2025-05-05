import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal, Colors.teal, Colors.teal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: AppBar(
            title: Text(l10n.helpTitle, style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
              Text(
                l10n.helpImHomeTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.helpImHomeContent,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.helpMapTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.helpMapContent,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.helpFollowModeTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.helpFollowModeContent,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.helpNotificationsTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.helpNotificationsContent,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.helpConnectivityTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.helpConnectivityDescription,
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                l10n.helpConnectivityModes,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.helpConnectivityTip,
                style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ],

        ),
      ),
    );
  }
}
