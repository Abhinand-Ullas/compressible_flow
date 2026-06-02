import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────
//  Colour tokens  (same palette as Standard Atmosphere page)
// ─────────────────────────────────────────────
class _C {
  static const headerBg = Color(0xFF18397C); // Color.fromARGB(255,24,62,124)
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
  static const unitDivider = Color(0xFFE5E7EB);
  static const unitText = Color(0xFF374151);
  static const unitArrow = Color(0xFF6B7280);
  static const sectionLabel = Color(0xFF18397C);
  static const outputLabel = Color(0xFF374151);
  static const outputValue = Color(0xFF0D1F3C);
  static const outputDash = Color(0xFF9CA3AF);
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
//  Predefined gas data  (mirrors Java spinner)
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
//  Enum: which field the user is currently typing in
// ─────────────────────────────────────────────
enum _ActiveField { none, mach, tRatio, pRatio, rhoRatio, aRatio, mu, nu }

// ─────────────────────────────────────────────
//  Calculation engine  (pure, no Flutter deps)
// ─────────────────────────────────────────────
class IsentropicEngine {
  // ── Core: given M and γ, compute all ratios ──────────────────────────────
  static Map<String, double> fromMach(double M, double gamma) {
    final g = gamma;
    final X = 1.0 + 0.5 * (g - 1.0) * M * M;

    // T/T₀
    final tRatio = 1.0 / X;

    // P/P₀  =  (1 + (γ-1)/2 · M²)^(−γ/(γ−1))
    final pRatio = pow(X, -g / (g - 1.0)).toDouble();

    // ρ/ρ₀  =  (1 + (γ-1)/2 · M²)^(−1/(γ−1))
    final rhoRatio = pow(X, -1.0 / (g - 1.0)).toDouble();

    // A/A*  =  (1/M) · [ (2/(γ+1)) · (1 + (γ-1)/2 · M²) ]^((γ+1)/(2(γ−1)))
    final aRatio =
        (1.0 / M) *
        pow(X / ((g + 1.0) / 2.0), (g + 1.0) / (2.0 * (g - 1.0))).toDouble();

    final result = {
      'M': M,
      'tRatio': tRatio,
      'pRatio': pRatio,
      'rhoRatio': rhoRatio,
      'aRatio': aRatio,
    };

    // Mach angle and Prandtl-Meyer only for supersonic
    if (M >= 1.0) {
      result['mu'] = degrees(asin(1.0 / M));
      double nu =
          sqrt((g + 1.0) / (g - 1.0)) *
              atan(sqrt((g - 1.0) * (M * M - 1.0) / (g + 1.0))) -
          atan(sqrt(M * M - 1.0));
      result['nu'] = degrees(nu);
    }

    return result;
  }

  // ── Case 2: T/T₀ → M ─────────────────────────────────────────────────────
  static double machFromTRatio(double tRatio, double gamma) {
    return sqrt(2.0 * ((1.0 / tRatio) - 1.0) / (gamma - 1.0));
  }

  // ── Case 3: P/P₀ → M ─────────────────────────────────────────────────────
  static double machFromPRatio(double pRatio, double gamma) {
    return sqrt(
      2.0 *
          (pow(pRatio, (1.0 - gamma) / gamma).toDouble() - 1.0) /
          (gamma - 1.0),
    );
  }

  // ── Case 4: ρ/ρ₀ → M ────────────────────────────────────────────────────
  static double machFromRhoRatio(double rhoRatio, double gamma) {
    return sqrt(
      2.0 *
          ((pow(1.0 / rhoRatio, gamma - 1.0).toDouble()) - 1.0) /
          (gamma - 1.0),
    );
  }

  // ── Case 5: A/A* → M (Newton-Raphson, subsonic or supersonic) ────────────
  static double machFromARatio(
    double aRatio,
    double gamma, {
    required bool supersonic,
  }) {
    double m = supersonic ? 2.0 : 0.00001;
    double mNew = m - _fAAstar(m, aRatio, gamma) / _dfAAstar(m, gamma);
    int iter = 0;
    while ((mNew - m).abs() > 1e-7 && iter < 10000) {
      m = mNew;
      mNew = m - _fAAstar(m, aRatio, gamma) / _dfAAstar(m, gamma);
      iter++;
    }
    return mNew;
  }

  static double _fAAstar(double m, double aRatio, double g) {
    final X = 1.0 + 0.5 * (g - 1.0) * m * m;
    return (1.0 / m) *
            pow(
              X / ((g + 1.0) / 2.0),
              (g + 1.0) / (2.0 * (g - 1.0)),
            ).toDouble() -
        aRatio;
  }

  static double _dfAAstar(double m, double g) {
    final temp1 = pow(
      2.0 / (g + 1.0),
      (g + 1.0) / (2.0 * (g - 1.0)),
    ).toDouble();
    final temp2 =
        m *
        m *
        ((g + 1.0) / 2.0) *
        pow(
          1.0 + (g - 1.0) * m * m / 2.0,
          (3.0 - g) / (2.0 * (g - 1.0)),
        ).toDouble();
    final temp3 = pow(
      1.0 + (g - 1.0) * m * m / 2.0,
      (g + 1.0) / (2.0 * (g - 1.0)),
    ).toDouble();
    return temp1 * (temp2 - temp3) / (m * m);
  }

  // ── Case 6: μ → M ────────────────────────────────────────────────────────
  static double machFromMu(double muDeg) {
    return 1.0 / sin(radians(muDeg));
  }

  // ── Case 7: ν → M (Newton-Raphson, always supersonic) ────────────────────
  static double machFromNu(double nuDeg, double gamma) {
    final nuRad = radians(nuDeg);
    double m = 2.0;
    double mOld = 0.0;
    int iter = 0;
    while ((m - mOld).abs() > 1e-7 && iter < 10000) {
      mOld = m;
      m = mOld - (_fNu(mOld, gamma) - nuRad) / _dfNu(mOld, gamma);
      iter++;
    }
    return m;
  }

  static double _fNu(double m, double g) {
    return sqrt((g + 1.0) / (g - 1.0)) *
            atan(sqrt((g - 1.0) * (m * m - 1.0) / (g + 1.0))) -
        atan(sqrt(m * m - 1.0));
  }

  static double _dfNu(double m, double g) {
    return sqrt(m * m - 1.0) / (1.0 + 0.5 * (g - 1.0) * m * m) / m;
  }

  // ── νmax for given γ ──────────────────────────────────────────────────────
  static double nuMax(double gamma) {
    return (sqrt((gamma + 1.0) / (gamma - 1.0)) - 1.0) * 90.0;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static double radians(double deg) => deg * pi / 180.0;
  static double degrees(double rad) => rad * 180.0 / pi;
}

// ─────────────────────────────────────────────
//  Result model
// ─────────────────────────────────────────────
class IsentropicResult {
  final double M;
  final double tRatio;
  final double pRatio;
  final double rhoRatio;
  final double aRatio;
  final double? mu; // null if subsonic
  final double? nu; // null if subsonic

  const IsentropicResult({
    required this.M,
    required this.tRatio,
    required this.pRatio,
    required this.rhoRatio,
    required this.aRatio,
    this.mu,
    this.nu,
  });
}

// ─────────────────────────────────────────────
//  Main Screen Widget
// ─────────────────────────────────────────────
class IsentropicFlowScreen extends StatefulWidget {
  final  VoidCallback? onDrawer;
  const IsentropicFlowScreen({super.key, this.onDrawer});

  @override
  State<IsentropicFlowScreen> createState() => _IsentropicFlowScreenState();
}

class _IsentropicFlowScreenState extends State<IsentropicFlowScreen> {
  // ── Controllers ────────────────────────────────────────────────────────────
  final _gammaCtrl = TextEditingController();
  final _machCtrl = TextEditingController();
  final _tRatioCtrl = TextEditingController();
  final _pRatioCtrl = TextEditingController();
  final _rhoRatioCtrl = TextEditingController();
  final _aRatioCtrl = TextEditingController();
  final _muCtrl = TextEditingController();
  final _nuCtrl = TextEditingController();

  // ── Focus nodes ───────────────────────────────────────────────────────────
  final _gammaFocus = FocusNode();
  final _machFocus = FocusNode();
  final _tRatioFocus = FocusNode();
  final _pRatioFocus = FocusNode();
  final _rhoRatioFocus = FocusNode();
  final _aRatioFocus = FocusNode();
  final _muFocus = FocusNode();
  final _nuFocus = FocusNode();

  // ── State ─────────────────────────────────────────────────────────────────
  double _gamma = 1.4;
  bool _gammaValid = true;
  String? _gammaError;

  _ActiveField _activeField = _ActiveField.none;
  IsentropicResult? _result;

  // Validation error strings per field (null = no error)
  final Map<_ActiveField, String?> _fieldErrors = {};

  // Supersonic toggle (only relevant when A/A* is active)
  bool _isSupersonic = false;

  // Gamma dropdown — currently selected gas name (shown in the button)
  String _selectedGasName = 'Air';

  // Guard against recursive setText calls triggering listeners
  bool _updating = false;

  // Guard: true while user manually toggled sub/sup (suppresses auto-sync in _computeFromMach)
  bool _togglingSupersonic = false;

  final _gammaKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _gammaCtrl.text = '1.4';
    _selectedGasName = 'Air';

    // Focus listeners: when user taps a field, immediately mark it as active
    // so the previous field's active highlight clears right away.
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
    onFocusChange(_ActiveField.aRatio, _aRatioFocus);
    onFocusChange(_ActiveField.mu, _muFocus);
    onFocusChange(_ActiveField.nu, _nuFocus);
  }

  @override
  void dispose() {
    for (final c in [
      _gammaCtrl,
      _machCtrl,
      _tRatioCtrl,
      _pRatioCtrl,
      _rhoRatioCtrl,
      _aRatioCtrl,
      _muCtrl,
      _nuCtrl,
    ]) {
      c.dispose();
    }
    for (final f in [
      _gammaFocus,
      _machFocus,
      _tRatioFocus,
      _pRatioFocus,
      _rhoRatioFocus,
      _aRatioFocus,
      _muFocus,
      _nuFocus,
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

    // Valid gamma — check if it matches a preset gas
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

    // Re-trigger calculation for current active field
    _recalculate();
  }

  // ─────────────────────────────────────────────
  //  Field change handlers — one per field
  // ─────────────────────────────────────────────

  void _onMachChanged(String raw) {
    if (_updating) return;
    _activeField = _ActiveField.mach;
    _clearOtherErrors(_ActiveField.mach);

    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '.') {
      setState(() {
        _fieldErrors[_ActiveField.mach] = null;
        _result = null;
      });
      _clearComputedFields(_ActiveField.mach);
      return;
    }

    final val = double.tryParse(trimmed);
    if (val == null) {
      setState(() {
        _fieldErrors[_ActiveField.mach] = 'Invalid format';
        _result = null;
      });
      _clearComputedFields(_ActiveField.mach);
      return;
    }

    if (val < 0) {
      setState(() {
        _fieldErrors[_ActiveField.mach] = 'Mach number must be ≥ 0';
        _result = null;
      });
      _clearComputedFields(_ActiveField.mach);
      return;
    }

    if (!_gammaValid) {
      setState(() {
        _fieldErrors[_ActiveField.mach] = 'Enter a valid γ first';
        _result = null;
      });
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
    if (trimmed.isEmpty || trimmed == '.') {
      setState(() {
        _fieldErrors[_ActiveField.tRatio] = null;
        _result = null;
      });
      _clearComputedFields(_ActiveField.tRatio);
      return;
    }

    final val = double.tryParse(trimmed);
    if (val == null) {
      setState(() {
        _fieldErrors[_ActiveField.tRatio] = 'Invalid format';
        _result = null;
      });
      _clearComputedFields(_ActiveField.tRatio);
      return;
    }

    if (val <= 0.0 || val >= 1.0) {
      setState(() {
        _fieldErrors[_ActiveField.tRatio] = 'T/T₀ must be between 0 and 1';
        _result = null;
      });
      _clearComputedFields(_ActiveField.tRatio);
      return;
    }

    if (!_gammaValid) {
      setState(() {
        _fieldErrors[_ActiveField.tRatio] = 'Enter a valid γ first';
        _result = null;
      });
      return;
    }

    setState(() => _fieldErrors[_ActiveField.tRatio] = null);
    final M = IsentropicEngine.machFromTRatio(val, _gamma);
    _computeFromMach(M);
  }

  void _onPRatioChanged(String raw) {
    if (_updating) return;
    _activeField = _ActiveField.pRatio;
    _clearOtherErrors(_ActiveField.pRatio);

    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '.') {
      setState(() {
        _fieldErrors[_ActiveField.pRatio] = null;
        _result = null;
      });
      _clearComputedFields(_ActiveField.pRatio);
      return;
    }

    final val = double.tryParse(trimmed);
    if (val == null) {
      setState(() {
        _fieldErrors[_ActiveField.pRatio] = 'Invalid format';
        _result = null;
      });
      _clearComputedFields(_ActiveField.pRatio);
      return;
    }

    if (val <= 0.0 || val >= 1.0) {
      setState(() {
        _fieldErrors[_ActiveField.pRatio] = 'P/P₀ must be between 0 and 1';
        _result = null;
      });
      _clearComputedFields(_ActiveField.pRatio);
      return;
    }

    if (!_gammaValid) {
      setState(() {
        _fieldErrors[_ActiveField.pRatio] = 'Enter a valid γ first';
        _result = null;
      });
      return;
    }

    setState(() => _fieldErrors[_ActiveField.pRatio] = null);
    final M = IsentropicEngine.machFromPRatio(val, _gamma);
    _computeFromMach(M);
  }

  void _onRhoRatioChanged(String raw) {
    if (_updating) return;
    _activeField = _ActiveField.rhoRatio;
    _clearOtherErrors(_ActiveField.rhoRatio);

    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '.') {
      setState(() {
        _fieldErrors[_ActiveField.rhoRatio] = null;
        _result = null;
      });
      _clearComputedFields(_ActiveField.rhoRatio);
      return;
    }

    final val = double.tryParse(trimmed);
    if (val == null) {
      setState(() {
        _fieldErrors[_ActiveField.rhoRatio] = 'Invalid format';
        _result = null;
      });
      _clearComputedFields(_ActiveField.rhoRatio);
      return;
    }

    if (val <= 0.0 || val >= 1.0) {
      setState(() {
        _fieldErrors[_ActiveField.rhoRatio] = 'ρ/ρ₀ must be between 0 and 1';
        _result = null;
      });
      _clearComputedFields(_ActiveField.rhoRatio);
      return;
    }

    if (!_gammaValid) {
      setState(() {
        _fieldErrors[_ActiveField.rhoRatio] = 'Enter a valid γ first';
        _result = null;
      });
      return;
    }

    setState(() => _fieldErrors[_ActiveField.rhoRatio] = null);
    final M = IsentropicEngine.machFromRhoRatio(val, _gamma);
    _computeFromMach(M);
  }

  void _onARatioChanged(String raw) {
    if (_updating) return;
    _activeField = _ActiveField.aRatio;
    _clearOtherErrors(_ActiveField.aRatio);

    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '.') {
      setState(() {
        _fieldErrors[_ActiveField.aRatio] = null;
        _result = null;
      });
      _clearComputedFields(_ActiveField.aRatio);
      return;
    }

    final val = double.tryParse(trimmed);
    if (val == null) {
      setState(() {
        _fieldErrors[_ActiveField.aRatio] = 'Invalid format';
        _result = null;
      });
      _clearComputedFields(_ActiveField.aRatio);
      return;
    }

    if (val < 1.0) {
      setState(() {
        _fieldErrors[_ActiveField.aRatio] = 'A/A* must be ≥ 1';
        _result = null;
      });
      _clearComputedFields(_ActiveField.aRatio);
      return;
    }

    if (!_gammaValid) {
      setState(() {
        _fieldErrors[_ActiveField.aRatio] = 'Enter a valid γ first';
        _result = null;
      });
      return;
    }

    setState(() => _fieldErrors[_ActiveField.aRatio] = null);
    final M = IsentropicEngine.machFromARatio(
      val,
      _gamma,
      supersonic: _isSupersonic,
    );
    _computeFromMach(M);
  }

  void _onMuChanged(String raw) {
    if (_updating) return;
    _activeField = _ActiveField.mu;
    _clearOtherErrors(_ActiveField.mu);

    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '.') {
      setState(() {
        _fieldErrors[_ActiveField.mu] = null;
        _result = null;
      });
      _clearComputedFields(_ActiveField.mu);
      return;
    }

    final val = double.tryParse(trimmed);
    if (val == null) {
      setState(() {
        _fieldErrors[_ActiveField.mu] = 'Invalid format';
        _result = null;
      });
      _clearComputedFields(_ActiveField.mu);
      return;
    }

    if (val <= 0.0 || val >= 90.0) {
      setState(() {
        _fieldErrors[_ActiveField.mu] =
            'Mach angle μ must be between 0° and 90°';
        _result = null;
      });
      _clearComputedFields(_ActiveField.mu);
      return;
    }

    if (!_gammaValid) {
      setState(() {
        _fieldErrors[_ActiveField.mu] = 'Enter a valid γ first';
        _result = null;
      });
      return;
    }

    setState(() => _fieldErrors[_ActiveField.mu] = null);
    final M = IsentropicEngine.machFromMu(val);
    _computeFromMach(M);
  }

  void _onNuChanged(String raw) {
    if (_updating) return;
    _activeField = _ActiveField.nu;
    _clearOtherErrors(_ActiveField.nu);

    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '.') {
      setState(() {
        _fieldErrors[_ActiveField.nu] = null;
        _result = null;
      });
      _clearComputedFields(_ActiveField.nu);
      return;
    }

    final val = double.tryParse(trimmed);
    if (val == null) {
      setState(() {
        _fieldErrors[_ActiveField.nu] = 'Invalid format';
        _result = null;
      });
      _clearComputedFields(_ActiveField.nu);
      return;
    }

    final maxNu = IsentropicEngine.nuMax(_gamma);
    if (val < 0.0 || val > maxNu) {
      setState(() {
        _fieldErrors[_ActiveField.nu] =
            'ν must be between 0° and ${_fmt(maxNu)}°';
        _result = null;
      });
      _clearComputedFields(_ActiveField.nu);
      return;
    }

    if (!_gammaValid) {
      setState(() {
        _fieldErrors[_ActiveField.nu] = 'Enter a valid γ first';
        _result = null;
      });
      return;
    }

    setState(() => _fieldErrors[_ActiveField.nu] = null);
    final M = IsentropicEngine.machFromNu(val, _gamma);
    _computeFromMach(M);
  }

  // ─────────────────────────────────────────────
  //  Core compute dispatcher
  // ─────────────────────────────────────────────
  void _computeFromMach(double M) {
    final data = IsentropicEngine.fromMach(M, _gamma);
    final result = IsentropicResult(
      M: data['M']!,
      tRatio: data['tRatio']!,
      pRatio: data['pRatio']!,
      rhoRatio: data['rhoRatio']!,
      aRatio: data['aRatio']!,
      mu: data['mu'],
      nu: data['nu'],
    );

    // Update the supersonic toggle based on computed Mach
    // Suppressed when the user manually toggled (to avoid overwriting their choice)
    if (!_togglingSupersonic) {
      _isSupersonic = M >= 1.0;
    }

    setState(() => _result = result);
    _writeComputedFields();
  }

  void _recalculate() {
    // Re-run calculation for whatever field is currently active
    if (_activeField == _ActiveField.none) return;
    switch (_activeField) {
      case _ActiveField.mach:
        _onMachChanged(_machCtrl.text);
      case _ActiveField.tRatio:
        _onTRatioChanged(_tRatioCtrl.text);
      case _ActiveField.pRatio:
        _onPRatioChanged(_pRatioCtrl.text);
      case _ActiveField.rhoRatio:
        _onRhoRatioChanged(_rhoRatioCtrl.text);
      case _ActiveField.aRatio:
        _onARatioChanged(_aRatioCtrl.text);
      case _ActiveField.mu:
        _onMuChanged(_muCtrl.text);
      case _ActiveField.nu:
        _onNuChanged(_nuCtrl.text);
      case _ActiveField.none:
        break;
    }
  }

  // ─────────────────────────────────────────────
  //  Write computed values to all non-active fields
  // ─────────────────────────────────────────────
  void _writeComputedFields() {
    if (_result == null) return;
    _updating = true;

    void setIfNotActive(
      _ActiveField field,
      TextEditingController ctrl,
      String Function() value,
    ) {
      if (_activeField != field) {
        ctrl.text = value();
      }
    }

    final r = _result!;
    setIfNotActive(_ActiveField.mach, _machCtrl, () => _fmt(r.M));
    setIfNotActive(_ActiveField.tRatio, _tRatioCtrl, () => _fmt(r.tRatio));
    setIfNotActive(_ActiveField.pRatio, _pRatioCtrl, () => _fmt(r.pRatio));
    setIfNotActive(
      _ActiveField.rhoRatio,
      _rhoRatioCtrl,
      () => _fmt(r.rhoRatio),
    );
    setIfNotActive(_ActiveField.aRatio, _aRatioCtrl, () => _fmt(r.aRatio));

    if (_activeField != _ActiveField.mu) {
      _muCtrl.text = r.mu != null ? _fmt(r.mu!) : '—';
    }
    if (_activeField != _ActiveField.nu) {
      _nuCtrl.text = r.nu != null ? _fmt(r.nu!) : '—';
    }

    _updating = false;
  }

  // ─────────────────────────────────────────────
  //  Clear computed outputs when input is invalid/empty
  // ─────────────────────────────────────────────
  void _clearComputedFields(_ActiveField keepField) {
    _updating = true;
    void clearIfNotActive(_ActiveField field, TextEditingController ctrl) {
      if (field != keepField) ctrl.clear();
    }

    clearIfNotActive(_ActiveField.mach, _machCtrl);
    clearIfNotActive(_ActiveField.tRatio, _tRatioCtrl);
    clearIfNotActive(_ActiveField.pRatio, _pRatioCtrl);
    clearIfNotActive(_ActiveField.rhoRatio, _rhoRatioCtrl);
    clearIfNotActive(_ActiveField.aRatio, _aRatioCtrl);
    if (keepField != _ActiveField.mu) _muCtrl.clear();
    if (keepField != _ActiveField.nu) _nuCtrl.clear();
    _updating = false;
  }

  void _clearOtherErrors(_ActiveField keep) {
    for (final f in _ActiveField.values) {
      if (f != keep) _fieldErrors.remove(f);
    }
  }

  // ─────────────────────────────────────────────
  //  Supersonic toggle handler (for A/A* case)
  // ─────────────────────────────────────────────
  void _onToggleSupersonic(bool val) {
    // If no result yet (all fields empty), just update the flag and return
    if (_result == null) {
      setState(() => _isSupersonic = val);
      return;
    }
    // Use the guard to prevent _computeFromMach from overwriting the user's toggle choice
    _togglingSupersonic = true;
    setState(() {
      _isSupersonic = val;
      _activeField = _ActiveField.aRatio;
    });
    _onARatioChanged(_aRatioCtrl.text);
    _togglingSupersonic = false;
  }

  // ─────────────────────────────────────────────
  //  Format helper
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

  // ─────────────────────────────────────────────
  //  HandyCalc dialog
  // ─────────────────────────────────────────────
  void _openHandyCalc({
    required String title,
    required String label1, // e.g. "T"
    required String label2, // e.g. "T₀"
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
      _activeField = _ActiveField.none;
      _result = null;
      _fieldErrors.clear();
      _isSupersonic = false;
    });
    _updating = true;
    _machCtrl.clear();
    _tRatioCtrl.clear();
    _pRatioCtrl.clear();
    _rhoRatioCtrl.clear();
    _aRatioCtrl.clear();
    _muCtrl.clear();
    _nuCtrl.clear();
    _updating = false;
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
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
                onPressed: widget.onDrawer ?? () {}
 // wire to  nav drawer
              ),
              const Expanded(
                child: Text(
                  'Isentropic Flow',
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
      'isentropic flow properties. Tap a ratio label (T/T₀, P/P₀ …) to '
      'convert between static and stagnation values.',
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
              // Label row
              Row(
                children: [
                  const Text(
                    'γ  (Gamma)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _C.fieldLabel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              // Gamma field + dropdown button
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      key: _gammaKey,
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

  // ── Fields card (all 7 flow properties) ──────────────────────────────────
  Widget _buildFieldsCard() {
    final r = _result;
    final bool hasResult = r != null;
    final bool isSupersonic = hasResult && r.M >= 1.0;

    return _Card(
      header: _cardHeader(Icons.calculate_outlined, 'FLOW PROPERTIES'),
      children: [
        // ── Mach number ────────────────────────────────────────────────────
        _flowField(
          field: _ActiveField.mach,
          label: 'Mach Number',
          symbol: 'M',
          controller: _machCtrl,
          focusNode: _machFocus,
          hintText: 'Enter M (≥ 0)',
          subHint: 'Any non-negative value',
          onChanged: _onMachChanged,
          error: _fieldErrors[_ActiveField.mach],
        ),

        _divider(),

        // ── T/T₀ ──────────────────────────────────────────────────────────
        _flowField(
          field: _ActiveField.tRatio,
          label: 'Temperature Ratio',
          symbol: 'T/T₀',
          controller: _tRatioCtrl,
          focusNode: _tRatioFocus,
          hintText: 'Enter T/T₀',
          subHint: 'Between 0 and 1',
          onChanged: _onTRatioChanged,
          error: _fieldErrors[_ActiveField.tRatio],
          onLabelTap: hasResult
              ? () => _openHandyCalc(
                  title: 'T/T₀ = ${_fmt(r.tRatio)}',
                  label1: 'T  =',
                  label2: 'T₀ =',
                  ratio: r.tRatio,
                )
              : null,
        ),

        _divider(),

        // ── P/P₀ ──────────────────────────────────────────────────────────
        _flowField(
          field: _ActiveField.pRatio,
          label: 'Pressure Ratio',
          symbol: 'P/P₀',
          controller: _pRatioCtrl,
          focusNode: _pRatioFocus,
          hintText: 'Enter P/P₀',
          subHint: 'Between 0 and 1',
          onChanged: _onPRatioChanged,
          error: _fieldErrors[_ActiveField.pRatio],
          onLabelTap: hasResult
              ? () => _openHandyCalc(
                  title: 'P/P₀ = ${_fmt(r.pRatio)}',
                  label1: 'P  =',
                  label2: 'P₀ =',
                  ratio: r.pRatio,
                )
              : null,
        ),

        _divider(),

        // ── ρ/ρ₀ ──────────────────────────────────────────────────────────
        _flowField(
          field: _ActiveField.rhoRatio,
          label: 'Density Ratio',
          symbol: 'ρ/ρ₀',
          controller: _rhoRatioCtrl,
          focusNode: _rhoRatioFocus,
          hintText: 'Enter ρ/ρ₀',
          subHint: 'Between 0 and 1',
          onChanged: _onRhoRatioChanged,
          error: _fieldErrors[_ActiveField.rhoRatio],
          onLabelTap: hasResult
              ? () => _openHandyCalc(
                  title: 'ρ/ρ₀ = ${_fmt(r.rhoRatio)}',
                  label1: 'ρ  =',
                  label2: 'ρ₀ =',
                  ratio: r.rhoRatio,
                )
              : null,
        ),

        _divider(),

        // ── A/A* with subsonic/supersonic toggle ──────────────────────────
        _flowField(
          field: _ActiveField.aRatio,
          label: 'Area Ratio',
          symbol: 'A/A*',
          controller: _aRatioCtrl,
          focusNode: _aRatioFocus,
          hintText: 'Enter A/A* (≥ 1)',
          subHint: 'Must be ≥ 1',
          onChanged: _onARatioChanged,
          error: _fieldErrors[_ActiveField.aRatio],
          onLabelTap: hasResult
              ? () => _openHandyCalc(
                  title: 'A/A* = ${_fmt(r.aRatio)}',
                  label1: 'A  =',
                  label2: 'A* =',
                  ratio: r.aRatio,
                )
              : null,
          // Always show the sub/sup toggle on the A/A* row
          trailing: _SupersonicToggle(
            isSupersonic: _isSupersonic,
            onChanged: _onToggleSupersonic,
          ),
        ),

        _divider(),

        // ── Mach angle μ ──────────────────────────────────────────────────
        _flowField(
          field: _ActiveField.mu,
          label: 'Mach Angle',
          symbol: 'μ  (°)',
          controller: _muCtrl,
          focusNode: _muFocus,
          hintText: '0° to 90°',
          subHint: 'Supersonic only — between 0° and 90°',
          onChanged: _onMuChanged,
          error: _fieldErrors[_ActiveField.mu],
        ),

        _divider(),

        // ── Prandtl-Meyer angle ν ────────────────────────────────────────
        _flowField(
          field: _ActiveField.nu,
          label: 'Prandtl-Meyer Angle',
          symbol: 'ν  (°)',
          controller: _nuCtrl,
          focusNode: _nuFocus,
          hintText: '0° to νmax',
          subHint:
              'Supersonic only — max = ${_fmt(IsentropicEngine.nuMax(_gamma))}°',
          onChanged: _onNuChanged,
          error: _fieldErrors[_ActiveField.nu],
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
              'Subscript \'0\' denotes stagnation (total) quantities. '
              'Superscript \'*\' denotes the sonic throat condition.\n'
              'μ and ν are defined only for supersonic flow (M ≥ 1). '
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

  /// A single flow-property field row.
  Widget _flowField({
    required _ActiveField field,
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
    bool dimmed = false,
  }) {
    final isActive = _activeField == field;
    final isComputed =
        _activeField != _ActiveField.none && !isActive && _result != null;

    return Opacity(
      opacity: dimmed ? 0.45 : 1.0,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, isLast ? 16 : 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label row
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
            // Input field — style changes when computed vs active
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
      ),
    );
  }

  /// Styled text field — shared by gamma and flow property fields.
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
    // Use ListenableBuilder on the focusNode so the border reacts to focus
    // changes without wrapping in a Focus widget (which would try to make the
    // node a parent of itself when also passed to TextField).
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

  // ─────────────────────────────────────────────
  //  Info dialog
  // ─────────────────────────────────────────────
  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _C.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Isentropic Flow',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _C.headerBg,
          ),
        ),
        content: const Text(
          '1. Subscript \'0\' → stagnation (total) quantity.\n'
          '2. Superscript \'*\' → isentropic sonic throat state.\n'
          '3. γ (gamma) is required; tap the gas button to pick a preset.\n'
          '4. Enter any one of M, T/T₀, P/P₀, ρ/ρ₀, A/A*, μ or ν to instantly '
          'compute all remaining properties.\n'
          '5. For A/A*, use the Subsonic / Supersonic toggle to select '
          'which solution branch to compute.\n'
          '6. μ and ν are only defined for supersonic flow (M ≥ 1).\n'
          '7. Tap any ratio label (e.g. T/T₀) to open HandyCalc for '
          'converting between static and stagnation absolute values.',
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
//  Subsonic / Supersonic toggle widget
// ─────────────────────────────────────────────
class _SupersonicToggle extends StatelessWidget {
  const _SupersonicToggle({
    required this.isSupersonic,
    required this.onChanged,
  });

  final bool isSupersonic;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _label('Sub', !isSupersonic),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => onChanged(!isSupersonic),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: isSupersonic ? _C.toggleActive : _C.toggleInactive,
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: isSupersonic
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.all(2),
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        _label('Sup', isSupersonic),
      ],
    );
  }

  Widget _label(String text, bool active) => Text(
    text,
    style: TextStyle(
      fontSize: 10,
      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
      color: active ? _C.toggleActive : _C.toggleInactive,
    ),
  );
}

// ─────────────────────────────────────────────
//  Flow regime badge (displayed when reading from another input)
// ─────────────────────────────────────────────
class _FlowRegimeBadge extends StatelessWidget {
  const _FlowRegimeBadge({required this.supersonic});
  final bool supersonic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: supersonic
            ? const Color(0xFFFF6B0020)
            : const Color(0xFF18397C20),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: supersonic ? const Color(0xFFFF6B00) : _C.headerBg,
          width: 0.8,
        ),
      ),
      child: Text(
        supersonic ? 'Supersonic' : 'Subsonic',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: supersonic ? const Color(0xFFFF6B00) : _C.headerBg,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Gas dropdown button
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
//  HandyCalc Dialog
//  Given ratio R, lets user type either the
//  numerator (→ computes denominator) or
//  denominator (→ computes numerator)
// ─────────────────────────────────────────────
class _HandyCalcDialog extends StatefulWidget {
  const _HandyCalcDialog({
    required this.title,
    required this.label1,
    required this.label2,
    required this.ratio,
  });

  final String title;
  final String label1; // numerator label e.g. "T ="
  final String label2; // denominator label e.g. "T₀ ="
  final double ratio;

  @override
  State<_HandyCalcDialog> createState() => _HandyCalcDialogState();
}

class _HandyCalcDialogState extends State<_HandyCalcDialog> {
  final _ctrl1 = TextEditingController(); // numerator
  final _ctrl2 = TextEditingController(); // denominator
  bool _updating = false;
  String? _error1; // error for numerator
  String? _error2; // error for denominator

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
    // numerator / ratio = denominator
    _updating = true;
    _ctrl2.text = _fmt(val / widget.ratio);
    _updating = false;
    setState(() {
      _error1 = null;
      _error2 = null; // Clear both errors
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
    // denominator * ratio = numerator
    _updating = true;
    _ctrl1.text = _fmt(val * widget.ratio);
    _updating = false;
    setState(() {
      _error1 = null;
      _error2 = null; // Clear both errors
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
            _errorText(_error1!),
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
            _errorText(_error2!),
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

  Widget _handyRow(
    String label,
    TextEditingController ctrl,
    ValueChanged<String> onChanged,
    String? error,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 42,
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
//  Reusable Card  (same style as SA page)
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
/* void main() {
  runApp(const _IsentropicApp());
}

class _IsentropicApp extends StatelessWidget {
  const _IsentropicApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Isentropic Flow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D1F3C)),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const IsentropicFlowScreen(),
    );
  }
} */