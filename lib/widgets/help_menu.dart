import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../screens/help_screen.dart';
import '../theme/post_it.dart';

const String appName = 'ePad for Android';
const String copyright = '© 2026 Gnomic Software';

enum _HelpItem { howTo, about }

/// The Help button in the top bar: "How to use ePad" and "About ePad".
class HelpMenuButton extends StatelessWidget {
  const HelpMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_HelpItem>(
      tooltip: 'Help',
      icon: const Icon(Icons.help_outline),
      onSelected: (item) => switch (item) {
        _HelpItem.howTo => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const HelpScreen()),
          ),
        _HelpItem.about => showEPadAbout(context),
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _HelpItem.howTo,
          child: ListTile(
            leading: Icon(Icons.menu_book_outlined),
            title: Text('How to use ePad'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _HelpItem.about,
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('About ePad'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

/// Shows the About box: name, version (from the installed app), copyright,
/// and a button for the open-source licenses of the libraries ePad uses.
Future<void> showEPadAbout(BuildContext context) async {
  final info = await PackageInfo.fromPlatform();
  if (!context.mounted) return;
  showAboutDialog(
    context: context,
    applicationName: appName,
    applicationVersion: 'Version ${info.version} (build ${info.buildNumber})',
    applicationLegalese: copyright,
    applicationIcon: Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: PostIt.yellow,
        border: Border(
          top: BorderSide(color: PostIt.strip(PostIt.yellow), width: 8),
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(1, 2)),
        ],
      ),
      child: const Icon(Icons.edit_note, color: PostIt.ink),
    ),
    children: const [
      SizedBox(height: 16),
      Text('A simple quick-notes pad. Plain text, no formatting, '
          'saved on your device.'),
    ],
  );
}
