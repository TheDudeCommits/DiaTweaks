#import "Look.h"

// Arc's sidebar keeps everything 9 points from its edges, where Dia uses 6, and its pinned tiles are square with wider gaps.
static const CGFloat DPArcEdgeGain = 3, DPArcTileMargin = 9, DPArcTileGap = 8;
#define DPDiaTabDock "_TtC10TabSurface11TabDockView"

NSView *DPArcHostOf(NSWindow *window, BOOL create);

// Only inside a sidebar whose header this tweak has taken over: a cheap check, since these hooks run on every layout.
static BOOL DPArcSpacing(NSView *view) {
    NSView *host = DPArcSidebarHeader.on && view.window ? DPArcHostOf(view.window, NO) : nil;
    return host.superview && [view isDescendantOf:host.superview];
}

// Tab, folder and New Tab rows: narrower by the extra edge, so their hover and selection shapes line up with Arc's.
static void DPList_prepareLayout(NSCollectionViewLayout *self, SEL _cmd) {
    DPCallOriginal(DPList_prepareLayout, self);
    if (!DPArcSpacing(self.collectionView)) return;
    NSArray *(*elements)(id, SEL, NSRect) = (void *)DPDiaIMP(objc_getClass(DPDiaTabListLayout), @selector(layoutAttributesForElementsInRect:));
    CGFloat width = NSWidth(self.collectionView.bounds);
    for (NSCollectionViewLayoutAttributes *a in elements(self, @selector(layoutAttributesForElementsInRect:), NSMakeRect(-1e5, -1e5, 2e5, 1e7))) {
        // Only full-width rows: indented ones, like tabs in a folder, already sit inside it.
        if (a.representedElementCategory != NSCollectionElementCategoryItem || NSMinX(a.frame) > 0.5 || fabs(NSWidth(a.frame) - width) > 0.5) continue;
        a.frame = NSInsetRect(a.frame, DPArcEdgeGain, 0);
    }
}

static NSArray<NSView *> *DPTiles(NSView *dock) {
    NSMutableArray *tiles = [NSMutableArray new];
    for (NSView *sub in dock.subviews) if (DPIsKind(sub, DPDiaPinnedTab) && !sub.hidden) [tiles addObject:sub];
    return tiles;
}

// The dock's height for Arc's grid, at this width: square tiles, the same number across as Dia chose.
static CGFloat DPArcDockHeight(NSView *dock, CGFloat width, NSUInteger *columns, CGFloat *side) {
    NSArray<NSView *> *tiles = DPTiles(dock);
    NSMutableSet *xs = [NSMutableSet new];
    for (NSView *tile in tiles) [xs addObject:@(round(NSMinX(tile.frame)))];
    *columns = MAX(1, xs.count);
    *side = floor((width - 2 * DPArcTileMargin - DPArcTileGap * (*columns - 1)) / *columns * 2) / 2;
    NSUInteger rows = (tiles.count + *columns - 1) / *columns;
    return rows ? rows * *side + (rows - 1) * DPArcTileGap : 0;
}

static void DPDock_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPDock_layout, self);
    if (!DPArcSpacing(self)) return;
    NSUInteger columns;
    CGFloat side;
    DPArcDockHeight(self, NSWidth(self.bounds), &columns, &side);
    NSArray<NSView *> *tiles = [DPTiles(self) sortedArrayUsingComparator:^NSComparisonResult(NSView *a, NSView *b) {
        if (fabs(NSMinY(a.frame) - NSMinY(b.frame)) > 0.5) return [@(NSMinY(a.frame)) compare:@(NSMinY(b.frame))];
        return [@(NSMinX(a.frame)) compare:@(NSMinX(b.frame))];
    }];
    [tiles enumerateObjectsUsingBlock:^(NSView *tile, NSUInteger i, BOOL *stop) {
        NSRect frame = NSMakeRect(DPArcTileMargin + (i % columns) * (side + DPArcTileGap), (i / columns) * (side + DPArcTileGap), side, side);
        if (!self.isFlipped) frame.origin.y = NSHeight(self.bounds) - NSMaxY(frame);
        if (NSEqualRects(tile.frame, frame) || !DPMayAdjust(tile)) return;
        tile.frame = frame;
        [tile layoutSubtreeIfNeeded];
    }];
}

// The tab list under the dock moves down by however much taller Arc's grid is. Every frame is worked out
// from the one Dia last gave that view, which its setter records: Dia often moves the list under the dock
// without touching the dock (the sidebar opening over the page, a resize), and a one-off nudge measured
// from the dock's current height then left the list where Dia put it, under the taller grid.
static char DPDiaFrameKey, DPPlacedKey;
static BOOL DPPlacingList;

static NSView *DPDockIn(NSView *list) {
    for (NSView *sub in list.subviews) if (DPIsKind(sub, DPDiaTabDock)) return sub;
    return nil;
}

static NSRect DPDiaFrame(NSView *view) {
    NSValue *dia = DPGet(view, &DPDiaFrameKey), *placed = DPGet(view, &DPPlacedKey);
    // Moved some way other than setFrame: since (its origin or size alone): that's Dia's frame now.
    if (!dia || (placed && !NSEqualRects(view.frame, placed.rectValue) && !NSEqualRects(view.frame, dia.rectValue))) return view.frame;
    return dia.rectValue;
}

// Where Arc's spacing puts this child of the tab list, given the frame Dia wants for it.
static NSRect DPArcPlaced(NSView *list, NSView *view, NSRect frame) {
    NSView *dock = DPDockIn(list);
    if (!dock || !list.isFlipped || !DPArcSpacing(list)) return frame;
    NSRect diaDock = view == dock ? frame : DPDiaFrame(dock);
    NSUInteger columns;
    CGFloat side, height = DPArcDockHeight(dock, NSWidth(diaDock), &columns, &side);
    if (!height) return frame;  // (no tiles: Dia's dock as it is)
    if (view == dock) {
        frame.size.height = height;
        return frame;
    }
    CGFloat grow = height - NSHeight(diaDock);
    if (NSMinY(frame) < NSMaxY(diaDock) - 0.5) return frame;
    frame.origin.y += grow;
    frame.size.height = MAX(0, NSHeight(frame) - grow);
    return frame;
}

static void DPListChild_setFrame(NSView *self, SEL _cmd, NSRect frame) {
    NSView *list = self.superview;
    if (DPPlacingList || !DPIsKind(list, DPDiaTabList)) return DPCallOriginal(DPListChild_setFrame, self, frame);
    DPSet(self, &DPDiaFrameKey, @(frame));
    frame = DPArcPlaced(list, self, frame);
    DPSet(self, &DPPlacedKey, @(frame));
    DPCallOriginal(DPListChild_setFrame, self, frame);
}

static void DPPlaceList(NSView *list) {
    for (NSView *sub in list.subviews) {
        DPHookClass(sub.class, @selector(setFrame:), (IMP)DPListChild_setFrame);
        NSRect dia = DPDiaFrame(sub), frame = DPArcPlaced(list, sub, dia);
        DPSet(sub, &DPDiaFrameKey, @(dia));
        DPSet(sub, &DPPlacedKey, @(frame));
        if (NSEqualRects(sub.frame, frame) || !DPMayAdjust(sub)) continue;
        DPPlacingList = YES;
        sub.frame = frame;
        DPPlacingList = NO;
    }
}

static void DPTabList_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPTabList_layout, self);
    if (DPDockIn(self)) DPPlaceList(self);
}

void DPArcInstallSpacing(void) {
    DPHook(DPDiaTabListLayout, @selector(prepareLayout), (IMP)DPList_prepareLayout);
    DPHook(DPDiaTabDock, @selector(layout), (IMP)DPDock_layout);
    DPHook(DPDiaTabList, @selector(layout), (IMP)DPTabList_layout);
}

void DPArcApplySpacing(void) {
    for (NSView *view in DPFindViews(DPDiaTabListCollection)) [((NSCollectionView *)view).collectionViewLayout invalidateLayout];
    for (NSView *list in DPFindViews(DPDiaTabList)) {
        list.needsLayout = YES;
        for (NSView *sub in list.subviews) sub.needsLayout = YES;
    }
}
