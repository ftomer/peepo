// Flatten a captured window PNG to opaque RGB.
//
//   strip_alpha in.png out.png
//
// App Store Connect rejects any image with an alpha channel, and a macOS
// window capture always has one because the window corners are rounded.
// Filling those corners with a flat colour leaves visible notches, so the
// backdrop is the same image drawn slightly larger underneath; the corners
// then pick up the colour that surrounds them.

import AppKit

let args = CommandLine.arguments
guard args.count == 3 else {
  FileHandle.standardError.write("usage: strip_alpha in.png out.png\n".data(using: .utf8)!)
  exit(1)
}

guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
  FileHandle.standardError.write("cannot read \(args[1])\n".data(using: .utf8)!)
  exit(1)
}

let w = image.width, h = image.height
guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                          bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
  FileHandle.standardError.write("cannot make an opaque context\n".data(using: .utf8)!)
  exit(1)
}

ctx.interpolationQuality = .high
// The backdrop, 2% larger and centred, so the corners are covered by pixels
// that came from just inside them.
let grow = 0.02
ctx.draw(image, in: CGRect(x: -Double(w) * grow / 2, y: -Double(h) * grow / 2,
                           width: Double(w) * (1 + grow), height: Double(h) * (1 + grow)))
ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

guard let out = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: args[2]) as CFURL,
                                                 "public.png" as CFString, 1, nil) else {
  FileHandle.standardError.write("cannot write \(args[2])\n".data(using: .utf8)!)
  exit(1)
}
CGImageDestinationAddImage(dest, out, nil)
guard CGImageDestinationFinalize(dest) else {
  FileHandle.standardError.write("cannot finish \(args[2])\n".data(using: .utf8)!)
  exit(1)
}
