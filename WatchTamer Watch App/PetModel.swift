//
//  PetModel.swift
//  WatchTamer Watch App
//
//  The pure game rules of a classic 90s virtual pet, with no UI and no timers.
//  Everything advances one "game minute" at a time through `simulateMinute(at:)`,
//  so the same code runs live, catches up after the app was closed, and
//  predicts the future (for reminder notifications).
//

import Foundation

// MARK: - Life stages

enum DinoStage: String, Codable, CaseIterable {
    case egg, baby1, baby2, rookie, champion, ultimate

    var order: Int {
        switch self {
        case .egg: return 0
        case .baby1: return 1
        case .baby2: return 2
        case .rookie: return 3
        case .champion: return 4
        case .ultimate: return 5
        }
    }

    var displayName: String {
        switch self {
        case .egg: return "EGG"
        case .baby1: return "BABY I"
        case .baby2: return "BABY II"
        case .rookie: return "ROOKIE"
        case .champion: return "CHAMPION"
        case .ultimate: return "ULTIMATE"
        }
    }
}

// MARK: - The dinosaur roster

/// What kind of egg a new dino came from. Every new egg rolls the dice.
enum EggKind: String, Codable {
    case normal   // 88%: care, training and battles decide
    case rare     // 10%: striped egg, becomes a random Ultimate (no battles needed)
    case spiky    //  2%: spiky egg, Dino Kid -> T-Rex or Ultimate Raptor

    /// 2% spiky, 10% rare, otherwise normal. `roll` is 0..<1.
    static func roll(_ roll: Double = Double.random(in: 0..<1)) -> EggKind {
        if roll < Tuning.spikyEggChance { return .spiky }
        if roll < Tuning.spikyEggChance + Tuning.rareEggChance { return .rare }
        return .normal
    }
}

enum DinoSpecies: String, Codable, CaseIterable {
    // NOTE: battle codes store the index of each case, so new cases go at the END.
    // Rookie (velociraptor = the old rookie, kept so older saves still load)
    case velociraptor, compsognathus
    // Champion
    case triceratops, stegosaurus, pteranodon, parasaurolophus, dilophosaurus
    // Ultimate (T-Rex now only hatches from the spiky egg)
    case tRex = "t_rex", spinosaurus, brachiosaurus, ankylosaurus, pachycephalosaurus
    // Added later
    case oviraptor                     // Rookie
    case styracosaurus                 // Ultimate (from Triceratops)
    case megaRaptor = "mega_raptor"    // Ultimate Raptor, spiky egg only

    var displayName: String {
        switch self {
        case .velociraptor: return "RAPTOR"
        case .compsognathus: return "COMPY"
        case .triceratops: return "TRICERATOPS"
        case .stegosaurus: return "STEGOSAURUS"
        case .pteranodon: return "PTERANODON"
        case .parasaurolophus: return "PARASAUR"
        case .dilophosaurus: return "DILOPHO"
        case .tRex: return "T-REX"
        case .spinosaurus: return "SPINOSAURUS"
        case .brachiosaurus: return "BRACHIO"
        case .ankylosaurus: return "ANKYLOSAUR"
        case .pachycephalosaurus: return "PACHY"
        case .oviraptor: return "OVIRAPTOR"
        case .styracosaurus: return "STYRACO"
        case .megaRaptor: return "RAPTOR"
        }
    }

    var stage: DinoStage {
        switch self {
        case .velociraptor, .compsognathus, .oviraptor: return .rookie
        case .triceratops, .stegosaurus, .pteranodon, .parasaurolophus, .dilophosaurus: return .champion
        default: return .ultimate
        }
    }

    /// T-Rex and Ultimate Raptor: only from the spiky egg, the best of the best.
    var isLegendary: Bool { self == .tRex || self == .megaRaptor }


    /// Dinos you can meet as CPU rivals (normal play only).
    static func roster(for stage: DinoStage) -> [DinoSpecies] {
        allCases.filter { $0.stage == stage && !$0.isLegendary && $0 != .velociraptor }
    }

    /// The Ultimates a rare egg can turn into (25% each).
    static let rareUltimates: [DinoSpecies] = [.styracosaurus, .spinosaurus, .ankylosaurus, .brachiosaurus]
}

// MARK: - Tuning (all times are GAME minutes; game speed multiplies real time)

enum Tuning {
    /// How long each stage lasts before it evolves.
    static func stageDuration(_ s: DinoStage) -> Double {
        switch s {
        case .egg: return 10
        case .baby1: return 10
        case .baby2: return 6 * 60
        case .rookie: return 24 * 60
        case .champion: return 36 * 60
        case .ultimate: return .infinity
        }
    }

    /// Minutes for one hunger heart (and one strength heart) to drain.
    static func drainInterval(_ s: DinoStage) -> Double {
        switch s {
        case .egg: return .infinity
        case .baby1: return 3
        case .baby2: return 30
        case .rookie: return 48
        case .champion: return 59
        case .ultimate: return 69
        }
    }

    static func poopInterval(_ s: DinoStage) -> Double {
        switch s {
        case .egg: return .infinity
        case .baby1: return 3
        case .baby2: return 60
        default: return 120
        }
    }

    /// Bedtime / wake-up hours on the real clock. Baby I naps instead of sleeping.
    /// The dino only actually sleeps if the light is off (see Pet.isAsleep).
    static func sleepHours(_ s: DinoStage) -> (sleep: Int, wake: Int)? {
        switch s {
        case .egg, .baby1: return nil
        case .baby2, .rookie: return (20, 8)
        case .champion: return (21, 8)
        case .ultimate: return (22, 8)
        }
    }

    static func baseWeight(_ s: DinoStage) -> Int {
        switch s {
        case .egg, .baby1: return 5
        case .baby2: return 10
        case .rookie: return 20
        case .champion: return 30
        case .ultimate: return 40
        }
    }

    static func battlePower(_ s: DinoStage) -> Double {
        switch s {
        case .rookie: return 30
        case .champion: return 55
        case .ultimate: return 80
        default: return 15
        }
    }

    static let callTimeout: Double = 10        // ignore a call this long -> care mistake
    static let lightsGrace: Double = 30        // lights left on while asleep
    static let maxPoops = 8                    // this many poops -> sick
    static let starveDeath: Double = 12 * 60   // hunger empty this long -> dies
    static let sickDeath: Double = 12 * 60     // sick untreated this long -> dies
    static let maxInjuries = 20                // lifetime injuries/sicknesses -> dies
    static let trainingsPerEffort = 4
    static let bigTrainingGoal = 16            // trainings needed for the best evolutions
    static let ultimateBattles = 15
    static let ultimateWinRate = 0.8
    static let sukamonMistakes = 6
    static let rareEggChance = 0.10
    static let spikyEggChance = 0.02
    static let legendaryBonus: Double = 15     // T-Rex / Ultimate Raptor attack and defense
    static let rarePrizeBonus: Double = 8      // a rare egg's Ultimate (not Pachy)

    /// Extra attack AND defense in battle: spiky-egg dinos +15, a rare egg's Ultimate +8.
    static func battleBonus(species: DinoSpecies, rarePrize: Bool) -> Double {
        if species.isLegendary { return legendaryBonus }
        return rarePrize ? rarePrizeBonus : 0
    }
    /// "Start new egg" can be used once per this many days (unless your dino died).
    static let newEggCooldownDays: Double = 14
    /// Safety net: if a deadly problem builds up while the app is closed, the dino
    /// survives and you get at least this many game minutes after you come back.
    static let comebackGrace: Double = 60
}

// MARK: - Events the simulation reports back

enum PetEvent: Equatable {
    case hatched, evolved, call, careMistake, poop, sick, fellAsleep, wokeUp, died
}

/// A "call" (the attention icon). Ignoring it for `Tuning.callTimeout` minutes = 1 care mistake.
struct CallTimer: Codable, Equatable {
    var minutes: Double? = nil
    var expired = false

    var isCalling: Bool { minutes != nil }

    /// Returns (callStarted, mistakeMade)
    mutating func tick(needsCare: Bool) -> (Bool, Bool) {
        if !needsCare {
            minutes = nil
            expired = false
            return (false, false)
        }
        if expired { return (false, false) }
        guard let m = minutes else {
            minutes = 0
            return (true, false)
        }
        let next = m + 1
        if next >= Tuning.callTimeout {
            minutes = nil
            expired = true
            return (false, true)
        }
        minutes = next
        return (false, false)
    }
}

// MARK: - The pet

struct Pet: Codable, Equatable {
    var generation = 1
    var stage: DinoStage = .egg
    var species: DinoSpecies = .oviraptor
    /// Optional so older saves still load (missing = normal egg).
    var eggKindSaved: EggKind? = nil
    /// The Ultimate waiting inside a rare or spiky egg, picked when the egg is laid.
    var prize: DinoSpecies? = nil
    var ageMinutes: Double = 0
    var stageMinutes: Double = 0
    var eggProgress: Double = 0

    var weight = 5
    var hunger = 0          // hearts 0...4
    var strength = 0        // hearts 0...4
    var hungerClock: Double = 0
    var strengthClock: Double = 0
    var poopClock: Double = 0
    var poops = 0

    var isSick = false
    var sickMinutes: Double = 0
    var injuries = 0
    var starvingMinutes: Double = 0

    var careMistakes = 0
    var hungerCall = CallTimer()
    var strengthCall = CallTimer()
    var lightsCall: Double? = nil
    var sleepMistakeTonight = false
    var lightsOn = true
    var wasAsleep = false

    var trainings = 0       // this stage
    var effort = 0          // hearts 0...4
    var effortProgress = 0  // trainings toward next effort heart
    var battles = 0         // this stage
    var wins = 0
    var totalBattles = 0
    var totalWins = 0

    var isDead = false
    var deathReason = ""
    var lastUpdate = Date()

    // MARK: derived

    var winRate: Double { battles == 0 ? 0 : Double(wins) / Double(battles) }
    var totalWinRate: Double { totalBattles == 0 ? 0 : Double(totalWins) / Double(totalBattles) }
    var ageDays: Int { Int(ageMinutes / (24 * 60)) }
    var isCalling: Bool { hungerCall.isCalling || strengthCall.isCalling }
    var eggKind: EggKind { eggKindSaved ?? .normal }

    /// A rare egg that reached its Ultimate (Pachy doesn't count): a little stronger in battle.
    var isRarePrize: Bool { eggKind == .rare && stage == .ultimate && species != .pachycephalosaurus }

    /// Extra attack and defense in battle (see Tuning.battleBonus).
    var battleBonus: Double { Tuning.battleBonus(species: species, rarePrize: isRarePrize) }

    /// A brand-new egg of the given kind. Rare and spiky eggs pick their prize now.
    static func newEgg(generation: Int, kind: EggKind) -> Pet {
        var p = Pet()
        p.generation = generation
        p.eggKindSaved = kind
        switch kind {
        case .normal: p.prize = nil
        case .rare: p.prize = DinoSpecies.rareUltimates.randomElement()
        case .spiky: p.prize = Bool.random() ? .tRex : .megaRaptor
        }
        p.lastUpdate = Date()
        return p
    }

    var formName: String {
        switch stage {
        case .egg:
            switch eggKind {
            case .normal: return "EGG"
            case .rare: return "RARE EGG"
            case .spiky: return "SPIKY EGG"
            }
        case .baby1: return "HATCHLING"
        case .baby2: return "DINO KID"
        default: return species.displayName
        }
    }

    /// Key into PixelArt.creatures
    var spriteKey: String {
        switch stage {
        case .egg:
            switch eggKind {
            case .normal: return "egg"
            case .rare: return "egg_rare"
            case .spiky: return "egg_spiky"
            }
        case .baby1: return "baby1"
        case .baby2: return "baby2"
        default: return species.rawValue
        }
    }

    /// Real-clock bedtime for this stage (e.g. 8pm-8am). Baby I has none.
    func isBedtime(at date: Date) -> Bool {
        guard !isDead, let hours = Tuning.sleepHours(stage) else { return false }
        let hour = Calendar.current.component(.hour, from: date)
        return hour >= hours.sleep || hour < hours.wake
    }

    /// Sleeping = bedtime AND the light is off. Turn the light on to wake it up.
    func isAsleep(at date: Date) -> Bool {
        isBedtime(at: date) && !lightsOn
    }

    // MARK: simulation

    /// Advance the pet by one game minute. `date` is the real-world time of that minute
    /// (used for bedtime).
    /// `allowDeath: false` is used while the app was closed: the dino can get sick
    /// and hungry, but it waits for you instead of dying.
    /// `autoLights: true` = the app is closed, so the light turns itself off at bedtime.
    mutating func simulateMinute(at date: Date, allowDeath: Bool = true, autoLights: Bool = false) -> [PetEvent] {
        var events: [PetEvent] = []
        if isDead { return events }

        ageMinutes += 1
        stageMinutes += 1

        if stage == .egg {
            eggProgress += 10
            if eggProgress >= 100 {
                hatch()
                events.append(.hatched)
            }
            return events
        }

        // Sickness always progresses, even while sleeping.
        if isSick {
            sickMinutes += 1
            if sickMinutes >= Tuning.sickDeath {
                if allowDeath {
                    die("SICKNESS")
                    events.append(.died)
                    return events
                }
                sickMinutes = Tuning.sickDeath - Tuning.comebackGrace
            }
        }

        // Bedtime hours come from the real clock, but the LIGHT decides:
        // light on = awake (you can play any time), light off at bedtime = asleep.
        let bedtime = isBedtime(at: date)
        if bedtime != wasAsleep {            // `wasAsleep` remembers "was it bedtime"
            wasAsleep = bedtime
            if bedtime {
                events.append(.fellAsleep)
            } else {
                lightsOn = true                // morning: lights come back on
                events.append(.wokeUp)
            }
        }
        // While you're away at bedtime, the light switches itself off.
        if autoLights && bedtime && lightsOn {
            lightsOn = false
        }
        if bedtime && !lightsOn {
            return events                      // asleep: hunger, strength and poop pause
        }

        // --- Awake: hearts drain, poop happens, calls tick ---
        let interval = Tuning.drainInterval(stage)
        hungerClock += 1
        if hungerClock >= interval {
            hungerClock = 0
            hunger = max(0, hunger - 1)
        }
        strengthClock += 1
        if strengthClock >= interval {
            strengthClock = 0
            strength = max(0, strength - 1)
        }

        poopClock += 1
        if poopClock >= Tuning.poopInterval(stage) {
            poopClock = 0
            poops = min(Tuning.maxPoops, poops + 1)
            events.append(.poop)
            if poops >= Tuning.maxPoops && !isSick {
                makeSick(allowDeath: allowDeath)
                events.append(.sick)
                if isDead {
                    events.append(.died)
                    return events
                }
            }
        }

        let h = hungerCall.tick(needsCare: hunger == 0)
        if h.0 { events.append(.call) }
        if h.1 { careMistakes += 1; events.append(.careMistake) }

        let s = strengthCall.tick(needsCare: strength == 0)
        if s.0 { events.append(.call) }
        if s.1 { careMistakes += 1; events.append(.careMistake) }

        if hunger == 0 {
            starvingMinutes += 1
            if starvingMinutes >= Tuning.starveDeath {
                if allowDeath {
                    die("HUNGER")
                    events.append(.died)
                    return events
                }
                starvingMinutes = Tuning.starveDeath - Tuning.comebackGrace
            }
        } else {
            starvingMinutes = 0
        }

        if isDead { return events }

        // Evolution
        if stageMinutes >= Tuning.stageDuration(stage) {
            if tryEvolve() { events.append(.evolved) }
        }
        return events
    }

    // MARK: life events

    mutating func hatch() {
        stage = .baby1
        species = .oviraptor
        stageMinutes = 0
        eggProgress = 100
        weight = Tuning.baseWeight(.baby1)
        hunger = 0
        strength = 0
        hungerClock = 0
        strengthClock = 0
        poopClock = 0
        wasAsleep = false
        lightsOn = true
    }

    mutating func makeSick(allowDeath: Bool = true) {
        isSick = true
        sickMinutes = 0
        injuries += 1
        if injuries >= Tuning.maxInjuries {
            if allowDeath {
                die("INJURIES")
            } else {
                injuries = Tuning.maxInjuries - 1
            }
        }
    }

    mutating func die(_ reason: String) {
        isDead = true
        deathReason = reason
        hungerCall = CallTimer()
        strengthCall = CallTimer()
        lightsCall = nil
    }

    /// The classic branching evolution chart. Returns true if the pet changed form.
    mutating func tryEvolve() -> Bool {
        switch stage {
        case .egg:
            hatch()
            return true
        case .baby1:
            setForm(.baby2, .oviraptor)
        case .baby2:
            if eggKind == .spiky {
                // The rarest egg: straight to T-Rex or Ultimate Raptor. Never a Pachy.
                setForm(.ultimate, prize ?? .tRex)
            } else {
                setForm(.rookie, careMistakes <= 3 ? .oviraptor : .compsognathus)
            }
        case .rookie:
            setForm(.champion, championForm())
        case .champion:
            if careMistakes >= Tuning.sukamonMistakes {
                setForm(.ultimate, .pachycephalosaurus)   // neglected (normal or rare egg)
            } else if eggKind == .rare {
                // Rare egg + good care: its random Ultimate, no battles needed.
                setForm(.ultimate, prize ?? DinoSpecies.rareUltimates[0])
            } else if battles >= Tuning.ultimateBattles && winRate >= Tuning.ultimateWinRate {
                setForm(.ultimate, ultimateForm())
            } else {
                return false   // stays Champion until it proves itself in battle
            }
        case .ultimate:
            return false
        }
        return true
    }

    func championForm() -> DinoSpecies {
        let trainedHard = trainings >= Tuning.bigTrainingGoal
        if species == .oviraptor || species == .velociraptor {
            if careMistakes <= 3 { return trainedHard ? .triceratops : .pteranodon }
            return trainedHard ? .stegosaurus : .parasaurolophus
        }
        // Compsognathus line
        if trainedHard && careMistakes <= 5 { return .dilophosaurus }
        if trainings >= Tuning.bigTrainingGoal / 2 { return .stegosaurus }
        return .parasaurolophus
    }

    func ultimateForm() -> DinoSpecies {
        switch species {
        case .triceratops: return .styracosaurus
        case .pteranodon, .dilophosaurus: return .spinosaurus
        case .stegosaurus: return .ankylosaurus
        case .parasaurolophus: return .brachiosaurus
        default: return .styracosaurus
        }
    }

    private mutating func setForm(_ newStage: DinoStage, _ newSpecies: DinoSpecies) {
        stage = newStage
        species = newSpecies
        stageMinutes = 0
        weight = Tuning.baseWeight(newStage)
        careMistakes = 0
        trainings = 0
        battles = 0
        wins = 0
    }

    // MARK: care actions (pure)

    mutating func applyTraining(success: Bool, weightLoss: Int) {
        trainings += 1
        effortProgress += 1
        if effortProgress >= Tuning.trainingsPerEffort {
            effortProgress = 0
            effort = min(4, effort + 1)
        }
        weight = max(5, weight - weightLoss)
        if success { strength = min(4, strength + 1) }
    }
}
