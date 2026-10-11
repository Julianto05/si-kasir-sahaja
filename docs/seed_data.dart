// ╔═══════════════════════════════════════════════════════════════════╗
// ║  Seed Script — Membuat akun admin dan kasir di Firebase          ║
// ║                                                                   ║
// ║  Jalankan script ini SATU KALI setelah Firebase terhubung.       ║
// ║  Bisa dijalankan dari Firebase Console atau via script terpisah.  ║
// ║                                                                   ║
// ║  CATATAN: Script ini memerlukan Firebase Admin SDK atau           ║
// ║  bisa dijalankan secara manual melalui Firebase Console.          ║
// ╚═══════════════════════════════════════════════════════════════════╝
//
// ========================================
//  CARA MEMBUAT SEED DATA SECARA MANUAL:
// ========================================
//
// 1. BUKA Firebase Console → https://console.firebase.google.com
//
// 2. BUAT AKUN DI FIREBASE AUTHENTICATION:
//    - Pergi ke Authentication → Users → Add User
//
//    Akun Admin:
//      Email: admin@example.com
//      Password: Admin@123456   (GANTI untuk production!)
//
//    Akun Kasir:
//      Email: kasir@example.com
//      Password: Kasir@123456   (GANTI untuk production!)
//
//    Catat UID yang dihasilkan untuk masing-masing akun.
//
// 3. BUAT DOKUMEN DI CLOUD FIRESTORE:
//    - Pergi ke Firestore Database → Start Collection
//
//    Collection: users
//
//    Document ID: [UID admin dari langkah 2]
//    Fields:
//      email     : string  : admin@example.com
//      name      : string  : Admin Utama
//      role      : string  : admin
//      isActive  : boolean : true
//      createdAt : timestamp : (pilih tanggal sekarang)
//      updatedAt : timestamp : (pilih tanggal sekarang)
//
//    Document ID: [UID kasir dari langkah 2]
//    Fields:
//      email     : string  : kasir@example.com
//      name      : string  : Kasir Utama
//      role      : string  : kasir
//      isActive  : boolean : true
//      createdAt : timestamp : (pilih tanggal sekarang)
//      updatedAt : timestamp : (pilih tanggal sekarang)
//
// 4. BUAT FIRESTORE SECURITY RULES:
//    - Pergi ke Firestore Database → Rules
//    - Paste rules dari file firestore.rules di root project
//
// ========================================
//  SELESAI — Anda bisa login ke aplikasi!
// ========================================
