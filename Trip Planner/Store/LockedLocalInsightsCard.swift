import SwiftUI

/// Locked Local insights teaser. Shows one truncated line of tip copy.
struct LockedLocalInsightsCard: View {
    var previewText: String
    var expertColor: Color = AppColor.expert
    var cardFill: Color = AppColor.card
    var cornerRadius: CGFloat = 20
    
    @State private var showPaywall = false
    
    var body: some View {
        Button {
            showPaywall = true
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: 10) {
                    AppIcon(lucide: "user-star", size: AppLucide.fieldSize, color: expertColor)
                    Text("Local insights")
                        .font(.app(15, weight: .medium))
                        .foregroundStyle(expertColor)
                    Spacer(minLength: 0)
                    AppIcon(lucide: "lock", size: 18, color: AppColor.textWeak)
                }
                
                Text(previewText)
                    .font(.app(15, weight: .medium))
                    .foregroundStyle(AppColor.textStrong)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                UnlockWithTripStacksPlusLabel()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.cardPadding)
            .background(cardFill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .expertTipOutlineShine(cornerRadius: cornerRadius)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPaywall) {
            PaywallSheet()
        }
        .accessibilityHint("Opens TripStacks+ to unlock local insights")
    }
}

struct UnlockWithTripStacksPlusLabel: View {
    var size: CGFloat = 13
    
    var body: some View {
        HStack(spacing: 4) {
            Text("Unlock with")
                .font(.app(size, weight: .medium))
                .foregroundStyle(AppColor.textStrong)
            Text("TripStacks+")
                .font(.app(size, weight: .bold))
                .foregroundStyle(AppColor.plusGradient)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Unlock with TripStacks+")
    }
}
