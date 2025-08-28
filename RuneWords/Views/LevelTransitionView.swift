import SwiftUI

struct LevelTransitionView: View {
    let fromLevel: Int
    let toLevel: Int
    let phase: Int
    
    var body: some View {
        ZStack {
            // Phase 1: Level complete celebration
            if phase == 1 {
                VStack(spacing: 20) {
                    Text("Level \(fromLevel)")
                        .font(.custom("Cinzel-Regular", size: 24))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("COMPLETE!")
                        .font(.custom("Cinzel-Bold", size: 42))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            // Phase 2: Swoosh transition
            if phase == 2 {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.8), .blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .transition(.move(edge: .trailing))
            }
            
            // Phase 3: Realm info
            if phase == 3 {
                VStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 50))
                        .foregroundColor(.yellow)
                    
                    Text("Entering")
                        .font(.custom("Cinzel-Regular", size: 20))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(realmName(for: toLevel))
                        .font(.custom("Cinzel-Bold", size: 32))
                        .foregroundColor(.white)
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            // Phase 4: Level number
            if phase == 4 {
                VStack(spacing: 12) {
                    Text("Level")
                        .font(.custom("Cinzel-Regular", size: 24))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("\(toLevel)")
                        .font(.custom("Cinzel-Bold", size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .yellow],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.8))
    }
    
    private func realmName(for level: Int) -> String {
        switch level {
        case 1...25: return "Tree Library"
        case 26...50: return "Crystal Forest"
        case 51...75: return "Sleeping Titan"
        case 76...100: return "Astral Peak"
        default: return "Unknown Realm"
        }
    }
}
