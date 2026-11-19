#import "ArcSidebarHeader.h"

NSView *DPArcMakeHost(void);
NSView *DPArcCapsuleOf(NSView *host);

// Where a moved view came from, held weakly so the toolbar and its buttons don't keep each other alive.
@interface DPArcHome : NSObject
@property (nonatomic, weak) NSView *superview;
@property (nonatomic) NSUInteger index;
@end
@implementation DPArcHome
@end

static char DPPartsKey, DPHomeKey, DPHostKey;
NSArray<NSString *> *const DPArcRoles = @[ @"toggle", @"back", @"forward", @"reload", @"address", @"extensions" ];

static BOOL DPNamed(NSView *view, NSString *part) { return [NSStringFromClass(view.class) containsString:part]; }

static NSView *DPIconControl(NSView *bar, NSString *icon, NSString *label, NSUInteger nth) {
    NSView *byLabel = DPFindView(bar, ^BOOL(NSView *v) { return DPHasLabel(v, label); });
    if (byLabel) return byLabel;
    NSMutableArray<NSView *> *found = [NSMutableArray new];
    DPFindView(bar, ^BOOL(NSView *v) {
        if (DPNamed(v, @"InteractiveIconControl") && DPNamed(v, icon)) [found addObject:v];
        return NO;
    });
    [found sortUsingComparator:^NSComparisonResult(NSView *a, NSView *b) { return [@(NSMinX(a.frame)) compare:@(NSMinX(b.frame))]; }];
    return nth < found.count ? found[nth] : nil;
}

// Dia's own controls, so their actions, hover states, menus and popovers keep working where they land.
NSDictionary<NSString *, NSView *> *DPArcParts(NSView *pane) {
    NSMutableDictionary *parts = DPGet(pane, &DPPartsKey);
    NSView *bar = DPSubview(pane, DPDiaToolbar);
    if (parts) {
        // Pinning a first extension makes its view later: pick it up then.
        if (!parts[@"extensions"] && bar) parts[@"extensions"] = DPFindView(bar, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaPinnedExtensions); });
        return parts;
    }
    if (!bar) return nil;
    Class hoverable = objc_getClass(DPDiaHoverableControl);
    NSMutableDictionary *found = [NSMutableDictionary new];
    found[@"toggle"] = DPFindView(bar, ^BOOL(NSView *v) { return DPHasLabel(v, @"Toggle sidebar") || (hoverable && v.class == hoverable); });
    found[@"back"] = DPIconControl(bar, @"ChevronIconView", @"Go back", 0);
    found[@"forward"] = DPIconControl(bar, @"ChevronIconView", @"Go forward", 1);
    found[@"reload"] = DPIconControl(bar, @"ReloadIconView", @"Reload this page", 0);
    found[@"address"] = DPFindView(bar, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaAddressField); });
    found[@"extensions"] = DPFindView(bar, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaPinnedExtensions); });
    // Without pinned extensions there is no extensions view: move the rest, and look again next time.
    if (found.count < DPArcRoles.count - (found[@"extensions"] ? 0 : 1)) return nil;
    DPSet(pane, &DPPartsKey, found);
    return found;
}

NSView *DPArcHostOf(NSWindow *window, BOOL create) {
    NSView *host = DPGet(window, &DPHostKey);
    if (!host && create) DPSet(window, &DPHostKey, host = DPArcMakeHost());
    return host;
}

void DPArcMoveIn(NSView *view, NSView *into) {
    if (view.superview == into) return;
    if (!DPArcIsMoved(view)) {
        DPArcHome *home = [DPArcHome new];
        home.superview = view.superview;
        home.index = [view.superview.subviews indexOfObject:view];
        DPSet(view, &DPHomeKey, home);
        DPArcWatchFrames(view);
    }
    DPArcMarkMoved(view, YES);
    [into addSubview:view];
}

void DPArcMoveHome(NSView *view) {
    DPArcHome *home = DPGet(view, &DPHomeKey);
    if (!DPArcIsMoved(view) || !home.superview) return;
    DPArcMarkMoved(view, NO);
    NSArray *siblings = home.superview.subviews;
    if (home.index < siblings.count) [home.superview addSubview:view positioned:NSWindowBelow relativeTo:siblings[home.index]];
    else [home.superview addSubview:view];
    DPArcPlace(view, DPArcDiaFrame(view));
    home.superview.needsLayout = YES;
}

void DPArcMovePaneHome(NSView *pane) {
    NSDictionary *parts = DPGet(pane, &DPPartsKey);
    for (NSString *role in DPArcRoles) if (parts[role]) DPArcMoveHome(parts[role]);
}

NSView *DPArcCapsuleIn(NSView *host) { return DPArcCapsuleOf(host); }
