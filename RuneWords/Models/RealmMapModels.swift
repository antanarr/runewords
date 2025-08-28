//
//  RealmMapModels.swift
//  RuneWords
//
//  Centralized data models for the Realm Map feature
//

import SwiftUI

// MARK: - Data Models
struct RealmLevel: Identifiable {
    let id: Int
    let position: CGPoint
    let realm: RealmType
    let difficulty: Difficulty
    let levelType: LevelType
    var isUnlocked: Bool = false
    var isCompleted: Bool = false
    var stars: Int = 0
    var hasWisp: Bool = false
    var hasCrown: Bool = false
    var storyText: String?
    
    enum LevelType {
        case normal
        case boss
        case story
        case challenge
        case bonus
        
        var icon: String {
            switch self {
            case .normal: return "circle.fill"
            case .boss: return "crown.fill"
            case .story: return "book.fill"
            case .challenge: return "bolt.fill"
            case .bonus: return "star.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .normal: return .blue
            case .boss: return .red
            case .story: return .purple
            case .challenge: return .orange
            case .bonus: return .yellow
            }
        }
    }
    
    enum RealmType: String, CaseIterable {
        case treeLibrary = "Tree Library"
        case crystalForest = "Crystal Forest"
        case sleepingTitan = "Sleeping Titan"
        case astralPeak = "Astral Peak"
        
        var color: Color {
            switch self {
            case .treeLibrary: return .green
            case .crystalForest: return .blue
            case .sleepingTitan: return .orange
            case .astralPeak: return .pink
            }
        }
        
        var icon: String {
            switch self {
            case .treeLibrary: return "tree.fill"
            case .crystalForest: return "sparkles"
            case .sleepingTitan: return "flame.fill"
            case .astralPeak: return "star.circle.fill"
            }
        }
    }
}

struct JourneyLandmark: Identifiable {
    let id = UUID()
    let position: CGPoint
    let type: LandmarkType
    let realm: RealmLevel.RealmType
    let title: String
    let description: String
    var isDiscovered: Bool = false
    
    enum LandmarkType {
        case portal
        case monument
        case shrine
        case library
        case tower
        
        var icon: String {
            switch self {
            case .portal: return "oval.portrait.fill"
            case .monument: return "building.columns.fill"
            case .shrine: return "flame.fill"
            case .library: return "books.vertical.fill"
            case .tower: return "building.2.fill"
            }
        }
    }
}

struct MagicalWisp: Identifiable {
    let id = UUID()
    let levelID: Int
    let position: CGPoint
    let color: Color
    var isCollected: Bool = false
    var rarity: Rarity = .common
    
    enum Rarity {
        case common, rare, epic, legendary
        
        var color: Color {
            switch self {
            case .common: return .gray
            case .rare: return .blue
            case .epic: return .purple
            case .legendary: return .orange
            }
        }
    }
}

// MARK: - Custom Shapes
struct MagicalWispShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        // Create a magical wisp shape with floating orb effect
        path.addEllipse(in: CGRect(
            x: center.x - radius * 0.8,
            y: center.y - radius * 0.8,
            width: radius * 1.6,
            height: radius * 1.6
        ))
        
        // Add smaller energy trails
        for i in 0..<3 {
            let angle = Double(i) * 2 * .pi / 3
            let trailRadius = radius * 0.3
            let trailCenter = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius * 0.6,
                y: center.y + CGFloat(sin(angle)) * radius * 0.6
            )
            path.addEllipse(in: CGRect(
                x: trailCenter.x - trailRadius,
                y: trailCenter.y - trailRadius,
                width: trailRadius * 2,
                height: trailRadius * 2
            ))
        }
        
        return path
    }
}
