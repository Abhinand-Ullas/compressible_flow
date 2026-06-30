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
  static const sectionLabel = Color(0xFF18397C);
  static const outputValue = Color(0xFF0D1F3C);
  static const errorText = Color(0xFFDC2626);
  static const inputActiveBg = Color(0xFFF0F4FF);
  static const outputReadonlyBg = Color(0xFFF0F4FF);
  static const outputReadonlyBorder = Color(0xFFC7D4E6);
  static const noteCardBg = Color(0xFFEEF2F8);
  static const noteCardBorder = Color(0xFFC7D4E6);
  static const noteIcon = Color(0xFF0D1F3C);
  static const noteText = Color(0xFF4B6082);
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
//  Active field (mirrors oblique page's _OSField pattern)
// ─────────────────────────────────────────────
enum _CSField { none, thetaS, thetaC, mc }

// ─────────────────────────────────────────────
//  Simple arithmetic expression evaluator (same as oblique page)
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
//  Calculation engine  (mirrors the reference conical_shock.ipynb)
// ─────────────────────────────────────────────

/// Raw output of the oblique-shock relation used to seed Taylor-Maccoll.
class _ObliqueRaw {
  final double delta, m2, p2p1, rho2rho1, t2t1;
  const _ObliqueRaw(this.delta, this.m2, this.p2p1, this.rho2rho1, this.t2t1);
}

/// Full set of metrics for one attached conical-shock solution.
class ConicalResult {
  final double thetaS;   // shock wave angle (rad) actually used
  final double thetaC;   // cone half-angle (rad)
  final double mc;       // Mach number at cone surface
  final double delta;    // flow deflection / shock turn angle (rad)
  final double m2;       // Mach immediately behind shock
  final double p2p1, rho2rho1, t2t1;
  final double vrC, vtC; // V'/Vmax components at cone surface
  final double po2po1, tcT1, pcP1, rhocRho1, cp, dsR, vTotalPrime;

  const ConicalResult({
    required this.thetaS,
    required this.thetaC,
    required this.mc,
    required this.delta,
    required this.m2,
    required this.p2p1,
    required this.rho2rho1,
    required this.t2t1,
    required this.vrC,
    required this.vtC,
    required this.po2po1,
    required this.tcT1,
    required this.pcP1,
    required this.rhocRho1,
    required this.cp,
    required this.dsR,
    required this.vTotalPrime,
  });
}

class _ConeRawMetrics {
  final double thetaC, mc, delta, m2, p2p1, rho2rho1, t2t1, vrC, vtC;
  const _ConeRawMetrics(this.thetaC, this.mc, this.delta, this.m2, this.p2p1,
      this.rho2rho1, this.t2t1, this.vrC, this.vtC);
}

class ConicalShockEngine {
  // ── Exact oblique-shock relations ──────────────────────────────────────
  static _ObliqueRaw obliqueShock(double m1, double thetaS, double gamma) {
    final sinTs = sin(thetaS);
    final cos2ts = cos(2 * thetaS);

    final delta = atan(
      2 / tan(thetaS) *
          (m1 * m1 * sinTs * sinTs - 1) /
          (m1 * m1 * (gamma + cos2ts) + 2),
    );

    final num = (gamma - 1) / 2 * m1 * m1 * sinTs * sinTs + 1;
    final den = gamma * m1 * m1 * sinTs * sinTs - (gamma - 1) / 2;
    final m2 = 1 / sin(thetaS - delta) * sqrt(num / den);

    final p2p1 = (2 * gamma * m1 * m1 * sinTs * sinTs - (gamma - 1)) / (gamma + 1);
    final rho2rho1 = ((gamma + 1) * m1 * m1 * sinTs * sinTs) /
        ((gamma - 1) * m1 * m1 * sinTs * sinTs + 2);
    final t2t1 = p2p1 / rho2rho1;

    return _ObliqueRaw(delta, m2, p2p1, rho2rho1, t2t1);
  }

  // ── Taylor-Maccoll ODE (V' = V/Vmax) ──────────────────────────────────
  static List<double> _tm(double theta, List<double> w, double gamma) {
    final vr = w[0], vt = w[1];
    if (tan(theta).abs() < 1e-15 || (1 - vr * vr - vt * vt) <= 0) {
      return [0.0, 0.0];
    }
    final n = vr * vt * vt -
        (gamma - 1) * (1 - vr * vr - vt * vt) * (2 * vr + vt / tan(theta)) / 2;
    final d = (gamma - 1) * (1 - vr * vr - vt * vt) / 2 - vt * vt;
    if (d.abs() < 1e-15) return [0.0, 0.0];
    return [vt, n / d];
  }

  static List<double> _rk4Step(double theta, List<double> w, double h, double gamma) {
    final k1 = _tm(theta, w, gamma);
    final w2 = [w[0] + h / 2 * k1[0], w[1] + h / 2 * k1[1]];
    final k2 = _tm(theta + h / 2, w2, gamma);
    final w3 = [w[0] + h / 2 * k2[0], w[1] + h / 2 * k2[1]];
    final k3 = _tm(theta + h / 2, w3, gamma);
    final w4 = [w[0] + h * k3[0], w[1] + h * k3[1]];
    final k4 = _tm(theta + h, w4, gamma);
    return [
      w[0] + h / 6 * (k1[0] + 2 * k2[0] + 2 * k3[0] + k4[0]),
      w[1] + h / 6 * (k1[1] + 2 * k2[1] + 2 * k3[1] + k4[1]),
    ];
  }

  /// Integrates backwards from theta_s towards the axis, looking for the
  /// solid-cone surface event (V_theta crosses zero, increasing direction).
  static ({double thetaC, List<double> wc})? _integrateToSurface(
      double thetaS, List<double> w0, double gamma) {
    const steps = 4000;
    double h = -thetaS / steps;
    double theta = thetaS;
    var w = w0;

    for (int i = 0; i < steps; i++) {
      if (theta + h <= 1e-9) {
        h = -(theta - 1e-9);
        if (h >= 0) break;
      }
      final wNew = _rk4Step(theta, w, h, gamma);
      if (wNew[0].isNaN || wNew[1].isNaN) return null;

      if (w[1] < 0 && wNew[1] >= 0) {
        // Bisect within this step (fraction of h) for the crossing point.
        double lo = 0.0, hi = 1.0;
        var wHi = wNew;
        for (int b = 0; b < 60; b++) {
          final mid = 0.5 * (lo + hi);
          final wMid = _rk4Step(theta, w, h * mid, gamma);
          if (wMid[1] >= 0) {
            hi = mid;
            wHi = wMid;
          } else {
            lo = mid;
          }
        }
        return (thetaC: theta + h * hi, wc: wHi);
      }
      theta += h;
      w = wNew;
    }
    return null;
  }

  /// Mirrors find_cone_properties_from_shock(): integrates the cone flow
  /// given a shock-wave angle, returns null for a detached configuration.
  static _ConeRawMetrics? findConeFromShock(double thetaS, double m1, double gamma) {
    final os = obliqueShock(m1, thetaS, gamma);
    if (os.m2.isNaN || os.m2 < 0) return null;

    final vPrime = pow(2 / ((gamma - 1) * os.m2 * os.m2) + 1, -0.5).toDouble();
    final w0 = [vPrime * cos(thetaS - os.delta), -vPrime * sin(thetaS - os.delta)];

    final ev = _integrateToSurface(thetaS, w0, gamma);
    if (ev == null) return null;

    final wc = ev.wc;
    final vcPrime = sqrt(wc[0] * wc[0] + wc[1] * wc[1]);
    final denomMc = (gamma - 1) * (1 - vcPrime * vcPrime);
    if (denomMc <= 0) return null;
    final mc = sqrt(2 * vcPrime * vcPrime / denomMc);
    if (mc.isNaN) return null;

    return _ConeRawMetrics(
      ev.thetaC, mc, os.delta, os.m2, os.p2p1, os.rho2rho1, os.t2t1, wc[0], wc[1],
    );
  }

  // ── Generic robust root finder (bisection w/ auto-bracket, mirrors brentq use) ──
  static double? _bisectRoot(
      double Function(double) f, double lo, double hi, {int maxIter = 100}) {
    double flo = f(lo);
    double fhi = f(hi);
    if (flo.isNaN || fhi.isNaN) return null;

    if (flo * fhi > 0) {
      const n = 60;
      bool found = false;
      for (int i = 0; i < n; i++) {
        final a = lo + (hi - lo) * i / n;
        final b = lo + (hi - lo) * (i + 1) / n;
        final fa = f(a), fb = f(b);
        if (!fa.isNaN && !fb.isNaN && fa * fb < 0) {
          lo = a; hi = b; flo = fa; fhi = fb;
          found = true;
          break;
        }
      }
      if (!found) return null;
    }

    for (int i = 0; i < maxIter; i++) {
      final mid = 0.5 * (lo + hi);
      final fm = f(mid);
      if (fm.isNaN) return null;
      if (flo * fm <= 0) {
        hi = mid; fhi = fm;
      } else {
        lo = mid; flo = fm;
      }
      if ((hi - lo).abs() < 1e-13) break;
    }
    return 0.5 * (lo + hi);
  }

  /// Mirrors analyze_detachment_limits(): mach angle, max attachable theta_s,
  /// and the maximum attached cone half-angle.
  static ({double machAngle, double lowerBound, double upperBound, double maxConeRad})
      analyzeDetachmentLimits(double m1, double gamma) {
    final machAngle = asin(1 / m1);
    final lowerBound = machAngle + 1e-12;

    const n = 150;
    final start = machAngle + 1e-6;
    final end = 89.9 * pi / 180;
    final step = (end - start) / (n - 1);

    double maxTc = 0.0;
    double lastValidTs = start;
    double firstInvalidTs = end;

    for (int i = 0; i < n; i++) {
      final ts = start + step * i;
      final m = findConeFromShock(ts, m1, gamma);
      if (m != null && !m.thetaC.isNaN) {
        lastValidTs = ts;
        if (m.thetaC > maxTc) maxTc = m.thetaC;
      } else {
        firstInvalidTs = ts;
        break;
      }
    }

    double left = lastValidTs, right = firstInvalidTs;
    for (int k = 0; k < 20; k++) {
      final mid = 0.5 * (left + right);
      final m = findConeFromShock(mid, m1, gamma);
      if (m != null && !m.thetaC.isNaN) {
        left = mid;
        if (m.thetaC > maxTc) maxTc = m.thetaC;
      } else {
        right = mid;
      }
    }

    final upperBound = left - 1e-6;
    return (machAngle: machAngle, lowerBound: lowerBound, upperBound: upperBound, maxConeRad: maxTc);
  }

  static double? solveForTargetCone(
      double m1, double targetTcRad, double gamma, double low, double high) {
    double obj(double ts) {
      final m = findConeFromShock(ts, m1, gamma);
      return (m == null || m.thetaC.isNaN) ? 99.0 : m.thetaC - targetTcRad;
    }
    return _bisectRoot(obj, low, high);
  }

  static double? solveForTargetMc(
      double m1, double targetMc, double gamma, double low, double high) {
    double obj(double ts) {
      final m = findConeFromShock(ts, m1, gamma);
      return m == null ? -99.0 : m.mc - targetMc;
    }
    return _bisectRoot(obj, low, high);
  }

  /// Mirrors the post-processing block in the reference notebook's __main__:
  /// builds the full ConicalResult (Cp, ds/R, cone-surface ratios, ...).
  static ConicalResult buildFullResult(
      double thetaSUsed, _ConeRawMetrics m, double m1, double gamma) {
    final mc = m.mc;
    final m2 = m.m2;
    final p2p1 = m.p2p1;
    final rho2rho1 = m.rho2rho1;
    final t2t1 = m.t2t1;

    final po2po1 = p2p1 *
        pow(
          (1 + (gamma - 1) / 2 * m2 * m2) / (1 + (gamma - 1) / 2 * m1 * m1),
          gamma / (gamma - 1),
        ).toDouble();
    final toLocalRatio = 1 + (gamma - 1) / 2 * mc * mc;

    final tcT1 = t2t1 * (1 + (gamma - 1) / 2 * m2 * m2) / toLocalRatio;
    final pcP1 = p2p1 *
        pow((1 + (gamma - 1) / 2 * m2 * m2) / toLocalRatio, gamma / (gamma - 1))
            .toDouble();
    final rhocRho1 = rho2rho1 *
        pow((1 + (gamma - 1) / 2 * m2 * m2) / toLocalRatio, 1 / (gamma - 1))
            .toDouble();

    final cp = (2.0 / (gamma * m1 * m1)) * (pcP1 - 1.0);
    final dsR = -log(po2po1);
    final vTotalPrime = sqrt(m.vrC * m.vrC + m.vtC * m.vtC);

    return ConicalResult(
      thetaS: thetaSUsed,
      thetaC: m.thetaC,
      mc: mc,
      delta: m.delta,
      m2: m2,
      p2p1: p2p1,
      rho2rho1: rho2rho1,
      t2t1: t2t1,
      vrC: m.vrC,
      vtC: m.vtC,
      po2po1: po2po1,
      tcT1: tcT1,
      pcP1: pcP1,
      rhocRho1: rhocRho1,
      cp: cp,
      dsR: dsR,
      vTotalPrime: vTotalPrime,
    );
  }
}

// ─────────────────────────────────────────────
//  Main Screen Widget
// ─────────────────────────────────────────────
class ConicalShockScreen extends StatefulWidget {
  final VoidCallback? onDrawer;
  const ConicalShockScreen({super.key, this.onDrawer});

  @override
  State<ConicalShockScreen> createState() => _ConicalShockScreenState();
}

class _ConicalShockScreenState extends State<ConicalShockScreen> {
  // ── Controllers ───────────────────────────────────────────────────────
  final _gammaCtrl = TextEditingController();
  final _m1Ctrl = TextEditingController();
  final _thetaSCtrl = TextEditingController();
  final _thetaCCtrl = TextEditingController();
  final _mcCtrl = TextEditingController();

  // ── Focus nodes ───────────────────────────────────────────────────────
  final _gammaFocus = FocusNode();
  final _m1Focus = FocusNode();
  final _thetaSFocus = FocusNode();
  final _thetaCFocus = FocusNode();
  final _mcFocus = FocusNode();

  // ── Gamma state ───────────────────────────────────────────────────────
  double _gamma = 1.4;
  bool _gammaValid = true;
  String? _gammaError;
  String _selectedGasName = 'Air';
  bool _updating = false;

  // ── M1 state ──────────────────────────────────────────────────────────
  bool _m1Valid = false;
  double _m1Value = 0.0;
  String? _m1Error;

  // ── Detachment limits (depend on gamma & M1) ─────────────────────────
  double _machAngleRad = 0.0;
  double _lowerBoundRad = 0.0;
  double _upperBoundRad = 0.0;
  double _maxConeRad = 0.0;
  bool _limitsValid = false;

  // ── Active secondary field ───────────────────────────────────────────
  _CSField _activeField = _CSField.none;
  final Map<_CSField, String?> _fieldErrors = {};

  // ── Result ────────────────────────────────────────────────────────────
  ConicalResult? _result;

  // ── Reciprocal ratio toggle ──────────────────────────────────────────
  bool _inverseRatio = false;

  @override
  void initState() {
    super.initState();
    _gammaCtrl.text = '1.4';

    void onFocusChange(_CSField field, FocusNode node) {
      node.addListener(() {
        if (node.hasFocus && _activeField != field) {
          setState(() => _activeField = field);
        }
      });
    }

    onFocusChange(_CSField.thetaS, _thetaSFocus);
    onFocusChange(_CSField.thetaC, _thetaCFocus);
    onFocusChange(_CSField.mc, _mcFocus);
  }

  @override
  void dispose() {
    for (final c in [_gammaCtrl, _m1Ctrl, _thetaSCtrl, _thetaCCtrl, _mcCtrl]) {
      c.dispose();
    }
    for (final f in [_gammaFocus, _m1Focus, _thetaSFocus, _thetaCFocus, _mcFocus]) {
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
  void _onGammaChanged(String raw) {
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
    if (_m1Valid) _recomputeLimits();
    _recalculate();
  }

  // ─────────────────────────────────────────────
  //  M1 change
  // ─────────────────────────────────────────────
  void _onM1Changed(String raw) {
    if (_updating) return;
    _clearOtherErrors(null);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _m1Valid = false;
        _m1Error = null;
        _limitsValid = false;
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    final val = _evalExpr(trimmed);
    if (val == null) {
      setState(() {
        _m1Valid = false;
        _m1Error = 'Invalid expression';
        _limitsValid = false;
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    if (!_gammaValid) {
      setState(() => _m1Error = 'Enter a valid γ first');
      return;
    }
    if (val <= 1.0) {
      setState(() {
        _m1Valid = false;
        _m1Error = 'M₁ must be greater than 1';
        _limitsValid = false;
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    _m1Value = val;
    setState(() {
      _m1Valid = true;
      _m1Error = null;
    });
    _recomputeLimits();
    _recalculateSecondaryField();
  }

  void _recomputeLimits() {
    if (!_m1Valid || !_gammaValid) {
      _limitsValid = false;
      return;
    }
    final lim = ConicalShockEngine.analyzeDetachmentLimits(_m1Value, _gamma);
    setState(() {
      _machAngleRad = lim.machAngle;
      _lowerBoundRad = lim.lowerBound;
      _upperBoundRad = lim.upperBound;
      _maxConeRad = lim.maxConeRad;
      _limitsValid = true;
    });
  }

  // ─────────────────────────────────────────────
  //  θs change
  // ─────────────────────────────────────────────
  void _onThetaSChanged(String raw) {
    if (_updating) return;
    _activeField = _CSField.thetaS;
    _clearOtherErrors(_CSField.thetaS);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _fieldErrors[_CSField.thetaS] = null;
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    final val = _evalExpr(trimmed);
    if (val == null) {
      setState(() {
        _fieldErrors[_CSField.thetaS] = 'Invalid expression';
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    if (!_gammaValid) {
      setState(() => _fieldErrors[_CSField.thetaS] = 'Enter a valid γ first');
      return;
    }
    if (!_m1Valid || !_limitsValid) {
      setState(() => _fieldErrors[_CSField.thetaS] = 'Enter a valid M₁ first');
      return;
    }
    final muDeg = _machAngleRad * 180 / pi;
    if (val <= muDeg || val >= 90.0) {
      setState(() {
        _fieldErrors[_CSField.thetaS] = 'θs must be between ${_fmt(muDeg)}° and 90°';
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    final tsRad = val * pi / 180.0;
    final m = ConicalShockEngine.findConeFromShock(tsRad, _m1Value, _gamma);
    if (m == null || m.mc.isNaN) {
      setState(() {
        _fieldErrors[_CSField.thetaS] = 'Detached shock at this θs';
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    setState(() => _fieldErrors[_CSField.thetaS] = null);
    _setResult(ConicalShockEngine.buildFullResult(tsRad, m, _m1Value, _gamma));
  }

  // ─────────────────────────────────────────────
  //  θc change
  // ─────────────────────────────────────────────
  void _onThetaCChanged(String raw) {
    if (_updating) return;
    _activeField = _CSField.thetaC;
    _clearOtherErrors(_CSField.thetaC);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _fieldErrors[_CSField.thetaC] = null;
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    final val = _evalExpr(trimmed);
    if (val == null) {
      setState(() {
        _fieldErrors[_CSField.thetaC] = 'Invalid expression';
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    if (!_gammaValid) {
      setState(() => _fieldErrors[_CSField.thetaC] = 'Enter a valid γ first');
      return;
    }
    if (!_m1Valid || !_limitsValid) {
      setState(() => _fieldErrors[_CSField.thetaC] = 'Enter a valid M₁ first');
      return;
    }
    final maxConeDeg = _maxConeRad * 180 / pi;
    if (val <= 0 || val > maxConeDeg) {
      setState(() {
        _fieldErrors[_CSField.thetaC] = 'θc must be between 0° and ${_fmt(maxConeDeg)}° (θcmax)';
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    final tcRad = val * pi / 180.0;
    final ts = ConicalShockEngine.solveForTargetCone(
        _m1Value, tcRad, _gamma, _lowerBoundRad, _upperBoundRad);
    if (ts == null) {
      setState(() {
        _fieldErrors[_CSField.thetaC] = 'Detached shock';
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    final m = ConicalShockEngine.findConeFromShock(ts, _m1Value, _gamma);
    if (m == null || m.mc.isNaN) {
      setState(() {
        _fieldErrors[_CSField.thetaC] = 'Detached shock';
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    setState(() => _fieldErrors[_CSField.thetaC] = null);
    _setResult(ConicalShockEngine.buildFullResult(ts, m, _m1Value, _gamma));
  }

  // ─────────────────────────────────────────────
  //  Mc change
  // ─────────────────────────────────────────────
  void _onMcChanged(String raw) {
    if (_updating) return;
    _activeField = _CSField.mc;
    _clearOtherErrors(_CSField.mc);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _fieldErrors[_CSField.mc] = null;
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    final val = _evalExpr(trimmed);
    if (val == null) {
      setState(() {
        _fieldErrors[_CSField.mc] = 'Invalid expression';
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    if (!_gammaValid) {
      setState(() => _fieldErrors[_CSField.mc] = 'Enter a valid γ first');
      return;
    }
    if (!_m1Valid || !_limitsValid) {
      setState(() => _fieldErrors[_CSField.mc] = 'Enter a valid M₁ first');
      return;
    }
    if (val >= _m1Value) {
      setState(() {
        _fieldErrors[_CSField.mc] = 'Mc must be lower than M₁ (${_fmt(_m1Value)})';
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    final edge = ConicalShockEngine.findConeFromShock(_upperBoundRad, _m1Value, _gamma);
    final minPossibleMc = edge?.mc ?? 0.0;
    if (val < minPossibleMc) {
      setState(() {
        _fieldErrors[_CSField.mc] = 'Mc must be at least ${_fmt(minPossibleMc)} for an attached shock';
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    final ts = ConicalShockEngine.solveForTargetMc(
        _m1Value, val, _gamma, _lowerBoundRad, _upperBoundRad);
    if (ts == null) {
      setState(() {
        _fieldErrors[_CSField.mc] = 'No attached solution found';
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    final m = ConicalShockEngine.findConeFromShock(ts, _m1Value, _gamma);
    if (m == null || m.mc.isNaN) {
      setState(() {
        _fieldErrors[_CSField.mc] = 'Detached shock';
        _result = null;
      });
      _clearOutputFields();
      return;
    }
    setState(() => _fieldErrors[_CSField.mc] = null);
    _setResult(ConicalShockEngine.buildFullResult(ts, m, _m1Value, _gamma));
  }

  // ─────────────────────────────────────────────
  //  Shared result handling
  // ─────────────────────────────────────────────
  void _setResult(ConicalResult result) {
    setState(() => _result = result);
    _writeComputedFields();
  }

  void _recalculate() {
    if (_activeField == _CSField.none) return;
    switch (_activeField) {
      case _CSField.thetaS:
        _onThetaSChanged(_thetaSCtrl.text);
      case _CSField.thetaC:
        _onThetaCChanged(_thetaCCtrl.text);
      case _CSField.mc:
        _onMcChanged(_mcCtrl.text);
      case _CSField.none:
        break;
    }
  }

  // When M1 changes and a secondary field is active, recompute
  void _recalculateSecondaryField() {
    if (_activeField == _CSField.none) {
      setState(() {});
      return;
    }
    switch (_activeField) {
      case _CSField.thetaS:
        _onThetaSChanged(_thetaSCtrl.text);
      case _CSField.thetaC:
        _onThetaCChanged(_thetaCCtrl.text);
      case _CSField.mc:
        _onMcChanged(_mcCtrl.text);
      case _CSField.none:
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

    void setIfNotActive(_CSField field, TextEditingController ctrl, String Function() value) {
      if (_activeField != field) ctrl.text = value();
    }

    setIfNotActive(_CSField.thetaS, _thetaSCtrl, () => _fmt(r.thetaS * 180.0 / pi));
    setIfNotActive(_CSField.thetaC, _thetaCCtrl, () => _fmt(r.thetaC * 180.0 / pi));
    setIfNotActive(_CSField.mc, _mcCtrl, () => _fmt(r.mc));

    _updating = false;
  }

  void _clearOutputFields() {
    _updating = true;
    if (_activeField != _CSField.thetaS) _thetaSCtrl.clear();
    if (_activeField != _CSField.thetaC) _thetaCCtrl.clear();
    if (_activeField != _CSField.mc) _mcCtrl.clear();
    _updating = false;
    setState(() => _result = null);
  }

  void _clearOtherErrors(_CSField? keep) {
    for (final f in _CSField.values) {
      if (f != keep) _fieldErrors.remove(f);
    }
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

  // ── App Bar ───────────────────────────────────────────────────────────
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
                  'Conical Shock',
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

  // ── Gamma card ────────────────────────────────────────────────────────
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
                      _onGammaChanged(gas.gamma.toString());
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

  // ── Flow Properties card (M₁, θs, θc, Mc inputs + all outputs) ──────────
  Widget _buildFlowPropertiesCard(BuildContext context) {
    final r = _result;
    String outVal(double? v) => v != null ? _fmt(v) : '—';

    final p2p1Sym = _inverseRatio ? 'P₁/P₂' : 'P₂/P₁';
    final pcp1Sym = _inverseRatio ? 'P₁/Pc' : 'Pc/P₁';
    final po2po1Sym = _inverseRatio ? 'P₀₁/P₀₂' : 'P₀₂/P₀₁';
    final pocpo1Sym = _inverseRatio ? 'P₀₁/P₀c' : 'P₀c/P₀₁';
    final rhoSym = _inverseRatio ? 'ρ₁/ρ₂' : 'ρ₂/ρ₁';
    final rhocSym = _inverseRatio ? 'ρ₁/ρc' : 'ρc/ρ₁';
    final t2t1Sym = _inverseRatio ? 'T₁/T₂' : 'T₂/T₁';
    final tct1Sym = _inverseRatio ? 'T₁/Tc' : 'Tc/T₁';

    double? inv(double? v) => v == null ? null : (_inverseRatio ? 1.0 / v : v);

    final reciprocalToggle = GestureDetector(
      onTap: () => setState(() => _inverseRatio = !_inverseRatio),
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
          reciprocalToggle,
        ],
      ),
      children: [
        // ── M₁ ─────────────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(
            Responsive.pad(context, 14),
            Responsive.pad(context, 8),
            Responsive.pad(context, 14),
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Freestream Mach',
                    style: TextStyle(
                      fontSize: Responsive.sp(context, 13),
                      fontWeight: FontWeight.w500,
                      color: _C.fieldLabel,
                    ),
                  ),
                  SizedBox(width: Responsive.wp(context, 4)),
                  Text(
                    'M₁',
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
                controller: _m1Ctrl,
                focusNode: _m1Focus,
                hintText: 'Must be supersonic (greater than 1)',
                onChanged: _onM1Changed,
                hasError: _m1Error != null,
              ),
              if (_m1Error != null) ...[
                SizedBox(height: Responsive.hp(context, 4)),
                _errorText(context, _m1Error!),
              ],
            ],
          ),
        ),

        _divider(),

        // ── θs ─────────────────────────────────────────────────────────
        _flowField(
          context: context,
          field: _CSField.thetaS,
          label: 'Shock Wave Angle',
          symbol: 'θs°',
          controller: _thetaSCtrl,
          focusNode: _thetaSFocus,
          hintText: _limitsValid
              ? 'Between ${_fmt(_machAngleRad * 180 / pi)}° and 90°'
              : 'Enter M₁ first',
          onChanged: _onThetaSChanged,
          error: _fieldErrors[_CSField.thetaS],
        ),

        _divider(),

        // ── θc ─────────────────────────────────────────────────────────
        _flowField(
          context: context,
          field: _CSField.thetaC,
          label: 'Cone Body Angle',
          symbol: 'θc°',
          controller: _thetaCCtrl,
          focusNode: _thetaCFocus,
          hintText: _limitsValid
              ? 'Between 0° and ${_fmt(_maxConeRad * 180 / pi)}° (θcmax)'
              : 'Enter M₁ first',
          onChanged: _onThetaCChanged,
          error: _fieldErrors[_CSField.thetaC],
        ),

        _divider(),

        // ── Mc ─────────────────────────────────────────────────────────
        _flowField(
          context: context,
          field: _CSField.mc,
          label: 'Surface Mach',
          symbol: 'Mc',
          controller: _mcCtrl,
          focusNode: _mcFocus,
          hintText: _m1Valid ? 'Must be lower than M₁ (${_fmt(_m1Value)})' : 'Enter M₁ first',
          onChanged: _onMcChanged,
          error: _fieldErrors[_CSField.mc],
          isLast: true,
        ),

        const Divider(height: 0, thickness: 0.5, color: _C.sectionDiv),

        // ── Output section ──────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(
            Responsive.pad(context, 14),
            Responsive.pad(context, 10),
            Responsive.pad(context, 14),
            Responsive.pad(context, 10),
          ),
          child: Column(
            children: [
              // Row: θcmax (always shown)
              _outputRowFull(
                context: context,
                symbol: 'θcmax',
                label: 'Max attached cone angle',
                value: _limitsValid ? outVal(_maxConeRad * 180 / pi) : '—',
                unit: '°',
              ),

              SizedBox(height: Responsive.hp(context, 8)),

              _outputRowPair(
                context: context,
                sym1: 'θs (wave)',
                val1: r != null ? '${outVal(r.thetaS * 180 / pi)}°' : '—',
                sym2: 'δ (turn)',
                val2: r != null ? '${outVal(r.delta * 180 / pi)}°' : '—',
              ),
              SizedBox(height: Responsive.hp(context, 8)),
              _outputRowPair(
                context: context,
                sym1: 'Cp (surface)',
                val1: outVal(r?.cp),
                sym2: 'Δs/R',
                val2: outVal(r?.dsR),
              ),
              SizedBox(height: Responsive.hp(context, 8)),
              _outputRowPair(
                context: context,
                sym1: "V' surface",
                val1: outVal(r?.vTotalPrime),
                sym2: 'M₂ (post-shock)',
                val2: outVal(r?.m2),
              ),
              SizedBox(height: Responsive.hp(context, 10)),
              const Divider(height: 0, thickness: 0.5),
              SizedBox(height: Responsive.hp(context, 10)),
              _outputRowPair(
                context: context,
                sym1: p2p1Sym,
                val1: outVal(inv(r?.p2p1)),
                sym2: pcp1Sym,
                val2: outVal(inv(r?.pcP1)),
              ),
              SizedBox(height: Responsive.hp(context, 8)),
              _outputRowPair(
                context: context,
                sym1: po2po1Sym,
                val1: outVal(inv(r?.po2po1)),
                sym2: pocpo1Sym,
                val2: outVal(inv(r?.po2po1)),
              ),
              SizedBox(height: Responsive.hp(context, 8)),
              _outputRowPair(
                context: context,
                sym1: rhoSym,
                val1: outVal(inv(r?.rho2rho1)),
                sym2: rhocSym,
                val2: outVal(inv(r?.rhocRho1)),
              ),
              SizedBox(height: Responsive.hp(context, 8)),
              _outputRowPair(
                context: context,
                sym1: t2t1Sym,
                val1: outVal(inv(r?.t2t1)),
                sym2: tct1Sym,
                val2: outVal(inv(r?.tcT1)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divider() =>
      const Divider(height: 0, thickness: 0.5, color: _C.rowDivider);

  Widget _flowField({
    required BuildContext context,
    required _CSField field,
    required String label,
    required String symbol,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required ValueChanged<String> onChanged,
    String? error,
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
          ),
          if (error != null) ...[
            SizedBox(height: Responsive.hp(context, 4)),
            _errorText(context, error),
          ],
        ],
      ),
    );
  }

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

  // ─────────────────────────────────────────────
  //  Output row helpers
  // ─────────────────────────────────────────────
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

  Widget _outputCell(BuildContext context, String symbol, String value) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.pad(context, 10),
        vertical: Responsive.pad(context, 8),
      ),
      decoration: BoxDecoration(
        color: _C.outputReadonlyBg,
        borderRadius: BorderRadius.circular(Responsive.wp(context, 8)),
        border: Border.all(color: _C.outputReadonlyBorder, width: 0.8),
      ),
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

  Widget _buildInputField({
    required BuildContext context,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required ValueChanged<String> onChanged,
    bool hasError = false,
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
        } else if (focused) {
          borderColor = _C.fieldBorderFocus;
          bgColor = _C.inputActiveBg;
        } else {
          borderColor = _C.fieldBorder;
          bgColor = _C.fieldBg;
        }

        return Container(
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
              fontWeight: FontWeight.w400,
              color: _C.textPrimary,
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

  // ── Features dialog ───────────────────────────────────────────────────
  void _showFeaturesDialog(BuildContext context) {
    showAppFeaturesDialog(context);
  }

  // ── Info dialog ────────────────────────────────────────────────────────
  void _showInfoDialog(BuildContext context) {
    showTopicInfoDialog(
      context,
      title: 'About Conical Shock',
      items: const [
        MapEntry('θs — Shock wave angle', 'Angle of the conical shock sheet relative to the freestream. Must lie between the Mach angle μ₁ and 90°.'),
        MapEntry('θc — Cone half-angle', 'Half-angle of the solid cone generating the attached shock. Exceeding the max attachable value detaches the shock.'),
        MapEntry('Mc — Surface Mach', 'Mach number of the flow right at the cone surface, after isentropic compression behind the conical shock.'),
        MapEntry('δ — Flow deflection', 'Flow turn angle immediately behind the shock (from the oblique-shock relation), before the flow further turns isentropically to the cone surface.'),
        MapEntry('Cp', 'Surface pressure coefficient, (pc/p∞ − 1) · 2/(γM₁²).'),
        MapEntry('Δs/R', 'Non-dimensional entropy rise across the shock, −ln(p₀c/p₀∞).'),
        MapEntry('Reciprocal', 'Flips all ratio outputs to their reciprocals (e.g. T₂/T₁ ↔ T₁/T₂).'),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Gas dropdown button (same as oblique page)
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
//  Reusable Card (same as oblique page)
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