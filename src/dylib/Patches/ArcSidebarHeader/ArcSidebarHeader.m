#import "Look.h"

NSView *DPArcHostOf(NSWindow *window, BOOL create);

static NSHashTable<NSWindow *> *DPPending;

// Moving views inside Dia's layout pass makes it lay out again; do it once, right after.
static void DPSchedule(NSWindow *window) {
    if (!window || [DPPending containsObject:window]) return;
    [DPPending addObject:window];
    __weak NSWindow *weak = window;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSWindow *strong = weak;
        if (!strong) return;
        [DPPending removeObject:strong];
        DPArcSyncWindow(strong);
    });
}

static void DPHeader_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPHeader_layout, self);
    DPSchedule(self.window);
}

static void DPPane_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPPane_layout, self);
    DPSchedule(self.window);
}

static void DPInstallArcSidebarHeader(void) {
    DPPending = [NSHashTable weakObjectsHashTable];
    DPHook(DPDiaSidebarHeader, @selector(layout), (IMP)DPHeader_layout);
    DPHook(DPDiaContentPane, @selector(layout), (IMP)DPPane_layout);
    [NSNotificationCenter.defaultCenter addObserverForName:NSWindowDidBecomeKeyNotification object:nil queue:nil
                                                usingBlock:^(NSNotification *note) { DPSchedule(note.object); }];
    // Keeps the site name, the arrows' enabled look and editing in step with Dia, after each event.
    [NSNotificationCenter.defaultCenter addObserverForName:NSWindowDidUpdateNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        NSView *host = DPArcSidebarHeader.on ? DPArcHostOf(note.object, NO) : nil;
        if (host.superview) DPArcRestyle(DPArcStateOf(host));
    }];
    DPArcInstallSnapshot();
}

static void DPApplyArcSidebarHeader(DPPatch *patch) { DPArcSyncAll(); }

static NSString *DPVerifyArcSidebarHeader(DPPatch *patch) {
    DPPatch *hide = DPPatchNamed(@"hideToolbar");
    for (NSView *header in DPFindViews(DPDiaSidebarHeader)) {
        NSWindow *window = header.window;
        if (!DPFindView(window.contentView, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaSidebarFooter); })) continue;
        NSArray<NSView *> *fields = DPFindViews(DPDiaAddressField);
        NSUInteger inSidebar = 0, inWindow = 0;
        for (NSView *field in fields) {
            if (field.window != window) continue;
            inWindow++;
            if ([field isDescendantOf:header.superview]) inSidebar++;
        }
        BOOL want = patch->on && hide && hide->on;
        if (want && inWindow && inSidebar != 1) return @"address field isn't in the sidebar";
        if (!want && inSidebar) return @"address field is still in the sidebar";
        NSView *below = nil;
        for (NSView *sub in header.superview.subviews)
            if (sub != header && fabs(NSMinY(sub.frame) - NSMaxY(header.frame) - (want ? DPArcRowHeight : 0)) < 0.5) below = sub;
        if (header.superview.isFlipped && !below) return want ? @"tabs didn't move down for the address row" : @"tabs aren't right under the header";
    }
    return nil;
}

DP_PATCH(DPArcSidebarHeader) {
    .key = @"arcSidebarHeader",
    .order = 46,
    .title = @"Address in Sidebar",
    .detail = @"Move the address field and pinned extensions into the top of the sidebar, with the sidebar, back, forward and reload buttons beside the window buttons, like Arc. The profile switcher makes way: switch profiles with ⌘1–9 or the Profiles menu.",
    .symbol = @"sidebar.left",
    .tint = @"systemIndigoColor",
    .requires = @"hideToolbar",
    .disabledBy = @"compactSidebarHeader",
    .section = @"Showing the Toolbar",
    .classes = DPClasses(DPDiaSidebarHeader, DPDiaContentPane, DPDiaToolbar, DPDiaAddressField, DPDiaSidebarFooter),
    .install = DPInstallArcSidebarHeader,
    .apply = DPApplyArcSidebarHeader,
    .verify = DPVerifyArcSidebarHeader,
};
