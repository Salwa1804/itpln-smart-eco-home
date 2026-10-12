import 'package:flutter/material.dart';

void main() {
  runApp(const SmartEcoHomeApp());
}

// =============================================================================
// ROOT APP
// =============================================================================
class SmartEcoHomeApp extends StatelessWidget {
  const SmartEcoHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ITPLN Eco-Home Controller',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.light,
      ),
      home: const EcoHomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// =============================================================================
// MODEL PERANGKAT
// =============================================================================
class _Device {
  _Device({
    required this.name,
    required this.icon,
    required this.watt,
    required this.pos,
    required this.active,
  });

  final String name;
  final IconData icon;
  final int watt;
  Offset pos; // posisi di denah (diubah oleh Pan gesture)
  bool active; // status ON/OFF (diubah oleh Tap gesture)
}

// =============================================================================
// SCREEN UTAMA
// =============================================================================
class EcoHomeScreen extends StatefulWidget {
  const EcoHomeScreen({super.key});

  @override
  State<EcoHomeScreen> createState() => _EcoHomeScreenState();
}

class _EcoHomeScreenState extends State<EcoHomeScreen> {
  // ---------------------------------------------------------------------------
  // STATE LOKAL
  // ---------------------------------------------------------------------------
  static const double _deviceWidth = 72;
  static const double _deviceHeight = 80;
  static const double _tariffPerWatt = 1.44; // estimasi Rp per Watt per jam

  bool _isPowerOn = true;
  bool _isEcoSaver = false;

  final List<_Device> _devices = [
    _Device(
      name: 'Lampu',
      icon: Icons.lightbulb,
      watt: 20,
      pos: const Offset(40, 60),
      active: true,
    ),
    _Device(
      name: 'AC Smart',
      icon: Icons.ac_unit,
      watt: 400,
      pos: const Offset(180, 60),
      active: true,
    ),
    _Device(
      name: 'EV Charger',
      icon: Icons.ev_station,
      watt: 1000,
      pos: const Offset(110, 200),
      active: false,
    ),
  ];

  // Estimasi konsumsi daya total
  int get _totalWatt {
    if (!_isPowerOn) return 0;
    final base = _devices
        .where((d) => d.active)
        .fold<int>(0, (sum, d) => sum + d.watt);
    return _isEcoSaver ? (base * 0.6).round() : base;
  }

  // ---------------------------------------------------------------------------
  // HELPER
  // ---------------------------------------------------------------------------
  // Menjaga ikon tetap berada di dalam area denah
  Offset _clamp(Offset p, Size area) {
    final maxX = (area.width - _deviceWidth).clamp(0.0, double.infinity);
    final maxY = (area.height - _deviceHeight).clamp(0.0, double.infinity);
    return Offset(p.dx.clamp(0.0, maxX), p.dy.clamp(0.0, maxY));
  }

  void _showPowerOffMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Power utama mati. Ketuk kartu status untuk menyalakan.'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  // GESTURE 2 (Long Press): pop-up diagnostik
  void _showDiagnosticSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.health_and_safety, color: Colors.teal, size: 28),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Laporan Diagnostik Jaringan (SDG 7)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              const ListTile(
                leading: Icon(Icons.speed, color: Colors.blue),
                title: Text('Tegangan Jaringan (Voltage)'),
                trailing: Text('220.4 V', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const ListTile(
                leading: Icon(Icons.bolt, color: Colors.orange),
                title: Text('Frekuensi Listrik'),
                trailing: Text('50.0 Hz', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.eco, color: Colors.green),
                title: const Text('Status Efisiensi Energi'),
                trailing: Text(
                  _isEcoSaver ? 'OPTIMAL (Eco-Active)' : 'STANDAR',
                  style: TextStyle(
                    color: _isEcoSaver ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ITPLN Smart Eco-Home Controller'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isEcoSaver ? Icons.eco : Icons.eco_outlined),
            onPressed: () => setState(() => _isEcoSaver = !_isEcoSaver),
            tooltip: 'Toggle Eco Mode',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Latar belakang dinamis
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            color: !_isPowerOn
                ? Colors.grey.shade300
                : (_isEcoSaver ? Colors.green.shade50 : Colors.teal.shade50),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 12),
                  _buildMetricsCard(),
                  const SizedBox(height: 16),
                  const Text(
                    'Atur Posisi Beban Listrik (Geser / Drag Ikon):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Expanded(child: _buildFloorPlan()),
                  const SizedBox(height: 8),
                  const Text(
                    'Ketuk ikon beban untuk ON/OFF-kan perangkat secara individu.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. KARTU STATUS UTAMA (GESTURE: TAP & LONG PRESS)
  // ---------------------------------------------------------------------------
  Widget _buildStatusCard() {
    return GestureDetector(
      // GESTURE 1: TAP -> toggle master power
      onTap: () => setState(() => _isPowerOn = !_isPowerOn),
      // GESTURE 2: LONG PRESS -> buka diagnostik
      onLongPress: () => _showDiagnosticSheet(context),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: _isPowerOn ? Colors.teal : Colors.red,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isPowerOn ? Colors.teal.shade100 : Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPowerOn ? Icons.power : Icons.power_off,
                  size: 36,
                  color: _isPowerOn ? Colors.teal.shade900 : Colors.red,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isPowerOn ? 'SISTEM LISTRIK AKTIF' : 'POWER MATI (OFF)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _isPowerOn ? Colors.teal.shade900 : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isPowerOn
                          ? 'Total Beban: $_totalWatt Watt ${_isEcoSaver ? '(Eco Mode)' : ''}'
                          : 'Ketuk untuk menyalakan listrik',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '[Tap: Power On/Off | Hold: Cek Diagnostik]',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. DASHBOARD METRIK
  // ---------------------------------------------------------------------------
  Widget _buildMetricsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildMetricItem(
              'Estimasi Biaya',
              'Rp ${(_totalWatt * _tariffPerWatt).toInt()}/jam',
              Icons.monetization_on,
            ),
            const SizedBox(width: 8, child: VerticalDivider()),
            _buildMetricItem(
              'Reduksi CO2',
              _isEcoSaver ? '-40%' : '0%',
              Icons.eco,
            ),
            const SizedBox(width: 8, child: VerticalDivider()),
            _buildMetricItem('Status Grid', 'Stabil', Icons.grid_view),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.teal.shade700),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3. DENAH INTERAKTIF (STACK + DRAG/PAN GESTURE)
  // ---------------------------------------------------------------------------
  Widget _buildFloorPlan() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final area = Size(constraints.maxWidth, constraints.maxHeight);
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                const Positioned(
                  bottom: 12,
                  right: 12,
                  child: Text(
                    'LAYOUT DENAH RUMAH (ITPLN)',
                    style: TextStyle(
                      color: Colors.black12,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                for (final device in _devices)
                  _buildDraggableDevice(device, area),
              ],
            );
          },
        ),
      ),
    );
  }

  // Elemen beban listrik interaktif (GESTURE 3: PAN + TAP)
  Widget _buildDraggableDevice(_Device device, Size area) {
    final pos = _clamp(device.pos, area);
    final isActive = device.active && _isPowerOn;

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: GestureDetector(
        // GESTURE 3: PAN -> pindahkan posisi, dibatasi area denah
        onPanUpdate: (details) {
          setState(() => device.pos = _clamp(pos + details.delta, area));
        },
        // TAP -> ON/OFF perangkat individu
        onTap: () {
          if (!_isPowerOn) {
            _showPowerOffMessage();
            return;
          }
          setState(() => device.active = !device.active);
        },
        child: SizedBox(
          width: _deviceWidth,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isActive ? Colors.amber.shade400 : Colors.grey.shade400,
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (isActive)
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.6),
                        blurRadius: 16,
                        spreadRadius: 4,
                      ),
                  ],
                ),
                child: Icon(device.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  device.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
