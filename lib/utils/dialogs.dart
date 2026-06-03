import 'package:flutter/material.dart';

/// Shows the application-wide features and capabilities dialog.
void showAppFeaturesDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        'App Capabilities & Features',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF18397C),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogItem('Instant Solver', 'Enter a value into any text field, and all other properties will compute automatically.'),
            _buildDialogItem('Preset & Custom Gas Selectors', 'Choose a gas preset or select "Other" to specify a custom heat ratio (gamma).'),
            _buildDialogItem('Reciprocal Toggle', 'Tap the reciprocal toggle button in the header card to invert all ratio fields (e.g., switch between T/T₀ ⇌ T₀/T).'),
            _buildDialogItem('Expression Evaluation', 'Text boxes support basic mathematical expressions (e.g. typing "1.4*2" evaluates automatically).'),
            _buildDialogItem('HandyCalc Utility', 'Tap the compare icon next to any ratio field to open a quick calculator for converting between relative ratios and actual absolute properties.'),
            _buildDialogItem('Subsonic/Supersonic Toggle', 'Use the Subsonic/Supersonic toggle to choose the correct flow branch.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Close',
            style: TextStyle(color: Color(0xFF18397C), fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

/// Shows a topic-specific information dialog with bold item titles.
void showTopicInfoDialog(
  BuildContext context, {
  required String title,
  required List<MapEntry<String, String>> items,
}) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF18397C),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map((e) => _buildDialogItem(e.key, e.value)).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Close',
            style: TextStyle(color: Color(0xFF18397C), fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

Widget _buildDialogItem(String title, String description) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12.0),
    child: RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 12.5,
          height: 1.5,
          color: Color(0xFF4B5563),
          fontFamily: 'Roboto',
        ),
        children: [
          TextSpan(
            text: '• $title:\n',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          TextSpan(text: '  $description'),
        ],
      ),
    ),
  );
}
