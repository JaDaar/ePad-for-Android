import 'package:material_ui/material_ui.dart';

import 'screens/notes_list_screen.dart';

void main() => runApp(const EPadApp());

class EPadApp extends StatelessWidget {
  const EPadApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Colors.blueGrey;
    return MaterialApp(
      title: 'ePad',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark),
      home: const NotesListScreen(),
    );
  }
}
