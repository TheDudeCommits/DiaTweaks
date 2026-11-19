#import "Look.h"
#import "Patches/HideToolbar/HideToolbar.h"

void DPArcPlaceToggle(DPArcState *state);

NSDictionary<NSString *, NSView *> *DPArcParts(NSView *pane);
NSView *DPArcHostOf(NSWindow *window, BOOL create);
NSView *DPArcCapsuleIn(NSView *host);
void DPArcMoveIn(NSView *view, NSView *into);
void DPArcMovePartsHome(NSDictionary<NSString *, NSView *> *parts);
NSHashTable<NSView *> *DPArcPanes;  // Every tab's content pane Dia has laid out; filled by the pane layout hook.
static char DPHidKey, DPHeaderKey, DPFooterKey;
static BOOL DPSyncing;
void DPArcApplySpacing(void);
// Developer tools only: what the sync decided, to find out why the header leaves the sidebar.
void DPArcLog(NSString *format, ...) {
    static NSFileHandle *log;
    static BOOL checked;
    if (!checked) {
        checked = YES;
        if ([[[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"] boolForKey:@"devTools"]) {
            NSString *path = DPAppSupport(@"DiaPatches/arc-log.txt");
            [NSFileManager.defaultManager createFileAtPath:path contents:nil attributes:nil];
            log = [NSFileHandle fileHandleForWritingAtPath:path];
        }
    }
    if (!log) return;
    va_list args;
    va_start(args, format);
    NSString *line = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    [log writeData:[[NSString stringWithFormat:@"%.3f %@\n", CACurrentMediaTime(), line] dataUsingEncoding:NSUTF8StringEncoding]];
}

// Each tab has its own pane and toolbar; the one on screen lends the sidebar its controls. In split view, the side
// you're typing or clicking in; otherwise the one that already has them, or the widest.
static NSView *DPVisiblePane(NSWindow *window, NSView *current) {
    NSResponder *responder = window.firstResponder;
    if ([responder isKindOfClass:NSTextView.class] && ((NSTextView *)responder).isFieldEditor) responder = (NSResponder *)((NSTextView *)responder).delegate;
    NSView *focused = nil, *widest = nil;
    BOOL currentShows = NO;
    for (NSView *pane in DPArcPanes) {
        if (pane.window != window || pane.hiddenOrHasHiddenAncestor || NSIsEmptyRect(pane.visibleRect) || !DPSubview(pane, DPDiaToolbar)) continue;
        if ([responder isKindOfClass:NSView.class] && [(NSView *)responder isDescendantOf:pane]) focused = pane;
        if (pane == current) currentShows = YES;
        if (!widest || NSWidth(pane.frame) > NSWidth(widest.frame)) widest = pane;
    }
    return focused ?: currentShows ? current : widest;
}

// Looked up once per window and kept while it's still there: a search of the whole window on every layout is what stutters.
static NSView *DPCached(NSWindow *window, const void *key, const char *cls) {
    NSView *found = [DPGet(window, key) pointerValue];
    if (found && found.window == window) return found;
    found = DPFindView(window.contentView, ^BOOL(NSView *v) { return DPIsKind(v, cls); });
    DPSet(window, key, found ? [NSValue valueWithNonretainedObject:found] : nil);
    return found;
}

// Only the sidebar layout has a footer, even with the sidebar hidden.
static BOOL DPSidebarLayout(NSWindow *window) { return DPCached(window, &DPFooterKey, DPDiaSidebarFooter) != nil; }

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
    NSView *existing = DPArcHostOf(window, NO);
    DPArcState *old = existing ? DPArcStateOf(existing) : nil;
    NSView *header = DPCached(window, &DPHeaderKey, DPDiaSidebarHeader), *root = header.superview;
    BOOL active = DPArcSidebarHeader.on && DPHideToolbar.on && root && DPSidebarLayout(window);
    NSView *pane = active ? DPVisiblePane(window, old.pane) : nil;
    NSDictionary *parts = pane ? DPArcParts(pane) : nil;
    // A pane with no address field yet (a tab still opening) keeps the controls already in the sidebar, rather than emptying it.
    BOOL switching = parts && pane != old.pane;
    static void *lastPane;
    if (pane != lastPane || switching) DPArcLog(@"%@ active=%d pane=%p old=%p parts=%lu switching=%d", window.title, active, pane, old.pane, (unsigned long)parts.count, switching);
    lastPane = (__bridge void *)pane;
    NSView *profile = header ? DPProfileWrapper(header) : nil;
    if (active && (parts || old.parts)) {
        NSView *host = DPArcHostOf(window, YES);
        DPArcState *state = DPArcStateOf(host);
        BOOL fresh = host.superview == nil;
        if (switching && state.parts) {
            DPArcUnstyle(state);
            DPArcMovePartsHome(state.parts);
        }
        if (switching || !state.parts) {
            state.pane = pane;
            state.parts = parts;
        }
        state.window = window;
        state.host = host;
        state.header = header;
        DPArcWatchSidebar(root);
        NSDictionary *mine = state.parts;
        for (NSString *role in @[ @"toggle", @"back", @"forward", @"reload" ]) if (mine[role]) DPArcMoveIn(mine[role], host);
        DPArcMoveIn(mine[@"address"], DPArcCapsuleIn(host));
        if (mine[@"extensions"]) DPArcMoveIn(mine[@"extensions"], DPArcClipIn(DPArcCapsuleIn(host)));
        DPLayOut(state);
        // The profile switcher would sit under the back and forward buttons; ⌘1–9 and the Profiles menu still switch.
        if (profile && !profile.hidden) { profile.hidden = YES; DPSet(profile, &DPHidKey, @YES); }
        DPArcSetShift(root, YES);
        if (fresh) DPArcApplySpacing();  // The tab list laid out before the sidebar was ours: lay it out again with Arc's spacing.
    } else if (!active) {
        if (old) {
            DPArcUnstyle(old);
            DPArcMovePartsHome(old.parts);
            old.parts = nil;
            old.pane = nil;
        }
        [existing removeFromSuperview];
        if (profile && DPGet(profile, &DPHidKey)) { profile.hidden = NO; DPSet(profile, &DPHidKey, nil); }
        if (root) DPArcSetShift(root, NO);
        if (existing.window == nil && old) DPArcApplySpacing();
    }
    DPSyncing = NO;
}

void DPArcLogState(NSString *when) {
    for (NSWindow *window in NSApp.windows) {
        NSView *host = DPArcHostOf(window, NO);
        if (!host || !window.visible) continue;
        DPArcState *state = DPArcStateOf(host);
        NSMutableString *parts = [NSMutableString new];
        for (NSString *role in state.parts) {
            NSView *v = state.parts[role];
            [parts appendFormat:@" %@:%@%@", role, [v isDescendantOf:host] ? @"in" : @"OUT", v.hiddenOrHasHiddenAncestor ? @"(hidden)" : @""];
        }
        NSView *root = state.header.superview;
        DPArcLog(@"[%@] fullscreen=%d %@ host:%@ root:%@ x=%g alpha=%g%@ label='%@'", when, (window.styleMask & NSWindowStyleMaskFullScreen) != 0, window.title, host.superview == root ? @"in" : @"OUT", root.hidden ? @"hidden" : @"shown",
                 NSMinX(root.frame), host.alphaValue, parts, state.label.stringValue);
    }
}

void DPArcSyncAll(void) {
    for (NSWindow *window in NSApp.windows) DPArcSyncWindow(window);
}
