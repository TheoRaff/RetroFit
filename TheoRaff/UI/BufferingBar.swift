import SwiftUI

/// The "Buffering…" box shown while the AI render runs: a small Windows progress dialog
/// with a row of navy blocks sweeping along a sunken track.
struct BufferingBar: View {
    let text: String

    private let blockWidth: CGFloat = 10
    private let blockGap: CGFloat = 2
    private let blockCount = 6
    /// Points per second the blocks travel.
    private let speed: CGFloat = 120

    var body: some View {
        VStack(spacing: 0) {
            Win95TitleBar(title: "Buffering…", height: 32, centred: false)
            VStack(alignment: .leading, spacing: 10) {
                Text(text)
                    .font(Win95.font(14))
                    .foregroundStyle(Win95.text)
                track
            }
            .padding(12)
        }
        .padding(2)
        .win95Raised()
        .frame(maxWidth: 320)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var track: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let groupWidth = CGFloat(blockCount) * (blockWidth + blockGap)
                let travel = size.width + groupWidth
                let elapsed = CGFloat(timeline.date.timeIntervalSinceReferenceDate)
                let start = (elapsed * speed).truncatingRemainder(dividingBy: travel) - groupWidth
                for index in 0..<blockCount {
                    let x = start + CGFloat(index) * (blockWidth + blockGap)
                    let block = CGRect(x: x, y: 1, width: blockWidth, height: size.height - 2)
                    context.fill(Path(block), with: .color(Win95.navy))
                }
            }
        }
        .frame(height: 20)
        .padding(1)
        .clipShape(RoundedRectangle(cornerRadius: Win95.cornerRadius, style: .continuous))
        .background(Win95.face, in: RoundedRectangle(cornerRadius: Win95.cornerRadius, style: .continuous))
        .overlay(Win95Bevel(style: .thinSunken))
    }
}
