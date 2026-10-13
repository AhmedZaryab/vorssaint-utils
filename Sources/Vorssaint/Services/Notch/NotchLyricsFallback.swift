// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// What the exact LRCLIB lookup cannot do. Players tag songs differently from
/// LRCLIB ("Song - Remastered 2011", "A, B" against "A"), so an exact miss
/// retries through the search endpoint and accepts a near match by title,
/// artist and length. Found lyrics are kept on disk, one small file per song.
enum NotchLyricsFallback {
    static func searchURL(for track: NotchMusicIdentity) -> URL? {
        guard !track.title.isEmpty, track.title.utf8.count <= 1024, track.artist.utf8.count <= 1024,
              track.duration.isFinite, (1...3600).contains(track.duration) else { return nil }
        var url = URLComponents(string: "https://lrclib.net/api/search")!
        url.queryItems = [URLQueryItem(name: "track_name", value: track.title),
                          URLQueryItem(name: "artist_name", value: track.artist)]
        return url.url
    }

    static func normalize(_ text: String) -> String {
        var value = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        while let open = value.firstIndex(where: { $0 == "(" || $0 == "[" }),
              let close = value[open...].firstIndex(where: { $0 == ")" || $0 == "]" }) {
            value.removeSubrange(open...close)
        }
        if let dash = value.range(of: " - ") { value = String(value[..<dash.lowerBound]) }
        return String(value.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }

    static func decodeBest(_ data: Data, for track: NotchMusicIdentity) -> NotchLyrics? {
        guard data.count <= 2 * NotchLyricsSupport.maximumBytes,
              let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        let title = normalize(track.title), artist = normalize(track.artist)
        var best: (score: Double, object: [String: Any])?
        for object in list {
            guard let name = object["trackName"] as? String, normalize(name) == title,
                  let by = object["artistName"] as? String else { continue }
            let other = normalize(by)
            guard artist.isEmpty || other.contains(artist) || artist.contains(other) else { continue }
            guard let duration = object["duration"] as? Double, duration.isFinite else { continue }
            let gap = abs(duration - track.duration)
            guard gap <= 5 else { continue }
            var score = 10 - gap
            if let synced = object["syncedLyrics"] as? String, !synced.isEmpty { score += 20 }
            if let album = object["albumName"] as? String, !track.album.isEmpty,
               normalize(album) == normalize(NotchLyricsSupport.catalogAlbum(track.album)) { score += 3 }
            if score > (best?.score ?? -.infinity) { best = (score, object) }
        }
        guard let object = best?.object else { return nil }
        let plain = (object["plainLyrics"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let instrumental = object["instrumental"] as? Bool == true
        let lines = NotchLyricsSupport.parse(object["syncedLyrics"] as? String ?? "", duration: track.duration)
        guard instrumental || !plain.isEmpty || !lines.isEmpty else { return nil }
        return NotchLyrics(lines: instrumental ? [] : lines, plain: instrumental ? "" : plain, instrumental: instrumental)
    }

    // MARK: Disk cache

    private static var directory: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Vorssaint/Lyrics", isDirectory: true)
    }

    private static func file(for track: NotchMusicIdentity) -> URL? {
        let key = [normalize(track.title), normalize(track.artist), String(Int(track.duration))].joined(separator: "|")
        guard !key.hasPrefix("|") else { return nil }
        var hash: UInt64 = 14695981039346656037
        for byte in key.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        return directory?.appendingPathComponent(String(hash, radix: 16) + ".json")
    }

    static func cached(for track: NotchMusicIdentity) -> NotchLyrics? {
        guard let url = file(for: track), let data = try? Data(contentsOf: url),
              data.count <= 2 * NotchLyricsSupport.maximumBytes,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let rows = object["lines"] as? [[Any]] ?? []
        let lines = rows.compactMap { row -> NotchLyricLine? in
            guard row.count == 2, let time = row[0] as? Double, let text = row[1] as? String else { return nil }
            return NotchLyricLine(time: time, text: text)
        }
        return NotchLyrics(lines: lines, plain: object["plain"] as? String ?? "",
                           instrumental: object["instrumental"] as? Bool == true)
    }

    static func store(_ lyrics: NotchLyrics, for track: NotchMusicIdentity) {
        guard let url = file(for: track), let directory else { return }
        let object: [String: Any] = ["lines": lyrics.lines.map { [$0.time, $0.text] as [Any] },
                                     "plain": lyrics.plain, "instrumental": lyrics.instrumental]
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
