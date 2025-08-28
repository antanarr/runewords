import SwiftUI

struct IncorrectGuessEffectView: View {
    let position: CGPoint
    let word: String
    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Red particle burst
            ForEach(0..<8, id: \.self) { index in
                Circle()
                    .fill(Color.red.opacity(0.8))
                    .frame(width: 6, height: 6)
                    .offset(
                        x: CGFloat(cos(Double(index) * .pi / 4)) * 40,
                        y: CGFloat(sin(Double(index) * .pi / 4)) * 40
                    )
                    .scaleEffect(scale)
                    .opacity(opacity)
            }
            
            // X mark indicator
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.red)
                .background(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 36, height: 36)
                )
                .scaleEffect(scale)
                .opacity(opacity)
                .offset(y: offset)
        }
        .position(position)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                scale = 1.5
            }
            
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                opacity = 0
                offset = -30
            }
        }
    }
}
