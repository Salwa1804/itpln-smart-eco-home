# ITPLN Eco-Home (Smart Eco-Home Controller)

Aplikasi mobile interaktif berbasis **Flutter** untuk memantau dan mengontrol beban listrik rumah pintar secara visual. Dibuat untuk **Tugas 4 – Pemrograman Mobile** dengan tema **SDG 7: Energi Bersih dan Terjangkau** (ketenagalistrikan, efisiensi energi, dan energi terbarukan).

## Latar Belakang

Pemakaian listrik rumah tangga yang tidak terkontrol menyebabkan pemborosan energi, tagihan membengkak, dan emisi karbon lebih tinggi. SDG 7 menargetkan energi yang bersih, terjangkau, dan berkelanjutan, termasuk peningkatan efisiensi energi. Aplikasi ini mensimulasikan pengendali listrik rumah pintar agar pengguna dapat melihat dampak tiap perangkat terhadap total daya, biaya, dan emisi, lalu mengaturnya hanya dengan gestur sentuhan.

## Struktur Aplikasi

| Tab | Isi |
|-----|-----|
| **Beranda** | Sapaan dan tanggal, ikon notifikasi (lencana), kartu status, gauge daya, bar sumber energi (PLN vs Surya), aksi cepat, skenario, slider panel surya, tips hemat energi |
| **Denah** | Denah rumah interaktif: lima perangkat dapat digeser, diketuk, dan ditahan |
| **Perangkat** | Daftar beban listrik dan sumber energi dengan saklar ON/OFF |
| **Statistik** | Grafik beban 24 jam, grafik konsumsi 7 hari, kartu ringkasan, dan target hemat energi |
| **Profil** | Profil, pengaturan notifikasi dan getaran, pilihan tarif listrik, reset data, tentang aplikasi |

## Gestur

| Gestur | Lokasi | Aksi | Perubahan visual |
|--------|--------|------|------------------|
| **Tap** | Kartu status | Power utama ON/OFF | Latar, border, ikon, teks, dan gauge berubah; beban menjadi 0 W saat OFF |
| **Tap** | Ikon/kartu perangkat, aksi cepat, chip skenario, batang grafik | ON/OFF perangkat, Eco Mode, terapkan skenario, pilih hari | Ikon menyala/mati, total watt, biaya, dan gauge ikut berubah |
| **Long Press** | Kartu status | Diagnostik jaringan | Bottom sheet (tegangan, frekuensi, sumber energi, efisiensi, perangkat aktif) |
| **Long Press** | Perangkat (denah dan daftar) | Detail perangkat | Bottom sheet detail dengan tombol Nyalakan/Matikan |
| **Drag / Pan** | Ikon perangkat di denah | Memindahkan posisi | Ikon membesar dan bersinar, mengikuti jari real-time, dibatasi area denah |
| **Drag horizontal** | Slider kustom panel surya | Mengatur intensitas matahari | Produksi surya, biaya, dan emisi berubah real-time |
| **Tap / Drag horizontal** | Grafik 24 jam | Memilih jam | Penanda dan nilai Watt berubah |
| **Swipe** | Kartu tips | Berpindah tips | Indikator titik bergeser |

## Fitur Utama

- **Panel Surya**: sumber energi terbarukan yang mengurangi beban PLN; intensitas diatur dengan slider kustom.
- **Eco Mode**: menurunkan estimasi beban 40% dan mengubah tema warna menjadi hijau.
- **Skenario otomatis**: Pagi, Pulang, Tidur, Keluar, Hemat Max (satu ketukan mengatur banyak perangkat).
- **Notifikasi peringatan**: dihitung otomatis dari kondisi (beban tinggi, EV Charger aktif, surplus surya, saran hemat).
- **Statistik**: grafik garis dan batang, estimasi kWh, biaya, CO2 dihemat, setara pohon, target hemat.
- **Pengaturan**: notifikasi, getaran sentuhan, pilihan tarif listrik (mempengaruhi seluruh estimasi biaya).

## Struktur Widget

```
MaterialApp
 └─ SplashScreen (StatefulWidget) → pushReplacement
     └─ EcoHomeShell (StatefulWidget, state lokal setState)
         └─ Scaffold
             ├─ NavigationBar (5 tab)
             └─ Stack
                 ├─ AnimatedContainer (latar gradasi) + cahaya dekoratif
                 └─ SafeArea → IndexedStack
                     ├─ Beranda: ListView (status, gauge, sumber energi,
                     │            aksi cepat, skenario, slider surya, tips)
                     ├─ Denah: Expanded → LayoutBuilder → Stack
                     │            └─ 5x Positioned → GestureDetector (Pan + Tap + Long Press)
                     ├─ Perangkat: ListView → Card → Row (Switch)
                     ├─ Statistik: ListView (grafik garis, grafik batang, ringkasan, target)
                     └─ Profil: ListView (SwitchListTile, ChoiceChip, ListTile)
```

## Anggota Kelompok

| Nama | NIM |
|------|-----|
| M. Abriel Afrian Lenry | 202431020 |
| Salwa Azzahra Rambe | 202431079 |