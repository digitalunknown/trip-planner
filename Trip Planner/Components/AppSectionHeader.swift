import SwiftUI

/// Shared section title for Forms and custom stacks.
/// 15pt semibold, title case (Form would otherwise uppercase it).
struct AppSectionHeader: View {
    let title: String
    var color: Color = AppColor.textWeak
    
    init(_ title: String, color: Color = AppColor.textWeak) {
        self.title = title
        self.color = color
    }
    
    var body: some View {
        Text(title)
            .font(.app(15, weight: .semibold))
            .foregroundStyle(color)
            .textCase(.none)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
