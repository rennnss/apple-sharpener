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

#pragma mark - Helper Functions

// Check if a window should have sharp corners applied.
// Excludes alert panels, modal dialogs, and special system windows.
// Inlined for performance since it's called frequently
static inline BOOL isStandardAppWindow(NSWindow *window) {
    if (!window) return NO;
    
    // Exclude NSPanel subclasses (alerts, modals, etc.)
    if ([window isKindOfClass:NSClassFromString(@"NSPanel")]) {
        return NO;
    }
    
    // Exclude windows with utility or HUD style (popovers, tooltips, etc.)
    NSWindowStyleMask mask = window.styleMask;
    if (mask & (NSWindowStyleMaskUtilityWindow | NSWindowStyleMaskHUDWindow)) {
        return NO;
    }
    
    // Exclude windows that are modal sheets
    if (window.sheet || window.sheetParent) {
        return NO;
    }
    
    // Apply only to titled windows
    return (mask & NSWindowStyleMaskTitled) != 0;
}

// Apply the desired corner radius to a given window.
static void applyCornerRadiusToWindow(NSWindow *window) {
    if (!isStandardAppWindow(window)) return;
    
    // Calculate radius once
    CGFloat radius;
    if (window.styleMask & NSWindowStyleMaskFullScreen) {
        radius = 0;
    } else if (enableSharpener && enableCustomRadius) {
        radius = customRadius;
    } else {
        radius = 10;
    }
    
    // Use setValue:forKey: without exception handling overhead
    // This is safe on macOS and more performant than @try/@catch
    [(id)window setValue:@(radius) forKey:@"cornerRadius"];
    
    // Only invalidate shadow if radius actually changed
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
        NSArray<NSWindow *> *windows = [NSApplication sharedApplication].windows;
        for (NSWindow *window in windows) {
            applyCornerRadiusToWindow(window);
        }
    }
}

#pragma mark - Swizzled NSWindow

ZKSwizzleInterface(AS_NSWindow_CornerRadius, NSWindow, NSWindow)
@implementation AS_NSWindow_CornerRadius

- (id)_cornerMask {
    // Apply to all titled windows when sharpener is enabled
    if (enableSharpener && enableCustomRadius && isStandardAppWindow(self)) {
        if (customRadius == 0) {
            // Return a 1x1 white image mask for completely square corners
            if (!_cachedSquareCornerMask) {
                _cachedSquareCornerMask = [[NSImage alloc] initWithSize:NSMakeSize(1, 1)];
                [_cachedSquareCornerMask lockFocus];
                [[NSColor whiteColor] set];
                NSRectFill(NSMakeRect(0, 0, 1, 1));
                [_cachedSquareCornerMask unlockFocus];
            }
            return _cachedSquareCornerMask;
        }
    }
    return ZKOrig(id);
}

- (void)setFrame:(NSRect)frameRect display:(BOOL)flag {
    ZKOrig(void, frameRect, flag);
    
    if (!isStandardAppWindow(self))
        return;
    
    if (!enableSharpener || !enableCustomRadius) {
        // Reset to default radius
        [(id)self setValue:@(10) forKey:@"cornerRadius"];
        [self invalidateShadow];
        return;
    }
    
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

- (void)_setCornerRadius:(CGFloat)radius {
    if (enableSharpener && enableCustomRadius && isStandardAppWindow(self)) {
        ZKOrig(void, customRadius);
    } else {
        ZKOrig(void, radius);
    }
}

- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)style backing:(NSBackingStoreType)backingStoreType defer:(BOOL)flag {
    id result = ZKOrig(id, contentRect, style, backingStoreType, flag);
    if (result && enableSharpener && enableCustomRadius && isStandardAppWindow((NSWindow *)result)) {
        applyCornerRadiusToWindow((NSWindow *)result);
        // Force corner mask update
        [(NSWindow *)result setBackgroundColor:[(NSWindow *)result backgroundColor]];
        [(NSWindow *)result display];
    }
    return result;
}

- (void)orderFront:(id)sender {
    ZKOrig(void, sender);
    if (enableSharpener && enableCustomRadius && isStandardAppWindow(self)) {
        applyCornerRadiusToWindow(self);
    }
}

- (void)orderWindow:(NSWindowOrderingMode)place relativeTo:(NSInteger)otherWin {
    ZKOrig(void, place, otherWin);
    if (enableSharpener && enableCustomRadius && isStandardAppWindow(self)) {
        applyCornerRadiusToWindow(self);
    }
}

@end

#pragma mark - Swizzled Titlebar Decoration View

ZKSwizzleInterface(AS_TitlebarDecorationView, _NSTitlebarDecorationView, NSView)
@implementation AS_TitlebarDecorationView

- (void)viewDidMoveToWindow {
    ZKOrig(void);
    
    if (enableSharpener && customRadius == 0 && self.window && isStandardAppWindow(self.window)) {
        self.hidden = YES;
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    if (enableSharpener && customRadius == 0 && isStandardAppWindow(self.window))
        return;  // Suppress drawing when square corners are in use
    
    ZKOrig(void, dirtyRect);
}

@end
