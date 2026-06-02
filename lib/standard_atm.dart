import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// entry point
void main() {
  runApp(const AtmosphereApp());
}
// our app
class AtmosphereApp extends StatelessWidget {
  const AtmosphereApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Standard Atmosphere',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D1F3C)),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const StandardAtmosphereScreen(),
    );
  }
}

//  Colour tokens —  Blue theme
class _C {
  static const headerBg = Color.fromARGB(255, 24, 62, 124);
  static const pageBg = Color(0xFFF4F5F7);
  static const cardBg = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFD1D5DB);
  static const sectionDiv = Color(0xFFE5E7EB);
  static const rowDivider = Color(0xFFF3F4F6);
  static const labelSmall = Color(0xFF9CA3AF);
  static const labelMedium = Color(0xFF6B7280);
  static const textPrimary = Color(0xFF111827);
  // Input field
  static const fieldBorder = Color(0xFFD1D5DB); // idle border
  static const fieldBorderFocus = Color.fromARGB(
    255,
    24,
    62,
    124,
  ); // focused border
  static const fieldBg = Color(0xFFFFFFFF);
  static const fieldHint = Color(0xFFB0B7C3);
  static const fieldLabel = Color(0xFF374151); // label above field
  static const fieldSubHint = Color(0xFF9CA3AF); // "0 to 86,000 m"
  // Unit divider inside field
  static const unitDivider = Color(0xFFE5E7EB);
  static const unitText = Color(0xFF374151);
  static const unitArrow = Color(0xFF6B7280);
  // Section header
  static const sectionIcon = Color.fromARGB(255, 24, 62, 124);
  static const sectionLabel = Color.fromARGB(255, 24, 62, 124);
  // Outputs
  static const outputLabel = Color(0xFF374151);
  static const outputValue = Color(0xFF0D1F3C);
  static const outputDash = Color(0xFF9CA3AF);
  static const outputUnit = Color(0xFF6B7280);
  // Note card
  static const noteCardBg = Color(0xFFEEF2F8);
  static const noteCardBorder = Color(0xFFC7D4E6);
  static const noteIcon = Color(0xFF0D1F3C);
  static const noteText = Color(0xFF4B6082);
  static const descText = Color(0xFF6B7280);
}


//  Unit definitions

enum AltitudeUnit { m, ft, km }

enum PressureUnit { pa, hpa, atm, psi }

enum DensityUnit { kgm3, slugft3 }

// unit display names

extension AltitudeUnitExt on AltitudeUnit {
  String get label => const ['m', 'ft', 'km'][index];
}

extension PressureUnitExt on PressureUnit {
  String get label => const ['Pa', 'hPa', 'atm', 'psi'][index];
}

extension DensityUnitExt on DensityUnit {
  String get label => const ['kg/m³', 'slug/ft³'][index];
}

//  Screen

class StandardAtmosphereScreen extends StatefulWidget {
  const StandardAtmosphereScreen({super.key});

  @override
  State<StandardAtmosphereScreen> createState() =>
      _StandardAtmosphereScreenState();
}

class _StandardAtmosphereScreenState extends State<StandardAtmosphereScreen> {
  //  Controllers 
  final _altCtrl = TextEditingController();
  final _presCtrl = TextEditingController();
  final _densCtrl = TextEditingController();

  //  Selected units 
  AltitudeUnit _altUnit = AltitudeUnit.m;
  PressureUnit _presUnit = PressureUnit.pa;
  DensityUnit _densUnit = DensityUnit.kgm3;

  //  Output display values (we will connect  model here) 
  // will Replace these with real computed values from our atmosphere model.
  String _temperature = '—';
  String _speedOfSound = '—';
  String _viscosity = '—';

  @override
  void dispose() {
    _altCtrl.dispose();
    _presCtrl.dispose();
    _densCtrl.dispose();
    super.dispose();
  }

  //  setstate called whenever any input changes 
  // connect to our atmosphere model to populate the output fields.
  void _onInputChanged() {
    // update the output values based on the current inputs and selected units
    // _temperature, _speedOfSound, _viscosity via setState().
  }

  //  BUILD

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.pageBg,
      body: Column(
        children: [
          _buildAppBar(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDescription(),
                  const SizedBox(height: 14),
                  _buildInputCard(),
                  const SizedBox(height: 12),
                  _buildOutputCard(),
                  const SizedBox(height: 12),
                  _buildNoteCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  //  App Bar 
  Widget _buildAppBar(BuildContext context) {
    return Container(
      color: _C.headerBg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 13),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu, color: Colors.white, size: 22),
                onPressed: () {},
              ),
              const Expanded(
                child: Text(
                  'Standard Atmosphere',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: () => _showInfoDialog(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //  Description 
  Widget _buildDescription() {
    return const Text(
      'Calculate atmospheric properties of the standard atmosphere'
      ' at a given altitude, pressure or density.',
      style: TextStyle(fontSize: 12, color: _C.descText, height: 1.55),
    );
  }

  //  Input Card 
  Widget _buildInputCard() {
    return _Card(
      header: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: _C.headerBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.swap_vert, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 10),
          const Text(
            'INPUT',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _C.sectionLabel,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      children: [
        //  Altitude 
        _InputRow(
          label: 'Altitude',
          controller: _altCtrl,
          unitLabel: _altUnit.label,
          onUnitTap: _showAltUnitPicker,
          hintText: 'Enter altitude',
          subHint: '0 to 86,000 m',
          onChanged: (_) => _onInputChanged(),
        ),
        //  Pressure 
        _InputRow(
          label: 'Pressure',
          controller: _presCtrl,
          unitLabel: _presUnit.label,
          onUnitTap: _showPresUnitPicker,
          hintText: 'Enter pressure',
          onChanged: (_) => _onInputChanged(),
        ),
        //  Density 
        _InputRow(
          label: 'Density',
          controller: _densCtrl,
          unitLabel: _densUnit.label,
          onUnitTap: _showDensUnitPicker,
          hintText: 'Enter density',
          onChanged: (_) => _onInputChanged(),
          isLast: true,
        ),
      ],
    );
  }

  //  Output Card 
  Widget _buildOutputCard() {
    return _Card(
      header: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: _C.headerBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bar_chart, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 10),
          const Text(
            'OUTPUT',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _C.sectionLabel,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      children: [
        _OutputRow(
          label: 'Temperature, ',
          symbol: 'T',
          value: _temperature,
          unit: 'K',
        ),
        _OutputRow(
          label: 'Speed of Sound, ',
          symbol: 'a',
          value: _speedOfSound,
          unit: 'm/s',
        ),
        _OutputRow(
          label: 'Viscosity, ',
          symbol: 'μ',
          value: _viscosity,
          unit: 'Pa·s',
          isLast: true,
        ),
      ],
    );
  }

  //  Note Card 
  Widget _buildNoteCard() {
    return Container(
      decoration: BoxDecoration(
        color: _C.noteCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.noteCardBorder, width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: _C.noteIcon),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Based on the U.S. Standard Atmosphere 1976\nup to 86 km geometric altitude.',
              style: TextStyle(
                fontSize: 11.5,
                color: _C.noteText,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  //  Unit pickers 
  void _showAltUnitPicker() {
    _showUnitSheet<AltitudeUnit>(
      title: 'Unit',
      values: AltitudeUnit.values,
      labelOf: (u) => u.label,
      current: _altUnit,
      onSelect: (u) => setState(() {
        _altUnit = u;
        _onInputChanged();
      }),
    );
  }

  void _showPresUnitPicker() {
    _showUnitSheet<PressureUnit>(
      title: 'Unit',
      values: PressureUnit.values,
      labelOf: (u) => u.label,
      current: _presUnit,
      onSelect: (u) => setState(() {
        _presUnit = u;
        _onInputChanged();
      }),
    );
  }

  void _showDensUnitPicker() {
    _showUnitSheet<DensityUnit>(
      title: 'Unit',
      values: DensityUnit.values,
      labelOf: (u) => u.label,
      current: _densUnit,
      onSelect: (u) => setState(() {
        _densUnit = u;
        _onInputChanged();
      }),
    );
  }

  void _showUnitSheet<T>({
    required String title,
    required List<T> values,
    required String Function(T) labelOf,
    required T current,
    required void Function(T) onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _C.pageBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _C.headerBg,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: values.map((v) {
                  final isSelected = v == current;
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onSelect(v);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _C.cardBg,
                        border: Border.all(
                          color: isSelected ? _C.headerBg : _C.cardBorder,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            labelOf(v),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected ? _C.headerBg : _C.textPrimary,
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle,
                              size: 18,
                              color: _C.headerBg,
                            )
                          else
                            const Icon(
                              Icons.radio_button_unchecked,
                              size: 18,
                              color: _C.cardBorder,
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  //  Info dialog 
  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _C.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        
        content: const Text(
          'U.S. Standard Atmosphere 1976\n\n'
          'Provides temperature, pressure, density, speed of sound, and '
          'dynamic viscosity from sea level up to 86 km geometric altitude.\n\n'
          'Enter any one of: Altitude, Pressure, or Density to instantly '
          'compute the remaining atmospheric state.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.55,
            color: Color(0xFF4B5563),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: _C.headerBg, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Reusable Card
// ─────────────────────────────────────────────
class _Card extends StatelessWidget {
  const _Card({required this.header, required this.children});

  final Widget header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: header,
          ),
          const Divider(height: 0, thickness: 0.5, color: _C.sectionDiv),
          ...children,
        ],
      ),
    );
  }
}

//  Input Row
//  Layout: label → bordered field (text + divider + unit▾) → optional subHint
class _InputRow extends StatefulWidget {
  const _InputRow({
    required this.label,
    required this.controller,
    required this.unitLabel,
    required this.onUnitTap,
    required this.hintText,
    this.subHint,
    this.onChanged,
    this.isLast = false,
  });

  final String label;
  final TextEditingController controller;
  final String unitLabel;
  final VoidCallback onUnitTap;
  final String hintText;
  final String? subHint; // e.g. "0 to 86,000 m" shown below field
  final ValueChanged<String>? onChanged;
  final bool isLast;

  @override
  State<_InputRow> createState() => _InputRowState();
}

class _InputRowState extends State<_InputRow> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _focused ? _C.fieldBorderFocus : _C.fieldBorder;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, widget.isLast ? 16 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //  Field label 
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _C.fieldLabel,
            ),
          ),
          const SizedBox(height: 7),

          //  Bordered field 
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: _C.fieldBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              children: [
                // Text input
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    onChanged: widget.onChanged,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[-0-9. ]')),
                    ],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: _C.textPrimary,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 13,
                      ),
                      border: InputBorder.none,
                      hintText: widget.hintText,
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: _C.fieldHint,
                      ),
                    ),
                  ),
                ),

                // Vertical divider
                Container(width: 1, height: 26, color: _C.unitDivider),

                // Unit button
                GestureDetector(
                  onTap: widget.onUnitTap,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.unitLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _C.unitText,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          size: 16,
                          color: _C.unitArrow,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          //  Optional sub-hint (e.g. range text) 
          if (widget.subHint != null) ...[
            const SizedBox(height: 5),
            Text(
              widget.subHint!,
              style: const TextStyle(fontSize: 11, color: _C.fieldSubHint),
            ),
          ],

          //  Row divider (between inputs, not after last) 
          if (!widget.isLast) ...[
            const SizedBox(height: 14),
            const Divider(height: 0, thickness: 0.5, color: _C.rowDivider),
          ],
        ],
      ),
    );
  }
}

//  Output Row
//  Label with italic symbol + dash placeholder + unit

class _OutputRow extends StatelessWidget {
  const _OutputRow({
    required this.label,
    required this.symbol,
    required this.value,
    required this.unit,
    this.isLast = false,
  });

  final String label;
  final String symbol; // e.g. 'T', 'a', 'μ'
  final String value;
  final String unit;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isDash = value == '—';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Label + italic symbol
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: _C.outputLabel,
                      fontFamily: 'Roboto',
                    ),
                    children: [
                      TextSpan(text: label),
                      TextSpan(
                        text: symbol,
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                          color: _C.outputLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Value
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isDash ? FontWeight.w400 : FontWeight.w500,
                  color: isDash ? _C.outputDash : _C.outputValue,
                ),
              ),
              const SizedBox(width: 10),
              // Unit
              SizedBox(
                width: 40,
                child: Text(
                  unit,
                  style: const TextStyle(fontSize: 12, color: _C.outputUnit),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(
            height: 0,
            thickness: 0.5,
            color: _C.rowDivider,
            indent: 16,
            endIndent: 16,
          ),
      ],
    );
  }
}
