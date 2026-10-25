import SwiftUI

struct SyncSheet: View {
    @Environment(SyncController.self) private var sync
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(SyncCopy.title)
                .font(AppFont.title(size: 32))
                .foregroundStyle(palette.foreground.color)
            if sync.phase == .working || sync.phase == .idle {
                ProgressView()
                    .tint(palette.primary.color)
            }
            Text(message)
                .font(AppFont.body())
                .foregroundStyle(palette.foreground.color)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("sync.message")
            Spacer(minLength: 0)
            if sync.phase == .working || sync.phase == .idle {
                Button {
                    sync.cancel()
                    sync.showsSheet = false
                } label: {
                    Text("Cancel")
                        .font(AppFont.interface(size: 16, weight: .semibold))
                        .foregroundStyle(palette.foreground.color)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: ControlMetrics.minimumHeight)
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityIdentifier("sync.cancel")
            }
            Button {
                sync.showsSheet = false
            } label: {
                Text("Done")
                    .font(AppFont.interface(size: 16, weight: .semibold))
                    .foregroundStyle(palette.primaryForeground.color)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: ControlMetrics.minimumHeight)
                    .background(palette.primary.color, in: RoundedRectangle(cornerRadius: Radius.md))
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(sync.phase == .working || sync.phase == .idle)
            .opacity(sync.phase == .working || sync.phase == .idle ? 0.4 : 1)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.background.color)
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium])
        .presentationBackground(palette.background.color)
        .accessibilityIdentifier("sync.sheet")
    }

    private var message: String {
        switch sync.phase {
        case .idle, .working:
            SyncCopy.working
        case .finished(let report):
            switch report.outcome {
            case .current:
                report.bookmarksKept ? "\(SyncCopy.current) \(SyncCopy.bookmarksNotSent)" : SyncCopy.current
            case .needsSignIn:
                SyncCopy.signIn
            case .connection:
                SyncCopy.connection
            }
        }
    }
}
