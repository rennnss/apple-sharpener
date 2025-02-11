#import <AppKit/AppKit.h>
#import "ZKSwizzle.h"

/**
 * This file contains swizzled implementations to enforce custom window corner radius on macOS application windows.
 * When enabled, the tweak overrides the default corner radius by setting the window's cornerRadius property.
 * This approach uses the native macOS window corner masking for better compatibility.
 * When disabled, the original system behavior is used.
 */

// Global flag to control whether the custom radius is applied,
// and the radius value to use when enabled.
static BOOL enableCustomRadius = YES;
static NSInteger customRadius = 40;

/**
 * Configures the custom window radius feature.
 *
 * @param enable YES to enable custom radius, NO to use system default
 * @param radius The corner radius to apply when enabled
 */
void toggleSquareCorners(BOOL enable, NSInteger radius) {
    enableCustomRadius = enable;
    customRadius = MAX(0, radius); // Ensure radius is not negative
    
    // Update all existing windows
    for (NSWindow *window in [NSApplication sharedApplication].windows) {
        if (window.styleMask & NSWindowStyleMaskFullScreen) {
            [(id)window setValue:@(0) forKey:@"cornerRadius"];
        } else {
            [(id)window setValue:@(customRadius) forKey:@"cornerRadius"];
        }
        [window invalidateShadow];
        [window.contentView setNeedsDisplay:YES];
    }
}

/**
 * Swizzled NSWindow implementation to enforce custom corner radius for application windows.
 */
ZKSwizzleInterface(AS_NSWindow_CornerRadius, NSWindow, NSWindow)
@implementation AS_NSWindow_CornerRadius

- (id)_cornerMask {
    // Only modify windows that are titled (application windows)
    if (customRadius == 0 && (self.styleMask & NSWindowStyleMaskTitled)) {
        // Create a 1x1 white image for square corners
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
    
    // Apply appropriate radius after frame change
    if (self.styleMask & NSWindowStyleMaskFullScreen) {
        [(id)self setValue:@(0) forKey:@"cornerRadius"];
        [self invalidateShadow];
    } else if (enableCustomRadius && (self.styleMask & NSWindowStyleMaskTitled)) {
        [(id)self setValue:@(customRadius) forKey:@"cornerRadius"];
        [self invalidateShadow];
    }
}

- (void)toggleFullScreen:(id)sender {
    // Keep current radius until fullscreen transition completes
    ZKOrig(void, sender);
    
    // Radius will be handled by setFrame:display: after transition
}

@end

/**
 * Swizzled implementation of the private _NSTitlebarDecorationView to handle titlebar appearance
 * when custom radius is active.
 */
ZKSwizzleInterface(AS_TitlebarDecorationView, _NSTitlebarDecorationView, NSView)
@implementation AS_TitlebarDecorationView

- (void)viewDidMoveToWindow {
    ZKOrig(void);
    
    // Only hide decoration for windows that are titled (application windows)
    if (customRadius == 0 && self.window && (self.window.styleMask & NSWindowStyleMaskTitled)) {
        self.hidden = YES;  // Hide the decoration view entirely
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    // Only prevent drawing for titled windows with radius 0
    if (customRadius == 0 && self.window.styleMask & NSWindowStyleMaskTitled) {
        return;  // No-op to prevent any drawing
    }
    
    ZKOrig(void);
}

@end