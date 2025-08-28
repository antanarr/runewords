import SwiftUI

struct ErrorMessageOverlay: View {
    let message: String
    @State private var slideIn = false
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
                
                Text(message)
                    .font(.custom("Cinzel-Regular", size: 16))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.red.opacity(0.9))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: .red.opacity(0.5), radius: 10)
            .offset(y: slideIn ? 0 : 100)
            .padding(.bottom, 100)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                slideIn = true
            }
        }
    }
}