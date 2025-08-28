// HintExplanationView.swift - Tutorial overlay explaining hint mechanics
import SwiftUI

struct HintExplanationView: View {
    @Binding var isPresented: Bool
    @State private var selectedHint: HintType? = nil
    @State private var animateIcons = false
    
    enum HintType: CaseIterable {
        case clarity, precision, momentum, revelation
        
        var title: String {
            switch self {
            case .clarity: return "Clarity"
            case .precision: return "Precision"
            case .momentum: return "Momentum"
            case .revelation: return "Revelation"
            }
        }
        
        var icon: String {
            switch self {
            case .clarity: return "lightbulb.max.fill"
            case .precision: return "target"
            case .momentum: return "bolt.circle.fill"
            case .revelation: return "eye.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .clarity: return .yellow
            case .precision: return .blue
            case .momentum: return .purple
            case .revelation: return .red
            }
        }
        
        var cost: Int {
            switch self {
            case .clarity: return 25
            case .precision: return 50
            case .momentum: return 75
            case .revelation: return 125
            }
        }
        
        var description: String {
            switch self {
            case .clarity:
                return "Reveals one random letter in an unfound word. Great for getting unstuck!"
            case .precision:
                return "Reveals the first letter of the shortest unfound word. Strategic hint for targeted progress."
            case .momentum:
                return "Reveals three random letters at once. Best value when you're really stuck!"
            case .revelation:
                return "Reveals an entire word instantly. Most expensive but guarantees progress."
            }
        }
        
        var example: String {
            switch self {
            case .clarity:
                return "T_A_ → T_AM"
            case .precision:
                return "Short word: ___ → S__"
            case .momentum:
                return "______ → _E_T_R"
            case .revelation:
                return "______ → MATTER"
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("Hint System Guide")
                        .font(.custom("Cinzel-Bold", size: 24))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal)
                
                // Hint Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(HintType.allCases, id: \.self) { hint in
                        HintCard(
                            hint: hint,
                            isSelected: selectedHint == hint,
                            animateIcon: animateIcons
                        ) {
                            withAnimation(.spring()) {
                                selectedHint = selectedHint == hint ? nil : hint
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Detail View
                if let selected = selectedHint {
                    HintDetailView(hint: selected)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                } else {
                    // General tips
                    VStack(spacing: 12) {
                        Text("💡 Pro Tips")
                            .font(.custom("Cinzel-Bold", size: 18))
                            .foregroundStyle(.yellow)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            TipRow(icon: "star.fill", text: "Save coins by finding bonus words")
                            TipRow(icon: "timer", text: "Use hints strategically - start with Clarity")
                            TipRow(icon: "sparkles", text: "Watch ads for free coins if you're stuck")
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Close button
                Button {
                    isPresented = false
                } label: {
                    Text("Got it!")
                        .font(.custom("Cinzel-Bold", size: 18))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 50)
                        .padding(.vertical, 14)
                        .background(Color.yellow)
                        .clipShape(Capsule())
                }
                .padding(.bottom, 30)
            }
            .padding(.top, 50)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                animateIcons = true
            }
        }
    }
}

private struct HintCard: View {
    let hint: HintExplanationView.HintType
    let isSelected: Bool
    let animateIcon: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Icon with animation
                Image(systemName: hint.icon)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(hint.color)
                    .scaleEffect(animateIcon && !isSelected ? 1.1 : 1.0)
                    .shadow(color: hint.color.opacity(0.5), radius: isSelected ? 10 : 5)
                
                // Title
                Text(hint.title)
                    .font(.custom("Cinzel-Bold", size: 16))
                    .foregroundStyle(.white)
                
                // Cost
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 14))
                    Text("\(hint.cost)")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.yellow)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? hint.color.opacity(0.3) : Color.white.opacity(0.1))
                    .strokeBorder(isSelected ? hint.color : Color.white.opacity(0.2), lineWidth: 2)
            )
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
    }
}

private struct HintDetailView: View {
    let hint: HintExplanationView.HintType
    
    var body: some View {
        VStack(spacing: 16) {
            // Description
            Text(hint.description)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Example
            VStack(spacing: 8) {
                Text("Example:")
                    .font(.custom("Cinzel-Bold", size: 14))
                    .foregroundStyle(.white.opacity(0.7))
                
                Text(hint.example)
                    .font(.system(size: 20, design: .monospaced))
                    .foregroundStyle(hint.color)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Strategy tip
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text(strategyTip)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding()
            .background(hint.color.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
                .strokeBorder(hint.color.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    private var strategyTip: String {
        switch hint {
        case .clarity:
            return "Use when you need any progress"
        case .precision:
            return "Best for targeting specific words"
        case .momentum:
            return "Great value for difficult levels"
        case .revelation:
            return "Save for emergency situations"
        }
    }
}

private struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.yellow)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.9))
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    HintExplanationView(isPresented: .constant(true))
        .background(Color.black)
}
