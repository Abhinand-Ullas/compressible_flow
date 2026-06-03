import 'package:flutter/material.dart';
import 'package:cftk/utils/responsive.dart';

/// Shows the application-wide features and capabilities dialog.
void showAppFeaturesDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Responsive.wp(context, 12)),
      ),
      title: Text(
        'App Capabilities & Features',
        style: TextStyle(
          fontSize: Responsive.sp(context, 15),
          fontWeight: FontWeight.w600,
          color: const Color(0xFF18397C),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogItem(context, 'Instant Solver', 'Enter a value into any text field, and all other properties will compute automatically.'),
            _buildDialogItem(context, 'Preset & Custom Gas Selectors', 'Choose a gas preset or select "Other" to specify a custom heat ratio (gamma).'),
            _buildDialogItem(context, 'Reciprocal Toggle', 'Tap the reciprocal toggle button in the header card to invert all ratio fields (e.g., switch between T/T₀ ⇌ T₀/T).'),
            _buildDialogItem(context, 'Expression Evaluation', 'Text boxes support basic mathematical expressions (e.g. typing "1.4*2" evaluates automatically).'),
            _buildDialogItem(context, 'HandyCalc Utility', 'Tap the compare icon next to any ratio field to open a quick calculator for converting between relative ratios and actual absolute properties.'),
            _buildDialogItem(context, 'Subsonic/Supersonic Toggle', 'Use the Subsonic/Supersonic toggle to choose the correct flow branch.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Close',
            style: TextStyle(
              color: const Color(0xFF18397C),
              fontSize: Responsive.sp(context, 13),
            ),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Responsive.wp(context, 12)),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: Responsive.sp(context, 15),
          fontWeight: FontWeight.w600,
          color: const Color(0xFF18397C),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map((e) => _buildDialogItem(context, e.key, e.value)).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Close',
            style: TextStyle(
              color: const Color(0xFF18397C),
              fontSize: Responsive.sp(context, 13),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildDialogItem(BuildContext context, String title, String description) {
  return Padding(
    padding: EdgeInsets.only(bottom: Responsive.hp(context, 12)),
    child: RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: Responsive.sp(context, 12.5),
          height: 1.5,
          color: const Color(0xFF4B5563),
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
