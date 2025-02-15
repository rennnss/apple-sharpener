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

#pragma mark - Helper Functions

// Check if a window is a standard application window.
static BOOL isStandardAppWindow(NSWindow *window) {
    return ((window.styleMask & NSWindowStyleMaskTitled) &&
            !(window.styleMask & NSWindowStyleMaskHUDWindow) &&
            !(window.styleMask & NSWindowStyleMaskUtilityWindow));
}

// Apply the desired corner radius to a given window.
static void applyCornerRadiusToWindow(NSWindow *window) {
    if (!isStandardAppWindow(window)) return;
    
    if (window.styleMask & NSWindowStyleMaskFullScreen) {
        [(id)window setValue:@(0) forKey:@"cornerRadius"];
    } else if (enableSharpener && enableCustomRadius) {
        [(id)window setValue:@(customRadius) forKey:@"cornerRadius"];
    } else {
        [(id)window setValue:@(10) forKey:@"cornerRadius"];
    }
    [window invalidateShadow];
    [window.contentView setNeedsDisplay:YES];
}

#pragma mark - Tweak API

/**
 * Configures the custom window radius feature.
 *
 * @param enable YES to enable custom radius, NO to use system default
 * @param radius The corner radius to apply when enabled
 */
void toggleSquareCorners(BOOL enable, NSInteger radius) {
    enableSharpener = enable;
    customRadius = MAX(0, radius);
    
    // Update all windows
    for (NSWindow *window in [NSApplication sharedApplication].windows) {
        applyCornerRadiusToWindow(window);
    }
}

#pragma mark - Swizzled NSWindow

ZKSwizzleInterface(AS_NSWindow_CornerRadius, NSWindow, NSWindow)
@implementation AS_NSWindow_CornerRadius

- (id)_cornerMask {
    if (!enableSharpener || !enableCustomRadius)
        return ZKOrig(id);
    
    // When customRadius is 0 we return a 1x1 white image mask for square corners.
    if (customRadius == 0 && isStandardAppWindow(self)) {
        NSImage *squareCornerMask = [[NSImage alloc] initWithSize:NSMakeSize(1, 1)];
        [squareCornerMask lockFocus];
        [[NSColor whiteColor] set];
        NSRectFill(NSMakeRect(0, 0, 1, 1));
        [squareCornerMask unlockFocus];
        return squareCornerMask;
    }
    return ZKOrig(id);
}

- (void)setFrame:(NSRect)frameRect display:(BOOL)flag {
    ZKOrig(void, frameRect, flag);
    
    if (!enableSharpener || !enableCustomRadius) {
        [(id)self setValue:@(10) forKey:@"cornerRadius"];
        [self invalidateShadow];
        return;
    }
    
    if (!isStandardAppWindow(self))
        return;
    
    applyCornerRadiusToWindow(self);
}

- (void)toggleFullScreen:(id)sender {
    // Let the setFrame:display: update the corner radius after the transition.
    ZKOrig(void, sender);
}

@end

#pragma mark - Swizzled Titlebar Decoration View

ZKSwizzleInterface(AS_TitlebarDecorationView, _NSTitlebarDecorationView, NSView)
@implementation AS_TitlebarDecorationView

- (void)viewDidMoveToWindow {
    ZKOrig(void);
    
    if (!enableSharpener)
        return;
    
    // Hide decoration when using square corners on standard app windows.
    if (customRadius == 0 && self.window && isStandardAppWindow(self.window)) {
        self.hidden = YES;
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    if (!enableSharpener) {
        ZKOrig(void, dirtyRect);
        return;
    }
    
    if (customRadius == 0 && isStandardAppWindow(self.window))
        return;  // Suppress drawing when square corners are in use.
    
    ZKOrig(void, dirtyRect);
}

@end

#pragma mark - Darwin Notification Handler

// Use the low‑level Darwin notify API instead of NSDistributedNotificationCenter.
// This avoids loading extra system agents.
static int tokenEnable, tokenDisable, tokenToggle, tokenSetRadius;

__attribute__((constructor))
static void initializeSharpenerDarwinNotificationHandler() {
    // Reset initial state
    customRadius = 0;
    enableSharpener = YES;
    enableCustomRadius = YES;
    
    // Register for the "enable" notification.
    notify_register_dispatch("com.aspauldingcode.apple_sharpener.enable",
                               &tokenEnable,
                               dispatch_get_main_queue(),
                               ^(int __unused token) {
        enableCustomRadius = YES;
        for (NSWindow *window in [NSApplication sharedApplication].windows) {
            NSRect originalFrame = window.frame;
            NSRect tempFrame = NSInsetRect(originalFrame, 0.5, 0.5);
            [window setFrame:tempFrame display:YES];
            [window setFrame:originalFrame display:YES];
            NSView *titlebarView = [window valueForKey:@"_titlebarDecorationView"];
            [titlebarView setNeedsDisplay:YES];
        }
        toggleSquareCorners(YES, customRadius);
    });
    
    // Register for the "disable" notification.
    notify_register_dispatch("com.aspauldingcode.apple_sharpener.disable",
                               &tokenDisable,
                               dispatch_get_main_queue(),
                               ^(int __unused token) {
        toggleSquareCorners(NO, customRadius);
    });
    
    // Register for the "toggle" notification.
    notify_register_dispatch("com.aspauldingcode.apple_sharpener.toggle",
                               &tokenToggle,
                               dispatch_get_main_queue(),
                               ^(int __unused token) {
        enableCustomRadius = !enableCustomRadius;
        toggleSquareCorners(enableCustomRadius, customRadius);
    });
    
    // Register for "set_radius". Use notify_get_state to read the new radius.
    notify_register_dispatch("com.aspauldingcode.apple_sharpener.set_radius",
                               &tokenSetRadius,
                               dispatch_get_main_queue(),
                               ^(int token) {
        uint64_t newRadius = 0;
        notify_get_state(token, &newRadius);
        toggleSquareCorners(enableCustomRadius, newRadius);
    });
}