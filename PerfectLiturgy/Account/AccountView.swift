import SwiftData
import SwiftUI

struct AccountView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var modelContext

    @Query private var bookmarks: [HymnBookmark]
    @State private var email = ""

    private var client: AuthClient { .live }

    var body: some View {
        VStack(spacing: 0) {
            PLTopBar()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if session.isSignedIn {
                        signedIn
                    } else {
                        signedOut
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .background(palette.background.color)
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var signedOut: some View {
        card {
            VStack(spacing: 16) {
                AccountMark()
                    .padding(.top, 8)
                Text(AccountCopy.signedOutTitle)
                    .font(AppFont.title(size: 32))
                    .foregroundStyle(palette.foreground.color)
                    .multilineTextAlignment(.center)
                Text(AccountCopy.signedOutSupport)
                    .font(AppFont.body(size: 15))
                    .foregroundStyle(palette.mutedForeground.color)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                providerButton(title: "Continue with Google", identifier: "account.google") {
                    Task { await google() }
                } icon: {
                    Text("G")
                        .font(AppFont.interface(size: 18, weight: .semibold))
                        .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                }
                providerButton(title: "Continue with Apple", identifier: "account.apple") {
                    Task { await apple() }
                } icon: {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(palette.foreground.color)
                }
                emailDivider
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email address")
                        .font(AppFont.interface(size: 16, weight: .semibold))
                        .foregroundStyle(palette.foreground.color)
                    ZStack(alignment: .leading) {
                        if email.isEmpty {
                            Text("you@example.com")
                                .font(AppFont.interface(size: 16))
                                .foregroundStyle(palette.mutedForeground.color)
                                .padding(.horizontal, 14)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                        TextField("", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocorrectionDisabled()
                            .submitLabel(.go)
                            .font(AppFont.interface(size: 16))
                            .foregroundStyle(palette.foreground.color)
                            .tint(palette.primary.color)
                            .padding(.horizontal, 14)
                            .frame(maxWidth: .infinity, minHeight: ControlMetrics.minimumHeight, alignment: .leading)
                            .accessibilityLabel("Email address")
                            .accessibilityIdentifier("account.email")
                            .onSubmit { Task { await sendLink() } }
                    }
                    .background(palette.background.color, in: RoundedRectangle(cornerRadius: Radius.md))
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.md)
                            .strokeBorder(palette.input.color, lineWidth: 1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    Task { await sendLink() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "envelope")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Email me a sign-in link")
                            .font(AppFont.interface(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(palette.primaryForeground.color)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: ControlMetrics.minimumHeight)
                    .background(palette.primary.color, in: RoundedRectangle(cornerRadius: Radius.md))
                }
                .buttonStyle(PressScaleButtonStyle())
                .disabled(session.isWorking)
                .opacity(session.isWorking ? 0.4 : 1)
                .accessibilityIdentifier("account.magicLink")
                if let notice = session.notice {
                    Text(notice)
                        .font(AppFont.body(size: 13))
                        .foregroundStyle(notice == AccountCopy.magicLinkSent ? palette.mutedForeground.color : palette.emphasis.color)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("account.notice")
                }
            }
        }
    }

    private var signedIn: some View {
        VStack(alignment: .leading, spacing: 16) {
            card {
                VStack(alignment: .leading, spacing: 12) {
                    AccountMark()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    Text(AccountCopy.signedInTitle)
                        .font(AppFont.title(size: 32))
                        .foregroundStyle(palette.foreground.color)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                    VStack(spacing: 4) {
                        if let name = session.profile?.name, !name.isEmpty, name != session.profile?.email {
                            Text(name)
                                .font(AppFont.interface(size: 16, weight: .semibold))
                                .foregroundStyle(palette.foreground.color)
                        }
                        Text(session.profile?.email ?? "Signed in")
                            .font(AppFont.interface(size: 16, weight: .semibold))
                            .foregroundStyle(palette.foreground.color)
                        if let method = session.method {
                            Text(AccountCopy.methodLine(method))
                                .font(AppFont.body(size: 14))
                                .foregroundStyle(palette.mutedForeground.color)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    Button {
                        Task { await session.signOut(client: client) }
                    } label: {
                        Text("Sign out")
                            .font(AppFont.interface(size: 16, weight: .semibold))
                            .foregroundStyle(palette.foreground.color)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: ControlMetrics.minimumHeight)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .disabled(session.isWorking)
                    .accessibilityIdentifier("account.signOut")
                    if let notice = session.notice {
                        Text(notice)
                            .font(AppFont.body(size: 13))
                            .foregroundStyle(palette.mutedForeground.color)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("account.notice")
                    }
                }
            }
            Button {
                navigation.showSaved()
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AccountCopy.savedTitle)
                            .font(AppFont.interface(size: 16, weight: .semibold))
                            .foregroundStyle(palette.foreground.color)
                        Text(AccountCopy.savedDetail(count: bookmarks.count))
                            .font(AppFont.body(size: 14))
                            .foregroundStyle(palette.mutedForeground.color)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.mutedForeground.color)
                }
                .frame(minHeight: ControlMetrics.minimumHeight)
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityIdentifier("account.saved")
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AccountCopy.syncTitle)
                        .font(AppFont.interface(size: 16, weight: .semibold))
                        .foregroundStyle(palette.foreground.color)
                    Text(AccountCopy.syncStatus)
                        .font(AppFont.body(size: 14))
                        .foregroundStyle(palette.mutedForeground.color)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(palette.mutedForeground.color)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: ControlMetrics.minimumHeight)
            .accessibilityElement(children: .combine)
        }
    }

    private var emailDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(palette.border.color)
                .frame(height: 1)
            Text("OR CONTINUE WITH EMAIL")
                .font(AppFont.eyebrow())
                .tracking(AppFont.eyebrowTracking)
                .foregroundStyle(palette.mutedForeground.color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: true, vertical: false)
            Rectangle()
                .fill(palette.border.color)
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.card.color, in: RoundedRectangle(cornerRadius: Radius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg)
                    .strokeBorder(palette.border.color, lineWidth: 1)
            }
    }

    private func providerButton<Icon: View>(
        title: String,
        identifier: String,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                icon()
                Text(title)
                    .font(AppFont.interface(size: 16, weight: .semibold))
            }
            .foregroundStyle(palette.foreground.color)
            .frame(maxWidth: .infinity)
            .frame(minHeight: ControlMetrics.minimumHeight)
            .background(palette.background.color, in: RoundedRectangle(cornerRadius: Radius.md))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md)
                    .strokeBorder(palette.border.color, lineWidth: 1)
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(session.isWorking)
        .opacity(session.isWorking ? 0.4 : 1)
        .accessibilityIdentifier(identifier)
    }

    private func google() async {
        session.prepare(.google)
        session.isWorking = true
        do {
            let url = try await WebSignIn().authenticate(client.startURL(provider: "google"))
            await session.accept(url, client: client, context: modelContext)
        } catch AuthError.cancelled {
            session.cancelPending()
        } catch {
            session.cancelPending()
            session.notice = AccountCopy.connection
        }
    }

    private func apple() async {
        do {
            let credential = try await AppleSignIn().authenticate()
            await session.signInWithApple(
                identityToken: credential.identityToken,
                nonce: credential.nonce,
                name: credential.name,
                client: client,
                context: modelContext
            )
        } catch AuthError.cancelled {
            return
        } catch {
            session.notice = AccountCopy.appleUnavailable
        }
    }

    private func sendLink() async {
        await session.sendMagicLink(email: email, client: client)
    }
}

private struct AccountMark: View {
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            AccountArch()
                .stroke(palette.emphasis.color, lineWidth: 1.5)
            Image(systemName: "person")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(palette.emphasis.color)
                .offset(y: 4)
        }
        .frame(width: 54, height: 58)
        .accessibilityHidden(true)
    }
}

private nonisolated struct AccountArch: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = rect.width / 2
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

#Preview {
    AccountView()
        .modelContainer(try! HymnStore.make(inMemory: true))
        .environment(AppNavigation())
        .environment(AppSession(token: nil, store: MemorySessionStore()))
        .resolvePalette()
}
