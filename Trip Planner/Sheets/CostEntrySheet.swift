import SwiftUI

enum CurrencyFormatting {
    static func string(for amount: Double?, currencyCode: String? = nil) -> String {
        let code = currencyCode ?? UserDefaults.standard.string(forKey: "currencyCode") ?? "USD"
        guard let amount else { return string(forCents: 0, currencyCode: code) }
        return formatter(for: code).string(from: NSNumber(value: amount)) ?? string(forCents: 0, currencyCode: code)
    }
    
    fileprivate static func string(forCents cents: Int, currencyCode: String? = nil) -> String {
        let code = currencyCode ?? UserDefaults.standard.string(forKey: "currencyCode") ?? "USD"
        let amount = Double(max(0, cents)) / 100.0
        return formatter(for: code).string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    private static var cache: [String: NumberFormatter] = [:]
    private static let lock = NSLock()
    
    private static func formatter(for currencyCode: String) -> NumberFormatter {
        lock.lock()
        defer { lock.unlock() }
        
        if let existing = cache[currencyCode] { return existing }
        
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = .current
        f.currencyCode = currencyCode
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        cache[currencyCode] = f
        return f
    }
}

struct CostEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @Binding var cost: Double?
    @Binding var currencyCode: String
    
    @State private var digits: String = ""
    @FocusState private var isFocused: Bool
    @State private var caretOn: Bool = true
    
    private struct CurrencyOption: Identifiable, Hashable {
        let code: String
        let name: String
        var id: String { code }
        var label: String { "\(name) (\(code))" }
    }
    
    private let popularCurrencies: [CurrencyOption] = [
        CurrencyOption(code: "USD", name: "US Dollar"),
        CurrencyOption(code: "EUR", name: "Euro"),
        CurrencyOption(code: "GBP", name: "British Pound"),
        CurrencyOption(code: "JPY", name: "Japanese Yen"),
        CurrencyOption(code: "CAD", name: "Canadian Dollar"),
        CurrencyOption(code: "AUD", name: "Australian Dollar"),
        CurrencyOption(code: "CHF", name: "Swiss Franc"),
        CurrencyOption(code: "CNY", name: "Chinese Yuan"),
        CurrencyOption(code: "INR", name: "Indian Rupee"),
        CurrencyOption(code: "SGD", name: "Singapore Dollar")
    ]
    
    private var centsValue: Int {
        Int(digits) ?? 0
    }
    
    private var displayText: String {
        CurrencyFormatting.string(forCents: centsValue, currencyCode: currencyCode)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer(minLength: 0)
                
                HStack(spacing: 0) {
                    Text(displayText)
                        .font(.app(56, weight: .semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .contentShape(Rectangle())
                    
                    if isFocused {
                        Rectangle()
                            .fill(appAccentColor)
                            .frame(width: 3, height: 44)
                            .opacity(caretOn ? 1 : 0)
                            .padding(.leading, 6)
                            .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 24)
                .contentShape(Rectangle())
                .onTapGesture { isFocused = true }
                
                TextField("", text: $digits)
                    .keyboardType(.numberPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .opacity(0.01)
                    .frame(width: 1, height: 1)
                    .tint(appAccentColor)
                    .onChange(of: digits) { _, newValue in
                        let cleaned = newValue.filter(\.isNumber)
                        digits = String(cleaned.prefix(9))
                    }
                
                Spacer(minLength: 0)
            }
            .navigationTitle("Cost")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    LiquidGlassIconButton(systemName: "checkmark") {
                        commit()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    currencyCode = UserDefaults.standard.string(forKey: "currencyCode") ?? "USD"
                }
                if let cost {
                    let cents = Int((cost * 100).rounded())
                    digits = String(max(0, cents))
                } else {
                    digits = ""
                }
                
                DispatchQueue.main.async {
                    isFocused = true
                }
                
                caretOn = true
            }
            .onChange(of: isFocused) { _, newValue in
                guard newValue else {
                    caretOn = false
                    return
                }
                caretOn = true
                withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                    caretOn.toggle()
                }
            }
        }
        .tint(.primary)
        .safeAreaInset(edge: .bottom) {
            if isFocused {
                HStack {
                    Spacer()
                    
                    Menu {
                        ForEach(popularCurrencies) { option in
                            Button {
                                currencyCode = option.code
                            } label: {
                                if option.code == currencyCode {
                                    Label(option.label, systemImage: "checkmark")
                                } else {
                                    Text(option.label)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Currency")
                                .font(.appCaption)
                                .foregroundStyle(.secondary)
                            
                            Text(currencyCode)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                            
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.app(11, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.thinMaterial, in: Capsule())
                        .contentShape(Capsule())
                    }
                    .buttonStyle(currencyButtonStyle)
                    
                    Spacer()
                }
                .padding(.bottom, 10)
                .padding(.top, 6)
            }
        }
    }
    
    private func commit() {
        let cleaned = digits.filter(\.isNumber)
        guard !cleaned.isEmpty, let cents = Int(cleaned) else {
            cost = nil
            return
        }
        cost = Double(max(0, cents)) / 100.0
    }
    
    private var currencyButtonStyle: some PrimitiveButtonStyle {
        if #available(iOS 26.0, *) {
            return AnyPrimitiveButtonStyle(.glass)
        } else {
            return AnyPrimitiveButtonStyle(.plain)
        }
    }
}

// Type-erased button style wrapper
private struct AnyPrimitiveButtonStyle: PrimitiveButtonStyle {
    private let _makeBody: (Configuration) -> AnyView
    
    init<S: PrimitiveButtonStyle>(_ style: S) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }
    
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

