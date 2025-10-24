#import <AppKit/AppKit.h>
#import "ZKSwizzle.h"
#import <notify.h>

/**
 * Window sharpening implementation for apple-sharpener
 * Contains swizzled implementations to enforce custom window corner radius on macOS application windows.
 * When enabled, the tweak overrides the default corner radius by setting the window's cornerRadius property.
 */

#pragma mark - Global State

static BOOL enableSharpener = YES;
static BOOL enableCustomRadius = YES;
static NSInteger customRadius = 0;

#pragma mark - Forward Declarations

void toggleSquareCorners(BOOL enable, NSInteger radius);
static void setupWindowNotifications(void) __attribute__((constructor));

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

static void setupWindowNotifications(void) {
    // Perform grouped swizzling after +load has run to avoid class-method collisions
    ZKSwizzleGroup(APPLE_SHARPENER);

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
    notify_register_dispatch("com.aspauldingcode.apple_sharpener.enable", &tokenEnable, queue, ^(int __unused t){
        toggleSquareCorners(YES, customRadius);
    });

    int tokenDisable = 0;
    notify_register_dispatch("com.aspauldingcode.apple_sharpener.disable", &tokenDisable, queue, ^(int __unused t){
        toggleSquareCorners(NO, customRadius);
    });

    int tokenToggle = 0;
    notify_register_dispatch("com.aspauldingcode.apple_sharpener.toggle", &tokenToggle, queue, ^(int __unused t){
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

 ZKSwizzleInterfaceGroup(AS_NSWindow_CornerRadius, NSWindow, NSWindow, APPLE_SHARPENER)
@implementation AS_NSWindow_CornerRadius

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)style backing:(NSBackingStoreType)backingStoreType defer:(BOOL)flag {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-function-type-mismatch"
    id result = ZKOrig(id, contentRect, style, backingStoreType, flag);
#pragma clang diagnostic pop
    if (result && enableSharpener && enableCustomRadius) {
        applyCornerRadiusToWindow((NSWindow *)result);
    }
    return result;
}
#pragma clang diagnostic pop

- (void)setFrame:(NSRect)frameRect display:(BOOL)flag {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-function-type-mismatch"
    ZKOrig(void, frameRect, flag);
#pragma clang diagnostic pop
    if (enableSharpener && enableCustomRadius && isStandardAppWindow(self))
        applyCornerRadiusToWindow(self);
}

- (void)_updateCornerMask {
    if (enableSharpener && enableCustomRadius && isStandardAppWindow(self)) {
        applyCornerRadiusToWindow(self);
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-function-type-mismatch"
        ZKOrig(void);
#pragma clang diagnostic pop
    }
}

- (void)_setCornerRadius:(CGFloat)radius {
    if (!enableSharpener || !enableCustomRadius || !isStandardAppWindow(self)) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-function-type-mismatch"
        ZKOrig(void, radius);
#pragma clang diagnostic pop
        return;
    }

    if (customRadius == 0) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-function-type-mismatch"
        ZKOrig(void, 0);
#pragma clang diagnostic pop
        return;
    }

    CGFloat r = (self.styleMask & NSWindowStyleMaskFullScreen) ? 0 : customRadius;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-function-type-mismatch"
    ZKOrig(void, r);
#pragma clang diagnostic pop
}

- (id)_cornerMask {
    if (!enableSharpener || !enableCustomRadius)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-function-type-mismatch"
        return ZKOrig(id);
#pragma clang diagnostic pop
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-function-type-mismatch"
    return ZKOrig(id);
#pragma clang diagnostic pop
}

- (void)toggleFullScreen:(id)sender {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-function-type-mismatch"
    ZKOrig(void, sender);
#pragma clang diagnostic pop
}

@end

#pragma mark - Swizzled Titlebar Decoration View

 ZKSwizzleInterfaceGroup(AS_TitlebarDecorationView, _NSTitlebarDecorationView, NSView, APPLE_SHARPENER)
@implementation AS_TitlebarDecorationView

- (void)viewDidMoveToWindow {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-function-type-mismatch"
    ZKOrig(void);
#pragma clang diagnostic pop
}

- (void)drawRect:(NSRect)dirtyRect {
    if (enableSharpener && customRadius != 0 && isStandardAppWindow(self.window)) {
        return;  // Suppress drawing when custom radius is used (but not when radius is 0)
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-function-type-mismatch"
    // Call original implementation
    void (*originalDrawRect)(id, SEL, NSRect) = (void (*)(id, SEL, NSRect))ZKOriginalImplementation(self, _cmd, __PRETTY_FUNCTION__);
    originalDrawRect(self, _cmd, dirtyRect);
#pragma clang diagnostic pop
}

@end