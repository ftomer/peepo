// Reads or sets the main display's mode, for the iPad screenshot size.
//
// An iPad 13" shot is a 1376x1032 point window, which does not fit on a laptop
// screen running at its default scaled resolution. The screenshot rig switches
// the display to a roomier mode for the duration and puts it back afterwards.
//
//   display_mode          - prints `index width height` per mode, then `current <index>`
//   display_mode <index>  - switches to that mode
import CoreGraphics
import Foundation

let display = CGMainDisplayID()
let options = [kCGDisplayShowDuplicateLowResolutionModes as String: kCFBooleanTrue!] as CFDictionary
guard let modes = CGDisplayCopyAllDisplayModes(display, options) as? [CGDisplayMode] else {
  FileHandle.standardError.write(Data("no display modes\n".utf8))
  exit(1)
}

let args = CommandLine.arguments
if args.count == 1 {
  for (i, mode) in modes.enumerated() {
    print(i, mode.width, mode.height)
  }
  // Matched on the pixel size as well as the point size: the duplicate
  // low-resolution modes share a point size with a HiDPI mode, and restoring
  // the wrong one of the pair hands back a blurrier screen than we borrowed.
  let current = CGDisplayCopyDisplayMode(display)!
  let index = modes.firstIndex {
    $0.width == current.width && $0.height == current.height
      && $0.pixelWidth == current.pixelWidth && $0.pixelHeight == current.pixelHeight
  }
  print("current", index ?? -1)
} else if let index = Int(args[1]), index >= 0, index < modes.count {
  var config: CGDisplayConfigRef?
  CGBeginDisplayConfiguration(&config)
  CGConfigureDisplayWithDisplayMode(config, display, modes[index], nil)
  CGCompleteDisplayConfiguration(config, .permanently)
} else {
  FileHandle.standardError.write(Data("usage: display_mode [index]\n".utf8))
  exit(1)
}
