#import "Look.h"
#import "Patches/HideToolbar/HideToolbar.h"

void DPArcPlaceToggle(DPArcState *state);

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

static CGFloat DPExtensionsWidth(NSView *extensions, CGFloat *full) {
    // A collection view only makes the icons it has room for, so size it from its item count, not its frame.
    NSCollectionView *list = (NSCollectionView *)DPFindView(extensions, ^BOOL(NSView *v) { return [v isKindOfClass:NSCollectionView.class]; });
    NSInteger icons = list.numberOfSections > 0 ? [list numberOfItemsInSection:0] : 0;
    CGFloat pitch = 30;
    if ([list.collectionViewLayout isKindOfClass:NSCollectionViewFlowLayout.class]) {
        NSCollectionViewFlowLayout *flow = (NSCollectionViewFlowLayout *)list.collectionViewLayout;
        if (flow.itemSize.width > 0) pitch = flow.itemSize.width + flow.minimumInteritemSpacing;
    }
    *full = icons * pitch;
    return pitch;
}

static void DPLayOut(DPArcState *state) {
    NSView *host = state.host, *header = state.header, *root = header.superview, *capsule = DPArcCapsuleIn(host), *clip = DPArcClipIn(capsule);
    NSDictionary<NSString *, NSView *> *parts = state.parts;
    CGFloat width = NSWidth(root.bounds);
    if (host.superview != root || root.subviews.lastObject != host) [root addSubview:host positioned:NSWindowAbove relativeTo:nil];
    host.frame = NSMakeRect(0, 0, width, NSMaxY(header.frame) + DPArcRowHeight);
    CGFloat mid = DPArcCentreLine(state);

    DPArcPlaceToggle(state);
    CGFloat centre = width - DPArcReloadInset;
    for (NSString *role in @[ @"reload", @"forward", @"back" ]) {
        NSSize size = DPArcDiaFrame(parts[role]).size;
        DPArcPlace(parts[role], NSMakeRect(round(centre - size.width / 2), round(mid - size.height / 2), size.width, size.height));
        centre -= DPArcButtonPitch;
    }

    NSRect pill = NSMakeRect(DPArcCapsuleInset, round(mid + DPArcCapsuleGap), width - 2 * DPArcCapsuleInset, DPArcCapsuleHeight);
    capsule.frame = pill;
    NSView *extensions = parts[@"extensions"], *address = parts[@"address"];
    CGFloat shown = 0;
    if (extensions) {
        CGFloat full = 0, pitch = DPExtensionsWidth(extensions, &full), height = NSHeight(DPArcDiaFrame(extensions)) ?: 42;
        // Whole icons only, leaving the address at least 100 points.
        shown = MIN(full, floor(MAX(0, NSWidth(pill) - 110) / pitch) * pitch);
        clip.frame = NSMakeRect(NSWidth(pill) - shown - 4, 0, shown, NSHeight(pill));
        DPArcPlace(extensions, NSMakeRect(0, round((NSHeight(pill) - height) / 2), full, height));
    }
    CGFloat height = NSHeight(DPArcDiaFrame(address));
    DPArcPlace(address, NSMakeRect(4, round((NSHeight(pill) - height) / 2), NSWidth(pill) - shown - 12, height));
    DPArcTrack(state);
    DPArcRestyle(state);
}

void DPArcSyncWindow(NSWindow *window) {
    if (DPSyncing || !window) return;
    DPSyncing = YES;
    NSView *header = DPFindView(window.contentView, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaSidebarHeader); });
    NSArray<NSView *> *panes = DPPanesIn(window);
    NSView *pane = DPChosenPane(window, panes), *root = header.superview;
    NSDictionary *parts = pane ? DPArcParts(pane) : nil;
    BOOL want = DPArcSidebarHeader.on && DPHideToolbar.on && header && root && parts && !DPTabsAtTop(window);
    NSView *host = DPArcHostOf(window, want), *profile = header ? DPProfileWrapper(header) : nil;
    for (NSView *other in panes) {
        if (want && other == pane) continue;
        // Split view moved the controls to another pane: give these back looking as Dia drew them.
        if (host && DPArcStateOf(host).parts[@"address"] == DPArcParts(other)[@"address"]) DPArcUnstyle(DPArcStateOf(host));
        DPArcMovePaneHome(other);
    }
    if (want) {
        DPSet(window, &DPPaneKey, pane);
        if (root) DPArcWatchSidebar(root);
        for (NSString *role in @[ @"toggle", @"back", @"forward", @"reload" ]) DPArcMoveIn(parts[role], host);
        DPArcMoveIn(parts[@"address"], DPArcCapsuleIn(host));
        if (parts[@"extensions"]) DPArcMoveIn(parts[@"extensions"], DPArcClipIn(DPArcCapsuleIn(host)));
        DPArcState *state = DPArcStateOf(host);
        state.window = window;
        state.host = host;
        state.header = header;
        state.parts = parts;
        DPLayOut(state);
        // The profile switcher would sit under the back and forward buttons; ⌘1–9 and the Profiles menu still switch.
        if (profile && !profile.hidden) { profile.hidden = YES; DPSet(profile, &DPHidKey, @YES); }
    } else {
        if (host) DPArcUnstyle(DPArcStateOf(host));
        [host removeFromSuperview];
        if (profile && DPGet(profile, &DPHidKey)) { profile.hidden = NO; DPSet(profile, &DPHidKey, nil); }
    }
    if (root) DPArcSetShift(root, want);
    DPSyncing = NO;
}

void DPArcSyncAll(void) {
    for (NSWindow *window in NSApp.windows) DPArcSyncWindow(window);
}
