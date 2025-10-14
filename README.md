# 🎵 Spotify Taşıyıcı

Spotify'daki beğenilen şarkılarınızı Apple Music'e aktaran iOS uygulaması.

## ✨ Özellikler

- ✅ Spotify'dan beğenilen şarkıları otomatik çekme
- ✅ Apple Music'te şarkıları arama ve eşleştirme
- ✅ Yeni playlist oluşturma ve şarkıları ekleme
- ✅ Gerçek zamanlı aktarım durumu takibi
- ✅ Yerel veri saklama (aktarım durumu korunur)
- ✅ Kuyruğu sıfırlama özelliği

## 🛠️ Gereksinimler

- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+
- Aktif Spotify Developer hesabı
- Apple Music aboneliği

## 📦 Kurulum

### 1. Projeyi Klonlayın

```bash
git clone https://github.com/KULLANICI_ADINIZ/SpotifyTasiyici.git
cd SpotifyTasiyici
```

### 2. Spotify API Ayarları

1. [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)'a gidin
2. Yeni bir uygulama oluşturun
3. Redirect URI olarak `spotify-tasiyici://callback` ekleyin
4. Client ID ve Client Secret'ı kopyalayın

### 3. Config Dosyasını Oluşturun

```bash
cd SpotifyTasiyici
cp Config.Example.swift Config.swift
```

`Config.swift` dosyasını açın ve kendi Spotify API bilgilerinizi girin:

```swift
struct SpotifyConfig {
    static let clientID = "BURAYA_CLIENT_ID"
    static let clientSecret = "BURAYA_CLIENT_SECRET"
    static let redirectURI = "spotify-tasiyici://callback"
}
```

### 4. Xcode'da Açın ve Çalıştırın

```bash
open SpotifyTasiyici.xcodeproj
```

## 🚀 Kullanım

1. **Spotify'dan Yükle** butonuna tıklayarak Spotify hesabınıza giriş yapın
2. Beğenilen şarkılarınız otomatik olarak yüklenecektir
3. Playlist adını girin
4. **Aktarımı Başlat** butonuna tıklayın
5. Uygulama otomatik olarak:
   - Her şarkıyı Apple Music'te arayacak
   - Yeni bir playlist oluşturacak
   - Bulunan şarkıları playlist'e ekleyecek

## 📱 Ekran Görüntüleri

*(Buraya ekran görüntülerini ekleyebilirsiniz)*

## 🔒 Güvenlik

⚠️ **ÖNEMLİ:** `Config.swift` dosyası hassas bilgiler içerir ve `.gitignore` ile korunmaktadır. Bu dosyayı asla GitHub'a yüklemeyin!

## 🏗️ Mimari

- **TransferManager**: Aktarım sürecini yöneten ana sınıf
- **SpotifyAPIManager**: Spotify API entegrasyonu
- **AppleMusicAPIManager**: Apple Music API entegrasyonu
- **ContentView**: SwiftUI arayüzü

## 📝 Yapılacaklar

- [ ] Daha gelişmiş eşleştirme algoritması
- [ ] Batch işleme optimizasyonu
- [ ] Hata ayıklama ve log sistemi
- [ ] İstatistik ekranı
- [ ] Karanlık mod desteği

## 🤝 Katkıda Bulunma

Pull request'ler memnuniyetle karşılanır! Büyük değişiklikler için lütfen önce bir issue açın.

## 📄 Lisans

Bu proje MIT lisansı altında lisanslanmıştır.

## 👤 Geliştirici

Zafer Avcı

---

⭐ Projeyi beğendiyseniz yıldız vermeyi unutmayın!

