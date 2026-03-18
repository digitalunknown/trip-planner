import SwiftUI
import AuthenticationServices

struct SignInGateView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AppleSignInManager
    @Environment(\.appAccentColor) private var appAccentColor
    
    @AppStorage("exploreSampleEnabled") private var exploreSampleEnabled: Bool = false
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                
                SignInHeroAnimation()
                    .padding(.horizontal, 20)

                Spacer(minLength: 40)
                
                VStack(spacing: 10) {
                    Text("Start organizing your travel today")
                        .font(.app(34, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 36)
                
                Spacer(minLength: 0)
                
                VStack(spacing: 12) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName]
                    } onCompletion: { result in
                        auth.handleAuthorizationResult(result)
                        if auth.isSignedIn {
                            exploreSampleEnabled = false
                            dismiss()
                        }
                    }
                    .frame(height: 50)
                    .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 400 : .infinity)
                    .signInWithAppleButtonStyle(.black)
                    
                    Button {
                        exploreSampleEnabled = true
                        dismiss()
                    } label: {
                        Text("Explore Sample Trip")
                            .font(.appHeadline)
                            .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 400 : .infinity)
                            .frame(height: 52)
                            .foregroundStyle(appAccentColor)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 22)
            }
        }
        .interactiveDismissDisabled(true)
        .tint(.primary)
        .onChange(of: auth.isSignedIn) { _, newValue in
            if newValue {
                exploreSampleEnabled = false
                dismiss()
            }
        }
    }
}

