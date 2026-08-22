import Lucide
import SwiftUI
import UIKit

/// First-pass Lucide integration: map existing SF Symbol names → Lucide icons,
/// with SF Symbol fallback when no mapping exists (activity pickers, rare glyphs).
enum AppLucide {
    static let chromeSize: CGFloat = 18
    /// Toolbar / liquid-glass controls — slightly larger so outline glyphs stay readable.
    static let toolbarSize: CGFloat = 18
    /// Tab bar glyph size (template UIImage).
    static let tabSize: CGFloat = 24
    
    /// High-contrast label color that stays visible on liquid glass.
    static var labelColor: Color { Color(uiColor: .label) }
    
    /// Lucide kebab-case name for an SF Symbol **or** a stored Lucide id.
    static func lucideName(forSystemName systemName: String) -> String? {
        let key = systemName
            .replacingOccurrences(of: ".fill", with: "")
            .replacingOccurrences(of: ".circle", with: "")
        if let mapped = map[systemName] ?? map[key] {
            return mapped
        }
        // Activity picker may store Lucide ids directly (e.g. "baggage-claim").
        if LucideIcon(rawValue: systemName) != nil {
            return systemName
        }
        return nil
    }
    
    /// Rasterize a Lucide icon as a template `UIImage` for TabView / toolbars.
    /// Tab bars ignore arbitrary SwiftUI Shape views; they need template images.
    @MainActor
    static func templateImage(lucide name: String, pointSize: CGFloat) -> UIImage? {
        let key = "\(name)@\(Int((pointSize * 10).rounded()))"
        if let cached = templateCache[key] { return cached }
        guard let icon = Lucide(name) else { return nil }
        
        let content = Color.black
            .frame(width: pointSize, height: pointSize)
            .mask {
                icon
                    .frame(width: pointSize, height: pointSize)
            }
        
        let renderer = ImageRenderer(content: content)
        renderer.scale = UIScreen.main.scale
        renderer.isOpaque = false
        guard let image = renderer.uiImage else { return nil }
        let templated = image.withRenderingMode(.alwaysTemplate)
        templateCache[key] = templated
        return templated
    }
    
    @MainActor
    private static var templateCache: [String: UIImage] = [:]
    
    /// Swap system search-field glyphs (magnifier + clear) for Lucide templates.
    @MainActor
    static func applySearchBarChrome(pointSize: CGFloat = 16) {
        let searchBar = UISearchBar.appearance()
        if let search = templateImage(lucide: "search", pointSize: pointSize) {
            searchBar.setImage(search, for: .search, state: .normal)
            searchBar.setImage(search, for: .search, state: .highlighted)
            searchBar.setImage(search, for: .search, state: .disabled)
        }
        // Clear control inside the field (xmark.circle.fill).
        if let clear = templateImage(lucide: "circle-x", pointSize: pointSize) {
            searchBar.setImage(clear, for: .clear, state: .normal)
            searchBar.setImage(clear, for: .clear, state: .highlighted)
            searchBar.setImage(clear, for: .clear, state: .selected)
            searchBar.setImage(clear, for: .clear, state: .disabled)
        }
    }
    
    /// iOS 26 search presents a liquid-glass Close button (SF `xmark`) beside the field.
    /// Re-apply Lucide `x` after presentation — the system can rebuild the control.
    @MainActor
    static func patchSearchDismissButtons() {
        guard let xImage = templateImage(lucide: "x", pointSize: toolbarSize) else { return }
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        for window in windows {
            patchSearchDismissButtons(in: window, image: xImage)
        }
    }
    
    @MainActor
    private static func patchSearchDismissButtons(in view: UIView, image: UIImage) {
        if let button = view as? UIButton {
            let label = (button.accessibilityLabel ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let isClose = label == "close" || label == "dismiss"
            // Skip the clear control inside the text field; keep the glass Close beside search.
            let isInsideTextField = sequence(first: view.superview, next: { $0?.superview })
                .contains { $0 is UITextField }
            if isClose, !isInsideTextField {
                applyLucideCloseImage(image, to: button)
            }
        }
        for subview in view.subviews {
            patchSearchDismissButtons(in: subview, image: image)
        }
    }
    
    @MainActor
    private static func applyLucideCloseImage(_ image: UIImage, to button: UIButton) {
        button.setImage(image, for: .normal)
        button.setImage(image, for: .highlighted)
        button.setImage(image, for: .selected)
        button.setImage(image, for: .disabled)
        if var config = button.configuration {
            config.image = image
            config.preferredSymbolConfigurationForImage = nil
            button.configuration = config
        }
        // Liquid Glass can composite over UIButton images; keep a non-interactive Lucide overlay.
        let tag = 0x4C554358 // 'LUX'
        let overlay: UIImageView
        if let existing = button.viewWithTag(tag) as? UIImageView {
            overlay = existing
        } else {
            overlay = UIImageView()
            overlay.tag = tag
            overlay.isUserInteractionEnabled = false
            overlay.contentMode = .scaleAspectFit
            overlay.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(overlay)
            NSLayoutConstraint.activate([
                overlay.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                overlay.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                overlay.widthAnchor.constraint(equalToConstant: toolbarSize),
                overlay.heightAnchor.constraint(equalToConstant: toolbarSize)
            ])
        }
        overlay.image = image.withRenderingMode(.alwaysTemplate)
        overlay.tintColor = .label
        button.imageView?.alpha = 0.01
    }
    
    private static let map: [String: String] = [
        // Tabs / nav
        "briefcase": "backpack",
        "briefcase.fill": "backpack",
        "mappin": "map-pinned",
        "mappin.and.ellipse": "map-pinned",
        "mappin.slash": "map-pin-off",
        "safari": "compass",
        "safari.fill": "compass",
        "person": "user-round",
        "person.fill": "user-round",
        "magnifyingglass": "search",
        "gearshape": "settings",
        "gearshape.fill": "settings",
        
        // Chrome
        "plus": "plus",
        "plus.circle.fill": "circle-plus",
        "plus.circle": "circle-plus",
        "xmark": "x",
        "xmark.circle.fill": "circle-x",
        "checkmark": "check",
        "checkmark.circle.fill": "circle-check-big",
        "checkmark.circle": "circle-check-big",
        "circle": "circle",
        "checkmark.square.fill": "square-check-big",
        "trash": "trash-2",
        "pencil": "square-pen",
        "square.and.pencil": "square-pen",
        "doc.on.doc": "copy",
        "doc.fill": "file",
        "folder": "folder",
        "sparkles": "sparkles",
        "photo": "image",
        "photo.fill": "image",
        "photo.on.rectangle": "images",
        "photo.badge.plus": "image-plus",
        "camera": "camera",
        "camera.fill": "camera",
        "calendar": "calendar",
        "calendar.badge.plus": "calendar-plus",
        "clock": "clock",
        "clock.fill": "clock",
        "clock.arrow.circlepath": "history",
        "chevron.right": "chevron-right",
        "chevron.left": "chevron-left",
        "chevron.up": "chevron-up",
        "chevron.down": "chevron-down",
        "chevron.up.chevron.down": "chevrons-up-down",
        "arrow.left": "arrow-left",
        "arrow.right": "arrow-right",
        "arrow.right.circle": "circle-arrow-right",
        "arrow.up": "arrow-up",
        "arrow.up.right": "arrow-up-right",
        "arrow.uturn.left": "undo-2",
        "arrow.left.arrow.right": "arrow-left-right",
        "square.arrow.right": "square-arrow-right",
        "square.arrow.left": "square-arrow-left",
        "paintbrush": "paintbrush-vertical",
        "paintbrush.pointed": "paintbrush-vertical",
        "paintbrush.pointed.fill": "paintbrush-vertical",
        "lightbulb": "lightbulb",
        "lightbulb.fill": "lightbulb",
        "stop.fill": "square",
        "stop": "square",
        "text.badge.plus": "list-plus",
        "checklist": "list-checks",
        "checklist.checked": "list-checks",
        
        // Food & drink
        "fork.knife": "utensils",
        "carrot.fill": "carrot",
        "carrot": "carrot",
        "cup.and.saucer.fill": "coffee",
        "cup.and.saucer": "coffee",
        "mug.fill": "coffee",
        "mug": "coffee",
        "takeoutbag.and.cup.and.straw.fill": "shopping-bag",
        "wineglass.fill": "wine",
        "wineglass": "wine",
        "waterbottle": "glass-water",
        "birthday.cake.fill": "cake",
        "birthday.cake": "cake",
        
        // Travel / transport
        "suitcase": "backpack",
        "suitcase.fill": "backpack",
        "airplane": "plane",
        "airplane.departure": "plane-takeoff",
        "airplane.arrival": "plane-landing",
        "car.fill": "car",
        "car": "car",
        "cablecar.fill": "cable-car",
        "cablecar": "cable-car",
        "bus.fill": "bus",
        "bus": "bus",
        "bus.doubledecker.fill": "bus",
        "tram.fill": "train-front",
        "tram": "train-front",
        "train.side.front.car": "train-front",
        "ferry.fill": "ship",
        "ferry": "ship",
        "scooter": "scooter",
        "motorcycle.fill": "motorbike",
        "motorcycle": "motorbike",
        "truck.box.fill": "truck",
        "truck.box": "truck",
        "fuelpump.fill": "fuel",
        "fuelpump": "fuel",
        "bicycle": "bike",
        "figure.walk": "footprints",
        
        // Shopping
        "cart.fill": "shopping-cart",
        "cart": "shopping-cart",
        "bag.fill": "shopping-bag",
        "bag": "shopping-bag",
        "duffle.bag.fill": "luggage",
        "duffle.bag": "luggage",
        "creditcard.fill": "credit-card",
        "creditcard": "credit-card",
        "gift.fill": "gift",
        "gift": "gift",
        "tag.fill": "tag",
        "tag": "tag",
        
        // Places / nature
        "globe": "globe",
        "globe.americas.fill": "globe",
        "globe.europe.africa.fill": "earth",
        "map": "map",
        "map.fill": "map",
        "location.fill": "locate",
        "pin.fill": "pin",
        "bed.double.fill": "bed-double",
        "bed.double": "bed-double",
        "house.fill": "house",
        "house": "house",
        "building.fill": "building-2",
        "building.2.fill": "building-2",
        "building.2": "building-2",
        "building.columns.fill": "landmark",
        "building.columns": "landmark",
        "tent.fill": "tent",
        "tent": "tent",
        "mountain.2.fill": "mountain",
        "mountain.2": "mountain",
        "water.waves": "waves-horizontal",
        "leaf.fill": "leaf",
        "leaf": "leaf",
        "sun.max.fill": "sun",
        "sun.max": "sun",
        "sunrise": "sunrise",
        "sunrise.fill": "sunrise",
        "sunset": "sunset",
        "sunset.fill": "sunset",
        "beach.umbrella.fill": "umbrella",
        "beach.umbrella": "umbrella",
        "cloud.sun.rain.fill": "cloud-sun-rain",
        "cloud.sun.rain": "cloud-sun-rain",
        "cloud.rain.fill": "cloud-rain",
        "cloud.rain": "cloud-rain",
        "cloud.snow.fill": "cloud-snow",
        "cloud.snow": "cloud-snow",
        "cloud.bolt.rain.fill": "cloud-lightning",
        "cloud.bolt.rain": "cloud-lightning",
        "wind": "wind",
        
        // Entertainment / lifestyle
        "ticket.fill": "ticket",
        "ticket": "ticket",
        "theatermasks.fill": "drama",
        "theatermasks": "drama",
        "movieclapper": "clapperboard",
        "gamecontroller.fill": "gamepad-2",
        "gamecontroller": "gamepad-2",
        "figure.hiking": "person-standing",
        "dumbbell.fill": "dumbbell",
        "dumbbell": "dumbbell",
        "trophy.fill": "trophy",
        "trophy": "trophy",
        "heart.fill": "heart",
        "heart": "heart",
        "figure.run": "person-standing",
        "figure.yoga": "person-standing",
        "airpods.max": "headphones",
        "stroller.fill": "baby",
        "stroller": "baby",
        "drone.fill": "drone",
        "drone": "drone",
        "sunglasses.fill": "glasses",
        "sunglasses": "glasses",
        "shoe.fill": "sport-shoe",
        "shoe": "sport-shoe",
        "tshirt.fill": "shirt",
        "tshirt": "shirt",
        "jacket.fill": "shirt",
        "jacket": "shirt",
        
        // Misc
        "star.fill": "star",
        "eye.slash": "eye-off",
        "questionmark.circle.fill": "circle-question-mark",
        "exclamationmark.triangle.fill": "triangle-alert",
        "square.and.arrow.up": "share",
    ]
}

/// Renders a Lucide icon (by SF Symbol alias or Lucide name), with SF Symbol fallback.
/// Uses template `UIImage`s so TabView / liquid glass can tint glyphs correctly.
struct AppIcon: View {
    private enum Source {
        case systemName(String)
        case lucideName(String)
    }
    
    private let source: Source
    var size: CGFloat = AppLucide.chromeSize
    /// Kept for call-site compatibility; Lucide outlines bake stroke weight in.
    var strokeWidth: CGFloat = 2
    var color: Color? = nil
    /// Kept for call-site compatibility; Lucide icons are outline fills.
    var filled: Bool = false
    /// Extra trailing space so Form `Label` rows can loosen icon→title spacing without changing Icon type.
    var trailingPadding: CGFloat = 0
    
    init(
        systemName: String,
        size: CGFloat = AppLucide.chromeSize,
        strokeWidth: CGFloat = 2,
        color: Color? = nil,
        filled: Bool = false,
        trailingPadding: CGFloat = 0
    ) {
        self.source = .systemName(systemName)
        self.size = size
        self.strokeWidth = strokeWidth
        self.color = color
        self.filled = filled
        self.trailingPadding = trailingPadding
    }
    
    init(
        lucide name: String,
        size: CGFloat = AppLucide.chromeSize,
        strokeWidth: CGFloat = 2,
        color: Color? = nil,
        filled: Bool = false,
        trailingPadding: CGFloat = 0
    ) {
        self.source = .lucideName(name)
        self.size = size
        self.strokeWidth = strokeWidth
        self.color = color
        self.filled = filled
        self.trailingPadding = trailingPadding
    }
    
    private var resolvedLucideName: String? {
        switch source {
        case .lucideName(let name):
            return name
        case .systemName(let systemName):
            return AppLucide.lucideName(forSystemName: systemName)
        }
    }
    
    private var fallbackSystemName: String? {
        if case .systemName(let name) = source { return name }
        return nil
    }
    
    var body: some View {
        Group {
            if let lucide = resolvedLucideName,
               let uiImage = AppLucide.templateImage(lucide: lucide, pointSize: size) {
                templateImage(uiImage)
            } else if let fallbackSystemName {
                Image(systemName: fallbackSystemName)
                    .font(.system(size: size * 0.85, weight: .semibold))
                    .frame(width: size, height: size)
                    .modifier(AppIconForeground(color: color))
            } else {
                Color.clear.frame(width: size, height: size)
            }
        }
        .padding(.trailing, trailingPadding)
    }
    
    @ViewBuilder
    private func templateImage(_ uiImage: UIImage) -> some View {
        Image(uiImage: uiImage)
            .resizable()
            .renderingMode(.template)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .modifier(AppIconForeground(color: color))
    }
}

/// Applies an explicit tint, or leaves the glyph free to inherit parent `foregroundStyle`
/// (needed for accent capsules / buttons).
private struct AppIconForeground: ViewModifier {
    let color: Color?
    
    func body(content: Content) -> some View {
        if let color {
            content.foregroundStyle(color)
        } else {
            content
        }
    }
}

/// Tab-bar label that uses a template Lucide UIImage (required for TabView visibility).
struct LucideTabLabel: View {
    let title: String
    let lucideName: String
    
    var body: some View {
        if let uiImage = AppLucide.templateImage(lucide: lucideName, pointSize: AppLucide.tabSize) {
            Label {
                Text(title)
            } icon: {
                Image(uiImage: uiImage)
            }
        } else {
            Label(title, systemImage: "circle")
        }
    }
}

extension Label where Title == Text, Icon == AppIcon {
    /// Label that prefers Lucide for known SF Symbol names.
    /// Pass `color: .primary` in Forms so List/Link accent tint can’t turn the glyph blue.
    /// Use `iconTitleSpacing` when a Form row needs a bit more room between icon and title.
    init(
        _ title: String,
        appIcon systemName: String,
        size: CGFloat = AppLucide.chromeSize,
        color: Color? = nil,
        iconTitleSpacing: CGFloat = 0
    ) {
        self.init {
            Text(title)
        } icon: {
            AppIcon(
                systemName: systemName,
                size: size,
                color: color,
                trailingPadding: iconTitleSpacing
            )
        }
    }
}
