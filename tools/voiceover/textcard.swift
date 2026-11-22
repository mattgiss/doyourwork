// Renders one line of text to a transparent PNG, for the ad's caption cards (this Mac's ffmpeg has no text filter).
//
//   swift textcard.swift <font.ttf> <size> <style: card|white|ink|orange> <out.png> <text>
//
// "card" draws dark text on a white rounded box, "pill" white text on a dark plum pill; the others
// draw the text alone in that colour.
import AppKit
import CoreText

let a = CommandLine.arguments
let fontURL = URL(fileURLWithPath: a[1]), size = CGFloat(Double(a[2])!), style = a[3], out = a[4]
let text = a[5...].joined(separator: " ")

CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
let descs = CTFontManagerCreateFontDescriptorsFromURL(fontURL as CFURL) as! [CTFontDescriptor]
let font = CTFontCreateWithFontDescriptor(descs[0], size, nil)

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
}
let ink = color(0x2B2340)
let fg: NSColor = ["white": .white, "pill": .white, "orange": color(0xE2751C), "ink": ink][style] ?? ink
let str = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: fg])
let textSize = str.size()
let pad: CGFloat = (style == "card" || style == "pill") ? size * 0.6 : 4
let w = ceil(textSize.width + pad * 2), h = ceil(textSize.height + pad * 1.4)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(w), pixelsHigh: Int(h), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
if style == "card" || style == "pill" {
    (style == "pill" ? color(0x1D1530).withAlphaComponent(0.9) : NSColor.white.withAlphaComponent(0.95)).setFill()
    NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: w, height: h), xRadius: h / 2, yRadius: h / 2).fill()
}
str.draw(at: NSPoint(x: pad, y: (h - textSize.height) / 2))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
