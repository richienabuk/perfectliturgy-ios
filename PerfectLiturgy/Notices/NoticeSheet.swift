import SwiftUI

struct NoticeSheet: View {
    let notice: ParishNotice

    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(notice.title)
                    .font(AppFont.title(size: 32))
                    .foregroundStyle(palette.foreground.color)
                    .fixedSize(horizontal: false, vertical: true)
                if let body = notice.body, !body.isEmpty {
                    Text(body)
                        .font(AppFont.body())
                        .foregroundStyle(palette.foreground.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let imageURL = notice.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFit()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(palette.background.color)
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
        .presentationBackground(palette.background.color)
        .accessibilityIdentifier("notice.sheet")
    }
}
