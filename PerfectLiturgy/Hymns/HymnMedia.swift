import AVFoundation
import PDFKit
import SwiftUI
import WebKit

struct HymnMediaSection: View {
    var audioURLs: [String]
    var videoURLs: [String]
    var sheetMusicURLs: [String]

    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var openURL
    @State private var player: AVPlayer?
    @State private var playingURL: String?
    @State private var audioNote: String?

    var body: some View {
        let audios = audioURLs.compactMap(HymnMediaURL.safe)
        let videos = videoURLs.compactMap(HymnMediaURL.safe)
        let sheets = sheetMusicURLs.compactMap(HymnMediaURL.safe)
        if audios.isEmpty && videos.isEmpty && sheets.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(audios.enumerated()), id: \.offset) { index, url in
                    PLButton(title: audioTitle(index: index, url: url, count: audios.count), kind: .outline) {
                        toggleAudio(url)
                    }
                }
                if let audioNote {
                    Text(audioNote)
                        .font(AppFont.body(size: 14))
                        .foregroundStyle(palette.mutedForeground.color)
                }
                ForEach(Array(videos.enumerated()), id: \.offset) { _, url in
                    video(url)
                }
                ForEach(Array(sheets.enumerated()), id: \.offset) { _, url in
                    sheet(url)
                }
            }
            .onDisappear {
                player?.pause()
                playingURL = nil
            }
        }
    }

    private func audioTitle(index: Int, url: URL, count: Int) -> String {
        let playing = playingURL == url.absoluteString
        let label = count == 1 ? "audio" : "audio \(index + 1)"
        return playing ? "Pause \(label)" : "Play \(label)"
    }

    private func toggleAudio(_ url: URL) {
        if playingURL == url.absoluteString {
            player?.pause()
            playingURL = nil
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            audioNote = "This recording needs a connection."
            return
        }
        let item = AVPlayerItem(url: url)
        let next = AVPlayer(playerItem: item)
        player = next
        playingURL = url.absoluteString
        audioNote = nil
        next.play()
    }

    @ViewBuilder
    private func video(_ url: URL) -> some View {
        if let embed = HymnVideo.embedURL(for: url) {
            HymnVideoView(url: embed)
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        } else {
            PLButton(title: "Open video", kind: .outline) {
                openURL(url)
            }
        }
    }

    @ViewBuilder
    private func sheet(_ url: URL) -> some View {
        let kind = url.pathExtension.lowercased()
        if ["png", "jpg", "jpeg", "gif", "webp", "heic"].contains(kind) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Text("Opening sheet music.")
                    .font(AppFont.body(size: 14))
                    .foregroundStyle(palette.mutedForeground.color)
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        } else if kind == "pdf" {
            HymnPDFView(url: url)
                .frame(height: 360)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        } else {
            PLButton(title: "Open sheet music", kind: .outline) {
                openURL(url)
            }
        }
    }
}

/// Media links come from a pack. Only secure web links open, whatever the pack says.
enum HymnMediaURL {
    static func safe(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty
        else { return nil }
        return url
    }

    /// The host is one of the names, or a subdomain of one. `notyoutube.com` is neither.
    static func host(of url: URL, isOneOf names: [String]) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return names.contains { host == $0 || host.hasSuffix("." + $0) }
    }
}

enum HymnVideo {
    private static let youtubeHosts = ["youtube.com", "youtube-nocookie.com"]

    static func embedURL(for url: URL) -> URL? {
        if HymnMediaURL.host(of: url, isOneOf: ["youtu.be"] + youtubeHosts) {
            guard let identifier = youtubeID(from: url) else { return nil }
            return URL(string: "https://www.youtube.com/embed/\(identifier)")
        }
        if HymnMediaURL.host(of: url, isOneOf: ["vimeo.com"]) {
            guard let identifier = url.pathComponents.last(where: { Int($0) != nil }) else { return nil }
            return URL(string: "https://player.vimeo.com/video/\(identifier)")
        }
        return nil
    }

    static func youtubeID(from url: URL) -> String? {
        let candidate: String?
        if HymnMediaURL.host(of: url, isOneOf: ["youtu.be"]) {
            candidate = url.pathComponents.dropFirst().first
        } else if HymnMediaURL.host(of: url, isOneOf: youtubeHosts) {
            if let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                .first(where: { $0.name == "v" })?.value, !query.isEmpty {
                candidate = query
            } else if let embed = url.pathComponents.firstIndex(of: "embed"),
                      embed + 1 < url.pathComponents.count {
                candidate = url.pathComponents[embed + 1]
            } else {
                candidate = nil
            }
        } else {
            candidate = nil
        }
        guard let candidate, isVideoID(candidate) else { return nil }
        return candidate
    }

    /// Letters, digits, `-` and `_`. Nothing that could add a path or a query to the embed link.
    static func isVideoID(_ value: String) -> Bool {
        guard !value.isEmpty, value.utf8.count <= 32 else { return false }
        return value.utf8.allSatisfy { byte in
            (byte >= 97 && byte <= 122) || (byte >= 65 && byte <= 90) || (byte >= 48 && byte <= 57)
                || byte == 45 || byte == 95
        }
    }
}

private struct HymnVideoView: UIViewRepresentable {
    var url: URL

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.scrollView.isScrollEnabled = false
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

private struct HymnPDFView: View {
    var url: URL
    @State private var document: PDFDocument?
    @State private var failed = false

    var body: some View {
        Group {
            if let document {
                HymnPDFDocumentView(document: document)
            } else if failed {
                Text("Sheet music could not be opened.")
                    .font(AppFont.body(size: 14))
                    .foregroundStyle(Color.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Opening sheet music.")
                    .font(AppFont.body(size: 14))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                let ok = (response as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
                if ok, data.count <= 25_000_000, let document = PDFDocument(data: data) {
                    self.document = document
                } else {
                    failed = true
                }
            } catch {
                failed = true
            }
        }
    }
}

private struct HymnPDFDocumentView: UIViewRepresentable {
    var document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.document = document
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}
