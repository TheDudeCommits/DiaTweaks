#import "Look.h"
#import "Patches/HideToolbar/HideToolbar.h"

// With Collapse Pinned Tabs on, its Pinned line reads like Arc's space title instead: the profile's emoji and name, no rule,
// the chevron only under the pointer. It still folds the pinned tabs.
static char DPDiaTitleKey;

// Dia titles its windows "<profile>: <page>", and draws the switcher's name without a label to read.
static NSString *DPProfileName(NSWindow *window) {
    NSRange colon = [window.title rangeOfString:@": "];
    return colon.location == NSNotFound ? nil : [window.title substringToIndex:colon.location];
}

static NSString *DPProfileEmojiFor(NSString *space) {
    DPPatch *emoji = DPPatchNamed(@"profileEmoji");
    if (!space || !emoji || !emoji->on) return nil;
    return [[[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"] dictionaryForKey:@"profileEmojis"][space];
}

static void DPRestyle(NSView *header) {
    NSTextField *title = [header valueForKey:@"title"];
    NSImageView *pin = [header valueForKey:@"pin"], *chevron = [header valueForKey:@"chevron"];
    CALayer *line = [header valueForKey:@"line"];
    BOOL arc = DPArcSidebarHeader.on && DPHideToolbar.on && header.window;
    NSString *dia = DPDiaValue(title, &DPDiaTitleKey, title.stringValue);
    NSString *name = arc ? DPProfileName(header.window) : nil;
    NSString *emoji = arc ? DPProfileEmojiFor([header valueForKey:@"space"]) : nil;
    NSString *text = name.length ? (emoji.length ? [NSString stringWithFormat:@"%@  %@", emoji, name] : name) : dia;
    DPOverride(title, &DPDiaTitleKey, dia, text);
    if (![title.stringValue isEqual:text]) title.stringValue = text;
    title.font = arc ? [NSFont systemFontOfSize:13 weight:NSFontWeightMedium] : [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    // Arc: the space's icon where a tab's icon sits, its name where a tab's title starts.
    pin.hidden = arc && name.length && emoji.length;
    line.hidden = arc;
    chevron.hidden = arc && ![[header valueForKey:@"hovered"] boolValue] && ![[header valueForKey:@"collapsed"] boolValue];
    if (arc && name.length) {
        [title sizeToFit];
        NSRect frame = title.frame;
        frame.origin.x = emoji.length ? 24 : 41;
        frame.origin.y = round(NSMidY(header.bounds) - NSHeight(frame) / 2);
        title.frame = frame;
        if (!pin.hidden) pin.frame = NSMakeRect(25, NSMidY(header.bounds) - 8, 16, 16);
    }
}

static void DPHeader_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPHeader_layout, self);
    DPRestyle(self);
}

static void DPHeader_restyle(NSView *self, SEL _cmd) {
    DPCallOriginal(DPHeader_restyle, self);
    DPRestyle(self);
}

void DPArcInstallSpaceLabel(void) {
    if (!objc_getClass("DPPinnedHeader")) return;
    DPHook("DPPinnedHeader", @selector(layout), (IMP)DPHeader_layout);
    DPHook("DPPinnedHeader", NSSelectorFromString(@"restyle"), (IMP)DPHeader_restyle);
}

void DPArcApplySpaceLabel(void) {
    Class cls = objc_getClass("DPPinnedHeader");
    for (NSWindow *window in NSApp.windows)
        DPFindView(window.contentView, ^BOOL(NSView *v) {
            if (cls && [v isKindOfClass:cls]) v.needsLayout = YES;
            return NO;
        });
}
