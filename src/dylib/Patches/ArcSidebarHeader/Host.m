#import "ArcSidebarHeader.h"

// Passes clicks through its empty space, so the window buttons and window dragging under it keep working.
@interface DPArcHostView : NSView
@end
@implementation DPArcHostView
- (BOOL)isFlipped { return YES; }
- (NSView *)hitTest:(NSPoint)point {
    NSView *hit = [super hitTest:point];
    return hit == self ? nil : hit;
}
- (BOOL)mouseDownCanMoveWindow { return YES; }
@end

// Arc's address capsule: a soft fill a little lighter than the sidebar.
@interface DPArcCapsuleView : NSView
@end
@implementation DPArcCapsuleView
- (BOOL)isFlipped { return YES; }
- (BOOL)wantsUpdateLayer { return YES; }
- (void)updateLayer {
    BOOL dark = [self.effectiveAppearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]] == NSAppearanceNameDarkAqua;
    self.layer.backgroundColor = [NSColor colorWithWhite:dark ? 1 : 0 alpha:dark ? 0.09 : 0.06].CGColor;
    self.layer.cornerRadius = 10;
    self.layer.cornerCurve = kCACornerCurveContinuous;
}
- (void)viewDidChangeEffectiveAppearance { self.needsDisplay = YES; }
- (BOOL)mouseDownCanMoveWindow { return NO; }
@end

void DPArcPlace(NSView *view, NSRect frame) {
    if (NSEqualRects(view.frame, frame)) return;
    DPArcPlacing = YES;
    view.frame = frame;
    DPArcPlacing = NO;
}

NSView *DPArcMakeHost(void) {
    DPArcHostView *host = [[DPArcHostView alloc] initWithFrame:NSZeroRect];
    host.identifier = @"DPArcSidebarHeader";
    DPArcCapsuleView *capsule = [[DPArcCapsuleView alloc] initWithFrame:NSZeroRect];
    capsule.wantsLayer = YES;
    capsule.identifier = @"DPArcCapsule";
    [host addSubview:capsule];
    return host;
}

NSView *DPArcCapsuleOf(NSView *host) {
    for (NSView *sub in host.subviews) if ([sub.identifier isEqual:@"DPArcCapsule"]) return sub;
    return nil;
}
