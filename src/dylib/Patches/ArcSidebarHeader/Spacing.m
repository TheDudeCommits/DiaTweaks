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

// The dock's height for Arc's grid: square tiles, the same number across as Dia chose.
static CGFloat DPArcDockHeight(NSView *dock, NSUInteger *columns, CGFloat *side) {
    NSArray<NSView *> *tiles = DPTiles(dock);
    NSMutableSet *xs = [NSMutableSet new];
    for (NSView *tile in tiles) [xs addObject:@(round(NSMinX(tile.frame)))];
    *columns = MAX(1, xs.count);
    *side = floor((NSWidth(dock.bounds) - 2 * DPArcTileMargin - DPArcTileGap * (*columns - 1)) / *columns * 2) / 2;
    NSUInteger rows = (tiles.count + *columns - 1) / *columns;
    return rows ? rows * *side + (rows - 1) * DPArcTileGap : 0;
}

static void DPDock_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPDock_layout, self);
    if (!DPArcSpacing(self)) return;
    NSUInteger columns;
    CGFloat side;
    DPArcDockHeight(self, &columns, &side);
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

// The tab list under the dock moves down by however much taller Arc's grid is.
static void DPTabList_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPTabList_layout, self);
    NSView *dock = nil;
    for (NSView *sub in self.subviews) if (DPIsKind(sub, DPDiaTabDock)) dock = sub;
    if (!dock || !DPArcSpacing(self) || !self.isFlipped) return;
    NSUInteger columns;
    CGFloat side, height = DPArcDockHeight(dock, &columns, &side), grow = height - NSHeight(dock.frame);
    if (fabs(grow) < 0.5 || !DPMayAdjust(dock)) return;
    CGFloat below = NSMaxY(dock.frame);
    dock.frame = NSMakeRect(NSMinX(dock.frame), NSMinY(dock.frame), NSWidth(dock.frame), height);
    for (NSView *sub in self.subviews) {
        if (sub == dock || NSMinY(sub.frame) < below - 0.5 || !DPMayAdjust(sub)) continue;
        sub.frame = NSMakeRect(NSMinX(sub.frame), NSMinY(sub.frame) + grow, NSWidth(sub.frame), MAX(0, NSHeight(sub.frame) - grow));
    }
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
