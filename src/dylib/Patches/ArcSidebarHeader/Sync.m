#import "ArcSidebarHeader.h"
#import "Patches/HideToolbar/HideToolbar.h"

NSDictionary<NSString *, NSView *> *DPArcParts(NSView *pane);
NSView *DPArcHostOf(NSWindow *window, BOOL create);
NSView *DPArcCapsuleIn(NSView *host);
void DPArcMoveIn(NSView *view, NSView *into);
void DPArcMovePaneHome(NSView *pane);
static char DPPaneKey, DPHidKey;
static BOOL DPSyncing;

static NSArray<NSView *> *DPPanesIn(NSWindow *window) {
    NSMutableArray *panes = [NSMutableArray new];
    DPFindView(window.contentView, ^BOOL(NSView *v) {
        if (DPIsKind(v, DPDiaContentPane) && DPSubview(v, DPDiaToolbar)) [panes addObject:v];
        return NO;
    });
    return panes;
}

// In split view, the pane you're typing or clicking in lends its controls; otherwise the one that already has.
static NSView *DPChosenPane(NSWindow *window, NSArray<NSView *> *panes) {
    NSResponder *responder = window.firstResponder;
    if ([responder isKindOfClass:NSTextView.class] && ((NSTextView *)responder).isFieldEditor) responder = (NSResponder *)((NSTextView *)responder).delegate;
    for (NSView *pane in panes) if ([responder isKindOfClass:NSView.class] && [(NSView *)responder isDescendantOf:pane]) return pane;
    NSView *current = DPGet(window, &DPPaneKey);
    return [panes containsObject:current] ? current : panes.firstObject;
}

static NSView *DPProfileWrapper(NSView *header) {
    return DPFindView(header, ^BOOL(NSView *v) { return [NSStringFromClass(v.class) containsString:@"ProfileIndicatorWrapperView"]; });
}

static void DPLayOut(NSView *host, NSView *header, NSDictionary<NSString *, NSView *> *parts) {
    NSView *root = header.superview, *capsule = DPArcCapsuleIn(host);
    CGFloat width = NSWidth(root.bounds), top = NSMaxY(header.frame), mid = NSMidY(header.frame);
    if (host.superview != root || root.subviews.lastObject != host) [root addSubview:host positioned:NSWindowAbove relativeTo:nil];
    host.frame = NSMakeRect(0, 0, width, top + DPArcRowHeight);

    NSView *lights = DPFindView(header, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaTrafficLights); });
    CGFloat left = lights ? NSMaxX([lights convertRect:lights.bounds toView:host]) + 6 : 84, right = width - 8;
    NSView *toggle = parts[@"toggle"];
    NSSize size = DPArcDiaFrame(toggle).size;
    DPArcPlace(toggle, NSMakeRect(left, round(mid - size.height / 2), size.width, size.height));
    for (NSString *role in @[ @"reload", @"forward", @"back" ]) {
        NSView *button = parts[role];
        size = DPArcDiaFrame(button).size;
        right -= size.width;
        DPArcPlace(button, NSMakeRect(right, round(mid - size.height / 2), size.width, size.height));
        right -= 2;
    }

    NSRect pill = NSMakeRect(8, top + 2, width - 16, DPArcRowHeight - 6);
    capsule.frame = pill;
    NSView *extensions = parts[@"extensions"], *address = parts[@"address"];
    CGFloat shown = 0;
    if (extensions) {
        // A collection view only makes the icons it has room for, so size it from its item count, not its frame.
        // Whole icons only, leaving the address at least 100 points.
        NSRect wants = DPArcDiaFrame(extensions);
        NSCollectionView *list = (NSCollectionView *)DPFindView(extensions, ^BOOL(NSView *v) { return [v isKindOfClass:NSCollectionView.class]; });
        NSInteger icons = list.numberOfSections > 0 ? [list numberOfItemsInSection:0] : 0;
        CGFloat pitch = 30, room = NSWidth(pill) - 110;
        if ([list.collectionViewLayout isKindOfClass:NSCollectionViewFlowLayout.class]) {
            NSCollectionViewFlowLayout *flow = (NSCollectionViewFlowLayout *)list.collectionViewLayout;
            if (flow.itemSize.width > 0) pitch = flow.itemSize.width + flow.minimumInteritemSpacing;
        }
        if (NSHeight(wants) < 1) wants.size.height = 42;
        shown = MIN(icons * pitch, floor(MAX(0, room) / pitch) * pitch);
        extensions.wantsLayer = YES;
        extensions.layer.masksToBounds = YES;
        DPArcPlace(extensions, NSMakeRect(NSWidth(pill) - shown - 4, round((NSHeight(pill) - NSHeight(wants)) / 2), shown, NSHeight(wants)));
    }
    CGFloat height = NSHeight(DPArcDiaFrame(address));
    DPArcPlace(address, NSMakeRect(4, round((NSHeight(pill) - height) / 2), NSWidth(pill) - shown - 12, height));
}

void DPArcSyncWindow(NSWindow *window) {
    if (DPSyncing || !window) return;
    DPSyncing = YES;
    NSView *header = DPFindView(window.contentView, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaSidebarHeader); });
    NSArray<NSView *> *panes = DPPanesIn(window);
    NSView *pane = DPChosenPane(window, panes), *root = header.superview;
    NSDictionary *parts = pane ? DPArcParts(pane) : nil;
    BOOL want = DPArcSidebarHeader.on && DPHideToolbar.on && header && root && parts && !DPTabsAtTop(window);
    for (NSView *other in panes) if (!want || other != pane) DPArcMovePaneHome(other);
    NSView *host = DPArcHostOf(window, want), *profile = header ? DPProfileWrapper(header) : nil;
    if (want) {
        DPSet(window, &DPPaneKey, pane);
        if (root) DPArcWatchSidebar(root);
        for (NSString *role in @[ @"toggle", @"back", @"forward", @"reload" ]) DPArcMoveIn(parts[role], host);
        for (NSString *role in @[ @"address", @"extensions" ]) if (parts[role]) DPArcMoveIn(parts[role], DPArcCapsuleIn(host));
        DPLayOut(host, header, parts);
        // The profile switcher would sit under the back and forward buttons; ⌘1–9 and the Profiles menu still switch.
        if (profile && !profile.hidden) { profile.hidden = YES; DPSet(profile, &DPHidKey, @YES); }
    } else {
        [host removeFromSuperview];
        if (profile && DPGet(profile, &DPHidKey)) { profile.hidden = NO; DPSet(profile, &DPHidKey, nil); }
    }
    if (root) DPArcSetShift(root, want);
    DPSyncing = NO;
}

void DPArcSyncAll(void) {
    for (NSWindow *window in NSApp.windows) DPArcSyncWindow(window);
}
