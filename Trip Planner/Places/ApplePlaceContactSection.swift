import SwiftUI
import MapKit

/// Inline Address / Phone / Website rows plus “View more details” (Apple Place Card).
struct ApplePlaceContactSection: View {
    let mapItem: MKMapItem
    var fallbackTitle: String = "Place"
    @Binding var selectedMapItem: MKMapItem?
    
    @Environment(\.openURL) private var openURL
    @Environment(\.appAccentColor) private var appAccentColor
    
    private var address: String {
        mapItemAddressString(mapItem)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    private var phone: String {
        mapItem.phoneNumber?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    private var websiteURL: URL? { mapItem.url }
    
    private var hasContactRows: Bool {
        !address.isEmpty || !phone.isEmpty || websiteURL != nil
    }
    
    var body: some View {
        Section {
            if !address.isEmpty {
                labeledRow("Address") {
                    Text(address)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .textSelection(.enabled)
                }
            }
            
            if !phone.isEmpty {
                labeledRow("Phone") {
                    Button {
                        if let url = Self.telephoneURL(from: phone) {
                            openURL(url)
                        }
                    } label: {
                        Text(phone)
                            .foregroundStyle(appAccentColor)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                    .disabled(Self.telephoneURL(from: phone) == nil)
                }
            }
            
            if let websiteURL {
                labeledRow("Website") {
                    Button {
                        openURL(websiteURL)
                    } label: {
                        Text(Self.websiteDisplayText(for: websiteURL))
                            .foregroundStyle(appAccentColor)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Button {
                selectedMapItem = mapItem
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(hasContactRows ? "View more details" : (mapItem.name ?? fallbackTitle))
                            .foregroundStyle(.primary)
                        Text("Photos, hours, ratings & more")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.app(13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    private func labeledRow<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.appCaption)
                .foregroundStyle(.secondary)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }
    
    static func telephoneURL(from phone: String) -> URL? {
        let dialable = phone.filter { $0.isNumber || $0 == "+" }
        guard !dialable.isEmpty else { return nil }
        return URL(string: "tel:\(dialable)")
    }
    
    static func websiteDisplayText(for url: URL) -> String {
        guard var host = url.host(), !host.isEmpty else {
            return url.absoluteString
        }
        if host.lowercased().hasPrefix("www.") {
            host = String(host.dropFirst(4))
        }
        return host
    }
}

/// Looks up an `MKMapItem` from a location query / coordinates for place contact UI.
/// Implementation lives in `ApplePlaceLookup.swift` (shared with AI covers + Maps preview).


private struct ApplePlaceCardSheetModifier: ViewModifier {
    @Binding var item: MKMapItem?
    
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.mapItemDetailSheet(item: $item, displaysMap: true)
        } else {
            content.sheet(isPresented: Binding(
                get: { item != nil },
                set: { if !$0 { item = nil } }
            )) {
                if let item {
                    InAppMapItemPreview(mapItem: item) {
                        self.item = nil
                    }
                }
            }
        }
    }
}

/// Pre–iOS 18 fallback so map previews stay in-app.
private struct InAppMapItemPreview: View {
    let mapItem: MKMapItem
    let onDismiss: () -> Void
    
    private var coordinate: CLLocationCoordinate2D? {
        let coordinate = mapItem.placemark.coordinate
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        return coordinate
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if let coordinate {
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: coordinate,
                        latitudinalMeters: 1_200,
                        longitudinalMeters: 1_200
                    ))) {
                        Marker(mapItem.name ?? "Place", coordinate: coordinate)
                    }
                    .mapStyle(.standard)
                } else {
                    ContentUnavailableView(
                        mapItem.name ?? "Place",
                        systemImage: "map",
                        description: Text("Map preview isn’t available for this place.")
                    )
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(mapItem.name ?? "Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDismiss)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

extension View {
    func applePlaceCardSheet(item: Binding<MKMapItem?>) -> some View {
        modifier(ApplePlaceCardSheetModifier(item: item))
    }
}
