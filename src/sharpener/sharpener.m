#import <AppKit/AppKit.h>
#import "ZKSwizzle.h"
#import <notify.h>

/**
 * This file contains swizzled implementations to enforce custom window corner radius on macOS application windows.
 * When enabled, the tweak overrides the default corner radius by setting the window's cornerRadius property.
 */

#pragma mark - Global State

static BOOL enableSharpener = YES;
static BOOL enableCustomRadius = YES;
static NSInteger customRadius = 0;

#pragma mark - Forward Declarations

void toggleSquareCorners(BOOL enable, NSInteger radius);
static void setupSharpenerNotifications(void) __attribute__((constructor));

#pragma mark - Helper Functions

// Check if a window is a standard application window.
// Inlined for performance since it's called frequently
static inline BOOL isStandardAppWindow(NSWindow *window) {
    if (!window) return NO;
    NSWindowStyleMask mask = window.styleMask;
    return ((mask & NSWindowStyleMaskTitled) &&
            !(mask & (NSWindowStyleMaskHUDWindow | NSWindowStyleMaskUtilityWindow)));
}

static void applyCornerRadiusToWindow(NSWindow *window) {
    if (!isStandardAppWindow(window)) return;
    if (!(enableSharpener && enableCustomRadius)) return;
    
    [(id)window setValue:@(customRadius) forKey:@"cornerRadius"];
    [window invalidateShadow];
}

#pragma mark - Public API

void toggleSquareCorners(BOOL enable, NSInteger radius) {
    BOOL stateChanged = (enableSharpener != enable || customRadius != MAX(0, radius));
    
    enableSharpener = enable;
    customRadius = MAX(0, radius);
    
    if (stateChanged) {
        for (NSWindow *window in [NSApplication sharedApplication].windows) {
            if (enableSharpener && enableCustomRadius) {
                applyCornerRadiusToWindow(window);
            } else if (isStandardAppWindow(window)) {
                [(id)window setValue:@0 forKey:@"cornerRadius"];
                [window invalidateShadow];
            }
        }
    }
}

#pragma mark - Notification Setup

static void setupSharpenerNotifications(void) {
    dispatch_queue_t queue = dispatch_get_main_queue();

    static const char *kNotifyEnabled = "com.aspauldingcode.apple_sharpener.enabled";
    static const char *kNotifyRadius  = "com.aspauldingcode.apple_sharpener.set_radius";

    // Hydrate current state at load
    {
        int tokenEnabled = 0;
        uint64_t enabledState = 1;
        if (notify_register_check(kNotifyEnabled, &tokenEnabled) == NOTIFY_STATUS_OK) {
            notify_get_state(tokenEnabled, &enabledState);
        }
        enableSharpener = (enabledState != 0);
    }
    {
        int tokenRadius = 0;
        uint64_t radiusState = 0;
        if (notify_register_check(kNotifyRadius, &tokenRadius) == NOTIFY_STATUS_OK) {
            notify_get_state(tokenRadius, &radiusState);
        }
        customRadius = (NSInteger)radiusState;
    }

    toggleSquareCorners(enableSharpener, customRadius);

    int tokenEnable = 0;
    notify_register_dispatch("com.aspauldingcode.apple_sharpener.enable", &tokenEnable, queue, ^(int t){
        toggleSquareCorners(YES, customRadius);
    });

    int tokenDisable = 0;
    notify_register_dispatch("com.aspauldingcode.apple_sharpener.disable", &tokenDisable, queue, ^(int t){
        toggleSquareCorners(NO, customRadius);
    });

    int tokenToggle = 0;
    notify_register_dispatch("com.aspauldingcode.apple_sharpener.toggle", &tokenToggle, queue, ^(int t){
        toggleSquareCorners(!enableSharpener, customRadius);
    });

    int tokenSetRadius = 0;
    notify_register_dispatch(kNotifyRadius, &tokenSetRadius, queue, ^(int t){
        uint64_t state = 0;
        if (notify_get_state(t, &state) == NOTIFY_STATUS_OK) {
            toggleSquareCorners(enableSharpener, (NSInteger)state);
        }
    });
}

#pragma mark - Swizzled NSWindow

ZKSwizzleInterface(AS_NSWindow_CornerRadius, NSWindow, NSWindow)
@implementation AS_NSWindow_CornerRadius

- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)style backing:(NSBackingStoreType)backingStoreType defer:(BOOL)flag {
    id result = ZKOrig(id, contentRect, style, backingStoreType, flag);
    if (result && enableSharpener && enableCustomRadius) {
        applyCornerRadiusToWindow((NSWindow *)result);
    }
    return result;
}

- (void)setFrame:(NSRect)frameRect display:(BOOL)flag {
    ZKOrig(void, frameRect, flag);
    if (enableSharpener && enableCustomRadius && isStandardAppWindow(self))
        applyCornerRadiusToWindow(self);
}

- (void)_updateCornerMask {
    if (enableSharpener && enableCustomRadius && isStandardAppWindow(self)) {
        applyCornerRadiusToWindow(self);
    } else {
        ZKOrig(void);
    }
}

- (void)_setCornerRadius:(CGFloat)radius {
    if (!enableSharpener || !enableCustomRadius || !isStandardAppWindow(self)) {
        ZKOrig(void, radius);
        return;
    }

    if (customRadius == 0) {
        ZKOrig(void, 0);
        return;
    }

    CGFloat r = (self.styleMask & NSWindowStyleMaskFullScreen) ? 0 : customRadius;
    ZKOrig(void, r);
}

- (id)_cornerMask {
    if (!enableSharpener || !enableCustomRadius)
        return ZKOrig(id);
    return ZKOrig(id);
}

- (void)toggleFullScreen:(id)sender {
    ZKOrig(void, sender);
}

@end

#pragma mark - Swizzled Titlebar Decoration View

ZKSwizzleInterface(AS_TitlebarDecorationView, _NSTitlebarDecorationView, NSView)
@implementation AS_TitlebarDecorationView

- (void)viewDidMoveToWindow {
    ZKOrig(void);
}

- (void)drawRect:(NSRect)dirtyRect {
    if (enableSharpener && customRadius != 0 && isStandardAppWindow(self.window)) {
        return;  // Suppress drawing when custom radius is used (but not when radius is 0)
    }
    ZKOrig(void, dirtyRect);
}

@end
