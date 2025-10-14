import Foundation
import Combine
import MusicKit

// Her bir şarkının aktarım durumunu takip eden etiketler.
enum TransferStatus: Codable {
    case pending    // Bekliyor
    case searching  // Apple Music'te aranıyor
    case found      // Eşleşme bulundu
    case notFound   // Eşleşme bulunamadı
    case adding     // Kütüphaneye ekleniyor
    case added      // Başarıyla eklendi
    case failed     // Hata oluştu
}

// Her bir şarkının bilgilerini ve aktarım durumunu tutan "kimlik kartı".
// Codable olması, JSON'a çevrilip diske kaydedilebilmesini sağlar.
struct SongTransfer: Identifiable, Codable {
    let id: UUID
    let spotifyTrackName: String
    let spotifyArtistName: String
    var status: TransferStatus
    var appleMusicId: String?
}

// Tüm aktarım sürecini yöneten "beyin".
final class TransferManager: ObservableObject {
    // Arayüzün anlık olarak takip edebilmesi için @Published olarak işaretlendi.
    @Published var transferQueue: [SongTransfer] = []
    
    // Verinin kaydedileceği dosyanın tam yolu.
    private let fileURL: URL
    
    init() {
        // Dosya yolunu belirle (uygulamanın Documents klasöründe transfers.json)
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = documentsDirectory.appendingPathComponent("transfers.json")
        
        // Uygulama başlarken, daha önce kaydedilmiş bir kuyruk varsa yükle.
        loadQueue()
    }
    
    // MARK: - Kalıcı Hafıza Fonksiyonları
    
    /// Kuyruğun mevcut durumunu diske (transfers.json) kaydeder.
    private func saveQueue() {
        do {
            let data = try JSONEncoder().encode(transferQueue)
            try data.write(to: fileURL)
            print("✅ Kuyruk başarıyla dosyaya kaydedildi.")
        } catch {
            print("❌ Kuyruk kaydedilirken hata oluştu: \(error.localizedDescription)")
        }
    }
    
    /// Diskteki transfers.json dosyasından kuyruğu yükler.
    private func loadQueue() {
        do {
            let data = try Data(contentsOf: fileURL)
            transferQueue = try JSONDecoder().decode([SongTransfer].self, from: data)
            print("✅ Kayıtlı kuyruk başarıyla yüklendi. \(transferQueue.count) şarkı bulundu.")
        } catch {
            print("ℹ️ Kayıtlı bir kuyruk bulunamadı. Sıfırdan başlanıyor.")
        }
    }
    
    /// Kuyruğu sıfırlar ve kayıtlı dosyayı siler.
    func resetQueue() {
        // Kuyruğu temizle
        transferQueue.removeAll()
        print("✅ Kuyruk temizlendi.")
        
        // Dosyayı sil
        do {
            try FileManager.default.removeItem(at: fileURL)
            print("✅ Kayıtlı kuyruk dosyası başarıyla silindi.")
        } catch {
            print("ℹ️ Kuyruk dosyası silinemedi: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Sprint 2: Aktarım Mantığı
    
    /// Spotify'dan gelen şarkı listesiyle aktarım kuyruğunu doldurur.
    /// Sadece kuyruk boşsa çalışır, böylece mevcut ilerleme kaybolmaz.
    func populateQueue(from spotifySongs: [(trackName: String, artistName: String)]) {
        guard transferQueue.isEmpty else {
            print("ℹ️ Kuyruk zaten dolu, doldurma işlemi atlandı.")
            return
        }
        
        self.transferQueue = spotifySongs.map { song in
            SongTransfer(
                id: UUID(),
                spotifyTrackName: song.trackName,
                spotifyArtistName: song.artistName,
                status: .pending, // Tüm şarkılar "Bekliyor" durumuyla başlar.
                appleMusicId: nil
            )
        }
        print("✅ Kuyruk \(transferQueue.count) şarkı ile dolduruldu.")
        saveQueue() // Kuyruğun ilk halini diske kaydet.
    }
    
    /// Kuyruktaki şarkıları baştan sona işleyen ana motor.
    func processQueue(playlistName: String) async {
        print("🚀 Aktarım süreci başlatıldı...")
        
        // Apple Music izni kontrolü ve isteme
        let authStatus = await MusicAuthorization.request()
        guard authStatus == .authorized else {
            print("❌ Apple Music izni verilmedi. Durum: \(authStatus)")
            return
        }
        print("✅ Apple Music izni alındı.")
        
        // Yeni playlist oluştur
        let playlist: Playlist
        do {
            playlist = try await MusicLibrary.shared.createPlaylist(name: playlistName, description: "Spotify'dan aktarılan şarkılar")
            print("✅ Playlist oluşturuldu: \(playlistName)")
        } catch {
            print("❌ Playlist oluşturma hatası: \(error.localizedDescription)")
            return
        }
        
        for index in transferQueue.indices {
            // DURUM KONTROLÜ (Mükerrerliği Önleme):
            // Eğer şarkının durumu ".pending" değilse, bu şarkı zaten işlenmiş veya
            // işlenmeye çalışılmış demektir. Hiçbir şey yapmadan bir sonrakine geç.
            guard transferQueue[index].status == .pending else {
                continue
            }
            
            // 1. Durumu "Aranıyor" olarak güncelle ve kaydet.
            await updateStatus(for: index, to: .searching)
            
            // 2. Apple Music'te eşleşme ara.
            if let appleMusicSong = await findMatch(for: transferQueue[index]) {
                
                // 3. Eşleşme bulundu, durumu güncelle ve kaydet.
                await updateStatus(for: index, to: .found, appleMusicId: appleMusicSong.id.rawValue)
                await updateStatus(for: index, to: .adding)
                
                // 4. Şarkıyı Apple Music playlist'ine ekle.
                if await addToAppleMusic(song: appleMusicSong, to: playlist) {
                    await updateStatus(for: index, to: .added)
                    print("✅ Eklendi: \(transferQueue[index].spotifyTrackName)")
                } else {
                    await updateStatus(for: index, to: .failed)
                    print("❌ Eklenemedi: \(transferQueue[index].spotifyTrackName)")
                }
                
            } else {
                // 5. Eşleşme bulunamadı, durumu güncelle ve kaydet.
                await updateStatus(for: index, to: .notFound)
                print("⚠️ Bulunamadı: \(transferQueue[index].spotifyTrackName)")
            }
            
            // HIZ LİMİTİ ÖNLEMİ: Apple Music API'ını yormamak için her işlemden sonra kısa bir bekleme yap.
            try? await Task.sleep(nanoseconds: 500_000_000) // 500 milliseconds
        }
        print("🎉 Aktarım süreci tamamlandı.")
    }
    
    /// Bir şarkının durumunu güncelleyen ve değişikliği diske kaydeden yardımcı fonksiyon.
    private func updateStatus(for index: Int, to newStatus: TransferStatus, appleMusicId: String? = nil) async {
        await MainActor.run {
            transferQueue[index].status = newStatus
            if let id = appleMusicId {
                transferQueue[index].appleMusicId = id
            }
            saveQueue()
        }
    }
    
    // MARK: - MusicKit Fonksiyonları
    
    /// Bir şarkı için Apple Music'te eşleşme bulur.
    func findMatch(for song: SongTransfer) async -> Song? {
        print("🔎 Aranıyor: \(song.spotifyTrackName)")
        
        // Arama terimi: şarkı adı + sanatçı adı
        let searchTerm = "\(song.spotifyTrackName) \(song.spotifyArtistName)"
        
        // MusicCatalogSearchRequest oluştur
        var request = MusicCatalogSearchRequest(term: searchTerm, types: [Song.self])
        request.limit = 5
        
        do {
            let response = try await request.response()
            
            // İlk sonucu döndür (varsa)
            if let firstSong = response.songs.first {
                print("✅ Bulundu: \(firstSong.title) - \(firstSong.artistName)")
                return firstSong
            } else {
                print("⚠️ Sonuç bulunamadı: \(song.spotifyTrackName)")
                return nil
            }
        } catch {
            print("❌ Arama hatası: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Bir şarkıyı belirtilen playlist'e ekler.
    func addToAppleMusic(song: Song, to playlist: Playlist) async -> Bool {
        print("🎵 Ekleniyor: \(song.title)")
        
        do {
            try await MusicLibrary.shared.add(song, to: playlist)
            print("✅ Başarıyla eklendi: \(song.title)")
            return true
        } catch {
            print("❌ Ekleme hatası: \(error.localizedDescription)")
            return false
        }
    }
}

