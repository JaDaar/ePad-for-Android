# ePad for Android

A simple quick-notes pad for Android, written in Dart with Flutter.

- **Plain text only.** No formatting. Text is kept to printable ASCII plus tab
  and newline. Smart quotes, dashes and ellipses from the keyboard are turned
  into ASCII, and anything else (emoji, accented letters) is dropped.
- **No limits.** There is no cap on note length or the number of notes.
- **Saved in SQLite.** Each note is one plain-text row in `epad.db`, which sits
  in the app's private storage. Notes save as you type, when the app goes to
  the background, and when you leave the editor. A note you leave empty is
  deleted.
- **Post-it look.** Notes appear as sticky notes in a grid, each slightly
  tilted. The editor is note paper with a monospace font and a line, column
  and character count.
- **Categories and colors.** Every note has a category, and the category sets
  the note's color. New notes are **General** (yellow) unless a category
  filter is selected, in which case they start in that category. The starting
  categories are General (yellow), Development (blue), Recipe (green),
  Personal (pink) and Work (orange).
  - Change a note's category with the label button in the editor's top bar,
    or long-press the note in the grid and choose **Change category**.
  - Create categories from the picker (**New category**: a name and one of 8
    colors). Long-press a category in the picker to delete it; its notes
    move to General. General can't be deleted.
  - The chips under the top bar show one category at a time.
- **Help menu.** The ? button in the top bar has **How to use ePad** (a short
  guide) and **About ePad** (version, copyright Gnomic Software, and the
  open-source licenses of the libraries used). The version shown comes from
  `version:` in `pubspec.yaml`.

## Project layout

| Path | Purpose |
|---|---|
| `lib/main.dart` | App entry and theme (light and dark) |
| `lib/screens/notes_list_screen.dart` | Post-it grid, category filter, search, note actions |
| `lib/screens/editor_screen.dart` | Editor with autosave and category button |
| `lib/widgets/category_picker.dart` | Category picker and New category dialog |
| `lib/data/note_repository.dart` | SQLite storage (`sqflite`) and schema migrations |
| `lib/data/note.dart` | List model and title rule (first non-blank line) |
| `lib/data/note_category.dart` | Category model |
| `lib/theme/post_it.dart` | Post-it colors and editor theme |
| `lib/text/ascii.dart` | ASCII conversion and input filter |
| `test/` | Unit, widget and database tests (the database tests use `sqflite_common_ffi`) |

## Database

`epad.db`, schema version 2. Opening an older database upgrades it
automatically.

- `notes`: `id`, `title` (first non-blank line), `content` (plain ASCII
  text), `created_at`, `modified_at` (milliseconds since epoch),
  `category_id` (defaults to 1, General).
- `categories`: `id`, `name` (unique, ignoring case), `color` (ARGB integer).

## Setup (first time)

1. Install the Flutter SDK: https://docs.flutter.dev/get-started/install/windows/mobile
   You already have the Android SDK, so Flutter only needs to be pointed at it:
   `flutter config --android-sdk "%LOCALAPPDATA%\Android\Sdk"`, then
   `flutter doctor --android-licenses`.
2. In this folder, generate the Android project files. Existing files are left
   alone:
   ```
   flutter create --platforms=android --org com.epad --project-name epad .
   ```
3. Set the launcher name: in `android/app/src/main/AndroidManifest.xml`,
   change `android:label="epad"` to `android:label="ePad"`.
4. Get packages, test, and run:
   ```
   flutter pub get
   flutter test
   flutter run
   ```
5. Build an installable APK: `flutter build apk --release`. The output is
   `build/app/outputs/flutter-apk/app-release.apk`.

## This machine's setup

- Flutter: `D:\DevTools\flutter` (on the user PATH).
- Android SDK: `%LOCALAPPDATA%\Android\Sdk`. JDK: Android Studio's bundled
  runtime, `D:\Program Files\Android\Android Studio\jbr`.
- Emulator: `ePad_Pixel` (Android 36). Start it with
  `flutter emulators --launch ePad_Pixel`.

### Troubleshooting: "PKIX path building failed"

Norton Web/Mail Shield intercepts HTTPS with its own root certificate, which
Java doesn't trust by default. Gradle and `sdkmanager` use a trust store at
`D:\DevTools\java-truststore\cacerts`: the JDK's standard certificates plus
Norton's root. It is set in `%USERPROFILE%\.gradle\gradle.properties` and in
the `SDKMANAGER_OPTS` user environment variable. If Norton ever regenerates
its root, export the new one from the Windows certificate store and re-import
it with `keytool -importcert`.

## License

MIT License. Copyright (c) 2026 Gnomic Software. See [LICENSE](LICENSE).
