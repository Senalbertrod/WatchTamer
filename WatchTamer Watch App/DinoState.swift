//
//  DinoState.swift
//  WatchTamer Watch App
//
//  The live game: owns the Pet, runs the clock, handles every button,
//  runs battles and training, counts steps, saves, and schedules reminders.
//

import SwiftUI
import WatchKit
import Combine
import CoreMotion
import UserNotifications

// MARK: - UI enums

enum Screen: Equatable {
    case home
    case status(Int)
    case feed
    case train
    case trainTap
    case walk
    case battleMenu
    case friendCode
    case battle
}

enum FoodKind: Equatable { case meat, protein }

enum HomeAnim: Equatable {
    case none
    case eating(FoodKind, Int)   // bite 0...3
    case refusing
    case flushing
    case evolving
    case healing
    case walkRep
}

enum BattlePhase: Equatable {
    case docking(Int)
    case fighting
    case result(Bool)
}

enum PauseReason: String, Codable {
    case daycare   // the player paused
    case charger   // paused automatically because the watch was charging
}

enum MenuItem: CaseIterable {
    case status, feed, train, battle, flush, lights, medical, call

    var symbol: String {
        switch self {
        case .status: return "scalemass.fill"
        case .feed: return "fork.knife"
        case .train: return "dumbbell.fill"
        case .battle: return "bolt.fill"
        case .flush: return "water.waves"
        case .lights: return "lightbulb.fill"
        case .medical: return "cross.case.fill"
        case .call: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Player / device settings (not tied to one pet)

struct Tamer: Codable, Equatable {
    var speed: Double = 1            // 1 = classic real-time, 10 = fast
    var walkTraining = true
    var stepsPerRep = 250
    var notifications = true
    // Per-type switches (optional so older saves still load; nil = on)
    var notifyHungerSetting: Bool? = nil
    var notifyPoopSetting: Bool? = nil
    var notifySickSetting: Bool? = nil

    var notifyHunger: Bool {
        get { notifyHungerSetting ?? true }
        set { notifyHungerSetting = newValue }
    }
    var notifyPoop: Bool {
        get { notifyPoopSetting ?? true }
        set { notifyPoopSetting = newValue }
    }
    var notifySick: Bool {
        get { notifySickSetting ?? true }
        set { notifySickSetting = newValue }
    }
    var nightScreen = false          // false = classic grey-green LCD, true = black + neon

    var stepAnchor = Date()
    var stepsSinceAnchor = 0
    var lastStepQuery: Date? = nil
    var stepBank = 0                 // steps toward the next walk rep
    var lifetimeSteps = 0
    var walkReps = 0

    var myBattleCode: String? = nil  // snapshot shown to friends; renewed after each battle

    var pausedReason: PauseReason? = nil
    var pauseWhenChargingSetting: Bool? = nil
    var pauseWhenCharging: Bool {
        get { pauseWhenChargingSetting ?? true }
        set { pauseWhenChargingSetting = newValue }
    }
}

// MARK: - DinoState

final class DinoState: ObservableObject {
    @Published var pet: Pet
    @Published var tamer: Tamer

    @Published var screen: Screen = .home
    @Published var anim: HomeAnim = .none
    @Published var toast: String? = nil
    @Published var flashOn = false

    // Tap training
    @Published var trainMeter: Double = 0
    @Published var trainTimeLeft: Double = 5
    @Published var trainOver = false
    @Published var trainSuccess = false

    // Battle
    @Published var battlePhase: BattlePhase = .docking(0)
    @Published var enemySpecies: DinoSpecies = .triceratops
    @Published var playerLives = 3
    @Published var enemyLives = 3
    @Published var shotActive = false
    @Published var shotFromPlayer = true
    @Published var shotHit = true
    @Published var shotProgress: Double = 0
    @Published var playerShake = false
    @Published var enemyShake = false
    @Published var battleText = ""
    @Published var isFriendBattle = false

    private var ticker: AnyCancellable?
    private var tickCount = 0
    private var toastTask: Task<Void, Never>?
    private var trainTask: Task<Void, Never>?
    private let pedometer = CMPedometer()

    private let petKey = "watch_tamer_v3_pet"
    private let tamerKey = "watch_tamer_v3_tamer"

    init() {
        pet = DinoState.load(Pet.self, key: "watch_tamer_v3_pet") ?? Pet()
        tamer = DinoState.load(Tamer.self, key: "watch_tamer_v3_tamer") ?? Tamer()
        catchUp()
        WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
        requestNotificationPermission()
        refreshSteps()
    }

    // MARK: - Derived

    var isAsleep: Bool { pet.stage != .egg && pet.isAsleep(at: Date()) }
    var secondsPerGameMinute: Double { 60.0 / max(tamer.speed, 1) }

    // MARK: - Persistence

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func save() {
        if let data = try? JSONEncoder().encode(pet) {
            UserDefaults.standard.set(data, forKey: petKey)
        }
        if let data = try? JSONEncoder().encode(tamer) {
            UserDefaults.standard.set(data, forKey: tamerKey)
        }
    }

    // MARK: - Clock

    private func tick() {
        catchUp()
        tickCount += 1
        if tickCount % 10 == 0 { checkCharger() }
        if tickCount % 15 == 0 { refreshSteps() }
        if tickCount % 30 == 0 { save() }
    }

    /// Runs every whole game-minute that has passed since the last update.
    func catchUp() {
        if isPaused { return }   // frozen: no time passes in daycare
        let now = Date()
        let secPerMin = secondsPerGameMinute
        let elapsed = now.timeIntervalSince(pet.lastUpdate)
        if elapsed < 0 {
            pet.lastUpdate = now
            return
        }
        let minutes = Int(elapsed / secPerMin)
        guard minutes > 0 else { return }
        // More than a couple of minutes = the app was closed. The dino can't die
        // while you weren't looking; it waits for you instead.
        let live = minutes <= 2

        var p = pet
        var events: [PetEvent] = []
        let cap = 20_000
        var t = p.lastUpdate
        for _ in 0..<min(minutes, cap) {
            t = t.addingTimeInterval(secPerMin)
            events.append(contentsOf: p.simulateMinute(at: t, allowDeath: live, autoLights: !live))
            if p.isDead { break }
        }
        if p.isDead || minutes > cap {
            p.lastUpdate = now
        } else {
            p.lastUpdate = p.lastUpdate.addingTimeInterval(Double(minutes) * secPerMin)
        }
        pet = p
        handle(events, live: live)
        if !events.isEmpty { save() }
    }

    private func handle(_ events: [PetEvent], live: Bool) {
        if events.contains(.died) {
            screen = .home
            anim = .none
            haptic(.failure)
            return
        }
        if events.contains(.hatched) {
            haptic(.success)
            showToast("HATCHED!")
        }
        if events.contains(.evolved) {
            screen = .home
            playEvolution()
        }
        guard live else { return }
        if events.contains(.call) { haptic(.notification) }
        if events.contains(.sick) { haptic(.failure) }
        if events.contains(.fellAsleep) { showToast("BEDTIME!") }
        if events.contains(.wokeUp) { showToast("GOOD MORNING") }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            checkCharger()
            catchUp()
            refreshSteps()
            if isAsleep && !isPaused { showToast("ZZZ... TAP 💡 TO WAKE") }
        case .inactive:
            // Wrist lowered for a moment: just save.
            checkCharger()
            catchUp()
            save()
            scheduleCareReminder()
        case .background:
            // Really left the game. During bedtime, the light goes off and the dino sleeps.
            checkCharger()
            catchUp()
            if !pet.isDead && pet.lightsOn && pet.isBedtime(at: Date()) {
                pet.lightsOn = false
            }
            save()
            scheduleCareReminder()
        @unknown default:
            break
        }
    }

    // MARK: - Pause (daycare) & charger

    var isPaused: Bool { tamer.pausedReason != nil }

    var isCharging: Bool {
        let s = WKInterfaceDevice.current().batteryState
        return s == .charging || s == .full
    }

    /// Freeze time completely. Needs, poop, sickness and evolution all stop.
    func pause(_ reason: PauseReason) {
        guard !pet.isDead, !isPaused else { return }
        if screen == .battle || screen == .trainTap { return }
        catchUp()                       // settle everything up to this moment
        tamer.pausedReason = reason
        screen = .home
        save()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        haptic(.stop)
        showToast(reason == .charger ? "CHARGING..." : "PAUSED")
    }

    /// Unfreeze. The paused time is skipped, as if it never happened.
    func resume() {
        guard isPaused else { return }
        tamer.pausedReason = nil
        pet.lastUpdate = Date()
        save()
        haptic(.start)
        showToast("WELCOME BACK!")
    }

    /// Auto-pause while on the charger, auto-resume once unplugged.
    func checkCharger() {
        if isCharging {
            if tamer.pauseWhenCharging && !isPaused { pause(.charger) }
        } else if tamer.pausedReason == .charger {
            resume()
        }
    }

    func setPauseWhenCharging(_ on: Bool) {
        tamer.pauseWhenCharging = on
        if !on && tamer.pausedReason == .charger { resume() }
        save()
        checkCharger()
    }

    // MARK: - Helpers

    func haptic(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }

    func showToast(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(1.6))
            if !Task.isCancelled { toast = nil }
        }
    }

    /// Common checks before an action. Shows a message and returns false if not allowed.
    private func canAct(allowSick: Bool = true) -> Bool {
        if pet.isDead { return false }
        if isPaused { showToast("PAUSED"); return false }
        if pet.stage == .egg { showToast("TAP THE EGG"); return false }
        if anim != .none { return false }
        if isAsleep { showToast("ZZZ... TAP 💡 TO WAKE"); haptic(.failure); return false }
        if !allowSick && pet.isSick { showToast("SICK! MEDS"); haptic(.failure); return false }
        return true
    }

    // MARK: - Menu

    func select(_ item: MenuItem) {
        guard !pet.isDead else { return }
        if isPaused { showToast("TAP TO RESUME"); haptic(.click); return }
        if screen == .battle || screen == .trainTap { return }
        haptic(.click)
        switch item {
        case .status:
            if pet.stage == .egg { showToast("TAP THE EGG"); return }
            if case .status = screen { screen = .home } else { screen = .status(0) }
        case .feed:
            if screen == .feed { screen = .home; return }
            if canAct() { screen = .feed }
        case .train:
            if screen == .train { screen = .home; return }
            if canAct() { screen = .train }
        case .battle:
            if screen == .battleMenu || screen == .friendCode { screen = .home; return }
            screen = .home
            if battleReady() { screen = .battleMenu }
        case .flush:
            screen = .home
            flush()
        case .lights:
            screen = .home
            toggleLights()
        case .medical:
            screen = .home
            giveMedicine()
        case .call:
            if pet.stage != .egg { screen = .status(0) }
        }
    }

    func goHome() {
        if screen == .battle || screen == .trainTap { return }
        screen = .home
    }

    func nextStatusPage() {
        if case .status(let page) = screen {
            screen = page >= 5 ? .home : .status(page + 1)
            haptic(.click)
        }
    }

    // MARK: - Egg

    func tapEgg() {
        guard pet.stage == .egg, !pet.isDead else { return }
        haptic(.click)
        pet.eggProgress += 10
        if pet.eggProgress >= 100 {
            pet.hatch()
            handle([.hatched], live: true)
            save()
        }
    }

    // MARK: - Feeding

    func feed(_ kind: FoodKind) {
        screen = .home
        guard canAct() else { return }
        if kind == .meat && pet.hunger >= 4 {
            anim = .refusing
            showToast("FULL!")
            haptic(.failure)
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                anim = .none
            }
            return
        }
        anim = .eating(kind, 0)
        haptic(.start)
        Task {
            for bite in 1...3 {
                try? await Task.sleep(for: .milliseconds(450))
                anim = .eating(kind, bite)
                haptic(.click)
            }
            try? await Task.sleep(for: .milliseconds(300))
            switch kind {
            case .meat:
                pet.hunger = min(4, pet.hunger + 1)
                pet.weight = min(99, pet.weight + 1)
            case .protein:
                pet.strength = min(4, pet.strength + 1)
                pet.weight = min(99, pet.weight + 2)
            }
            anim = .none
            save()
        }
    }

    // MARK: - Flush / Lights / Medicine

    func flush() {
        guard canAct() else { return }
        if pet.poops == 0 { showToast("ALL CLEAN"); return }
        anim = .flushing
        haptic(.start)
        Task {
            try? await Task.sleep(for: .seconds(1.3))
            pet.poops = 0
            anim = .none
            haptic(.success)
            save()
        }
    }

    func toggleLights() {
        guard !pet.isDead else { return }
        catchUp()                       // settle time with the old light setting first
        pet.lightsOn.toggle()
        if pet.stage != .egg && pet.isBedtime(at: Date()) {
            showToast(pet.lightsOn ? "WOKE UP!" : "GOOD NIGHT")
        }
        save()
    }

    func giveMedicine() {
        guard !pet.isDead, pet.stage != .egg, anim == .none else { return }
        if !pet.isSick { showToast("HEALTHY!"); return }
        pet.isSick = false
        pet.sickMinutes = 0
        anim = .healing
        haptic(.success)
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            anim = .none
            save()
        }
    }

    // MARK: - Evolution flash

    private func playEvolution() {
        anim = .evolving
        haptic(.success)
        Task {
            for _ in 0..<10 {
                flashOn.toggle()
                try? await Task.sleep(for: .milliseconds(160))
            }
            flashOn = false
            anim = .none
            showToast(pet.formName + "!")
        }
    }

    // MARK: - Tap training (button mash)

    func startTapTraining() {
        guard canAct(allowSick: false) else { screen = .home; return }
        screen = .trainTap
        trainMeter = 0
        trainTimeLeft = 5
        trainOver = false
        trainSuccess = false
        haptic(.start)
        trainTask?.cancel()
        trainTask = Task {
            while trainTimeLeft > 0 && !trainOver {
                try? await Task.sleep(for: .milliseconds(50))
                if Task.isCancelled { return }
                trainTimeLeft = max(0, trainTimeLeft - 0.05)
                trainMeter = max(0, trainMeter - 0.5)
            }
            if !trainOver { finishTraining(success: false) }
        }
    }

    func mash() {
        guard screen == .trainTap, !trainOver else { return }
        trainMeter = min(100, trainMeter + 9)
        haptic(.click)
        if trainMeter >= 100 { finishTraining(success: true) }
    }

    private func finishTraining(success: Bool) {
        trainOver = true
        trainSuccess = success
        pet.applyTraining(success: success, weightLoss: 2)
        haptic(success ? .success : .failure)
        save()
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            if screen == .trainTap { screen = .home }
        }
    }

    // MARK: - Walk training (pedometer)

    func openWalk() {
        screen = .walk
        refreshSteps()
    }

    func refreshSteps() {
        guard tamer.walkTraining, CMPedometer.isStepCountingAvailable() else { return }
        let now = Date()
        // Move the anchor forward every few hours so queries stay small.
        if now.timeIntervalSince(tamer.stepAnchor) > 3 * 3600, let last = tamer.lastStepQuery {
            tamer.stepAnchor = last
            tamer.stepsSinceAnchor = 0
        }
        // The pedometer only remembers 7 days.
        if now.timeIntervalSince(tamer.stepAnchor) > 6 * 86_400 {
            tamer.stepAnchor = now.addingTimeInterval(-6 * 86_400)
            tamer.stepsSinceAnchor = 0
        }
        let anchor = tamer.stepAnchor
        // Core Motion calls back on a background queue, so hop to the main actor.
        pedometer.queryPedometerData(from: anchor, to: now) { @Sendable data, error in
            guard error == nil, let total = data?.numberOfSteps.intValue else { return }
            Task { @MainActor in
                self.receiveSteps(total: total, anchor: anchor, end: now)
            }
        }
    }

    private func receiveSteps(total: Int, anchor: Date, end: Date) {
        guard anchor == tamer.stepAnchor else { return }
        tamer.lastStepQuery = end
        let newSteps = total - tamer.stepsSinceAnchor
        guard newSteps > 0 else { return }
        tamer.stepsSinceAnchor = total
        creditSteps(newSteps)
    }

    /// Walking turns into training. Also used by the debug "+steps" button.
    func creditSteps(_ steps: Int) {
        guard steps > 0 else { return }
        tamer.lifetimeSteps += steps
        if pet.isDead || isPaused { save(); return }

        if pet.stage == .egg {
            pet.eggProgress += Double(steps) / 3.0   // ~30 steps = one tap
            if pet.eggProgress >= 100 {
                pet.hatch()
                handle([.hatched], live: true)
            }
            save()
            return
        }

        tamer.stepBank += steps
        let perRep = max(50, tamer.stepsPerRep)
        var reps = 0
        while tamer.stepBank >= perRep && reps < 20 {
            tamer.stepBank -= perRep
            reps += 1
            pet.applyTraining(success: true, weightLoss: 1)
        }
        if reps == 20 { tamer.stepBank = min(tamer.stepBank, perRep - 1) }
        if reps > 0 {
            tamer.walkReps += reps
            haptic(.success)
            showToast(reps == 1 ? "WALK TRAINING!" : "WALK x\(reps)!")
            if screen == .home && anim == .none {
                anim = .walkRep
                Task {
                    try? await Task.sleep(for: .seconds(1.4))
                    if anim == .walkRep { anim = .none }
                }
            }
        }
        save()
    }

    // MARK: - Battle

    /// Checks the classic battle rules and explains why not.
    func battleReady() -> Bool {
        guard canAct(allowSick: false) else { return false }
        if pet.stage.order < DinoStage.rookie.order { showToast("TOO YOUNG"); haptic(.failure); return false }
        if pet.hunger == 0 || pet.strength == 0 { showToast("TOO WEAK"); haptic(.failure); return false }
        return true
    }

    /// Fight a computer rival.
    func startBattle() {
        guard battleReady() else { screen = .home; return }
        let rivals = DinoSpecies.roster(for: pet.stage).filter { $0 != pet.species }
        let rival = rivals.randomElement() ?? pet.species
        isFriendBattle = false
        screen = .battle
        Task { await runBattle(rival: rival, plan: nil) }
    }

    // MARK: - Friend battles (battle codes)

    /// This watch's code. It stays the same until a battle is fought,
    /// so your friend can type it in without it changing.
    var myBattleCode: BattleCode {
        if let text = tamer.myBattleCode, let code = BattleCode.decode(text), code.species == pet.species {
            return code
        }
        let code = BattleCode(pet: pet)
        tamer.myBattleCode = code.text
        save()
        return code
    }

    func openFriendCode() {
        guard battleReady() else { screen = .home; return }
        _ = myBattleCode
        screen = .friendCode
    }

    func newBattleCode() {
        tamer.myBattleCode = nil
        _ = myBattleCode
        haptic(.click)
    }

    func startFriendBattle(code input: String) {
        guard let theirs = BattleCode.decode(input) else {
            showToast("BAD CODE")
            haptic(.failure)
            return
        }
        let mine = myBattleCode
        if theirs == mine {
            showToast("THAT'S YOU!")
            haptic(.failure)
            return
        }
        guard battleReady() else { screen = .home; return }
        isFriendBattle = true
        screen = .battle
        let plan = BattleCode.duel(mine: mine, theirs: theirs)
        Task { await runBattle(rival: theirs.species, plan: plan) }
    }

    private func playerPower() -> Double {
        Tuning.battlePower(pet.stage)
            + Double(pet.strength) * 5
            + Double(pet.effort) * 5
            + Double(min(pet.trainings, 30)) * 0.5
    }

    /// `plan` = pre-decided shots for friend battles; nil = roll dice live against the CPU.
    private func runBattle(rival: DinoSpecies, plan: [BattleCode.Shot]?) async {
        battlePhase = .docking(0)
        playerLives = 3
        enemyLives = 3
        shotActive = false
        battleText = ""
        enemySpecies = rival

        for step in 1...3 {
            try? await Task.sleep(for: .milliseconds(650))
            battlePhase = .docking(step)
            haptic(.click)
        }
        try? await Task.sleep(for: .milliseconds(600))

        battlePhase = .fighting
        haptic(.start)
        let mine = playerPower()
        let theirs = Tuning.battlePower(rival.stage) + Double.random(in: 10...38)
        let myHit = min(0.85, max(0.25, 0.5 + (mine - theirs) / 100))
        let theirHit = min(0.8, max(0.2, 0.5 + (theirs - mine) / 100))

        if let plan {
            for shot in plan where playerLives > 0 && enemyLives > 0 {
                await fire(fromPlayer: shot.fromPlayer, hit: shot.hit)
            }
        } else {
            while playerLives > 0 && enemyLives > 0 {
                await fire(fromPlayer: true, hit: Double.random(in: 0..<1) < myHit)
                if enemyLives == 0 { break }
                await fire(fromPlayer: false, hit: Double.random(in: 0..<1) < theirHit)
            }
        }

        let won = enemyLives == 0
        battlePhase = .result(won)
        pet.battles += 1
        pet.totalBattles += 1
        if won {
            pet.wins += 1
            pet.totalWins += 1
        }
        pet.strength = max(0, pet.strength - 1)
        pet.weight = max(5, pet.weight - 4)
        battleText = won ? "YOU WIN!" : "YOU LOSE..."
        if Double.random(in: 0..<1) < (won ? 0.1 : 0.25) {
            pet.makeSick()
            battleText += " INJURED!"
        }
        haptic(won ? .success : .failure)
        if plan != nil { tamer.myBattleCode = nil }   // fresh code for the next friend battle
        save()

        try? await Task.sleep(for: .seconds(2.6))
        screen = .home
    }

    private func fire(fromPlayer: Bool, hit: Bool) async {
        shotFromPlayer = fromPlayer
        shotHit = hit
        shotProgress = 0
        shotActive = true
        battleText = fromPlayer ? "ATTACK!" : "RIVAL ATTACKS!"
        haptic(fromPlayer ? .directionUp : .directionDown)
        withAnimation(.linear(duration: 0.6)) { shotProgress = 1 }
        try? await Task.sleep(for: .milliseconds(620))
        shotActive = false
        if hit {
            if fromPlayer {
                enemyLives -= 1
                enemyShake = true
            } else {
                playerLives -= 1
                playerShake = true
            }
            battleText = "HIT!"
            haptic(.notification)
        } else {
            battleText = "MISS!"
        }
        try? await Task.sleep(for: .milliseconds(380))
        playerShake = false
        enemyShake = false
        try? await Task.sleep(for: .milliseconds(250))
    }

    // MARK: - New egg

    func newEgg() {
        let gen = pet.generation + 1
        var p = Pet()
        p.generation = gen
        p.lastUpdate = Date()
        pet = p
        screen = .home
        anim = .none
        haptic(.retry)
        save()
    }

    // MARK: - Settings helpers

    func setSpeed(_ speed: Double) {
        catchUp()                 // settle time at the old speed first
        tamer.speed = speed
        pet.lastUpdate = Date()
        save()
    }

    // MARK: - Debug / testing (compiled only into Debug builds)

    #if DEBUG

    func debugSkip(minutes: Double) {
        pet.lastUpdate = pet.lastUpdate.addingTimeInterval(-minutes * secondsPerGameMinute)
        catchUp()
    }

    func debugEvolve() {
        if pet.isDead { return }
        if pet.stage == .egg {
            pet.hatch()
            handle([.hatched], live: true)
            return
        }
        if pet.stage == .champion && pet.battles < Tuning.ultimateBattles {
            pet.battles = Tuning.ultimateBattles
            pet.wins = Tuning.ultimateBattles
        }
        if pet.tryEvolve() {
            handle([.evolved], live: true)
        } else {
            showToast("FINAL FORM")
        }
        save()
    }

    func debugSick() {
        guard !pet.isDead, pet.stage != .egg else { return }
        pet.makeSick()
        save()
    }
    #endif

    // MARK: - Notifications

    func setNotifications(_ on: Bool) {
        tamer.notifications = on
        if on { requestNotificationPermission() }
        notificationSettingsChanged()
    }

    func notificationSettingsChanged() {
        save()
        scheduleCareReminder()
    }

    private func requestNotificationPermission() {
        guard tamer.notifications else { return }
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
    }

    /// Looks ahead with the same game rules and schedules a notification for each
    /// moment the dino will need you: hungry, pooped or sick.
    /// Called whenever the app leaves the screen, so it always matches the latest state.
    func scheduleCareReminder() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard tamer.notifications, !pet.isDead, !isPaused, pet.stage != .egg else { return }

        var p = pet
        let name = p.formName
        let secPerMin = secondsPerGameMinute
        var t = p.lastUpdate
        var hungerSent = false
        var proteinSent = false
        var sickSent = false
        var poopsSent = 0

        func add(_ id: String, at date: Date, _ body: String) {
            let interval = date.timeIntervalSinceNow
            guard interval > 5 else { return }
            let content = UNMutableNotificationContent()
            content.title = "WatchTamer"
            content.body = body
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger),
                       withCompletionHandler: nil)
        }

        for _ in 0..<2880 {
            t = t.addingTimeInterval(secPerMin)
            let before = p
            let events = p.simulateMinute(at: t, autoLights: true)
            if events.isEmpty { continue }

            if events.contains(.call) {
                if tamer.notifyHunger && !hungerSent && p.hungerCall.isCalling && !before.hungerCall.isCalling {
                    hungerSent = true
                    add("hungry", at: t, "🍖 Your \(name) is hungry! Feed it within 10 minutes.")
                }
                if tamer.notifyHunger && !proteinSent && p.strengthCall.isCalling && !before.strengthCall.isCalling {
                    proteinSent = true
                    add("protein", at: t, "💪 Your \(name) is weak! Give it protein or train it.")
                }
            }

            if events.contains(.poop) && tamer.notifyPoop && poopsSent < Tuning.maxPoops {
                poopsSent += 1
                let body: String
                if p.poops >= Tuning.maxPoops - 1 {
                    body = "💩 \(p.poops) poops! Flush now or your \(name) will get sick!"
                } else if p.poops == 1 {
                    body = "💩 Your \(name) pooped! Time to flush."
                } else {
                    body = "💩 \(p.poops) poops piling up. Flush them!"
                }
                add("poop-\(poopsSent)", at: t, body)
            }

            if events.contains(.sick) && tamer.notifySick && !sickSent {
                sickSent = true
                add("sick", at: t, "💀 Your \(name) is sick! Give it medicine.")
            }

            if p.isDead { break }
        }
    }
}
