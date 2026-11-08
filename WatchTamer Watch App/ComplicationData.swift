//
//  ComplicationData.swift
//  WatchTamer Watch App (also built into the WatchTamer Widgets complication)
//
//  What the watch-face complication shows: the most urgent need, or the dino
//  when everything is fine. The game looks ahead with the same rules it uses
//  while the app is closed and leaves a short plan in the shared App Group,
//  so the complication changes at the right moments without the game running.
//  Nothing leaves the watch.
//

import Foundation

/// The one thing the complication shows, most urgent first.
enum CareNeed: String, Codable {
    case dead, egg, sick, hungry, poop, weak, asleep, ok
}

extension Pet {
    /// The most urgent need right now: sick, then hungry, then poop, then weak.
    func careNeed(at date: Date) -> CareNeed {
        if isDead { return .dead }
        if stage == .egg { return .egg }
        if isSick { return .sick }
        if hunger == 0 { return .hungry }
        if poops > 0 { return .poop }
        if strength == 0 { return .weak }
        if isAsleep(at: date) { return .asleep }
        return .ok
    }
}

/// The plan the game leaves for the complication.
struct CareSnapshot: Codable {
    struct Entry: Codable, Equatable {
        var date: Date
        var need: CareNeed
        var spriteKey: String
        var formName: String
    }

    var entries: [Entry]

    static let appGroup = "group.com.senalbert.WatchTamer"
    static let key = "complication_v1"
    /// How far ahead the plan looks (the game refreshes it every time you leave the app).
    static let lookAheadMinutes = 48 * 60

    /// Looks ahead minute by minute, the same way the game catches up while it's closed,
    /// and keeps only the moments where what the complication shows changes.
    static func plan(for pet: Pet, now: Date = Date()) -> CareSnapshot {
        var p = pet
        func entry(_ date: Date) -> Entry {
            Entry(date: date, need: p.careNeed(at: date), spriteKey: p.spriteKey, formName: p.formName)
        }
        var entries = [entry(now)]
        var t = p.lastUpdate
        for _ in 0..<lookAheadMinutes {
            t = t.addingTimeInterval(60)
            _ = p.simulateMinute(at: t, allowDeath: false, autoLights: true)
            guard t > now else { continue }
            let next = entry(t)
            if let last = entries.last, last.need == next.need, last.spriteKey == next.spriteKey { continue }
            entries.append(next)
        }
        return CareSnapshot(entries: entries)
    }

    /// Same plan, ignoring the time stamp of the first entry (which is always "now").
    func sameMoments(as other: CareSnapshot?) -> Bool {
        guard let other, entries.count == other.entries.count else { return false }
        return zip(entries, other.entries).enumerated().allSatisfy { i, pair in
            pair.0.need == pair.1.need && pair.0.spriteKey == pair.1.spriteKey
                && pair.0.formName == pair.1.formName && (i == 0 || pair.0.date == pair.1.date)
        }
    }

    // MARK: Shared storage (App Group, on this watch only)

    static func load() -> CareSnapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CareSnapshot.self, from: data)
    }

    /// Saves the plan. Returns false if it's the same as the saved one (nothing to refresh).
    @discardableResult
    func save() -> Bool {
        guard !sameMoments(as: CareSnapshot.load()), let data = try? JSONEncoder().encode(self) else { return false }
        UserDefaults(suiteName: CareSnapshot.appGroup)?.set(data, forKey: CareSnapshot.key)
        return true
    }
}
