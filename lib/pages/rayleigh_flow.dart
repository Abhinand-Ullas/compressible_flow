import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/dialogs.dart';
import '../utils/responsive.dart';

// ─────────────────────────────────────────────
//  Colour tokens (same as other pages)
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
  static const toggleActive = Color(0xFF18397C);
  static const toggleInactive = Color(0xFF9CA3AF);
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
enum _ActiveField { none, mach, tRatio, pRatio, rhoRatio, t0Ratio, p0Ratio, uRatio }

// ─────────────────────────────────────────────
//  Simple arithmetic expression evaluator
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
    if (_pos == start) throw FormatException('expected number');
    return double.parse(_s.substring(start, _pos));
  }
}

// ─────────────────────────────────────────────
//  Calculation Engine — Rayleigh Flow
// ─────────────────────────────────────────────
class RayleighFlowEngine {
  // ── Forward: given M, compute all ratios ─────────────────────────────────
  static RayleighResult fromMach(double M, double gamma) {
    final g = gamma;
    final m = M;

    final tRatio = m * m * (1.0 + g) * (1.0 + g) / pow(1.0 + g * m * m, 2.0);
    final pRatio = (1.0 + g) / (1.0 + g * m * m);
    final rhoRatio = (1.0 + g * m * m) / ((1.0 + g) * m * m);
    final t0Ratio = 2.0 * (1.0 + g) * m * m / pow(1.0 + g * m * m, 2.0) *
        (1.0 + (g - 1.0) / 2.0 * m * m);
    final p0Ratio = (1.0 + g) / (1.0 + g * m * m) *
        pow((1.0 + (g - 1.0) / 2.0 * m * m) / ((g + 1.0) / 2.0), g / (g - 1.0));
    final uRatio = (1.0 + g) * m * m / (1.0 + g * m * m);

    return RayleighResult(
      M: M,
      tRatio: tRatio.toDouble(),
      pRatio: pRatio,
      rhoRatio: rhoRatio,
      t0Ratio: t0Ratio.toDouble(),
      p0Ratio: p0Ratio.toDouble(),
      uRatio: uRatio,
    );
  }

  // ── Limit helpers ─────────────────────────────────────────────────────────
  static double tRatioMax(double g) => pow(1.0 + g, 2.0) / (4.0 * g);
  static double pRatioMax(double g) => (1.0 + g) / 2.0;
  static double rhoRatioMin(double g) => g / (1.0 + g);
  static double t0RatioMinSup(double g) => 1.0 - 1.0 / (g * g);
  static double p0RatioMaxSub(double g) =>
      (g + 1.0) * pow(2.0 / (g + 1.0), g / (g - 1.0));
  static double uRatioMax(double g) => (1.0 + g) / g;

  // ── Inverse: M from T/T* ─────────────────────────────────────────────────
  // T/T* = M²(1+γ)²/(1+γM²)²  → two solutions split at M=1/√γ
  // Using closed-form from Java (quadratic solution from paper):
  static double machFromTRatio(double tRatio, double gamma, {required bool aboveTmax}) {
    final v = tRatio;
    final g = gamma;
    final aa = sqrt(1.0 - 4.0 * v * g - 8.0 * v * g * g - 4.0 * v * pow(g, 3.0) +
        4.0 * g + 6.0 * g * g + 4.0 * pow(g, 3.0) + pow(g, 4.0));
    double M;
    if (aboveTmax) {
      // M > 1/√γ  (supersonic or high-subsonic branch)
      M = sqrt(-2.0 * v * (2.0 * v * g - 1.0 - 2.0 * g - g * g - aa)) / (2.0 * v * g);
    } else {
      // M < 1/√γ  (low-subsonic branch)
      M = sqrt(-2.0 * v * (2.0 * v * g - 1.0 - 2.0 * g - g * g + aa)) / (2.0 * v * g);
    }
    return M.abs();
  }

  // ── Inverse: M from P/P* ─────────────────────────────────────────────────
  // P/P* = (1+γ)/(1+γM²)  → single solution
  static double machFromPRatio(double pRatio, double gamma) {
    final p = pRatio;
    final g = gamma;
    return sqrt(p * g * (1.0 + g - p)) / (p * g);
  }

  // ── Inverse: M from ρ/ρ* ─────────────────────────────────────────────────
  // ρ/ρ* = (1+γM²)/((1+γ)M²) → single solution
  static double machFromRhoRatio(double rhoRatio, double gamma) {
    final r = rhoRatio;
    final g = gamma;
    return sqrt(1.0 / (r + g * r - g));
  }

  // ── Inverse: M from T₀/T₀* ─────────────────────────────────────────────
  // Two solutions; use supersonic flag. Closed-form from Java:
  static double machFromT0Ratio(double t0Ratio, double gamma, {required bool supersonic}) {
    final v = t0Ratio;
    final g = gamma;
    final inner = sqrt(-2.0 * v * g - v * g * g + 1.0 + 2.0 * g + g * g - v);
    double M;
    if (supersonic) {
      M = sqrt(-(v * g * g + 1.0 - g * g) * (v * g - 1.0 - g - inner)) /
          (v * g * g + 1.0 - g * g);
    } else {
      M = sqrt(-(v * g * g + 1.0 - g * g) * (v * g - 1.0 - g + inner)) /
          (v * g * g + 1.0 - g * g);
    }
    return M.abs();
  }

  // ── Inverse: M from P₀/P₀* — bisection (same structure as Java) ──────────
  static double p0RatioFromM(double m, double g) {
    return (1.0 + g) / (1.0 + g * m * m) *
        pow((1.0 + (g - 1.0) / 2.0 * m * m) / ((g + 1.0) / 2.0), g / (g - 1.0));
  }

  static double machFromP0Ratio(double p0Ratio, double gamma, {required bool supersonic}) {
    final g = gamma;
    final v = p0Ratio;
    double xlo = supersonic ? 1.0 : 1e-9;
    double xhi = supersonic ? 100.0 : 1.0;

    if (supersonic) {
      while (p0RatioFromM(xhi, g) < v) {
        xhi *= 2.0;
        if (xhi > 1e6) break;
      }
    }

    double x = 0;
    for (int i = 0; i < 200; i++) {
      x = (xlo + xhi) / 2.0;
      final y = p0RatioFromM(x, g);
      if ((xhi - xlo).abs() < 1e-10) break;
      if (supersonic) {
        if (y > v) xhi = x; else xlo = x;
      } else {
        if (y > v) xlo = x; else xhi = x;
      }
    }
    return x;
  }

  // ── Inverse: M from U/U* ─────────────────────────────────────────────────
  // U/U* = (1+γ)M²/(1+γM²) → single solution
  static double machFromURatio(double uRatio, double gamma) {
    final u = uRatio;
    final g = gamma;
    // Rearranging: (1+γ)M² = u(1+γM²)  => M²[(1+γ)-uγ] = u => M² = u/((1+γ)-uγ)
    final denom = (1.0 + g) - u * g;
    return sqrt(u / denom);
  }
}

// ─────────────────────────────────────────────
//  Result model
// ─────────────────────────────────────────────
class RayleighResult {
  final double M;
  final double tRatio;
  final double pRatio;
  final double rhoRatio;
  final double t0Ratio;
  final double p0Ratio;
  final double uRatio;

  const RayleighResult({
    required this.M,
    required this.tRatio,
    required this.pRatio,
    required this.rhoRatio,
    required this.t0Ratio,
    required this.p0Ratio,
    required this.uRatio,
  });
}

// ─────────────────────────────────────────────
//  Main Screen Widget
// ─────────────────────────────────────────────
class RayleighFlowScreen extends StatefulWidget {
  final VoidCallback? onDrawer;
  const RayleighFlowScreen({super.key, this.onDrawer});

  @override
  State<RayleighFlowScreen> createState() => _RayleighFlowScreenState();
}

class _RayleighFlowScreenState extends State<RayleighFlowScreen> {
  // ── Controllers ────────────────────────────────────────────────────────────
  final _gammaCtrl = TextEditingController();
  final _machCtrl = TextEditingController();
  final _tRatioCtrl = TextEditingController();
  final _pRatioCtrl = TextEditingController();
  final _rhoRatioCtrl = TextEditingController();
  final _t0RatioCtrl = TextEditingController();
  final _p0RatioCtrl = TextEditingController();
  final _uRatioCtrl = TextEditingController();

  // ── Focus nodes ───────────────────────────────────────────────────────────
  final _gammaFocus = FocusNode();
  final _machFocus = FocusNode();
  final _tRatioFocus = FocusNode();
  final _pRatioFocus = FocusNode();
  final _rhoRatioFocus = FocusNode();
  final _t0RatioFocus = FocusNode();
  final _p0RatioFocus = FocusNode();
  final _uRatioFocus = FocusNode();

  // ── State ─────────────────────────────────────────────────────────────────
  double _gamma = 1.4;
  bool _gammaValid = true;
  String? _gammaError;

  _ActiveField _activeField = _ActiveField.none;
  RayleighResult? _result;

  final Map<_ActiveField, String?> _fieldErrors = {};
  String _selectedGasName = 'Air';
  bool _updating = false;

  // T/T* has two branches split at M=1/√γ
  bool _isTAboveTmax = false;
  // T₀/T₀* two branches
  bool _isT0Supersonic = false;
  // P₀/P₀* two branches
  bool _isP0Supersonic = false;

  bool _togglingT = false;
  bool _togglingT0 = false;
  bool _togglingP0 = false;

  bool _inverseRatio = false;

  final _gammaKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _gammaCtrl.text = '1.4';

    void onFocusChange(_ActiveField field, FocusNode node) {
      node.addListener(() {
        if (node.hasFocus && _activeField != field) {
          setState(() => _activeField = field);
        }
      });
    }

    onFocusChange(_ActiveField.mach, _machFocus);
    onFocusChange(_ActiveField.tRatio, _tRatioFocus);
    onFocusChange(_ActiveField.pRatio, _pRatioFocus);
    onFocusChange(_ActiveField.rhoRatio, _rhoRatioFocus);
    onFocusChange(_ActiveField.t0Ratio, _t0RatioFocus);
    onFocusChange(_ActiveField.p0Ratio, _p0RatioFocus);
    onFocusChange(_ActiveField.uRatio, _uRatioFocus);
  }

  @override
  void dispose() {
    for (final c in [
      _gammaCtrl, _machCtrl, _tRatioCtrl, _pRatioCtrl,
      _rhoRatioCtrl, _t0RatioCtrl, _p0RatioCtrl, _uRatioCtrl,
    ]) { c.dispose(); }
    for (final f in [
      _gammaFocus, _machFocus, _tRatioFocus, _pRatioFocus,
      _rhoRatioFocus, _t0RatioFocus, _p0RatioFocus, _uRatioFocus,
    ]) { f.dispose(); }
    super.dispose();
  }

  // ─────────────────────────────────────────────
  //  Gamma change handler
  // ─────────────────────────────────────────────
  void _onGammaChanged(String raw, {bool fromDropdown = false}) {
    if (_updating) return;
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '.') {
      setState(() { _gammaValid = false; _gammaError = 'γ is required'; _result = null; });
      return;
    }
    final val = _evalExpr(trimmed);
    if (val == null) {
      setState(() { _gammaValid = false; _gammaError = 'Invalid expression'; _result = null; });
      return;
    }
    if (val <= 1.0) {
      setState(() { _gammaValid = false; _gammaError = 'γ must be greater than 1'; _result = null; });
      return;
    }
    _gamma = val;
    if (fromDropdown) {
      setState(() {
        _gammaValid = true;
        _gammaError = null;
      });
    } else {
      final match = _kGases.where((g) => !g.gamma.isNaN && (g.gamma - val).abs() < 1e-9).firstOrNull;
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
  void _onMachChanged(String raw) {
    if (_updating) return;
    _activeField = _ActiveField.mach;
    _clearOtherErrors(_ActiveField.mach);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() { _fieldErrors[_ActiveField.mach] = null; _result = null; });
      _clearComputedFields(_ActiveField.mach);
      return;
    }
    final val = _evalExpr(trimmed);
    if (val == null) {
      setState(() { _fieldErrors[_ActiveField.mach] = 'Invalid expression'; _result = null; });
      _clearComputedFields(_ActiveField.mach);
      return;
    }
    if (val <= 0.0) {
      setState(() { _fieldErrors[_ActiveField.mach] = 'Mach number must be > 0'; _result = null; });
      _clearComputedFields(_ActiveField.mach);
      return;
    }
    if (!_gammaValid) {
      setState(() => _fieldErrors[_ActiveField.mach] = 'Enter a valid γ first');
      return;
    }
    setState(() => _fieldErrors[_ActiveField.mach] = null);
    _computeFromMach(val);
  }

  void _onTRatioChanged(String raw) {
    if (_updating) return;
    _activeField = _ActiveField.tRatio;
    _clearOtherErrors(_ActiveField.tRatio);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() { _fieldErrors[_ActiveField.tRatio] = null; _result = null; });
      _clearComputedFields(_ActiveField.tRatio);
      return;
    }
    final rawVal = _evalExpr(trimmed);
    if (rawVal == null) {
      setState(() { _fieldErrors[_ActiveField.tRatio] = 'Invalid expression'; _result = null; });
      _clearComputedFields(_ActiveField.tRatio);
      return;
    }
    final val = _inverseRatio ? 1.0 / rawVal : rawVal;
    final maxT = RayleighFlowEngine.tRatioMax(_gamma);
    if (val <= 0.0 || val >= maxT) {
      setState(() {
        _fieldErrors[_ActiveField.tRatio] = _inverseRatio
            ? 'T*/T must be greater than ${_fmt(1.0 / maxT)}'
            : 'T/T* must be between 0 and ${_fmt(maxT)}';
        _result = null;
      });
      _clearComputedFields(_ActiveField.tRatio);
      return;
    }
    if (!_gammaValid) {
      setState(() => _fieldErrors[_ActiveField.tRatio] = 'Enter a valid γ first');
      return;
    }
    setState(() => _fieldErrors[_ActiveField.tRatio] = null);
    final M = RayleighFlowEngine.machFromTRatio(val, _gamma, aboveTmax: _isTAboveTmax);
    _computeFromMach(M);
  }

  void _onPRatioChanged(String raw) {
    if (_updating) return;
    _activeField = _ActiveField.pRatio;
    _clearOtherErrors(_ActiveField.pRatio);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() { _fieldErrors[_ActiveField.pRatio] = null; _result = null; });
      _clearComputedFields(_ActiveField.pRatio);
      return;
    }
    final rawVal = _evalExpr(trimmed);
    if (rawVal == null) {
      setState(() { _fieldErrors[_ActiveField.pRatio] = 'Invalid expression'; _result = null; });
      _clearComputedFields(_ActiveField.pRatio);
      return;
    }
    final val = _inverseRatio ? 1.0 / rawVal : rawVal;
    final maxP = RayleighFlowEngine.pRatioMax(_gamma);
    if (val <= 0.0 || val >= maxP) {
      setState(() {
        _fieldErrors[_ActiveField.pRatio] = _inverseRatio
            ? 'P*/P must be greater than ${_fmt(1.0 / maxP)}'
            : 'P/P* must be between 0 and ${_fmt(maxP)}';
        _result = null;
      });
      _clearComputedFields(_ActiveField.pRatio);
      return;
    }
    if (!_gammaValid) {
      setState(() => _fieldErrors[_ActiveField.pRatio] = 'Enter a valid γ first');
      return;
    }
    setState(() => _fieldErrors[_ActiveField.pRatio] = null);
    final M = RayleighFlowEngine.machFromPRatio(val, _gamma);
    _computeFromMach(M);
  }

  void _onRhoRatioChanged(String raw) {
    if (_updating) return;
    _activeField = _ActiveField.rhoRatio;
    _clearOtherErrors(_ActiveField.rhoRatio);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() { _fieldErrors[_ActiveField.rhoRatio] = null; _result = null; });
      _clearComputedFields(_ActiveField.rhoRatio);
      return;
    }
    final rawVal = _evalExpr(trimmed);
    if (rawVal == null) {
      setState(() { _fieldErrors[_ActiveField.rhoRatio] = 'Invalid expression'; _result = null; });
      _clearComputedFields(_ActiveField.rhoRatio);
      return;
    }
    final val = _inverseRatio ? 1.0 / rawVal : rawVal;
    final minRho = RayleighFlowEngine.rhoRatioMin(_gamma);
    if (val <= minRho) {
      setState(() {
        _fieldErrors[_ActiveField.rhoRatio] = _inverseRatio
            ? 'ρ*/ρ must be between 0 and ${_fmt(1.0 / minRho)}'
            : 'ρ/ρ* must be greater than ${_fmt(minRho)}';
        _result = null;
      });
      _clearComputedFields(_ActiveField.rhoRatio);
      return;
    }
    if (!_gammaValid) {
      setState(() => _fieldErrors[_ActiveField.rhoRatio] = 'Enter a valid γ first');
      return;
    }
    setState(() => _fieldErrors[_ActiveField.rhoRatio] = null);
    final M = RayleighFlowEngine.machFromRhoRatio(val, _gamma);
    _computeFromMach(M);
  }

  void _onT0RatioChanged(String raw) {
    if (_updating) return;
    _activeField = _ActiveField.t0Ratio;
    _clearOtherErrors(_ActiveField.t0Ratio);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() { _fieldErrors[_ActiveField.t0Ratio] = null; _result = null; });
      _clearComputedFields(_ActiveField.t0Ratio);
      return;
    }
    final rawVal = _evalExpr(trimmed);
    if (rawVal == null) {
      setState(() { _fieldErrors[_ActiveField.t0Ratio] = 'Invalid expression'; _result = null; });
      _clearComputedFields(_ActiveField.t0Ratio);
      return;
    }
    final val = _inverseRatio ? 1.0 / rawVal : rawVal;
    final minSup = RayleighFlowEngine.t0RatioMinSup(_gamma);
    if (val <= 0.0 || val >= 1.0) {
      setState(() {
        _fieldErrors[_ActiveField.t0Ratio] = _inverseRatio
            ? 'T₀*/T₀ must be greater than 1'
            : 'T₀/T₀* must be between 0 and 1';
        _result = null;
      });
      _clearComputedFields(_ActiveField.t0Ratio);
      return;
    }
    if (_isT0Supersonic && val <= minSup) {
      setState(() {
        _fieldErrors[_ActiveField.t0Ratio] = _inverseRatio
            ? 'T₀*/T₀ must be less than ${_fmt(1.0 / minSup)} for supersonic'
            : 'T₀/T₀* must be greater than ${_fmt(minSup)} for supersonic';
        _result = null;
      });
      _clearComputedFields(_ActiveField.t0Ratio);
      return;
    }
    if (!_gammaValid) {
      setState(() => _fieldErrors[_ActiveField.t0Ratio] = 'Enter a valid γ first');
      return;
    }
    setState(() => _fieldErrors[_ActiveField.t0Ratio] = null);
    final M = RayleighFlowEngine.machFromT0Ratio(val, _gamma, supersonic: _isT0Supersonic);
    _computeFromMach(M);
  }

  void _onP0RatioChanged(String raw) {
    if (_updating) return;
    _activeField = _ActiveField.p0Ratio;
    _clearOtherErrors(_ActiveField.p0Ratio);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() { _fieldErrors[_ActiveField.p0Ratio] = null; _result = null; });
      _clearComputedFields(_ActiveField.p0Ratio);
      return;
    }
    final rawVal = _evalExpr(trimmed);
    if (rawVal == null) {
      setState(() { _fieldErrors[_ActiveField.p0Ratio] = 'Invalid expression'; _result = null; });
      _clearComputedFields(_ActiveField.p0Ratio);
      return;
    }
    final val = _inverseRatio ? 1.0 / rawVal : rawVal;
    final maxSub = RayleighFlowEngine.p0RatioMaxSub(_gamma);
    if (_isP0Supersonic) {
      if (val < 1.0) {
        setState(() {
          _fieldErrors[_ActiveField.p0Ratio] = _inverseRatio
              ? 'P₀*/P₀ must be ≤ 1'
              : 'P₀/P₀* must be ≥ 1';
          _result = null;
        });
        _clearComputedFields(_ActiveField.p0Ratio);
        return;
      }
    } else {
      if (val <= 1.0 || val >= maxSub) {
        setState(() {
          _fieldErrors[_ActiveField.p0Ratio] = _inverseRatio
              ? 'P₀*/P₀ must be between ${_fmt(1.0 / maxSub)} and 1'
              : 'P₀/P₀* must be between 1 and ${_fmt(maxSub)}';
          _result = null;
        });
        _clearComputedFields(_ActiveField.p0Ratio);
        return;
      }
    }
    if (!_gammaValid) {
      setState(() => _fieldErrors[_ActiveField.p0Ratio] = 'Enter a valid γ first');
      return;
    }
    setState(() => _fieldErrors[_ActiveField.p0Ratio] = null);
    final M = RayleighFlowEngine.machFromP0Ratio(val, _gamma, supersonic: _isP0Supersonic);
    _computeFromMach(M);
  }

  void _onURatioChanged(String raw) {
    if (_updating) return;
    _activeField = _ActiveField.uRatio;
    _clearOtherErrors(_ActiveField.uRatio);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() { _fieldErrors[_ActiveField.uRatio] = null; _result = null; });
      _clearComputedFields(_ActiveField.uRatio);
      return;
    }
    final rawVal = _evalExpr(trimmed);
    if (rawVal == null) {
      setState(() { _fieldErrors[_ActiveField.uRatio] = 'Invalid expression'; _result = null; });
      _clearComputedFields(_ActiveField.uRatio);
      return;
    }
    final val = _inverseRatio ? 1.0 / rawVal : rawVal;
    final maxU = RayleighFlowEngine.uRatioMax(_gamma);
    if (val <= 0.0 || val >= maxU) {
      setState(() {
        _fieldErrors[_ActiveField.uRatio] = _inverseRatio
            ? 'U*/U must be greater than ${_fmt(1.0 / maxU)}'
            : 'U/U* must be between 0 and ${_fmt(maxU)}';
        _result = null;
      });
      _clearComputedFields(_ActiveField.uRatio);
      return;
    }
    if (!_gammaValid) {
      setState(() => _fieldErrors[_ActiveField.uRatio] = 'Enter a valid γ first');
      return;
    }
    setState(() => _fieldErrors[_ActiveField.uRatio] = null);
    final M = RayleighFlowEngine.machFromURatio(val, _gamma);
    _computeFromMach(M);
  }

  // ─────────────────────────────────────────────
  //  Core compute dispatcher
  // ─────────────────────────────────────────────
  void _computeFromMach(double M) {
    final result = RayleighFlowEngine.fromMach(M, _gamma);
    final mAtTmax = 1.0 / sqrt(_gamma);

    if (!_togglingT) _isTAboveTmax = M > mAtTmax;
    if (!_togglingT0) _isT0Supersonic = M >= 1.0;
    if (!_togglingP0) _isP0Supersonic = M >= 1.0;

    setState(() => _result = result);
    _writeComputedFields();
  }

  void _recalculate() {
    if (_activeField == _ActiveField.none) return;
    switch (_activeField) {
      case _ActiveField.mach: _onMachChanged(_machCtrl.text);
      case _ActiveField.tRatio: _onTRatioChanged(_tRatioCtrl.text);
      case _ActiveField.pRatio: _onPRatioChanged(_pRatioCtrl.text);
      case _ActiveField.rhoRatio: _onRhoRatioChanged(_rhoRatioCtrl.text);
      case _ActiveField.t0Ratio: _onT0RatioChanged(_t0RatioCtrl.text);
      case _ActiveField.p0Ratio: _onP0RatioChanged(_p0RatioCtrl.text);
      case _ActiveField.uRatio: _onURatioChanged(_uRatioCtrl.text);
      case _ActiveField.none: break;
    }
  }

  void _writeComputedFields() {
    if (_result == null) return;
    _updating = true;
    void setIfNotActive(_ActiveField field, TextEditingController ctrl, String Function() value) {
      if (_activeField != field) ctrl.text = value();
    }
    final r = _result!;
    setIfNotActive(_ActiveField.mach, _machCtrl, () => _fmt(r.M));
    setIfNotActive(_ActiveField.tRatio, _tRatioCtrl,
        () => _inverseRatio ? _fmt(1.0 / r.tRatio) : _fmt(r.tRatio));
    setIfNotActive(_ActiveField.pRatio, _pRatioCtrl,
        () => _inverseRatio ? _fmt(1.0 / r.pRatio) : _fmt(r.pRatio));
    setIfNotActive(_ActiveField.rhoRatio, _rhoRatioCtrl,
        () => _inverseRatio ? _fmt(1.0 / r.rhoRatio) : _fmt(r.rhoRatio));
    setIfNotActive(_ActiveField.t0Ratio, _t0RatioCtrl,
        () => _inverseRatio ? _fmt(1.0 / r.t0Ratio) : _fmt(r.t0Ratio));
    setIfNotActive(_ActiveField.p0Ratio, _p0RatioCtrl,
        () => _inverseRatio ? _fmt(1.0 / r.p0Ratio) : _fmt(r.p0Ratio));
    setIfNotActive(_ActiveField.uRatio, _uRatioCtrl,
        () => _inverseRatio ? _fmt(1.0 / r.uRatio) : _fmt(r.uRatio));
    _updating = false;
  }

  void _clearComputedFields(_ActiveField keepField) {
    _updating = true;
    void clearIfNotActive(_ActiveField field, TextEditingController ctrl) {
      if (field != keepField) ctrl.clear();
    }
    clearIfNotActive(_ActiveField.mach, _machCtrl);
    clearIfNotActive(_ActiveField.tRatio, _tRatioCtrl);
    clearIfNotActive(_ActiveField.pRatio, _pRatioCtrl);
    clearIfNotActive(_ActiveField.rhoRatio, _rhoRatioCtrl);
    clearIfNotActive(_ActiveField.t0Ratio, _t0RatioCtrl);
    clearIfNotActive(_ActiveField.p0Ratio, _p0RatioCtrl);
    clearIfNotActive(_ActiveField.uRatio, _uRatioCtrl);
    _updating = false;
  }

  void _clearOtherErrors(_ActiveField keep) {
    for (final f in _ActiveField.values) {
      if (f != keep) _fieldErrors.remove(f);
    }
  }

  // ─────────────────────────────────────────────
  //  Toggle handlers
  // ─────────────────────────────────────────────
  void _onToggleTAboveTmax(bool val) {
    if (_result == null && _tRatioCtrl.text.trim().isEmpty) { setState(() => _isTAboveTmax = val); return; }
    _togglingT = true;
    setState(() { _isTAboveTmax = val; _activeField = _ActiveField.tRatio; });
    _onTRatioChanged(_tRatioCtrl.text);
    _togglingT = false;
  }

  void _onToggleT0Supersonic(bool val) {
    if (_result == null && _t0RatioCtrl.text.trim().isEmpty) { setState(() => _isT0Supersonic = val); return; }
    _togglingT0 = true;
    setState(() { _isT0Supersonic = val; _activeField = _ActiveField.t0Ratio; });
    _onT0RatioChanged(_t0RatioCtrl.text);
    _togglingT0 = false;
  }

  void _onToggleP0Supersonic(bool val) {
    if (_result == null && _p0RatioCtrl.text.trim().isEmpty) { setState(() => _isP0Supersonic = val); return; }
    _togglingP0 = true;
    setState(() { _isP0Supersonic = val; _activeField = _ActiveField.p0Ratio; });
    _onP0RatioChanged(_p0RatioCtrl.text);
    _togglingP0 = false;
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
      if (s.endsWith('.')) s = '${s}0';
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
                  _buildGammaCard(context),
                  SizedBox(height: Responsive.hp(context, 6)),
                  _buildFieldsCard(context),
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
                  'Rayleigh Flow',
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
                icon: Icon(Icons.tips_and_updates_outlined, color: Colors.yellow, size: Responsive.sp(context, 22)),
                onPressed: () => _showFeaturesDialog(context),
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
                      key: _gammaKey,
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

  // ── Fields card ───────────────────────────────────────────────────────────
  Widget _buildFieldsCard(BuildContext context) {
    final r = _result;
    final bool hasResult = r != null;

    final tSym = _inverseRatio ? 'T*/T' : 'T/T*';
    final pSym = _inverseRatio ? 'P*/P' : 'P/P*';
    final rhoSym = _inverseRatio ? 'ρ*/ρ' : 'ρ/ρ*';
    final t0Sym = _inverseRatio ? 'T₀*/T₀' : 'T₀/T₀*';
    final p0Sym = _inverseRatio ? 'P₀*/P₀' : 'P₀/P₀*';
    final uSym = _inverseRatio ? 'U*/U' : 'U/U*';

    final maxT = RayleighFlowEngine.tRatioMax(_gamma);
    final maxP = RayleighFlowEngine.pRatioMax(_gamma);
    final minRho = RayleighFlowEngine.rhoRatioMin(_gamma);
    final maxU = RayleighFlowEngine.uRatioMax(_gamma);

    final tHint = _inverseRatio ? 'Greater than ${_fmt(1.0 / maxT)}' : 'Between 0 and ${_fmt(maxT)}';
    final pHint = _inverseRatio ? 'Greater than ${_fmt(1.0 / maxP)}' : 'Between 0 and ${_fmt(maxP)}';
    final rhoHint = _inverseRatio ? 'Between 0 and ${_fmt(1.0 / minRho)}' : 'Greater than ${_fmt(minRho)}';
    final t0Hint = _inverseRatio ? 'Greater than 1' : 'Between 0 and 1';
    final p0Hint = _isP0Supersonic
        ? (_inverseRatio ? '≤ 1' : '≥ 1')
        : (_inverseRatio ? 'Between 0 and 1' : 'Greater than 1');
    final uHint = _inverseRatio ? 'Greater than ${_fmt(1.0 / maxU)}' : 'Between 0 and ${_fmt(maxU)}';

    return _Card(
      context: context,
      header: Row(
        children: [
          Expanded(child: _cardHeader(context, Icons.calculate_outlined, 'FLOW PROPERTIES')),
          GestureDetector(
            onTap: () {
              setState(() => _inverseRatio = !_inverseRatio);
              _writeComputedFields();
              if (_result != null) {
                _updating = true;
                final r2 = _result!;
                switch (_activeField) {
                  case _ActiveField.tRatio:
                    _tRatioCtrl.text = _inverseRatio ? _fmt(1.0 / r2.tRatio) : _fmt(r2.tRatio);
                  case _ActiveField.pRatio:
                    _pRatioCtrl.text = _inverseRatio ? _fmt(1.0 / r2.pRatio) : _fmt(r2.pRatio);
                  case _ActiveField.rhoRatio:
                    _rhoRatioCtrl.text = _inverseRatio ? _fmt(1.0 / r2.rhoRatio) : _fmt(r2.rhoRatio);
                  case _ActiveField.t0Ratio:
                    _t0RatioCtrl.text = _inverseRatio ? _fmt(1.0 / r2.t0Ratio) : _fmt(r2.t0Ratio);
                  case _ActiveField.p0Ratio:
                    _p0RatioCtrl.text = _inverseRatio ? _fmt(1.0 / r2.p0Ratio) : _fmt(r2.p0Ratio);
                  case _ActiveField.uRatio:
                    _uRatioCtrl.text = _inverseRatio ? _fmt(1.0 / r2.uRatio) : _fmt(r2.uRatio);
                  default:
                    break;
                }
                _updating = false;
              } else {
                TextEditingController? ctrl;
                void Function(String)? onChanged;
                switch (_activeField) {
                  case _ActiveField.tRatio: ctrl = _tRatioCtrl; onChanged = _onTRatioChanged;
                  case _ActiveField.pRatio: ctrl = _pRatioCtrl; onChanged = _onPRatioChanged;
                  case _ActiveField.rhoRatio: ctrl = _rhoRatioCtrl; onChanged = _onRhoRatioChanged;
                  case _ActiveField.t0Ratio: ctrl = _t0RatioCtrl; onChanged = _onT0RatioChanged;
                  case _ActiveField.p0Ratio: ctrl = _p0RatioCtrl; onChanged = _onP0RatioChanged;
                  case _ActiveField.uRatio: ctrl = _uRatioCtrl; onChanged = _onURatioChanged;
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
                color: _inverseRatio ? _C.toggleActive : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(Responsive.wp(context, 6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_horiz, size: Responsive.sp(context, 14),
                      color: _inverseRatio ? Colors.white : _C.labelMedium),
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
        // ── Mach number ──────────────────────────────────────────────────────
        _flowField(
          context: context,
          field: _ActiveField.mach,
          label: 'Mach Number',
          symbol: 'M',
          controller: _machCtrl,
          focusNode: _machFocus,
          hintText: 'Must be greater than 0',
          onChanged: _onMachChanged,
          error: _fieldErrors[_ActiveField.mach],
        ),

        _divider(),

        // ── T/T* ─────────────────────────────────────────────────────────────
        _flowField(
          context: context,
          field: _ActiveField.tRatio,
          label: 'Temperature Ratio',
          symbol: tSym,
          controller: _tRatioCtrl,
          focusNode: _tRatioFocus,
          hintText: tHint,
          onChanged: _onTRatioChanged,
          error: _fieldErrors[_ActiveField.tRatio],
          onHandyCalc: hasResult
              ? () => _openHandyCalc(
                    title: '$tSym = ${_tRatioCtrl.text}',
                    inverseTitle: _inverseRatio ? 'T/T* = ${_fmt(r.tRatio)}' : 'T*/T = ${_fmt(1.0 / r.tRatio)}',
                    label1: _inverseRatio ? 'T* =' : 'T  =',
                    label2: _inverseRatio ? 'T  =' : 'T* =',
                    ratio: _inverseRatio ? 1.0 / r.tRatio : r.tRatio,
                  )
              : null,
          trailing: _SupersonicToggle(
            context: context,
            isSupersonic: _isTAboveTmax,
            labelSub: 'M<1/√γ',
            labelSup: 'M>1/√γ',
            onChanged: _onToggleTAboveTmax,
          ),
        ),

        _divider(),

        // ── P/P* ─────────────────────────────────────────────────────────────
        _flowField(
          context: context,
          field: _ActiveField.pRatio,
          label: 'Pressure Ratio',
          symbol: pSym,
          controller: _pRatioCtrl,
          focusNode: _pRatioFocus,
          hintText: pHint,
          onChanged: _onPRatioChanged,
          error: _fieldErrors[_ActiveField.pRatio],
          onHandyCalc: hasResult
              ? () => _openHandyCalc(
                    title: '$pSym = ${_pRatioCtrl.text}',
                    inverseTitle: _inverseRatio ? 'P/P* = ${_fmt(r.pRatio)}' : 'P*/P = ${_fmt(1.0 / r.pRatio)}',
                    label1: _inverseRatio ? 'P* =' : 'P  =',
                    label2: _inverseRatio ? 'P  =' : 'P* =',
                    ratio: _inverseRatio ? 1.0 / r.pRatio : r.pRatio,
                  )
              : null,
        ),

        _divider(),

        // ── ρ/ρ* ─────────────────────────────────────────────────────────────
        _flowField(
          context: context,
          field: _ActiveField.rhoRatio,
          label: 'Density Ratio',
          symbol: rhoSym,
          controller: _rhoRatioCtrl,
          focusNode: _rhoRatioFocus,
          hintText: rhoHint,
          onChanged: _onRhoRatioChanged,
          error: _fieldErrors[_ActiveField.rhoRatio],
          onHandyCalc: hasResult
              ? () => _openHandyCalc(
                    title: '$rhoSym = ${_rhoRatioCtrl.text}',
                    inverseTitle: _inverseRatio ? 'ρ/ρ* = ${_fmt(r.rhoRatio)}' : 'ρ*/ρ = ${_fmt(1.0 / r.rhoRatio)}',
                    label1: _inverseRatio ? 'ρ* =' : 'ρ  =',
                    label2: _inverseRatio ? 'ρ  =' : 'ρ* =',
                    ratio: _inverseRatio ? 1.0 / r.rhoRatio : r.rhoRatio,
                  )
              : null,
        ),

        _divider(),

        // ── T₀/T₀* ───────────────────────────────────────────────────────────
        _flowField(
          context: context,
          field: _ActiveField.t0Ratio,
          label: 'Stagnation Temperature Ratio',
          symbol: t0Sym,
          controller: _t0RatioCtrl,
          focusNode: _t0RatioFocus,
          hintText: t0Hint,
          onChanged: _onT0RatioChanged,
          error: _fieldErrors[_ActiveField.t0Ratio],
          onHandyCalc: hasResult
              ? () => _openHandyCalc(
                    title: '$t0Sym = ${_t0RatioCtrl.text}',
                    inverseTitle: _inverseRatio ? 'T₀/T₀* = ${_fmt(r.t0Ratio)}' : 'T₀*/T₀ = ${_fmt(1.0 / r.t0Ratio)}',
                    label1: _inverseRatio ? 'T₀* =' : 'T₀  =',
                    label2: _inverseRatio ? 'T₀  =' : 'T₀* =',
                    ratio: _inverseRatio ? 1.0 / r.t0Ratio : r.t0Ratio,
                  )
              : null,
          trailing: _SupersonicToggle(
            context: context,
            isSupersonic: _isT0Supersonic,
            onChanged: _onToggleT0Supersonic,
          ),
        ),

        _divider(),

        // ── P₀/P₀* ───────────────────────────────────────────────────────────
        _flowField(
          context: context,
          field: _ActiveField.p0Ratio,
          label: 'Stagnation Pressure Ratio',
          symbol: p0Sym,
          controller: _p0RatioCtrl,
          focusNode: _p0RatioFocus,
          hintText: p0Hint,
          onChanged: _onP0RatioChanged,
          error: _fieldErrors[_ActiveField.p0Ratio],
          onHandyCalc: hasResult
              ? () => _openHandyCalc(
                    title: '$p0Sym = ${_p0RatioCtrl.text}',
                    inverseTitle: _inverseRatio ? 'P₀/P₀* = ${_fmt(r.p0Ratio)}' : 'P₀*/P₀ = ${_fmt(1.0 / r.p0Ratio)}',
                    label1: _inverseRatio ? 'P₀* =' : 'P₀  =',
                    label2: _inverseRatio ? 'P₀  =' : 'P₀* =',
                    ratio: _inverseRatio ? 1.0 / r.p0Ratio : r.p0Ratio,
                  )
              : null,
          trailing: _SupersonicToggle(
            context: context,
            isSupersonic: _isP0Supersonic,
            onChanged: _onToggleP0Supersonic,
          ),
        ),

        _divider(),

        // ── U/U* ─────────────────────────────────────────────────────────────
        _flowField(
          context: context,
          field: _ActiveField.uRatio,
          label: 'Velocity Ratio',
          symbol: uSym,
          controller: _uRatioCtrl,
          focusNode: _uRatioFocus,
          hintText: uHint,
          onChanged: _onURatioChanged,
          error: _fieldErrors[_ActiveField.uRatio],
          isLast: true,
          onHandyCalc: hasResult
              ? () => _openHandyCalc(
                    title: '$uSym = ${_uRatioCtrl.text}',
                    inverseTitle: _inverseRatio ? 'U/U* = ${_fmt(r.uRatio)}' : 'U*/U = ${_fmt(1.0 / r.uRatio)}',
                    label1: _inverseRatio ? 'U* =' : 'U  =',
                    label2: _inverseRatio ? 'U  =' : 'U* =',
                    ratio: _inverseRatio ? 1.0 / r.uRatio : r.uRatio,
                  )
              : null,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  Reusable sub-builders (identical to fanno)
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

  Widget _flowField({
    required BuildContext context,
    required _ActiveField field,
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
    final isComputed = _activeField != _ActiveField.none && !isActive && _result != null;

    return Opacity(
      opacity: 1.0,
      child: Padding(
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
                ),
                if (trailing != null) trailing,
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
              onHandyCalc: onHandyCalc,
            ),
            if (error != null) ...[
              SizedBox(height: Responsive.hp(context, 4)),
              _errorText(context, error),
            ],
          ],
        ),
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
              child: Icon(Icons.compare_arrows_rounded, size: Responsive.sp(context, 18), color: _C.headerBg),
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
          child: Text(msg, style: TextStyle(fontSize: Responsive.sp(context, 11), color: _C.errorText)),
        ),
      ],
    );
  }

  void _showFeaturesDialog(BuildContext context) {
    showAppFeaturesDialog(context);
  }

  void _showInfoDialog(BuildContext context) {
    showTopicInfoDialog(
      context,
      title: 'About Rayleigh Flow',
      items: [
        const MapEntry('Sonic Reference State', "Superscript '*' refers to the thermal sonic state where local Mach number = 1.0."),
        const MapEntry('Stagnation Reference State', "Subscript '0' refers to the local stagnation or total state condition."),
        const MapEntry('Core Assumptions', 'Assumes steady, one-dimensional flow with heat transfer in a constant area duct (no friction, no work).'),
        const MapEntry('Temperature Ratio Branch', 'For T/T*, two Mach numbers exist for each value below the maximum. The toggle switches between M < 1/√γ and M > 1/√γ branches.'),
        const MapEntry('Stagnation Temperature Limit', 'T₀/T₀* is bounded between 0 and 1. For supersonic flow, there is a non-zero lower limit of (1 − 1/γ²).'),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Subsonic / Supersonic toggle widget
// ─────────────────────────────────────────────
class _SupersonicToggle extends StatelessWidget {
  const _SupersonicToggle({
    required this.context,
    required this.isSupersonic,
    required this.onChanged,
    this.labelSub = 'Sub',
    this.labelSup = 'Sup',
  });

  final BuildContext context;
  final bool isSupersonic;
  final ValueChanged<bool> onChanged;
  final String labelSub;
  final String labelSup;

  @override
  Widget build(BuildContext ctx) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _label(ctx, labelSub, !isSupersonic),
        SizedBox(width: Responsive.wp(ctx, 4)),
        GestureDetector(
          onTap: () => onChanged(!isSupersonic),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: Responsive.wp(ctx, 40),
            height: Responsive.hp(ctx, 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Responsive.wp(ctx, 11)),
              color: isSupersonic ? _C.toggleActive : _C.toggleInactive,
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: isSupersonic ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: EdgeInsets.all(Responsive.wp(ctx, 2)),
                width: Responsive.wp(ctx, 18),
                height: Responsive.wp(ctx, 18),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
              ),
            ),
          ),
        ),
        SizedBox(width: Responsive.wp(ctx, 4)),
        _label(ctx, labelSup, isSupersonic),
      ],
    );
  }

  Widget _label(BuildContext ctx, String text, bool active) => Text(
        text,
        style: TextStyle(
          fontSize: Responsive.sp(ctx, 10),
          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          color: active ? _C.toggleActive : _C.toggleInactive,
        ),
      );
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
              style: TextStyle(color: Colors.white, fontSize: Responsive.sp(ctx, 13), fontWeight: FontWeight.w500),
            ),
            SizedBox(width: Responsive.wp(ctx, 4)),
            Icon(Icons.keyboard_arrow_down, color: Colors.white, size: Responsive.sp(ctx, 16)),
          ],
        ),
      ),
    );
  }

  void _showGasPicker(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: _C.pageBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                Responsive.pad(ctx, 20), Responsive.pad(ctx, 16),
                Responsive.pad(ctx, 20), Responsive.pad(ctx, 12),
              ),
              child: Text(
                'Select Gas / Fluid',
                style: TextStyle(fontSize: Responsive.sp(ctx, 14), fontWeight: FontWeight.w600, color: _C.headerBg),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  Responsive.pad(ctx, 16), 0,
                  Responsive.pad(ctx, 16), Responsive.pad(ctx, 12),
                ),
                child: Column(
                  children: _kGases.where((g) => !g.gamma.isNaN).map((gas) => GestureDetector(
                    onTap: () { Navigator.pop(ctx); onSelect(gas); },
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
                          Text(gas.name, style: TextStyle(fontSize: Responsive.sp(ctx, 14), fontWeight: FontWeight.w500, color: _C.textPrimary)),
                          Text('γ = ${gas.gamma}', style: TextStyle(fontSize: Responsive.sp(ctx, 13), color: _C.labelMedium)),
                        ],
                      ),
                    ),
                  )).toList(),
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
//  HandyCalc Dialog
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
    if (v.abs() >= 1e6 || (v.abs() < 1e-4 && v != 0)) return v.toStringAsExponential(5);
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
      _updating = true; _ctrl2.clear(); _updating = false;
      setState(() => _error1 = trimmed.isEmpty ? null : 'Invalid format');
      return;
    }
    _updating = true; _ctrl2.text = _fmt(val / widget.ratio); _updating = false;
    setState(() { _error1 = null; _error2 = null; });
  }

  void _onDenominatorChanged(String raw) {
    if (_updating) return;
    final trimmed = raw.trim();
    final val = double.tryParse(trimmed);
    if (val == null) {
      _updating = true; _ctrl1.clear(); _updating = false;
      setState(() => _error2 = trimmed.isEmpty ? null : 'Invalid format');
      return;
    }
    _updating = true; _ctrl1.text = _fmt(val * widget.ratio); _updating = false;
    setState(() { _error1 = null; _error2 = null; });
  }

  @override
  void dispose() { _ctrl1.dispose(); _ctrl2.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _C.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.wp(context, 12))),
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
          Text('Enter either value to compute the other:',
              style: TextStyle(fontSize: Responsive.sp(context, 11), color: _C.labelMedium)),
          SizedBox(height: Responsive.hp(context, 10)),
          _handyRow(context, widget.label1, _ctrl1, _onNumeratorChanged, _error1),
          if (_error1 != null) ...[
            SizedBox(height: Responsive.hp(context, 4)),
            _errorText(context, _error1!),
          ],
          SizedBox(height: Responsive.hp(context, 8)),
          Row(children: [
            SizedBox(width: Responsive.wp(context, 8)),
            Expanded(child: Container(height: 1, color: _C.sectionDiv)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Responsive.pad(context, 8)),
              child: Text('÷  ratio', style: TextStyle(fontSize: Responsive.sp(context, 9), color: _C.labelSmall)),
            ),
            Expanded(child: Container(height: 1, color: _C.sectionDiv)),
          ]),
          SizedBox(height: Responsive.hp(context, 8)),
          _handyRow(context, widget.label2, _ctrl2, _onDenominatorChanged, _error2),
          if (_error2 != null) ...[
            SizedBox(height: Responsive.hp(context, 4)),
            _errorText(context, _error2!),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Done', style: TextStyle(color: _C.headerBg, fontSize: Responsive.sp(context, 12))),
        ),
      ],
    );
  }

  Widget _ratioBadge(BuildContext context, String text) => Container(
        padding: EdgeInsets.symmetric(horizontal: Responsive.pad(context, 8), vertical: Responsive.pad(context, 4)),
        decoration: BoxDecoration(
          color: _C.headerBg.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(Responsive.wp(context, 6)),
          border: Border.all(color: _C.headerBg.withValues(alpha: 0.4)),
        ),
        child: Text(text, style: TextStyle(fontSize: Responsive.sp(context, 11.5), fontWeight: FontWeight.w600, color: _C.headerBg)),
      );

  Widget _errorText(BuildContext context, String msg) => Row(
        children: [
          Icon(Icons.error_outline, size: Responsive.sp(context, 13), color: _C.errorText),
          SizedBox(width: Responsive.wp(context, 4)),
          Expanded(child: Text(msg, style: TextStyle(fontSize: Responsive.sp(context, 11), color: _C.errorText))),
        ],
      );

  Widget _handyRow(BuildContext context, String label, TextEditingController ctrl,
      ValueChanged<String> onChanged, String? error) {
    return Row(
      children: [
        SizedBox(
          width: Responsive.wp(context, 36),
          child: Text(label, style: TextStyle(fontSize: Responsive.sp(context, 12), color: _C.fieldLabel, fontWeight: FontWeight.w500)),
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
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              style: TextStyle(fontSize: Responsive.sp(context, 13), color: _C.textPrimary, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: Responsive.pad(context, 10),
                  vertical: Responsive.pad(context, 9),
                ),
                border: InputBorder.none,
                hintText: 'Enter value',
                hintStyle: TextStyle(fontSize: Responsive.sp(context, 12), color: _C.fieldHint, fontWeight: FontWeight.w400),
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
  const _Card({required this.context, required this.header, required this.children});
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
              Responsive.pad(ctx, 12), Responsive.pad(ctx, 6),
              Responsive.pad(ctx, 12), Responsive.pad(ctx, 6),
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