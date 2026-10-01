//
//  DinoSpriteView.swift
//  WatchTamer Watch App
//
//  Draws the dot-matrix LCD: palettes, pixel sprites, hearts and bars.
//

import SwiftUI

// MARK: - LCD palette

struct LCDPalette {
    let screen: Color
    let dot: Color
    let ghost: Color
    let bezel: Color

    /// Grey-green 90s LCD with dark dots.
    static let classic = LCDPalette(
        screen: Color(red: 0.61, green: 0.67, blue: 0.50),
        dot: Color(red: 0.13, green: 0.16, blue: 0.11),
        ghost: Color(red: 0.13, green: 0.16, blue: 0.11).opacity(0.07),
        bezel: Color(red: 0.36, green: 0.40, blue: 0.30)
    )

    /// Black screen with glowing green dots.
    static let night = LCDPalette(
        screen: Color.black,
        dot: Color(red: 0.25, green: 0.95, blue: 0.45),
        ghost: Color(red: 0.25, green: 0.95, blue: 0.45).opacity(0.08),
        bezel: Color(red: 0.12, green: 0.45, blue: 0.22)
    )

    static func current(night: Bool) -> LCDPalette { night ? .night : .classic }
}

// MARK: - Pixel sprite

struct PixelSprite: View {
    let rows: [String]
    let dot: CGFloat
    let color: Color
    var flipped = false

    private var columns: Int { rows.map { $0.count }.max() ?? 0 }

    var body: some View {
        let w = columns
        Canvas { ctx, _ in
            for (y, row) in rows.enumerated() {
                for (x, ch) in row.enumerated() where ch == "#" {
                    let col = flipped ? (w - 1 - x) : x
                    let rect = CGRect(x: CGFloat(col) * dot, y: CGFloat(y) * dot,
                                      width: dot * 0.88, height: dot * 0.88)
                    ctx.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: CGFloat(w) * dot, height: CGFloat(rows.count) * dot)
    }
}

/// A creature from PixelArt.creatures. Creatures face LEFT unless `facingRight`.
struct DinoSprite: View {
    let key: String
    var frame: Int = 0
    let dot: CGFloat
    let color: Color
    var facingRight = false

    static func rows(_ key: String, frame: Int) -> [String] {
        guard let frames = PixelArt.creatures[key], !frames.isEmpty else { return [] }
        return frames[min(max(frame, 0), frames.count - 1)]
    }

    var body: some View {
        PixelSprite(rows: DinoSprite.rows(key, frame: frame), dot: dot, color: color, flipped: facingRight)
    }
}

// MARK: - Hearts & bars

struct HeartsRow: View {
    let filled: Int
    var total: Int = 4
    let dot: CGFloat
    let color: Color

    var body: some View {
        HStack(spacing: dot) {
            ForEach(0..<total, id: \.self) { i in
                PixelSprite(rows: i < filled ? PixelArt.heart : PixelArt.heartEmpty, dot: dot, color: color)
            }
        }
    }
}

struct LCDBar: View {
    let progress: Double
    let color: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().stroke(color, lineWidth: 1)
                Rectangle()
                    .fill(color)
                    .frame(width: max(0, min(1, progress)) * max(0, geo.size.width - 4))
                    .padding(2)
            }
        }
        .frame(height: height)
    }
}

/// Faint dot grid so the screen reads as an LCD.
struct LCDGrid: View {
    let dot: CGFloat
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            guard dot >= 2 else { return }
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    ctx.fill(Path(CGRect(x: x, y: y, width: dot * 0.88, height: dot * 0.88)), with: .color(color))
                    x += dot
                }
                y += dot
            }
        }
        .allowsHitTesting(false)
    }
}
