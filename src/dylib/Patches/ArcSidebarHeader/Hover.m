#import "Look.h"

// Like Arc, the window buttons stay hidden until the pointer comes near them, and the sidebar button steps aside for them.
@interface DPArcTracker : NSObject
@property (nonatomic, weak) DPArcState *state;
@end

void DPArcPlaceToggle(DPArcState *state) {
    NSView *toggle = state.parts[@"toggle"], *lights = DPArcLights(state.header);
    if (!toggle || !state.host) return;
    CGFloat after = lights ? NSMaxX([lights convertRect:lights.bounds toView:state.host]) + 6 : DPArcToggleLeft;
    NSSize size = DPArcDiaFrame(toggle).size;
    CGFloat x = round(DPArcToggleLeft + (after - DPArcToggleLeft) * state.lightsProgress);
    DPArcPlace(toggle, NSMakeRect(x, round(DPArcCentreLine(state) - size.height / 2), size.width, size.height));
    if (lights && fabs(lights.alphaValue - state.lightsProgress) > 0.001) lights.alphaValue = state.lightsProgress;
}

static void DPShowLights(DPArcState *state, BOOL show) {
    CGFloat from = state.lightsProgress, to = show ? 1 : 0;
    [state.lightsTimer invalidate];
    if (from == to) return;
    CFTimeInterval start = CACurrentMediaTime();
    __weak DPArcState *weak = state;
    state.lightsTimer = [NSTimer timerWithTimeInterval:1.0 / 120 repeats:YES block:^(NSTimer *timer) {
        DPArcState *me = weak;
        CGFloat t = MIN(1, (CACurrentMediaTime() - start) / 0.18);
        if (!me || t == 1) [timer invalidate];
        me.lightsProgress = from + (to - from) * t * t * (3 - 2 * t);
        DPArcPlaceToggle(me);
    }];
    [NSRunLoop.mainRunLoop addTimer:state.lightsTimer forMode:NSRunLoopCommonModes];
}

@implementation DPArcTracker
- (void)update:(NSEvent *)event {
    DPArcState *state = self.state;
    NSView *host = state.host, *capsule = state.parts[@"address"].superview;
    if (!host || !capsule) return;
    NSPoint point = [host convertPoint:event.locationInWindow fromView:nil];
    BOOL inside = NSPointInRect(point, host.bounds);
    BOOL overButtons = inside && point.y < NSMinY(capsule.frame) && point.x < NSMinX(state.parts[@"back"].frame) - 4;
    BOOL overCapsule = inside && NSPointInRect(point, capsule.frame);
    if (overButtons != state.overButtons) DPShowLights(state, overButtons);
    state.overButtons = overButtons;
    if (overCapsule != state.overCapsule) {
        state.overCapsule = overCapsule;
        DPArcRestyle(state);
    }
}
- (void)mouseEntered:(NSEvent *)event { [self update:event]; }
- (void)mouseMoved:(NSEvent *)event { [self update:event]; }
- (void)mouseExited:(NSEvent *)event { [self update:event]; }
@end

void DPArcTrack(DPArcState *state) {
    NSView *host = state.host;
    if (!host || state.tracking) return;
    DPArcTracker *tracker = [DPArcTracker new];
    tracker.state = state;
    DPSet(host, (__bridge const void *)tracker.class, tracker);  // The tracking area doesn't keep its owner alive.
    state.tracking = [[NSTrackingArea alloc] initWithRect:NSZeroRect
                                                  options:NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveAlways | NSTrackingInVisibleRect
                                                    owner:tracker userInfo:nil];
    [host addTrackingArea:state.tracking];
}
