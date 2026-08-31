import SwiftUI

/// Read-only Form section for curated Expert Tips (distinct from user Notes).
struct ExpertTipsSection: View {
    let tips: [ExpertTip]
    
    var body: some View {
        if !tips.isEmpty {
            Section {
                ForEach(tips) { tip in
                    ExpertTipCard(tip: tip)
                }
            } header: {
                Text("Expert Tips")
            }
        }
    }
}

struct ExpertTipCard: View {
    let tip: ExpertTip
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tip.tip)
                .font(.appBody)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            let author = tip.author.trimmingCharacters(in: .whitespacesAndNewlines)
            if !author.isEmpty {
                Text("— \(author)")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Expert Tip")
                .font(.app(13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(tip.tip)
                .font(.app(14, weight: .regular))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            let author = tip.author.trimmingCharacters(in: .whitespacesAndNewlines)
            if !author.isEmpty {
                Text("— \(author)")
                    .font(.app(12, weight: .regular))
                    .foregroundStyle(.secondary)
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
