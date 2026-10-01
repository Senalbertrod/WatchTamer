//
//  SettingsView.swift
//  WatchTamer Watch App
//
//  Swipe left from the pet to reach this page.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: DinoState
    @State private var confirmReset = false

    var body: some View {
        List {
            Section("GAME") {
                Toggle("Pause (daycare)", isOn: Binding(
                    get: { state.isPaused },
                    set: { $0 ? state.pause(.daycare) : state.resume() }
                ))

                Toggle("Pause while charging", isOn: Binding(
                    get: { state.tamer.pauseWhenCharging },
                    set: { state.setPauseWhenCharging($0) }
                ))

                Picker("Speed", selection: Binding(
                    get: { state.tamer.speed },
                    set: { state.setSpeed($0) }
                )) {
                    Text("Classic (real time)").tag(1.0)
                    Text("Fast (10x)").tag(10.0)
                }

                Toggle("Night screen", isOn: Binding(
                    get: { state.tamer.nightScreen },
                    set: { state.tamer.nightScreen = $0; state.save() }
                ))

            }

            Section("NOTIFICATIONS") {
                Toggle("Care reminders", isOn: Binding(
                    get: { state.tamer.notifications },
                    set: { state.setNotifications($0) }
                ))
                Group {
                    Toggle("Hungry", isOn: Binding(
                        get: { state.tamer.notifyHunger },
                        set: { state.tamer.notifyHunger = $0; state.notificationSettingsChanged() }
                    ))
                    Toggle("Poop", isOn: Binding(
                        get: { state.tamer.notifyPoop },
                        set: { state.tamer.notifyPoop = $0; state.notificationSettingsChanged() }
                    ))
                    Toggle("Sick", isOn: Binding(
                        get: { state.tamer.notifySick },
                        set: { state.tamer.notifySick = $0; state.notificationSettingsChanged() }
                    ))
                }
                .disabled(!state.tamer.notifications)
            }

            Section("WALK TRAINING") {
                Toggle("Walking trains dino", isOn: Binding(
                    get: { state.tamer.walkTraining },
                    set: { state.tamer.walkTraining = $0; state.save(); state.refreshSteps() }
                ))

                Picker("Steps per rep", selection: Binding(
                    get: { state.tamer.stepsPerRep },
                    set: { state.tamer.stepsPerRep = $0; state.save() }
                )) {
                    Text("100").tag(100)
                    Text("250").tag(250)
                    Text("500").tag(500)
                    Text("1000").tag(1000)
                }

                LabeledContent("Lifetime steps", value: "\(state.tamer.lifetimeSteps)")
                LabeledContent("Walk reps", value: "\(state.tamer.walkReps)")
            }

            Section("HOW TO PLAY") {
                Text("Feed MEAT for hunger hearts, PROTEIN for strength. TRAIN by tapping fast or just walking. FLUSH poop, give MEDICINE when you see a skull. The ! light means your dino needs you. Bedtime is 8-10pm: light off = asleep (needs pause), light on = awake and ready to play any time. Leaving the game at night turns the light off for you. Good care + lots of training + winning battles = the best dinosaurs. Every new egg rolls the dice: a striped RARE egg (10%) becomes a random, slightly stronger Ultimate, and the SPIKY egg (2%) is the only way to get a T-Rex or Raptor. Taking the watch off? Hold the screen for 1 second to pause (daycare). Charging pauses automatically.")
                    .font(.system(size: 12))
            }

            #if DEBUG
            // Only in builds run from Xcode. App Store / TestFlight (Release) builds hide this.
            Section("TESTING") {
                Button("Skip 1 hour") { state.debugSkip(minutes: 60) }
                Button("Add 250 steps") { state.creditSteps(250) }
                Button("Evolve now") { state.debugEvolve() }
                Button("Make sick") { state.debugSick() }
                Button("Lay rare egg") { state.debugEgg(.rare) }
                Button("Lay spiky egg") { state.debugEgg(.spiky) }
            }
            #endif

            Section {
                if state.newEggUnlocksAt == nil {
                    Button("Start new egg", role: .destructive) { confirmReset = true }
                } else {
                    LabeledContent("New egg in", value: "\(state.newEggDaysLeft) days")
                }
            } footer: {
                Text("You can start a new egg once every 2 weeks, or right away if your dino dies.")
            }
        }
        .confirmationDialog("Start over with a new egg?", isPresented: $confirmReset) {
            Button("New egg", role: .destructive) { state.newEgg() }
            Button("Cancel", role: .cancel) {}
        }
    }
}
