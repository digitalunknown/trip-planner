import SwiftUI

/// Read-only Form section for curated Expert Tips (distinct from user Notes).
struct ExpertTipsSection: View {
    let tips: [ExpertTip]
    
    @Environment(PremiumStore.self) private var premium
    private let expertColor = AppColor.expert
    
    var body: some View {
        if !tips.isEmpty {
            Section {
                Group {
                    if premium.isPremium {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                AppIcon(lucide: "user-star", size: AppLucide.fieldSize, color: expertColor)
                                Text("Local insights")
                                    .font(.app(15, weight: .medium))
                                    .foregroundStyle(expertColor)
                            }
                            
                            ForEach(tips) { tip in
                                Text(tip.tip)
                                    .font(.app(15, weight: .medium))
                                    .foregroundStyle(AppColor.textStrong)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityLabel(accessibilityLabel(for: tip))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                        .background(AppDetailSurface.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .expertTipOutlineShine(cornerRadius: 20)
                    } else {
                        LockedLocalInsightsCard(previewText: tips[0].tip)
                    }
                }
                .padding(ExpertTipShine.lineWidth)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
    }
    
    private func accessibilityLabel(for tip: ExpertTip) -> String {
        let author = tip.author.trimmingCharacters(in: .whitespacesAndNewlines)
        if author.isEmpty { return tip.tip }
        return "\(tip.tip). By \(author)"
    }
}

struct ExpertTipCard: View {
    let tip: ExpertTip
    
    private let expertColor = AppColor.expert
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AppIcon(lucide: "user-star", size: AppLucide.fieldSize, color: expertColor)
                Text("Local insights")
                    .font(.app(15, weight: .medium))
                    .foregroundStyle(expertColor)
            }
            
            Text(tip.tip)
                .font(.app(15, weight: .medium))
                .foregroundStyle(AppColor.textStrong)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.cardPadding)
        .background(AppDetailSurface.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .expertTipOutlineShine(cornerRadius: 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
    
    private var accessibilityLabel: String {
        let author = tip.author.trimmingCharacters(in: .whitespacesAndNewlines)
        if author.isEmpty { return tip.tip }
        return "\(tip.tip). By \(author)"
    }
}

/// Compact tip callout for AI result cards (non-Form layout).
struct ExpertTipInlineCallout: View {
    let tip: ExpertTip
    
    @Environment(PremiumStore.self) private var premium
    @State private var showPaywall = false
    
    var body: some View {
        Group {
            if premium.isPremium {
                unlocked
            } else {
                Button {
                    showPaywall = true
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Local insights")
                                .font(.app(13, weight: .semibold))
                                .foregroundStyle(AppColor.expert)
                            Spacer(minLength: 0)
                            AppIcon(lucide: "lock", size: 14, color: AppColor.textWeak)
                        }
                        Text(tip.tip)
                            .font(.app(15, weight: .medium))
                            .foregroundStyle(AppColor.textStrong)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        UnlockWithTripStacksPlusLabel()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallSheet()
        }
    }
    
    private var unlocked: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Local insights")
                .font(.app(13, weight: .semibold))
                .foregroundStyle(AppColor.textWeak)
            Text(tip.tip)
                .font(.appBody)
                .foregroundStyle(AppColor.textStrong)
                .fixedSize(horizontal: false, vertical: true)
            let author = tip.author.trimmingCharacters(in: .whitespacesAndNewlines)
            if !author.isEmpty {
                Text("— \(author)")
                    .font(.appCaption)
                    .foregroundStyle(AppColor.textWeak)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        }
        .accessibilityElement(children: .combine)
    }
}

/// Lavender rim light: brightest at the top-leading corner, fading along the top and leading edges.
enum ExpertTipShine {
    static let lineWidth: CGFloat = 1
    
    static var gradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: AppColor.expert, location: 0),
                .init(color: AppColor.expert.opacity(0.55), location: 0.18),
                .init(color: AppColor.expert.opacity(0.14), location: 0.36),
                .init(color: AppColor.expert.opacity(0), location: 0.55)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension View {
    func expertTipOutlineShine(cornerRadius: CGFloat) -> some View {
        let line = ExpertTipShine.lineWidth
        return overlay {
            RoundedRectangle(cornerRadius: max(cornerRadius - line, 0), style: .continuous)
                .strokeBorder(ExpertTipShine.gradient, lineWidth: line)
                .padding(line)
                .allowsHitTesting(false)
        }
    }
}

/// Loads tips for a query and renders a Form section when matches exist.
struct ExpertTipsMatchingSection: View {
    @Environment(ExpertTipsStore.self) private var expertTips
    let query: ExpertTipQuery
    
    var body: some View {
        ExpertTipsSection(tips: expertTips.tips(matching: query))
            .task {
                await expertTips.refresh()
            }
    }
}
