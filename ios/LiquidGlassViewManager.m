// React Native bridge for LiquidGlassView.
#import <React/RCTViewManager.h>

@interface RCT_EXTERN_MODULE(LiquidGlassViewManager, RCTViewManager)
RCT_EXPORT_VIEW_PROPERTY(uniforms, NSArray)
RCT_EXPORT_VIEW_PROPERTY(backdrop, NSDictionary)
RCT_EXPORT_VIEW_PROPERTY(liveBackdrop, BOOL)
@end
