#import "ArcSidebarHeader.h"

// Developer tools only: `com.diapatches.dev.sidebarSnapshot` draws the top of each window's sidebar to
// ~/Library/Application Support/DiaPatches/sidebar-<n>.png, for checking this tweak without screen recording.
static void DPWriteSnapshots(void) {
    NSUInteger n = 0;
    for (NSWindow *window in NSApp.windows) {
        NSView *header = DPFindView(window.contentView, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaSidebarHeader); });
        NSView *root = header.superview;
        if (!root || NSIsEmptyRect(root.bounds)) continue;
        NSRect rect = NSMakeRect(0, 0, NSWidth(root.bounds), MIN(NSHeight(root.bounds), 260));
        if (!root.isFlipped) rect.origin.y = NSHeight(root.bounds) - NSHeight(rect);
        NSBitmapImageRep *rep = [root bitmapImageRepForCachingDisplayInRect:rect];
        if (!rep) continue;
        [root cacheDisplayInRect:rect toBitmapImageRep:rep];
        NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        [png writeToFile:DPAppSupport([NSString stringWithFormat:@"DiaPatches/sidebar-%lu.png", (unsigned long)n++]) atomically:YES];
    }
}

void DPArcLogState(NSString *when);

static NSMenuItem *DPFindItem(NSMenu *menu, NSString *title) {
    for (NSMenuItem *item in menu.itemArray) {
        if ([item.title isEqualToString:title]) return item;
        NSMenuItem *found = item.submenu ? DPFindItem(item.submenu, title) : nil;
        if (found) return found;
    }
    return nil;
}

// Developer tools only: `com.diapatches.dev.arcMenu` with a menu item's title runs it, then logs where the header's parts are.
static void DPRunMenuItem(NSString *title) {
    if ([title isEqual:@"?"]) {
        NSMutableArray *titles = [NSMutableArray new];
        for (NSMenuItem *top in NSApp.mainMenu.itemArray)
            for (NSMenuItem *item in top.submenu.itemArray) if (item.title.length) [titles addObject:[NSString stringWithFormat:@"%@>%@", top.title, item.title]];
        return DPArcLogState([titles componentsJoinedByString:@" | "]);
    }
    NSMenuItem *item = DPFindItem(NSApp.mainMenu, title);
    if (!item) return DPArcLogState([@"no menu item " stringByAppendingString:title]);
    [item.menu update];
    [item.menu performActionForItemAtIndex:[item.menu indexOfItem:item]];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 2), dispatch_get_main_queue(), ^{ DPArcLogState(title); });
}

void DPArcInstallSnapshot(void) {
    if (![[[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"] boolForKey:@"devTools"]) return;
    [NSDistributedNotificationCenter.defaultCenter addObserverForName:@"com.diapatches.dev.sidebarSnapshot" object:nil queue:NSOperationQueue.mainQueue
                                                           usingBlock:^(NSNotification *_) { DPWriteSnapshots(); }];
    [NSDistributedNotificationCenter.defaultCenter addObserverForName:@"com.diapatches.dev.arcMenu" object:nil queue:NSOperationQueue.mainQueue
                                                           usingBlock:^(NSNotification *note) { DPRunMenuItem(note.object); }];
}
