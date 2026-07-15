import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/dialogs.dart';
import '../utils/responsive.dart';

// ─────────────────────────────────────────────
//  Colour tokens  (identical palette to Isentropic Flow page)
// ─────────────────────────────────────────────
class _C {
  static const headerBg = Color(0xFF18397C);
  static const pageBg = Color(0xFFF4F5F7);
  static const cardBg = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFD1D5DB);
  static const sectionDiv = Color(0xFFE5E7EB);
  static const rowDivider = Color(0xFFF3F4F6);
  static const labelSmall = Color(0xFF9CA3AF);
  static const labelMedium = Color(0xFF6B7280);
  static const textPrimary = Color(0xFF111827);
  static const fieldBorder = Color(0xFFD1D5DB);
  static const fieldBorderFocus = Color(0xFF18397C);
  static const fieldBg = Color(0xFFFFFFFF);
  static const fieldHint = Color(0xFFB0B7C3);
  static const fieldLabel = Color(0xFF374151);
  static const sectionLabel = Color(0xFF18397C);
  static const outputValue = Color(0xFF0D1F3C);
  static const errorText = Color(0xFFDC2626);
  static const inputActiveBg = Color(0xFFF0F4FF);
  static const computedBg = Color(0xFFFAFAFA);
}

// ─────────────────────────────────────────────
//  Which field the user is currently typing in
// ─────────────────────────────────────────────
enum _ActiveField { none, altitude, pressure, density }

// ─────────────────────────────────────────────
//  Simple arithmetic expression evaluator (same as Isentropic page)
//  Supports: + - * / ^ and parentheses
// ─────────────────────────────────────────────
double? _evalExpr(String input) {
  if (input.contains(RegExp(r'\s'))) return null;
  final s = input.trim();
  if (s.isEmpty) return null;
  try {
    final result = _ExprParser(s).parse();
    return result.isNaN || result.isInfinite ? null : result;
  } catch (_) {
    return null;
  }
}

class _ExprParser {
  _ExprParser(this._s);
  final String _s;
  int _pos = 0;

  double parse() {
    final val = _parseAddSub();
    if (_pos != _s.length) throw FormatException('unexpected char');
    return val;
  }

  double _parseAddSub() {
    double val = _parseMulDiv();
    while (_pos < _s.length) {
      if (_s[_pos] == '+') { _pos++; val += _parseMulDiv(); }
      else if (_s[_pos] == '-') { _pos++; val -= _parseMulDiv(); }
      else break;
    }
    return val;
  }

  double _parseMulDiv() {
    double val = _parsePow();
    while (_pos < _s.length) {
      if (_s[_pos] == '*') { _pos++; val *= _parsePow(); }
      else if (_s[_pos] == '/') { _pos++; val /= _parsePow(); }
      else break;
    }
    return val;
  }

  double _parsePow() {
    double base = _parseUnary();
    if (_pos < _s.length && _s[_pos] == '^') {
      _pos++;
      final exp = _parseUnary();
      return pow(base, exp).toDouble();
    }
    return base;
  }

  double _parseUnary() {
    if (_pos < _s.length && _s[_pos] == '-') { _pos++; return -_parsePrimary(); }
    if (_pos < _s.length && _s[_pos] == '+') { _pos++; return _parsePrimary(); }
    return _parsePrimary();
  }

  double _parsePrimary() {
    if (_pos < _s.length && _s[_pos] == '(') {
      _pos++;
      final val = _parseAddSub();
      if (_pos >= _s.length || _s[_pos] != ')') throw FormatException('missing )');
      _pos++;
      return val;
    }
    return _parseNumber();
  }

  double _parseNumber() {
    final start = _pos;
    while (_pos < _s.length && (RegExp(r'[0-9.]').hasMatch(_s[_pos]))) _pos++;
    if (_pos == start) throw FormatException('expected number at pos $_pos');
    return double.parse(_s.substring(start, _pos));
  }
}

// ─────────────────────────────────────────────
//  US Standard Atmosphere 1976 — layer table
//  (geopotential altitude, 0 → 84852 m)
// ─────────────────────────────────────────────
class _AtmLayer {
  final double hBase; // m
  final double hTop; // m
  final double tBase; // K
  final double pBase; // Pa
  final double lapse; // K/m  (0 = isothermal layer)
  const _AtmLayer({
    required this.hBase,
    required this.hTop,
    required this.tBase,
    required this.pBase,
    required this.lapse,
  });
}

class AtmosphereResult {
  final double h; // geopotential altitude, m
  final double p; // Pa
  final double rho; // kg/m3
  final double t; // K
  final double a; // speed of sound, m/s
  final double mu; // dynamic viscosity, Pa·s
  const AtmosphereResult({
    required this.h,
    required this.p,
    required this.rho,
    required this.t,
    required this.a,
    required this.mu,
  });
}

class AtmosphereEngine {
  static const g0 = 9.80665; // m/s2
  static const R = 287.0528; // J/(kg·K)
  static const gamma = 1.4;
  static const mu0 = 1.716e-5; // Pa·s, Sutherland reference
  static const tSuth = 273.15; // K
  static const sSuth = 110.4; // K

  static const double hMin = 0.0;
  static const double hMax = 84852.0;

  static final List<_AtmLayer> layers = _buildLayers();
  static final double pMin = layers.last.pBase == 0 ? 0 : _pressureAtTop(layers.last);
  static final double pMax = layers.first.pBase;
  static final double rhoMin = _densityAtTop(layers.last);
  static final double rhoMax = layers.first.pBase / (R * layers.first.tBase);

  // Base (hBase, TBase, lapse) definitions taken directly from the 1976
  // Standard Atmosphere. Base pressures are then generated recursively so
  // there is a single source of truth for the whole table.
  static List<_AtmLayer> _buildLayers() {
    const defs = [
      [0.0, 288.15, -0.0065],
      [11000.0, 216.65, 0.0],
      [20000.0, 216.65, 0.001],
      [32000.0, 228.65, 0.0028],
      [47000.0, 270.65, 0.0],
      [51000.0, 270.65, -0.0028],
      [71000.0, 214.65, -0.002],
      [84852.0, 186.946, 0.0], // top marker only — closes final layer
    ];

    final list = <_AtmLayer>[];
    double p = 101325.0;
    for (int i = 0; i < defs.length - 1; i++) {
      final hBase = defs[i][0];
      final tBase = defs[i][1];
      final lapse = defs[i][2];
      final hTop = defs[i + 1][0];
      list.add(_AtmLayer(hBase: hBase, hTop: hTop, tBase: tBase, pBase: p, lapse: lapse));

      final tTop = lapse != 0 ? tBase + lapse * (hTop - hBase) : tBase;
      p = lapse != 0
          ? p * pow(tTop / tBase, -g0 / (lapse * R)).toDouble()
          : p * exp(-g0 * (hTop - hBase) / (R * tBase));
    }
    return list;
  }

  static double _pressureAtTop(_AtmLayer l) {
    if (l.lapse != 0) {
      final tTop = l.tBase + l.lapse * (l.hTop - l.hBase);
      return l.pBase * pow(tTop / l.tBase, -g0 / (l.lapse * R)).toDouble();
    }
    return l.pBase * exp(-g0 * (l.hTop - l.hBase) / (R * l.tBase));
  }

  static double _densityAtTop(_AtmLayer l) {
    final pTop = _pressureAtTop(l);
    final tTop = l.lapse != 0 ? l.tBase + l.lapse * (l.hTop - l.hBase) : l.tBase;
    return pTop / (R * tTop);
  }
// this function might have to be changed
  static _AtmLayer _layerForAltitude(double h) { 
    for (final l in layers) {
      if (h <= l.hTop) return l;
    }
    return layers.last;
  }

  // Pressure decreases monotonically with altitude — walk the table until
  // the requested pressure sits at or above a layer's top-of-layer pressure.
  static _AtmLayer _layerForPressure(double p) {
    for (final l in layers) {
      if (p >= _pressureAtTop(l)) return l;
    }
    return layers.last;
  }

  static _AtmLayer _layerForDensity(double rho) {
    for (final l in layers) {
      if (rho >= _densityAtTop(l)) return l;
    }
    return layers.last;
  }

  static AtmosphereResult _finish({required double h, required double p, required double rho, required double t}) {
    final a = sqrt(gamma * R * t);
    final mu = mu0 * pow(t / tSuth, 1.5).toDouble() * (tSuth + sSuth) / (t + sSuth);
    return AtmosphereResult(h: h, p: p, rho: rho, t: t, a: a, mu: mu);
  }

  /// Direct method — geopotential altitude is a native input to the 1976 model.
  static AtmosphereResult fromAltitude(double h) {
    final l = _layerForAltitude(h);
    double t, p;
    if (l.lapse != 0) {
      t = l.tBase + l.lapse * (h - l.hBase);
      p = l.pBase * pow(t / l.tBase, -g0 / (l.lapse * R)).toDouble();
    } else {
      t = l.tBase;
      p = l.pBase * exp(-g0 * (h - l.hBase) / (R * l.tBase));
    }
    return _finish(h: h, p: p, rho: p / (R * t), t: t);
  }

  /// Inverse method — locate the layer by pressure, then invert the
  /// pressure-altitude relation for that layer analytically (closed form,
  /// no iteration needed since P(h) is monotonic within a layer).
  static AtmosphereResult fromPressure(double p) {
    final l = _layerForPressure(p);
    double t, h;
    if (l.lapse != 0) {
      t = l.tBase * pow(p / l.pBase, -(l.lapse * R) / g0).toDouble();
      h = l.hBase + (t - l.tBase) / l.lapse;
    } else {
      t = l.tBase;
      h = l.hBase - (R * l.tBase / g0) * log(p / l.pBase);
    }
    return _finish(h: h, p: p, rho: p / (R * t), t: t);
  }

  /// Inverse method — same idea as [fromPressure] but inverting the
  /// density-altitude relation for the layer.
  static AtmosphereResult fromDensity(double rho) {
    final l = _layerForDensity(rho);
    final rhoBase = l.pBase / (R * l.tBase);
    double t, h;
    if (l.lapse != 0) {
      final expo = -(l.lapse * R) / (g0 + l.lapse * R);
      t = l.tBase * pow(rho / rhoBase, expo).toDouble();
      h = l.hBase + (t - l.tBase) / l.lapse;
    } else {
      t = l.tBase;
      h = l.hBase - (R * l.tBase / g0) * log(rho / rhoBase);
    }
    final p = rho * R * t;
    return _finish(h: h, p: p, rho: rho, t: t);
  }
}

// ─────────────────────────────────────────────
//  Main Screen Widget
// ─────────────────────────────────────────────
class StandardAtmosphereScreen extends StatefulWidget {
  final VoidCallback? onDrawer;
  const StandardAtmosphereScreen({super.key, this.onDrawer});

  @override
  State<StandardAtmosphereScreen> createState() => _StandardAtmosphereScreenState();
}

class _StandardAtmosphereScreenState extends State<StandardAtmosphereScreen> {
  final _altCtrl = TextEditingController();
  final _pCtrl = TextEditingController();
  final _rhoCtrl = TextEditingController();

  final _altFocus = FocusNode();
  final _pFocus = FocusNode();
  final _rhoFocus = FocusNode();

  final _tCtrl = TextEditingController();
  final _aCtrl = TextEditingController();
  final _muCtrl = TextEditingController();

  _ActiveField _activeField = _ActiveField.none;
  AtmosphereResult? _result;

  final Map<_ActiveField, String?> _fieldErrors = {};

  bool _updating = false;

  @override
  void initState() {
    super.initState();
    void onFocusChange(_ActiveField field, FocusNode node) {
      node.addListener(() {
        if (node.hasFocus && _activeField != field) {
          setState(() => _activeField = field);
        }
      });
    }

    onFocusChange(_ActiveField.altitude, _altFocus);
    onFocusChange(_ActiveField.pressure, _pFocus);
    onFocusChange(_ActiveField.density, _rhoFocus);
  }

  @override
  void dispose() {
    for (final c in [_altCtrl, _pCtrl, _rhoCtrl, _tCtrl, _aCtrl, _muCtrl]) {
      c.dispose();
    }
    for (final f in [_altFocus, _pFocus, _rhoFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  // ─────────────────────────────────────────────
  //  Field change handlers
  // ─────────────────────────────────────────────
  void _clearOtherErrors(_ActiveField keep) {
    for (final f in _ActiveField.values) {
      if (f != keep) _fieldErrors[f] = null;
    }
  }

  void _clearComputedFields(_ActiveField except) {
    _updating = true;
    if (except != _ActiveField.altitude) _altCtrl.clear();
    if (except != _ActiveField.pressure) _pCtrl.clear();
    if (except != _ActiveField.density) _rhoCtrl.clear();
    _tCtrl.clear();
    _aCtrl.clear();
    _muCtrl.clear();
    _updating = false;
  }

  void _writeComputedFields(_ActiveField source, AtmosphereResult r) {
    _updating = true;
    if (source != _ActiveField.altitude) _altCtrl.text = _fmt(r.h);
    if (source != _ActiveField.pressure) _pCtrl.text = _fmt(r.p);
    if (source != _ActiveField.density) _rhoCtrl.text = _fmt(r.rho);
    _tCtrl.text = _fmt(r.t);
    _aCtrl.text = _fmt(r.a);
    _muCtrl.text = _fmtMu(r.mu);
    _updating = false;
  }

  void _onAltitudeChanged(String raw) {
    if (_updating) return;
    _activeField = _ActiveField.altitude;
    _clearOtherErrors(_ActiveField.altitude);

    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _fieldErrors[_ActiveField.altitude] = null;
        _result = null;
      });
      _clearComputedFields(_ActiveField.altitude);
      return;
    }

    final val = _evalExpr(trimmed);
    if (val == null) {
      setState(() {
        _fieldErrors[_ActiveField.altitude] = 'Invalid expression';
        _result = null;
      });
      _clearComputedFields(_ActiveField.altitude);
      return;
    }

    if (val < AtmosphereEngine.hMin || val > AtmosphereEngine.hMax) {
      setState(() {
        _fieldErrors[_ActiveField.altitude] = 'Must be between 0 and 84852 m';
        _result = null;
      });
      _clearComputedFields(_ActiveField.altitude);
      return;
    }

    setState(() => _fieldErrors[_ActiveField.altitude] = null);
    final r = AtmosphereEngine.fromAltitude(val);
    setState(() => _result = r);
    _writeComputedFields(_ActiveField.altitude, r);
  }

  void _onPressureChanged(String raw) {
    if (_updating) return;
    _activeField = _ActiveField.pressure;
    _clearOtherErrors(_ActiveField.pressure);

    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _fieldErrors[_ActiveField.pressure] = null;
        _result = null;
      });
      _clearComputedFields(_ActiveField.pressure);
      return;
    }

    final val = _evalExpr(trimmed);
    if (val == null) {
      setState(() {
        _fieldErrors[_ActiveField.pressure] = 'Invalid expression';
        _result = null;
      });
      _clearComputedFields(_ActiveField.pressure);
      return;
    }

    if (val <= AtmosphereEngine.pMin || val > AtmosphereEngine.pMax) {
      setState(() {
        _fieldErrors[_ActiveField.pressure] = 'Must be between ${_fmt(AtmosphereEngine.pMin)} and ${_fmt(AtmosphereEngine.pMax)} Pa';
        _result = null;
      });
      _clearComputedFields(_ActiveField.pressure);
      return;
    }

    setState(() => _fieldErrors[_ActiveField.pressure] = null);
    final r = AtmosphereEngine.fromPressure(val);
    setState(() => _result = r);
    _writeComputedFields(_ActiveField.pressure, r);
  }

  void _onDensityChanged(String raw) {
    if (_updating) return;
    _activeField = _ActiveField.density;
    _clearOtherErrors(_ActiveField.density);

    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _fieldErrors[_ActiveField.density] = null;
        _result = null;
      });
      _clearComputedFields(_ActiveField.density);
      return;
    }

    final val = _evalExpr(trimmed);
    if (val == null) {
      setState(() {
        _fieldErrors[_ActiveField.density] = 'Invalid expression';
        _result = null;
      });
      _clearComputedFields(_ActiveField.density);
      return;
    }

    if (val <= AtmosphereEngine.rhoMin || val > AtmosphereEngine.rhoMax) {
      setState(() {
        _fieldErrors[_ActiveField.density] = 'Must be between ${_fmt(AtmosphereEngine.rhoMin)} and ${_fmt(AtmosphereEngine.rhoMax)} kg/m³';
        _result = null;
      });
      _clearComputedFields(_ActiveField.density);
      return;
    }

    setState(() => _fieldErrors[_ActiveField.density] = null);
    final r = AtmosphereEngine.fromDensity(val);
    setState(() => _result = r);
    _writeComputedFields(_ActiveField.density, r);
  }

  // ─────────────────────────────────────────────
  //  Formatting
  // ─────────────────────────────────────────────
  String _fmt(double v) {
    if (v.abs() >= 1e6 || (v.abs() < 1e-4 && v != 0)) {
      return v.toStringAsExponential(5);
    }
    // Up to 6 significant decimal digits, strip trailing zeros
    String s = v.toStringAsFixed(6);
    // Remove trailing zeros after decimal
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      if (s.endsWith('.')) s = s + '0';
    }
    return s;
  }

  String _fmtMu(double v) => '${v.toStringAsExponential(4)}';

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          _buildAppBar(context),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                Responsive.pad(context, 12),
                Responsive.pad(context, 6),
                Responsive.pad(context, 12),
                Responsive.pad(context, 12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInputsCard(context),
                  SizedBox(height: Responsive.hp(context, 6)),
                  _buildOutputsCard(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      color: _C.headerBg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Responsive.pad(context, 4),
            Responsive.pad(context, 4),
            Responsive.pad(context, 4),
            Responsive.pad(context, 13),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.menu, color: Colors.white, size: Responsive.sp(context, 22)),
                onPressed: widget.onDrawer ?? () {},
              ),
              Expanded(
                child: Text(
                  'Standard Atmosphere',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: Responsive.sp(context, 15),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.info_outline, color: Colors.white, size: Responsive.sp(context, 22)),
                onPressed: () => _showInfoDialog(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Inputs card ───────────────────────────────────────────────────────────
  Widget _buildInputsCard(BuildContext context) {
    return _Card(
      context: context,
      header: _cardHeader(context, Icons.height, 'ATMOSPHERIC STATE'),
      children: [
        _atmField(
          context: context,
          field: _ActiveField.altitude,
          label: 'Geopotential Altitude',
          symbol: 'h  (m)',
          controller: _altCtrl,
          focusNode: _altFocus,
          hintText: '0 to 84852',
          onChanged: _onAltitudeChanged,
          error: _fieldErrors[_ActiveField.altitude],
        ),
        _divider(),
        _atmField(
          context: context,
          field: _ActiveField.pressure,
          label: 'Pressure',
          symbol: 'P  (Pa)',
          controller: _pCtrl,
          focusNode: _pFocus,
          hintText: 'Static pressure in pascals',
          onChanged: _onPressureChanged,
          error: _fieldErrors[_ActiveField.pressure],
        ),
        _divider(),
        _atmField(
          context: context,
          field: _ActiveField.density,
          label: 'Density',
          symbol: 'ρ  (kg/m³)',
          controller: _rhoCtrl,
          focusNode: _rhoFocus,
          hintText: 'Static density',
          onChanged: _onDensityChanged,
          error: _fieldErrors[_ActiveField.density],
          isLast: true,
        ),
      ],
    );
  }

  // ── Outputs card (always locked / computed) ─────────────────────────────
  Widget _buildOutputsCard(BuildContext context) {
    return _Card(
      context: context,
      header: _cardHeader(context, Icons.calculate_outlined, 'DERIVED PROPERTIES'),
      children: [
        _outputField(
          context: context,
          label: 'Temperature',
          symbol: 'T  (K)',
          controller: _tCtrl,
        ),
        _divider(),
        _outputField(
          context: context,
          label: 'Speed of Sound',
          symbol: 'a  (m/s)',
          controller: _aCtrl,
        ),
        _divider(),
        _outputField(
          context: context,
          label: 'Dynamic Viscosity',
          symbol: 'μ  (Pa·s)',
          controller: _muCtrl,
          isLast: true,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  Reusable sub-builders
  // ─────────────────────────────────────────────
  Widget _cardHeader(BuildContext context, IconData icon, String title) {
    return Row(
      children: [
        Container(
          width: Responsive.wp(context, 20),
          height: Responsive.wp(context, 20),
          decoration: const BoxDecoration(color: _C.headerBg, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: Responsive.sp(context, 11)),
        ),
        SizedBox(width: Responsive.wp(context, 8)),
        Text(
          title,
          style: TextStyle(
            fontSize: Responsive.sp(context, 12),
            fontWeight: FontWeight.w700,
            color: _C.sectionLabel,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _divider() => const Divider(height: 0, thickness: 0.5, color: _C.rowDivider);

  /// A single editable atmospheric-state field row.
  Widget _atmField({
    required BuildContext context,
    required _ActiveField field,
    required String label,
    required String symbol,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required ValueChanged<String> onChanged,
    String? error,
    bool isLast = false,
  }) {
    final isActive = _activeField == field;
    final isComputed = _activeField != _ActiveField.none && !isActive && _result != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Responsive.pad(context, 14),
        Responsive.pad(context, 8),
        Responsive.pad(context, 14),
        isLast ? Responsive.pad(context, 10) : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: Responsive.sp(context, 12),
                  fontWeight: FontWeight.w500,
                  color: _C.fieldLabel,
                ),
              ),
              SizedBox(width: Responsive.wp(context, 4)),
              Text(
                symbol,
                style: TextStyle(
                  fontSize: Responsive.sp(context, 12),
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  color: _C.fieldLabel,
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.hp(context, 2)),
          _buildInputField(
            context: context,
            controller: controller,
            focusNode: focusNode,
            hintText: hintText,
            onChanged: onChanged,
            hasError: error != null,
            isComputed: isComputed,
            isActive: isActive,
          ),
          if (error != null) ...[
            SizedBox(height: Responsive.hp(context, 4)),
            _errorText(context, error),
          ],
        ],
      ),
    );
  }

  /// A read-only derived-output row — always shown in the "computed" style.
  Widget _outputField({
    required BuildContext context,
    required String label,
    required String symbol,
    required TextEditingController controller,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Responsive.pad(context, 14),
        Responsive.pad(context, 8),
        Responsive.pad(context, 14),
        isLast ? Responsive.pad(context, 10) : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: Responsive.sp(context, 12),
                  fontWeight: FontWeight.w500,
                  color: _C.fieldLabel,
                ),
              ),
              SizedBox(width: Responsive.wp(context, 4)),
              Text(
                symbol,
                style: TextStyle(
                  fontSize: Responsive.sp(context, 12),
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  color: _C.fieldLabel,
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.hp(context, 2)),
          Container(
            height: Responsive.hp(context, 36),
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.symmetric(horizontal: Responsive.pad(context, 12)),
            decoration: BoxDecoration(
              color: _C.computedBg,
              borderRadius: BorderRadius.circular(Responsive.wp(context, 8)),
              border: Border.all(color: _C.fieldBorder.withValues(alpha: 0.6), width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    controller.text.isEmpty ? '—' : controller.text,
                    style: TextStyle(
                      fontSize: Responsive.sp(context, 14),
                      fontWeight: FontWeight.w500,
                      color: controller.text.isEmpty ? _C.labelSmall : _C.outputValue,
                    ),
                  ),
                ),
                if (controller.text.isNotEmpty)
                  Icon(Icons.lock_outline, size: Responsive.sp(context, 14), color: _C.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Styled text field — mirrors the Isentropic Flow input styling.
  Widget _buildInputField({
    required BuildContext context,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required ValueChanged<String> onChanged,
    bool hasError = false,
    bool isComputed = false,
    bool isActive = false,
  }) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (_, __) {
        final focused = focusNode.hasFocus;
        Color borderColor;
        Color bgColor;
        if (hasError) {
          borderColor = _C.errorText;
          bgColor = const Color(0xFFFFF5F5);
        } else if (focused || isActive) {
          borderColor = _C.fieldBorderFocus;
          bgColor = _C.inputActiveBg;
        } else if (isComputed) {
          borderColor = _C.fieldBorder.withValues(alpha: 0.6);
          bgColor = _C.computedBg;
        } else {
          borderColor = _C.fieldBorder;
          bgColor = _C.fieldBg;
        }

        Widget? suffix;
        if (isComputed) {
          suffix = Padding(
            padding: EdgeInsets.only(right: Responsive.pad(context, 10)),
            child: Icon(Icons.lock_outline, size: Responsive.sp(context, 14), color: _C.labelSmall),
          );
        }

        return Container(
          height: Responsive.hp(context, 36),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(Responsive.wp(context, 8)),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            keyboardType: TextInputType.visiblePassword,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.+\-*/^() ×÷]')),
              TextInputFormatter.withFunction((oldValue, newValue) {
                final text = newValue.text.replaceAll('×', '*').replaceAll('÷', '/');
                return newValue.copyWith(text: text);
              }),
              TextInputFormatter.withFunction((oldValue, newValue) {
                final replacedStart = oldValue.selection.start;
                final replacedEnd = oldValue.selection.end;
                int insertedLen;
                if (replacedStart >= 0 && replacedEnd >= 0) {
                  final replacedLen = replacedEnd - replacedStart;
                  insertedLen = newValue.text.length - (oldValue.text.length - replacedLen);
                } else {
                  insertedLen = newValue.text.length - oldValue.text.length;
                }
                if (insertedLen == 1) {
                  final offset = newValue.selection.baseOffset;
                  if (offset > 0 && offset <= newValue.text.length) {
                    final added = newValue.text.substring(offset - 1, offset);
                    if (RegExp(r'\s').hasMatch(added)) {
                      return oldValue;
                    }
                  }
                }
                return newValue;
              }),
            ],
            autocorrect: false,
            enableSuggestions: false,
            style: TextStyle(
              fontSize: Responsive.sp(context, 13),
              fontWeight: isComputed ? FontWeight.w500 : FontWeight.w400,
              color: isComputed ? _C.outputValue : _C.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: Responsive.pad(context, 12),
                vertical: Responsive.pad(context, 6),
              ),
              border: InputBorder.none,
              hintText: hintText,
              hintStyle: TextStyle(
                fontSize: Responsive.sp(context, 12),
                fontWeight: FontWeight.w400,
                color: _C.fieldHint,
              ),
              suffixIcon: suffix,
              suffixIconConstraints: BoxConstraints(
                minWidth: Responsive.wp(context, 34),
                minHeight: Responsive.wp(context, 34),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _errorText(BuildContext context, String msg) {
    return Row(
      children: [
        Icon(Icons.error_outline, size: Responsive.sp(context, 13), color: _C.errorText),
        SizedBox(width: Responsive.wp(context, 4)),
        Expanded(
          child: Text(
            msg,
            style: TextStyle(fontSize: Responsive.sp(context, 11), color: _C.errorText),
          ),
        ),
      ],
    );
  }

  void _showInfoDialog(BuildContext context) {
    showTopicInfoDialog(
      context,
      title: 'About Standard Atmosphere',
      items: const [
        MapEntry('Geopotential Altitude', 'All altitude values are geopotential, per the 1976 US Standard Atmosphere model.'),
        MapEntry('Direct Method', 'When altitude is entered, temperature and pressure follow directly from the layer lapse-rate equations.'),
        MapEntry('Inverse Method', 'When pressure or density is entered, the containing atmospheric layer is located first, then the layer equation is inverted in closed form to recover altitude and temperature.'),
        MapEntry('Viscosity', 'Dynamic viscosity is computed from temperature using Sutherland\'s Law.'),
        MapEntry('Valid Range', 'Altitude 0 – 84,852 m, covering the troposphere through the mesosphere.'),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Reusable Card  (identical to Isentropic Flow page)
// ─────────────────────────────────────────────
class _Card extends StatelessWidget {
  const _Card({
    required this.context,
    required this.header,
    required this.children,
  });

  final BuildContext context;
  final Widget header;
  final List<Widget> children;

  @override
  Widget build(BuildContext ctx) {
    return Container(
      decoration: BoxDecoration(
        color: _C.cardBg,
        borderRadius: BorderRadius.circular(Responsive.wp(ctx, 12)),
        border: Border.all(color: _C.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              Responsive.pad(ctx, 12),
              Responsive.pad(ctx, 6),
              Responsive.pad(ctx, 12),
              Responsive.pad(ctx, 6),
            ),
            child: header,
          ),
          const Divider(height: 0, thickness: 0.5, color: _C.sectionDiv),
          ...children,
        ],
      ),
    );
  }
}