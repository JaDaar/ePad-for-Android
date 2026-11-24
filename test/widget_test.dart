import 'package:epad/text/ascii.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('editor text field only accepts ASCII', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextField(
          controller: controller,
          maxLines: null,
          inputFormatters: const [AsciiTextInputFormatter()],
        ),
      ),
    ));

    await tester.enterText(find.byType(TextField), '‘ok’ \u{1F44D}\r\nnext');
    expect(controller.text, "'ok' \nnext");
  });
}
