//
//  WatchTamerWidgets.swift
//  WatchTamer Widgets
//
//  The watch-face complication: shows what your dino needs most right now
//  (medicine, food, a flush or protein), or your dino when everything is fine.
//  It reads the plan the game leaves in the shared App Group (CareSnapshot).
//

import SwiftUI
import WidgetKit

// MARK: - Timeline

struct CareEntry: TimelineEntry {
    let date: Date
    let need: CareNeed
    let spriteKey: String
    let formName: String
    /// False until the game has been opened once with this version.
    var hasPlan = true

    static let placeholder = CareEntry(date: Date(), need: .ok, spriteKey: "oviraptor", formName: "WATCHTAMER")
}

struct CareProvider: TimelineProvider {
    func placeholder(in context: Context) -> CareEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (CareEntry) -> Void) {
        completion(context.isPreview ? .placeholder : entries().first ?? .placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CareEntry>) -> Void) {
        // The game refreshes this plan every time you leave it, so no polling is needed.
        completion(Timeline(entries: entries(), policy: .never))
    }

    /// The saved plan, starting with whatever applies right now.
    private func entries(now: Date = Date()) -> [CareEntry] {
        guard let plan = CareSnapshot.load(), !plan.entries.isEmpty else {
            return [CareEntry(date: now, need: .ok, spriteKey: "egg", formName: "WATCHTAMER", hasPlan: false)]
        }
        let all = plan.entries.map {
            CareEntry(date: $0.date, need: $0.need, spriteKey: $0.spriteKey, formName: $0.formName)
        }
        let current = all.last(where: { $0.date <= now }) ?? all[0]
        let future = all.filter { $0.date > now }
        return [CareEntry(date: now, need: current.need, spriteKey: current.spriteKey,
                          formName: current.formName)] + future
    }
}

// MARK: - What each need looks like

extension CareEntry {
    /// The pixel picture: the problem's icon, or the dino when all is well.
    var sprite: [String] {
        switch need {
        case .dead: return PixelArt.tombstone
        case .sick: return PixelArt.skull
        case .hungry: return PixelArt.meat
        case .poop: return PixelArt.poop
        case .weak: return PixelArt.protein
        case .egg, .asleep, .ok: return DinoSprite.rows(spriteKey, frame: 0)
        }
    }

    /// Short label (corner and circular).
    var shortText: String {
        switch need {
        case .dead: return String(localized: "RIP")
        case .egg: return String(localized: "HATCH")
        case .sick: return String(localized: "SICK!")
        case .hungry: return String(localized: "HUNGRY!")
        case .poop: return String(localized: "FLUSH!")
        case .weak: return String(localized: "WEAK!")
        case .asleep: return String(localized: "ZZZ")
        case .ok: return String(localized: "OK")
        }
    }

    /// What to do about it (rectangular).
    var actionText: String {
        guard hasPlan else { return String(localized: "OPEN THE GAME") }
        switch need {
        case .dead: return String(localized: "NEW EGG")
        case .egg: return String(localized: "TAP OR WALK TO HATCH")
        case .sick: return String(localized: "GIVE MEDICINE")
        case .hungry: return String(localized: "FEED IT")
        case .poop: return String(localized: "FLUSH THE POOP")
        case .weak: return String(localized: "PROTEIN OR TRAIN")
        case .asleep: return String(localized: "SLEEPING")
        case .ok: return String(localized: "ALL GOOD")
        }
    }

    var needsYou: Bool {
        switch need {
        case .sick, .hungry, .poop, .weak, .dead: return true
        case .egg, .asleep, .ok: return false
        }
    }
}

// MARK: - Views

/// A pixel sprite scaled to fit the space it's given.
struct FittedSprite: View {
    let rows: [String]

    var body: some View {
        GeometryReader { geo in
            let cols = CGFloat(rows.map { $0.count }.max() ?? 1)
            let dot = min(geo.size.width / max(cols, 1), geo.size.height / CGFloat(max(rows.count, 1)))
            PixelSprite(rows: rows, dot: dot, color: .white)
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

struct CareComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CareEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                FittedSprite(rows: entry.sprite)
                    .padding(entry.needsYou ? 9 : 7)
                    .widgetAccentable(entry.needsYou)
            }
        case .accessoryCorner:
            FittedSprite(rows: entry.sprite)
                .padding(3)
                .widgetAccentable(entry.needsYou)
                .widgetLabel(entry.needsYou ? entry.shortText : entry.formName)
        case .accessoryInline:
            Label(entry.needsYou ? "\(entry.shortText) \(entry.actionText)" : "\(entry.formName) \(entry.actionText)",
                  systemImage: entry.needsYou ? "exclamationmark.triangle.fill" : "pawprint.fill")
        default:
            HStack(spacing: 6) {
                FittedSprite(rows: entry.sprite)
                    .frame(width: 44, height: 44)
                    .widgetAccentable(entry.needsYou)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.needsYou ? entry.shortText : entry.formName)
                        .font(.system(size: 15, weight: .heavy, design: .monospaced))
                        .widgetAccentable(entry.needsYou)
                    Text(entry.actionText)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    Text("WATCHTAMER")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Widget

@main
struct WatchTamerComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchTamerCare", provider: CareProvider()) { entry in
            CareComplicationView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("WatchTamer")
        .description("Shows what your dino needs most, or your dino when all is well.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}
