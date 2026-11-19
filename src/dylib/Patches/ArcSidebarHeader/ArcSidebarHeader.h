#import "StdPatch/StdPatch.h"

extern DPPatch DPArcSidebarHeader;

// The capsule row's height, added between the sidebar header and the tabs.
static const CGFloat DPArcRowHeight = 32;

// Set while we place a moved view, so its setFrame: goes through; Dia's own calls are only recorded.
extern BOOL DPArcPlacing;

BOOL DPArcIsMoved(NSView *view);
NSRect DPArcDiaFrame(NSView *view);  // The frame Dia last tried to give a moved view.
void DPArcWatchFrames(NSView *view);
void DPArcMarkMoved(NSView *view, BOOL moved);
void DPArcWatchSidebar(NSView *root);
void DPArcSetShift(NSView *root, BOOL shift);
void DPArcPlace(NSView *view, NSRect frame);
void DPArcSyncWindow(NSWindow *window);
void DPArcSyncAll(void);
void DPArcInstallSnapshot(void);
