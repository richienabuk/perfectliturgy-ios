import SwiftUI

struct MassTimesView: View {
    var body: some View {
        SafariPage(url: WebLink.massTimes)
            .ignoresSafeArea()
            .navigationTitle("Mass Times")
            .toolbar(.hidden, for: .navigationBar)
    }
}
