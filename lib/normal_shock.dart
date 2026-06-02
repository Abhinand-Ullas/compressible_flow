import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  _GasEntry('Other', double.nan),
];

// ─────────────────────────────────────────────
//  Enum: active input field
// ─────────────────────────────────────────────
enum _NSField { none, m1, m2, t2t1, p2p1, rho2rho1, p02p01, p02p1, delvA1 }

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
    final val = double.tryParse(trimmed);
    if (val == null) {
      setState(() {
        _gammaValid = false;
        _gammaError = 'Invalid number';
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
    if (trimmed.isEmpty || trimmed == '.') {
      setState(() {
        _fieldErrors[_NSField.m1] = null;
        _result = null;
      });
      _clearComputedFields(_NSField.m1);
      return;
    }
    final val = double.tryParse(trimmed);
    if (val == null) {
      setState(() {
        _fieldErrors[_NSField.m1] = 'Invalid format';
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
    if (trimmed.isEmpty || trimmed == '.') {
      setState(() {
        _fieldErrors[_NSField.m2] = null;
        _result = null;
      });
      _clearComputedFields(_NSField.m2);
      return;
    }
    final val = double.tryParse(trimmed);
    if (val == null) {
      setState(() {
        _fieldErrors[_NSField.m2] = 'Invalid format';
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
    if (trimmed.isEmpty || trimmed == '.') {
      setState(() {
        _fieldErrors[_NSField.t2t1] = null;
        _result = null;
      });
      _clearComputedFields(_NSField.t2t1);
      return;
    }
    final val = double.tryParse(trimmed);
    if (val == null) {
      setState(() {
        _fieldErrors[_NSField.t2t1] = 'Invalid format';
        _result = null;
      });
      _clearComputedFields(_NSField.t2t1);
      return;
    }
    if (val <= 1.0) {
      setState(() {
        _fieldErrors[_NSField.t2t1] = 'T₂/T₁ must be greater than 1';
        _result = null;
      });
      _clearComputedFields(_NSField.t2t1);
      return;
    }
    if (!_gammaValid) {
      setState(() => _fieldErrors[_NSField.t2t1] = 'Enter a valid γ first');
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
    if (trimmed.isEmpty || trimmed == '.') {
      setState(() {
        _fieldErrors[_NSField.p2p1] = null;
        _result = null;
      });
      _clearComputedFields(_NSField.p2p1);
      return;
    }
    final val = double.tryParse(trimmed);
    if (val == null) {
      setState(() {
        _fieldErrors[_NSField.p2p1] = 'Invalid format';
        _result = null;
      });
      _clearComputedFields(_NSField.p2p1);
      return;
    }
    if (val <= 1.0) {
      setState(() {
        _fieldErrors[_NSField.p2p1] = 'P₂/P₁ must be greater than 1';
        _result = null;
      });
      _clearComputedFields(_NSField.p2p1);
      return;
    }
    if (!_gammaValid) {
      setState(() => _fieldErrors[_NSField.p2p1] = 'Enter a valid γ first');
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
    if (trimmed.isEmpty || trimmed == '.') {
      setState(() {
        _fieldErrors[_NSField.rho2rho1] = null;
        _result = null;
      });
      _clearComputedFields(_NSField.rho2rho1);
      return;
    }
    final val = double.tryParse(trimmed);
    if (val == null) {
      setState(() {
        _fieldErrors[_NSField.rho2rho1] = 'Invalid format';
        _result = null;
      });
      _clearComputedFields(_NSField.rho2rho1);
      return;
    }
    final maxRho = NormalShockEngine.rho2Rho1max(_gamma);
    if (val <= 1.0 || val >= maxRho) {
      setState(() {
        _fieldErrors[_NSField.rho2rho1] =
            'ρ₂/ρ₁ must be between 1 and ${_fmt(maxRho)}';
        _result = null;
      });
      _clearComputedFields(_NSField.rho2rho1);
      return;
    }
    if (!_gammaValid) {
      setState(
        () => _fieldErrors[_NSField.rho2rho1] = 'Enter a valid γ first',
      );
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
    if (trimmed.isEmpty || trimmed == '.') {
      setState(() {
        _fieldErrors[_NSField.p02p01] = null;
        _result = null;
      });
      _clearComputedFields(_NSField.p02p01);
      return;
    }
    final val = double.tryParse(trimmed);
    if (val == null) {
      setState(() {
        _fieldErrors[_NSField.p02p01] = 'Invalid format';
        _result = null;
      });
      _clearComputedFields(_NSField.p02p01);
      return;
    }
    if (val <= 0.0 || val >= 1.0) {
      setState(() {
        _fieldErrors[_NSField.p02p01] = 'P₀₂/P₀₁ must be between 0 and 1';
        _result = null;
      });
      _clearComputedFields(_NSField.p02p01);
      return;
    }
    if (!_gammaValid) {
      setState(() => _fieldErrors[_NSField.p02p01] = 'Enter a valid γ first');
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
    if (trimmed.isEmpty || trimmed == '.') {
      setState(() {
        _fieldErrors[_NSField.p02p1] = null;
        _result = null;
      });
      _clearComputedFields(_NSField.p02p1);
      return;
    }
    final val = double.tryParse(trimmed);
    if (val == null) {
      setState(() {
        _fieldErrors[_NSField.p02p1] = 'Invalid format';
        _result = null;
      });
      _clearComputedFields(_NSField.p02p1);
      return;
    }
    final minP02p1 = NormalShockEngine.p02p1min(_gamma);
    if (val <= minP02p1) {
      setState(() {
        _fieldErrors[_NSField.p02p1] =
            'P₀₂/P₁ must be greater than ${_fmt(minP02p1)}';
        _result = null;
      });
      _clearComputedFields(_NSField.p02p1);
      return;
    }
    if (!_gammaValid) {
      setState(() => _fieldErrors[_NSField.p02p1] = 'Enter a valid γ first');
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
    if (trimmed.isEmpty || trimmed == '.') {
      setState(() {
        _fieldErrors[_NSField.delvA1] = null;
        _result = null;
      });
      _clearComputedFields(_NSField.delvA1);
      return;
    }
    final val = double.tryParse(trimmed);
    if (val == null) {
      setState(() {
        _fieldErrors[_NSField.delvA1] = 'Invalid format';
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
    setIfNotActive(_NSField.t2t1, _t2t1Ctrl, () => _fmt(r.t2t1));
    setIfNotActive(_NSField.p2p1, _p2p1Ctrl, () => _fmt(r.p2p1));
    setIfNotActive(_NSField.rho2rho1, _rho2rho1Ctrl, () => _fmt(r.rho2rho1));
    setIfNotActive(_NSField.p02p01, _p02p01Ctrl, () => _fmt(r.p02p01));
    setIfNotActive(_NSField.p02p1, _p02p1Ctrl, () => _fmt(r.p02p1));
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
    required String label1,
    required String label2,
    required double ratio,
  }) {
    showDialog(
      context: context,
      builder: (_) => _HandyCalcDialog(
        title: title,
        label1: label1,
        label2: label2,
        ratio: ratio,
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Reset all
  // ─────────────────────────────────────────────
  void _resetAll() {
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
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDescription(),
                    const SizedBox(height: 14),
                    _buildGammaCard(),
                    const SizedBox(height: 12),
                    _buildFieldsCard(),
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

  // ── App Bar ───────────────────────────────────────────────────────────────
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
                onPressed: widget.onDrawer ?? () {} // wire to nav drawer
              ),
              const Expanded(
                child: Text(
                  'Normal Shock',
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
                icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
                tooltip: 'Reset all',
                onPressed: _resetAll,
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

  // ── Description ───────────────────────────────────────────────────────────
  Widget _buildDescription() {
    return const Text(
      'Enter any one flow parameter to instantly compute all remaining '
      'normal shock properties. Tap a ratio label (T₂/T₁, P₂/P₁ …) to '
      'convert between pre-shock and post-shock absolute values.',
      style: TextStyle(fontSize: 12, color: _C.descText, height: 1.55),
    );
  }

  // ── Gamma card ────────────────────────────────────────────────────────────
  Widget _buildGammaCard() {
    return _Card(
      header: _cardHeader(Icons.tune, 'SPECIFIC HEAT RATIO  γ'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'γ  (Gamma)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _C.fieldLabel,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      controller: _gammaCtrl,
                      focusNode: _gammaFocus,
                      hintText: 'e.g. 1.4',
                      onChanged: _onGammaChanged,
                      hasError: !_gammaValid,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _GasDropdownButton(
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
                const SizedBox(height: 4),
                _errorText(_gammaError!),
              ],
              const SizedBox(height: 4),
              const Text(
                'Must be greater than 1',
                style: TextStyle(fontSize: 11, color: _C.fieldSubHint),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Fields card ───────────────────────────────────────────────────────────
  Widget _buildFieldsCard() {
    final r = _result;
    final bool hasResult = r != null;

    return _Card(
      header: _cardHeader(Icons.calculate_outlined, 'SHOCK PROPERTIES'),
      children: [
        // ── M₁ ──────────────────────────────────────────────────────────────
        _flowField(
          field: _NSField.m1,
          label: 'Mach Number (before shock)',
          symbol: 'M₁',
          controller: _m1Ctrl,
          focusNode: _m1Focus,
          hintText: 'Enter M₁ (> 1)',
          subHint: 'Must be greater than 1',
          onChanged: _onM1Changed,
          error: _fieldErrors[_NSField.m1],
        ),

        _divider(),

        // ── M₂ ──────────────────────────────────────────────────────────────
        _flowField(
          field: _NSField.m2,
          label: 'Mach Number (after shock)',
          symbol: 'M₂',
          controller: _m2Ctrl,
          focusNode: _m2Focus,
          hintText: 'Enter M₂',
          subHint: 'Between M₂min and 1',
          onChanged: _onM2Changed,
          error: _fieldErrors[_NSField.m2],
        ),

        _divider(),

        // ── T₂/T₁ ───────────────────────────────────────────────────────────
        _flowField(
          field: _NSField.t2t1,
          label: 'Temperature Ratio',
          symbol: 'T₂/T₁',
          controller: _t2t1Ctrl,
          focusNode: _t2t1Focus,
          hintText: 'Enter T₂/T₁',
          subHint: 'Must be greater than 1',
          onChanged: _onT2T1Changed,
          error: _fieldErrors[_NSField.t2t1],
          onLabelTap: hasResult
              ? () => _openHandyCalc(
                  title: 'T₂/T₁ = ${_fmt(r.t2t1)}',
                  label1: 'T₂ =',
                  label2: 'T₁ =',
                  ratio: r.t2t1,
                )
              : null,
        ),

        _divider(),

        // ── P₂/P₁ ───────────────────────────────────────────────────────────
        _flowField(
          field: _NSField.p2p1,
          label: 'Pressure Ratio',
          symbol: 'P₂/P₁',
          controller: _p2p1Ctrl,
          focusNode: _p2p1Focus,
          hintText: 'Enter P₂/P₁',
          subHint: 'Must be greater than 1',
          onChanged: _onP2P1Changed,
          error: _fieldErrors[_NSField.p2p1],
          onLabelTap: hasResult
              ? () => _openHandyCalc(
                  title: 'P₂/P₁ = ${_fmt(r.p2p1)}',
                  label1: 'P₂ =',
                  label2: 'P₁ =',
                  ratio: r.p2p1,
                )
              : null,
        ),

        _divider(),

        // ── ρ₂/ρ₁ ───────────────────────────────────────────────────────────
        _flowField(
          field: _NSField.rho2rho1,
          label: 'Density Ratio',
          symbol: 'ρ₂/ρ₁',
          controller: _rho2rho1Ctrl,
          focusNode: _rho2rho1Focus,
          hintText: 'Enter ρ₂/ρ₁',
          subHint: 'Between 1 and (γ+1)/(γ−1)',
          onChanged: _onRho2Rho1Changed,
          error: _fieldErrors[_NSField.rho2rho1],
          onLabelTap: hasResult
              ? () => _openHandyCalc(
                  title: 'ρ₂/ρ₁ = ${_fmt(r.rho2rho1)}',
                  label1: 'ρ₂ =',
                  label2: 'ρ₁ =',
                  ratio: r.rho2rho1,
                )
              : null,
        ),

        _divider(),

        // ── P₀₂/P₀₁ ─────────────────────────────────────────────────────────
        _flowField(
          field: _NSField.p02p01,
          label: 'Stagnation Pressure Ratio',
          symbol: 'P₀₂/P₀₁',
          controller: _p02p01Ctrl,
          focusNode: _p02p01Focus,
          hintText: 'Enter P₀₂/P₀₁',
          subHint: 'Between 0 and 1',
          onChanged: _onP02P01Changed,
          error: _fieldErrors[_NSField.p02p01],
          onLabelTap: hasResult
              ? () => _openHandyCalc(
                  title: 'P₀₂/P₀₁ = ${_fmt(r.p02p01)}',
                  label1: 'P₀₂ =',
                  label2: 'P₀₁ =',
                  ratio: r.p02p01,
                )
              : null,
        ),

        _divider(),

        // ── P₀₂/P₁ ──────────────────────────────────────────────────────────
        _flowField(
          field: _NSField.p02p1,
          label: 'Pitot-to-Static Ratio',
          symbol: 'P₀₂/P₁',
          controller: _p02p1Ctrl,
          focusNode: _p02p1Focus,
          hintText: 'Enter P₀₂/P₁',
          subHint: 'Must be greater than P₀₂/P₁ min',
          onChanged: _onP02P1Changed,
          error: _fieldErrors[_NSField.p02p1],
          onLabelTap: hasResult
              ? () => _openHandyCalc(
                  title: 'P₀₂/P₁ = ${_fmt(r.p02p1)}',
                  label1: 'P₀₂ =',
                  label2: 'P₁ =',
                  ratio: r.p02p1,
                )
              : null,
        ),

        _divider(),

        // ── ΔV/a₁ ────────────────────────────────────────────────────────────
        _flowField(
          field: _NSField.delvA1,
          label: 'Velocity Change Ratio',
          symbol: 'ΔV/a₁',
          controller: _delvA1Ctrl,
          focusNode: _delvA1Focus,
          hintText: 'Enter ΔV/a₁',
          subHint: 'Must be greater than 0',
          onChanged: _onDelvA1Changed,
          error: _fieldErrors[_NSField.delvA1],
          isLast: true,
        ),
      ],
    );
  }

  // ── Note card ─────────────────────────────────────────────────────────────
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

  // ─────────────────────────────────────────────
  //  Reusable sub-builders
  // ─────────────────────────────────────────────

  Widget _cardHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            color: _C.headerBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 17),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
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
    required _NSField field,
    required String label,
    required String symbol,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required ValueChanged<String> onChanged,
    String? subHint,
    String? error,
    VoidCallback? onLabelTap,
    Widget? trailing,
    bool isLast = false,
  }) {
    final isActive = _activeField == field;
    final isComputed =
        _activeField != _NSField.none && !isActive && _result != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, isLast ? 16 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onLabelTap,
                  child: Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: onLabelTap != null
                              ? _C.headerBg
                              : _C.fieldLabel,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        symbol,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          color: onLabelTap != null
                              ? _C.headerBg
                              : _C.fieldLabel,
                        ),
                      ),
                      if (onLabelTap != null) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.touch_app,
                          size: 13,
                          color: _C.headerBg,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 7),
          _buildInputField(
            controller: controller,
            focusNode: focusNode,
            hintText: hintText,
            onChanged: onChanged,
            hasError: error != null,
            isComputed: isComputed,
            isActive: isActive,
          ),
          if (error != null) ...[
            const SizedBox(height: 4),
            _errorText(error),
          ] else if (subHint != null) ...[
            const SizedBox(height: 4),
            Text(
              subHint,
              style: const TextStyle(fontSize: 11, color: _C.fieldSubHint),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputField({
    Key? key,
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

        return Container(
          key: key,
          height: 46,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: false,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            style: TextStyle(
              fontSize: 14,
              fontWeight: isComputed ? FontWeight.w500 : FontWeight.w400,
              color: isComputed ? _C.outputValue : _C.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 13,
              ),
              border: InputBorder.none,
              hintText: hintText,
              hintStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: _C.fieldHint,
              ),
              suffixIcon: isComputed
                  ? const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: _C.labelSmall,
                      ),
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 30,
                minHeight: 30,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _errorText(String msg) => Row(
    children: [
      const Icon(Icons.error_outline, size: 13, color: _C.errorText),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          msg,
          style: const TextStyle(fontSize: 11, color: _C.errorText),
        ),
      ),
    ],
  );

  // ── Info dialog ───────────────────────────────────────────────────────────
  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _C.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Normal Shock',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _C.headerBg,
          ),
        ),
        content: const Text(
          '1. Subscript \'1\' → state before the shock.\n'
          '2. Subscript \'2\' → state after the shock.\n'
          '3. Subscript \'0\' → stagnation (total) quantity.\n'
          '4. γ (gamma) is required; tap the gas button to pick a preset.\n'
          '5. Enter any one of M₁, M₂, T₂/T₁, P₂/P₁, ρ₂/ρ₁, P₀₂/P₀₁, P₀₂/P₁, or ΔV/a₁ to instantly compute all remaining properties.\n'
          '6. P₀₂/P₀₁ and P₀₂/P₁ cases use Newton-Raphson iteration.\n'
          '7. Tap any ratio label (e.g. T₂/T₁) to open HandyCalc for converting between absolute values.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.6,
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
//  Gas dropdown button  (identical to Isentropic page)
// ─────────────────────────────────────────────
class _GasDropdownButton extends StatelessWidget {
  const _GasDropdownButton({
    required this.onSelect,
    required this.selectedName,
  });
  final ValueChanged<_GasEntry> onSelect;
  final String selectedName;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showGasPicker(context),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _C.headerBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showGasPicker(BuildContext context) {
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
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                'Select Gas / Fluid',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _C.headerBg,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  children: _kGases
                      .where((g) => !g.gamma.isNaN)
                      .map(
                        (gas) => GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            onSelect(gas);
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
                                color: _C.cardBorder,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  gas.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: _C.textPrimary,
                                  ),
                                ),
                                Text(
                                  'γ = ${gas.gamma}',
                                  style: const TextStyle(
                                    fontSize: 13,
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
    required this.label1,
    required this.label2,
    required this.ratio,
  });

  final String title;
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        widget.title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _C.headerBg,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter either value to compute the other:',
            style: TextStyle(fontSize: 11.5, color: _C.labelMedium),
          ),
          const SizedBox(height: 14),
          _handyRow(widget.label1, _ctrl1, _onNumeratorChanged, _error1),
          if (_error1 != null) ...[
            const SizedBox(height: 4),
            _errorTextWidget(_error1!),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(width: 8),
              Expanded(child: Container(height: 1, color: _C.sectionDiv)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '÷  ratio',
                  style: TextStyle(fontSize: 10, color: _C.labelSmall),
                ),
              ),
              Expanded(child: Container(height: 1, color: _C.sectionDiv)),
            ],
          ),
          const SizedBox(height: 10),
          _handyRow(widget.label2, _ctrl2, _onDenominatorChanged, _error2),
          if (_error2 != null) ...[
            const SizedBox(height: 4),
            _errorTextWidget(_error2!),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Done',
            style: TextStyle(color: _C.headerBg, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _errorTextWidget(String msg) => Row(
    children: [
      const Icon(Icons.error_outline, size: 13, color: _C.errorText),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          msg,
          style: const TextStyle(fontSize: 11, color: _C.errorText),
        ),
      ),
    ],
  );

  Widget _handyRow(
    String label,
    TextEditingController ctrl,
    ValueChanged<String> onChanged,
    String? error,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: _C.fieldLabel,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: _C.handyCalcBg,
              borderRadius: BorderRadius.circular(8),
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
              style: const TextStyle(
                fontSize: 14,
                color: _C.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: InputBorder.none,
                hintText: 'Enter value',
                hintStyle: TextStyle(
                  fontSize: 13,
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