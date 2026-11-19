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
void DPArcLog(NSString *format, ...);

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

@class DPArcState;
NSView *DPArcHostOf(NSWindow *window, BOOL create);
id DPArcStateOf(NSView *host);
void DPArcFakeHover(id state, NSString *what);

void DPArcShowControlCenter(NSView *button);

// Developer tools only: `com.diapatches.dev.arcPanel` opens the site panel; with a title, presses that tile too.
static void DPOpenPanel(NSString *title) {
    NSView *site = nil;
    for (NSWindow *window in NSApp.windows) {
        NSView *host = DPArcHostOf(window, NO);
        if (host.superview && window.isVisible) site = DPFindView(host, ^BOOL(NSView *v) { return DPHasLabel(v, @"Site menu"); });
        if (site) break;
    }
    if (!site) return DPArcLogState(@"no site button");
    DPArcShowControlCenter(site);
    void DPArcDrawPanel(void);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 2), dispatch_get_main_queue(), ^{ DPArcDrawPanel(); });
    if (!title.length) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 2), dispatch_get_main_queue(), ^{
        for (NSWindow *window in NSApp.windows) {
            NSView *tile = DPFindView(window.contentView, ^BOOL(NSView *v) { return [NSStringFromClass(v.class) isEqual:@"DPArcTile"] && DPHasLabel(v, title); });
            if (!tile) continue;
            // Logs what opened: a menu that starts tracking (closed again after a moment) and the windows after a second.
            __block id observer = [NSNotificationCenter.defaultCenter addObserverForName:NSMenuDidBeginTrackingNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
                NSMenu *menu = note.object;
                NSMutableArray *titles = [NSMutableArray new];
                for (NSMenuItem *item in menu.itemArray) if (item.title.length) [titles addObject:item.title];
                DPArcLog(@"menu opened: %@", [titles componentsJoinedByString:@" | "]);
                NSTimer *close = [NSTimer timerWithTimeInterval:0.8 repeats:NO block:^(NSTimer *_) { [menu cancelTracking]; }];
                [NSRunLoop.mainRunLoop addTimer:close forMode:NSRunLoopCommonModes];
            }];
            [tile accessibilityPerformPress];
            DPArcLog(@"pressed %@", title);
            NSTimer *later = [NSTimer timerWithTimeInterval:1.5 repeats:NO block:^(NSTimer *_) {
                [NSNotificationCenter.defaultCenter removeObserver:observer];
                for (NSWindow *w in NSApp.windows)
                    if (w.isVisible) DPArcLog(@"window %@ %@ key=%d", NSStringFromClass(w.class), NSStringFromRect(w.frame), w.isKeyWindow);
            }];
            [NSRunLoop.mainRunLoop addTimer:later forMode:NSRunLoopCommonModes];
            return;
        }
        DPArcLogState([@"no tile " stringByAppendingString:title]);
    });
}

static void DPFakeHover(NSString *what) {
    for (NSWindow *window in NSApp.windows) {
        NSView *host = DPArcHostOf(window, NO);
        if (host.superview && window.isVisible) DPArcFakeHover(DPArcStateOf(host), what);
    }
}

// Developer tools only: `com.diapatches.dev.arcMenuTree` writes every menu item, and the capsule buttons' actions, to menus.txt.
static void DPDumpMenu(NSMenu *menu, NSMutableString *out, NSUInteger depth) {
    if ([menu.delegate respondsToSelector:@selector(menuNeedsUpdate:)]) [menu.delegate menuNeedsUpdate:menu];
    [menu update];
    for (NSMenuItem *item in menu.itemArray) {
        [out appendFormat:@"%@%@ action=%@ target=%@ image=%d tag=%ld rep=%@ key=%@%@\n", [@"" stringByPaddingToLength:depth * 2 withString:@" " startingAtIndex:0],
                          item.isSeparatorItem ? @"---" : item.title, NSStringFromSelector(item.action), item.target ? NSStringFromClass([item.target class]) : @"-",
                          item.image != nil, (long)item.tag, item.representedObject ? NSStringFromClass([item.representedObject class]) : @"-", item.keyEquivalent,
                          item.hidden ? @" hidden" : @""];
        if (item.submenu && depth < 4) DPDumpMenu(item.submenu, out, depth + 1);
    }
}

static void DPDumpMenus(void) {
    NSMutableString *out = [NSMutableString new];
    DPDumpMenu(NSApp.mainMenu, out, 0);
    for (NSView *v in DPFindViews(DPDiaHoverableControl)) {
        NSControl *c = (NSControl *)v;
        [out appendFormat:@"control %@ class=%@ action=%@ target=%@ menu=%d gestures=%lu\n", v.accessibilityLabel, NSStringFromClass(v.superclass),
                          [c respondsToSelector:@selector(action)] ? NSStringFromSelector(c.action) : @"?",
                          [c respondsToSelector:@selector(target)] && c.target ? NSStringFromClass([c.target class]) : @"-", v.menu != nil, (unsigned long)v.gestureRecognizers.count];
    }
    [out writeToFile:DPAppSupport(@"DiaPatches/menus.txt") atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

void DPArcInstallSnapshot(void) {
    if (![[[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"] boolForKey:@"devTools"]) return;
    [NSDistributedNotificationCenter.defaultCenter addObserverForName:@"com.diapatches.dev.sidebarSnapshot" object:nil queue:NSOperationQueue.mainQueue
                                                           usingBlock:^(NSNotification *_) { DPWriteSnapshots(); }];
    [NSDistributedNotificationCenter.defaultCenter addObserverForName:@"com.diapatches.dev.arcMenu" object:nil queue:NSOperationQueue.mainQueue
                                                           usingBlock:^(NSNotification *note) { DPRunMenuItem(note.object); }];
    [NSDistributedNotificationCenter.defaultCenter addObserverForName:@"com.diapatches.dev.arcHover" object:nil queue:NSOperationQueue.mainQueue
                                                           usingBlock:^(NSNotification *note) { DPFakeHover(note.object); }];
    [NSDistributedNotificationCenter.defaultCenter addObserverForName:@"com.diapatches.dev.arcMenuTree" object:nil queue:NSOperationQueue.mainQueue
                                                           usingBlock:^(NSNotification *_) { DPDumpMenus(); }];
    [NSDistributedNotificationCenter.defaultCenter addObserverForName:@"com.diapatches.dev.arcPanel" object:nil queue:NSOperationQueue.mainQueue
                                                           usingBlock:^(NSNotification *note) { DPOpenPanel(note.object); }];
}
