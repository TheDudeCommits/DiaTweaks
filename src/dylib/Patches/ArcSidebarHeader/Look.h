#import "ArcSidebarHeader.h"

// Arc's measurements, in points, read off Arc's sidebar at 224 points wide.
static const CGFloat DPArcToggleLeft = 14;      // Where the sidebar button sits while the window buttons are hidden.
static const CGFloat DPArcButtonPitch = 35;     // Back, forward and reload, centre to centre.
static const CGFloat DPArcReloadInset = 18;     // Reload's centre from the sidebar's right edge.
static const CGFloat DPArcCapsuleGap = 23;      // From the buttons' centre line to the capsule's top.
static const CGFloat DPArcCapsuleHeight = 35;
static const CGFloat DPArcCapsuleInset = 8;
static const CGFloat DPArcTextInset = 12;

@interface DPArcState : NSObject
@property (nonatomic, weak) NSWindow *window;
@property (nonatomic, weak) NSView *host, *header;
@property (nonatomic, strong) NSDictionary<NSString *, NSView *> *parts;
@property (nonatomic, strong) NSTextField *label;
@property (nonatomic, strong) NSTrackingArea *tracking;
@property (nonatomic, strong) NSTimer *lightsTimer;
@property (nonatomic) CGFloat lightsProgress;  // 0 hidden, 1 shown.
@property (nonatomic) BOOL overButtons, overCapsule;
@end

DPArcState *DPArcStateOf(NSView *host);
NSView *DPArcLights(NSView *header);
CGFloat DPArcCentreLine(DPArcState *state);
NSView *DPArcClipIn(NSView *capsule);
void DPArcRestyle(DPArcState *state);
void DPArcUnstyle(DPArcState *state);
void DPArcTrack(DPArcState *state);
