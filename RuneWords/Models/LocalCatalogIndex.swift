import Foundation

// MARK: - Local Catalog Index
struct LocalCatalogIndex: Codable {
    let version: String
    let source: String
    let totalLevels: Int
    let chunks: [ChunkInfo]
    let metadata: CatalogMetadata
    
    struct ChunkInfo: Codable {
        let id: String
        let file: String
        let startId: Int
        let endId: Int
        let count: Int
    }
    
    struct CatalogMetadata: Codable {
        let generatedAt: String
        let minWordLength: Int
        let maxWordLength: Int
        let baseLetterCount: Int
    }
}
