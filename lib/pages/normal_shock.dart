import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/dialogs.dart';
import '../utils/responsive.dart';

// ─────────────────────────────────────────────
//  Colour tokens  (same palette as Isentropic page)
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
}

// ─────────────────────────────────────────────
//  Predefined gas data  (same as Isentropic page)
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
enum _NSField { none, m1, m2, t2t1, p2p1, rho2rho1, p02p01, p02p1, delvA1 }

// ─────────────────────────────────────────────
//  Simple arithmetic expression evaluator
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
//  Calculation engine  (pure, no Flutter deps)
//  Reuses isentropic helper functions (tt0, pp0, rr0) exactly as Java did.
// ─────────────────────────────────────────────
class NormalShockEngine {
  // ── Isentropic helpers (reused from Isentropic.java, same as Java source) ──
  static double tt0(double g, double m) =>
      pow(1.0 + 0.5 * (g - 1.0) * m * m, -1.0).toDouble();

  static double pp0(double g, double m) =>
      pow(1.0 + 0.5 * (g - 1.0) * m * m, -g / (g - 1.0)).toDouble();

  static double rr0(double g, double m) =>
      pow(1.0 + 0.5 * (g - 1.0) * m * m, -1.0 / (g - 1.0)).toDouble();

  // ── Core: given M1 and γ compute all NS properties ──────────────────────────
  // Mirrors calculate_ns_prop() in Java exactly.
  static NormalShockResult fromM1(double m1, double gamma) {
    final g = gamma;
    final m2 = sqrt(
      (1.0 + 0.5 * (g - 1.0) * m1 * m1) / (g * m1 * m1 - 0.5 * (g - 1.0)),
    );
    final t2t1 = tt0(g, m2) / tt0(g, m1);
    final p2p1 = 1.0 + 2.0 * g / (g + 1.0) * (m1 * m1 - 1.0);
    final p02p01 = pp0(g, m1) / pp0(g, m2) * p2p1;
    final rho2rho1 = rr0(g, m2) / rr0(g, m1) * p02p01;
    final p02p1 = p02p01 / pp0(g, m1);
    final delvA1 = (2.0 / (g + 1.0)) * (m1 * m1 - 1.0) / m1;

    return NormalShockResult(
      m1: m1,
      m2: m2,
      t2t1: t2t1,
      p2p1: p2p1,
      rho2rho1: rho2rho1,
      p02p01: p02p01,
      p02p1: p02p1,
      delvA1: delvA1,
    );
  }

  // ── Case 2: M2 → M1  (inverse of M2 formula) ─────────────────────────────
  static double m1FromM2(double m2, double gamma) {
    final g = gamma;
    return sqrt(
      (1.0 + 0.5 * (g - 1.0) * m2 * m2) / (g * m2 * m2 - 0.5 * (g - 1.0)),
    );
  }

  // ── Case 3: T2/T1 → M1  (quadratic formula from PDF) ──────────────────────
  static double m1FromT2T1(double t2t1, double gamma) {
    final g = gamma;
    final aa = 2.0 * g * (g - 1.0);
    final bb = 4.0 * g - (g - 1.0) * (g - 1.0) - t2t1 * (g + 1.0) * (g + 1.0);
    final cc = -2.0 * (g - 1.0);
    return sqrt((-bb + sqrt(bb * bb - 4.0 * aa * cc)) / (2.0 * aa));
  }

  // ── Case 4: P2/P1 → M1 ───────────────────────────────────────────────────
  static double m1FromP2P1(double p2p1, double gamma) {
    final g = gamma;
    return sqrt((p2p1 - 1.0) * (g + 1.0) / (2.0 * g) + 1.0);
  }

  // ── Case 5: ρ2/ρ1 → M1 ───────────────────────────────────────────────────
  static double m1FromRho2Rho1(double rho2rho1, double gamma) {
    final g = gamma;
    return sqrt(2.0 * rho2rho1 / (g + 1.0 - rho2rho1 * (g - 1.0)));
  }

  // ── Case 6: P02/P01 → M1  (Newton-Raphson) ───────────────────────────────
  // Mirrors P02_P012M1() in Java exactly.
  static double m1FromP02P01(double p02p01, double gamma) {
    final g = gamma;
    double mnew = 2.0;
    double m1 = 0.0;
    int iter = 0;
    while ((mnew - m1).abs() > 1e-5 && iter < 10000) {
      m1 = mnew;
      final al = (g + 1.0) * m1 * m1 / ((g - 1.0) * m1 * m1 + 2.0);
      final be = (g + 1.0) / (2.0 * g * m1 * m1 - (g - 1.0));
      final daldm1 =
          (2.0 / m1 - 2.0 * m1 * (g - 1.0) / ((g - 1.0) * m1 * m1 + 2.0)) *
          al;
      final dbedm1 = -4.0 * g * m1 * be / (2.0 * g * m1 * m1 - (g - 1.0));
      final fm =
          pow(al, g / (g - 1.0)).toDouble() *
              pow(be, 1.0 / (g - 1.0)).toDouble() -
          p02p01;
      final fdm =
          g /
              (g - 1.0) *
              pow(al, 1.0 / (g - 1.0)).toDouble() *
              daldm1 *
              pow(be, 1.0 / (g - 1.0)).toDouble() +
          pow(al, g / (g - 1.0)).toDouble() /
              (g - 1.0) *
              pow(be, (2.0 - g) / (g - 1.0)).toDouble() *
              dbedm1;
      mnew = m1 - fm / fdm;
      iter++;
    }
    return mnew;
  }

  // ── Case 7: P02/P1 → M1  (Newton-Raphson) ────────────────────────────────
  // Mirrors P02_P12M1() in Java exactly.
  // Note: Java uses 1/v = P01/P02 in its formulation (inverted).
  static double m1FromP02P1(double p02p1, double gamma) {
    final g = gamma;
    final v = 1.0 / p02p1; // Java uses v = 1/P02_P1
    double mnew = 2.0;
    double m1 = 0.0;
    int iter = 0;
    while ((mnew - m1).abs() > 1e-5 && iter < 10000) {
      m1 = mnew;
      final al = (g + 1.0) * m1 * m1 / 2.0;
      final be = (g + 1.0) / (2.0 * g * m1 * m1 - (g - 1.0));
      final daldm1 = m1 * (g + 1.0);
      final dbedm1 = -4.0 * g * m1 * be / (2.0 * g * m1 * m1 - (g - 1.0));
      final fm =
          pow(al, g / (g - 1.0)).toDouble() *
              pow(be, 1.0 / (g - 1.0)).toDouble() -
          1.0 / v;
      final fdm =
          g /
              (g - 1.0) *
              pow(al, 1.0 / (g - 1.0)).toDouble() *
              daldm1 *
              pow(be, 1.0 / (g - 1.0)).toDouble() +
          pow(al, g / (g - 1.0)).toDouble() /
              (g - 1.0) *
              pow(be, (2.0 - g) / (g - 1.0)).toDouble() *
              dbedm1;
      mnew = m1 - fm / fdm;
      iter++;
    }
    return mnew;
  }

  // ── Case 8: ΔV/a1 → M1 ───────────────────────────────────────────────────
  static double m1FromDelvA1(double delvA1, double gamma) {
    final g = gamma;
    final half = delvA1 * (g + 1.0) * 0.5;
    return 0.5 * (half + sqrt(half * half + 4.0));
  }

  // ── Boundary helpers ─────────────────────────────────────────────────────
  static double m2min(double gamma) => sqrt((gamma - 1.0) / (2.0 * gamma));

  static double rho2Rho1max(double gamma) => (gamma + 1.0) / (gamma - 1.0);

  static double p02p1min(double gamma) =>
      pow((gamma + 1.0) / 2.0, gamma / (gamma - 1.0)).toDouble();
}

// ─────────────────────────────────────────────
//  Result model
// ─────────────────────────────────────────────
class NormalShockResult {
  final double m1;
  final double m2;
  final double t2t1;
  final double p2p1;
  final double rho2rho1;
  final double p02p01;
  final double p02p1;
  final double delvA1;

  const NormalShockResult({
    required this.m1,
    required this.m2,
    required this.t2t1,
    required this.p2p1,
    required this.rho2rho1,
    required this.p02p01,
    required this.p02p1,
    required this.delvA1,
  });
}

// ─────────────────────────────────────────────
//  Main Screen Widget
// ─────────────────────────────────────────────
class NormalShockScreen extends StatefulWidget {
  final VoidCallback? onDrawer; 
  const NormalShockScreen({super.key, this.onDrawer});

  @override
  State<NormalShockScreen> createState() => _NormalShockScreenState();
}

class _NormalShockScreenState extends State<NormalShockScreen> {
  // ── Controllers ────────────────────────────────────────────────────────────
  final _gammaCtrl = TextEditingController();
  final _m1Ctrl = TextEditingController();
  final _m2Ctrl = TextEditingController();
  final _t2t1Ctrl = TextEditingController();
  final _p2p1Ctrl = TextEditingController();
  final _rho2rho1Ctrl = TextEditingController();
  final _p02p01Ctrl = TextEditingController();
  final _p02p1Ctrl = TextEditingController();
  final _delvA1Ctrl = TextEditingController();

  // ── Focus nodes ───────────────────────────────────────────────────────────
  final _gammaFocus = FocusNode();
  final _m1Focus = FocusNode();
  final _m2Focus = FocusNode();
  final _t2t1Focus = FocusNode();
  final _p2p1Focus = FocusNode();
  final _rho2rho1Focus = FocusNode();
  final _p02p01Focus = FocusNode();
  final _p02p1Focus = FocusNode();
  final _delvA1Focus = FocusNode();

  // ── State ─────────────────────────────────────────────────────────────────
  double _gamma = 1.4;
  bool _gammaValid = true;
  String? _gammaError;

  _NSField _activeField = _NSField.none;
  NormalShockResult? _result;

  final Map<_NSField, String?> _fieldErrors = {};
  String _selectedGasName = 'Air';
  bool _updating = false;

  // Inverse ratio toggle — flips all ratio labels and values
  bool _inverseRatio = false;

  @override
  void initState() {
    super.initState();
    _gammaCtrl.text = '1.4';

    void onFocusChange(_NSField field, FocusNode node) {
      node.addListener(() {
        if (node.hasFocus && _activeField != field) {
          setState(() => _activeField = field);
        }
      });
    }

    onFocusChange(_NSField.m1, _m1Focus);
    onFocusChange(_NSField.m2, _m2Focus);
    onFocusChange(_NSField.t2t1, _t2t1Focus);
    onFocusChange(_NSField.p2p1, _p2p1Focus);
    onFocusChange(_NSField.rho2rho1, _rho2rho1Focus);
    onFocusChange(_NSField.p02p01, _p02p01Focus);
    onFocusChange(_NSField.p02p1, _p02p1Focus);
    onFocusChange(_NSField.delvA1, _delvA1Focus);
  }

  @override
  void dispose() {
    for (final c in [
      _gammaCtrl,
      _m1Ctrl,
      _m2Ctrl,
      _t2t1Ctrl,
      _p2p1Ctrl,
      _rho2rho1Ctrl,
      _p02p01Ctrl,
      _p02p1Ctrl,
      _delvA1Ctrl,
    ]) {
      c.dispose();
    }
    for (final f in [
      _gammaFocus,
      _m1Focus,
      _m2Focus,
      _t2t1Focus,
      _p2p1Focus,
      _rho2rho1Focus,
      _p02p01Focus,
      _p02p1Focus,
      _delvA1Focus,
    ]) {
      f.dispose();
    }
    super.dispose();
  }

  // ─────────────────────────────────────────────
  //  Gamma change handler
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
    _recalculate();
  }

  // ─────────────────────────────────────────────
  //  Field change handlers
  // ─────────────────────────────────────────────

  void _onM1Changed(String raw) {
    if (_updating) return;
    _activeField = _NSField.m1;
    _clearOtherErrors(_NSField.m1);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _fieldErrors[_NSField.m1] = null;
        _result = null;
      });
      _clearComputedFields(_NSField.m1);
      return;
    }
    final val = _evalExpr(trimmed);
    if (val == null) {
      setState(() {
        _fieldErrors[_NSField.m1] = 'Invalid expression';
        _result = null;
      });
      _clearComputedFields(_NSField.m1);
      return;
    }
    if (val <= 1.0) {
      setState(() {
        _fieldErrors[_NSField.m1] = 'M₁ must be greater than 1';
        _result = null;
      });
      _clearComputedFields(_NSField.m1);
      return;
    }
    if (!_gammaValid) {
      setState(() => _fieldErrors[_NSField.m1] = 'Enter a valid γ first');
      _clearComputedFields(_NSField.m1);
      return;
    }
    setState(() => _fieldErrors[_NSField.m1] = null);
    _computeFromM1(val);
  }

  void _onM2Changed(String raw) {
    if (_updating) return;
    _activeField = _NSField.m2;
    _clearOtherErrors(_NSField.m2);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _fieldErrors[_NSField.m2] = null;
        _result = null;
      });
      _clearComputedFields(_NSField.m2);
      return;
    }
    final val = _evalExpr(trimmed);
    if (val == null) {
      setState(() {
        _fieldErrors[_NSField.m2] = 'Invalid expression';
        _result = null;
      });
      _clearComputedFields(_NSField.m2);
      return;
    }
    final minM2 = NormalShockEngine.m2min(_gamma);
    if (val >= 1.0 || val < minM2) {
      setState(() {
        _fieldErrors[_NSField.m2] =
            'M₂ must be between ${_fmt(minM2)} and 1';
        _result = null;
      });
      _clearComputedFields(_NSField.m2);
      return;
    }
    if (!_gammaValid) {
      setState(() => _fieldErrors[_NSField.m2] = 'Enter a valid γ first');
      _clearComputedFields(_NSField.m2);
      return;
    }
    setState(() => _fieldErrors[_NSField.m2] = null);
    final m1 = NormalShockEngine.m1FromM2(val, _gamma);
    _computeFromM1(m1);
  }

  void _onT2T1Changed(String raw) {
    if (_updating) return;
    _activeField = _NSField.t2t1;
    _clearOtherErrors(_NSField.t2t1);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _fieldErrors[_NSField.t2t1] = null;
        _result = null;
      });
      _clearComputedFields(_NSField.t2t1);
      return;
    }
    final rawVal = _evalExpr(trimmed);
    if (rawVal == null) {
      setState(() {
        _fieldErrors[_NSField.t2t1] = 'Invalid expression';
        _result = null;
      });
      _clearComputedFields(_NSField.t2t1);
      return;
    }
    // If inverse: user entered T₁/T₂, so T₂/T₁ = 1/input
    final val = _inverseRatio ? 1.0 / rawVal : rawVal;
    if (val <= 1.0) {
      setState(() {
        _fieldErrors[_NSField.t2t1] = _inverseRatio
            ? 'T₁/T₂ must be between 0 and 1'
            : 'T₂/T₁ must be greater than 1';
        _result = null;
      });
      _clearComputedFields(_NSField.t2t1);
      return;
    }
    if (!_gammaValid) {
      setState(() => _fieldErrors[_NSField.t2t1] = 'Enter a valid γ first');
      _clearComputedFields(_NSField.t2t1);
      return;
    }
    setState(() => _fieldErrors[_NSField.t2t1] = null);
    final m1 = NormalShockEngine.m1FromT2T1(val, _gamma);
    _computeFromM1(m1);
  }

  void _onP2P1Changed(String raw) {
    if (_updating) return;
    _activeField = _NSField.p2p1;
    _clearOtherErrors(_NSField.p2p1);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _fieldErrors[_NSField.p2p1] = null;
        _result = null;
      });
      _clearComputedFields(_NSField.p2p1);
      return;
    }
    final rawVal = _evalExpr(trimmed);
    if (rawVal == null) {
      setState(() {
        _fieldErrors[_NSField.p2p1] = 'Invalid expression';
        _result = null;
      });
      _clearComputedFields(_NSField.p2p1);
      return;
    }
    final val = _inverseRatio ? 1.0 / rawVal : rawVal;
    if (val <= 1.0) {
      setState(() {
        _fieldErrors[_NSField.p2p1] = _inverseRatio
            ? 'P₁/P₂ must be between 0 and 1'
            : 'P₂/P₁ must be greater than 1';
        _result = null;
      });
      _clearComputedFields(_NSField.p2p1);
      return;
    }
    if (!_gammaValid) {
      setState(() => _fieldErrors[_NSField.p2p1] = 'Enter a valid γ first');
      _clearComputedFields(_NSField.p2p1);
      return;
    }
    setState(() => _fieldErrors[_NSField.p2p1] = null);
    final m1 = NormalShockEngine.m1FromP2P1(val, _gamma);
    _computeFromM1(m1);
  }

  void _onRho2Rho1Changed(String raw) {
    if (_updating) return;
    _activeField = _NSField.rho2rho1;
    _clearOtherErrors(_NSField.rho2rho1);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _fieldErrors[_NSField.rho2rho1] = null;
        _result = null;
      });
      _clearComputedFields(_NSField.rho2rho1);
      return;
    }
    final rawVal = _evalExpr(trimmed);
    if (rawVal == null) {
      setState(() {
        _fieldErrors[_NSField.rho2rho1] = 'Invalid expression';
        _result = null;
      });
      _clearComputedFields(_NSField.rho2rho1);
      return;
    }
    final val = _inverseRatio ? 1.0 / rawVal : rawVal;
    final maxRho = NormalShockEngine.rho2Rho1max(_gamma);
    if (val <= 1.0 || val >= maxRho) {
      setState(() {
        _fieldErrors[_NSField.rho2rho1] = _inverseRatio
            ? 'ρ₁/ρ₂ must be between ${_fmt(1.0/maxRho)} and 1'
            : 'ρ₂/ρ₁ must be between 1 and ${_fmt(maxRho)}';
        _result = null;
      });
      _clearComputedFields(_NSField.rho2rho1);
      return;
    }
    if (!_gammaValid) {
      setState(
        () => _fieldErrors[_NSField.rho2rho1] = 'Enter a valid γ first',
      );
      _clearComputedFields(_NSField.rho2rho1);
      return;
    }
    setState(() => _fieldErrors[_NSField.rho2rho1] = null);
    final m1 = NormalShockEngine.m1FromRho2Rho1(val, _gamma);
    _computeFromM1(m1);
  }

  void _onP02P01Changed(String raw) {
    if (_updating) return;
    _activeField = _NSField.p02p01;
    _clearOtherErrors(_NSField.p02p01);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _fieldErrors[_NSField.p02p01] = null;
        _result = null;
      });
      _clearComputedFields(_NSField.p02p01);
      return;
    }
    final rawVal = _evalExpr(trimmed);
    if (rawVal == null) {
      setState(() {
        _fieldErrors[_NSField.p02p01] = 'Invalid expression';
        _result = null;
      });
      _clearComputedFields(_NSField.p02p01);
      return;
    }
    final val = _inverseRatio ? 1.0 / rawVal : rawVal;
    if (val <= 0.0 || val >= 1.0) {
      setState(() {
        _fieldErrors[_NSField.p02p01] = _inverseRatio
            ? 'P₀₁/P₀₂ must be greater than 1'
            : 'P₀₂/P₀₁ must be between 0 and 1';
        _result = null;
      });
      _clearComputedFields(_NSField.p02p01);
      return;
    }
    if (!_gammaValid) {
      setState(() => _fieldErrors[_NSField.p02p01] = 'Enter a valid γ first');
      _clearComputedFields(_NSField.p02p01);
      return;
    }
    setState(() => _fieldErrors[_NSField.p02p01] = null);
    final m1 = NormalShockEngine.m1FromP02P01(val, _gamma);
    _computeFromM1(m1);
  }

  void _onP02P1Changed(String raw) {
    if (_updating) return;
    _activeField = _NSField.p02p1;
    _clearOtherErrors(_NSField.p02p1);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _fieldErrors[_NSField.p02p1] = null;
        _result = null;
      });
      _clearComputedFields(_NSField.p02p1);
      return;
    }
    final rawVal = _evalExpr(trimmed);
    if (rawVal == null) {
      setState(() {
        _fieldErrors[_NSField.p02p1] = 'Invalid expression';
        _result = null;
      });
      _clearComputedFields(_NSField.p02p1);
      return;
    }
    final val = _inverseRatio ? 1.0 / rawVal : rawVal;
    final minP02p1 = NormalShockEngine.p02p1min(_gamma);
    if (val <= minP02p1) {
      setState(() {
        _fieldErrors[_NSField.p02p1] =
            _inverseRatio
                ? 'P₁/P₀₂ must be between 0 and ${_fmt(1.0/minP02p1)}'
                : 'P₀₂/P₁ must be greater than ${_fmt(minP02p1)}';
        _result = null;
      });
      _clearComputedFields(_NSField.p02p1);
      return;
    }
    if (!_gammaValid) {
      setState(() => _fieldErrors[_NSField.p02p1] = 'Enter a valid γ first');
      _clearComputedFields(_NSField.p02p1);
      return;
    }
    setState(() => _fieldErrors[_NSField.p02p1] = null);
    final m1 = NormalShockEngine.m1FromP02P1(val, _gamma);
    _computeFromM1(m1);
  }

  void _onDelvA1Changed(String raw) {
    if (_updating) return;
    _activeField = _NSField.delvA1;
    _clearOtherErrors(_NSField.delvA1);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _fieldErrors[_NSField.delvA1] = null;
        _result = null;
      });
      _clearComputedFields(_NSField.delvA1);
      return;
    }
    final val = _evalExpr(trimmed);
    if (val == null) {
      setState(() {
        _fieldErrors[_NSField.delvA1] = 'Invalid expression';
        _result = null;
      });
      _clearComputedFields(_NSField.delvA1);
      return;
    }
    if (val <= 0.0) {
      setState(() {
        _fieldErrors[_NSField.delvA1] = 'ΔV/a₁ must be greater than 0';
        _result = null;
      });
      _clearComputedFields(_NSField.delvA1);
      return;
    }
    if (!_gammaValid) {
      setState(() => _fieldErrors[_NSField.delvA1] = 'Enter a valid γ first');
      _clearComputedFields(_NSField.delvA1);
      return;
    }
    setState(() => _fieldErrors[_NSField.delvA1] = null);
    final m1 = NormalShockEngine.m1FromDelvA1(val, _gamma);
    _computeFromM1(m1);
  }

  // ─────────────────────────────────────────────
  //  Core compute dispatcher
  // ─────────────────────────────────────────────
  void _computeFromM1(double m1) {
    final result = NormalShockEngine.fromM1(m1, _gamma);
    setState(() => _result = result);
    _writeComputedFields();
  }

  void _recalculate() {
    if (_activeField == _NSField.none) return;
    switch (_activeField) {
      case _NSField.m1:
        _onM1Changed(_m1Ctrl.text);
      case _NSField.m2:
        _onM2Changed(_m2Ctrl.text);
      case _NSField.t2t1:
        _onT2T1Changed(_t2t1Ctrl.text);
      case _NSField.p2p1:
        _onP2P1Changed(_p2p1Ctrl.text);
      case _NSField.rho2rho1:
        _onRho2Rho1Changed(_rho2rho1Ctrl.text);
      case _NSField.p02p01:
        _onP02P01Changed(_p02p01Ctrl.text);
      case _NSField.p02p1:
        _onP02P1Changed(_p02p1Ctrl.text);
      case _NSField.delvA1:
        _onDelvA1Changed(_delvA1Ctrl.text);
      case _NSField.none:
        break;
    }
  }

  // ─────────────────────────────────────────────
  //  Write computed values to non-active fields
  // ─────────────────────────────────────────────
  void _writeComputedFields() {
    if (_result == null) return;
    _updating = true;

    void setIfNotActive(
      _NSField field,
      TextEditingController ctrl,
      String Function() value,
    ) {
      if (_activeField != field) ctrl.text = value();
    }

    final r = _result!;
    setIfNotActive(_NSField.m1, _m1Ctrl, () => _fmt(r.m1));
    setIfNotActive(_NSField.m2, _m2Ctrl, () => _fmt(r.m2));
    // Ratio fields: display 1/value when inverse mode is on
    setIfNotActive(_NSField.t2t1, _t2t1Ctrl,
        () => _inverseRatio ? _fmt(1.0 / r.t2t1) : _fmt(r.t2t1));
    setIfNotActive(_NSField.p2p1, _p2p1Ctrl,
        () => _inverseRatio ? _fmt(1.0 / r.p2p1) : _fmt(r.p2p1));
    setIfNotActive(_NSField.rho2rho1, _rho2rho1Ctrl,
        () => _inverseRatio ? _fmt(1.0 / r.rho2rho1) : _fmt(r.rho2rho1));
    setIfNotActive(_NSField.p02p01, _p02p01Ctrl,
        () => _inverseRatio ? _fmt(1.0 / r.p02p01) : _fmt(r.p02p01));
    setIfNotActive(_NSField.p02p1, _p02p1Ctrl,
        () => _inverseRatio ? _fmt(1.0 / r.p02p1) : _fmt(r.p02p1));
    setIfNotActive(_NSField.delvA1, _delvA1Ctrl, () => _fmt(r.delvA1));

    _updating = false;
  }

  void _clearComputedFields(_NSField keepField) {
    _updating = true;
    void clearIfNot(_NSField field, TextEditingController ctrl) {
      if (field != keepField) ctrl.clear();
    }

    clearIfNot(_NSField.m1, _m1Ctrl);
    clearIfNot(_NSField.m2, _m2Ctrl);
    clearIfNot(_NSField.t2t1, _t2t1Ctrl);
    clearIfNot(_NSField.p2p1, _p2p1Ctrl);
    clearIfNot(_NSField.rho2rho1, _rho2rho1Ctrl);
    clearIfNot(_NSField.p02p01, _p02p01Ctrl);
    clearIfNot(_NSField.p02p1, _p02p1Ctrl);
    clearIfNot(_NSField.delvA1, _delvA1Ctrl);
    _updating = false;
  }

  void _clearOtherErrors(_NSField keep) {
    for (final f in _NSField.values) {
      if (f != keep) _fieldErrors.remove(f);
    }
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
  //  Reset all
  // ─────────────────────────────────────────────
 /* void _resetAll() {
    setState(() {
      _activeField = _NSField.none;
      _result = null;
      _fieldErrors.clear();
    });
    _updating = true;
    _m1Ctrl.clear();
    _m2Ctrl.clear();
    _t2t1Ctrl.clear();
    _p2p1Ctrl.clear();
    _rho2rho1Ctrl.clear();
    _p02p01Ctrl.clear();
    _p02p1Ctrl.clear();
    _delvA1Ctrl.clear();
    _updating = false;
  } */

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
                    // _buildDescription(),  // moved to info section
                    // SizedBox(height: Responsive.hp(context, 14)),
                    _buildGammaCard(context),
                    SizedBox(height: Responsive.hp(context, 6)),
                    _buildFieldsCard(context),
                    // const SizedBox(height: 12),
                    // _buildNoteCard(),  // moved to info section
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
                onPressed: widget.onDrawer ?? () {}
              ),
              Expanded(
                child: Text(
                  'Normal Shock',
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
            Responsive.pad(context, 5),
            Responsive.pad(context, 14),
            Responsive.pad(context, 5),
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

  // ── Fields card ────────────────────────────────────────────────────────────
  Widget _buildFieldsCard(BuildContext context) {
    
    final r = _result;
    final bool hasResult = r != null;

    // Dynamic labels based on inverse toggle
    final t2t1Sym    = _inverseRatio ? 'T₁/T₂'    : 'T₂/T₁';
    final p2p1Sym    = _inverseRatio ? 'P₁/P₂'    : 'P₂/P₁';
    final rhoSym     = _inverseRatio ? 'ρ₁/ρ₂'    : 'ρ₂/ρ₁';
    final p02p01Sym  = _inverseRatio ? 'P₀₁/P₀₂'  : 'P₀₂/P₀₁';
    final p02p1Sym   = _inverseRatio ? 'P₁/P₀₂'   : 'P₀₂/P₁';

    final t2t1Hint   = _inverseRatio ? 'Between 0 and 1' : 'Greater than 1';
    final p2p1Hint   = _inverseRatio ? 'Between 0 and 1' : 'Greater than 1';
    final rhoHint    = _inverseRatio ? 'Between 1/((γ+1)/(γ−1)) and 1' : 'Between 1 and (γ+1)/(γ−1)';
    final p02p01Hint = _inverseRatio ? 'Greater than 1'  : 'Between 0 and 1';
    final String m2Hint;
    if (_gammaValid) {
      final minM2 = NormalShockEngine.m2min(_gamma);
      m2Hint = 'Between ${_fmt(minM2)} and 1';
    } else {
      m2Hint = 'Between M₂min and 1';
    }
    final String p02p1Hint;
    if (_gammaValid) {
      final minVal = NormalShockEngine.p02p1min(_gamma);
      p02p1Hint = _inverseRatio
          ? 'Between 0 and ${_fmt(1.0 / minVal)}'
          : 'Greater than ${_fmt(minVal)}';
    } else {
      p02p1Hint = _inverseRatio
          ? 'Between 0 and 1/(p02p1min)'
          : 'Greater than p02p1min';
    }

    return _Card(
      context: context,
      header: Row(
        children: [
          Expanded(child: _cardHeader(context, Icons.calculate_outlined, 'SHOCK PROPERTIES')),
          GestureDetector(
            onTap: () {
              setState(() => _inverseRatio = !_inverseRatio);
              _writeComputedFields();
              // Also flip the active field if it is a ratio
              if (_result != null) {
                _updating = true;
                final r = _result!;
                switch (_activeField) {
                  case _NSField.t2t1:
                    _t2t1Ctrl.text = _inverseRatio ? _fmt(1.0 / r.t2t1) : _fmt(r.t2t1);
                  case _NSField.p2p1:
                    _p2p1Ctrl.text = _inverseRatio ? _fmt(1.0 / r.p2p1) : _fmt(r.p2p1);
                  case _NSField.rho2rho1:
                    _rho2rho1Ctrl.text = _inverseRatio ? _fmt(1.0 / r.rho2rho1) : _fmt(r.rho2rho1);
                  case _NSField.p02p01:
                    _p02p01Ctrl.text = _inverseRatio ? _fmt(1.0 / r.p02p01) : _fmt(r.p02p01);
                  case _NSField.p02p1:
                    _p02p1Ctrl.text = _inverseRatio ? _fmt(1.0 / r.p02p1) : _fmt(r.p02p1);
                  default:
                    break;
                }
                _updating = false;
              } else {
                TextEditingController? ctrl;
                void Function(String)? onChanged;
                switch (_activeField) {
                  case _NSField.t2t1: ctrl = _t2t1Ctrl; onChanged = _onT2T1Changed; break;
                  case _NSField.p2p1: ctrl = _p2p1Ctrl; onChanged = _onP2P1Changed; break;
                  case _NSField.rho2rho1: ctrl = _rho2rho1Ctrl; onChanged = _onRho2Rho1Changed; break;
                  case _NSField.p02p01: ctrl = _p02p01Ctrl; onChanged = _onP02P01Changed; break;
                  case _NSField.p02p1: ctrl = _p02p1Ctrl; onChanged = _onP02P1Changed; break;
                  default: break;
                }
                if (ctrl != null && onChanged != null) {
                  final val = _evalExpr(ctrl.text);
                  if (val != null && val != 0) {
                    final invertedText = _fmt(1.0 / val);
                    ctrl.text = invertedText;
                    onChanged(invertedText);
                  }
                }
              }
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
          ),
        ],
      ),
      children: [
        // ── M₁ ─────────────────────────────────────────────────────────────────────────
        _flowField(
          context: context,
          field: _NSField.m1,
          label: 'Mach Number (before shock)',
          symbol: 'M₁',
          controller: _m1Ctrl,
          focusNode: _m1Focus,
          hintText: 'Must be greater than 1',
          onChanged: _onM1Changed,
          error: _fieldErrors[_NSField.m1],
        ),

        _divider(),

        // ── M₂ ─────────────────────────────────────────────────────────────────────────
        _flowField(
          context: context,
          field: _NSField.m2,
          label: 'Mach Number (after shock)',
          symbol: 'M₂',
          controller: _m2Ctrl,
          focusNode: _m2Focus,
          hintText: m2Hint,
          onChanged: _onM2Changed,
          error: _fieldErrors[_NSField.m2],
        ),

        _divider(),

        // ── T₂/T₁ ───────────────────────────────────────────────────────────────────
        _flowField(
          context: context,
          field: _NSField.t2t1,
          label: 'Temperature Ratio',
          symbol: t2t1Sym,
          controller: _t2t1Ctrl,
          focusNode: _t2t1Focus,
          hintText: t2t1Hint,
          onChanged: _onT2T1Changed,
          error: _fieldErrors[_NSField.t2t1],
          onHandyCalc: hasResult
              ? () => _openHandyCalc(
                  title: '$t2t1Sym = ${_t2t1Ctrl.text}',
                  inverseTitle: _inverseRatio
                      ? 'T₂/T₁ = ${_fmt(r!.t2t1)}'
                      : 'T₁/T₂ = ${_fmt(1.0 / r!.t2t1)}',
                  label1: _inverseRatio ? 'T₁ =' : 'T₂ =',
                  label2: _inverseRatio ? 'T₂ =' : 'T₁ =',
                  ratio: _inverseRatio ? 1.0 / r!.t2t1 : r!.t2t1,
                )
              : null,
        ),

        _divider(),

        // ── P₂/P₁ ───────────────────────────────────────────────────────────────────
        _flowField(
          context: context,
          field: _NSField.p2p1,
          label: 'Pressure Ratio',
          symbol: p2p1Sym,
          controller: _p2p1Ctrl,
          focusNode: _p2p1Focus,
          hintText: p2p1Hint,
          onChanged: _onP2P1Changed,
          error: _fieldErrors[_NSField.p2p1],
          onHandyCalc: hasResult
              ? () => _openHandyCalc(
                  title: '$p2p1Sym = ${_p2p1Ctrl.text}',
                  inverseTitle: _inverseRatio
                      ? 'P₂/P₁ = ${_fmt(r!.p2p1)}'
                      : 'P₁/P₂ = ${_fmt(1.0 / r!.p2p1)}',
                  label1: _inverseRatio ? 'P₁ =' : 'P₂ =',
                  label2: _inverseRatio ? 'P₂ =' : 'P₁ =',
                  ratio: _inverseRatio ? 1.0 / r!.p2p1 : r!.p2p1,
                )
              : null,
        ),

        _divider(),

        // ── ρ₂/ρ₁ ───────────────────────────────────────────────────────────
        _flowField(
          context: context,
          field: _NSField.rho2rho1,
          label: 'Density Ratio',
          symbol: rhoSym,
          controller: _rho2rho1Ctrl,
          focusNode: _rho2rho1Focus,
          hintText: rhoHint,
          onChanged: _onRho2Rho1Changed,
          error: _fieldErrors[_NSField.rho2rho1],
          onHandyCalc: hasResult
              ? () => _openHandyCalc(
                  title: '$rhoSym = ${_rho2rho1Ctrl.text}',
                  inverseTitle: _inverseRatio
                      ? 'ρ₂/ρ₁ = ${_fmt(r!.rho2rho1)}'
                      : 'ρ₁/ρ₂ = ${_fmt(1.0 / r!.rho2rho1)}',
                  label1: _inverseRatio ? 'ρ₁ =' : 'ρ₂ =',
                  label2: _inverseRatio ? 'ρ₂ =' : 'ρ₁ =',
                  ratio: _inverseRatio ? 1.0 / r!.rho2rho1 : r!.rho2rho1,
                )
              : null,
        ),

        _divider(),

        // ── P₀₂/P₀₁ ─────────────────────────────────────────────────────────
        _flowField(
          context: context,
          field: _NSField.p02p01,
          label: 'Stagnation Pressure Ratio',
          symbol: p02p01Sym,
          controller: _p02p01Ctrl,
          focusNode: _p02p01Focus,
          hintText: p02p01Hint,
          onChanged: _onP02P01Changed,
          error: _fieldErrors[_NSField.p02p01],
          onHandyCalc: hasResult
              ? () => _openHandyCalc(
                  title: '$p02p01Sym = ${_p02p01Ctrl.text}',
                  inverseTitle: _inverseRatio
                      ? 'P₀₂/P₀₁ = ${_fmt(r!.p02p01)}'
                      : 'P₀₁/P₀₂ = ${_fmt(1.0 / r!.p02p01)}',
                  label1: _inverseRatio ? 'P₀₁ =' : 'P₀₂ =',
                  label2: _inverseRatio ? 'P₀₂ =' : 'P₀₁ =',
                  ratio: _inverseRatio ? 1.0 / r!.p02p01 : r!.p02p01,
                )
              : null,
        ),

        _divider(),

        // ── P₀₂/P₁ (or P₁/P₀₂) ─────────────────────────────────────────────
        _flowField(
          context: context,
          field: _NSField.p02p1,
          label: 'Pitot-to-Static Ratio',
          symbol: p02p1Sym,
          controller: _p02p1Ctrl,
          focusNode: _p02p1Focus,
          hintText: p02p1Hint,
          onChanged: _onP02P1Changed,
          error: _fieldErrors[_NSField.p02p1],
          onHandyCalc: hasResult
              ? () => _openHandyCalc(
                  title: '$p02p1Sym = ${_p02p1Ctrl.text}',
                  inverseTitle: _inverseRatio
                      ? 'P₀₂/P₁ = ${_fmt(r!.p02p1)}'
                      : 'P₁/P₀₂ = ${_fmt(1.0 / r!.p02p1)}',
                  label1: _inverseRatio ? 'P₁ =' : 'P₀₂ =',
                  label2: _inverseRatio ? 'P₀₂ =' : 'P₁ =',
                  ratio: _inverseRatio ? 1.0 / r!.p02p1 : r!.p02p1,
                )
              : null,
        ),

        _divider(),

        // ── ΔV/a₁ ────────────────────────────────────────────────────────────
        _flowField(
          context: context,
          field: _NSField.delvA1,
          label: 'Velocity Change Ratio',
          symbol: 'ΔV/a₁',
          controller: _delvA1Ctrl,
          focusNode: _delvA1Focus,
          hintText: 'Must be greater than 0',
          onChanged: _onDelvA1Changed,
          error: _fieldErrors[_NSField.delvA1],
          isLast: true,
        ),
      ],
    );
  }

  // ── Note card ── (commented out; moved to info section)
  /*
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
              'Subscript \'1\' = state before shock.  Subscript \'2\' = state after shock.\n'
              'Subscript \'0\' = stagnation (total) quantity.\n'
              'ΔV/a₁ = (V₁ − V₂)/a₁, the normalised velocity change across the shock.\n'
              'Tap any ratio label to open HandyCalc for absolute value conversions.',
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
  */

  // ─────────────────────────────────────────────
  //  Reusable sub-builders
  // ─────────────────────────────────────────────

  Widget _cardHeader(BuildContext context, IconData icon, String title) {
    
    return Row(
      children: [
        Container(
          width: Responsive.wp(context, 16),
          height: Responsive.wp(context, 16),
          decoration: const BoxDecoration(
            color: _C.headerBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: Responsive.sp(context, 10)),
        ),
        SizedBox(width: Responsive.wp(context, 6)),
        Text(
          title,
          style: TextStyle(
            fontSize: Responsive.sp(context, 11),
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
    required _NSField field,
    required String label,
    required String symbol,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required ValueChanged<String> onChanged,
    String? error,
    VoidCallback? onHandyCalc,
    Widget? trailing,
    bool isLast = false,
  }) {
    
    final isActive = _activeField == field;
    final isComputed =
        _activeField != _NSField.none && !isActive && _result != null;

    return Padding(
        padding: EdgeInsets.fromLTRB(
          Responsive.pad(context, 12),
          Responsive.pad(context, 4),
          Responsive.pad(context, 12),
          isLast ? Responsive.pad(context, 4) : 0,
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: Responsive.sp(context, 13),
                        fontWeight: FontWeight.w400,
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
              ),
              if (trailing != null) trailing,
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
            onHandyCalc: onHandyCalc,
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
      title: 'About Normal Shock',
      items: const [
        MapEntry('State 1', 'Upstream conditions directly before the shock wave (always supersonic, M₁ > 1).'),
        MapEntry('State 2', 'Downstream conditions directly after the shock wave (always subsonic, M₂ < 1).'),
        MapEntry('Stagnation Pressures', 'Stagnation pressure decreases across the shock (P₀₂ < P₀₁) due to entropy increase.'),
        MapEntry('Stagnation Temperature', 'Stagnation temperature remains constant across the shock (T₀₂ = T₀₁).'),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Gas dropdown button  (identical to Isentropic page)
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
        height: Responsive.hp(ctx, 36),
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
                              border: Border.all(
                                color: _C.cardBorder,
                                width: 1,
                              ),
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
//  HandyCalc Dialog  (identical logic to Isentropic page)
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
    setState(() {
      _error1 = null;
      _error2 = null;
    });
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
    setState(() {
      _error1 = null;
      _error2 = null;
    });
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
            style: TextStyle(
              fontSize: Responsive.sp(context, 11),
              color: _C.labelMedium,
            ),
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
                  style: TextStyle(
                    fontSize: Responsive.sp(context, 9),
                    color: _C.labelSmall,
                  ),
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
            style: TextStyle(
              color: _C.headerBg,
              fontSize: Responsive.sp(context, 12),
            ),
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
      border: Border.all(
        color: _C.headerBg.withValues(alpha: 0.4),
      ),
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
//  Reusable Card  (identical to Isentropic page)
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

// ─────────────────────────────────────────────
//  Entry point (for standalone testing)
//  Remove this main() when integrating as a page.
// ─────────────────────────────────────────────
/*void main() {
  runApp(const _NormalShockApp());
}

class _NormalShockApp extends StatelessWidget {
  const _NormalShockApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Normal Shock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D1F3C)),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const NormalShockScreen(),
    );
  }
} */