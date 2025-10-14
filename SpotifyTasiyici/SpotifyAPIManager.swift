import Foundation
import AuthenticationServices

class SpotifyAPIManager: NSObject, ASWebAuthenticationPresentationContextProviding {
    // MARK: - Singleton
    static let shared = SpotifyAPIManager()
    
    // MARK: - Properties
    private let clientID: String
    private let clientSecret: String
    private let redirectURI: String
    
    private(set) var accessToken: String?
    
    // MARK: - Initialization
    private override init() {
        self.clientID = "4c7c75d2d8424a308e026cf361a7f4dc"
        self.clientSecret = "accea17f291642b59747e60a54a2a3bb"
        self.redirectURI = "spotify-tasiyici://callback"
    }
    
    // MARK: - Authentication Flow
    func getAuthorizationURL() -> URL? {
        var urlComponents = URLComponents(string: "https://accounts.spotify.com/authorize")!
        urlComponents.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: "user-library-read")
        ]
        return urlComponents.url
    }
    
    func authenticate(completion: @escaping (Result<String, Error>) -> Void) {
        guard let authURL = getAuthorizationURL() else {
            completion(.failure(SpotifyAuthError.invalidURL))
            return
        }
        
        let authSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "spotify-tasiyici"
        ) { [weak self] callbackURL, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let callbackURL = callbackURL,
                  let authorizationCode = URLComponents(url: callbackURL, resolvingAgainstBaseURL: true)?.queryItems?.first(where: { $0.name == "code" })?.value else {
                completion(.failure(SpotifyAuthError.noAuthorizationCode))
                return
            }
            self?.exchangeCodeForToken(code: authorizationCode, completion: completion)
        }
        
        authSession.presentationContextProvider = self
        authSession.prefersEphemeralWebBrowserSession = true
        authSession.start()
    }
    
    private func exchangeCodeForToken(code: String, completion: @escaping (Result<String, Error>) -> Void) {
        // DÜZELTME: URL, /api/token olmalı.
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else {
            completion(.failure(SpotifyAuthError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: self.redirectURI)
        ]
        request.httpBody = bodyComponents.query?.data(using: .utf8)
        
        let authHeader = "\(self.clientID):\(self.clientSecret)".data(using: .utf8)!.base64EncodedString()
        request.setValue("Basic \(authHeader)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(SpotifyAuthError.noDataReceived))
                return
            }
            
            // Bonus: Olası hataları görmek için gelen veriyi string olarak yazdır.
            if let responseString = String(data: data, encoding: .utf8) {
                print("Token sunucusundan gelen cevap: \(responseString)")
            }

            do {
                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                self.accessToken = tokenResponse.access_token
                completion(.success(tokenResponse.access_token))
            } catch {
                // JSON parse hatası burada yakalanır.
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    func fetchLikedSongs(accessToken: String) async -> [(trackName: String, artistName: String)] {
        var allSongs: [(trackName: String, artistName: String)] = []
        
        // Başlangıç URL'imiz
        var nextUrlString: String? = "https://api.spotify.com/v1/me/tracks"
        
        // "next" URL'i olduğu sürece döngüye devam et
        while let urlString = nextUrlString {
            guard let url = URL(string: urlString) else {
                print("Geçersiz URL: \(urlString)")
                break // Döngüyü kır
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    print("HTTP Hatası: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                    break // Döngüyü kır
                }
                
                let likedSongsResponse = try JSONDecoder().decode(LikedSongsResponse.self, from: data)
                
                // Bu sayfadaki şarkıları ana listeye ekle
                let songsFromThisPage = likedSongsResponse.items.map { item -> (trackName: String, artistName: String) in
                    let artistNames = item.track.artists.map { $0.name }.joined(separator: ", ")
                    return (trackName: item.track.name, artistName: artistNames)
                }
                allSongs.append(contentsOf: songsFromThisPage)
                
                print("✅ \(songsFromThisPage.count) şarkı daha çekildi. Toplam: \(allSongs.count)")

                // Bir sonraki sayfanın URL'ini al. Eğer yoksa (nil ise), döngü duracak.
                nextUrlString = likedSongsResponse.next
                
            } catch {
                print("❌ Şarkılar çekilirken hata oluştu: \(error.localizedDescription)")
                break // Hata durumunda döngüyü kır
            }
        }
        
        print("🎉 Toplamda \(allSongs.count) adet beğenilen şarkı çekildi.")
        return allSongs
    }


    // MARK: - Data Models
    // LikedSongsResponse modeline "next" ve "total" alanlarını ekleyin
    struct LikedSongsResponse: Codable {
        let items: [LikedSongItem]
        let next: String? // Bir sonraki sayfanın URL'i
        let total: Int    // Toplam şarkı sayısı
    }
    
    // MARK: - ASWebAuthenticationPresentationContextProviding
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

// MARK: - Data Models
struct TokenResponse: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
}
struct LikedSongsResponse: Codable {
    let items: [LikedSongItem]
}
struct LikedSongItem: Codable {
    let track: Track
}
struct Track: Codable {
    let name: String
    let artists: [Artist]
}
struct Artist: Codable {
    let name: String
}

// MARK: - Errors
enum SpotifyAuthError: Error, LocalizedError {
    case invalidURL
    case noCallbackURL
    case noAuthorizationCode
    case noDataReceived
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Failed to create URL"
        case .noCallbackURL: return "No callback URL received"
        case .noAuthorizationCode: return "No authorization code found in callback URL"
        case .noDataReceived: return "No data received from token exchange"
        }
    }
}


