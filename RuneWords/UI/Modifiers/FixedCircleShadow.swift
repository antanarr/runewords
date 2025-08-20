import SwiftUI

/// A fast shadow for circular/rounded controls that sets CALayer.shadowPath.
public struct FixedCircleShadow: ViewModifier {
    var color: UIColor = UIColor.black.withAlphaComponent(0.35)
    var blur: CGFloat = 8
    var x: CGFloat = 0
    var y: CGFloat = 4
    var cornerRadius: CGFloat? = nil   // if nil, we treat width/2 as a circle
    
    public func body(content: Content) -> some View {
        content.background(ShadowHost(color: color, blur: blur, x: x, y: y, cornerRadius: cornerRadius))
    }
    
    private struct ShadowHost: UIViewRepresentable {
        var color: UIColor
        var blur: CGFloat
        var x: CGFloat
        var y: CGFloat
        var cornerRadius: CGFloat?
        
        func makeUIView(context: Context) -> ShadowView { 
            ShadowView() 
        }
        
        func updateUIView(_ v: ShadowView, context: Context) {
            v.configure(color: color, blur: blur, x: x, y: y, cornerRadius: cornerRadius)
        }
        
        final class ShadowView: UIView {
            override class var layerClass: AnyClass { CALayer.self }
            private var configured = false
            
            override func layoutSubviews() {
                super.layoutSubviews()
                guard configured else { return }
                let r = layer.cornerRadius
                layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: r).cgPath
            }
            
            func configure(color: UIColor, blur: CGFloat, x: CGFloat, y: CGFloat, cornerRadius: CGFloat?) {
                isUserInteractionEnabled = false
                layer.masksToBounds = false
                // If cornerRadius not provided, assume circle
                let r = cornerRadius ?? (min(bounds.width, bounds.height) * 0.5)
                layer.cornerRadius = r
                layer.shadowColor = color.cgColor
                layer.shadowOpacity = 1
                layer.shadowRadius = blur
                layer.shadowOffset = CGSize(width: x, height: y)
                layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: r).cgPath
                // cache for scrolling/animation
                layer.shouldRasterize = true
                layer.rasterizationScale = UIScreen.main.scale
                configured = true
            }
        }
    }
}

public extension View {
    /// Fast drop shadow for circular chips/buttons/tiles.
    func fixedCircleShadow(
        color: Color = .black.opacity(0.35), 
        blur: CGFloat = 8, 
        x: CGFloat = 0, 
        y: CGFloat = 4, 
        cornerRadius: CGFloat? = nil
    ) -> some View {
        modifier(FixedCircleShadow(color: UIColor(color), blur: blur, x: x, y: y, cornerRadius: cornerRadius))
    }
}
