import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/dialogs.dart';
import '../utils/responsive.dart';

// ─────────────────────────────────────────────
//  Colour tokens  (same palette as other pages)
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
  static const fieldSubHint = Color(0xFF9CA3AF);
  static const sectionLabel = Color(0xFF18397C);
  static const outputValue = Color(0xFF0D1F3C);
  static const noteCardBg = Color(0xFFEEF2F8);
  static const noteCardBorder = Color(0xFFC7D4E6);
  static const noteIcon = Color(0xFF0D1F3C);
  static const noteText = Color(0xFF4B6082);
  static const descText = Color(0xFF6B7280);
  static const errorText = Color(0xFFDC2626);
  static const inputActiveBg = Color(0xFFF0F4FF);
  static const computedBg = Color(0xFFFAFAFA);
  static const handyCalcBg = Color(0xFFEEF2F8);
  static const handyCalcBorder = Color(0xFFC7D4E6);
  static const outputReadonlyBg = Color(0xFFF0F4FF);
  static const outputReadonlyBorder = Color(0xFFC7D4E6);
}

// ─────────────────────────────────────────────
//  Predefined gas data
// ─────────────────────────────────────────────
class _GasEntry {
  final String name;
  final double gamma;
  const _GasEntry(this.name, this.gamma);
}

const List<_GasEntry> _kGases = [
  _GasEntry('Air', 1.4),
  _GasEntry('Acetylene', 1.23),
  _GasEntry('Ammonia', 1.3),
  _GasEntry('Argon', 1.67),
  _GasEntry('Butane', 1.09),
  _GasEntry('CO₂', 1.3),
  _GasEntry('CO', 1.4),
  _GasEntry('Ethane', 1.18),
  _GasEntry('Ethylene', 1.21),
  _GasEntry('Helium', 1.67),
  _GasEntry('Hydrogen', 1.4),
  _GasEntry('Methane', 1.32),
  _GasEntry('Nitrogen', 1.4),
  _GasEntry('Oxygen', 1.4),
  _GasEntry('Propane', 1.12),
  _GasEntry('Water Vap.', 1.33),
  _GasEntry('Other', 2.0),
];

// ─────────────────────────────────────────────
//  Enum: active input field
// ─────────────────────────────────────────────
enum _OSField { none, m1, theta, beta, m1n }

// ─────────────────────────────────────────────
//  Simple arithmetic expression evaluator
// ─────────────────────────────────────────────
double? _evalExpr(String input) {
  final s = input.trim().replaceAll(' ', '');
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
//  Calculation engine  (mirrors ObliqueShock.java)
// ─────────────────────────────────────────────
class ObliqueShockResult {
  final double m1;
  final double theta;    // radians
  final double beta;     // radians
  final double m1n;
  final double thetaMax; // radians
  final double m2;
  final double m2n;
  final double t2t1;
  final double p2p1;
  final double rho2rho1;
  final double p02p01;
  final bool isStrong;

  const ObliqueShockResult({
    required this.m1,
    required this.theta,
    required this.beta,
    required this.m1n,
    required this.thetaMax,
    required this.m2,
    required this.m2n,
    required this.t2t1,
    required this.p2p1,
    required this.rho2rho1,
    required this.p02p01,
    required this.isStrong,
  });
}

class ObliqueShockEngine {
  // ── Isentropic helpers ──────────────────────────────────────────────────────
  static double tt0(double g, double m) =>
      pow(1.0 + (g - 1.0) / 2.0 * m * m, -1.0).toDouble();

  static double pp0(double g, double m) =>
      pow(1.0 + (g - 1.0) / 2.0 * m * m, -g / (g - 1.0)).toDouble();

  static double rr0(double g, double m) =>
      pow(1.0 + (g - 1.0) / 2.0 * m * m, -1.0 / (g - 1.0)).toDouble();

  // ── beta at theta_max  (analytic, from PDF) ──────────────────────────────
  static double betaAtThetaMax(double m1, double g) {
    final aa = sqrt(
      (g + 1.0) * ((g + 1.0) * pow(m1, 4) / 16.0 + (g - 1.0) * m1 * m1 / 2.0 + 1.0),
    );
    final bb = (1.0 / (g * m1 * m1)) * ((g + 1.0) * m1 * m1 / 4.0 - 1.0 + aa);
    return asin(sqrt(bb));
  }

  // ── theta_max ──────────────────────────────────────────────────────────────
  static double thetaMax(double m1, double g) {
    final b = betaAtThetaMax(m1, g);
    return atan(
      (m1 * m1 * sin(2.0 * b) - 2.0 / tan(b)) /
      (2.0 + m1 * m1 * (g + cos(2.0 * b))),
    );
  }

  // ── calculate_beta: cubic solver (mirrors Java calculate_beta()) ────────
  // Returns {betaWeak, betaStrong} or null for detached shock (Δ > 0).
  static ({double weak, double strong})? solveBeta(
      double m1, double thetaRad, double g) {
    final d = thetaRad;
    final p = -(m1 * m1 + 2.0) / m1 / m1 - g * sin(d) * sin(d);
    final q = (2.0 * m1 * m1 + 1.0) / pow(m1, 4) +
        ((g + 1.0) * (g + 1.0) / 4.0 + (g - 1.0) / m1 / m1) * sin(d) * sin(d);
    final r = -cos(d) * cos(d) / pow(m1, 4);

    final a = (3.0 * q - p * p) / 3.0;
    final b = (2.0 * p * p * p - 9.0 * p * q + 27.0 * r) / 27.0;
    final delta = b * b / 4.0 + a * a * a / 27.0;

    if (delta > 0.0) return null; // detached

    double x1, x2, x3;
    if (delta == 0.0) {
      x1 = sqrt(-a / 3.0);
      x2 = x1;
      x3 = 2.0 * x1;
      if (b > 0.0) { x1 = -x1; x2 = -x2; x3 = -x3; }
    } else {
      final phi = acos(sqrt(-27.0 * b * b / 4.0 / a / a / a));
      x1 = 2.0 * sqrt(-a / 3.0) * cos(phi / 3.0);
      x2 = 2.0 * sqrt(-a / 3.0) * cos(phi / 3.0 + pi * 2.0 / 3.0);
      x3 = 2.0 * sqrt(-a / 3.0) * cos(phi / 3.0 + pi * 4.0 / 3.0);
      if (b > 0.0) { x1 = -x1; x2 = -x2; x3 = -x3; }
    }

    final s1 = x1 - p / 3.0;
    final s2 = x2 - p / 3.0;
    final s3 = x3 - p / 3.0;

    double t1, t2;
    if (s1 < s2 && s1 < s3) { t1 = s2; t2 = s3; }
    else if (s2 < s1 && s2 < s3) { t1 = s1; t2 = s3; }
    else { t1 = s1; t2 = s2; }

    final b1 = asin(sqrt(t1));
    final b2 = asin(sqrt(t2));

    final bStr = b2 > b1 ? b2 : b1;
    final bWeak = b2 > b1 ? b1 : b2;
    return (weak: bWeak, strong: bStr);
  }

  // ── Core: given beta (radians) compute all oblique-shock properties ───────
  static ObliqueShockResult fromBeta(
      double m1, double betaRad, double g, bool isStrongHint) {
    final betaAtMax = betaAtThetaMax(m1, g);
    final thetaMaxVal = thetaMax(m1, g);
    final isStrong = betaRad >= betaAtMax;

    final theta = atan(
      (m1 * m1 * sin(2.0 * betaRad) - 2.0 / tan(betaRad)) /
      (2.0 + m1 * m1 * (g + cos(2.0 * betaRad))),
    );
    final m1n = m1 * sin(betaRad);
    final m2n = sqrt(
      (1.0 + 0.5 * (g - 1.0) * m1n * m1n) /
      (g * m1n * m1n - 0.5 * (g - 1.0)),
    );
    final m2 = m2n / sin(betaRad - theta);
    final t2t1 = tt0(g, m2n) / tt0(g, m1n);
    final p2p1 = 1.0 + 2.0 * g / (g + 1.0) * (m1n * m1n - 1.0);
    final p02p01 = pp0(g, m1n) / pp0(g, m2n) * p2p1;
    final rho2rho1 = rr0(g, m2n) / rr0(g, m1n) * p02p01;

    return ObliqueShockResult(
      m1: m1,
      theta: theta,
      beta: betaRad,
      m1n: m1n,
      thetaMax: thetaMaxVal,
      m2: m2,
      m2n: m2n,
      t2t1: t2t1,
      p2p1: p2p1,
      rho2rho1: rho2rho1,
      p02p01: p02p01,
      isStrong: isStrong,
    );
  }
}

// ─────────────────────────────────────────────
//  Main Screen Widget
// ─────────────────────────────────────────────
class ObliqueShockScreen extends StatefulWidget {
  final VoidCallback? onDrawer;
  const ObliqueShockScreen({super.key, this.onDrawer});

  @override
  State<ObliqueShockScreen> createState() => _ObliqueShockScreenState();
}

class _ObliqueShockScreenState extends State<ObliqueShockScreen> {
  // ── Controllers ───────────────────────────────────────────────────────────
  final _gammaCtrl  = TextEditingController();
  final _m1Ctrl     = TextEditingController();
  final _thetaCtrl  = TextEditingController();
  final _betaCtrl   = TextEditingController();
  final _m1nCtrl    = TextEditingController();

  // ── Focus nodes ──────────────────────────────────────────────────────────
  final _gammaFocus = FocusNode();
  final _m1Focus    = FocusNode();
  final _thetaFocus = FocusNode();
  final _betaFocus  = FocusNode();
  final _m1nFocus   = FocusNode();

  // ── State ─────────────────────────────────────────────────────────────────
  double _gamma = 1.4;
  bool _gammaValid = true;
  String? _gammaError;

  bool _m1Valid = false;
  double _m1Value = 0.0;
  double _machAngle = 0.0; // μ₁ = asin(1/M1) in radians
  double _thetaMaxRad = 0.0;

  _OSField _activeField = _OSField.none;
  ObliqueShockResult? _result;

  final Map<_OSField, String?> _fieldErrors = {};
  String _selectedGasName = 'Air';
  bool _updating = false;

  // Weak/Strong toggle
  bool _isStrong = false;

  // ── Reciprocal ratio toggle (for ratio outputs) ──────────────────────────
  bool _inverseRatio = false;

  @override
  void initState() {
    super.initState();
    _gammaCtrl.text = '1.4';

    void onFocusChange(_OSField field, FocusNode node) {
      node.addListener(() {
        if (node.hasFocus && _activeField != field) {
          setState(() => _activeField = field);
        }
      });
    }

    onFocusChange(_OSField.m1, _m1Focus);
    onFocusChange(_OSField.theta, _thetaFocus);
    onFocusChange(_OSField.beta, _betaFocus);
    onFocusChange(_OSField.m1n, _m1nFocus);
  }

  @override
  void dispose() {
    for (final c in [_gammaCtrl, _m1Ctrl, _thetaCtrl, _betaCtrl, _m1nCtrl]) {
      c.dispose();
    }
    for (final f in [_gammaFocus, _m1Focus, _thetaFocus, _betaFocus, _m1nFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  // ─────────────────────────────────────────────
  //  Format helper
  // ─────────────────────────────────────────────
  String _fmt(double v) {
    if (v.abs() >= 1e6 || (v.abs() < 1e-4 && v != 0)) {
      return v.toStringAsExponential(5);
    }
    String s = v.toStringAsFixed(6);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      if (s.endsWith('.')) s += '0';
    }
    return s;
  }

  // ─────────────────────────────────────────────
  //  Gamma change
  // ─────────────────────────────────────────────
  void _onGammaChanged(String raw, {bool fromDropdown = false}) {
    if (_updating) return;
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '.') {
      setState(() {
        _gammaValid = false;
        _gammaError = 'γ is required';
        _result = null;
      });
      return;
    }
    final val = _evalExpr(trimmed);
    if (val == null) {
      setState(() {
        _gammaValid = false;
        _gammaError = 'Invalid expression';
        _result = null;
      });
      return;
    }
    if (val <= 1.0) {
      setState(() {
        _gammaValid = false;
        _gammaError = 'γ must be greater than 1';
        _result = null;
      });
      return;
    }
    _gamma = val;
    if (fromDropdown) {
      setState(() {
        _gammaValid = true;
        _gammaError = null;
      });
    } else {
      final match = _kGases
          .where((g) => !g.gamma.isNaN && (g.gamma - val).abs() < 1e-9)
          .firstOrNull;
      setState(() {
        _gammaValid = true;
        _gammaError = null;
        if (match != null) {
          _selectedGasName = match.name;
        } else if (_selectedGasName != 'Other') {
          _selectedGasName = 'Other';
        }
      });
    }
    // Recalc theta_max if M1 valid
    if (_m1Valid) {
      _thetaMaxRad = ObliqueShockEngine.thetaMax(_m1Value, _gamma);
    }
    _recalculate();
  }

  // ─────────────────────────────────────────────
  //  M1 change
  // ─────────────────────────────────────────────
  void _onM1Changed(String raw) {
    if (_updating) return;
    _activeField = _OSField.m1;
    _clearOtherErrors(_OSField.m1);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _m1Valid = false;
        _fieldErrors[_OSField.m1] = null;
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    final val = _evalExpr(trimmed);
    if (val == null) {
      setState(() {
        _m1Valid = false;
        _fieldErrors[_OSField.m1] = 'Invalid expression';
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    if (!_gammaValid) {
      setState(() => _fieldErrors[_OSField.m1] = 'Enter a valid γ first');
      return;
    }
    if (val <= 1.0) {
      setState(() {
        _m1Valid = false;
        _fieldErrors[_OSField.m1] = 'M₁ must be greater than 1';
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    _m1Valid = true;
    _m1Value = val;
    _machAngle = asin(1.0 / val);
    _thetaMaxRad = ObliqueShockEngine.thetaMax(val, _gamma);
    setState(() => _fieldErrors[_OSField.m1] = null);
    // If another field is active, recalc with new M1
    _recalculateSecondaryField();
  }

  // ─────────────────────────────────────────────
  //  θ change
  // ─────────────────────────────────────────────
  void _onThetaChanged(String raw) {
    if (_updating) return;
    _activeField = _OSField.theta;
    _clearOtherErrors(_OSField.theta);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _fieldErrors[_OSField.theta] = null;
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    final val = _evalExpr(trimmed);
    if (val == null) {
      setState(() {
        _fieldErrors[_OSField.theta] = 'Invalid expression';
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    if (!_gammaValid) {
      setState(() => _fieldErrors[_OSField.theta] = 'Enter a valid γ first');
      return;
    }
    if (!_m1Valid) {
      setState(() => _fieldErrors[_OSField.theta] = 'Enter a valid M₁ first');
      return;
    }
    if (val <= 0.0 || val >= 90.0) {
      setState(() {
        _fieldErrors[_OSField.theta] = 'θ must be between 0° and 90°';
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    final thetaRad = val * pi / 180.0;
    if (thetaRad > _thetaMaxRad) {
      setState(() {
        _fieldErrors[_OSField.theta] =
            'Detached shock (θ > θmax = ${_fmt(_thetaMaxRad * 180.0 / pi)}°)';
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    final betas = ObliqueShockEngine.solveBeta(_m1Value, thetaRad, _gamma);
    if (betas == null) {
      setState(() {
        _fieldErrors[_OSField.theta] = 'Detached shock';
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    final betaRad = _isStrong ? betas.strong : betas.weak;
    setState(() => _fieldErrors[_OSField.theta] = null);
    _computeFromBeta(betaRad);
  }

  // ─────────────────────────────────────────────
  //  β change
  // ─────────────────────────────────────────────
  void _onBetaChanged(String raw) {
    if (_updating) return;
    _activeField = _OSField.beta;
    _clearOtherErrors(_OSField.beta);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _fieldErrors[_OSField.beta] = null;
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    final val = _evalExpr(trimmed);
    if (val == null) {
      setState(() {
        _fieldErrors[_OSField.beta] = 'Invalid expression';
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    if (!_gammaValid) {
      setState(() => _fieldErrors[_OSField.beta] = 'Enter a valid γ first');
      return;
    }
    if (!_m1Valid) {
      setState(() => _fieldErrors[_OSField.beta] = 'Enter a valid M₁ first');
      return;
    }
    final betaRad = val * pi / 180.0;
    final muDeg = _machAngle * 180.0 / pi;
    if (betaRad >= pi / 2.0) {
      setState(() {
        _fieldErrors[_OSField.beta] = 'β must be less than 90°';
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    if (betaRad <= _machAngle) {
      setState(() {
        _fieldErrors[_OSField.beta] =
            'β must be greater than Mach angle (${_fmt(muDeg)}°)';
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    setState(() => _fieldErrors[_OSField.beta] = null);
    _computeFromBeta(betaRad);
  }

  // ─────────────────────────────────────────────
  //  M1n change
  // ─────────────────────────────────────────────
  void _onM1nChanged(String raw) {
    if (_updating) return;
    _activeField = _OSField.m1n;
    _clearOtherErrors(_OSField.m1n);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _fieldErrors[_OSField.m1n] = null;
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    final val = _evalExpr(trimmed);
    if (val == null) {
      setState(() {
        _fieldErrors[_OSField.m1n] = 'Invalid expression';
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    if (!_gammaValid) {
      setState(() => _fieldErrors[_OSField.m1n] = 'Enter a valid γ first');
      return;
    }
    if (!_m1Valid) {
      setState(() => _fieldErrors[_OSField.m1n] = 'Enter a valid M₁ first');
      return;
    }
    if (val <= 1.0 || val >= _m1Value) {
      setState(() {
        _fieldErrors[_OSField.m1n] = 'M₁ₙ must be between 1 and M₁ (${_fmt(_m1Value)})';
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    setState(() => _fieldErrors[_OSField.m1n] = null);
    // β = asin(M1n/M1)
    final betaRad = asin(val / _m1Value);
    _computeFromBeta(betaRad);
  }

  // ─────────────────────────────────────────────
  //  Core compute
  // ─────────────────────────────────────────────
  void _computeFromBeta(double betaRad) {
    final result = ObliqueShockEngine.fromBeta(_m1Value, betaRad, _gamma, _isStrong);
    setState(() {
      _result = result;
      _isStrong = result.isStrong;
    });
    _writeComputedFields();
  }

  void _recalculate() {
    if (_activeField == _OSField.none) return;
    switch (_activeField) {
      case _OSField.m1:
        _onM1Changed(_m1Ctrl.text);
      case _OSField.theta:
        _onThetaChanged(_thetaCtrl.text);
      case _OSField.beta:
        _onBetaChanged(_betaCtrl.text);
      case _OSField.m1n:
        _onM1nChanged(_m1nCtrl.text);
      case _OSField.none:
        break;
    }
  }

  // When M1 changes and another secondary field is active, recompute
  void _recalculateSecondaryField() {
    if (_activeField == _OSField.none || _activeField == _OSField.m1) {
      setState(() {});
      return;
    }
    switch (_activeField) {
      case _OSField.theta:
        _onThetaChanged(_thetaCtrl.text);
      case _OSField.beta:
        _onBetaChanged(_betaCtrl.text);
      case _OSField.m1n:
        _onM1nChanged(_m1nCtrl.text);
      default:
        break;
    }
  }

  // ─────────────────────────────────────────────
  //  Write computed values to non-active fields
  // ─────────────────────────────────────────────
  void _writeComputedFields() {
    if (_result == null) return;
    _updating = true;
    final r = _result!;

    void setIfNotActive(_OSField field, TextEditingController ctrl, String Function() value) {
      if (_activeField != field) ctrl.text = value();
    }

    setIfNotActive(_OSField.m1, _m1Ctrl, () => _fmt(r.m1));
    setIfNotActive(_OSField.theta, _thetaCtrl, () => _fmt(r.theta * 180.0 / pi));
    setIfNotActive(_OSField.beta, _betaCtrl, () => _fmt(r.beta * 180.0 / pi));
    setIfNotActive(_OSField.m1n, _m1nCtrl, () => _fmt(r.m1n));

    _updating = false;
  }

  void _clearOutputFields() {
    _updating = true;
    // Clear all secondary fields except the one currently being edited
    if (_activeField != _OSField.theta) _thetaCtrl.clear();
    if (_activeField != _OSField.beta)  _betaCtrl.clear();
    if (_activeField != _OSField.m1n)   _m1nCtrl.clear();
    _updating = false;
    setState(() => _result = null);
  }

  void _clearOtherErrors(_OSField keep) {
    for (final f in _OSField.values) {
      if (f != keep) _fieldErrors.remove(f);
    }
  }

  // ─────────────────────────────────────────────
  //  HandyCalc dialog
  // ─────────────────────────────────────────────
  void _openHandyCalc({
    required String title,
    required String inverseTitle,
    required String label1,
    required String label2,
    required double ratio,
  }) {
    showDialog(
      context: context,
      builder: (_) => _HandyCalcDialog(
        title: title,
        inverseTitle: inverseTitle,
        label1: label1,
        label2: label2,
        ratio: ratio,
      ),
    );
  }

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
                Responsive.pad(context, 14),
                Responsive.pad(context, 10),
                Responsive.pad(context, 14),
                Responsive.pad(context, 24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGammaCard(context),
                  SizedBox(height: Responsive.hp(context, 10)),
                  _buildFlowPropertiesCard(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────
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
                  'Oblique Shock',
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
                icon: Icon(
                  Icons.tips_and_updates_outlined,
                  color: Colors.yellow,
                  size: Responsive.sp(context, 22),
                ),
                onPressed: () => _showFeaturesDialog(context),
              ),
              IconButton(
                icon: Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: Responsive.sp(context, 22),
                ),
                onPressed: () => _showInfoDialog(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Gamma card ────────────────────────────────────────────────────────────
  Widget _buildGammaCard(BuildContext context) {
    return _Card(
      context: context,
      header: _cardHeader(context, Icons.tune, 'SPECIFIC HEAT RATIO  γ'),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            Responsive.pad(context, 14),
            Responsive.pad(context, 10),
            Responsive.pad(context, 14),
            Responsive.pad(context, 10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      context: context,
                      controller: _gammaCtrl,
                      focusNode: _gammaFocus,
                      hintText: 'Must be greater than 1 (e.g. 1.4)',
                      onChanged: _onGammaChanged,
                      hasError: !_gammaValid,
                    ),
                  ),
                  SizedBox(width: Responsive.wp(context, 8)),
                  _GasDropdownButton(
                    context: context,
                    selectedName: _selectedGasName,
                    onSelect: (gas) {
                      _updating = true;
                      _gammaCtrl.text = gas.gamma.toString();
                      _updating = false;
                      setState(() => _selectedGasName = gas.name);
                      _onGammaChanged(gas.gamma.toString(), fromDropdown: true);
                    },
                  ),
                ],
              ),
              if (_gammaError != null) ...[
                SizedBox(height: Responsive.hp(context, 4)),
                _errorText(context, _gammaError!),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Single Flow Properties card (inputs + outputs combined) ─────────────
  Widget _buildFlowPropertiesCard(BuildContext context) {
    final r = _result;

    // Dynamic ratio labels
    final t2t1Sym   = _inverseRatio ? 'T₁/T₂'   : 'T₂/T₁';
    final p2p1Sym   = _inverseRatio ? 'P₁/P₂'   : 'P₂/P₁';
    final rhoSym    = _inverseRatio ? 'ρ₁/ρ₂'   : 'ρ₂/ρ₁';
    final p02p01Sym = _inverseRatio ? 'P₀₁/P₀₂' : 'P₀₂/P₀₁';

    String outVal(double? v) => v != null ? _fmt(v) : '—';

    // Weak/strong toggle
    final toggleWidget = GestureDetector(
      onTap: () {
        if (_result == null && _thetaCtrl.text.trim().isEmpty) {
          // No result yet and no theta value — just flip the flag
          setState(() => _isStrong = !_isStrong);
          return;
        }
        setState(() {
          _isStrong = !_isStrong;
          _activeField = _OSField.theta;
        });
        _onThetaChanged(_thetaCtrl.text);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.pad(context, 8),
          vertical: Responsive.pad(context, 5),
        ),
        decoration: BoxDecoration(
          color: _isStrong ? _C.headerBg : const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(Responsive.wp(context, 6)),
        ),
        child: Text(
          _isStrong ? 'STRONG' : 'WEAK',
          style: TextStyle(
            fontSize: Responsive.sp(context, 11),
            fontWeight: FontWeight.w600,
            color: _isStrong ? Colors.white : _C.labelMedium,
          ),
        ),
      ),
    );

    // Reciprocal toggle
    final reciprocalToggle = GestureDetector(
      onTap: () {
        setState(() => _inverseRatio = !_inverseRatio);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.pad(context, 8),
          vertical: Responsive.pad(context, 5),
        ),
        decoration: BoxDecoration(
          color: _inverseRatio ? _C.headerBg : const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(Responsive.wp(context, 6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_horiz,
              size: Responsive.sp(context, 14),
              color: _inverseRatio ? Colors.white : _C.labelMedium,
            ),
            SizedBox(width: Responsive.wp(context, 4)),
            Text(
              'Reciprocal',
              style: TextStyle(
                fontSize: Responsive.sp(context, 11),
                fontWeight: FontWeight.w600,
                color: _inverseRatio ? Colors.white : _C.labelMedium,
              ),
            ),
          ],
        ),
      ),
    );

    return _Card(
      context: context,
      header: Row(
        children: [
          Expanded(child: _cardHeader(context, Icons.calculate_outlined, 'FLOW PROPERTIES')),
          toggleWidget,
          SizedBox(width: Responsive.wp(context, 6)),
          reciprocalToggle,
        ],
      ),
      children: [
        // ── M₁ ─────────────────────────────────────────────────────────────
        _flowField(
          context: context,
          field: _OSField.m1,
          label: 'Upstream Mach',
          symbol: 'M₁',
          controller: _m1Ctrl,
          focusNode: _m1Focus,
          hintText: 'Must be greater than 1',
          onChanged: _onM1Changed,
          error: _fieldErrors[_OSField.m1],
        ),

        _divider(),

        // ── θ ──────────────────────────────────────────────────────────────
        _flowField(
          context: context,
          field: _OSField.theta,
          label: 'Turn / Deflection angle',
          symbol: 'θ°',
          controller: _thetaCtrl,
          focusNode: _thetaFocus,
          hintText: _m1Valid
              ? 'Between 0° and ${_fmt(_thetaMaxRad * 180.0 / pi)}°'
              : 'Enter M₁ first',
          onChanged: _onThetaChanged,
          error: _fieldErrors[_OSField.theta],
        ),

        _divider(),

        // ── β ──────────────────────────────────────────────────────────────
        _flowField(
          context: context,
          field: _OSField.beta,
          label: 'Shock angle',
          symbol: 'β°',
          controller: _betaCtrl,
          focusNode: _betaFocus,
          hintText: _m1Valid
              ? 'Between ${_fmt(_machAngle * 180.0 / pi)}° and 90°'
              : 'Enter M₁ first',
          onChanged: _onBetaChanged,
          error: _fieldErrors[_OSField.beta],
        ),

        _divider(),

        // ── M₁ₙ ────────────────────────────────────────────────────────────
        _flowField(
          context: context,
          field: _OSField.m1n,
          label: 'Normal component (before)',
          symbol: 'M₁ₙ',
          controller: _m1nCtrl,
          focusNode: _m1nFocus,
          hintText: _m1Valid ? 'Between 1 and M₁ (${_fmt(_m1Value)})' : 'Enter M₁ first',
          onChanged: _onM1nChanged,
          error: _fieldErrors[_OSField.m1n],
          isLast: false,
        ),

        const Divider(height: 0, thickness: 0.5, color: _C.sectionDiv),

        // ── Output section ──────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(
            Responsive.pad(context, 14),
            Responsive.pad(context, 10),
            Responsive.pad(context, 14),
            Responsive.pad(context, 10),
          ),
          child: Column(
            children: [
              // Row: θmax (always shown)
              _outputRowFull(
                context: context,
                symbol: 'θmax',
                label: 'Max turn angle',
                value: _m1Valid ? outVal(_thetaMaxRad * 180.0 / pi) : '—',
                unit: '°',
              ),

              SizedBox(height: Responsive.hp(context, 8)),

              // Row: M₂ | M₂ₙ
              _outputRowPair(
                context: context,
                sym1: 'M₂',
                val1: outVal(r?.m2),
                sym2: 'M₂ₙ',
                val2: outVal(r?.m2n),
              ),

              SizedBox(height: Responsive.hp(context, 8)),

              // Row: T₂/T₁ | P₂/P₁
              _outputRowPairWithHandy(
                context: context,
                sym1: t2t1Sym,
                val1: outVal(r != null
                    ? (_inverseRatio ? 1.0 / r.t2t1 : r.t2t1)
                    : null),
                sym2: p2p1Sym,
                val2: outVal(r != null
                    ? (_inverseRatio ? 1.0 / r.p2p1 : r.p2p1)
                    : null),
                onHandy1: r != null
                    ? () => _openHandyCalc(
                        title: '$t2t1Sym = ${_fmt(_inverseRatio ? 1.0/r.t2t1 : r.t2t1)}',
                        inverseTitle: _inverseRatio
                            ? 'T₂/T₁ = ${_fmt(r.t2t1)}'
                            : 'T₁/T₂ = ${_fmt(1.0/r.t2t1)}',
                        label1: _inverseRatio ? 'T₁ =' : 'T₂ =',
                        label2: _inverseRatio ? 'T₂ =' : 'T₁ =',
                        ratio: _inverseRatio ? 1.0/r.t2t1 : r.t2t1,
                      )
                    : null,
                onHandy2: r != null
                    ? () => _openHandyCalc(
                        title: '$p2p1Sym = ${_fmt(_inverseRatio ? 1.0/r.p2p1 : r.p2p1)}',
                        inverseTitle: _inverseRatio
                            ? 'P₂/P₁ = ${_fmt(r.p2p1)}'
                            : 'P₁/P₂ = ${_fmt(1.0/r.p2p1)}',
                        label1: _inverseRatio ? 'P₁ =' : 'P₂ =',
                        label2: _inverseRatio ? 'P₂ =' : 'P₁ =',
                        ratio: _inverseRatio ? 1.0/r.p2p1 : r.p2p1,
                      )
                    : null,
              ),

              SizedBox(height: Responsive.hp(context, 8)),

              // Row: ρ₂/ρ₁ | P₀₂/P₀₁
              _outputRowPairWithHandy(
                context: context,
                sym1: rhoSym,
                val1: outVal(r != null
                    ? (_inverseRatio ? 1.0 / r.rho2rho1 : r.rho2rho1)
                    : null),
                sym2: p02p01Sym,
                val2: outVal(r != null
                    ? (_inverseRatio ? 1.0 / r.p02p01 : r.p02p01)
                    : null),
                onHandy1: r != null
                    ? () => _openHandyCalc(
                        title: '$rhoSym = ${_fmt(_inverseRatio ? 1.0/r.rho2rho1 : r.rho2rho1)}',
                        inverseTitle: _inverseRatio
                            ? 'ρ₂/ρ₁ = ${_fmt(r.rho2rho1)}'
                            : 'ρ₁/ρ₂ = ${_fmt(1.0/r.rho2rho1)}',
                        label1: _inverseRatio ? 'ρ₁ =' : 'ρ₂ =',
                        label2: _inverseRatio ? 'ρ₂ =' : 'ρ₁ =',
                        ratio: _inverseRatio ? 1.0/r.rho2rho1 : r.rho2rho1,
                      )
                    : null,
                onHandy2: r != null
                    ? () => _openHandyCalc(
                        title: '$p02p01Sym = ${_fmt(_inverseRatio ? 1.0/r.p02p01 : r.p02p01)}',
                        inverseTitle: _inverseRatio
                            ? 'P₀₂/P₀₁ = ${_fmt(r.p02p01)}'
                            : 'P₀₁/P₀₂ = ${_fmt(1.0/r.p02p01)}',
                        label1: _inverseRatio ? 'P₀₁ =' : 'P₀₂ =',
                        label2: _inverseRatio ? 'P₀₂ =' : 'P₀₁ =',
                        ratio: _inverseRatio ? 1.0/r.p02p01 : r.p02p01,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  Output row helpers
  // ─────────────────────────────────────────────

  Widget _outputRowFull({
    required BuildContext context,
    required String symbol,
    required String label,
    required String value,
    String unit = '',
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.pad(context, 12),
        vertical: Responsive.pad(context, 10),
      ),
      decoration: BoxDecoration(
        color: _C.outputReadonlyBg,
        borderRadius: BorderRadius.circular(Responsive.wp(context, 8)),
        border: Border.all(color: _C.outputReadonlyBorder, width: 0.8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            symbol,
            style: TextStyle(
              fontSize: Responsive.sp(context, 13),
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: _C.sectionLabel,
            ),
          ),
          Text(
            '$value$unit',
            style: TextStyle(
              fontSize: Responsive.sp(context, 14),
              fontWeight: FontWeight.w600,
              color: _C.outputValue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _outputRowPair({
    required BuildContext context,
    required String sym1,
    required String val1,
    required String sym2,
    required String val2,
  }) {
    return Row(
      children: [
        Expanded(child: _outputCell(context, sym1, val1)),
        SizedBox(width: Responsive.wp(context, 8)),
        Expanded(child: _outputCell(context, sym2, val2)),
      ],
    );
  }

  Widget _outputRowPairWithHandy({
    required BuildContext context,
    required String sym1,
    required String val1,
    required String sym2,
    required String val2,
    VoidCallback? onHandy1,
    VoidCallback? onHandy2,
  }) {
    return Row(
      children: [
        Expanded(child: _outputCell(context, sym1, val1, onHandy: onHandy1)),
        SizedBox(width: Responsive.wp(context, 8)),
        Expanded(child: _outputCell(context, sym2, val2, onHandy: onHandy2)),
      ],
    );
  }

  Widget _outputCell(BuildContext context, String symbol, String value, {VoidCallback? onHandy}) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        Responsive.pad(context, 10),
        Responsive.pad(context, 8),
        Responsive.pad(context, onHandy != null ? 4 : 10),
        Responsive.pad(context, 8),
      ),
      decoration: BoxDecoration(
        color: _C.outputReadonlyBg,
        borderRadius: BorderRadius.circular(Responsive.wp(context, 8)),
        border: Border.all(color: _C.outputReadonlyBorder, width: 0.8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  symbol,
                  style: TextStyle(
                    fontSize: Responsive.sp(context, 11),
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    color: _C.sectionLabel,
                  ),
                ),
                SizedBox(height: Responsive.hp(context, 2)),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: Responsive.sp(context, 13),
                    fontWeight: FontWeight.w600,
                    color: _C.outputValue,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onHandy != null)
            GestureDetector(
              onTap: onHandy,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.all(Responsive.pad(context, 6)),
                child: Icon(
                  Icons.compare_arrows_rounded,
                  size: Responsive.sp(context, 16),
                  color: _C.headerBg,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Reusable sub-builders
  // ─────────────────────────────────────────────

  Widget _cardHeader(BuildContext context, IconData icon, String title) {
    return Row(
      children: [
        Container(
          width: Responsive.wp(context, 24),
          height: Responsive.wp(context, 24),
          decoration: const BoxDecoration(color: _C.headerBg, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: Responsive.sp(context, 13)),
        ),
        SizedBox(width: Responsive.wp(context, 8)),
        Text(
          title,
          style: TextStyle(
            fontSize: Responsive.sp(context, 13.5),
            fontWeight: FontWeight.w700,
            color: _C.sectionLabel,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _divider() =>
      const Divider(height: 0, thickness: 0.5, color: _C.rowDivider);

  Widget _flowField({
    required BuildContext context,
    required _OSField field,
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
    final isComputed =
        _activeField != _OSField.none && !isActive && _result != null;

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
                  fontSize: Responsive.sp(context, 13),
                  fontWeight: FontWeight.w500,
                  color: _C.fieldLabel,
                ),
              ),
              SizedBox(width: Responsive.wp(context, 4)),
              Text(
                symbol,
                style: TextStyle(
                  fontSize: Responsive.sp(context, 13),
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  color: _C.fieldLabel,
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.hp(context, 5)),
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

  Widget _buildInputField({
    required BuildContext context,
    Key? key,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required ValueChanged<String> onChanged,
    bool hasError = false,
    bool isComputed = false,
    bool isActive = false,
    VoidCallback? onHandyCalc,
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
        if (onHandyCalc != null) {
          suffix = GestureDetector(
            onTap: onHandyCalc,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: Responsive.pad(context, 10)),
              child: Icon(
                Icons.compare_arrows_rounded,
                size: Responsive.sp(context, 18),
                color: _C.headerBg,
              ),
            ),
          );
        } else if (isComputed) {
          suffix = Padding(
            padding: EdgeInsets.only(right: Responsive.pad(context, 10)),
            child: Icon(Icons.lock_outline, size: Responsive.sp(context, 14), color: _C.labelSmall),
          );
        }

        return Container(
          key: key,
          height: Responsive.hp(context, 46),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(Responsive.wp(context, 8)),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.+\-*/^() ×÷]')),
              TextInputFormatter.withFunction((oldValue, newValue) {
                final text = newValue.text.replaceAll('×', '*').replaceAll('÷', '/');
                return newValue.copyWith(text: text);
              }),
            ],
            autocorrect: false,
            enableSuggestions: false,
            style: TextStyle(
              fontSize: Responsive.sp(context, 14),
              fontWeight: isComputed ? FontWeight.w500 : FontWeight.w400,
              color: isComputed ? _C.outputValue : _C.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: Responsive.pad(context, 12),
                vertical: Responsive.pad(context, 13),
              ),
              border: InputBorder.none,
              hintText: hintText,
              hintStyle: TextStyle(
                fontSize: Responsive.sp(context, 13),
                fontWeight: FontWeight.w400,
                color: _C.fieldHint,
              ),
              suffixIcon: suffix,
              suffixIconConstraints: BoxConstraints(
                minWidth: Responsive.wp(context, 30),
                minHeight: Responsive.wp(context, 30),
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

  // ── Features dialog ───────────────────────────────────────────────────────
  void _showFeaturesDialog(BuildContext context) {
    showAppFeaturesDialog(context);
  }

  // ── Info dialog ───────────────────────────────────────────────────────────
  void _showInfoDialog(BuildContext context) {
    showTopicInfoDialog(
      context,
      title: 'About Oblique Shock',
      items: const [
        MapEntry('State 1', 'Upstream conditions before the shock. M₁ must be supersonic (> 1).'),
        MapEntry('State 2', 'Downstream conditions after the oblique shock.'),
        MapEntry('θ — Deflection angle', 'The flow turn angle caused by the body. Must be ≤ θmax for an attached shock.'),
        MapEntry('β — Shock angle', 'Angle between the shock wave and the upstream flow. Must be between the Mach angle μ₁ and 90°.'),
        MapEntry('M₁ₙ / M₂ₙ', 'Normal-to-shock components of Mach number, used in the equivalent normal-shock relations.'),
        MapEntry('θmax', 'Maximum deflection angle for an attached shock at the given M₁. Exceeding it gives a detached (bow) shock.'),
        MapEntry('Weak / Strong', 'Two solutions exist for a given θ. Weak shock has smaller β; strong shock has larger β. Toggle to switch.'),
        MapEntry('Reciprocal', 'Flips all ratio outputs to their reciprocals (e.g. T₂/T₁ ↔ T₁/T₂).'),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Gas dropdown button
// ─────────────────────────────────────────────
class _GasDropdownButton extends StatelessWidget {
  const _GasDropdownButton({
    required this.context,
    required this.onSelect,
    required this.selectedName,
  });
  final BuildContext context;
  final ValueChanged<_GasEntry> onSelect;
  final String selectedName;

  @override
  Widget build(BuildContext ctx) {
    return GestureDetector(
      onTap: () => _showGasPicker(ctx),
      child: Container(
        height: Responsive.hp(ctx, 46),
        padding: EdgeInsets.symmetric(horizontal: Responsive.pad(ctx, 12)),
        decoration: BoxDecoration(
          color: _C.headerBg,
          borderRadius: BorderRadius.circular(Responsive.wp(ctx, 8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedName,
              style: TextStyle(
                color: Colors.white,
                fontSize: Responsive.sp(ctx, 13),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: Responsive.wp(ctx, 4)),
            Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white,
              size: Responsive.sp(ctx, 16),
            ),
          ],
        ),
      ),
    );
  }

  void _showGasPicker(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
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
              padding: EdgeInsets.fromLTRB(
                Responsive.pad(ctx, 20),
                Responsive.pad(ctx, 16),
                Responsive.pad(ctx, 20),
                Responsive.pad(ctx, 12),
              ),
              child: Text(
                'Select Gas / Fluid',
                style: TextStyle(
                  fontSize: Responsive.sp(ctx, 14),
                  fontWeight: FontWeight.w600,
                  color: _C.headerBg,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  Responsive.pad(ctx, 16),
                  0,
                  Responsive.pad(ctx, 16),
                  Responsive.pad(ctx, 12),
                ),
                child: Column(
                  children: _kGases
                      .where((g) => !g.gamma.isNaN)
                      .map(
                        (gas) => GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            onSelect(gas);
                          },
                          child: Container(
                            margin: EdgeInsets.only(bottom: Responsive.hp(ctx, 8)),
                            padding: EdgeInsets.symmetric(
                              horizontal: Responsive.pad(ctx, 14),
                              vertical: Responsive.pad(ctx, 12),
                            ),
                            decoration: BoxDecoration(
                              color: _C.cardBg,
                              border: Border.all(color: _C.cardBorder, width: 1),
                              borderRadius: BorderRadius.circular(Responsive.wp(ctx, 8)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  gas.name,
                                  style: TextStyle(
                                    fontSize: Responsive.sp(ctx, 14),
                                    fontWeight: FontWeight.w500,
                                    color: _C.textPrimary,
                                  ),
                                ),
                                Text(
                                  'γ = ${gas.gamma}',
                                  style: TextStyle(
                                    fontSize: Responsive.sp(ctx, 13),
                                    color: _C.labelMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  HandyCalc Dialog  (identical to other pages)
// ─────────────────────────────────────────────
class _HandyCalcDialog extends StatefulWidget {
  const _HandyCalcDialog({
    required this.title,
    required this.inverseTitle,
    required this.label1,
    required this.label2,
    required this.ratio,
  });
  final String title;
  final String inverseTitle;
  final String label1;
  final String label2;
  final double ratio;

  @override
  State<_HandyCalcDialog> createState() => _HandyCalcDialogState();
}

class _HandyCalcDialogState extends State<_HandyCalcDialog> {
  final _ctrl1 = TextEditingController();
  final _ctrl2 = TextEditingController();
  bool _updating = false;
  String? _error1;
  String? _error2;

  String _fmt(double v) {
    if (v.abs() >= 1e6 || (v.abs() < 1e-4 && v != 0)) {
      return v.toStringAsExponential(5);
    }
    String s = v.toStringAsFixed(6);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      if (s.endsWith('.')) s += '0';
    }
    return s;
  }

  void _onNumeratorChanged(String raw) {
    if (_updating) return;
    final trimmed = raw.trim();
    final val = double.tryParse(trimmed);
    if (val == null) {
      _updating = true;
      _ctrl2.clear();
      _updating = false;
      setState(() => _error1 = trimmed.isEmpty ? null : 'Invalid format');
      return;
    }
    _updating = true;
    _ctrl2.text = _fmt(val / widget.ratio);
    _updating = false;
    setState(() { _error1 = null; _error2 = null; });
  }

  void _onDenominatorChanged(String raw) {
    if (_updating) return;
    final trimmed = raw.trim();
    final val = double.tryParse(trimmed);
    if (val == null) {
      _updating = true;
      _ctrl1.clear();
      _updating = false;
      setState(() => _error2 = trimmed.isEmpty ? null : 'Invalid format');
      return;
    }
    _updating = true;
    _ctrl1.text = _fmt(val * widget.ratio);
    _updating = false;
    setState(() { _error1 = null; _error2 = null; });
  }

  @override
  void dispose() {
    _ctrl1.dispose();
    _ctrl2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _C.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Responsive.wp(context, 12)),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ratioBadge(context, widget.title),
          SizedBox(width: Responsive.wp(context, 8)),
          _ratioBadge(context, widget.inverseTitle),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter either value to compute the other:',
            style: TextStyle(fontSize: Responsive.sp(context, 11), color: _C.labelMedium),
          ),
          SizedBox(height: Responsive.hp(context, 10)),
          _handyRow(context, widget.label1, _ctrl1, _onNumeratorChanged, _error1),
          if (_error1 != null) ...[
            SizedBox(height: Responsive.hp(context, 4)),
            _errorTextWidget(context, _error1!),
          ],
          SizedBox(height: Responsive.hp(context, 8)),
          Row(
            children: [
              SizedBox(width: Responsive.wp(context, 8)),
              Expanded(child: Container(height: 1, color: _C.sectionDiv)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: Responsive.pad(context, 8)),
                child: Text(
                  '÷  ratio',
                  style: TextStyle(fontSize: Responsive.sp(context, 9), color: _C.labelSmall),
                ),
              ),
              Expanded(child: Container(height: 1, color: _C.sectionDiv)),
            ],
          ),
          SizedBox(height: Responsive.hp(context, 8)),
          _handyRow(context, widget.label2, _ctrl2, _onDenominatorChanged, _error2),
          if (_error2 != null) ...[
            SizedBox(height: Responsive.hp(context, 4)),
            _errorTextWidget(context, _error2!),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Done',
            style: TextStyle(color: _C.headerBg, fontSize: Responsive.sp(context, 12)),
          ),
        ),
      ],
    );
  }

  Widget _ratioBadge(BuildContext context, String text) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: Responsive.pad(context, 8),
      vertical: Responsive.pad(context, 4),
    ),
    decoration: BoxDecoration(
      color: _C.headerBg.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(Responsive.wp(context, 6)),
      border: Border.all(color: _C.headerBg.withValues(alpha: 0.4)),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: Responsive.sp(context, 11.5),
        fontWeight: FontWeight.w600,
        color: _C.headerBg,
      ),
    ),
  );

  Widget _errorTextWidget(BuildContext context, String msg) => Row(
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

  Widget _handyRow(
    BuildContext context,
    String label,
    TextEditingController ctrl,
    ValueChanged<String> onChanged,
    String? error,
  ) {
    return Row(
      children: [
        SizedBox(
          width: Responsive.wp(context, 36),
          child: Text(
            label,
            style: TextStyle(
              fontSize: Responsive.sp(context, 12),
              color: _C.fieldLabel,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(width: Responsive.wp(context, 8)),
        Expanded(
          child: Container(
            height: Responsive.hp(context, 38),
            decoration: BoxDecoration(
              color: _C.handyCalcBg,
              borderRadius: BorderRadius.circular(Responsive.wp(context, 8)),
              border: Border.all(color: _C.handyCalcBorder),
            ),
            child: TextField(
              controller: ctrl,
              onChanged: onChanged,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              autocorrect: false,
              enableSuggestions: false,
              style: TextStyle(
                fontSize: Responsive.sp(context, 13),
                color: _C.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: Responsive.pad(context, 10),
                  vertical: Responsive.pad(context, 9),
                ),
                border: InputBorder.none,
                hintText: 'Enter value',
                hintStyle: TextStyle(
                  fontSize: Responsive.sp(context, 12),
                  color: _C.fieldHint,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Reusable Card
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
              Responsive.pad(ctx, 14),
              Responsive.pad(ctx, 10),
              Responsive.pad(ctx, 14),
              Responsive.pad(ctx, 10),
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