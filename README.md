# ITPLN Smart Eco-Home Controller
Aplikasi mobile interaktif berbasis Flutter untuk memantau dan mengontrol beban listrik rumah secara visual. Dengan tema **SDG 7: Energi Bersih dan Terjangkau** (ketenagalistrikan dan efisiensi energi).

## Latar Belakang
Pemakaian listrik rumah tangga yang tidak terkontrol menyebabkan pemborosan energi, tagihan membengkak, dan emisi karbon lebih tinggi. SDG 7 menargetkan energi yang bersih, terjangkau, dan berkelanjutan, termasuk peningkatan efisiensi energi. Aplikasi ini mensimulasikan pengendali listrik rumah pintar (smart home) agar pengguna dapat melihat dampak tiap perangkat terhadap total daya, biaya, dan emisi, lalu mengaturnya hanya dengan gestur sentuhan.

## Fitur dan Gestur

| Gestur | Widget | Aksi | Perubahan visual |
|--------|--------|------|------------------|
| **Tap** | `GestureDetector.onTap` pada kartu status | Menyalakan/mematikan power utama | Warna latar, border, ikon, dan teks berubah; total beban menjadi 0 W saat OFF |
| **Long Press** | `GestureDetector.onLongPress` pada kartu status | Membuka laporan diagnostik jaringan | Muncul bottom sheet (tegangan, frekuensi, status efisiensi) |
| **Drag / Pan** | `GestureDetector.onPanUpdate` pada ikon perangkat | Memindahkan lampu, AC, dan EV Charger di denah | Ikon berpindah real-time, dibatasi dalam area denah |
| **Tap (perangkat)** | `GestureDetector.onTap` pada ikon perangkat | ON/OFF perangkat individu | Ikon menyala kuning atau mati abu-abu; total watt dan biaya ikut berubah |

Fitur tambahan:

- **Eco Mode** (ikon daun di AppBar): menurunkan estimasi daya 40%, latar berubah hijau, Reduksi CO2 menjadi -40%.
- **SnackBar peringatan**: muncul jika perangkat diketuk saat power utama mati.
- **Dashboard metrik**: estimasi biaya per jam, reduksi CO2, dan status grid.

## Data Perangkat

| Perangkat | Daya | Posisi awal | Status awal |
|-----------|------|-------------|-------------|
| Lampu | 20 W | (40, 60) | ON |
| AC Smart | 400 W | (180, 60) | ON |
| EV Charger | 1000 W | (110, 200) | OFF |

## Perhitungan

- Total beban = jumlah daya perangkat aktif (0 W jika power utama mati).
- Eco Mode: total beban × 0,6 (turun 40%).
- Estimasi biaya = total beban × Rp 1,44 per Watt per jam (tarif asumsi untuk simulasi).

Contoh: kondisi awal (Lampu + AC) = 420 W, sekitar Rp 604/jam. Dengan Eco Mode = 252 W, sekitar Rp 362/jam.

## Struktur Widget

```
MaterialApp
 └─ EcoHomeScreen (StatefulWidget)
     └─ Scaffold
         ├─ AppBar (IconButton: Toggle Eco Mode)
         └─ Stack
             ├─ AnimatedContainer (latar dinamis)
             └─ SafeArea → Padding → Column
                 ├─ GestureDetector (Tap + Long Press) → Card → Row
                 ├─ Card → Row (3x metrik)
                 ├─ Expanded → Container → ClipRRect → LayoutBuilder → Stack
                 │   └─ 3x Positioned → GestureDetector (Pan + Tap)
                 └─ Text (petunjuk)
```

## Struktur Kode

- `SmartEcoHomeApp`: root `MaterialApp` dengan Material 3.
- `EcoHomeScreen` (`StatefulWidget`): menyimpan state lokal (`_isPowerOn`, `_isEcoSaver`, `_devices`).
- `_Device`: model perangkat (nama, ikon, watt, posisi, status).
- Helper modular: `_buildStatusCard`, `_buildMetricsCard`, `_buildMetricItem`, `_buildFloorPlan`, `_buildDraggableDevice`, `_showDiagnosticSheet`, `_showPowerOffMessage`, `_clamp`.

## Relevansi SDG 7

- **Transparansi konsumsi**: pengguna melihat perangkat paling boros (misalnya EV Charger 1000 W vs lampu 20 W).
- **Keterjangkauan**: estimasi biaya per jam membantu menekan pengeluaran listrik.
- **Keberlanjutan**: Eco Mode dan indikator CO2 menggambarkan dampak penghematan energi.
- **Keandalan jaringan**: laporan diagnostik tegangan dan frekuensi relevan dengan bidang ketenagalistrikan.

# Kelompok 20 :
Salwa Azzahra Rambe_202431079
