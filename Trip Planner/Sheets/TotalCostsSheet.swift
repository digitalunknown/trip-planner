import SwiftUI
import UIKit

struct TotalCostsSheet: View {
    struct LineItem: Identifiable, Hashable {
        let id: String
        let title: String
        let subtitle: String?
        let amount: Double
        let currencyCode: String
    }
    
    @Environment(\.dismiss) private var dismiss
    let items: [LineItem]
    
    private var totalsByCurrency: [(currencyCode: String, total: Double)] {
        let grouped = Dictionary(grouping: items, by: \.currencyCode)
            .mapValues { $0.map(\.amount).reduce(0, +) }
        return grouped
            .map { ($0.key, $0.value) }
            .sorted { $0.currencyCode < $1.currencyCode }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                            if let subtitle = item.subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(subtitle)
                                    .font(.appCaption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        
                        Spacer(minLength: 0)
                        
                        Text("\(CurrencyFormatting.string(for: item.amount, currencyCode: item.currencyCode)) \(item.currencyCode)")
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    }
                    .padding(.vertical, 2)
                }
                
                Section {
                    ForEach(totalsByCurrency, id: \.currencyCode) { entry in
                        HStack {
                            Text(totalsByCurrency.count == 1 ? "Total" : "Total (\(entry.currencyCode))")
                            Spacer()
                            Text("\(CurrencyFormatting.string(for: entry.total, currencyCode: entry.currencyCode)) \(entry.currencyCode)")
                                .monospacedDigit()
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = "\(CurrencyFormatting.string(for: entry.total, currencyCode: entry.currencyCode)) \(entry.currencyCode)"
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Total Cost")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { dismiss() }
                }
            }
        }
        .tint(.primary)
    }
}

