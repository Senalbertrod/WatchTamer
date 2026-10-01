//
//  BattleCode.swift
//  WatchTamer Watch App
//
//  Friend battles without internet, like plugging two pets together:
//  each watch shows a 6-character code holding a snapshot of its dino.
//  Players swap codes, and both watches replay the exact same fight
//  (same seeded dice), so both agree on who won.
//

import Foundation

struct BattleCode: Equatable {
    let species: DinoSpecies
    let strength: Int      // 0...4
    let effort: Int        // 0...4
    let trainings: Int     // 0...31
    let nonce: Int         // 0...511, makes every code unique

    // No 0/O or 1/I, so codes are easy to read and type.
    private static let alphabet = Array("23456789ABCDEFGHJKLMNPQRSTUVWXYZ")

    init(species: DinoSpecies, strength: Int, effort: Int, trainings: Int, nonce: Int) {
        self.species = species
        self.strength = min(4, max(0, strength))
        self.effort = min(4, max(0, effort))
        self.trainings = min(31, max(0, trainings))
        self.nonce = nonce & 511
    }

    init(pet: Pet) {
        self.init(species: pet.species, strength: pet.strength, effort: pet.effort,
                  trainings: pet.trainings, nonce: Int.random(in: 0...511))
    }

    /// 24 data bits + 6 check bits = 30 bits = 6 characters.
    private var payload: UInt32 {
        let index = UInt32(DinoSpecies.allCases.firstIndex(of: species) ?? 0)
        var p: UInt32 = index                 // 4 bits
        p = (p << 3) | UInt32(strength)       // 3 bits
        p = (p << 3) | UInt32(effort)         // 3 bits
        p = (p << 5) | UInt32(trainings)      // 5 bits
        p = (p << 9) | UInt32(nonce)          // 9 bits
        return p
    }

    private static func checksum(_ payload: UInt32) -> UInt32 {
        ((payload &* 0x9E37_79B1) >> 26) & 63
    }

    /// Numeric value, used to decide who shoots first and to seed the dice.
    var value: UInt32 { (payload << 6) | BattleCode.checksum(payload) }

    /// e.g. "K7M-3QX"
    var text: String {
        var v = value
        var chars: [Character] = []
        for _ in 0..<6 {
            chars.append(BattleCode.alphabet[Int(v & 31)])
            v >>= 5
        }
        let s = String(chars.reversed())
        return String(s.prefix(3)) + "-" + String(s.suffix(3))
    }

    /// Accepts any case, with or without the dash or spaces. Returns nil if mistyped.
    static func decode(_ input: String) -> BattleCode? {
        let cleaned = input.uppercased().filter { $0.isLetter || $0.isNumber }
        guard cleaned.count == 6 else { return nil }
        var v: UInt32 = 0
        for ch in cleaned {
            guard let i = alphabet.firstIndex(of: ch) else { return nil }
            v = (v << 5) | UInt32(i)
        }
        let payload = v >> 6
        guard v & 63 == checksum(payload) else { return nil }

        let nonce = Int(payload & 511)
        let trainings = Int((payload >> 9) & 31)
        let effort = Int((payload >> 14) & 7)
        let strength = Int((payload >> 17) & 7)
        let index = Int((payload >> 20) & 15)
        guard index < DinoSpecies.allCases.count, strength <= 4, effort <= 4 else { return nil }
        let species = DinoSpecies.allCases[index]
        guard species.stage.order >= DinoStage.rookie.order else { return nil }
        return BattleCode(species: species, strength: strength, effort: effort,
                          trainings: trainings, nonce: nonce)
    }

    var power: Double {
        Tuning.battlePower(species.stage)
            + Double(strength) * 5
            + Double(effort) * 5
            + Double(trainings) * 0.5
    }

    /// One shot in a fight: who fired, and whether it hit.
    struct Shot: Equatable {
        let fromPlayer: Bool
        let hit: Bool
    }

    /// Plays the whole fight with dice seeded from BOTH codes, so the two watches
    /// get identical results. Returned from `mine`'s point of view.
    static func duel(mine: BattleCode, theirs: BattleCode) -> [Shot] {
        let iAmFirst = mine.value < theirs.value
        let first = iAmFirst ? mine : theirs
        let second = iAmFirst ? theirs : mine
        var rng = SplitMix64(seed: (UInt64(first.value) << 32) | UInt64(second.value))

        let firstHit = hitChance(attacker: first.power, defender: second.power)
        let secondHit = hitChance(attacker: second.power, defender: first.power)
        var firstLives = 3
        var secondLives = 3
        var shots: [Shot] = []

        while firstLives > 0 && secondLives > 0 && shots.count < 60 {
            let h1 = rng.nextUnit() < firstHit
            shots.append(Shot(fromPlayer: iAmFirst, hit: h1))
            if h1 { secondLives -= 1 }
            if secondLives == 0 { break }

            let h2 = rng.nextUnit() < secondHit
            shots.append(Shot(fromPlayer: !iAmFirst, hit: h2))
            if h2 { firstLives -= 1 }
        }
        return shots
    }

    static func hitChance(attacker: Double, defender: Double) -> Double {
        min(0.85, max(0.2, 0.5 + (attacker - defender) / 100))
    }
}

/// Tiny deterministic random number generator (same sequence on every device).
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 0 ..< 1, built from integer bits only so every device agrees.
    mutating func nextUnit() -> Double {
        Double(next() >> 11) / Double(UInt64(1) << 53)
    }
}
