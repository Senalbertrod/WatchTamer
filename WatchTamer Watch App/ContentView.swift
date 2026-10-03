//
//  ContentView.swift
//  WatchTamer Watch App
//
//  The classic virtual-pet device: 4 icons on top, the LCD, 4 icons on the bottom.
//  Top:    STATUS  FEED  TRAIN  BATTLE
//  Bottom: FLUSH  LIGHTS  MEDICINE  CALL(attention light)
//

import SwiftUI
import CoreMotion
import Combine
import Foundation
import WatchKit

struct ContentView: View {
    @ObservedObject var state: DinoState

    // Classic step-by-step wandering (in LCD dots)
    @State private var walkX: Int = 0
    @State private var facingRight = false
    @State private var frame = 0
    @State private var blink = false
    @State private var flushProgress: CGFloat = 1
    @State private var friendCodeInput = ""
    @State private var showCodeEntry = false
    @State private var codeError = false

    private let stepTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var pal: LCDPalette { LCDPalette.current(night: state.tamer.nightScreen) }
    private var pet: Pet { state.pet }

    var body: some View {
        Group {
            if pet.isDead {
                deadView
            } else {
                deviceView
            }
        }
        .onReceive(stepTimer) { _ in stepAnimation() }
        // Friend-code entry lives on its own screen, away from the game's
        // tap gestures, so the watch keyboard / Scribble / dictation can open.
        .sheet(isPresented: $showCodeEntry) { codeEntrySheet }
        .onChange(of: state.anim) { _, newValue in
            if newValue == .flushing {
                flushProgress = 1
                withAnimation(.linear(duration: 1.2)) { flushProgress = 0 }
            }
        }
    }

    // MARK: - Device layout

    private var deviceView: some View {
        VStack(spacing: 3) {
            iconRow([.status, .feed, .train, .battle])
            lcd
            iconRow([.flush, .lights, .medical, .call])
        }
        .padding(.horizontal, 2)
    }

    private func iconRow(_ items: [MenuItem]) -> some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.self) { item in
                Button {
                    state.select(item)
                } label: {
                    Image(systemName: item.symbol)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(iconColor(item))
                        .frame(maxWidth: .infinity, minHeight: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isActive(item) ? pal.bezel.opacity(0.7) : Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func iconColor(_ item: MenuItem) -> Color {
        switch item {
        case .call:
            return pet.isCalling ? (blink ? .red : .orange) : .gray.opacity(0.35)
        case .medical:
            return pet.isSick ? .pink : .white.opacity(0.85)
        case .lights:
            return pet.lightsOn ? .yellow : .gray
        default:
            return .white.opacity(0.85)
        }
    }

    private func isActive(_ item: MenuItem) -> Bool {
        switch (item, state.screen) {
        case (.status, .status): return true
        case (.feed, .feed): return true
        case (.train, .train), (.train, .trainTap), (.train, .walk): return true
        case (.battle, .battle), (.battle, .battleMenu), (.battle, .friendCode): return true
        default: return false
        }
    }

    // MARK: - LCD

    private var lcd: some View {
        GeometryReader { geo in
            let dot = max(2, floor(min(geo.size.width / 40, geo.size.height / 26)))
            ZStack {
                pal.screen
                LCDGrid(dot: dot, color: pal.ghost)
                lcdContent(dot: dot, size: geo.size)

                // Lights off = dark screen
                if !pet.lightsOn && pet.stage != .egg && state.screen == .home {
                    Color.black.opacity(0.88)
                    if state.isAsleep {
                        PixelSprite(rows: PixelArt.zzz, dot: dot, color: pal.dot.opacity(0.9))
                            .position(x: geo.size.width - 5 * dot, y: 5 * dot)
                    }
                }

                // Evolution strobe
                if state.anim == .evolving && state.flashOn {
                    pal.dot
                }

                if let toast = state.toast {
                    VStack {
                        Text(toast)
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundColor(pal.screen)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(pal.dot)
                        Spacer()
                    }
                    .padding(.top, 3)
                    .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(pal.bezel, lineWidth: 2))
            .contentShape(Rectangle())
            .onTapGesture { lcdTapped() }
        }
    }

    private func lcdTapped() {
        switch state.screen {
        case .home:
            if pet.stage == .egg { state.tapEgg() }
        case .status:
            state.nextStatusPage()
        case .trainTap:
            state.mash()
        case .walk:
            state.goHome()
        case .friendCode:
            codeError = false
            showCodeEntry = true
        default:
            break
        }
    }

    @ViewBuilder
    private func lcdContent(dot: CGFloat, size: CGSize) -> some View {
        switch state.screen {
        case .home:
            homeScene(dot: dot, size: size)
        case .status(let page):
            statusPage(page, dot: dot)
        case .feed:
            feedMenu(dot: dot)
        case .train:
            trainMenu(dot: dot)
        case .trainTap:
            tapTrainingScene(dot: dot, size: size)
        case .walk:
            walkScene(dot: dot)
        case .battleMenu:
            battleMenu()
        case .friendCode:
            friendCodeScene()
        case .battle:
            battleScene(dot: dot, size: size)
        }
    }

    /// Shrinks a sprite's dot size (never grows it) so it fits in `cols` x `maxRows` LCD dots.
    private func fitDot(_ rows: [String], dot: CGFloat, cols: CGFloat, rows maxRows: CGFloat) -> CGFloat {
        let w = CGFloat(rows.map { $0.count }.max() ?? 1)
        let h = CGFloat(max(rows.count, 1))
        return dot * min(1, cols / max(w, 1), maxRows / h)
    }

    private func lcdText(_ text: String, _ size: CGFloat = 10) -> some View {
        Text(text)
            .font(.system(size: size, weight: .bold, design: .monospaced))
            .foregroundColor(pal.dot)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    // MARK: - Home scene

    private func homeScene(dot: CGFloat, size: CGSize) -> some View {
        let groundY = size.height - 2 * dot
        let rows = DinoSprite.rows(pet.spriteKey, frame: currentFrame)
        let spriteW = CGFloat(rows.first?.count ?? 0) * dot
        let spriteH = CGFloat(rows.count) * dot
        let poopAreaDots: CGFloat = pet.poops > 0 ? 13 : 0
        // Big dinos may stand partly in front of the poop rather than off the screen.
        let usableW = max(min(size.width, spriteW + 2 * dot), size.width - poopAreaDots * dot)
        let maxShift = max(0, (usableW - spriteW) / 2 - dot)
        let shift = min(maxShift, max(-maxShift, CGFloat(walkX) * dot))
        let isFlyer = pet.stage != .egg && pet.species == .pteranodon && pet.stage == .champion
        let dinoX = usableW / 2 + (isEatingOrStill ? 0 : shift)
        let dinoY = groundY - spriteH / 2 - (isFlyer ? 3 * dot : 0)

        return ZStack {
            // Ground line
            Rectangle()
                .fill(pal.dot.opacity(0.35))
                .frame(width: size.width, height: max(1, dot * 0.5))
                .position(x: size.width / 2, y: groundY + dot * 0.5)

            if pet.stage == .egg {
                eggScene(dot: dot, size: size, rows: rows, groundY: groundY)
            } else {
                PixelSprite(rows: rows, dot: dot, color: pal.dot, flipped: spriteFacesRight)
                    .position(x: dinoX, y: dinoY)

                // Food being eaten
                if case .eating(let kind, let bite) = state.anim {
                    let food = kind == .meat ? PixelArt.meat : PixelArt.protein
                    let remaining = Array(food.dropFirst(min(food.count, bite * food.count / 3)))
                    PixelSprite(rows: remaining, dot: dot, color: pal.dot)
                        .position(x: dinoX - spriteW / 2 - 5 * dot,
                                  y: groundY - CGFloat(remaining.count) * dot / 2)
                }

                if state.anim == .refusing {
                    PixelSprite(rows: PixelArt.no, dot: dot, color: pal.dot)
                        .position(x: dinoX - spriteW / 2 - 4 * dot, y: dinoY - spriteH / 3)
                }

                if state.anim == .healing {
                    PixelSprite(rows: PixelArt.heart, dot: dot, color: pal.dot)
                        .position(x: dinoX, y: max(4 * dot, dinoY - spriteH / 2 - 5 * dot))
                }

                if state.anim == .walkRep {
                    PixelSprite(rows: PixelArt.heart, dot: dot, color: pal.dot)
                        .position(x: dinoX + spriteW / 2, y: max(4 * dot, dinoY - spriteH / 2 - 3 * dot))
                }

                if pet.isSick {
                    PixelSprite(rows: PixelArt.skull, dot: dot, color: pal.dot)
                        .position(x: min(usableW - 4 * dot, dinoX + spriteW / 2 + 3 * dot),
                                  y: max(5 * dot, dinoY - spriteH / 2))
                }


                // Poop piles on the right, 2 columns, bottom-up
                ForEach(0..<pet.poops, id: \.self) { i in
                    let col = CGFloat(i % 2)
                    let row = CGFloat(i / 2)
                    PixelSprite(rows: PixelArt.poop, dot: dot, color: pal.dot)
                        .position(x: size.width - (3.5 + col * 6) * dot,
                                  y: groundY - (2 + row * 5) * dot)
                        .opacity(state.anim == .flushing && (size.width - (3.5 + col * 6) * dot) > size.width * flushProgress ? 0 : 1)
                }

                // Flush wave
                if state.anim == .flushing {
                    VStack(spacing: dot) {
                        ForEach(0..<Int(size.height / (2 * dot)), id: \.self) { _ in
                            Rectangle().fill(pal.dot).frame(width: 2 * dot, height: dot)
                        }
                    }
                    .position(x: size.width * flushProgress, y: size.height / 2)
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func eggScene(dot: CGFloat, size: CGSize, rows: [String], groundY: CGFloat) -> some View {
        let eggDot = fitDot(rows, dot: dot, cols: 30, rows: 15)   // leave room for the text
        let spriteH = CGFloat(rows.count) * eggDot
        let tapsLeft = max(0, Int(ceil((100 - pet.eggProgress) / 10)))
        return ZStack {
            PixelSprite(rows: rows, dot: eggDot, color: pal.dot)
                .position(x: size.width / 2, y: groundY - spriteH / 2)
            VStack(spacing: 1) {
                lcdText("TAP OR WALK", 9)
                lcdText("TO HATCH: \(tapsLeft)", 9)
            }
            .position(x: size.width / 2, y: 4 * dot)
        }
    }

    /// Animation frame: sleeping and still moments use frame 0.
    private var currentFrame: Int {
        if pet.stage == .egg { return frame }
        if state.isAsleep { return 0 }
        if case .eating(_, let bite) = state.anim { return bite % 2 }
        return frame
    }

    private var isEatingOrStill: Bool {
        if case .eating = state.anim { return true }
        return state.anim == .refusing || state.anim == .healing || state.isAsleep
    }

    private var spriteFacesRight: Bool {
        if case .eating = state.anim { return false }
        if state.anim == .refusing { return frame == 1 }   // shakes head
        return facingRight
    }

    private func stepAnimation() {
        blink.toggle()
        frame = frame == 0 ? 1 : 0
        guard state.screen == .home, state.anim == .none, !state.isAsleep, pet.stage != .egg else { return }
        // Classic hop-walk: move one dot at a time, turn around at the edges or randomly.
        if Int.random(in: 0..<10) < 6 {
            walkX += facingRight ? 1 : -1
        }
        if walkX >= 7 { facingRight = false }
        if walkX <= -7 { facingRight = true }
        if Int.random(in: 0..<12) == 0 { facingRight.toggle() }
    }

    // MARK: - Status pages

    private func statusPage(_ page: Int, dot: CGFloat) -> some View {
        let small = max(2, dot * 0.8)
        return VStack(spacing: 3) {
            switch page {
            case 0:
                lcdText(pet.formName, 12)
                lcdText(pet.stage.displayName, 9)
                lcdText("AGE \(pet.ageDays)d  GEN \(pet.generation)", 9)
                lcdText("WEIGHT \(pet.weight)g", 9)
            case 1:
                lcdText("HUNGRY", 11)
                HeartsRow(filled: pet.hunger, dot: small, color: pal.dot)
            case 2:
                lcdText("STRENGTH", 11)
                HeartsRow(filled: pet.strength, dot: small, color: pal.dot)
            case 3:
                lcdText("EFFORT", 11)
                HeartsRow(filled: pet.effort, dot: small, color: pal.dot)
                lcdText("TRAINED \(pet.trainings)x", 9)
            case 4:
                lcdText("BATTLES", 11)
                lcdText("THIS STAGE  W\(pet.wins) L\(pet.battles - pet.wins)  \(Int(pet.winRate * 100))%", 9)
                lcdText("ALL TIME  W\(pet.totalWins) L\(pet.totalBattles - pet.totalWins)", 9)
            default:
                lcdText("CARE", 11)
                lcdText("MISTAKES \(pet.careMistakes)", 9)
                lcdText("INJURIES \(pet.injuries)/\(Tuning.maxInjuries)", 9)
                lcdText("STEPS \(state.tamer.lifetimeSteps)", 9)
            }
            lcdText("TAP ▶ \(page + 1)/6", 7)
                .opacity(0.6)
        }
        .padding(4)
    }

    // MARK: - Feed & Train menus

    private func feedMenu(dot: CGFloat) -> some View {
        HStack(spacing: 6) {
            menuChoice(title: "MEAT", sprite: PixelArt.meat, dot: dot) { state.feed(.meat) }
            menuChoice(title: "PROTEIN", sprite: PixelArt.protein, dot: dot) { state.feed(.protein) }
        }
        .padding(4)
    }

    private func trainMenu(dot: CGFloat) -> some View {
        HStack(spacing: 6) {
            menuChoice(title: "TAP", symbol: "hand.tap.fill") { state.startTapTraining() }
            menuChoice(title: "WALK", symbol: "figure.walk") { state.openWalk() }
        }
        .padding(4)
    }

    private func menuChoice(title: String, sprite: [String]? = nil, symbol: String? = nil,
                            dot: CGFloat = 3, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                if let sprite {
                    PixelSprite(rows: sprite, dot: dot, color: pal.dot)
                }
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(pal.dot)
                }
                lcdText(title, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(pal.dot.opacity(0.5), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Battle menu & battle codes

    private func battleMenu() -> some View {
        HStack(spacing: 6) {
            menuChoice(title: "CPU", symbol: "cpu") { state.startBattle() }
            menuChoice(title: "FRIEND", symbol: "person.2.fill") { state.openFriendCode() }
        }
        .padding(4)
    }

    private func friendCodeScene() -> some View {
        VStack(spacing: 3) {
            lcdText("YOUR CODE", 9)
            Text(state.tamer.myBattleCode ?? "------")
                .font(.system(size: 18, weight: .heavy, design: .monospaced))
                .foregroundColor(pal.dot)
            lcdText("TAP TO ENTER", 10)
                .opacity(blink ? 1 : 0.4)
            lcdText("FRIEND'S CODE", 10)
                .opacity(blink ? 1 : 0.4)
        }
        .padding(4)
    }

    /// Full-screen code entry. Tapping the text box opens the watch's
    /// keyboard (or Scribble / dictation on watches without a keyboard).
    private var codeEntrySheet: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("FRIEND'S CODE")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundColor(.green)

                TextField("H5N-9QP", text: $friendCodeInput)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .onSubmit { submitFriendCode() }

                if codeError {
                    Text("BAD CODE. CHECK IT AND TRY AGAIN.")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    submitFriendCode()
                } label: {
                    Text("⚡ BATTLE!")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .frame(maxWidth: .infinity)
                }
                .tint(.green)
                .disabled(friendCodeInput.filter { $0.isLetter || $0.isNumber }.count != 6)

                Divider()

                Text("YOUR CODE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                Text(state.tamer.myBattleCode ?? "------")
                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                    .foregroundColor(.green)
                Button("NEW CODE") { state.newBattleCode() }
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            .padding(.horizontal, 4)
        }
    }

    private func submitFriendCode() {
        let code = friendCodeInput
        guard BattleCode.decode(code) != nil else {
            codeError = true
            state.haptic(.failure)
            return
        }
        friendCodeInput = ""
        codeError = false
        showCodeEntry = false
        state.startFriendBattle(code: code)
    }

    // MARK: - Tap training

    private func tapTrainingScene(dot: CGFloat, size: CGSize) -> some View {
        let groundY = size.height - 2 * dot
        let rows = DinoSprite.rows(pet.spriteKey, frame: state.trainOver ? 0 : frame)
        let tdot = fitDot(rows, dot: dot, cols: 22, rows: 14)
        let spriteW = CGFloat(rows.first?.count ?? 0) * tdot
        let spriteH = CGFloat(rows.count) * tdot
        let wallX = size.width - 4 * dot
        let dinoX = 2 * dot + spriteW / 2

        return ZStack {
            VStack(spacing: 2) {
                HStack {
                    lcdText(state.trainOver ? (state.trainSuccess ? "GREAT!" : "WEAK...") : "TAP FAST!", 10)
                    Spacer()
                    lcdText(String(format: "%.1f", state.trainTimeLeft), 10)
                }
                LCDBar(progress: state.trainMeter / 100, color: pal.dot, height: 7)
            }
            .padding(.horizontal, 5)
            .position(x: size.width / 2, y: 6 * dot)

            PixelSprite(rows: rows, dot: tdot, color: pal.dot, flipped: true)
                .position(x: dinoX, y: groundY - spriteH / 2)

            PixelSprite(rows: PixelArt.wall, dot: dot, color: pal.dot)
                .position(x: wallX, y: groundY - 5 * dot)
                .opacity(state.trainOver && state.trainSuccess && frame == 1 ? 0.2 : 1)

            if state.trainOver {
                let shotX = state.trainSuccess ? wallX - 3 * dot : (dinoX + wallX) / 2
                PixelSprite(rows: PixelArt.shot, dot: dot, color: pal.dot)
                    .position(x: shotX, y: groundY - spriteH / 2)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Walk training

    private func walkScene(dot: CGFloat) -> some View {
        let t = state.tamer
        let per = max(50, t.stepsPerRep)
        return VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(pal.dot)
                lcdText("WALK TRAINING", 10)
            }
            if !CMPedometer.isStepCountingAvailable() {
                lcdText("NO STEP SENSOR", 9)
                lcdText("USE TAP TRAINING", 8)
            } else if !t.walkTraining {
                lcdText("TURNED OFF", 9)
                lcdText("SWIPE → SETTINGS", 8)
            } else {
                lcdText("\(t.stepBank)/\(per) STEPS", 10)
                LCDBar(progress: Double(t.stepBank) / Double(per), color: pal.dot, height: 7)
                    .padding(.horizontal, 6)
                lcdText("REPS \(t.walkReps)  TRAINED \(pet.trainings)", 8)
                lcdText("JUST WALK - IT COUNTS!", 7)
                    .opacity(0.7)
            }
        }
        .padding(4)
    }

    // MARK: - Battle

    private func battleScene(dot: CGFloat, size: CGSize) -> some View {
        let bdot = max(2, floor(dot * 0.72))
        let groundY = size.height - 2 * dot
        let myRows = DinoSprite.rows(pet.spriteKey, frame: frame)
        let foeRows = DinoSprite.rows(state.enemySpecies.rawValue, frame: frame)
        let myDot = fitDot(myRows, dot: dot, cols: 16, rows: 13)
        let foeDot = fitDot(foeRows, dot: dot, cols: 16, rows: 13)
        let myW = CGFloat(myRows.first?.count ?? 0) * myDot
        let foeW = CGFloat(foeRows.first?.count ?? 0) * foeDot
        let myX = myW / 2 + 2 * dot + (state.playerShake ? -2 * bdot : 0)
        let foeX = size.width - foeW / 2 - 2 * dot + (state.enemyShake ? 2 * bdot : 0)
        let myY = groundY - CGFloat(myRows.count) * myDot / 2
        let foeY = groundY - CGFloat(foeRows.count) * foeDot / 2
        let small = max(1.5, bdot * 0.6)

        return ZStack {
            switch state.battlePhase {
            case .docking(let step):
                VStack(spacing: 4) {
                    lcdText("LINKING...", 11)
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { i in
                            Rectangle()
                                .fill(i < step ? pal.dot : pal.dot.opacity(0.2))
                                .frame(width: 14, height: 6)
                        }
                    }
                    lcdText((state.isFriendBattle ? "FRIEND: " : "RIVAL: ") + state.enemySpecies.displayName, 8)
                }
            case .fighting, .result:
                HStack {
                    HeartsRow(filled: state.playerLives, total: 3, dot: small, color: pal.dot)
                    Spacer()
                    HeartsRow(filled: state.enemyLives, total: 3, dot: small, color: pal.dot)
                }
                .padding(.horizontal, 4)
                .position(x: size.width / 2, y: 4 * dot)

                PixelSprite(rows: myRows, dot: myDot, color: pal.dot, flipped: true)
                    .position(x: myX, y: myY)
                    .opacity(state.battlePhase == .result(false) && frame == 1 ? 0.25 : 1)

                PixelSprite(rows: foeRows, dot: foeDot, color: pal.dot)
                    .position(x: foeX, y: foeY)
                    .opacity(state.battlePhase == .result(true) && frame == 1 ? 0.25 : 1)

                if state.shotActive {
                    let startX = state.shotFromPlayer ? myX + myW / 2 : foeX - foeW / 2
                    let endX = state.shotFromPlayer ? foeX : myX
                    let progress = CGFloat(state.shotProgress)
                    let x = startX + (endX - startX) * progress
                    let arc: CGFloat = state.shotHit ? 0 : CGFloat(sin(state.shotProgress * Double.pi)) * size.height * 0.35
                    PixelSprite(rows: PixelArt.shot, dot: bdot, color: pal.dot)
                        .position(x: x, y: groundY - 6 * dot - arc)
                }

                lcdText(state.battleText, 9)
                    .position(x: size.width / 2, y: 9 * dot)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Dead

    private var deadView: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(pal.screen)
                VStack(spacing: 4) {
                    PixelSprite(rows: PixelArt.tombstone, dot: 3, color: pal.dot)
                    Text("\(pet.formName) RIP")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundColor(pal.dot)
                    Text("\(pet.deathReason) · AGE \(pet.ageDays)d")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(pal.dot)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(pal.bezel, lineWidth: 2))

            Button {
                state.newEgg()
            } label: {
                Text("NEW EGG")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .background(Color.green)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }
}
