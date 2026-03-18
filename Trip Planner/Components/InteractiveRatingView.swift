import SwiftUI

struct InteractiveRatingView: View {
    @Binding var rating: Int
    @State private var dragRating: Int = 0
    @State private var isDragging: Bool = false
    @State private var impactOccurred = UIImpactFeedbackGenerator(style: .medium)
    
    private let ratingLabels = [
        "",
        "Meh",
        "Good",
        "Great",
        "Awesome",
        "Amazing"
    ]
    
    private var displayRating: Int {
        isDragging ? dragRating : rating
    }
    
    private var ratingLabel: String {
        guard displayRating > 0 && displayRating <= 5 else { return "" }
        return ratingLabels[displayRating]
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Stars
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { index in
                    StarView(
                        index: index,
                        currentRating: displayRating,
                        isDragging: isDragging
                    )
                    .onTapGesture {
                        if rating == index {
                            // Tapping the same star clears the rating
                            rating = 0
                        } else {
                            rating = index
                        }
                        triggerHaptic()
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            impactOccurred.prepare()
                        }
                        
                        let starWidth: CGFloat = 44
                        let spacing: CGFloat = 6
                        let totalWidth = (starWidth * 5) + (spacing * 4)
                        let startX = (UIScreen.main.bounds.width - totalWidth) / 2
                        let x = value.location.x
                        
                        let adjustedX = x - startX + (starWidth / 2)
                        let newRating = max(0, min(5, Int((adjustedX / (starWidth + spacing)).rounded())))
                        
                        if newRating != dragRating && newRating > 0 {
                            dragRating = newRating
                            triggerHaptic()
                        }
                    }
                    .onEnded { _ in
                        if dragRating > 0 {
                            rating = dragRating
                        }
                        isDragging = false
                    }
            )
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .onAppear {
            dragRating = rating
            impactOccurred.prepare()
        }
        .onChange(of: rating) { _, newValue in
            dragRating = newValue
        }
    }
    
    private func triggerHaptic() {
        impactOccurred.impactOccurred(intensity: 0.7)
        impactOccurred.prepare()
    }
}

struct StarView: View {
    let index: Int
    let currentRating: Int
    let isDragging: Bool
    
    private var isFilled: Bool {
        index <= currentRating
    }
    
    private var scale: CGFloat {
        if isDragging && index == currentRating {
            return 1.2
        } else if isFilled {
            return 1.0
        } else {
            return 0.9
        }
    }
    
    var body: some View {
        ZStack {
            // Glow effect for filled stars
            if isFilled {
                Image(systemName: "star.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.yellow)
                    .blur(radius: 6)
                    .opacity(0.6)
            }
            
            // Star
            Image(systemName: isFilled ? "star.fill" : "star")
                .font(.system(size: 36))
                .foregroundStyle(isFilled ? .yellow : Color.secondary.opacity(0.3))
                .symbolEffect(.bounce, value: isFilled && isDragging && index == currentRating)
        }
        .scaleEffect(scale)
        .animation(.bouncy(duration: 0.35), value: scale)
        .animation(.bouncy(duration: 0.35), value: isFilled)
    }
}

#Preview {
    VStack {
        InteractiveRatingView(rating: .constant(3))
    }
    .padding()
}
