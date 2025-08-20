import Foundation
import SwiftUI

/// Service for validating words against a dictionary
/// Fixed: All heavy processing moved off main thread with Task.detached
@MainActor
final class DictionaryService: ObservableObject {
    
    // MARK: - Shared normalization helper
    static func normalizeWord(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .applyingTransform(.toUnicodeName, reverse: true) ?? s // safe no-op
            .uppercased()
    }
    
    static let shared = DictionaryService()
    
    @MainActor @Published private(set) var isLoaded = false
    @MainActor @Published var loadingProgress: Double = 0.0
    
    private var validWords: Set<String> = []
    private var wordsByLength: [Int: Set<String>] = [:]
    private var prefixTree: PrefixTree = PrefixTree()
    
    // LRU Cache for recent lookups
    private var cache = LRUCache<String, Bool>(capacity: 1000)
    
    private init() {
        // Don't load immediately - defer to prevent crashes during startup
        Task {
            await loadDefaultWordsAsync()
        }
    }
    
    /// Load dictionary asynchronously - FULLY ASYNC
    func loadDictionaryAsync() async {
        await MainActor.run {
            loadingProgress = 0.0
        }
        
        // Try to load from file first
        if let url = Bundle.main.url(forResource: "dictionary-optimized", withExtension: "json") {
            // Load and decode in background thread
            let words = await Task.detached(priority: .userInitiated) { () -> [String]? in
                do {
                    let data = try Data(contentsOf: url)
                    if let words = try JSONSerialization.jsonObject(with: data) as? [String] {
                        return words
                    }
                } catch {
                    print("Failed to load dictionary file: \(error)")
                }
                return nil
            }.value
            
            if let words = words {
                await processDictionary(words)
                return
            }
        }
        
        // Fallback to built-in word list
        print("Using built-in dictionary as fallback")
        await processDictionary(defaultWordList)
    }
    
    /// Process dictionary in background - FULLY ASYNC
    private func processDictionary(_ words: [String]) async {
        // Process entirely in background
        let processedData = await Task.detached(priority: .userInitiated) { () -> (Set<String>, [Int: Set<String>], PrefixTree)? in
            
            var localValidWords = Set<String>()
            var localWordsByLength: [Int: Set<String>] = [:]
            let localPrefixTree = PrefixTree()
            
            for (index, word) in words.enumerated() {
                let upperWord = word.uppercased()
                localValidWords.insert(upperWord)
                
                // Organize by length
                let length = upperWord.count
                if localWordsByLength[length] == nil {
                    localWordsByLength[length] = []
                }
                localWordsByLength[length]?.insert(upperWord)
                
                // Add to prefix tree
                localPrefixTree.insert(upperWord)
                
                // Update progress periodically on main actor
                if index % 100 == 0 {
                    let progress = Double(index) / Double(words.count)
                    Task { @MainActor in
                        DictionaryService.shared.loadingProgress = progress
                    }
                }
            }
            
            return (localValidWords, localWordsByLength, localPrefixTree)
        }.value
        
        // Apply processed data
        if let (processedWords, processedByLength, processedTree) = processedData {
            self.validWords = processedWords
            self.wordsByLength = processedByLength
            self.prefixTree = processedTree
            
            await MainActor.run {
                loadingProgress = 1.0
                isLoaded = true
                print("Dictionary loaded: \(validWords.count) words")
            }
        }
    }
    
    /// Load a basic set of words for immediate use - ASYNC
    private func loadDefaultWordsAsync() async {
        // Process in background
        let processedData = await Task.detached(priority: .userInitiated) { () -> (Set<String>, [Int: Set<String>], PrefixTree)? in
            // Safety guard to prevent double initialization
            var localValidWords = Set<String>()
            var localWordsByLength: [Int: Set<String>] = [:]
            let localPrefixTree = PrefixTree()
            
            print("🔤 Loading default dictionary...")
            
            // Try to load from the default word list
            guard !defaultWordList.isEmpty else {
                print("⚠️ Default word list is empty, using minimal set")
                return DictionaryService.createMinimalWordSet()
            }
            
            // Load words safely
            var loadedCount = 0
            for word in defaultWordList {
                guard !word.isEmpty else { continue }
                
                let upperWord = word.uppercased()
                localValidWords.insert(upperWord)
                
                let length = upperWord.count
                if localWordsByLength[length] == nil {
                    localWordsByLength[length] = []
                }
                localWordsByLength[length]?.insert(upperWord)
                
                localPrefixTree.insert(upperWord)
                loadedCount += 1
            }
            
            // Verify we loaded something
            if loadedCount > 0 {
                print("✅ Default dictionary loaded: \(loadedCount) words")
                return (localValidWords, localWordsByLength, localPrefixTree)
            } else {
                print("❌ Failed to load default dictionary, using minimal set")
                return DictionaryService.createMinimalWordSet()
            }
        }.value
        
        // Apply processed data
        if let (processedWords, processedByLength, processedTree) = processedData {
            self.validWords = processedWords
            self.wordsByLength = processedByLength
            self.prefixTree = processedTree
            
            await MainActor.run {
                isLoaded = true
            }
        }
    }
    
    /// Create minimal word set for emergencies
    private nonisolated static func createMinimalWordSet() -> (Set<String>, [Int: Set<String>], PrefixTree) {
        let essentialWords = ["THE", "AND", "FOR", "ARE", "BUT", "NOT", "YOU", "ALL", "CAN", "HER", "WAS", "ONE", "OUR", "HAD", "BY", "HOT", "WORD", "OIL", "SIT", "TO", "IT", "BE", "IS"]
        
        var localValidWords = Set<String>()
        var localWordsByLength: [Int: Set<String>] = [:]
        let localPrefixTree = PrefixTree()
        
        for word in essentialWords {
            let upperWord = word.uppercased()
            localValidWords.insert(upperWord)
            
            let length = upperWord.count
            if localWordsByLength[length] == nil {
                localWordsByLength[length] = []
            }
            localWordsByLength[length]?.insert(upperWord)
            
            localPrefixTree.insert(upperWord)
        }
        
        print("Minimal dictionary loaded: \(localValidWords.count) words")
        return (localValidWords, localWordsByLength, localPrefixTree)
    }
    
    /// Check if a word is valid - thread-safe
    func isValidWord(_ word: String) -> Bool {
        // Normalize incoming word (trim + uppercase)
        let normalizedWord = DictionaryService.normalizeWord(word)
        
        // Check cache first
        if let cached = cache.get(normalizedWord) {
            return cached
        }
        
        // Check dictionary
        let isValid = validWords.contains(normalizedWord)
        cache.put(normalizedWord, isValid)
        
        return isValid
    }
    
    /// Check if any valid word starts with this prefix - thread-safe
    func hasPrefix(_ prefix: String) -> Bool {
        guard !prefix.isEmpty else { return true }
        // Normalize prefix to uppercase
        let normalizedPrefix = DictionaryService.normalizeWord(prefix)
        return prefixTree.hasPrefix(normalizedPrefix)
    }
    
    /// Check if a word is an isogram (no repeated letters)
    func isIsogram(_ word: String) -> Bool {
        let chars = Array(word.uppercased())
        return Set(chars).count == chars.count
    }
    
    /// Find all 6-letter isograms that can be made from base letters
    func find6LetterIsograms(from baseLetters: String) async -> [String] {
        guard baseLetters.count == 6 else { return [] }
        
        // If base itself isn't an isogram, no 6-letter isograms are possible
        if !isIsogram(baseLetters) {
            return []
        }
        
        // Find all 6-letter words from base
        let words = await findWords(from: baseLetters, minLength: 6, maxLength: 6)
        
        // Filter to only isograms
        return words.filter { isIsogram($0) }
    }
    
    /// Get all valid words that can be made from these letters - ASYNC
    func findWords(from letters: String, minLength: Int = 3, maxLength: Int = 7) async -> [String] {
        // Capture immutable snapshot on the main actor
        let snapshotWordsByLength = self.wordsByLength
        let upper = letters.uppercased()
        return await Task.detached(priority: .userInitiated) { () -> [String] in
            let letterCounts = DictionaryService.countLettersStatic(upper)
            var results: [String] = []
            for length in minLength...maxLength {
                guard let wordsOfLength = snapshotWordsByLength[length] else { continue }
                for word in wordsOfLength {
                    if DictionaryService.canMakeWordStatic(word, from: letterCounts) {
                        results.append(word)
                    }
                }
            }
            return results.sorted()
        }.value
    }
    
    // MARK: - Nonisolated static helpers for background work
    private nonisolated static func countLettersStatic(_ str: String) -> [Character: Int] {
        var counts: [Character: Int] = [:]
        for char in str {
            counts[char, default: 0] += 1
        }
        return counts
    }

    private nonisolated static func canMakeWordStatic(_ word: String, from availableLetters: [Character: Int]) -> Bool {
        let wordCounts = countLettersStatic(word)
        for (letter, count) in wordCounts {
            if availableLetters[letter, default: 0] < count { return false }
        }
        return true
    }

    private func countLetters(_ str: String) -> [Character: Int] {
        var counts: [Character: Int] = [:]
        for char in str {
            counts[char, default: 0] += 1
        }
        return counts
    }
    
    private func canMakeWord(_ word: String, from availableLetters: [Character: Int]) -> Bool {
        let wordCounts = countLetters(word)
        
        for (letter, count) in wordCounts {
            if availableLetters[letter, default: 0] < count {
                return false
            }
        }
        
        return true
    }
}

// MARK: - Prefix Tree for efficient prefix checking
private class PrefixTree {
    class Node {
        var children: [Character: Node] = [:]
        var isEndOfWord = false
    }
    
    private let root = Node()
    
    func insert(_ word: String) {
        var current = root
        for char in word {
            if current.children[char] == nil {
                current.children[char] = Node()
            }
            current = current.children[char]!
        }
        current.isEndOfWord = true
    }
    
    func hasPrefix(_ prefix: String) -> Bool {
        var current = root
        for char in prefix {
            guard let next = current.children[char] else {
                return false
            }
            current = next
        }
        return true
    }
}

// MARK: - LRU Cache for performance
private class LRUCache<Key: Hashable, Value> {
    private class Node {
        var key: Key?
        var value: Value?
        var prev: Node?
        var next: Node?
        
        init(key: Key? = nil, value: Value? = nil) {
            self.key = key
            self.value = value
        }
    }
    
    private let capacity: Int
    private var cache: [Key: Node] = [:]
    private let head = Node() // Dummy head node
    private let tail = Node() // Dummy tail node
    
    init(capacity: Int) {
        self.capacity = capacity
        head.next = tail
        tail.prev = head
    }
    
    func get(_ key: Key) -> Value? {
        guard let node = cache[key] else { return nil }
        moveToHead(node)
        return node.value
    }
    
    func put(_ key: Key, _ value: Value) {
        if let node = cache[key] {
            node.value = value
            moveToHead(node)
        } else {
            let newNode = Node(key: key, value: value)
            cache[key] = newNode
            addToHead(newNode)
            
            if cache.count > capacity {
                if let toRemove = tail.prev, toRemove !== head {
                    removeNode(toRemove)
                    if let keyToRemove = toRemove.key {
                        cache.removeValue(forKey: keyToRemove)
                    }
                }
            }
        }
    }
    
    private func addToHead(_ node: Node) {
        node.prev = head
        node.next = head.next
        head.next?.prev = node
        head.next = node
    }
    
    private func removeNode(_ node: Node) {
        node.prev?.next = node.next
        node.next?.prev = node.prev
    }
    
    private func moveToHead(_ node: Node) {
        removeNode(node)
        addToHead(node)
    }
}

// MARK: - Default Word List for Testing
private let defaultWordList = [
    // 3 letter words
    "ACE", "ACT", "ADD", "AGE", "AID", "AIM", "AIR", "ART", "ASK", "ATE",
    "BAD", "BAG", "BAT", "BED", "BIG", "BIT", "BOX", "BOY", "BUS", "BUT",
    "CAN", "CAR", "CAT", "CUP", "CUT", "DAD", "DAY", "DID", "DIG", "DOG",
    "EAR", "EAT", "EGG", "END", "EYE", "FAR", "FAT", "FEW", "FLY", "FOR",
    "FUN", "GET", "GOD", "GOT", "GUN", "GUY", "HAD", "HAS", "HAT", "HER",
    "HIM", "HIS", "HIT", "HOT", "HOW", "ITS", "JOB", "JOY", "KEY", "KID",
    "LAY", "LED", "LEG", "LET", "LIE", "LIT", "LOT", "LOW", "MAD", "MAN",
    "MAP", "MAT", "MAY", "MEN", "MET", "MIX", "MOM", "NEW", "NOT", "NOW",
    "ODD", "OFF", "OIL", "OLD", "ONE", "OUR", "OUT", "OWN", "PAY", "PET",
    "PUT", "RAN", "RAT", "RAY", "RED", "RID", "RUN", "SAD", "SAT", "SAW",
    "SAY", "SEA", "SEE", "SET", "SHE", "SIT", "SIX", "SKY", "SON", "SUN",
    "TEA", "TEN", "THE", "TIE", "TIP", "TOO", "TOP", "TOY", "TRY", "TWO",
    "USE", "VAN", "WAR", "WAS", "WAY", "WET", "WHO", "WHY", "WIN", "WON",
    "YES", "YET", "YOU", "ZIP",
    
    // 4 letter words
    "ABLE", "ALSO", "AREA", "ARMY", "AWAY", "BABY", "BACK", "BALL", "BAND", "BANK",
    "BASE", "BEAR", "BEAT", "BEEN", "BEST", "BILL", "BIRD", "BLOW", "BLUE", "BOAT",
    "BODY", "BOOK", "BORN", "BOTH", "BOWL", "BURN", "BUSY", "CALL", "CAME", "CAMP",
    "CARD", "CARE", "CASE", "CASH", "CAST", "CELL", "CITY", "CLUB", "COAL", "COAT",
    "CODE", "COLD", "COME", "COOK", "COOL", "COPY", "CORE", "COST", "CREW", "CROP",
    "DARK", "DATA", "DATE", "DAWN", "DAYS", "DEAD", "DEAL", "DEAR", "DEBT", "DEEP",
    "DENY", "DESK", "DIAL", "DIET", "DIRT", "DISH", "DOES", "DONE", "DOOR", "DOWN",
    "DRAW", "DREW", "DROP", "DRUG", "DUST", "DUTY", "EACH", "EARN", "EASE", "EAST",
    "EASY", "EDGE", "ELSE", "EVEN", "EVER", "FACE", "FACT", "FAIL", "FAIR", "FALL",
    "FARM", "FAST", "FATE", "FEAR", "FEED", "FEEL", "FEET", "FELL", "FELT", "FILE",
    "FILL", "FILM", "FIND", "FINE", "FIRE", "FIRM", "FISH", "FIVE", "FLAT", "FLOW",
    "FOOD", "FOOT", "FORM", "FORT", "FOUR", "FREE", "FROM", "FUEL", "FULL", "FUND",
    "GAIN", "GAME", "GATE", "GAVE", "GEAR", "GIFT", "GIRL", "GIVE", "GLAD", "GOAL",
    "GOES", "GOLD", "GOLF", "GONE", "GOOD", "GRAY", "GREW", "GREY", "GROW", "GULF",
    "HAIR", "HALF", "HALL", "HAND", "HANG", "HARD", "HARM", "HATE", "HAVE", "HEAD",
    "HEAR", "HEAT", "HELD", "HELL", "HELP", "HERE", "HERO", "HIGH", "HILL", "HINT",
    "HIRE", "HOLD", "HOLE", "HOLY", "HOME", "HOPE", "HOST", "HOUR", "HUGE", "HUNG",
    "HUNT", "HURT", "IDEA", "INCH", "INTO", "IRON", "ITEM", "JACK", "JANE", "JEAN",
    "JOHN", "JOIN", "JUMP", "JURY", "JUST", "KEEP", "KEPT", "KICK", "KILL", "KIND",
    "KING", "KNEE", "KNEW", "KNOW", "LACK", "LADY", "LAID", "LAKE", "LAND", "LAST",
    "LATE", "LEAD", "LEAN", "LEFT", "LESS", "LIFE", "LIFT", "LIKE", "LINE", "LINK",
    "LIST", "LIVE", "LOAD", "LOAN", "LOCK", "LOGO", "LONG", "LOOK", "LORD", "LOSE",
    "LOSS", "LOST", "LOVE", "LUCK", "MADE", "MAIL", "MAIN", "MAKE", "MALE", "MANY",
    "MARK", "MASS", "MATE", "MEAL", "MEAN", "MEAT", "MEET", "MENU", "MERE", "MIKE",
    "MILE", "MILK", "MIND", "MINE", "MISS", "MODE", "MOOD", "MOON", "MORE", "MOST",
    "MOVE", "MUCH", "MUST", "NAME", "NAVY", "NEAR", "NECK", "NEED", "NEWS", "NEXT",
    "NICE", "NICK", "NINE", "NONE", "NOON", "NORM", "NOSE", "NOTE", "OKAY", "ONCE",
    "ONLY", "ONTO", "OPEN", "ORAL", "OVER", "PACE", "PACK", "PAGE", "PAID", "PAIN",
    "PAIR", "PALE", "PALM", "PARK", "PART", "PASS", "PAST", "PATH", "PEAK", "PICK",
    "PINK", "PIPE", "PLAN", "PLAY", "PLOT", "PLUG", "PLUS", "POEM", "POET", "POLE",
    "POLL", "POND", "POOL", "POOR", "PORT", "POST", "POUR", "PRAY", "PREP", "PULL",
    "PURE", "PUSH", "QUIT", "RACE", "RAIL", "RAIN", "RANK", "RARE", "RATE", "READ",
    "REAL", "TEAM", "REAR", "RELY", "RENT", "REST", "RICE", "RICH", "RIDE", "RING",
    "RISE", "RISK", "ROAD", "ROCK", "RODE", "ROLE", "ROLL", "ROOF", "ROOM", "ROOT",
    "ROSE", "RULE", "RUSH", "RUTH", "SAFE", "SAID", "SAKE", "SALE", "SALT", "SAME",
    "SAND", "SANG", "SAVE", "SEAT", "SEED", "SEEK", "SEEM", "SEEN", "SELF", "SELL",
    "SEND", "SENT", "SEPT", "SHIP", "SHOP", "SHOT", "SHOW", "SHUT", "SICK", "SIDE",
    "SIGN", "SILK", "SING", "SINK", "SITE", "SIZE", "SKIN", "SLIP", "SLOW", "SNOW",
    "SOFT", "SOIL", "SOLD", "SOLE", "SOME", "SONG", "SOON", "SORT", "SOUL", "SPOT",
    "STAR", "STAY", "STEM", "STEP", "STOP", "SUCH", "SUIT", "SURE", "TAKE", "TALE",
    "TALK", "TALL", "TANK", "TAPE", "TASK", "TEAM", "TECH", "TELL", "TEND", "TERM",
    "TEST", "TEXT", "THAN", "THAT", "THEM", "THEN", "THEY", "THIN", "THIS", "THUS",
    "TIDE", "TIED", "TIER", "TILE", "TILL", "TIME", "TINY", "TIRE", "TOLD", "TOLL",
    "TONE", "TONY", "TOOK", "TOOL", "TORN", "TOUR", "TOWN", "TREE", "TRIM", "TRIP",
    "TRUE", "TUBE", "TUNE", "TURN", "TWIN", "TYPE", "UNIT", "UPON", "USED", "USER",
    "VARY", "VAST", "VERY", "VIEW", "VOTE", "WAGE", "WAIT", "WAKE", "WALK", "WALL",
    "WANT", "WARD", "WARM", "WARN", "WASH", "WAVE", "WAYS", "WEAK", "WEAR", "WEEK",
    "WELL", "WENT", "WERE", "WEST", "WHAT", "WHEN", "WHOM", "WIDE", "WIFE", "WILD",
    "WILL", "WIND", "WINE", "WING", "WIRE", "WISE", "WISH", "WITH", "WOOD", "WORD",
    "WORE", "WORK", "WORM", "WORN", "WRAP", "YARD", "YEAR", "YOUR", "ZERO", "ZONE",
    
    // 5 letter words
    "ABOUT", "ABOVE", "ABUSE", "ADMIT", "ADOPT", "ADULT", "AFTER", "AGAIN", "AGENT",
    "AGREE", "AHEAD", "ALARM", "ALBUM", "ALERT", "ALIKE", "ALIVE", "ALLOW", "ALONE",
    "ALONG", "ALTER", "ANGEL", "ANGER", "ANGLE", "ANGRY", "ANTES", "APART", "APPLE", "APPLY",
    "ARENA", "ARGUE", "ARISE", "ARMED", "ARMOR", "AROSE", "ARRAY", "ARROW", "ASIDE",
    "ASSET", "AVOID", "AWAKE", "AWARD", "AWARE", "BADLY", "BAKER", "BASES", "BASIC",
    "BEACH", "BEGAN", "BEING", "BELOW", "BENCH", "BILLY", "BIRTH", "BLACK", "BLAME",
    "BLANK", "BLIND", "BLOCK", "BLOOD", "BLOOM", "BLOWN", "BLUES", "BOARD", "BOOST",
    "BOOTH", "BOUND", "BRAIN", "BRAND", "BRASS", "BRAVE", "BREAD", "BREAK", "BREED",
    "BRIEF", "BRING", "BROAD", "BROKE", "BROWN", "BUILD", "BUILT", "BUYER", "CABLE",
    "CALIF", "CARRY", "CATCH", "CAUSE", "CHAIN", "CHAIR", "CHAOS", "CHARM", "CHART",
    "CHASE", "CHEAP", "CHECK", "CHEST", "CHIEF", "CHILD", "CHINA", "CHOSE", "CHRIS",
    "CIVIL", "CLAIM", "CLASS", "CLEAN", "CLEAR", "CLIMB", "CLOCK", "CLOSE", "CLOUD",
    "COACH", "COAST", "COULD", "COUNT", "COURT", "COVER", "CRACK", "CRAFT", "CRASH",
    "CRAZY", "CREAM", "CRIME", "CROSS", "CROWD", "CROWN", "CRUDE", "CURVE", "CYCLE",
    "DAILY", "DANCE", "DATED", "DEALT", "DEATH", "DEBUT", "DELAY", "DELTA", "DENSE",
    "DEPOT", "DEPTH", "DERBY", "DIGIT", "DIRTY", "DOESN", "DOING", "DOUBT", "DOZEN",
    "DRAFT", "DRAIN", "DRAMA", "DRANK", "DRAWN", "DREAM", "DRESS", "DRIED", "DRILL",
    "DRINK", "DRIVE", "DROVE", "DYING", "EAGER", "EARLY", "EARTH", "EIGHT", "EITHER",
    "ELECT", "EMAIL", "EMPTY", "ENEMY", "ENJOY", "ENTER", "ENTRY", "EQUAL", "ERROR",
    "EVENT", "EVERY", "EXACT", "EXIST", "EXTRA", "FAITH", "FALSE", "FANCY", "FAULT",
    "FENCE", "FIBER", "FIELD", "FIFTH", "FIFTY", "FIGHT", "FINAL", "FIRST", "FIXED",
    "FLASH", "FLEET", "FLESH", "FLIGHT", "FLOAT", "FLOOD", "FLOOR", "FLUID", "FOCUS",
    "FORCE", "FORTH", "FORTY", "FORUM", "FOUND", "FRAME", "FRANK", "FRAUD", "FRESH",
    "FRONT", "FROST", "FRUIT", "FULLY", "FUNNY", "GAMMA", "GAUGE", "GENRE", "GHOST",
    "GIANT", "GIVEN", "GLASS", "GLOBE", "GLORY", "GOING", "GRACE", "GRADE", "GRAIN",
    "GRAND", "GRANT", "GRASS", "GRAVE", "GREAT", "GREEN", "GROSS", "GROUP", "GROWN",
    "GUARD", "GUESS", "GUEST", "GUIDE", "GUILT", "HABIT", "HAPPY", "HARRY", "HARSH",
    "HASTE", "HEART", "HEAVY", "HEDGE", "HELLO", "HENRY", "HENCE", "HIRED", "HOBBY",
    "HOLDS", "HONOR", "HORSE", "HOTEL", "HOUSE", "HUMAN", "IDEAL", "IMAGE", "IMPLY",
    "INDEX", "INNER", "INPUT", "INSET", "ISSUE", "JAPAN", "JIMMY", "JOINT", "JONES", "JUDGE",
    "KNOWN", "LABEL", "LARGE", "LASER", "LATER", "LAUGH", "LAYER", "LEARN", "LEASE",
    "LEAST", "LEAVE", "LEGAL", "LEMON", "LEVEL", "LEWIS", "LIGHT", "LIMIT", "LINKS",
    "LIVES", "LOCAL", "LOGIC", "LOOSE", "LOWER", "LUCKY", "LUNCH", "LYING", "MAGIC",
    "MAJOR", "MAKER", "MARCH", "MARIA", "MATCH", "MAYBE", "MAYOR", "MEANT", "MEDIA",
    "METAL", "MIGHT", "MINOR", "MINUS", "MIXED", "MODEL", "MONEY", "MONTH", "MORAL",
    "MOTOR", "MOUNT", "MOUSE", "MOUTH", "MOVED", "MOVIE", "MUSIC", "NATES", "NEATS", "NEEDS", "NEVER",
    "NEWLY", "NIGHT", "NOISE", "NORTH", "NOTED", "NOVEL", "NURSE", "OCCUR", "OCEAN",
    "OFFER", "OFTEN", "ORDER", "OTHER", "OUGHT", "OUTER", "OWNER", "PAINT", "PANEL",
    "PAPER", "PARIS", "PARTY", "PEACE", "PENNY", "PETER", "PHASE", "PHONE", "PHOTO",
    "PIANO", "PIECE", "PILOT", "PITCH", "PLACE", "PLAIN", "PLANE", "PLANT", "PLATE",
    "PLAZA", "POINT", "POUND", "POWER", "PRESS", "PRICE", "PRIDE", "PRIME", "PRINT",
    "PRIOR", "PRIZE", "PROOF", "PROUD", "PROVE", "QUEEN", "QUEST", "QUICK", "QUIET",
    "QUITE", "RADIO", "RAISE", "RANGE", "RAPID", "RATIO", "REACH", "REALM", "REBEL",
    "REFER", "RELAX", "REPLY", "RIDER", "RIDGE", "RIFLE", "RIGHT", "RIGID", "RIVER",
    "ROCKY", "ROGER", "ROMAN", "ROUGH", "ROUND", "ROUTE", "ROYAL", "RURAL", "SAINT", "SATIN", "SCALE",
    "SCENE", "SCOPE", "SCORE", "SCREW", "SENSE", "SERVE", "SEVEN", "SHALL", "SHAPE",
    "SHARE", "SHARP", "SHEAR", "SHEET", "SHELF", "SHELL", "SHIFT", "SHINE", "SHIRT",
    "SHOCK", "SHOOT", "SHORE", "SHORT", "SHOWN", "SIDED", "SIGHT", "SILLY", "SIMON",
    "SINCE", "SIXTH", "SIXTY", "SIZED", "SKILL", "SLASH", "SLEEP", "SLIDE", "SLOPE",
    "SMALL", "SMART", "SMILE", "SMITH", "SMOKE", "SNAKE", "SOLID", "SOLVE", "SORRY",
    "SOUND", "SOUTH", "SPACE", "SPARE", "SPEAK", "SPEED", "SPEND", "SPENT", "SPLIT",
    "SPOKE", "SPORT", "SPREAD", "SQUAD", "STAFF", "STAGE", "STAIN", "STAIR", "STAKE", "STAND",
    "START", "STATE", "STEAM", "STEEL", "STEEP", "STEER", "STEIN", "STICK", "STILL", "STOCK",
    "STOLE", "STONE", "STOOD", "STORE", "STORM", "STORY", "STRIP", "STUCK", "STUDY",
    "STUFF", "STYLE", "SUGAR", "SUITE", "SUNNY", "SUPER", "SURGE", "SWEET", "SWIFT",
    "SWING", "SWORD", "TABLE", "TAINS", "TAKEN", "TASTE", "TAXES", "TEACH", "TEAMS", "TEENS",
    "TEETH", "TEMPO", "TERRY", "TEXAS", "THANK", "THEFT", "THEIR", "THEME", "THERE",
    "THESE", "THICK", "THING", "THINK", "THIRD", "THOSE", "THREE", "THREW", "THROW",
    "THUMB", "TIGHT", "TIMER", "TITLE", "TODAY", "TOMMY", "TOPIC", "TOTAL", "TOUCH",
    "TOUGH", "TOWER", "TRACK", "TRADE", "TRAIL", "TRAIN", "TRAIT", "TRASH", "TREAT",
    "TREND", "TRIAL", "TRIBE", "TRICK", "TRIED", "TRIES", "TROOP", "TRUCK", "TRULY",
    "TRUMP", "TRUST", "TRUTH", "TWICE", "UNDER", "UNDUE", "UNION", "UNITY", "UNTIL",
    "UPPER", "UPSET", "URBAN", "USAGE", "USUAL", "VALID", "VALUE", "VIDEO", "VIRUS",
    "VISIT", "VITAL", "VOCAL", "VOICE", "VOTER", "WATCH", "WATER", "WHEEL", "WHERE",
    "WHICH", "WHILE", "WHITE", "WHOLE", "WHOSE", "WIDER", "WIDOW", "WIDTH", "WOMAN",
    "WOMEN", "WORLD", "WORRY", "WORSE", "WORST", "WORTH", "WOULD", "WOUND", "WRIST",
    "WRITE", "WRONG", "WROTE", "YIELD", "YOUNG", "YOURS", "YOUTH",
    
    // 6 letter words
    "MATTER", "MATRIX", "STREET", "STREAM", "STRIPE", "SAINTE"
]
