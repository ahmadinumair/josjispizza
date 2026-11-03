# Josjis Pizza

Website pemesanan sederhana dengan frontend Flutter Web dan REST API Express.

## Menjalankan API

```powershell
cd backend
npm install
npm start
```

API berjalan di `http://localhost:3000`. Endpoint yang tersedia:

- `GET /api/health` — status server
- `GET /api/menu` — daftar pizza
- `POST /api/orders` — membuat pesanan

Pesanan disimpan di memori server, sehingga akan terhapus saat server dimulai ulang.

## Menjalankan website Flutter

Pastikan Flutter SDK dan browser Chrome tersedia:

```powershell
cd flutter_app
flutter pub get
flutter run -d chrome
```

Flutter Web menggunakan API `http://localhost:3000/api` secara default. Untuk alamat API lain:

```powershell
flutter run -d chrome --dart-define=API_URL=http://localhost:3000/api
```

Jika dijalankan di Android emulator, gunakan `http://10.0.2.2:3000/api` sebagai `API_URL`.

## Pengujian API

```powershell
cd backend
npm test
```
