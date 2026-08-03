import Foundation
import React

@objc(LiquidGlassViewManager)
final class LiquidGlassViewManager: RCTViewManager {
  override func view() -> UIView! { LiquidGlassView() }
  override static func requiresMainQueueSetup() -> Bool { true }
}
