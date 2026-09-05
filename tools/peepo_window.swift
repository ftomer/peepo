// Prints the running app's largest window as `id x y width height`, in points.
// The screenshot rig captures that window by id, so it does not matter which
// window is in front or what is sitting on top of it.
import CoreGraphics
import Foundation

let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as! [[String: Any]]
var best: (Int, Double, Double, Double, Double)?
for w in list {
  guard let owner = w[kCGWindowOwnerName as String] as? String, owner == "Peepo" else { continue }
  let num = w[kCGWindowNumber as String] as! Int
  let b = w[kCGWindowBounds as String] as! [String: Double]
  let area = b["Width"]! * b["Height"]!
  if best == nil || area > best!.3 * best!.4 {
    best = (num, b["X"]!, b["Y"]!, b["Width"]!, b["Height"]!)
  }
}
if let b = best {
  print(b.0, Int(b.1), Int(b.2), Int(b.3), Int(b.4))
}
