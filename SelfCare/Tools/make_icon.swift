import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue
let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: size * 4,
    space: colorSpace,
    bitmapInfo: bitmapInfo
)!

let background = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        CGColor(red: 0.08, green: 0.09, blue: 0.20, alpha: 1),
        CGColor(red: 0.04, green: 0.03, blue: 0.09, alpha: 1)
    ] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(
    background,
    start: CGPoint(x: 0, y: size),
    end: CGPoint(x: size, y: 0),
    options: []
)

let discRect = CGRect(x: 218, y: 218, width: 588, height: 588)
context.saveGState()
context.addEllipse(in: discRect)
context.clip()
let disc = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        CGColor(red: 0.98, green: 0.48, blue: 0.29, alpha: 1),
        CGColor(red: 0.77, green: 0.42, blue: 0.13, alpha: 1)
    ] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(
    disc,
    start: CGPoint(x: discRect.minX, y: discRect.maxY),
    end: CGPoint(x: discRect.maxX, y: discRect.minY),
    options: []
)
context.restoreGState()

let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 248, nil)
let attributed = NSAttributedString(
    string: "SC",
    attributes: [
        kCTFontAttributeName as NSAttributedString.Key: font,
        kCTForegroundColorAttributeName as NSAttributedString.Key: CGColor(gray: 1, alpha: 1)
    ]
)
let line = CTLineCreateWithAttributedString(attributed)
let bounds = CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds])
context.textPosition = CGPoint(
    x: CGFloat(size) / 2 - bounds.midX,
    y: CGFloat(size) / 2 - bounds.midY
)
CTLineDraw(line, context)

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = CGImageDestinationCreateWithURL(
    outputURL as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
precondition(CGImageDestinationFinalize(destination))
