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
            VStack(alignment: .leading, spacing: 12) {
                if !address.isEmpty {
                    labeledRow("Address") {
                        Text(address)
                            .font(.app(15, weight: .medium))
                            .foregroundStyle(AppColor.textStrong)
                            .multilineTextAlignment(.leading)
                            .textSelection(.enabled)
                    }
                    contactDivider
                }
                
                if !phone.isEmpty {
                    labeledRow("Phone") {
                        Button {
                            if let url = Self.telephoneURL(from: phone) {
                                openURL(url)
                            }
                        } label: {
                            Text(phone)
                                .font(.app(15, weight: .medium))
                                .foregroundStyle(appAccentColor)
                                .multilineTextAlignment(.leading)
                        }
                        .buttonStyle(.plain)
                        .disabled(Self.telephoneURL(from: phone) == nil)
                    }
                    contactDivider
                }
                
                if let websiteURL {
                    labeledRow("Website") {
                        Button {
                            openURL(websiteURL)
                        } label: {
                            Text(Self.websiteDisplayText(for: websiteURL))
                                .font(.app(15, weight: .medium))
                                .foregroundStyle(appAccentColor)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                        }
                        .buttonStyle(.plain)
                    }
                    contactDivider
                }
                
                Button {
                    selectedMapItem = mapItem
                } label: {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(hasContactRows ? "View More Details" : (mapItem.name ?? fallbackTitle))
                                .font(.app(15, weight: .medium))
                                .foregroundStyle(AppColor.textStrong)
                            Text("Photos, hours, ratings & more")
                                .font(.app(13, weight: .medium))
                                .foregroundStyle(AppColor.textWeak)
                        }
                        Spacer(minLength: 8)
                        AppIcon(lucide: "chevron-right", size: 24, color: AppColor.textWeak)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .appDetailFieldBackground()
    }
    
    private var contactDivider: some View {
        Rectangle()
            .fill(AppColor.textStrong.opacity(0.10))
            .frame(height: 1)
    }
    
    private func labeledRow<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.app(13, weight: .medium))
                .foregroundStyle(AppColor.textWeak)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
