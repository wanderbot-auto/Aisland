import SwiftUI
import AppKit

struct IslandPixelGlyph: View {
    var tint: Color
    var style: IslandPixelShapeStyle
    var isAnimating: Bool
    var width: CGFloat = 26
    var height: CGFloat = 14
    var customAvatarImage: NSImage? = nil

    var body: some View {
        if style == .custom, let avatar = customAvatarImage {
            Image(nsImage: avatar)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFill()
                .frame(width: min(width, height), height: min(width, height))
                .clipShape(Circle())
        } else if style.isPixelPet {
            pixelPetGlyph
        } else if style == .bars || style == .custom {
            AislandBrandMark(
                size: min(width, height),
                tint: tint,
                isAnimating: isAnimating,
                style: .duotone
            )
            .frame(width: width, height: height)
        } else if !style.chartFrames.isEmpty {
            TimelineView(.animation(minimumInterval: 0.18, paused: !isAnimating)) { context in
                let frame = style.chartFrames[frameIndex(for: context.date, frameCount: style.chartFrames.count)]

                HStack(alignment: .bottom, spacing: 3) {
                    PixelColumnCluster(heights: frame.0, tint: tint)
                    PixelColumnCluster(heights: frame.1, tint: tint)
                }
                .frame(width: width, height: height, alignment: .bottomLeading)
            }
        } else {
            AislandBrandMark(
                size: min(width, height),
                tint: tint,
                isAnimating: isAnimating,
                style: .duotone
            )
            .frame(width: width, height: height)
        }
    }

    private func frameIndex(for date: Date, frameCount: Int) -> Int {
        guard isAnimating else { return 0 }
        let ticks = Int(date.timeIntervalSinceReferenceDate / 0.18)
        return ticks % max(frameCount, 1)
    }

    @ViewBuilder
    private var pixelPetGlyph: some View {
        let petSize = min(width, height)
        let contentInset = max(2, petSize * 0.10)

        ZStack {
            if let petImage = style.pixelPetImage {
                petImage
                    .resizable()
                    .interpolation(.none)
                    .antialiased(false)
                    .scaledToFit()
                    .padding(contentInset)
                    .modifier(PixelPetIdleMotion(isAnimating: isAnimating, phaseOffset: style.petMotionPhaseOffset))
                    .shadow(color: tint.opacity(0.28), radius: 1.8, x: 0, y: 0)
            }
        }
        .frame(width: petSize, height: petSize)
    }
}

extension IslandPixelShapeStyle {
    var isPixelPet: Bool {
        pixelPetResourceName != nil
    }

    fileprivate var pixelPetImage: Image? {
        guard let resourceName = pixelPetResourceName,
              let url = Bundle.module.url(forResource: resourceName, withExtension: "png"),
              let image = NSImage(contentsOf: url)
        else {
            return nil
        }
        return Image(nsImage: image)
    }

    private var pixelPetResourceName: String? {
        switch self {
        case .kitten: "kitten"
        case .corgi: "corgi"
        case .puppy: "puppy"
        case .hamster: "hamster"
        case .bunny: "bunny"
        case .panda: "panda"
        case .bars, .steps, .blocks, .custom: nil
        }
    }

    fileprivate var petMotionPhaseOffset: Double {
        switch self {
        case .kitten: 0.0
        case .corgi: 0.1
        case .puppy: 0.2
        case .hamster: 0.35
        case .bunny: 0.5
        case .panda: 0.7
        case .bars, .steps, .blocks, .custom: 0
        }
    }

    fileprivate var chartFrames: [([Int], [Int])] {
        switch self {
        case .bars:
            [([1, 3, 2, 1], [2, 3, 1]),
             ([2, 2, 3, 1], [1, 2, 3]),
             ([1, 2, 1, 3], [3, 1, 2]),
             ([3, 1, 2, 2], [2, 3, 1])]
        case .steps:
            [([1, 2, 3, 4], [1, 2, 3]),
             ([2, 3, 4, 3], [2, 3, 2]),
             ([1, 2, 3, 4], [3, 2, 1]),
             ([2, 3, 2, 1], [2, 3, 4])]
        case .blocks:
            [([2, 4, 4, 2], [2, 4, 2]),
             ([3, 4, 3, 2], [3, 4, 2]),
             ([2, 3, 4, 3], [2, 4, 3]),
             ([2, 4, 3, 2], [3, 4, 2])]
        case .kitten, .corgi, .puppy, .hamster, .bunny, .panda:
            []
        case .custom:
            [([1, 3, 2, 1], [2, 3, 1])]
        }
    }
}

private struct PixelPetIdleMotion: ViewModifier {
    var isAnimating: Bool
    var phaseOffset: Double

    func body(content: Content) -> some View {
        if isAnimating {
            TimelineView(.animation(minimumInterval: 0.24)) { context in
                let phase = context.date.timeIntervalSinceReferenceDate + phaseOffset
                let tick = Int(phase / 0.24) % 4
                let yOffset: CGFloat = tick == 1 ? -1 : 0
                let xScale: CGFloat = tick == 2 ? 1.035 : 1
                let yScale: CGFloat = tick == 2 ? 0.965 : 1

                content
                    .offset(y: yOffset)
                    .scaleEffect(x: xScale, y: yScale, anchor: .bottom)
            }
        } else {
            content
        }
    }
}

private struct PixelColumnCluster: View {
    let heights: [Int]
    let tint: Color

    private let rows = 4
    private let pixelSize: CGFloat = 2.4
    private let pixelSpacing: CGFloat = 1.1

    var body: some View {
        HStack(alignment: .bottom, spacing: pixelSpacing) {
            ForEach(Array(heights.enumerated()), id: \.offset) { columnIndex, height in
                VStack(spacing: pixelSpacing) {
                    ForEach((0..<rows).reversed(), id: \.self) { row in
                        RoundedRectangle(cornerRadius: 0.4, style: .continuous)
                            .fill(row < height ? tint.opacity(0.45 + Double(row + 1) / Double(max(height, 1)) * 0.5) : .clear)
                            .frame(width: pixelSize, height: pixelSize)
                    }
                }
                .opacity(columnIndex == heights.count - 1 ? 0.86 : 1)
            }
        }
        .shadow(color: tint.opacity(0.55), radius: 2.2, x: 0, y: 0)
    }
}
