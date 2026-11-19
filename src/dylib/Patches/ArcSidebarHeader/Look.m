#import "Look.h"

static char DPStateKey;

@implementation DPArcState
- (void)dealloc { [_lightsTimer invalidate]; }
@end

DPArcState *DPArcStateOf(NSView *host) {
    DPArcState *state = DPGet(host, &DPStateKey);
    if (!state) DPSet(host, &DPStateKey, state = [DPArcState new]);
    return state;
}

NSView *DPArcLights(NSView *header) { return DPFindView(header, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaTrafficLights); }); }

// The window buttons' centre line, which the sidebar, back, forward and reload buttons share.
CGFloat DPArcCentreLine(DPArcState *state) {
    NSView *lights = DPArcLights(state.header);
    return lights ? NSMidY([lights convertRect:lights.bounds toView:state.host]) : NSMidY(state.header.frame);
}

NSView *DPArcClipIn(NSView *capsule) {
    for (NSView *sub in capsule.subviews) if ([sub.identifier isEqual:@"DPArcClip"]) return sub;
    return nil;
}

static BOOL DPEditing(DPArcState *state) {
    NSResponder *responder = state.window.firstResponder;
    if ([responder isKindOfClass:NSTextView.class] && ((NSTextView *)responder).isFieldEditor) responder = (NSResponder *)((NSTextView *)responder).delegate;
    return [responder isKindOfClass:NSView.class] && [(NSView *)responder isDescendantOf:state.parts[@"address"]];
}

static NSTextView *DPAddressText(NSView *address) {
    return (NSTextView *)DPFindView(address, ^BOOL(NSView *v) { return [v isKindOfClass:NSTextView.class]; });
}

// Arc shows only the site: crunchyroll.com, not https://www.crunchyroll.com/series/….
static NSString *DPSiteOf(NSString *text) {
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!trimmed.length || [trimmed containsString:@" "]) return trimmed;
    NSURL *url = [NSURL URLWithString:[trimmed containsString:@"://"] ? trimmed : [@"https://" stringByAppendingString:trimmed]];
    NSString *host = url.host;
    if (!host.length || ![host containsString:@"."]) return trimmed;
    return [host hasPrefix:@"www."] ? [host substringFromIndex:4] : host;
}

static void DPFade(NSView *view, CGFloat alpha) {
    if (!view || fabs(view.alphaValue - alpha) < 0.01) return;
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.15;
        view.animator.alphaValue = alpha;
    }];
}

static void DPStyleArrow(NSControl *control, NSString *symbol) {
    if (!control) return;
    NSImageView *arrow = nil;
    for (NSView *sub in control.subviews) if ([sub.identifier isEqual:@"DPArcArrow"]) arrow = (NSImageView *)sub;
    if (!arrow) {
        arrow = [[NSImageView alloc] initWithFrame:control.bounds];
        arrow.identifier = @"DPArcArrow";
        arrow.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration configurationWithPointSize:14 weight:NSFontWeightMedium];
        arrow.image = [[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil] imageWithSymbolConfiguration:config];
        [control addSubview:arrow];
    }
    for (NSView *sub in control.subviews) if (sub != arrow && sub.alphaValue != 0) sub.alphaValue = 0;
    NSColor *tint = control.isEnabled ? NSColor.secondaryLabelColor : NSColor.tertiaryLabelColor;
    if (arrow.contentTintColor != tint) arrow.contentTintColor = tint;
}

static void DPUnstyleArrow(NSView *control) {
    for (NSView *sub in [control.subviews copy]) {
        if ([sub.identifier isEqual:@"DPArcArrow"]) [sub removeFromSuperview];
        else sub.alphaValue = 1;
    }
}

void DPArcRestyle(DPArcState *state) {
    NSView *capsule = state.parts[@"address"].superview, *address = state.parts[@"address"];
    if (!state.host || !address) return;
    DPStyleArrow((NSControl *)state.parts[@"back"], @"arrow.left");
    DPStyleArrow((NSControl *)state.parts[@"forward"], @"arrow.right");

    // Arc's capsule is one soft shape: Dia's own hover background inside it would make a second one.
    NSView *inner = address.subviews.firstObject;
    if (inner.layer.backgroundColor && CGColorGetAlpha(inner.layer.backgroundColor) > 0) inner.layer.backgroundColor = NSColor.clearColor.CGColor;

    BOOL editing = DPEditing(state), open = editing || state.overCapsule;
    NSTextView *text = DPAddressText(address);
    NSView *scroller = text.enclosingScrollView ?: text;
    if (!state.label) {
        state.label = [NSTextField labelWithString:@""];
        state.label.font = [NSFont systemFontOfSize:13];
        state.label.textColor = [NSColor.labelColor colorWithAlphaComponent:0.72];
        state.label.lineBreakMode = NSLineBreakByTruncatingTail;
        state.label.identifier = @"DPArcSite";
    }
    if (state.label.superview != capsule) [capsule addSubview:state.label positioned:NSWindowBelow relativeTo:nil];
    NSString *site = DPSiteOf(text.string ?: @"");
    if (![state.label.stringValue isEqual:site]) state.label.stringValue = site;
    // At rest Arc shows the site alone; the bookmark, split and site buttons come in under the pointer.
    NSRect area = open && scroller ? [scroller convertRect:scroller.bounds toView:capsule] : [address convertRect:address.bounds toView:capsule];
    DPFindView(address, ^BOOL(NSView *v) {
        if (DPIsKind(v, DPDiaHoverableControl) && ![v isDescendantOf:scroller]) DPFade(v, open ? 1 : 0);
        return NO;
    });
    CGFloat height = ceil(state.label.intrinsicContentSize.height);
    NSRect frame = NSMakeRect(DPArcTextInset, round((NSHeight(capsule.bounds) - height) / 2), MAX(0, (open ? NSMaxX(area) : NSWidth(capsule.bounds) - DPArcTextInset) - DPArcTextInset), height);
    if (!NSEqualRects(state.label.frame, frame)) state.label.frame = frame;
    if (scroller.alphaValue != (editing ? 1 : 0)) scroller.alphaValue = editing ? 1 : 0;
    if (state.label.hidden != editing) state.label.hidden = editing;
    DPFade(DPArcClipIn(capsule), open ? 1 : 0);
    if ([capsule respondsToSelector:@selector(setHovered:)]) [capsule setValue:@(state.overCapsule && !editing) forKey:@"hovered"];
}

void DPArcUnstyle(DPArcState *state) {
    DPUnstyleArrow(state.parts[@"back"]);
    DPUnstyleArrow(state.parts[@"forward"]);
    NSTextView *text = DPAddressText(state.parts[@"address"]);
    (text.enclosingScrollView ?: text).alphaValue = 1;
    DPFindView(state.parts[@"address"], ^BOOL(NSView *v) {
        if (DPIsKind(v, DPDiaHoverableControl)) v.alphaValue = 1;
        return NO;
    });
    DPArcClipIn(state.parts[@"address"].superview).alphaValue = 1;
    [state.label removeFromSuperview];
    [state.lightsTimer invalidate];
    state.lightsProgress = 1;
    DPArcLights(state.header).alphaValue = 1;
}
