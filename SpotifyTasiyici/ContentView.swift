//
//  ContentView.swift
//  SpotifyTasiyici
//
//  Created by Zafer Avcı on 14.10.2025.
//

import SwiftUI
import MusicKit

struct ContentView: View {
    // TEK VE DOĞRU BİLGİ KAYNAĞI: TransferManager
    @StateObject private var transferManager = TransferManager()
    @State private var playlistName: String = ""
    
    // MARK: - Computed Properties for UI
    
    private var totalCount: Int {
        transferManager.transferQueue.count
    }
    
    private var processedCount: Int {
        transferManager.transferQueue.filter { $0.status != .pending }.count
    }
    
    private var recentLogs: [SongTransfer] {
        transferManager.transferQueue
            .filter { $0.status != .pending }
            .reversed()
            .prefix(10)
            .map { $0 }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Spotify -> Apple Music Aktarım")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)

            if totalCount > 0 {
                Text("\(totalCount) şarkıdan \(processedCount)'i işlendi")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                ProgressView(value: Double(processedCount), total: Double(totalCount))
                    .padding(.horizontal)
            } else {
                 Text("Başlamak için Spotify'dan şarkıları yükleyin.")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            List(recentLogs) { song in
                HStack {
                    statusIcon(for: song.status)
                    VStack(alignment: .leading) {
                        Text(song.spotifyTrackName)
                            .fontWeight(.semibold)
                        Text(song.spotifyArtistName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            
            // Playlist adı girişi
            TextField("Yeni Çalma Listesi Adı", text: $playlistName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            
            // Kontrol Butonları
            HStack(spacing: 20) {
                Button("1. Spotify'dan Yükle") {
                    Task {
                        await loadSongsFromSpotify()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!transferManager.transferQueue.isEmpty)
                
                Button("2. Aktarımı Başlat") {
                    Task {
                        await transferManager.processQueue(playlistName: playlistName)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(transferManager.transferQueue.isEmpty || playlistName.isEmpty)
                
                Button("Sıfırla") {
                    transferManager.resetQueue()
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(transferManager.transferQueue.isEmpty)
            }
            .padding()
        }
        .padding()
    }
    
    // MARK: - Helper Functions
    
    /// Spotify'dan şarkıları çeker ve TransferManager'ın kuyruğunu doldurur.
    private func loadSongsFromSpotify() async {
        do {
            let accessToken = try await withCheckedThrowingContinuation { continuation in
                SpotifyAPIManager.shared.authenticate { result in
                    continuation.resume(with: result)
                }
            }
            print("✅ Spotify authentication successful!")
            
            let fetchedSongs = await SpotifyAPIManager.shared.fetchLikedSongs(accessToken: accessToken)
            
            // EN ÖNEMLİ ADIM: Veriyi TransferManager'a teslim et.
            await MainActor.run {
                transferManager.populateQueue(from: fetchedSongs)
            }
        } catch {
            print("❌ Spotify bağlantı veya şarkı çekme hatası: \(error.localizedDescription)")
        }
    }
    
    /// Şarkı durumuna göre arayüzde gösterilecek ikonu belirler.
    @ViewBuilder
    private func statusIcon(for status: TransferStatus) -> some View {
        switch status {
        case .added:
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundColor(.red)
        case .notFound:
            Image(systemName: "questionmark.circle.fill").foregroundColor(.orange)
        case .searching, .adding:
            ProgressView().frame(width: 20, height: 20)
        case .found:
            Image(systemName: "magnifyingglass.circle.fill").foregroundColor(.blue)
        case .pending:
            Image(systemName: "hourglass.circle.fill").foregroundColor(.gray)
        }
    }
}

#Preview {
    ContentView()
}

