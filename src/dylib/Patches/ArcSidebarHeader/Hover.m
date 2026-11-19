#import "Look.h"

// The sidebar button sits just after the window buttons, on their centre line, as in Arc.
@interface DPArcTracker : NSObject
@property (nonatomic, weak) DPArcState *state;
@end

void DPArcPlaceToggle(DPArcState *state) {
    NSView *toggle = state.parts[@"toggle"], *lights = DPArcLights(state.header);
    if (!toggle || !state.host) return;
    CGFloat x = lights ? NSMaxX([lights convertRect:lights.bounds toView:state.host]) + DPArcToggleGap : DPArcCapsuleInset + DPArcToggleGap;
    NSSize size = DPArcDiaFrame(toggle).size;
    DPArcPlace(toggle, NSMakeRect(round(x), round(DPArcCentreLine(state) - size.height / 2), size.width, size.height));
}

// The capsule shows its buttons and extensions under the pointer.
@implementation DPArcTracker
- (void)update:(NSEvent *)event {
    DPArcState *state = self.state;
    NSView *host = state.host, *capsule = state.parts[@"address"].superview;
    if (!host || !capsule) return;
    NSPoint point = [host convertPoint:event.locationInWindow fromView:nil];
    BOOL overCapsule = NSPointInRect(point, host.bounds) && NSPointInRect(point, capsule.frame);
    if (overCapsule == state.overCapsule) return;
    state.overCapsule = overCapsule;
    DPArcRestyle(state);
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

// Developer tools only: show the hover look without a pointer ("capsule" or "none").
void DPArcFakeHover(DPArcState *state, NSString *what) {
    state.overCapsule = [what isEqual:@"capsule"];
    DPArcRestyle(state);
}
