#import "Look.h"

NSView *DPArcHostOf(NSWindow *window, BOOL create);

// A site asking for the microphone, camera, location... gets Dia's prompt, a popover from the site menu button.
// That button is in the sidebar's capsule now, and with the sidebar hidden it isn't on screen, so AppKit showed
// nothing and the site waited for an answer that never came. Then the prompt drops from the top left of the
// page instead, where the button would be, as long as the button can't be seen.

static BOOL DPOnScreen(NSView *view) {
    NSWindow *window = view.window;
    if (!window || !window.isVisible || view.hiddenOrHasHiddenAncestor || NSIsEmptyRect(view.visibleRect)) return NO;
    for (NSView *v = view; v; v = v.superview) if (v.alphaValue < 0.05 && v != view) return NO;  // (the button's own fade is fine)
    NSView *content = window.contentView;
    NSRect inContent = [view convertRect:view.bounds toView:content];
    return NSIntersectsRect(NSInsetRect(inContent, 2, 2), content.bounds);
}

static void DPArcPermission_show(NSPopover *self, SEL _cmd, NSRect rect, NSView *anchor, NSRectEdge edge) {
    NSWindow *window = anchor.window;
    NSView *host = DPArcSidebarHeader.on && window ? DPArcHostOf(window, NO) : nil;
    if (!host || ![anchor isDescendantOf:host] || DPOnScreen(anchor)) return DPCallOriginal(DPArcPermission_show, self, rect, anchor, edge);
    NSView *content = window.contentView, *pane = DPArcStateOf(host).pane;
    NSRect page = pane.window == window && !pane.hiddenOrHasHiddenAncestor ? [pane convertRect:pane.visibleRect toView:content] : content.bounds;
    CGFloat top = content.isFlipped ? NSMinY(page) : NSMaxY(page);
    NSRect spot = NSMakeRect(NSMinX(page) + 12, content.isFlipped ? top : top - 1, 28, 1);
    DPCallOriginal(DPArcPermission_show, self, spot, content, content.isFlipped ? NSRectEdgeMaxY : NSRectEdgeMinY);
}

void DPArcInstallPermission(void) {
    Class popover = objc_getClass(DPDiaWebsitePermissionPopover);
    SEL show = @selector(showRelativeToRect:ofView:preferredEdge:);
    if (class_getInstanceMethod(popover, show)) DPHookClass(popover, show, (IMP)DPArcPermission_show);
}
