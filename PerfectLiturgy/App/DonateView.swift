import SwiftUI

struct DonateView: View {
    var body: some View {
        SafariPage(url: WebLink.donate)
            .ignoresSafeArea()
            .navigationTitle("Donate")
            .toolbar(.hidden, for: .navigationBar)
    }
}
