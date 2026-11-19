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

void DPArcInstallSnapshot(void) {
    if (![[[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"] boolForKey:@"devTools"]) return;
    [NSDistributedNotificationCenter.defaultCenter addObserverForName:@"com.diapatches.dev.sidebarSnapshot" object:nil queue:NSOperationQueue.mainQueue
                                                           usingBlock:^(NSNotification *_) { DPWriteSnapshots(); }];
}
