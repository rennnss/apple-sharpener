#import <AppKit/AppKit.h>
#import "ZKSwizzle.h"
#import <notify.h>

/**
 * This file contains swizzled implementations to enforce custom window corner radius on macOS application windows.
 * When enabled, the tweak overrides the default corner radius by setting the window's cornerRadius property.
 * This approach uses the native macOS window corner masking for better compatibility.
 * When disabled, the original system behavior is used.
 */

// Global flags and default radius value
static BOOL enableSharpener = YES;
static BOOL enableCustomRadius = YES;
static NSInteger customRadius = 0;

// Cache for corner mask to avoid recreating it repeatedly
static NSImage *_cachedSquareCornerMask = nil;

#pragma mark - Notification Wiring

// Register notifications on load so the CLI can control radius and enable/disable state.
// Forward declaration for toggleSquareCorners used in handlers below.
void toggleSquareCorners(BOOL enable, NSInteger radius);
static void setupSharpenerNotifications(void) __attribute__((constructor));
static void setupSharpenerNotifications(void) {
    dispatch_queue_t queue = dispatch_get_main_queue();

    // Persistent state keys
    static const char *kNotifyEnabled = "com.aspauldingcode.apple_sharpener.enabled";
    static const char *kNotifyRadius  = "com.aspauldingcode.apple_sharpener.set_radius";

    // Hydrate current state at load (so newly injected apps use latest settings)
    {
        int tokenEnabled = 0;
        uint64_t enabledState = 1; // default ON
        if (notify_register_check(kNotifyEnabled, &tokenEnabled) == NOTIFY_STATUS_OK) {
            notify_get_state(tokenEnabled, &enabledState);
        }
        enableSharpener = (enabledState != 0);
    }
    {
        int tokenRadius = 0;
        uint64_t radiusState = 0; // default 0 (square corners)
        if (notify_register_check(kNotifyRadius, &tokenRadius) == NOTIFY_STATUS_OK) {
            notify_get_state(tokenRadius, &radiusState);
        }
        customRadius = (NSInteger)radiusState;
    }

    // Apply hydrated state to all existing windows
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
    notify_register_dispatch("com.aspauldingcode.apple_sharpener.set_radius", &tokenSetRadius, queue, ^(int t){
        uint64_t state = 0;
        // Read radius value carried on the notification token
        if (notify_get_state(t, &state) == NOTIFY_STATUS_OK) {
            toggleSquareCorners(enableSharpener, (NSInteger)state);
        }
    });

    // Listen for enabled state changes (persistent single channel)
    int tokenEnabledDispatch = 0;
    notify_register_dispatch(kNotifyEnabled, &tokenEnabledDispatch, queue, ^(int t){
        uint64_t state = 1;
        if (notify_get_state(t, &state) == NOTIFY_STATUS_OK) {
            toggleSquareCorners(state != 0, customRadius);
        }
    });
}

#pragma mark - Helper Functions

// Check if a window is a standard application window.
// Inlined for performance since it's called frequently
static inline BOOL isStandardAppWindow(NSWindow *window) {
    if (!window) return NO;
    NSWindowStyleMask mask = window.styleMask;
    return ((mask & NSWindowStyleMaskTitled) &&
            !(mask & (NSWindowStyleMaskHUDWindow | NSWindowStyleMaskUtilityWindow)));
}

// Apply the desired corner radius to a given window.
static void applyCornerRadiusToWindow(NSWindow *window) {
    if (!isStandardAppWindow(window)) return;
    
    // Only apply our custom radius when enabled; otherwise let the system manage defaults
    if (!(enableSharpener && enableCustomRadius)) {
        return;
    }
    
    // Use setValue:forKey: without exception handling overhead
    [(id)window setValue:@(customRadius) forKey:@"cornerRadius"];
    
    // Invalidate shadow after radius change
    [window invalidateShadow];
}

#pragma mark - Tweak API

/**
 * Configures the custom window radius feature.
 *
 * @param enable YES to enable custom radius, NO to use system default
 * @param radius The corner radius to apply when enabled
 */
void toggleSquareCorners(BOOL enable, NSInteger radius) {
    BOOL stateChanged = (enableSharpener != enable || customRadius != MAX(0, radius));
    
    enableSharpener = enable;
    customRadius = MAX(0, radius);
    
    // Invalidate cached mask if radius changed
    if (stateChanged && _cachedSquareCornerMask) {
        _cachedSquareCornerMask = nil;
    }
    
    // Only update windows if state actually changed
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

#pragma mark - Swizzled NSWindow

ZKSwizzleInterface(AS_NSWindow_CornerRadius, NSWindow, NSWindow)
@implementation AS_NSWindow_CornerRadius

- (id)_cornerMask {
    if (!enableSharpener || !enableCustomRadius)
        return ZKOrig(id);
    
    // When customRadius is 0 we return a cached 1x1 white image mask for square corners.
    if (customRadius == 0 && isStandardAppWindow(self)) {
        if (!_cachedSquareCornerMask) {
            _cachedSquareCornerMask = [[NSImage alloc] initWithSize:NSMakeSize(1, 1)];
            [_cachedSquareCornerMask lockFocus];
            [[NSColor whiteColor] set];
            NSRectFill(NSMakeRect(0, 0, 1, 1));
            [_cachedSquareCornerMask unlockFocus];
        }
        return _cachedSquareCornerMask;
    }
    return ZKOrig(id);
}

- (void)setFrame:(NSRect)frameRect display:(BOOL)flag {
    ZKOrig(void, frameRect, flag);
    if (enableSharpener && enableCustomRadius && isStandardAppWindow(self))
        applyCornerRadiusToWindow(self);
}

- (void)toggleFullScreen:(id)sender {
    ZKOrig(void, sender);
    // setFrame:display: will handle corner radius update
}

- (void)_updateCornerMask {
    if (enableSharpener && enableCustomRadius && isStandardAppWindow(self)) {
        applyCornerRadiusToWindow(self);
    } else {
        ZKOrig(void);
    }
}

// This thing here is what determines if it's going to be square, or rounded with custom radius.
- (void)_setCornerRadius:(CGFloat)radius {
    if (!enableSharpener || !enableCustomRadius || !isStandardAppWindow(self)) {
        ZKOrig(void, radius);
        return;
    }

    if (customRadius == 0) {
        // Explicitly restore square corners
        ZKOrig(void, 0);
        return;
    }

    // Otherwise, use the custom rounding behavior
    CGFloat r = (self.styleMask & NSWindowStyleMaskFullScreen) ? 0 : customRadius;
    ZKOrig(void, r);
}


- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)style backing:(NSBackingStoreType)backingStoreType defer:(BOOL)flag {
    id result = ZKOrig(id, contentRect, style, backingStoreType, flag);
    if (result && enableSharpener && enableCustomRadius) {
            applyCornerRadiusToWindow((NSWindow *)result);
    }
    return result;
}

@end

#pragma mark - Swizzled Titlebar Decoration View

ZKSwizzleInterface(AS_TitlebarDecorationView, _NSTitlebarDecorationView, NSView)
@implementation AS_TitlebarDecorationView

- (void)viewDidMoveToWindow {
    ZKOrig(void);
    
    // Keep decoration view visibility in sync with current state
    BOOL shouldHide = (enableSharpener && 
                       customRadius == 0 && 
                       self.window && 
                       isStandardAppWindow(self.window));
    self.hidden = shouldHide;
}

- (void)drawRect:(NSRect)dirtyRect {
    if (enableSharpener && customRadius == 0 && isStandardAppWindow(self.window)) {
        return;  // Suppress drawing when square corners are in use
    }
    // Ensure the view is visible again when not suppressing drawing
    if (self.hidden) self.hidden = NO;
    
    ZKOrig(void, dirtyRect);
}

@end
