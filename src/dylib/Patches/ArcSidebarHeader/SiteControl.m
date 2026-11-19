#import "Look.h"

// Arc's Site Control Center: the capsule's site button opens one panel with the page's actions, every extension,
// and the site's settings. Everything in it runs Dia's own menu items and buttons.
NSView *DPArcHostOf(NSWindow *window, BOOL create);

static const CGFloat DPPanelWidth = 236, DPPanelInset = 12, DPTileGap = 6;
static BOOL DPPassThrough;
static NSPopover *DPPanel;
static __weak NSView *DPPanelButton;
static CFTimeInterval DPPanelClosed;

static BOOL DPDark(NSView *view) {
    return [view.effectiveAppearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]] == NSAppearanceNameDarkAqua;
}

// A square of Arc's panel: a soft fill, a little lighter under the pointer.
@interface DPArcTile : NSControl
@property (nonatomic, copy) void (^run)(void);
@property (nonatomic) BOOL over, row;
@property (nonatomic, strong) NSImageView *icon;
@property (nonatomic, strong) NSTextField *title;
@end

@implementation DPArcTile
- (instancetype)initWithImage:(NSImage *)image title:(NSString *)title row:(BOOL)row run:(void (^)(void))run {
    if (!(self = [super initWithFrame:NSZeroRect])) return nil;
    self.wantsLayer = YES;
    self.row = row;
    self.run = run;
    self.toolTip = row ? nil : title;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.icon = [NSImageView imageViewWithImage:image];
    self.icon.translatesAutoresizingMaskIntoConstraints = NO;
    self.icon.contentTintColor = NSColor.labelColor;
    self.icon.imageScaling = NSImageScaleProportionallyDown;
    [self addSubview:self.icon];
    [self.icon.widthAnchor constraintEqualToConstant:16].active = YES;
    [self.icon.heightAnchor constraintEqualToConstant:16].active = YES;
    [self.icon.centerYAnchor constraintEqualToAnchor:self.centerYAnchor].active = YES;
    if (row) {
        self.title = [NSTextField labelWithString:title];
        self.title.font = [NSFont systemFontOfSize:13];
        self.title.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:self.title];
        [self.icon.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:10].active = YES;
        [self.title.leadingAnchor constraintEqualToAnchor:self.icon.trailingAnchor constant:10].active = YES;
        [self.title.centerYAnchor constraintEqualToAnchor:self.centerYAnchor].active = YES;
        [self.heightAnchor constraintEqualToConstant:30].active = YES;
    } else {
        [self.icon.centerXAnchor constraintEqualToAnchor:self.centerXAnchor].active = YES;
        [self.heightAnchor constraintEqualToConstant:38].active = YES;
    }
    [self setAccessibilityElement:YES];
    [self setAccessibilityRole:NSAccessibilityButtonRole];
    [self setAccessibilityLabel:title];
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect owner:self userInfo:nil]];
    return self;
}
- (BOOL)wantsUpdateLayer { return YES; }
- (void)updateLayer {
    BOOL dark = DPDark(self);
    CGFloat alpha = self.row ? (self.over ? (dark ? 0.10 : 0.06) : 0) : (dark ? (self.over ? 0.14 : 0.08) : (self.over ? 0.09 : 0.05));
    self.layer.backgroundColor = [NSColor colorWithWhite:dark ? 1 : 0 alpha:alpha].CGColor;
    self.layer.cornerRadius = self.row ? 7 : 9;
    self.layer.cornerCurve = kCACornerCurveContinuous;
}
- (void)setOver:(BOOL)over {
    _over = over;
    self.needsDisplay = YES;
}
- (void)mouseEntered:(NSEvent *)event { self.over = YES; }
- (void)mouseExited:(NSEvent *)event { self.over = NO; }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (void)mouseDown:(NSEvent *)event {}
- (void)mouseUp:(NSEvent *)event {
    if (NSPointInRect([self convertPoint:event.locationInWindow fromView:nil], self.bounds)) [self press];
}
- (BOOL)accessibilityPerformPress {
    [self press];
    return YES;
}
- (void)press {
    void (^run)(void) = self.run;
    [DPPanel close];
    // After the panel has gone, so Dia acts on the browser window, not the panel's.
    if (run) dispatch_async(dispatch_get_main_queue(), run);
}
@end

static NSMenuItem *DPArcMenuItem(NSString *menu, NSString *title) {
    NSMenu *submenu = [NSApp.mainMenu itemWithTitle:menu].submenu;
    if ([submenu.delegate respondsToSelector:@selector(menuNeedsUpdate:)]) [submenu.delegate menuNeedsUpdate:submenu];
    return [submenu itemWithTitle:title];
}

static void DPPerform(NSMenuItem *item) {
    NSMenu *menu = item.menu;
    NSInteger index = menu ? [menu indexOfItem:item] : -1;
    if (index < 0) return;
    [menu update];
    if (item.isEnabled) [menu performActionForItemAtIndex:index];
}

static void (^DPArcRunItem(NSString *menu, NSString *title))(void) {
    return ^{ DPPerform(DPArcMenuItem(menu, title)); };
}

static NSImage *DPSymbol(NSString *name) {
    NSImage *image = [NSImage imageWithSystemSymbolName:name accessibilityDescription:nil];
    return [image imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:14 weight:NSFontWeightRegular]];
}

static NSTextField *DPHeading(NSString *text) {
    NSTextField *label = [NSTextField labelWithString:text];
    label.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    label.textColor = NSColor.secondaryLabelColor;
    return label;
}

// Tiles in rows of four, as in Arc's panel.
static NSView *DPGrid(NSArray<DPArcTile *> *tiles) {
    NSMutableArray *rows = [NSMutableArray new];
    for (NSUInteger i = 0; i < tiles.count; i += 4) {
        NSMutableArray *row = [[tiles subarrayWithRange:NSMakeRange(i, MIN(4, tiles.count - i))] mutableCopy];
        while (row.count < 4) [row addObject:[NSView new]];  // Keeps a short last row's tiles the same width.
        NSStackView *stack = [NSStackView stackViewWithViews:row];
        stack.distribution = NSStackViewDistributionFillEqually;
        stack.spacing = DPTileGap;
        [rows addObject:stack];
    }
    NSStackView *grid = [NSStackView stackViewWithViews:rows];
    grid.orientation = NSUserInterfaceLayoutOrientationVertical;
    grid.spacing = DPTileGap;
    for (NSView *row in rows) [row.widthAnchor constraintEqualToAnchor:grid.widthAnchor].active = YES;
    return grid;
}

static NSView *DPPanelContent(NSView *siteButton) {
    __weak NSView *site = siteButton;
    NSArray *actions = @[
        [[DPArcTile alloc] initWithImage:DPSymbol(@"square.and.arrow.up") title:@"Share" row:NO run:DPArcRunItem(@"File", @"Share…")],
        [[DPArcTile alloc] initWithImage:DPSymbol(@"link") title:@"Copy Link" row:NO run:DPArcRunItem(@"Edit", @"Copy URL")],
        [[DPArcTile alloc] initWithImage:DPSymbol(@"bookmark") title:@"Bookmark This Page" row:NO run:DPArcRunItem(@"Bookmarks", @"Bookmark This Page")],
        [[DPArcTile alloc] initWithImage:DPSymbol(@"rectangle.split.2x1") title:@"Open Split Pane" row:NO run:DPArcRunItem(@"View", @"Open Split Pane")],
    ];
    // Every extension, pinned or not, from Dia's Extensions menu: choosing one there opens it, as in Arc.
    NSMutableArray *extensions = [NSMutableArray new];
    NSMenu *menu = [NSApp.mainMenu itemWithTitle:@"Extensions"].submenu;
    if ([menu.delegate respondsToSelector:@selector(menuNeedsUpdate:)]) [menu.delegate menuNeedsUpdate:menu];
    for (NSMenuItem *item in menu.itemArray) {
        if (item.isSeparatorItem) break;
        if (item.hidden || !item.image) continue;
        __weak NSMenuItem *weak = item;
        [extensions addObject:[[DPArcTile alloc] initWithImage:item.image title:item.title row:NO run:^{ DPPerform(weak); }]];
    }
    [extensions addObject:[[DPArcTile alloc] initWithImage:DPSymbol(@"plus") title:@"Add Extension" row:NO run:DPArcRunItem(@"Extensions", @"Add Extension…")]];
    NSArray *settings = @[
        [[DPArcTile alloc] initWithImage:DPSymbol(@"slider.horizontal.3") title:@"Site Settings" row:YES run:^{
            NSView *button = site;
            if (!button.window) return;
            DPPassThrough = YES;
            [button accessibilityPerformPress];
            DPPassThrough = NO;
        }],
        [[DPArcTile alloc] initWithImage:DPSymbol(@"puzzlepiece.extension") title:@"Manage Extensions" row:YES run:DPArcRunItem(@"Extensions", @"Manage Extensions…")],
        [[DPArcTile alloc] initWithImage:DPSymbol(@"pin") title:@"Pin Extensions" row:YES run:DPArcRunItem(@"Extensions", @"Pin Extensions…")],
    ];
    NSStackView *settingRows = [NSStackView stackViewWithViews:settings];
    settingRows.orientation = NSUserInterfaceLayoutOrientationVertical;
    settingRows.spacing = 2;
    for (NSView *row in settings) [row.widthAnchor constraintEqualToAnchor:settingRows.widthAnchor].active = YES;

    NSArray *parts = @[ DPGrid(actions), DPHeading(@"Extensions"), DPGrid(extensions), DPHeading(@"Settings"), settingRows ];
    NSStackView *content = [NSStackView stackViewWithViews:parts];
    content.orientation = NSUserInterfaceLayoutOrientationVertical;
    content.alignment = NSLayoutAttributeLeading;
    content.spacing = 10;
    [content setCustomSpacing:16 afterView:parts[0]];
    [content setCustomSpacing:16 afterView:parts[2]];
    [content setCustomSpacing:6 afterView:parts[1]];
    [content setCustomSpacing:4 afterView:parts[3]];
    content.edgeInsets = NSEdgeInsetsMake(DPPanelInset, DPPanelInset, DPPanelInset, DPPanelInset);
    for (NSView *part in parts)
        if (part != parts[1] && part != parts[3]) [part.widthAnchor constraintEqualToAnchor:content.widthAnchor constant:-2 * DPPanelInset].active = YES;
    [content.widthAnchor constraintEqualToConstant:DPPanelWidth].active = YES;
    return content;
}

@interface DPArcPanelDelegate : NSObject <NSPopoverDelegate>
@end
@implementation DPArcPanelDelegate
- (void)popoverDidClose:(NSNotification *)note { DPPanelClosed = CACurrentMediaTime(); }
@end

void DPArcShowControlCenter(NSView *button) {
    static DPArcPanelDelegate *delegate;
    // A click on the button while the panel is open closes it, as Arc's does, rather than opening it again.
    if (DPPanel.shown) return [DPPanel close];
    if (DPPanelButton == button && CACurrentMediaTime() - DPPanelClosed < 0.3) return;
    DPPanel = [NSPopover new];
    DPPanel.behavior = NSPopoverBehaviorTransient;
    DPPanel.delegate = delegate ?: (delegate = [DPArcPanelDelegate new]);
    DPPanel.appearance = button.effectiveAppearance;
    NSViewController *controller = [NSViewController new];
    controller.view = DPPanelContent(button);
    DPPanel.contentViewController = controller;
    DPPanelButton = button;
    [DPPanel showRelativeToRect:button.bounds ofView:button preferredEdge:NSRectEdgeMaxY];
}

// Dia's site button, once it's in the sidebar's capsule: the panel takes its click, and lists its menu as Site Settings.
static BOOL DPOurs(NSView *view) {
    if (DPPassThrough || !DPArcSidebarHeader.on || !view.window || !DPHasLabel(view, @"Site menu")) return NO;
    NSView *host = DPArcHostOf(view.window, NO);
    return host.superview && [view isDescendantOf:host];
}

static void DPSite_mouseDown(NSView *self, SEL _cmd, NSEvent *event) {
    if (!DPOurs(self)) return DPCallOriginal(DPSite_mouseDown, self, event);
    DPArcShowControlCenter(self);
}

static void DPSite_mouseUp(NSView *self, SEL _cmd, NSEvent *event) {
    if (!DPOurs(self)) DPCallOriginal(DPSite_mouseUp, self, event);
}

static BOOL DPSite_press(NSView *self, SEL _cmd) {
    if (!DPOurs(self)) return DPCallOriginal(DPSite_press, self);
    DPArcShowControlCenter(self);
    return YES;
}

void DPArcInstallControlCenter(void) {
    DPHook(DPDiaHoverableControl, @selector(mouseDown:), (IMP)DPSite_mouseDown);
    DPHook(DPDiaHoverableControl, @selector(mouseUp:), (IMP)DPSite_mouseUp);
    DPHook(DPDiaHoverableControl, @selector(accessibilityPerformPress), (IMP)DPSite_press);
}

void DPArcCloseControlCenter(void) { [DPPanel close]; }

// Developer tools only: draws the open panel, and the sidebar's top, to PNGs beside the dylib.
static void DPDraw(NSView *view, NSRect rect, NSString *name) {
    NSBitmapImageRep *rep = [view bitmapImageRepForCachingDisplayInRect:rect];
    if (!rep) return;
    [view cacheDisplayInRect:rect toBitmapImageRep:rep];
    [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:DPAppSupport([@"DiaPatches/" stringByAppendingString:name]) atomically:YES];
}

void DPArcDrawPanel(void) {
    NSView *frame = DPPanel.contentViewController.view.window.contentView.superview ?: DPPanel.contentViewController.view;
    if (DPPanel.shown) DPDraw(frame, frame.bounds, @"panel.png");
    NSView *host = DPPanelButton ? DPArcHostOf(DPPanelButton.window, NO) : nil;
    NSView *root = host.superview;
    if (root) DPDraw(root, NSMakeRect(0, 0, NSWidth(root.bounds), 160), @"header.png");
}
