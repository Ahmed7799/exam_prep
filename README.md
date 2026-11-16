# Exam Prep

Personal Android app for exam preparation. Data is stored on the phone in SQLite.

- **Today:** countdown, hours studied against today's target, warning banner, study timer,
  "What are you studying?" chapter picker, cards due.
- **Plan:** finish-date forecast, hours needed per day, progress per paper (Paper 1 General
  Studies, Paper 2 Core subject), last 7 days.
- **Syllabus:** topic tree with stages; import Claude's breakdown of your syllabus PDF.
- **Cards:** FSRS spaced repetition (intervals stop before the exam), Hard / Medium /
  To review lists, editor with bold and highlight, page numbers, cards from Claude,
  Anki export (text) and CSV with progress, Anki import.
- **Progress:** readiness score, streak and missed days, 12-week calendar, syllabus map,
  weakest topics, and a report to paste into Claude for advice.
- **Warnings:** a daily reality check pops up when you are behind.
- **Backup:** Progress > backup icon. Save everything to one file and restore it later.

## Import your syllabus (Claude app does the reading)

Syllabus tab > sparkle icon (or the button on the empty screen):

1. Tap **Copy prompt for Claude**.
2. Open the Claude app, attach your syllabus PDF and paste the prompt.
3. Copy Claude's whole reply, come back, and tap **Paste from clipboard**, then **Read reply**.
4. Review the topic list, remove anything that does not belong, then **Add topics**.

If the syllabus is long, ask Claude for the next part and import again. Each import adds
to the syllabus. No API key or internet permission is needed.

## Get the APK (no installs on your computer)

1. Create a new private repository on GitHub and upload everything in this folder
   (including the hidden `.github` folder), or push it with git.
2. Open the repository's **Actions** tab. The "Build APK" workflow runs on every push
   to `main`; you can also start it with **Run workflow**.
3. When it finishes, open the run and download the **exam-prep-apk** artifact (a zip
   containing `app-release.apk`).
4. Copy the APK to your phone, allow installing from your file manager when asked,
   and install it.

## Build locally instead

```
flutter create . --platforms=android --org com.ahmed.examprep --project-name exam_prep
rm -f test/widget_test.dart
flutter pub get
flutter test
flutter run
```

## Pasting a syllabus

One topic per line. A line indented deeper than the line above becomes its subtopic:

```
Polity
  Preamble
  Fundamental Rights
    Article 14
Economy
  Inflation
```

List markers such as `1.`, `-` or `(a)` are removed automatically.
