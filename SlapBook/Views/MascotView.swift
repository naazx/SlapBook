import SwiftUI

/// A tiny SwiftUI MacBook. It animates only when the model reports a reaction.
struct MascotView: View {
    let reactionID: Int
    var isMuted = false
    @State private var reacting = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let ink = Color(red: 0.29, green: 0.20, blue: 0.50)

    var body: some View {
        ZStack {
            Circle().fill(Color.purple.opacity(0.045)).frame(width: 200, height: 200)
            Circle().stroke(Color.purple.opacity(0.06), lineWidth: 1).frame(width: 184, height: 184)
            Ellipse().fill(ink.opacity(0.10)).frame(width: 215, height: 17).blur(radius: 7).offset(y: 75)
            VStack(spacing: -2) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(LinearGradient(colors: [Color(red: 0.75, green: 0.72, blue: 0.83), Color(red: 0.88, green: 0.86, blue: 0.93)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(ink.opacity(0.7), lineWidth: 2.5))
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [Color(red: 0.88, green: 0.84, blue: 1), Color(red: 0.95, green: 0.90, blue: 1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .padding(8).padding(.bottom, 4)
                    Circle().fill(ink.opacity(0.5)).frame(width: 3, height: 3).offset(y: -49)
                    face.offset(y: 4)
                    Path { p in
                        p.move(to: CGPoint(x: 22, y: 16)); p.addLine(to: CGPoint(x: 55, y: 16))
                        p.addLine(to: CGPoint(x: 22, y: 49)); p.closeSubpath()
                    }.fill(.white.opacity(0.27))
                }.frame(width: 180, height: 119)
                ZStack {
                    LaptopBase()
                        .fill(LinearGradient(colors: [Color(red: 0.91, green: 0.89, blue: 0.96), Color(red: 0.72, green: 0.69, blue: 0.82)], startPoint: .top, endPoint: .bottom))
                        .overlay(LaptopBase().stroke(ink.opacity(0.65), lineWidth: 2))
                    VStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { row in
                            HStack(spacing: 3) {
                                ForEach(0..<(row == 2 ? 8 : 10), id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 1).fill(ink.opacity(0.24)).frame(width: row == 2 ? 12 : 10, height: 3)
                                }
                            }
                        }
                        RoundedRectangle(cornerRadius: 2).stroke(ink.opacity(0.25), lineWidth: 0.8).frame(width: 37, height: 9)
                    }.offset(y: -3)
                    RoundedRectangle(cornerRadius: 2).fill(ink.opacity(0.24)).frame(width: 31, height: 2).offset(y: 19)
                }.frame(width: 224, height: 47)
            }
            .rotationEffect(.degrees(reacting && !reduceMotion ? -5 : 0))
            .scaleEffect(reacting && !reduceMotion ? 1.055 : 1)
            .offset(y: reacting && !reduceMotion ? -8 : 0)
            if reacting {
                Image(systemName: "sparkle").font(.system(size: 22)).foregroundStyle(.orange).offset(x: -111, y: -60).transition(.scale.combined(with: .opacity))
                Image(systemName: "sparkle").font(.system(size: 15)).foregroundStyle(.purple).offset(x: 108, y: -36).transition(.scale.combined(with: .opacity))
            }
        }
        .accessibilityElement(children: .ignore).accessibilityLabel(reacting ? "MacBook mascot reacting" : "A smiling MacBook mascot")
        .task(id: reactionID) {
            guard reactionID > 0 else { return }
            withAnimation(reduceMotion ? nil : .spring(response: 0.23, dampingFraction: 0.48)) { reacting = true }
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.6)) { reacting = false }
        }
    }

    private var face: some View {
        ZStack {
            HStack(spacing: 39) {
                Capsule().fill(ink).frame(width: 9, height: reacting ? 17 : 12)
                Capsule().fill(ink).frame(width: 9, height: reacting ? 17 : 12)
            }.offset(y: -7)
            HStack(spacing: 62) {
                Ellipse().fill(Color.pink.opacity(0.3)).frame(width: 20, height: 9)
                Ellipse().fill(Color.pink.opacity(0.3)).frame(width: 20, height: 9)
            }.offset(y: 8)
            if reacting && !isMuted {
                Ellipse().fill(ink).frame(width: 16, height: 21).offset(y: 19)
            } else {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 0)); p.addQuadCurve(to: CGPoint(x: 22, y: 0), control: CGPoint(x: 11, y: 15))
                }.stroke(ink, style: StrokeStyle(lineWidth: 3.5, lineCap: .round)).frame(width: 22, height: 12).offset(y: 19)
            }
        }
    }
}

private struct LaptopBase: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.width * 0.10, y: 0)); p.addLine(to: CGPoint(x: rect.width * 0.90, y: 0))
            p.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.76))
            p.addQuadCurve(to: CGPoint(x: rect.width * 0.96, y: rect.height), control: CGPoint(x: rect.width, y: rect.height))
            p.addLine(to: CGPoint(x: rect.width * 0.04, y: rect.height))
            p.addQuadCurve(to: CGPoint(x: 0, y: rect.height * 0.76), control: CGPoint(x: 0, y: rect.height))
            p.closeSubpath()
        }
    }
}
