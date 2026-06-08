import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'isentropic_flow.dart';
import 'normal_shock.dart';
import 'fanno_flow.dart';
import 'rayleigh_flow.dart';
import '../utils/responsive.dart';

// ─────────────────────────────────────────────
//  Colour tokens
// ─────────────────────────────────────────────
class _C {
  static const headerBg = Color(0xFF18397C);
  static const labelSmall = Color(0xFF6B7280);
  static const drawerBg = Color(0xFFF4F6FB); // light blue-grey bg
  static const drawerActiveBg = Color(0xFF18397C); // navy — active pill
  static const drawerActiveText = Colors.white;
  static const drawerInactiveText = Color(0xFF374151); // dark grey — readable
  static const drawerDivider = Color(0xFFD1D9EC); // soft blue-grey line
  static const drawerHeaderText = Color(0xFF0D1F3C); // near-black header
  static const drawerItemBg = Color(0xFFE8EDF7); // pale blue inactive pill
}

// ─────────────────────────────────────────────
//  Page enum
// ─────────────────────────────────────────────
enum _Page { isentropicFlow, normalShock, fannoFlow, rayleighFlow }

extension _PageInfo on _Page {
  String get title {
    switch (this) {
      case _Page.isentropicFlow:
        return 'Isentropic Flow';
      case _Page.normalShock:
        return 'Normal Shock';
      case _Page.fannoFlow:
        return 'Fanno Flow';
      case _Page.rayleighFlow:
        return 'Rayleigh Flow';
    }
  }
}

// ─────────────────────────────────────────────
//  HomePage
// ─────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  _Page _currentPage = _Page.isentropicFlow;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final Map<_Page, GlobalKey> _pageKeys = {
    _Page.isentropicFlow: GlobalKey(),
    _Page.normalShock: GlobalKey(),
    _Page.fannoFlow: GlobalKey(),
    _Page.rayleighFlow: GlobalKey(),
  };

  void _selectPage(_Page page) {
    setState(() => _currentPage = page);
    _scaffoldKey.currentState?.closeDrawer();
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  Widget _buildBody() {
    switch (_currentPage) {
      case _Page.isentropicFlow:
        return IsentropicFlowScreen(
          key: _pageKeys[_Page.isentropicFlow],
          onDrawer: _openDrawer,
        );
      case _Page.normalShock:
        return NormalShockScreen(
          key: _pageKeys[_Page.normalShock],
          onDrawer: _openDrawer,
        );
      case _Page.fannoFlow:
        return FannoFlowScreen(
          key: _pageKeys[_Page.fannoFlow],
          onDrawer: _openDrawer,
        );
      case _Page.rayleighFlow:
        return RayleighFlowScreen(
          key: _pageKeys[_Page.rayleighFlow],
          onDrawer: _openDrawer,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _AppDrawer(currentPage: _currentPage, onSelect: _selectPage),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: KeyedSubtree(key: ValueKey(_currentPage), child: _buildBody()),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Drawer
// ─────────────────────────────────────────────
class _AppDrawer extends StatelessWidget {
  const _AppDrawer({required this.currentPage, required this.onSelect});
  final _Page currentPage;
  final ValueChanged<_Page> onSelect;

  @override
  Widget build(BuildContext context) {
    
    return Drawer(
      backgroundColor: _C.drawerBg,
      width: Responsive.wp(context, 272),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                Responsive.pad(context, 20),
                Responsive.pad(context, 24),
                Responsive.pad(context, 20),
                Responsive.pad(context, 8),
              ),
              child: Row(
                children: [
                  Image.asset(
                    'lib/images/cftk.png',
                    width: Responsive.wp(context, 38),
                    height: Responsive.wp(context, 38),
                    fit: BoxFit.contain,
                  ),
                  SizedBox(width: Responsive.wp(context, 12)),
                  Text(
                    'Compressible Flow\nToolkit',
                    style: TextStyle(
                      color: _C.drawerHeaderText,
                      fontSize: Responsive.sp(context, 13.5),
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: Responsive.hp(context, 12)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Responsive.pad(context, 16)),
              child: Container(height: 0.5, color: _C.drawerDivider),
            ),
            SizedBox(height: Responsive.hp(context, 12)),

            // ── Section label ────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                Responsive.pad(context, 20),
                0,
                Responsive.pad(context, 20),
                Responsive.pad(context, 8),
              ),
              child: Text(
                'FLOW TYPES',
                style: TextStyle(
                  color: _C.labelSmall,
                  fontSize: Responsive.sp(context, 10.5),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            // ── Nav items ────────────────────────────────────────────────────
            ..._Page.values.map(
              (page) => _DrawerItem(
                page: page,
                isActive: currentPage == page,
                onTap: () => onSelect(page),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Drawer item  — no icons, no subtitles
// ─────────────────────────────────────────────
class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.page,
    required this.isActive,
    required this.onTap,
  });
  final _Page page;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: EdgeInsets.fromLTRB(
          Responsive.pad(context, 12),
          Responsive.pad(context, 3),
          Responsive.pad(context, 12),
          Responsive.pad(context, 3),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.pad(context, 16),
          vertical: Responsive.pad(context, 13),
        ),
        decoration: BoxDecoration(
          color: isActive ? _C.drawerActiveBg : _C.drawerItemBg,
          borderRadius: BorderRadius.circular(Responsive.wp(context, 8)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                page.title,
                style: TextStyle(
                  fontSize: Responsive.sp(context, 14),
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? _C.drawerActiveText : _C.drawerInactiveText,
                ),
              ),
            ),
            if (isActive)
              Container(
                width: Responsive.wp(context, 6),
                height: Responsive.wp(context, 6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Entry point
// ─────────────────────────────────────────────
void main() {
  runApp(
    DevicePreview(
      enabled: true,
      builder: (context) => const _App(),
    ),
  );
}

class _App extends StatelessWidget {
  const _App();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Compressible Flow Toolkit',
      debugShowCheckedModeBanner: false,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D1F3C)),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HomePage(),
    );
  }
}