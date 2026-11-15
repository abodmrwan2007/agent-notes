import UIKit

/// The built-in sticker pack. Every sticker is ORIGINAL artwork drawn in code in this file
/// (paths, fills and system-font lettering); no third-party images, icon sets or SF Symbols are
/// used, so the pack can be exported inside user documents. See docs/ASSET_LICENSES.md.
///
/// Stickers are drawn on a 256 × 256 canvas (banners on 256 × 96) and rendered to a transparent
/// PNG when inserted, so a notebook stays self-contained and looks the same everywhere.
enum Sticker: String, CaseIterable, Identifiable {
    case star
    case heart
    case check
    case warning
    case question
    case idea
    case pill
    case dna
    case flask
    case pulse
    case bone
    case arrow
    case importantEN
    case importantAR
    case examEN
    case examAR
    case reviewEN
    case reviewAR

    var id: String { rawValue }

    var isBanner: Bool {
        switch self {
        case .importantEN, .importantAR, .examEN, .examAR, .reviewEN, .reviewAR: return true
        default: return false
        }
    }

    /// Size of the drawing canvas, in points. Also the default size on the page.
    var canvas: CGSize { isBanner ? CGSize(width: 256, height: 96) : CGSize(width: 256, height: 256) }
    var pageSize: CGSize { isBanner ? CGSize(width: 180, height: 68) : CGSize(width: 96, height: 96) }

    /// Accessibility name (localized).
    var accessibilityName: String {
        switch self {
        case .star: return String(localized: "Star")
        case .heart: return String(localized: "Heart")
        case .check: return String(localized: "Check mark")
        case .warning: return String(localized: "Warning")
        case .question: return String(localized: "Question")
        case .idea: return String(localized: "Idea")
        case .pill: return String(localized: "Capsule")
        case .dna: return String(localized: "DNA")
        case .flask: return String(localized: "Flask")
        case .pulse: return String(localized: "Heartbeat")
        case .bone: return String(localized: "Bone")
        case .arrow: return String(localized: "Arrow")
        case .importantEN, .importantAR: return String(localized: "Important")
        case .examEN, .examAR: return String(localized: "Exam")
        case .reviewEN, .reviewAR: return String(localized: "Review")
        }
    }

    // MARK: Rendering

    func image(scale: CGFloat = 3) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: canvas, format: format).image { renderer in
            draw(in: renderer.cgContext)
        }
    }

    func pngData() -> Data? {
        image().pngData()
    }

    // MARK: Palette

    private static let ink = UIColor(red: 0.07, green: 0.13, blue: 0.27, alpha: 1)
    private static let yellow = UIColor(red: 1.00, green: 0.80, blue: 0.20, alpha: 1)
    private static let red = UIColor(red: 0.90, green: 0.25, blue: 0.30, alpha: 1)
    private static let green = UIColor(red: 0.20, green: 0.70, blue: 0.40, alpha: 1)
    private static let orange = UIColor(red: 0.98, green: 0.58, blue: 0.15, alpha: 1)
    private static let blue = UIColor(red: 0.20, green: 0.55, blue: 0.95, alpha: 1)
    private static let cyan = UIColor(red: 0.00, green: 0.62, blue: 0.80, alpha: 1)
    private static let cream = UIColor(red: 1.00, green: 0.97, blue: 0.88, alpha: 1)
    private static let lineWidth: CGFloat = 9

    private func fillAndOutline(_ path: UIBezierPath, fill: UIColor) {
        fill.setFill()
        path.fill()
        Self.ink.setStroke()
        path.lineWidth = Self.lineWidth
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.stroke()
    }

    private func outline(_ path: UIBezierPath, width: CGFloat = Sticker.lineWidth, color: UIColor = Sticker.ink) {
        color.setStroke()
        path.lineWidth = width
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.stroke()
    }

    private func draw(in context: CGContext) {
        switch self {
        case .star: drawStar()
        case .heart: drawHeart()
        case .check: drawCheck()
        case .warning: drawWarning()
        case .question: drawQuestion()
        case .idea: drawIdea()
        case .pill: drawPill(in: context)
        case .dna: drawDNA()
        case .flask: drawFlask()
        case .pulse: drawPulse()
        case .bone: drawBone()
        case .arrow: drawArrow()
        case .importantEN: drawBanner("IMPORTANT", color: Self.red, rightToLeft: false)
        case .importantAR: drawBanner("مهم", color: Self.red, rightToLeft: true)
        case .examEN: drawBanner("EXAM", color: Self.ink, rightToLeft: false)
        case .examAR: drawBanner("امتحان", color: Self.ink, rightToLeft: true)
        case .reviewEN: drawBanner("REVIEW", color: Self.cyan, rightToLeft: false)
        case .reviewAR: drawBanner("مراجعة", color: Self.cyan, rightToLeft: true)
        }
    }

    // MARK: Drawings

    private func drawStar() {
        let center = CGPoint(x: 128, y: 136)
        let path = UIBezierPath()
        for index in 0..<10 {
            let radius: CGFloat = index.isMultiple(of: 2) ? 112 : 48
            let angle = CGFloat(index) * .pi / 5 - .pi / 2
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.close()
        fillAndOutline(path, fill: Self.yellow)
        // A small shine.
        let shine = UIBezierPath(ovalIn: CGRect(x: 104, y: 98, width: 18, height: 10))
        UIColor.white.withAlphaComponent(0.8).setFill()
        shine.fill()
    }

    private func heartPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + h * 0.95))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + h * 0.32),
            controlPoint1: CGPoint(x: rect.minX + w * 0.25, y: rect.minY + h * 0.75),
            controlPoint2: CGPoint(x: rect.minX, y: rect.minY + h * 0.55))
        path.addArc(
            withCenter: CGPoint(x: rect.minX + w * 0.25, y: rect.minY + h * 0.30),
            radius: w * 0.25, startAngle: .pi, endAngle: 0, clockwise: true)
        path.addArc(
            withCenter: CGPoint(x: rect.minX + w * 0.75, y: rect.minY + h * 0.30),
            radius: w * 0.25, startAngle: .pi, endAngle: 0, clockwise: true)
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY + h * 0.95),
            controlPoint1: CGPoint(x: rect.maxX, y: rect.minY + h * 0.55),
            controlPoint2: CGPoint(x: rect.minX + w * 0.75, y: rect.minY + h * 0.75))
        path.close()
        return path
    }

    private func drawHeart() {
        fillAndOutline(heartPath(in: CGRect(x: 28, y: 40, width: 200, height: 190)), fill: Self.red)
        let shine = UIBezierPath(ovalIn: CGRect(x: 62, y: 76, width: 30, height: 18))
        UIColor.white.withAlphaComponent(0.7).setFill()
        shine.fill()
    }

    private func drawCheck() {
        fillAndOutline(UIBezierPath(ovalIn: CGRect(x: 24, y: 24, width: 208, height: 208)), fill: Self.green)
        let tick = UIBezierPath()
        tick.move(to: CGPoint(x: 74, y: 132))
        tick.addLine(to: CGPoint(x: 112, y: 170))
        tick.addLine(to: CGPoint(x: 184, y: 90))
        outline(tick, width: 22, color: .white)
    }

    private func drawWarning() {
        let triangle = UIBezierPath()
        triangle.move(to: CGPoint(x: 128, y: 26))
        triangle.addLine(to: CGPoint(x: 234, y: 222))
        triangle.addLine(to: CGPoint(x: 22, y: 222))
        triangle.close()
        fillAndOutline(triangle, fill: Self.orange)
        let bar = UIBezierPath(roundedRect: CGRect(x: 117, y: 92, width: 22, height: 74), cornerRadius: 11)
        Self.ink.setFill()
        bar.fill()
        UIBezierPath(ovalIn: CGRect(x: 116, y: 178, width: 24, height: 24)).fill()
    }

    private func drawQuestion() {
        let bubble = UIBezierPath(roundedRect: CGRect(x: 24, y: 28, width: 208, height: 168), cornerRadius: 44)
        bubble.move(to: CGPoint(x: 70, y: 194))
        bubble.addLine(to: CGPoint(x: 56, y: 236))
        bubble.addLine(to: CGPoint(x: 112, y: 196))
        fillAndOutline(bubble, fill: Self.blue)
        let mark = NSAttributedString(string: "?", attributes: [
            .font: UIFont.systemFont(ofSize: 132, weight: .heavy),
            .foregroundColor: UIColor.white
        ])
        let size = mark.size()
        mark.draw(at: CGPoint(x: 128 - size.width / 2, y: 112 - size.height / 2))
    }

    private func drawIdea() {
        let bulb = UIBezierPath(arcCenter: CGPoint(x: 128, y: 104), radius: 72,
                                startAngle: .pi * 0.8, endAngle: .pi * 0.2, clockwise: true)
        bulb.addLine(to: CGPoint(x: 156, y: 196))
        bulb.addLine(to: CGPoint(x: 100, y: 196))
        bulb.close()
        fillAndOutline(bulb, fill: Self.yellow)
        let base = UIBezierPath(roundedRect: CGRect(x: 98, y: 200, width: 60, height: 34), cornerRadius: 10)
        fillAndOutline(base, fill: UIColor(white: 0.75, alpha: 1))
        // Rays.
        for angle in stride(from: -150.0, through: -30.0, by: 30.0) {
            let radians = CGFloat(angle) * .pi / 180
            let ray = UIBezierPath()
            ray.move(to: CGPoint(x: 128 + 92 * cos(radians), y: 104 + 92 * sin(radians)))
            ray.addLine(to: CGPoint(x: 128 + 116 * cos(radians), y: 104 + 116 * sin(radians)))
            outline(ray, width: 9, color: Self.orange)
        }
    }

    private func drawPill(in context: CGContext) {
        context.saveGState()
        context.translateBy(x: 128, y: 128)
        context.rotate(by: -.pi / 4)
        context.translateBy(x: -128, y: -128)
        let body = CGRect(x: 32, y: 88, width: 192, height: 80)
        let left = UIBezierPath(roundedRect: CGRect(x: body.minX, y: body.minY, width: body.width / 2, height: body.height),
                                byRoundingCorners: [.topLeft, .bottomLeft], cornerRadii: CGSize(width: 40, height: 40))
        let right = UIBezierPath(roundedRect: CGRect(x: body.midX, y: body.minY, width: body.width / 2, height: body.height),
                                 byRoundingCorners: [.topRight, .bottomRight], cornerRadii: CGSize(width: 40, height: 40))
        fillAndOutline(left, fill: Self.red)
        fillAndOutline(right, fill: Self.cream)
        context.restoreGState()
    }

    private func drawDNA() {
        var strandA: [CGPoint] = []
        var strandB: [CGPoint] = []
        for step in 0...48 {
            let t = CGFloat(step) / 48
            let y = 24 + t * 208
            let phase = t * .pi * 3
            strandA.append(CGPoint(x: 128 + 64 * sin(phase), y: y))
            strandB.append(CGPoint(x: 128 - 64 * sin(phase), y: y))
        }
        // Rungs first, then the two strands over them.
        for step in stride(from: 2, to: 48, by: 4) {
            let rung = UIBezierPath()
            rung.move(to: strandA[step])
            rung.addLine(to: strandB[step])
            outline(rung, width: 7, color: step % 8 == 2 ? Self.cyan : Self.orange)
        }
        for (strand, color) in [(strandA, Self.blue), (strandB, Self.red)] {
            let path = UIBezierPath()
            path.move(to: strand[0])
            strand.dropFirst().forEach { path.addLine(to: $0) }
            outline(path, width: 14, color: color)
        }
    }

    private func drawFlask() {
        let flask = UIBezierPath()
        flask.move(to: CGPoint(x: 104, y: 30))
        flask.addLine(to: CGPoint(x: 104, y: 104))
        flask.addLine(to: CGPoint(x: 40, y: 212))
        flask.addQuadCurve(to: CGPoint(x: 60, y: 232), controlPoint: CGPoint(x: 36, y: 232))
        flask.addLine(to: CGPoint(x: 196, y: 232))
        flask.addQuadCurve(to: CGPoint(x: 216, y: 212), controlPoint: CGPoint(x: 220, y: 232))
        flask.addLine(to: CGPoint(x: 152, y: 104))
        flask.addLine(to: CGPoint(x: 152, y: 30))
        flask.close()
        UIColor(white: 0.97, alpha: 1).setFill()
        flask.fill()
        // Liquid.
        let liquid = UIBezierPath()
        liquid.move(to: CGPoint(x: 76, y: 160))
        liquid.addLine(to: CGPoint(x: 180, y: 160))
        liquid.addLine(to: CGPoint(x: 216, y: 212))
        liquid.addQuadCurve(to: CGPoint(x: 196, y: 232), controlPoint: CGPoint(x: 220, y: 232))
        liquid.addLine(to: CGPoint(x: 60, y: 232))
        liquid.addQuadCurve(to: CGPoint(x: 40, y: 212), controlPoint: CGPoint(x: 36, y: 232))
        liquid.close()
        Self.green.setFill()
        liquid.fill()
        for (x, y, r) in [(112.0, 196.0, 9.0), (140.0, 184.0, 6.0), (160.0, 206.0, 7.0)] {
            UIColor.white.withAlphaComponent(0.8).setFill()
            UIBezierPath(ovalIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)).fill()
        }
        outline(flask)
        let rim = UIBezierPath()
        rim.move(to: CGPoint(x: 92, y: 30))
        rim.addLine(to: CGPoint(x: 164, y: 30))
        outline(rim)
    }

    private func drawPulse() {
        let heart = heartPath(in: CGRect(x: 48, y: 40, width: 160, height: 150))
        fillAndOutline(heart, fill: Self.red.withAlphaComponent(0.18))
        let line = UIBezierPath()
        line.move(to: CGPoint(x: 16, y: 140))
        line.addLine(to: CGPoint(x: 84, y: 140))
        line.addLine(to: CGPoint(x: 104, y: 92))
        line.addLine(to: CGPoint(x: 132, y: 200))
        line.addLine(to: CGPoint(x: 156, y: 110))
        line.addLine(to: CGPoint(x: 172, y: 140))
        line.addLine(to: CGPoint(x: 240, y: 140))
        outline(line, width: 12, color: Self.red)
    }

    private func drawBone() {
        let path = UIBezierPath()
        let knobs = [CGPoint(x: 62, y: 74), CGPoint(x: 74, y: 52), CGPoint(x: 194, y: 182), CGPoint(x: 182, y: 204)]
        // Shaft.
        let shaft = UIBezierPath()
        shaft.move(to: CGPoint(x: 72, y: 68))
        shaft.addLine(to: CGPoint(x: 188, y: 188))
        shaft.lineWidth = 46
        shaft.lineCapStyle = .butt
        Self.ink.setStroke()
        shaft.lineWidth = 46 + Self.lineWidth * 2
        shaft.stroke()
        for knob in knobs {
            path.append(UIBezierPath(ovalIn: CGRect(x: knob.x - 30, y: knob.y - 30, width: 60, height: 60)))
        }
        fillAndOutline(path, fill: Self.cream)
        Self.cream.setStroke()
        shaft.lineWidth = 46
        shaft.stroke()
    }

    private func drawArrow() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 40, y: 200))
        path.addCurve(to: CGPoint(x: 176, y: 76),
                      controlPoint1: CGPoint(x: 52, y: 120), controlPoint2: CGPoint(x: 112, y: 76))
        outline(path, width: 22, color: Self.cyan)
        let head = UIBezierPath()
        head.move(to: CGPoint(x: 226, y: 76))
        head.addLine(to: CGPoint(x: 166, y: 30))
        head.addLine(to: CGPoint(x: 166, y: 122))
        head.close()
        Self.cyan.setFill()
        head.fill()
        Self.cyan.setStroke()
        head.lineWidth = 6
        head.lineJoinStyle = .round
        head.stroke()
    }

    private func drawBanner(_ text: String, color: UIColor, rightToLeft: Bool) {
        let ribbon = UIBezierPath()
        ribbon.move(to: CGPoint(x: 10, y: 12))
        ribbon.addLine(to: CGPoint(x: 246, y: 12))
        ribbon.addLine(to: CGPoint(x: 228, y: 48))
        ribbon.addLine(to: CGPoint(x: 246, y: 84))
        ribbon.addLine(to: CGPoint(x: 10, y: 84))
        ribbon.addLine(to: CGPoint(x: 28, y: 48))
        ribbon.close()
        color.setFill()
        ribbon.fill()
        UIColor.black.withAlphaComponent(0.18).setStroke()
        ribbon.lineWidth = 3
        ribbon.stroke()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.baseWritingDirection = rightToLeft ? .rightToLeft : .leftToRight
        let label = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: rightToLeft ? 44 : 36, weight: .heavy),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraph,
            .kern: rightToLeft ? 0 : 2
        ])
        let height = label.boundingRect(with: CGSize(width: 200, height: 96), options: .usesLineFragmentOrigin, context: nil).height
        label.draw(with: CGRect(x: 28, y: 48 - height / 2, width: 200, height: height), options: .usesLineFragmentOrigin, context: nil)
    }
}
