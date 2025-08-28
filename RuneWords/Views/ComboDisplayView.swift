import SwiftUI

struct ComboDisplayView: View {
    let comboCount: Int
    let multiplier: Int
    @State private var scale: CGFloat = 0.5
    @State private var rotation: Double = 0
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 8) {
                Text("COMBO x\(multiplier)")
                    .font(.custom("Cinzel-Bold", size: 32))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                Text("\(comboCount) words in a row!")
                    .font(.custom("Cinzel-Regular", size: 16))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                    )
            )
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .shadow(color: .orange.opacity(0.5), radius: 20)
            
            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.0
            }
            
            withAnimation(.easeInOut(duration: 0.15)) {
                rotation = -5
            }
            
            withAnimation(.easeInOut(duration: 0.15).delay(0.15)) {
                rotation = 5
            }
            
            withAnimation(.easeInOut(duration: 0.15).delay(0.3)) {
                rotation = 0
            }
        }
    }
}