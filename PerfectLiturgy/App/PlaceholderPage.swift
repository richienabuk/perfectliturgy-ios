import SwiftUI

struct PlaceholderPage<Accessory: View>: View {
    let title: String
    var heading: String?
    var emphasis: String?
    var note: String = "Nothing here yet."
    var columnWidth: CGFloat?
    @ViewBuilder var accessory: () -> Accessory

    @Environment(\.palette) private var palette

    private var headingText: String { heading ?? title }

    var body: some View {
        VStack(spacing: 0) {
            PLTopBar()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PLHeading(lead: headingText, emphasis: emphasis)
                    Text(note)
                        .font(AppFont.body())
                        .foregroundStyle(palette.mutedForeground.color)
                        .fixedSize(horizontal: false, vertical: true)
                    accessory()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: columnWidth ?? .infinity, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .background(palette.background.color)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }
}

extension PlaceholderPage where Accessory == EmptyView {
    init(
        title: String,
        heading: String? = nil,
        emphasis: String? = nil,
        note: String = "Nothing here yet.",
        columnWidth: CGFloat? = nil
    ) {
        self.init(title: title, heading: heading, emphasis: emphasis, note: note, columnWidth: columnWidth) {
            EmptyView()
        }
    }
}

struct PlaceholderLink: View {
    let title: String
    let route: AppRoute

    @Environment(\.palette) private var palette

    var body: some View {
        NavigationLink(value: route) {
            HStack(spacing: 12) {
                Text(title)
                    .font(AppFont.interface(size: 16, weight: .semibold))
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.mutedForeground.color)
            }
            .foregroundStyle(palette.foreground.color)
            .frame(minHeight: ControlMetrics.minimumHeight)
        }
    }
}
