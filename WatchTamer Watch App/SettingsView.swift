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

            Section("WALKING") {
                Toggle("Walking feeds and trains dino", isOn: Binding(
                    get: { state.tamer.walkTraining },
                    set: { state.tamer.walkTraining = $0; state.save(); state.refreshSteps() }
                ))

                LabeledContent("Food", value: "every \(Tuning.walkFoodSteps) steps")
                LabeledContent("Protein", value: "every \(Tuning.walkProteinSteps) steps")
                LabeledContent("Training", value: "every \(Tuning.walkTrainSteps) steps")

                LabeledContent("Lifetime steps", value: "\(state.tamer.lifetimeSteps)")
                LabeledContent("Walk trainings", value: "\(state.tamer.walkReps)")
            }

            Section("HOW TO PLAY") {
                Text("""
                    • MEAT fills hunger, PROTEIN fills strength.
                    • Train by tapping fast, or just walk: food every 250 steps, protein every 500, training every 1,000.
                    • FLUSH poop. Skull = give MEDICINE.
                    • ! means your dino needs you.
                    • Bedtime 8-10pm: the light turns off by itself. Tap 💡 to wake your dino and keep playing.
                    • Each battle uses 1 strength heart.
                    • Friend battle: swap codes (Done just closes the keyboard), both tap BATTLE. If your friend battled first, type their LAST CODE. Each code works only once.
                    • Good care, training and wins = the best dinos.
                    • Eggs: striped RARE (10%) becomes a stronger Ultimate. SPIKY (2%) is the only way to get a T-Rex or Raptor.
                    • Runs in real time. Don't leave it alone for 2 weeks.
                    """)
                    .font(.system(size: 12))
            }

            #if DEBUG
            // Only in builds run from Xcode. App Store / TestFlight (Release) builds hide this.
            Section("TESTING") {
                Button("Skip 1 hour") { state.debugSkip(minutes: 60) }
                Button("Add 250 steps") { state.creditSteps(250) }
                Button("Evolve now") { state.debugEvolve() }
                Button("Make sick") { state.debugSick() }
                Button("Away 14 days") { state.debugLonely() }
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
