import Foundation
import MusicKit

struct AppleMusicAPIManager {
    
    static func requestAuthorization() async -> MusicAuthorization.Status {
        let status = await MusicAuthorization.request()
        
        switch status {
        case .authorized:
            print("✅ Apple Music authorization granted")
        case .denied:
            print("❌ Apple Music authorization denied")
        case .notDetermined:
            print("⚠️ Apple Music authorization not determined")
        case .restricted:
            print("🚫 Apple Music authorization restricted")
        @unknown default:
            print("❓ Unknown Apple Music authorization status")
        }
        
        return status
    }
    
    static var currentAuthorizationStatus: MusicAuthorization.Status {
        return MusicAuthorization.currentStatus
    }
    
    static var isAuthorized: Bool {
        return MusicAuthorization.currentStatus == .authorized
    }
    
    static func searchSong(term: String) async -> Song? {
        guard isAuthorized else {
            print("❌ Apple Music authorization required to search songs")
            return nil
        }
        
        guard !term.isEmpty else {
            print("⚠️ Search term cannot be empty")
            return nil
        }
        
        do {
            var searchRequest = MusicCatalogSearchRequest(term: term, types: [Song.self])
            searchRequest.limit = 1
            
            let searchResponse = try await searchRequest.response()
            
            if let firstSong = searchResponse.songs.first {
                print("🎵 Found song: \(firstSong.title) by \(firstSong.artistName)")
                return firstSong
            } else {
                print("❓ No songs found for term: '\(term)'")
                return nil
            }
            
        } catch {
            print("❌ Error searching for song: \(error.localizedDescription)")
            return nil
        }
    }
}
