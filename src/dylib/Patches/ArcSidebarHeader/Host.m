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
@property (nonatomic) BOOL hovered;
@end
@implementation DPArcCapsuleView
- (BOOL)isFlipped { return YES; }
- (BOOL)wantsUpdateLayer { return YES; }
- (void)setHovered:(BOOL)hovered {
    if (_hovered == hovered) return;
    _hovered = hovered;
    self.needsDisplay = YES;
}
// Arc's capsule is a little lighter than the sidebar, and a little lighter again under the pointer.
- (void)updateLayer {
    BOOL dark = [self.effectiveAppearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]] == NSAppearanceNameDarkAqua;
    CGFloat alpha = dark ? (self.hovered ? 0.14 : 0.10) : (self.hovered ? 0.09 : 0.06);
    self.layer.backgroundColor = [NSColor colorWithWhite:dark ? 1 : 0 alpha:alpha].CGColor;
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
    // Extensions sit in this at their full width, so Dia never sees them squeezed and rebuilds them.
    NSView *clip = [[DPArcHostView alloc] initWithFrame:NSZeroRect];
    clip.identifier = @"DPArcClip";
    clip.wantsLayer = YES;
    clip.layer.masksToBounds = YES;
    [capsule addSubview:clip];
    return host;
}

NSView *DPArcCapsuleOf(NSView *host) {
    for (NSView *sub in host.subviews) if ([sub.identifier isEqual:@"DPArcCapsule"]) return sub;
    return nil;
}
