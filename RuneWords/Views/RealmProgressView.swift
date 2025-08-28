//
//  RealmProgressView.swift
//  RuneWords
//
//  Created by Anthony Yarand on 7/27/25.
//

import SwiftUI
import UIKit

struct Realm: Identifiable {
    let id = UUID()
    let name: String
    let isCompleted: Bool
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct RealmProgressView: View {
    let realms = [
        Realm(name: "Tree Library",     isCompleted: true),
        Realm(name: "Crystal Forest",   isCompleted: false),
        Realm(name: "Sleeping Titan",   isCompleted: false),
        Realm(name: "Astral Peak",      isCompleted: false)
    ]
    
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            let cardWidth = min(geo.size.width * 0.78, 340)
            let cardHeight = cardWidth * 0.6
            let background = realmImage(for: realms.first ?? realms[0])

            ZStack {
                background
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .offset(x: scrollOffset * 0.2)
                    .overlay(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black.opacity(0.4), Color.black.opacity(0.75)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                GeometryReader { scrollGeo in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(realms) { realm in
                                NavigationLink(destination: GameView()) {
                                    RealmCard(
                                        realm: realm,
                                        image: realmImage(for: realm),
                                        size: CGSize(width: cardWidth, height: cardHeight)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: cardHeight + 40)
                        .background(
                            GeometryReader { innerGeo in
                                Color.clear.preference(key: ScrollOffsetPreferenceKey.self, value: innerGeo.frame(in: .global).minX)
                            }
                        )
                    }
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        scrollOffset = value - scrollGeo.frame(in: .global).minX
                    }
                }
                .frame(height: cardHeight + 40)
            }
        }
    }
}

// File-scope helper so both the view and helpers can use it
private func realmImageName(for realm: Realm) -> String {
    let key = realm.name.lowercased().replacingOccurrences(of: " ", with: "")
    return "realm_\(key)"
}

// MARK: - Helpers & Card
private func resolvedRealmImageName(for realm: Realm) -> String {
    let base = realmImageName(for: realm)
    if UIImage(named: base) != nil { return base }
    // Fallback for asset rename not yet performed
    if base == "realm_crystalforest", UIImage(named: "realm_crystalforest") != nil { return "realm_crystalforest" }
    return base
}

private func realmImage(for realm: Realm) -> Image {
    let name = resolvedRealmImageName(for: realm)
    if let ui = UIImage(named: name) { return Image(uiImage: ui) }
    return Image(systemName: "mountain.2.fill")
}

private struct RealmCard: View {
    let realm: Realm
    let image: Image
    let size: CGSize

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            image
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
                .overlay(
                    LinearGradient(gradient: Gradient(colors: [
                        Color.black.opacity(0.0),
                        Color.black.opacity(0.55)
                    ]), startPoint: .center, endPoint: .bottom)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(realm.name)
                    .font(.custom("Cinzel-Bold", size: 20))
                    .shadow(radius: 6)

                if realm.isCompleted {
                    Label("Completed", systemImage: "checkmark.seal.fill")
                        .font(.footnote)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.25))
                        .clipShape(Capsule())
                } else {
                    Label("In Progress", systemImage: "arrow.forward.circle")
                        .font(.footnote)
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.25))
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(.white)
            .padding(12)
        }
        .background(Color.black.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(radius: 8)
    }
}
