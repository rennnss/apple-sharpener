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
static BOOL enableSharpener = YES;
static BOOL enableCustomRadius = YES;
static NSInteger customRadius = 0;

/**
 * Configures the custom window radius feature.
 *
 * @param enable YES to enable custom radius, NO to use system default
 * @param radius The corner radius to apply when enabled
 */
void toggleSquareCorners(BOOL enable, NSInteger radius) {
    enableSharpener = enable;  // Set the main enable flag
    customRadius = MAX(0, radius); // Preserve radius setting
    
    // Update all existing windows
    for (NSWindow *window in [NSApplication sharedApplication].windows) {
        // Only modify standard application windows
        if (!(window.styleMask & NSWindowStyleMaskTitled) || 
            (window.styleMask & NSWindowStyleMaskHUDWindow) ||
            (window.styleMask & NSWindowStyleMaskUtilityWindow)) {
            continue;
        }
        
        if (window.styleMask & NSWindowStyleMaskFullScreen) {
            [(id)window setValue:@(0) forKey:@"cornerRadius"];
        } else if (enable) {
            [(id)window setValue:@(customRadius) forKey:@"cornerRadius"];
        } else {
            // Restore default corner radius when disabling
            [(id)window setValue:@(10) forKey:@"cornerRadius"]; // macOS default is 10
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
    if (!enableSharpener) return ZKOrig(id);
    
    // Only modify standard application windows
    if (customRadius == 0 && 
        (self.styleMask & NSWindowStyleMaskTitled) && 
        !(self.styleMask & NSWindowStyleMaskHUDWindow) &&
        !(self.styleMask & NSWindowStyleMaskUtilityWindow)) {
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
    
    if (!enableSharpener) return;
    
    // Only modify standard application windows
    if (!(self.styleMask & NSWindowStyleMaskTitled) ||
        (self.styleMask & NSWindowStyleMaskHUDWindow) ||
        (self.styleMask & NSWindowStyleMaskUtilityWindow)) {
        return;
    }
    
    // Apply appropriate radius after frame change
    if (self.styleMask & NSWindowStyleMaskFullScreen) {
        [(id)self setValue:@(0) forKey:@"cornerRadius"];
        [self invalidateShadow];
    } else if (enableCustomRadius) {
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
    
    if (!enableSharpener) return;
    
    // Only hide decoration for standard application windows
    if (customRadius == 0 && 
        self.window && 
        (self.window.styleMask & NSWindowStyleMaskTitled) &&
        !(self.window.styleMask & NSWindowStyleMaskHUDWindow) &&
        !(self.window.styleMask & NSWindowStyleMaskUtilityWindow)) {
        self.hidden = YES;  // Hide the decoration view entirely
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    if (!enableSharpener) {
        ZKOrig(void, dirtyRect);
        return;
    }
    
    // Only prevent drawing for standard application windows
    if (customRadius == 0 && 
        (self.window.styleMask & NSWindowStyleMaskTitled) &&
        !(self.window.styleMask & NSWindowStyleMaskHUDWindow) &&
        !(self.window.styleMask & NSWindowStyleMaskUtilityWindow)) {
        return;  // No-op to prevent any drawing
    }
    
    ZKOrig(void, dirtyRect);
}

@end

// ------------------------------------------------------------------------
// New distributed notification observer registration so the CLI tool
// can instruct this tweak to toggle, enable, disable, or set the radius.
// ------------------------------------------------------------------------

__attribute__((constructor))
static void initializeSharpenerDistributedNotificationHandler() {
    if (!enableSharpener) return;
    
    NSDistributedNotificationCenter *dc = [NSDistributedNotificationCenter defaultCenter];
    __weak NSDistributedNotificationCenter *weakDC = dc; // Use a weak reference to avoid retain cycles

    [dc addObserverForName:@"com.aspauldingcode.apple_sharpener.enable"
                      object:nil
                       queue:[NSOperationQueue mainQueue]
                  usingBlock:^(NSNotification * _Nonnull note) {
        if (!enableSharpener) return;
        (void)note; // silence unused parameter warning
        NSLog(@"Received enable notification");
        toggleSquareCorners(YES, customRadius);
        [weakDC postNotificationName:@"com.aspauldingcode.apple_sharpener.status"
                                object:nil
                              userInfo:@{@"enabled": @(YES), @"radius": @(customRadius)}
                    deliverImmediately:YES];
    }];

    [dc addObserverForName:@"com.aspauldingcode.apple_sharpener.disable"
                      object:nil
                       queue:[NSOperationQueue mainQueue]
                  usingBlock:^(NSNotification * _Nonnull note) {
        if (!enableSharpener) return;
        (void)note;
        NSLog(@"Received disable notification");
        toggleSquareCorners(NO, customRadius);
        [weakDC postNotificationName:@"com.aspauldingcode.apple_sharpener.status"
                                object:nil
                              userInfo:@{@"enabled": @(NO), @"radius": @(customRadius)}
                    deliverImmediately:YES];
    }];

    [dc addObserverForName:@"com.aspauldingcode.apple_sharpener.toggle"
                      object:nil
                       queue:[NSOperationQueue mainQueue]
                  usingBlock:^(NSNotification * _Nonnull note) {
        if (!enableSharpener) return;
        (void)note;
        NSLog(@"Received toggle notification");
        BOOL newState = !enableCustomRadius;
        toggleSquareCorners(newState, customRadius);
        [weakDC postNotificationName:@"com.aspauldingcode.apple_sharpener.status"
                                object:nil
                              userInfo:@{@"enabled": @(newState), @"radius": @(customRadius)}
                    deliverImmediately:YES];
    }];

    [dc addObserverForName:@"com.aspauldingcode.apple_sharpener.set_radius"
                      object:nil
                       queue:[NSOperationQueue mainQueue]
                  usingBlock:^(NSNotification * _Nonnull note) {
        if (!enableSharpener) return;
        (void)note;
        NSNumber *radiusNumber = note.userInfo[@"radius"];
        if (radiusNumber) {
            NSInteger newRadius = [radiusNumber integerValue];
            NSLog(@"Received set_radius notification: %ld", (long)newRadius);
            toggleSquareCorners(enableCustomRadius, newRadius);
            [weakDC postNotificationName:@"com.aspauldingcode.apple_sharpener.status"
                                    object:nil
                                  userInfo:@{@"enabled": @(enableCustomRadius), @"radius": @(customRadius)}
                        deliverImmediately:YES];
        }
    }];

    [dc addObserverForName:@"com.aspauldingcode.apple_sharpener.get_radius"
                      object:nil
                       queue:[NSOperationQueue mainQueue]
                  usingBlock:^(NSNotification * _Nonnull note) {
        if (!enableSharpener) return;
        (void)note;
        NSLog(@"Received get_radius notification");
        [weakDC postNotificationName:@"com.aspauldingcode.apple_sharpener.radius_response"
                                object:nil
                              userInfo:@{@"radius": @(customRadius)}
                    deliverImmediately:YES];
    }];
}