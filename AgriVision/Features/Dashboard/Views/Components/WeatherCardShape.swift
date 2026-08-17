import SwiftUI

struct WeatherCardShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerRadius: CGFloat = 30
        let slantDrop: CGFloat = 40 // How far down the right side drops
        
        // Start top-left (flush with screen)
        path.move(to: CGPoint(x: 0, y: 0))
        
        // Line down to top-right slanted point
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: slantDrop))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: slantDrop + cornerRadius), control: CGPoint(x: rect.maxX, y: slantDrop))
        
        // Right edge down
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        
        // Bottom edge left to edge of screen
        path.addLine(to: CGPoint(x: 0, y: rect.maxY))
        
        path.closeSubpath()
        return path
    }
}
