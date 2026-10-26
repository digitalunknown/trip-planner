import SwiftUI
import AuthenticationServices

struct SignInGateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var auth: AppleSignInManager
    
    @State private var page = 0
    
    private var buttonMaxWidth: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 400 : .infinity
    }
    
    var body: some View {
        ZStack {
            AppDetailSurface.page
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                SignInOnboardingPager(page: $page)
                
                SignInOnboardingPageDots(
                    count: SignInOnboardingPage.allCases.count,
                    current: page
                )
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.md)
                
                SignInWithAppleButton(.signIn) { request in
                    // Name/email are only returned the first time the user authorizes this app.
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    auth.handleAuthorizationResult(result)
                    if auth.isSignedIn {
                        dismiss()
                    }
                }
                .frame(height: 50)
                .frame(maxWidth: buttonMaxWidth)
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .clipShape(Capsule(style: .continuous))
                .padding(.horizontal, 32)
                .padding(.bottom, 22)
            }
        }
        .interactiveDismissDisabled(true)
        .tint(.primary)
        .onChange(of: auth.isSignedIn) { _, newValue in
            if newValue {
                dismiss()
            }
        }
    }
}
