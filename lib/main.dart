import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const SmartEcoHomeApp());
}

// =============================================================================
// KONSTANTA & DATA SIMULASI
// =============================================================================
const double _co2GramPerWatt = 0.85; // gram CO2 per Watt per jam (asumsi)
const double _gaugeMax = 1600; // batas skala gauge (Watt)
const double _deviceW = 84;
const double _deviceH = 100;
const double _targetSaving = 60; // target hemat (%)
const Color _green = Color(0xFF69F0AE);

// Tarif simulasi (Rp per kWh, perkiraan)
const List<int> _tariffs = [1352, 1444, 1699];

// Konsumsi mingguan (kWh) dan profil beban 24 jam (Watt) - data simulasi
const List<double> _weeklyKwh = [4.2, 3.8, 4.6, 5.1, 3.9, 4.4, 3.5];
const List<String> _dayShort = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const List<int> _hourlyWatt = [
  180, 160, 150, 150, 170, 260, 420, 560, 480, 390, 350, 380,
  520, 540, 430, 400, 450, 620, 880, 950, 820, 640, 420, 260,
];

const List<String> _tips = [
  'Matikan perangkat yang tidak dipakai. Mode siaga (standby) tetap menarik daya listrik.',
  'Atur AC pada suhu sedang (24-25 C) agar konsumsi listrik tidak berlebihan.',
  'Isi daya kendaraan listrik saat panel surya produktif (siang hari) untuk mengurangi beban PLN.',
  'Ganti lampu lama dengan lampu LED karena jauh lebih hemat energi.',
];

String _rupiah(int n) => n
    .toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');

// =============================================================================
// MODEL
// =============================================================================
class _Device {
  _Device({
    required this.name,
    required this.icon,
    required this.watt,
    required this.pos,
    required this.active,
    this.isSource = false,
  });

  final String name;
  final IconData icon;
  final int watt;
  final bool isSource; // true = penghasil energi (panel surya)
  Offset pos; // diubah oleh Drag/Pan
  bool active; // diubah oleh Tap
}

List<_Device> _initialDevices() => [
      _Device(
          name: 'Lampu',
          icon: Icons.lightbulb,
          watt: 20,
          pos: const Offset(14, 24),
          active: true),
      _Device(
          name: 'AC Smart',
          icon: Icons.ac_unit,
          watt: 400,
          pos: const Offset(116, 24),
          active: true),
      _Device(
          name: 'Kulkas',
          icon: Icons.kitchen,
          watt: 150,
          pos: const Offset(218, 24),
          active: true),
      _Device(
          name: 'EV Charger',
          icon: Icons.ev_station,
          watt: 1000,
          pos: const Offset(40, 190),
          active: false),
      _Device(
          name: 'Panel Surya',
          icon: Icons.solar_power,
          watt: 300,
          pos: const Offset(190, 190),
          active: true,
          isSource: true),
    ];

class _Scene {
  const _Scene(this.name, this.icon, this.desc, this.on, this.eco);

  final String name;
  final IconData icon;
  final String desc;
  final Set<String> on; // nama perangkat yang menyala
  final bool eco;
}

const List<_Scene> _scenes = [
  _Scene('Pagi', Icons.wb_twilight, 'Lampu, kulkas, dan panel surya aktif.',
      {'Lampu', 'Kulkas', 'Panel Surya'}, false),
  _Scene('Pulang', Icons.home, 'Semua perangkat aktif, termasuk EV Charger.',
      {'Lampu', 'AC Smart', 'Kulkas', 'EV Charger', 'Panel Surya'}, false),
  _Scene('Tidur', Icons.bedtime, 'AC dan kulkas aktif dengan Eco Mode.',
      {'AC Smart', 'Kulkas', 'Panel Surya'}, true),
  _Scene('Keluar', Icons.exit_to_app, 'Hanya kulkas yang aktif, Eco Mode ON.',
      {'Kulkas', 'Panel Surya'}, true),
  _Scene('Hemat Max', Icons.savings, 'Lampu dan kulkas saja, Eco Mode ON.',
      {'Lampu', 'Kulkas', 'Panel Surya'}, true),
];

class _Alert {
  const _Alert(this.title, this.body, this.icon, this.color);

  final String title;
  final String body;
  final IconData icon;
  final Color color;
}

// =============================================================================
// ROOT APP
// =============================================================================
class SmartEcoHomeApp extends StatelessWidget {
  const SmartEcoHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ITPLN Eco-Home Pro',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// =============================================================================
// SPLASH SCREEN
// =============================================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (context, animation, secondary) => const EcoHomeShell(),
          transitionsBuilder: (context, animation, secondary, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF041A1F), Color(0xFF0A2E34)],
          ),
        ),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (context, v, child) => Opacity(
              opacity: v,
              child: Transform.scale(scale: 0.7 + 0.3 * v, child: child),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1DE9B6).withValues(alpha: 0.15),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1DE9B6).withValues(alpha: 0.4),
                        blurRadius: 40,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.bolt,
                      size: 64, color: Color(0xFF1DE9B6)),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Eco-Home Pro',
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8),
                ),
                const SizedBox(height: 6),
                const Text(
                  'SDG 7  •  Energi Bersih & Terjangkau',
                  style: TextStyle(fontSize: 12, color: Colors.white60),
                ),
                const SizedBox(height: 36),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                      strokeWidth: 3, color: Color(0xFF1DE9B6)),
                ),
                const SizedBox(height: 40),
                const Text('ITPLN',
                    style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 4,
                        color: Colors.white38,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SHELL UTAMA (BOTTOM NAVIGATION + SEMUA STATE LOKAL)
// =============================================================================
class EcoHomeShell extends StatefulWidget {
  const EcoHomeShell({super.key});

  @override
  State<EcoHomeShell> createState() => _EcoHomeShellState();
}

class _EcoHomeShellState extends State<EcoHomeShell> {
  // ---------------------------------------------------------------------------
  // STATE LOKAL (SEMUA DIKELOLA DENGAN setState)
  // ---------------------------------------------------------------------------
  int _tab = 0;
  bool _isPowerOn = true;
  bool _isEcoSaver = false;
  bool _notifOn = true;
  bool _haptics = true;
  double _sunIntensity = 0.8; // 0.0 - 1.0 (slider kustom)
  int _tariffIndex = 1;
  int _tipIndex = 0;
  bool _statsWeekly = false;
  int _selectedDay = 6;
  int _selectedHour = DateTime.now().hour;
  String? _activeScene;
  _Device? _dragging;
  List<_Device> _devices = _initialDevices();

  final PageController _tipController = PageController(viewportFraction: 0.92);

  @override
  void dispose() {
    _tipController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // PERHITUNGAN ENERGI
  // ---------------------------------------------------------------------------
  double get _tariffPerWatt => _tariffs[_tariffIndex] / 1000.0;

  int _deviceOutput(_Device d) =>
      d.isSource ? (d.watt * _sunIntensity).round() : d.watt;

  int get _baseLoad => _devices
      .where((d) => d.active && !d.isSource)
      .fold<int>(0, (sum, d) => sum + d.watt);

  int get _loadWatt {
    if (!_isPowerOn) return 0;
    return _isEcoSaver ? (_baseLoad * 0.6).round() : _baseLoad;
  }

  int get _solarWatt {
    if (!_isPowerOn) return 0;
    return _devices
        .where((d) => d.active && d.isSource)
        .fold<int>(0, (sum, d) => sum + _deviceOutput(d));
  }

  int get _solarUsed => math.min(_solarWatt, _loadWatt);
  int get _gridWatt => _loadWatt - _solarUsed;
  int get _costPerHour => (_gridWatt * _tariffPerWatt).round();
  int get _co2PerHour => (_gridWatt * _co2GramPerWatt).round();

  int get _savedWatt =>
      _isPowerOn ? math.max(0, _baseLoad - _gridWatt) : 0;

  int get _savingPercent {
    if (!_isPowerOn || _baseLoad == 0) return 0;
    return (_savedWatt / _baseLoad * 100).round();
  }

  int get _greenPercent {
    if (_loadWatt == 0) return 0;
    return (_solarUsed / _loadWatt * 100).round();
  }

  int get _activeCount => _devices.where((d) => d.active).length;

  // ---------------------------------------------------------------------------
  // PERINGATAN (DIHITUNG DARI STATE)
  // ---------------------------------------------------------------------------
  List<_Alert> get _alerts {
    final list = <_Alert>[];
    if (!_isPowerOn) {
      list.add(const _Alert(
        'Power utama mati',
        'Seluruh perangkat tidak mendapat listrik. Ketuk kartu status untuk menyalakan.',
        Icons.power_off,
        Colors.redAccent,
      ));
      return list;
    }
    if (_loadWatt > 1200) {
      list.add(_Alert(
        'Beban tinggi',
        'Total beban $_loadWatt W melebihi 1.200 W. Pertimbangkan Eco Mode atau matikan perangkat besar.',
        Icons.warning_amber_rounded,
        Colors.orangeAccent,
      ));
    }
    final ev = _devices.firstWhere((d) => d.name == 'EV Charger');
    if (ev.active) {
      list.add(const _Alert(
        'EV Charger aktif',
        'Pengisian kendaraan menarik 1.000 W. Idealnya dilakukan saat panel surya optimal.',
        Icons.ev_station,
        Colors.amber,
      ));
    }
    if (_solarWatt > _loadWatt && _solarWatt > 0) {
      list.add(_Alert(
        'Surplus energi surya',
        'Panel surya menghasilkan ${_solarWatt - _loadWatt} W lebih banyak dari kebutuhan rumah.',
        Icons.wb_sunny,
        _green,
      ));
    }
    if (!_isEcoSaver && _gridWatt > 300) {
      list.add(const _Alert(
        'Saran hemat energi',
        'Aktifkan Eco Mode untuk menurunkan estimasi beban sebesar 40%.',
        Icons.eco,
        Color(0xFF1DE9B6),
      ));
    }
    return list;
  }

  // ---------------------------------------------------------------------------
  // WARNA DINAMIS
  // ---------------------------------------------------------------------------
  Color get _accent => !_isPowerOn
      ? Colors.redAccent
      : (_isEcoSaver ? _green : const Color(0xFF1DE9B6));

  List<Color> get _bgColors => !_isPowerOn
      ? const [Color(0xFF141414), Color(0xFF2A2A2A)]
      : (_isEcoSaver
          ? const [Color(0xFF04210F), Color(0xFF0B3B24)]
          : const [Color(0xFF041A1F), Color(0xFF0A2E34)]);

  Color get _gaugeColor {
    if (!_isPowerOn) return Colors.grey;
    final f = _loadWatt / _gaugeMax;
    if (f < 0.4) return _green;
    if (f < 0.75) return Colors.amberAccent;
    return Colors.redAccent;
  }

  // ---------------------------------------------------------------------------
  // AKSI
  // ---------------------------------------------------------------------------
  void _tick() {
    if (_haptics) HapticFeedback.selectionClick();
  }

  void _impact() {
    if (_haptics) HapticFeedback.mediumImpact();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF263238),
          content: Text(msg),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Offset _clampPos(Offset p, Size area) {
    final maxX = math.max(0.0, area.width - _deviceW);
    final maxY = math.max(0.0, area.height - _deviceH);
    return Offset(
      math.max(0.0, math.min(maxX, p.dx)),
      math.max(0.0, math.min(maxY, p.dy)),
    );
  }

  void _togglePower() {
    _tick();
    setState(() => _isPowerOn = !_isPowerOn);
  }

  void _toggleEco() {
    _tick();
    setState(() {
      _isEcoSaver = !_isEcoSaver;
      _activeScene = null;
    });
  }

  void _toggleDevice(_Device d) {
    if (!_isPowerOn) {
      _snack('Power utama mati. Ketuk kartu status untuk menyalakan.');
      return;
    }
    _tick();
    setState(() {
      d.active = !d.active;
      _activeScene = null;
    });
  }

  void _setAll(bool value) {
    _tick();
    setState(() {
      if (value) _isPowerOn = true;
      for (final d in _devices) {
        d.active = value;
      }
      _activeScene = null;
    });
    _snack(value ? 'Semua perangkat dinyalakan.' : 'Semua perangkat dimatikan.');
  }

  void _applyScene(_Scene s) {
    _tick();
    setState(() {
      _isPowerOn = true;
      _isEcoSaver = s.eco;
      for (final d in _devices) {
        d.active = s.on.contains(d.name);
      }
      _activeScene = s.name;
    });
    _snack('Skenario "${s.name}" diterapkan.');
  }

  void _resetLayout() {
    final defaults = _initialDevices();
    setState(() {
      for (final d in _devices) {
        d.pos = defaults.firstWhere((x) => x.name == d.name).pos;
      }
    });
    _snack('Posisi denah dikembalikan.');
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset semua?'),
        content: const Text(
            'Perangkat, posisi denah, dan pengaturan simulasi akan dikembalikan ke kondisi awal.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reset')),
        ],
      ),
    );
    if (ok == true && mounted) {
      setState(() {
        _devices = _initialDevices();
        _isPowerOn = true;
        _isEcoSaver = false;
        _sunIntensity = 0.8;
        _tariffIndex = 1;
        _activeScene = null;
      });
      _snack('Semua pengaturan dikembalikan.');
    }
  }

  // ---------------------------------------------------------------------------
  // TEKS TANGGAL
  // ---------------------------------------------------------------------------
  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  String get _dateText {
    const days = [
      'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
    ];
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli',
      'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final n = DateTime.now();
    return '${days[n.weekday - 1]}, ${n.day} ${months[n.month - 1]} ${n.year}';
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF0A1A1D),
        indicatorColor: _accent.withValues(alpha: 0.2),
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          _tick();
          setState(() => _tab = i);
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Beranda'),
          NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Denah'),
          NavigationDestination(
              icon: Icon(Icons.devices_other_outlined),
              selectedIcon: Icon(Icons.devices_other),
              label: 'Perangkat'),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Statistik'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil'),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _bgColors,
                ),
              ),
            ),
          ),
          Positioned(
            top: -90,
            right: -70,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_accent.withValues(alpha: 0.28), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: IndexedStack(
                index: _tab,
                sizing: StackFit.expand,
                children: [
                  _buildHomeTab(),
                  _buildFloorTab(),
                  _buildDevicesTab(),
                  _buildStatsTab(),
                  _buildProfileTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: BERANDA
  // ===========================================================================
  Widget _buildHomeTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _buildHomeHeader(),
        const SizedBox(height: 16),
        _buildStatusCard(),
        const SizedBox(height: 12),
        _buildEnergyCard(),
        const SizedBox(height: 12),
        _buildSourceBar(),
        const SizedBox(height: 18),
        _buildSectionTitle('Aksi Cepat', Icons.flash_on),
        const SizedBox(height: 8),
        _buildQuickActions(),
        const SizedBox(height: 18),
        _buildSectionTitle('Skenario', Icons.auto_awesome),
        const SizedBox(height: 8),
        _buildScenes(),
        const SizedBox(height: 18),
        _buildSectionTitle('Panel Surya', Icons.solar_power),
        const SizedBox(height: 8),
        _buildSolarCard(),
        const SizedBox(height: 18),
        _buildSectionTitle('Tips Hemat Energi', Icons.tips_and_updates),
        const SizedBox(height: 8),
        _buildTips(),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _accent),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildHomeHeader() {
    final badge = _notifOn ? _alerts.length : 0;
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [_accent, _accent.withValues(alpha: 0.5)],
            ),
          ),
          child: const Text('S',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$_greeting, Salwa',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(_dateText,
                  style: const TextStyle(fontSize: 11.5, color: Colors.white60)),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            _tick();
            _showAlertsSheet();
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(color: Colors.white12),
                ),
                child: Icon(
                  badge > 0
                      ? Icons.notifications_active
                      : Icons.notifications_none,
                  size: 22,
                  color: badge > 0 ? Colors.amberAccent : Colors.white70,
                ),
              ),
              if (badge > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                        color: Colors.redAccent, shape: BoxShape.circle),
                    child: Text('$badge',
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // KARTU STATUS: GESTUR TAP + LONG PRESS
  Widget _buildStatusCard() {
    final on = _isPowerOn;
    return GestureDetector(
      // GESTUR 1: TAP -> master power ON/OFF
      onTap: _togglePower,
      // GESTUR 2: LONG PRESS -> diagnostik jaringan
      onLongPress: () {
        _impact();
        _showDiagnosticSheet();
      },
      child: _GlassCard(
        borderColor: _accent.withValues(alpha: 0.7),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accent.withValues(alpha: 0.18),
                boxShadow: on
                    ? [
                        BoxShadow(
                          color: _accent.withValues(alpha: 0.45),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: Icon(
                on ? Icons.power_settings_new : Icons.power_off,
                color: _accent,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    on ? 'SISTEM LISTRIK AKTIF' : 'POWER MATI (OFF)',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: _accent),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    on
                        ? 'Beban $_loadWatt W  •  Hemat $_savingPercent%'
                        : 'Ketuk untuk menyalakan listrik',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap: Power ON/OFF  |  Tahan: Diagnostik',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.white38,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // KARTU ENERGI: GAUGE + METRIK
  Widget _buildEnergyCard() {
    final fraction = math.max(0.0, math.min(1.0, _loadWatt / _gaugeMax));
    return _GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          SizedBox(
            width: 132,
            height: 132,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: fraction),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => CustomPaint(
                painter: _GaugePainter(fraction: value, color: _gaugeColor),
                child: child,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$_loadWatt',
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w800)),
                    const Text('Watt',
                        style: TextStyle(fontSize: 11, color: Colors.white60)),
                    const SizedBox(height: 2),
                    Text(
                      !_isPowerOn ? 'OFF' : (_isEcoSaver ? 'ECO' : 'NORMAL'),
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _gaugeColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 132,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetricRow(Icons.electrical_services, 'Dari PLN',
                      '$_gridWatt W', Colors.orangeAccent),
                  _buildMetricRow(Icons.wb_sunny, 'Dari Surya',
                      '$_solarUsed W', Colors.yellowAccent),
                  _buildMetricRow(Icons.payments, 'Biaya PLN',
                      'Rp ${_rupiah(_costPerHour)}/jam', _accent),
                  _buildMetricRow(Icons.eco, 'Emisi CO2',
                      '$_co2PerHour g/jam', _green),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(
      IconData icon, String title, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 10, color: Colors.white54)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  // BAR SUMBER ENERGI (PLN vs SURYA)
  Widget _buildSourceBar() {
    final total = _gridWatt + _solarUsed;
    final solarFrac = total == 0 ? 0.0 : _solarUsed / total;
    Widget legend(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        );

    return _GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Sumber Energi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              Text('Energi hijau $_greenPercent%',
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: _green)),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, box) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 12,
                  child: Stack(
                    children: [
                      Container(
                        color: total == 0
                            ? Colors.white12
                            : Colors.orangeAccent.withValues(alpha: 0.85),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          width: box.maxWidth * solarFrac,
                          height: 12,
                          color: _green,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              legend(Colors.orangeAccent, 'PLN  $_gridWatt W'),
              legend(_green, 'Surya  $_solarUsed W'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: _isEcoSaver ? Icons.eco : Icons.eco_outlined,
            label: 'Eco Mode',
            color: _green,
            active: _isEcoSaver,
            onTap: _toggleEco,
          ),
        ),
        Expanded(
          child: _QuickAction(
            icon: Icons.power,
            label: 'Semua ON',
            color: Colors.amberAccent,
            active: false,
            onTap: () => _setAll(true),
          ),
        ),
        Expanded(
          child: _QuickAction(
            icon: Icons.power_off,
            label: 'Semua OFF',
            color: Colors.redAccent,
            active: false,
            onTap: () => _setAll(false),
          ),
        ),
        Expanded(
          child: _QuickAction(
            icon: Icons.health_and_safety,
            label: 'Diagnostik',
            color: Colors.lightBlueAccent,
            active: false,
            onTap: () {
              _tick();
              _showDiagnosticSheet();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildScenes() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final s in _scenes)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildSceneChip(s),
            ),
        ],
      ),
    );
  }

  Widget _buildSceneChip(_Scene s) {
    final selected = _activeScene == s.name;
    return GestureDetector(
      onTap: () => _applyScene(s),
      onLongPress: () {
        _impact();
        _snack('${s.name}: ${s.desc}');
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? _accent.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? _accent : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(s.icon, size: 18, color: selected ? _accent : Colors.white70),
            const SizedBox(width: 8),
            Text(s.name,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: selected ? _accent : Colors.white70)),
          ],
        ),
      ),
    );
  }

  // KARTU PANEL SURYA + SLIDER KUSTOM (DRAG HORIZONTAL)
  Widget _buildSolarCard() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Intensitas matahari',
                  style: TextStyle(fontSize: 12.5, color: Colors.white70)),
              const Spacer(),
              Text('${(_sunIntensity * 100).round()}%',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Colors.yellowAccent)),
            ],
          ),
          const SizedBox(height: 6),
          _CustomSlider(
            value: _sunIntensity,
            color: Colors.yellowAccent,
            onChanged: (v) => setState(() => _sunIntensity = v),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mendung',
                  style: TextStyle(fontSize: 10, color: Colors.white38)),
              Text('Cerah',
                  style: TextStyle(fontSize: 10, color: Colors.white38)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.bolt, size: 18, color: _green),
              const SizedBox(width: 6),
              Text('Produksi saat ini: $_solarWatt W',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  // TIPS: PAGEVIEW (SWIPE)
  Widget _buildTips() {
    return Column(
      children: [
        SizedBox(
          height: 96,
          child: PageView.builder(
            controller: _tipController,
            itemCount: _tips.length,
            onPageChanged: (i) => setState(() => _tipIndex = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _GlassCard(
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        color: Colors.amberAccent, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_tips[i],
                          style: const TextStyle(fontSize: 12.5, height: 1.35)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < _tips.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _tipIndex ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _tipIndex ? _accent : Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 2: DENAH
  // ===========================================================================
  Widget _buildTabTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.white60)),
      ],
    );
  }

  Widget _pill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildFloorTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTabTitle('Denah Rumah', 'Atur posisi perangkat listrik'),
          const SizedBox(height: 12),
          _buildFloorPlanLegend(),
          const SizedBox(height: 8),
          Expanded(child: _buildFloorPlan()),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(Icons.speed, 'Beban $_loadWatt W', Colors.amberAccent),
              _pill(Icons.wb_sunny, 'Surya $_solarWatt W', _green),
              _pill(Icons.devices, 'Aktif $_activeCount/${_devices.length}',
                  Colors.lightBlueAccent),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Seret ikon untuk memindah  •  Ketuk untuk ON/OFF  •  Tahan untuk detail',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorPlanLegend() {
    Widget dot(Color c, String label) => Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(fontSize: 10, color: Colors.white60)),
          ],
        );

    return Row(
      children: [
        const Icon(Icons.map_outlined, size: 16, color: Colors.white70),
        const SizedBox(width: 6),
        const Text('Denah Interaktif',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const Spacer(),
        dot(Colors.amber.shade400, 'Beban'),
        const SizedBox(width: 10),
        dot(_green, 'Surya'),
      ],
    );
  }

  Widget _buildFloorPlan() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final area = Size(constraints.maxWidth, constraints.maxHeight);
            final ordered = [
              ..._devices.where((d) => !identical(d, _dragging)),
              ..._devices.where((d) => identical(d, _dragging)),
            ];
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _FloorPlanPainter()),
                ),
                const Positioned(
                  left: 12,
                  top: 8,
                  child: Text('DALAM RUMAH',
                      style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.2,
                          color: Colors.white24,
                          fontWeight: FontWeight.bold)),
                ),
                Positioned(
                  left: 12,
                  top: area.height * 0.5 + 8,
                  child: const Text('GARASI & ENERGI',
                      style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.2,
                          color: Colors.white24,
                          fontWeight: FontWeight.bold)),
                ),
                for (final d in ordered) _buildDraggableDevice(d, area),
              ],
            );
          },
        ),
      ),
    );
  }

  // Satu perangkat: GESTUR 3 (PAN) + TAP + LONG PRESS
  Widget _buildDraggableDevice(_Device d, Size area) {
    final pos = _clampPos(d.pos, area);
    final live = d.active && _isPowerOn;
    final color = d.isSource ? _green : Colors.amber.shade400;
    final dragging = identical(_dragging, d);
    final out = _deviceOutput(d);

    return Positioned(
      key: ValueKey(d.name),
      left: pos.dx,
      top: pos.dy,
      child: GestureDetector(
        onTap: () => _toggleDevice(d),
        onLongPress: () {
          _impact();
          _showDeviceSheet(d);
        },
        // GESTUR 3: DRAG/PAN -> pindahkan posisi (dibatasi area denah)
        onPanStart: (_) {
          _tick();
          setState(() => _dragging = d);
        },
        onPanUpdate: (details) {
          setState(() => d.pos = _clampPos(d.pos + details.delta, area));
        },
        onPanEnd: (_) => setState(() => _dragging = null),
        onPanCancel: () => setState(() => _dragging = null),
        child: SizedBox(
          width: _deviceW,
          height: _deviceH,
          child: AnimatedScale(
            scale: dragging ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: live ? color : Colors.blueGrey.shade700,
                    boxShadow: live
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: dragging ? 26 : 18,
                              spreadRadius: dragging ? 6 : 3,
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(d.icon,
                      size: 28, color: live ? Colors.black87 : Colors.white54),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(d.name,
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 2),
                Text(
                  live ? (d.isSource ? '+$out W' : '$out W') : 'OFF',
                  style: TextStyle(
                      fontSize: 10, color: live ? color : Colors.white38),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 3: PERANGKAT
  // ===========================================================================
  Widget _buildDevicesTab() {
    final loads = _devices.where((d) => !d.isSource).toList();
    final sources = _devices.where((d) => d.isSource).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _buildTabTitle('Perangkat', 'Kelola semua beban dan sumber energi'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _pill(Icons.devices, '$_activeCount aktif dari ${_devices.length}',
                Colors.lightBlueAccent),
            _pill(Icons.speed, 'Beban $_loadWatt W', Colors.amberAccent),
            _pill(Icons.payments, 'Rp ${_rupiah(_costPerHour)}/jam', _accent),
          ],
        ),
        const SizedBox(height: 18),
        _buildSectionTitle('Beban Listrik', Icons.power),
        const SizedBox(height: 8),
        for (final d in loads) ...[
          _buildDeviceTile(d),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        _buildSectionTitle('Sumber Energi', Icons.solar_power),
        const SizedBox(height: 8),
        for (final d in sources) ...[
          _buildDeviceTile(d),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 4),
        const Text(
          'Ketuk kartu untuk ON/OFF  •  Tahan kartu untuk melihat detail',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10.5, color: Colors.white38),
        ),
      ],
    );
  }

  Widget _buildDeviceTile(_Device d) {
    final live = d.active && _isPowerOn;
    final color = d.isSource ? _green : Colors.amber.shade400;
    final subtitle = d.isSource
        ? 'Produksi hingga ${d.watt} W  •  saat ini ${_deviceOutput(d)} W'
        : '${d.watt} W  •  Rp ${_rupiah((d.watt * _tariffPerWatt).round())}/jam';

    return GestureDetector(
      onTap: () => _toggleDevice(d),
      onLongPress: () {
        _impact();
        _showDeviceSheet(d);
      },
      child: _GlassCard(
        borderColor: live ? color.withValues(alpha: 0.5) : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: live ? color : Colors.blueGrey.shade700,
                boxShadow: live
                    ? [
                        BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 1),
                      ]
                    : [],
              ),
              child: Icon(d.icon,
                  size: 24, color: live ? Colors.black87 : Colors.white54),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(
                    _isPowerOn ? subtitle : 'Power utama mati',
                    style: const TextStyle(fontSize: 11, color: Colors.white60),
                  ),
                ],
              ),
            ),
            Switch(
              value: d.active,
              activeThumbColor: color,
              onChanged: (_) => _toggleDevice(d),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 4: STATISTIK
  // ===========================================================================
  Widget _buildStatsTab() {
    final todayKwh = _gridWatt * 24 / 1000;
    final costToday = (todayKwh * _tariffs[_tariffIndex]).round();
    final savedKgDay = _savedWatt * _co2GramPerWatt * 24 / 1000;
    final trees = (savedKgDay * 365 / 21).round();
    final progress = math.min(1.0, _savingPercent / _targetSaving);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _buildTabTitle('Statistik', 'Pantau konsumsi dan dampak lingkungan'),
        const SizedBox(height: 14),
        Row(
          children: [
            _buildRangeChip('Harian', !_statsWeekly, () {
              _tick();
              setState(() => _statsWeekly = false);
            }),
            const SizedBox(width: 8),
            _buildRangeChip('Mingguan', _statsWeekly, () {
              _tick();
              setState(() => _statsWeekly = true);
            }),
          ],
        ),
        const SizedBox(height: 12),
        _statsWeekly ? _buildWeeklyChart() : _buildDailyChart(),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(Icons.bolt, 'Estimasi 24 jam (PLN)',
                  '${todayKwh.toStringAsFixed(1)} kWh', Colors.orangeAccent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(Icons.payments, 'Biaya 24 jam',
                  'Rp ${_rupiah(costToday)}', _accent),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(Icons.cloud_off, 'CO2 dihemat/hari',
                  '${savedKgDay.toStringAsFixed(1)} kg', _green),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(Icons.park, 'Setara pohon/tahun',
                  '$trees pohon', Colors.lightGreenAccent),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.flag, size: 18, color: Colors.amberAccent),
                  const SizedBox(width: 8),
                  const Text('Target Hemat Energi',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const Spacer(),
                  Text('$_savingPercent% / ${_targetSaving.round()}%',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: Colors.white12,
                  color: progress >= 1 ? _green : _accent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                progress >= 1
                    ? 'Target tercapai. Kerja bagus!'
                    : 'Aktifkan Eco Mode dan panel surya untuk mencapai target.',
                style: const TextStyle(fontSize: 11, color: Colors.white60),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Catatan: grafik dan angka pada halaman ini adalah data simulasi.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10.5, color: Colors.white38),
        ),
      ],
    );
  }

  Widget _buildRangeChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? _accent.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? _accent : Colors.white24),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: selected ? _accent : Colors.white70)),
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value, Color color) {
    return _GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 10),
          Text(value,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 10.5, color: Colors.white60)),
        ],
      ),
    );
  }

  // Grafik garis 24 jam: sentuh / geser untuk memilih jam
  Widget _buildDailyChart() {
    final hour = _selectedHour.clamp(0, 23);
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Profil Beban 24 Jam',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              Text(
                '${hour.toString().padLeft(2, '0')}:00  •  ${_hourlyWatt[hour]} W',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: _accent),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: LayoutBuilder(
              builder: (context, box) {
                void pick(double dx) {
                  final i = (dx / box.maxWidth * 23).round();
                  setState(() => _selectedHour = math.max(0, math.min(23, i)));
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => pick(d.localPosition.dx),
                  onHorizontalDragUpdate: (d) => pick(d.localPosition.dx),
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _LineChartPainter(
                      values: _hourlyWatt,
                      maxValue: 1000,
                      color: _accent,
                      selected: hour,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('00', style: TextStyle(fontSize: 10, color: Colors.white38)),
              Text('06', style: TextStyle(fontSize: 10, color: Colors.white38)),
              Text('12', style: TextStyle(fontSize: 10, color: Colors.white38)),
              Text('18', style: TextStyle(fontSize: 10, color: Colors.white38)),
              Text('23', style: TextStyle(fontSize: 10, color: Colors.white38)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Sentuh atau geser grafik untuk memilih jam.',
              style: TextStyle(fontSize: 10.5, color: Colors.white38)),
        ],
      ),
    );
  }

  // Grafik batang 7 hari: ketuk batang untuk memilih hari
  Widget _buildWeeklyChart() {
    const maxKwh = 6.0;
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Konsumsi 7 Hari',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              Text(
                '${_dayShort[_selectedDay]}  •  ${_weeklyKwh[_selectedDay]} kWh',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: _accent),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < 7; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _tick();
                        setState(() => _selectedDay = i);
                      },
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          width: 24,
                          height: 130 * _weeklyKwh[i] / maxKwh,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: i == _selectedDay
                                ? _accent
                                : Colors.white.withValues(alpha: 0.18),
                            boxShadow: i == _selectedDay
                                ? [
                                    BoxShadow(
                                        color: _accent.withValues(alpha: 0.4),
                                        blurRadius: 12)
                                  ]
                                : [],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (int i = 0; i < 7; i++)
                Expanded(
                  child: Text(
                    _dayShort[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight:
                            i == _selectedDay ? FontWeight.bold : FontWeight.w400,
                        color:
                            i == _selectedDay ? _accent : Colors.white38),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 5: PROFIL & PENGATURAN
  // ===========================================================================
  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _buildTabTitle('Profil', 'Akun dan pengaturan aplikasi'),
        const SizedBox(height: 14),
        _GlassCard(
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_accent, _accent.withValues(alpha: 0.5)],
                  ),
                ),
                child: const Text('S',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87)),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Salwa Azzahra Rambe',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    SizedBox(height: 3),
                    Text('Rumah Eco ITPLN',
                        style: TextStyle(fontSize: 12, color: Colors.white60)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionTitle('Preferensi', Icons.tune),
        const SizedBox(height: 8),
        _GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                value: _notifOn,
                onChanged: (v) => setState(() => _notifOn = v),
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('Notifikasi peringatan'),
                subtitle: const Text('Tampilkan lencana pada ikon lonceng',
                    style: TextStyle(fontSize: 11)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: _haptics,
                onChanged: (v) => setState(() => _haptics = v),
                secondary: const Icon(Icons.vibration),
                title: const Text('Getaran sentuhan'),
                subtitle: const Text('Umpan balik saat gestur dilakukan',
                    style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionTitle('Tarif Listrik (simulasi)', Icons.payments),
        const SizedBox(height: 8),
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < _tariffs.length; i++)
                    ChoiceChip(
                      label: Text('Rp ${_rupiah(_tariffs[i])}/kWh'),
                      selected: _tariffIndex == i,
                      selectedColor: _accent.withValues(alpha: 0.25),
                      onSelected: (_) {
                        _tick();
                        setState(() => _tariffIndex = i);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Tarif mempengaruhi estimasi biaya di seluruh aplikasi. Nilai ini hanya perkiraan untuk simulasi.',
                style: TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionTitle('Data & Aplikasi', Icons.settings),
        const SizedBox(height: 8),
        _GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.restart_alt),
                title: const Text('Reset posisi denah'),
                onTap: _resetLayout,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined,
                    color: Colors.redAccent),
                title: const Text('Reset semua pengaturan'),
                onTap: _confirmReset,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Tentang aplikasi'),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'ITPLN Eco-Home Pro',
                  applicationVersion: '3.0.0',
                  applicationIcon:
                      const Icon(Icons.bolt, color: Color(0xFF1DE9B6), size: 36),
                  children: const [
                    SizedBox(height: 12),
                    Text(
                        'Simulasi pengendali listrik rumah pintar bertema SDG 7: Energi Bersih dan Terjangkau. Seluruh data bersifat simulasi.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // BOTTOM SHEET
  // ===========================================================================
  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }

  // Diagnostik jaringan (LONG PRESS kartu status)
  void _showDiagnosticSheet() {
    final activeDevices = _devices.where((d) => d.active).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E2A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.health_and_safety,
                        color: Color(0xFF1DE9B6), size: 28),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Diagnostik Jaringan (SDG 7)',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _infoRow('Tegangan jaringan', '220.4 V'),
                _infoRow('Frekuensi listrik', '50.0 Hz'),
                _infoRow(
                  'Sumber energi',
                  !_isPowerOn
                      ? '-'
                      : (_solarUsed > 0 ? 'PLN + Surya' : 'PLN'),
                ),
                _infoRow(
                  'Status efisiensi',
                  _isEcoSaver ? 'OPTIMAL (Eco-Active)' : 'STANDAR',
                  valueColor: _isEcoSaver ? _green : Colors.white54,
                ),
                _infoRow('Hemat energi PLN', '$_savingPercent%'),
                const Divider(height: 24),
                const Text('Perangkat aktif',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                if (!_isPowerOn || activeDevices.isEmpty)
                  const Text('Tidak ada perangkat aktif.',
                      style: TextStyle(color: Colors.white54))
                else
                  for (final d in activeDevices)
                    _infoRow(
                      d.name,
                      d.isSource
                          ? '+${_deviceOutput(d)} W'
                          : '${d.watt} W',
                      valueColor:
                          d.isSource ? _green : Colors.amber.shade400,
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Detail perangkat (LONG PRESS ikon / kartu perangkat)
  void _showDeviceSheet(_Device d) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E2A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(d.icon,
                        size: 28,
                        color: d.isSource ? _green : Colors.amber.shade400),
                    const SizedBox(width: 10),
                    Text(d.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(height: 24),
                _infoRow('Status', d.active ? 'AKTIF' : 'MATI',
                    valueColor: d.active ? _green : Colors.redAccent),
                _infoRow(
                    d.isSource ? 'Produksi saat ini' : 'Konsumsi daya',
                    '${_deviceOutput(d)} W'),
                if (d.isSource)
                  _infoRow('Kapasitas puncak', '${d.watt} W'),
                if (!d.isSource)
                  _infoRow('Biaya per jam',
                      'Rp ${_rupiah((d.watt * _tariffPerWatt).round())}'),
                _infoRow('Posisi di denah',
                    '(${d.pos.dx.round()}, ${d.pos.dy.round()})'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _toggleDevice(d);
                    },
                    icon: Icon(d.active ? Icons.power_off : Icons.power),
                    label: Text(d.active ? 'Matikan' : 'Nyalakan'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Daftar peringatan (ikon lonceng)
  void _showAlertsSheet() {
    final alerts = _alerts;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E2A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notifications_active,
                        color: Colors.amberAccent, size: 26),
                    SizedBox(width: 10),
                    Text('Notifikasi',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(height: 24),
                if (alerts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: _green),
                        SizedBox(width: 10),
                        Expanded(
                            child: Text(
                                'Semua normal. Tidak ada peringatan saat ini.')),
                      ],
                    ),
                  )
                else
                  for (final a in alerts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: a.color.withValues(alpha: 0.18),
                            ),
                            child: Icon(a.icon, color: a.color, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(a.body,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                        height: 1.3)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// WIDGET PEMBANTU
// =============================================================================
class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.borderColor,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white.withValues(alpha: 0.06),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: borderColor ?? Colors.white.withValues(alpha: 0.12),
          width: 1.5,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? color : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: active ? color : Colors.white70),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: active ? color : Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

// Slider kustom: ketuk atau geser horizontal untuk mengubah nilai 0.0 - 1.0
class _CustomSlider extends StatelessWidget {
  const _CustomSlider({
    required this.value,
    required this.onChanged,
    required this.color,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        void update(double dx) =>
            onChanged(math.max(0.0, math.min(1.0, dx / w)));
        final thumbLeft = math.max(0.0, math.min(w - 28, w * value - 14));

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => update(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => update(d.localPosition.dx),
          child: SizedBox(
            height: 40,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  width: w * value,
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.4), color],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Positioned(
                  left: thumbLeft,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.6),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.wb_sunny,
                        size: 16, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// CUSTOM PAINTER
// =============================================================================
// Gauge busur 270 derajat
class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - stroke;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = 3 * math.pi / 4;
    const sweep = 3 * math.pi / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.1);
    canvas.drawArc(rect, start, sweep, false, track);

    if (fraction <= 0) return;

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawArc(rect, start, sweep * fraction, false, glow);

    final value = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, start, sweep * fraction, false, value);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.fraction != fraction || old.color != color;
}

// Latar denah: titik grid dan garis pemisah putus-putus
class _FloorPlanPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.08);
    for (double x = 16; x < size.width; x += 24) {
      for (double y = 16; y < size.height; y += 24) {
        canvas.drawCircle(Offset(x, y), 1.2, dot);
      }
    }

    final line = Paint()
      ..color = Colors.tealAccent.withValues(alpha: 0.25)
      ..strokeWidth = 1.5;
    final y = size.height * 0.5;
    for (double x = 0; x < size.width; x += 14) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + 7, size.width), y),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Grafik garis dengan area gradasi dan penanda jam terpilih
class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.values,
    required this.maxValue,
    required this.color,
    required this.selected,
  });

  final List<int> values;
  final double maxValue;
  final Color color;
  final int selected;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final n = values.length;
    final dx = size.width / (n - 1);
    double yOf(int v) => size.height - (v / maxValue) * (size.height - 12) - 6;

    final path = Path()..moveTo(0, yOf(values[0]));
    for (int i = 1; i < n; i++) {
      path.lineTo(dx * i, yOf(values[i]));
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    if (selected >= 0 && selected < n) {
      final p = Offset(dx * selected, yOf(values[selected]));
      canvas.drawLine(
        Offset(p.dx, 0),
        Offset(p.dx, size.height),
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(p, 8, Paint()..color = color.withValues(alpha: 0.3));
      canvas.drawCircle(p, 4.5, Paint()..color = color);
      canvas.drawCircle(
        p,
        4.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.selected != selected || old.color != color || old.values != values;
}
