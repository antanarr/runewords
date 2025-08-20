// StoreView.swift - Enhanced with Watch Ad Option
// RuneWords

import SwiftUI
import StoreKit

struct StoreView: View {
    @EnvironmentObject private var storeVM: StoreViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAdOption = false
    @State private var adRewardAmount = 25
    @State private var isWatchingAd = false
    @State private var adWatchSuccess = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header with coin balance
                VStack(spacing: 16) {
                    Text("RuneWords Store")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    // Current coin balance
                    HStack(spacing: 8) {
                        Image("icon_coin")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                        Text("\(PlayerService.shared.player?.coins ?? 0)")
                            .font(.custom("Cinzel-Bold", size: 24))
                            .foregroundStyle(.yellow)
                        Text("coins")
                            .font(.custom("Cinzel-Regular", size: 18))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.black.opacity(0.3)))
                }
                .padding(.top, 32)
                .frame(maxWidth: .infinity, alignment: .center)

                // MARK: - Free Coins Section (Watch Ad)
                StoreSectionHeader(title: "Free Coins", icon: "gift.fill", color: .green)
                
                VStack(spacing: 12) {
                    // Watch Ad for Coins
                    Button(action: watchAdForCoins) {
                        HStack {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Watch Ad for Coins")
                                    .font(.custom("Cinzel-Bold", size: 18))
                                Text("Get 25 coins instantly")
                                    .font(.custom("Cinzel-Regular", size: 14))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Image("icon_coin")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                Text("+25")
                                    .font(.custom("Cinzel-Bold", size: 18))
                                    .foregroundStyle(.yellow)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(.green.opacity(0.3)))
                        }
                        .foregroundStyle(.white)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.green.opacity(0.6), .green.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.green.opacity(0.8), lineWidth: 1)
                        )
                    }
                    .accessibilityLabel("Watch ad for 25 coins")
                    .accessibilityAddTraits(.isButton)
                    .disabled(isWatchingAd || !AdManager.shared.isRewardedAdAvailable)
                    
                    if !AdManager.shared.isRewardedAdAvailable {
                        Text("Ad not available. Try again later.")
                            .font(.custom("Cinzel-Regular", size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                    }
                    
                    // Daily Bonus for Plus members
                    if storeVM.hasPlus && !storeVM.dailyBonusClaimedToday {
                        Button(action: { storeVM.claimPlusDailyBonusIfEligible() }) {
                            HStack {
                                Image(systemName: "star.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.yellow)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Plus Daily Bonus")
                                        .font(.custom("Cinzel-Bold", size: 18))
                                    Text("Claim your daily reward")
                                        .font(.custom("Cinzel-Regular", size: 14))
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                                
                                Spacer()
                                
                                HStack(spacing: 4) {
                                    Image("icon_coin")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                    Text("+75")
                                        .font(.custom("Cinzel-Bold", size: 18))
                                        .foregroundStyle(.yellow)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(.yellow.opacity(0.3)))
                            }
                            .foregroundStyle(.white)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.yellow.opacity(0.4), .orange.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(12)
                        }
                    }
                }

                // MARK: - Runes Plus (Monthly)
                if let plus = storeVM.plusMonthlyProduct {
                    StoreSectionHeader(title: "Runes Plus", icon: "crown.fill", color: .purple)

                    if storeVM.hasPlus {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Runes Plus is Active")
                                    .font(.custom("Cinzel-Bold", size: 20))
                                Spacer()
                                Label("Active", systemImage: "checkmark.seal.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.green)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                StoreFeatureRow(text: "No interstitial ads")
                                StoreFeatureRow(text: "+75 coins daily stipend")
                                StoreFeatureRow(text: "1 free Clarity per day")
                                StoreFeatureRow(text: "+10% coins on pack purchases")
                                StoreFeatureRow(text: "Exclusive rune cosmetics")
                            }
                        }
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.purple.opacity(0.2), .purple.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.purple.opacity(0.4), lineWidth: 1)
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(plus.displayName)
                                .font(.custom("Cinzel-Bold", size: 20))
                            VStack(alignment: .leading, spacing: 6) {
                                StoreFeatureRow(text: "No interstitial ads")
                                StoreFeatureRow(text: "+75 coins daily stipend")
                                StoreFeatureRow(text: "1 free Clarity per day")
                                StoreFeatureRow(text: "+10% coins on packs")
                                StoreFeatureRow(text: "Exclusive rune cosmetics")
                            }
                            Button(action: { Task { await storeVM.purchase(product: plus) } }) {
                                HStack {
                                    Text("Subscribe – \(plus.displayPrice)")
                                        .font(.custom("Cinzel-Regular", size: 16))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [.purple.opacity(0.7), .purple.opacity(0.5)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(10)
                            }
                            .accessibilityLabel("Subscribe to Runes Plus – \(plus.displayPrice)")
                            .accessibilityAddTraits(.isButton)
                            .disabled(storeVM.isPurchasing)
                        }
                        .padding()
                        .background(Color.black.opacity(0.20))
                        .cornerRadius(12)
                    }
                }

                // MARK: - Remove Ads (one‑time)
                if let remove = storeVM.removeAdsProduct {
                    StoreSectionHeader(title: "Remove Ads", icon: "nosign", color: .red)
                    Button(action: { Task { await storeVM.purchase(product: remove) } }) {
                        HStack {
                            Text(remove.displayName)
                                .font(.custom("Cinzel-Bold", size: 18))
                            Spacer()
                            if storeVM.hasRemoveAds {
                                Label("Active", systemImage: "checkmark.seal.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.green)
                            } else {
                                Text(remove.displayPrice)
                                    .font(.custom("Cinzel-Regular", size: 16))
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                    }
                    .accessibilityLabel(storeVM.hasRemoveAds ? "Remove Ads (Already Active)" : "Remove Ads – \(remove.displayPrice)")
                    .accessibilityAddTraits(.isButton)
                    .disabled(storeVM.isPurchasing || storeVM.hasRemoveAds)
                }

                // MARK: - Coin Packs
                if !storeVM.coinProducts.isEmpty {
                    StoreSectionHeader(title: "Coin Packs", icon: "dollarsign.circle.fill", color: .yellow)
                    
                    // Show savings percentage
                    Text("Best value on larger packs!")
                        .font(.custom("Cinzel-Regular", size: 14))
                        .foregroundStyle(.yellow.opacity(0.8))
                        .padding(.bottom, 8)
                    
                    VStack(spacing: 12) {
                        ForEach(storeVM.coinProducts, id: \.id) { product in
                            Button(action: { Task { await storeVM.purchase(product: product) } }) {
                                HStack(spacing: 12) {
                                    if let amount = storeVM.coinAmount(for: product) {
                                        HStack(spacing: 6) {
                                            Image("icon_coin")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 20, height: 20)
                                            Text("\(amount)")
                                                .font(.custom("Cinzel-Bold", size: 20))
                                        }
                                        
                                        // Show bonus if Plus member
                                        if storeVM.hasPlus {
                                            Text("+10%")
                                                .font(.custom("Cinzel-Bold", size: 12))
                                                .foregroundStyle(.yellow)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(.purple.opacity(0.3)))
                                        }
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(product.displayName)
                                            .font(.custom("Cinzel-Regular", size: 16))
                                        if let amount = storeVM.coinAmount(for: product) {
                                            let pricePerCoin = product.price / Decimal(amount)
                                            Text("(\(String(format: "%.3f", NSDecimalNumber(decimal: pricePerCoin).doubleValue)) per coin)")
                                                .font(.custom("Cinzel-Regular", size: 11))
                                                .foregroundStyle(.white.opacity(0.6))
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(product.displayPrice)
                                            .font(.custom("Cinzel-Bold", size: 18))
                                        
                                        // Show popular/best value badge
                                        if product.id == "com.yourskinmatters.RuneWords.coins_1000" {
                                            Text("POPULAR")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.orange)
                                                .cornerRadius(4)
                                        } else if product.id == "com.yourskinmatters.RuneWords.coins_5000" {
                                            Text("BEST VALUE")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.green)
                                                .cornerRadius(4)
                                        }
                                    }
                                }
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [.gray.opacity(0.25), .gray.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                            .disabled(storeVM.isPurchasing)
                        }
                    }
                }

                // MARK: - Restore
                Button(action: { Task { await storeVM.restore() } }) {
                    Text("Restore Purchases")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                }
                .accessibilityLabel("Restore previous purchases")
                .accessibilityAddTraits(.isButton)
                .padding(.top, 6)
                .disabled(storeVM.isPurchasing)

                // Purchase result toasts
                if storeVM.purchaseSuccess {
                    StoreToastView(message: "Purchase Successful! 🎉", isError: false)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if storeVM.purchaseFailure {
                    StoreToastView(message: "Purchase Failed", isError: true)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if adWatchSuccess {
                    StoreToastView(message: "You earned 25 coins! 🪙", isError: false)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                adWatchSuccess = false
                            }
                        }
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 24)
        }
        .overlay(alignment: .center) {
            if storeVM.isPurchasing || isWatchingAd {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(isWatchingAd ? "Loading Ad..." : "Processing...")
                            .font(.custom("Cinzel-Regular", size: 16))
                            .foregroundStyle(.white)
                    }
                    .padding(24)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(16)
                }
            }
        }
        .navigationTitle("Store")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.8))
                        .accessibilityLabel("Close store")
                }
            }
        }
        .onAppear {
            // Ensure ads are preloaded
            AdManager.shared.ensurePreloaded()
        }
    }
    
    // MARK: - Watch Ad Function
    private func watchAdForCoins() {
        isWatchingAd = true
        
        AdManager.shared.showRewardedAd { success in
            isWatchingAd = false
            
            if success {
                // Grant coins
                if var playerData = PlayerService.shared.player {
                    playerData.coins += adRewardAmount
                    PlayerService.shared.player = playerData
                    
                    // Show success
                    adWatchSuccess = true
                    HapticManager.shared.play(.success)
                    AudioManager.shared.playSound(effect: .success)
                }
            } else {
                // Ad failed or was dismissed
                HapticManager.shared.play(.error)
            }
        }
    }
}

// MARK: - Supporting Views

struct StoreToastView: View {
    var message: String
    var isError: Bool = false

    var body: some View {
        Text(message)
            .font(.custom("Cinzel-Bold", size: 16))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isError ? Color.red : Color.green)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            )
            .padding(.top, 50)
    }
}

private struct StoreSectionHeader: View {
    let title: String
    var icon: String? = nil
    var color: Color = .white
    
    var body: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
            }
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StoreFeatureRow: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 14))
            Text(text)
                .font(.custom("Cinzel-Regular", size: 14))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    NavigationView {
        StoreView()
            .environmentObject(StoreViewModel.shared)
    }
}
