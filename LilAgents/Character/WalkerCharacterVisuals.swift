import AppKit
import Lottie

extension WalkerCharacter {
    private static let importedGuestArrivalEffectName = "fall-smoke-dust"
    private static let importedGuestArrivalEffectExtension = "json"

    func animatePersonaSwap() {
        guard let imageView else { return }
        imageView.alphaValue = 0.5
        imageView.wantsLayer = true
        imageView.layer?.transform = CATransform3DMakeScale(0.92, 0.92, 1.0)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            imageView.animator().alphaValue = 1.0
        }

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.28)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        imageView.layer?.transform = CATransform3DIdentity
        CATransaction.commit()
    }

    func playHandoffEffect(from previousPersona: WalkerPersona, to newPersona: WalkerPersona) {
        guard case .lenny = previousPersona else {
            if case .lenny = newPersona {
                showHandoffCloud(accent: NSColor(red: 0.96, green: 0.63, blue: 0.23, alpha: 1.0), trailing: true)
            } else {
                showHandoffCloud(accent: NSColor(red: 0.72, green: 0.9, blue: 1.0, alpha: 1.0), trailing: false)
            }
            return
        }

        switch newPersona {
        case .lenny:
            showHandoffCloud(accent: NSColor(red: 0.96, green: 0.63, blue: 0.23, alpha: 1.0), trailing: true)
        case .expert:
            if !showImportedGuestArrivalEffect() {
                showHandoffCloud(accent: NSColor(red: 0.72, green: 0.9, blue: 1.0, alpha: 1.0), trailing: false)
            }
        }
    }

    private func showImportedGuestArrivalEffect() -> Bool {
        guard let effectURL = Bundle.main.url(
            forResource: Self.importedGuestArrivalEffectName,
            withExtension: Self.importedGuestArrivalEffectExtension
        ) else {
            return false
        }

        guard let effectWindow = handoffEffectWindow ?? makeHandoffEffectWindow() else { return false }
        handoffEffectWindow = effectWindow
        guard let contentView = effectWindow.contentView else { return false }

        contentView.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        let animationView = configuredHandoffEffectAnimationView(in: contentView.bounds)
        animationView.frame = contentView.bounds
        if animationView.superview == nil {
            contentView.addSubview(animationView)
        }
        guard let animation = LottieAnimation.filepath(effectURL.path) else { return false }
        animationView.stop()
        animationView.animation = animation

        let charFrame = window.frame
        let effectSize: CGFloat = 200
        effectWindow.setFrame(
            CGRect(
                x: charFrame.midX - effectSize / 2,
                y: charFrame.midY - effectSize / 2 + 10,
                width: effectSize,
                height: effectSize
            ),
            display: false
        )
        effectWindow.orderFrontRegardless()
        animationView.play()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) { [weak self] in
            guard let self else { return }
            self.handoffEffectAnimationView?.stop()
            self.handoffEffectAnimationView?.removeFromSuperview()
            self.handoffEffectWindow?.orderOut(nil)
            self.handoffEffectWindow?.contentView?.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        }

        return true
    }

    private func configuredHandoffEffectAnimationView(in frame: CGRect) -> LottieAnimationView {
        if let handoffEffectAnimationView {
            handoffEffectAnimationView.frame = frame
            return handoffEffectAnimationView
        }

        let animationView = LottieAnimationView(frame: frame)
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.loopMode = .playOnce
        animationView.autoresizingMask = [.width, .height]
        handoffEffectAnimationView = animationView
        return animationView
    }

    private func showHandoffCloud(accent: NSColor, trailing: Bool) {
        guard let effectWindow = handoffEffectWindow ?? makeHandoffEffectWindow() else { return }
        handoffEffectWindow = effectWindow
        guard let contentView = effectWindow.contentView else { return }

        handoffEffectAnimationView?.stop()
        handoffEffectAnimationView?.removeFromSuperview()
        contentView.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        contentView.alphaValue = 1.0

        let charFrame = window.frame
        let effectSize: CGFloat = 188
        effectWindow.setFrame(
            CGRect(
                x: charFrame.midX - effectSize / 2,
                y: charFrame.midY - effectSize / 2 + 8,
                width: effectSize,
                height: effectSize
            ),
            display: false
        )
        effectWindow.orderFrontRegardless()

        let smokeColor = accent.usingColorSpace(.deviceRGB) ?? accent
        let puffSpecs: [(CGPoint, CGFloat, CFTimeInterval)] = [
            (CGPoint(x: 50, y: 88), 34, 0.00),
            (CGPoint(x: 78, y: 118), 44, 0.04),
            (CGPoint(x: 114, y: 104), 40, 0.08),
            (CGPoint(x: 134, y: 82), 32, 0.12),
            (CGPoint(x: 94, y: 72), 54, 0.16),
            (CGPoint(x: 64, y: 58), 26, 0.20),
            (CGPoint(x: 126, y: 54), 24, 0.24)
        ]

        for (index, spec) in puffSpecs.enumerated() {
            let puff = CAShapeLayer()
            let origin = CGPoint(x: spec.0.x - spec.1 / 2, y: spec.0.y - spec.1 / 2)
            puff.path = CGPath(ellipseIn: CGRect(origin: origin, size: CGSize(width: spec.1, height: spec.1)), transform: nil)
            let alpha = trailing ? 0.26 : 0.18
            puff.fillColor = smokeColor.withAlphaComponent(alpha).cgColor
            puff.strokeColor = smokeColor.withAlphaComponent(trailing ? 0.42 : 0.32).cgColor
            puff.lineWidth = trailing ? 1.4 : 1.0
            puff.opacity = 0.0
            puff.transform = CATransform3DMakeScale(0.35, 0.35, 1.0)
            contentView.layer?.addSublayer(puff)

            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = [0.0, 0.95, trailing ? 0.5 : 0.3, 0.0]
            opacity.keyTimes = [0.0, 0.18, 0.55, 1.0]
            opacity.duration = 0.62
            opacity.beginTime = CACurrentMediaTime() + spec.2
            opacity.fillMode = .forwards
            opacity.isRemovedOnCompletion = false

            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 0.35
            scale.toValue = trailing ? 1.8 : 1.45
            scale.duration = 0.62
            scale.beginTime = opacity.beginTime
            scale.timingFunction = CAMediaTimingFunction(name: .easeOut)
            scale.fillMode = .forwards
            scale.isRemovedOnCompletion = false

            let drift = CABasicAnimation(keyPath: "position")
            drift.fromValue = NSValue(point: spec.0)
            let direction: CGFloat = trailing ? -12 : 14
            let verticalLift: CGFloat = trailing ? 18 : 28
            drift.toValue = NSValue(point: CGPoint(x: spec.0.x + direction + CGFloat(index * 2), y: spec.0.y + verticalLift))
            drift.duration = 0.62
            drift.beginTime = opacity.beginTime
            drift.timingFunction = CAMediaTimingFunction(name: .easeOut)
            drift.fillMode = .forwards
            drift.isRemovedOnCompletion = false

            puff.add(opacity, forKey: "opacity")
            puff.add(scale, forKey: "scale")
            puff.add(drift, forKey: "drift")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) { [weak self] in
            guard let self else { return }
            self.handoffEffectWindow?.orderOut(nil)
            self.handoffEffectWindow?.contentView?.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        }
    }

    private func makeHandoffEffectWindow() -> NSWindow? {
        let win = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 188, height: 188),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 6)
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let view = NSView(frame: NSRect(x: 0, y: 0, width: 188, height: 188))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        win.contentView = view
        return win
    }
}
