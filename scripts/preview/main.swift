import SwiftUI
import AppKit

// Renders Fluffy's face in each mood to PNGs, using the phone's real drawing code.
struct Shot { let name: String; let frame: FaceAnimator.Frame }
func frame(_ mood: Mood, talk: Double = 0, closed: Double = 0, pupil: Double = 1, lift: Double = 0, tilt: Double = 0,
           blush: Double = 0.25, squint: Double = 0, gaze: CGPoint = .zero, time: Double = 1.2) -> FaceAnimator.Frame {
    .init(gaze: gaze, mood: mood, talk: talk, closed: closed, breathe: 0, time: time, pupil: pupil, browLift: lift,
          browTilt: tilt, lean: -gaze.x * 0.045, hop: 0, blush: blush, squint: squint)
}

@main
struct Preview {
    @MainActor static func main() {
        let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/previews/fluffy")
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        let shots = [
            Shot(name: "listening", frame: frame(.listening, pupil: 1.12, lift: 10, gaze: CGPoint(x: -0.3, y: 0.2))),
            Shot(name: "talking", frame: frame(.talking, talk: 0.7, pupil: 1.05, lift: 16)),
            Shot(name: "pointing", frame: frame(.pointing, pupil: 0.95, lift: -4, tilt: -0.14, gaze: CGPoint(x: 0.8, y: -0.4))),
            Shot(name: "thinking", frame: frame(.thinking, pupil: 0.9, lift: 4, tilt: 0.22, gaze: CGPoint(x: 0.6, y: -0.85))),
            Shot(name: "happy", frame: frame(.happy, pupil: 1.2, lift: 16, blush: 0.85, squint: 1)),
            Shot(name: "resting", frame: frame(.resting, pupil: 0.9, lift: -8, blush: 0.15, time: 0.6)),
            Shot(name: "sleepy", frame: frame(.sleepy, pupil: 0.88, lift: -10, tilt: 0.12, blush: 0.15, gaze: CGPoint(x: 0, y: 0.4))),
        ]

        // An iPhone 12 Pro Max in landscape, in points.
        let size = CGSize(width: 926, height: 428)
        do {
            for shot in shots {
                let view = Canvas { ctx, s in FaceView.draw(shot.frame, in: &ctx, size: s) }.frame(width: size.width, height: size.height)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2
                guard let image = renderer.cgImage else { print("failed", shot.name); continue }
                let rep = NSBitmapImageRep(cgImage: image)
                try! rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent("\(shot.name).png"))
                print("wrote", shot.name)
            }
            // His head on its own, for icons.
            let happy = shots.first { $0.name == "happy" }!.frame
            let icon = Canvas { ctx, s in FaceView.drawIcon(happy, in: &ctx, size: s) }.frame(width: 512, height: 512)
            let renderer = ImageRenderer(content: icon)
            renderer.scale = 1
            if let image = renderer.cgImage {
                try! NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
                    .write(to: out.appendingPathComponent("icon.png"))
                print("wrote icon")
            }
        }
    }
}
