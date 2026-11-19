#import "ArcSidebarHeader.h"

BOOL DPArcPlacing;
static char DPDiaFrameKey, DPMovedKey, DPShiftKey;
static NSHashTable<NSView *> *DPArcSidebars;

BOOL DPArcIsMoved(NSView *view) { return [DPGet(view, &DPMovedKey) boolValue]; }

NSRect DPArcDiaFrame(NSView *view) {
    NSValue *value = DPGet(view, &DPDiaFrameKey);
    return value ? value.rectValue : view.frame;
}

// Dia keeps laying out the toolbar it took these from: remember what it wants, so they can go back, but keep our frame.
static void DPMoved_setFrame(NSView *self, SEL _cmd, NSRect frame) {
    if (!DPArcPlacing && DPGet(self, &DPMovedKey)) {
        DPSet(self, &DPDiaFrameKey, @(frame));
        if ([DPGet(self, &DPMovedKey) boolValue]) return;
    }
    DPCallOriginal(DPMoved_setFrame, self, frame);
}

void DPArcWatchFrames(NSView *view) {
    if (!DPGet(view, &DPMovedKey)) DPSet(view, &DPDiaFrameKey, @(view.frame));
    DPSet(view, &DPMovedKey, @NO);
    DPHookClass(view.class, @selector(setFrame:), (IMP)DPMoved_setFrame);
}

void DPArcMarkMoved(NSView *view, BOOL moved) { DPSet(view, &DPMovedKey, @(moved)); }

static NSView *DPHeaderIn(NSView *root) { return DPSubview(root, DPDiaSidebarHeader); }

static BOOL DPArcShifting(NSView *root) {
    return DPArcSidebarHeader.on && [DPArcSidebars containsObject:root] && DPGet(root, &DPShiftKey);
}

// The view under the header moves down a row and gets shorter, in its setter, so Dia's next layout can't undo it.
static void DPSidebarChild_setFrame(NSView *self, SEL _cmd, NSRect frame) {
    NSView *root = self.superview, *header = DPHeaderIn(root);
    if (header && self != header && root.isFlipped && DPArcShifting(root) && fabs(NSMinY(frame) - NSMaxY(header.frame)) < 0.5) {
        frame.origin.y += DPArcRowHeight;
        frame.size.height = MAX(0, NSHeight(frame) - DPArcRowHeight);
    }
    DPCallOriginal(DPSidebarChild_setFrame, self, frame);
}

void DPArcSetShift(NSView *root, BOOL shift) {
    if (!root || [DPGet(root, &DPShiftKey) boolValue] == shift) return;
    DPSet(root, &DPShiftKey, shift ? @YES : nil);
    root.needsLayout = YES;
    for (NSView *sub in root.subviews) sub.needsLayout = YES;
}

void DPArcWatchSidebar(NSView *root) {
    if (!DPArcSidebars) DPArcSidebars = [NSHashTable weakObjectsHashTable];
    if ([DPArcSidebars containsObject:root]) return;
    [DPArcSidebars addObject:root];
    for (NSView *sub in root.subviews)
        if (!DPIsKind(sub, DPDiaSidebarHeader)) DPHookClass(sub.class, @selector(setFrame:), (IMP)DPSidebarChild_setFrame);
}
