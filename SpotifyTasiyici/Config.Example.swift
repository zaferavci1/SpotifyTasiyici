//
//  Config.Example.swift
//  SpotifyTasiyici
//
//  KULLANIM TALİMATI:
//  1. Bu dosyayı "Config.swift" olarak kopyalayın
//  2. Aşağıdaki değerleri kendi Spotify API bilgilerinizle değiştirin
//  3. Spotify Developer Dashboard: https://developer.spotify.com/dashboard
//

import Foundation

struct SpotifyConfig {
    static let clientID = "BURAYA_SPOTIFY_CLIENT_ID_GİRİN"
    static let clientSecret = "BURAYA_SPOTIFY_CLIENT_SECRET_GİRİN"
    static let redirectURI = "spotify-tasiyici://callback"
}

