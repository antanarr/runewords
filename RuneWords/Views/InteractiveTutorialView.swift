// InteractiveTutorialView.swift - Coach Marks Style Tutorial
// Appears only on first game, after onboarding

import SwiftUI

struct InteractiveTutorialView: View {
    @Binding var isPresented: Bool
    @State private var currentStep = 0
    @State private var animateHighlight = false
    
    let tutorialSteps = [
        TutorialStep(
            title: "Drag to Form Words",
            description: "Drag your finger across the letters below to form words",
            highlightArea: .letterWheel,
            icon: "hand.draw"
        ),
        TutorialStep(
            title: "Find Target Words",
            description: "Complete the level by finding all words shown above",
            highlightArea: .wordGrid,
            icon: "star.fill"
        ),
        TutorialStep(
            title: "Use Hints",
            description: "Stuck? Use hints to reveal letters",
            highlightArea: .hintButtons,
            icon: "lightbulb.fill"
        ),
        TutorialStep(
            title: "Earn Bonus Coins",
            description: "Find extra words for bonus coins!",
            highlightArea: .bonusWords,
            icon: "dollarsign.circle.fill"
        )
    ]
    
    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    advanceStep()
                }
            
            // Tutorial popup
            VStack {
                if currentStep < tutorialSteps.count {
                    // Position based on highlight area
                    if tutorialSteps[currentStep].highlightArea == .wordGrid {
                        Spacer().frame(height: 200)
                    } else if tutorialSteps[currentStep].highlightArea == .letterWheel {
                        Spacer()
                    } else if tutorialSteps[currentStep].highlightArea == .hintButtons {
                        Spacer().frame(height: 100)
                    }
                    
                    TutorialPopup(
                        step: tutorialSteps[currentStep],
                        currentStep: currentStep,
                        totalSteps: tutorialSteps.count,
                        onNext: advanceStep,
                        onSkip: completeTutorial
                    )
                    .padding(.horizontal, 24)
                    .scaleEffect(animateHighlight ? 1.0 : 0.9)
                    .opacity(animateHighlight ? 1.0 : 0)
                    
                    if tutorialSteps[currentStep].highlightArea == .wordGrid {
                        Spacer()
                    } else if tutorialSteps[currentStep].highlightArea == .hintButtons {
                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animateHighlight = true
            }
        }
        .onChange(of: currentStep) { _, _ in
            animateHighlight = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    animateHighlight = true
                }
            }
        }
    }
    
    private func advanceStep() {
        HapticManager.shared.play(.light)
        if currentStep < tutorialSteps.count - 1 {
            currentStep += 1
        } else {
            completeTutorial()
        }
    }
    
    private func completeTutorial() {
        HapticManager.shared.play(.medium)
        withAnimation(.easeOut(duration: 0.3)) {
            isPresented = false
        }
        UserDefaults.standard.set(true, forKey: "hasCompletedTutorial")
    }
}

// MARK: - Tutorial Step Model
struct TutorialStep {
    let title: String
    let description: String
    let highlightArea: HighlightArea
    let icon: String
    
    enum HighlightArea {
        case letterWheel
        case wordGrid
        case hintButtons
        case bonusWords
    }
}

// MARK: - Tutorial Popup Component
struct TutorialPopup: View {
    let step: TutorialStep
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress indicator
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Circle()
                        .fill(index <= currentStep ? Color.yellow : Color.white.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            
            // Icon
            Image(systemName: step.icon)
                .font(.system(size: 44))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Content
            VStack(spacing: 8) {
                Text(step.title)
                    .font(.custom("Cinzel-Bold", size: 20))
                    .foregroundStyle(.white)
                
                Text(step.description)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
            
            // Buttons
            HStack(spacing: 16) {
                Button("Skip Tutorial") {
                    onSkip()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                
                Button(currentStep == totalSteps - 1 ? "Start Playing" : "Next") {
                    onNext()
                }
                .font(.custom("Cinzel-Bold", size: 16))
                .foregroundStyle(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.yellow)
                .clipShape(Capsule())
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.95))
                .strokeBorder(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview
#Preview("Tutorial") {
    InteractiveTutorialView(isPresented: .constant(true))
        .preferredColorScheme(.dark)
}