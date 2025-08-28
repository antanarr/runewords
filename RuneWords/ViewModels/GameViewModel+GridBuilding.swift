import Foundation

// MARK: - Grid Building Extension
extension GameViewModel {
    
    // MARK: - Solution Format Parsing
    func parseSolutionFormats(for level: Level) -> [String: SolutionFormat] {
        var formats: [String: SolutionFormat] = [:]
        
        for (word, indices) in level.solutions {
            // All our level data uses simple wheel format (1-based indices)
            formats[word] = .wheel(indices)
        }
        
        return formats
    }
    
    // MARK: - Grid Building Methods
    func buildGridFromWheelPaths(level: Level) -> [[GridLetter]] {
        let words = level.solutions.keys.map { $0.uppercased() }
        guard !words.isEmpty else { return [[]] }
        
        var grid = [[GridLetter(char: nil)]]
        
        // Helper: Ensure grid has sufficient size
        func ensureSize(rows: Int, cols: Int) {
            // Expand rows if needed
            if grid.count <= rows {
                let currentCols = grid.first?.count ?? (cols + 1)
                let newRows = Array(
                    repeating: Array(repeating: GridLetter(char: nil), count: currentCols),
                    count: rows - grid.count + 1
                )
                grid += newRows
            }
            
            // Expand columns if needed
            if let currentCols = grid.first?.count, currentCols <= cols {
                for r in 0..<grid.count {
                    let newCols = Array(
                        repeating: GridLetter(char: nil),
                        count: cols - currentCols + 1
                    )
                    grid[r] += newCols
                }
            }
        }
        
        // Helper: Place first word horizontally
        func placeFirst(_ word: String) {
            let letters = Array(word)
            ensureSize(rows: 0, cols: letters.count - 1)
            
            for (i, ch) in letters.enumerated() {
                grid[0][i].char = ch
            }
        }
        
        // Helper: Try to place word intersecting with existing words
        func tryPlace(_ word: String) -> Bool {
            let letters = Array(word)
            
            // Look for intersection points
            for (wi, ch) in letters.enumerated() {
                for r in 0..<grid.count {
                    for c in 0..<grid[r].count where grid[r][c].char == ch {
                        // Try vertical placement
                        if tryPlaceVertical(letters, at: (r, c), letterIndex: wi) {
                            return true
                        }
                        
                        // Try horizontal placement
                        if tryPlaceHorizontal(letters, at: (r, c), letterIndex: wi) {
                            return true
                        }
                    }
                }
            }
            
            return false
        }
        
        // Helper: Try vertical placement
        func tryPlaceVertical(_ letters: [Character], at position: (row: Int, col: Int), letterIndex: Int) -> Bool {
            let (r, c) = position
            let top = r - letterIndex
            let bottom = r + (letters.count - letterIndex - 1)
            
            // Check if placement is within bounds
            guard top >= 0 else { return false }
            
            // Ensure grid size
            ensureSize(rows: bottom, cols: c)
            
            // Check for conflicts
            for k in 0..<letters.count {
                let targetRow = top + k
                if let existing = grid[targetRow][c].char,
                   existing != letters[k] {
                    return false
                }
            }
            
            // Place the word
            for k in 0..<letters.count {
                grid[top + k][c].char = letters[k]
            }
            
            return true
        }
        
        // Helper: Try horizontal placement
        func tryPlaceHorizontal(_ letters: [Character], at position: (row: Int, col: Int), letterIndex: Int) -> Bool {
            let (r, c) = position
            let left = c - letterIndex
            let right = c + (letters.count - letterIndex - 1)
            
            // Check if placement is within bounds
            guard left >= 0 else { return false }
            
            // Ensure grid size
            ensureSize(rows: r, cols: right)
            
            // Check for conflicts
            for k in 0..<letters.count {
                let targetCol = left + k
                if let existing = grid[r][targetCol].char,
                   existing != letters[k] {
                    return false
                }
            }
            
            // Place the word
            for k in 0..<letters.count {
                grid[r][left + k].char = letters[k]
            }
            
            return true
        }
        
        // Place first word
        placeFirst(words[0])
        
        // Try to place remaining words
        for word in words.dropFirst() {
            if !tryPlace(word) {
                // If can't intersect, place on new row
                let newRow = grid.count
                let letters = Array(word)
                ensureSize(rows: newRow, cols: letters.count - 1)
                
                for (i, ch) in letters.enumerated() {
                    grid[newRow][i].char = ch
                }
            }
        }
        
        return grid
    }
    
    // MARK: - Legacy Grid Building (for backwards compatibility)
    func buildGridFromCoords(level: Level) -> [[GridLetter]] {
        var maxRow = 0, maxCol = 0
        
        // Parse coordinate pairs to find dimensions
        for coords in level.solutions.values {
            let positions = parsePositions(coords)
            
            // Coordinates come in pairs (row, col)
            for i in stride(from: 0, to: positions.count, by: 2) where i + 1 < positions.count {
                maxRow = max(maxRow, positions[i])
                maxCol = max(maxCol, positions[i + 1])
            }
        }
        
        // Initialize grid
        var grid = Array(
            repeating: Array(repeating: GridLetter(char: nil), count: maxCol + 1),
            count: maxRow + 1
        )
        
        // Place words
        for (word, coords) in level.solutions {
            let upperWord = word.uppercased()
            let letters = Array(upperWord)
            let positions = parsePositions(coords)
            
            // Validate coordinate count
            guard positions.count == letters.count * 2 else { continue }
            
            // Place each letter
            for i in 0..<letters.count {
                let row = positions[i * 2]
                let col = positions[i * 2 + 1]
                
                if row < grid.count, col < grid[row].count {
                    grid[row][col].char = letters[i]
                }
            }
        }
        
        return grid
    }
    
    // MARK: - Position Parsing
    private func parsePositions(_ input: Any) -> [Int] {
        if let string = input as? String {
            return string.split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        } else if let array = input as? [Int] {
            return array
        }
        return []
    }
    
    private func isGridCoordFormat(word: String, positions: [Int]) -> Bool {
        // Grid coordinates have 2 values per letter (row, col)
        return positions.count == word.count * 2
    }
}
