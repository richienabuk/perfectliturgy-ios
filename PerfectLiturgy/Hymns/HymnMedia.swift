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
        let audios = audioURLs.compactMap(URL.init(string:))
        let videos = videoURLs.compactMap(URL.init(string:))
        let sheets = sheetMusicURLs.compactMap(URL.init(string:))
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

enum HymnVideo {
    static func embedURL(for url: URL) -> URL? {
        let host = url.host?.lowercased() ?? ""
        if host.contains("youtu.be") || host.contains("youtube.com") {
            guard let identifier = youtubeID(from: url) else { return nil }
            return URL(string: "https://www.youtube.com/embed/\(identifier)")
        }
        if host.contains("vimeo.com") {
            guard let identifier = url.pathComponents.last(where: { Int($0) != nil }) else { return nil }
            return URL(string: "https://player.vimeo.com/video/\(identifier)")
        }
        return nil
    }

    static func youtubeID(from url: URL) -> String? {
        let host = url.host?.lowercased() ?? ""
        if host.contains("youtu.be") {
            let identifier = url.pathComponents.dropFirst().first
            return identifier?.isEmpty == false ? identifier : nil
        }
        if let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
            .first(where: { $0.name == "v" })?.value, !query.isEmpty {
            return query
        }
        if let embed = url.pathComponents.firstIndex(of: "embed"),
           embed + 1 < url.pathComponents.count {
            return url.pathComponents[embed + 1]
        }
        return nil
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
                let (data, _) = try await URLSession.shared.data(from: url)
                if let document = PDFDocument(data: data) {
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
