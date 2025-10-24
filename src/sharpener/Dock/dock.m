#import "dock.h"
#import "ZKSwizzle.h"
#import <notify.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

// Debug logging disabled by default; enable with APPLE_SHARPENER_DEBUG
#ifdef APPLE_SHARPENER_DEBUG
static void ASDebugLog(const char *fmt, ...) {
    va_list args; va_start(args, fmt);
    vfprintf(stderr, fmt, args);
    fprintf(stderr, "\n");
    va_end(args);
}
#else
#define ASDebugLog(...) do {} while (0)
#endif

/**
 * Dock sharpening implementation for apple-sharpener
 * Hooks into CALayer layoutSublayers to target DockCore.ModernFloorLayer
 */

#pragma mark - Constants

NSString * const kDockBundleIdentifier = @"com.apple.dock";
const CGFloat kDockDefaultRadius = 16.0;
const CGFloat kDockSquareRadius = 0.0;

#pragma mark - Global State

static BOOL enableDockSharpener = YES;
static NSInteger dockCustomRadius = 0;

#pragma mark - Helper Functions

BOOL isDockProcess(void) {
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    return [bundleId isEqualToString:kDockBundleIdentifier];
}

static void DoDock(CALayer *layer) {
    if (!layer || !enableDockSharpener) return;
    
    ASDebugLog("DoDock on %s, radius=%ld", [layer.className UTF8String], (long)dockCustomRadius);
    
    // Apply corner radius to the dock layer
    CGFloat targetRadius = enableDockSharpener ? dockCustomRadius : kDockDefaultRadius;
    layer.cornerRadius = targetRadius;
    layer.masksToBounds = YES;
    
    // Also apply to sublayers that might need it
    for (CALayer *sublayer in layer.sublayers) {
        NSString *subClass = sublayer.className;
        if ([subClass containsString:@"Dock"] ||
            [subClass containsString:@"Floor"] ||
            [subClass containsString:@"Background"] ||
            [subClass containsString:@"Backdrop"] ||
            [subClass containsString:@"Portal"] ||
            [subClass containsString:@"SDF"]) {
            ASDebugLog("Apply radius to sublayer: %s", [subClass UTF8String]);
            sublayer.cornerRadius = targetRadius;
            sublayer.masksToBounds = YES;
            [sublayer setNeedsLayout];
            [sublayer setNeedsDisplay];
        }
    }
}

#pragma mark - CALayer Hook

// Store original method implementation
static IMP __LayoutSublayers = NULL;

// Optional WALayerKitWindow hook (root layer provider)
static IMP __WALayerKitWindow_layer = NULL;
static CALayer* _PatchedWALayerKitWindow_layer(id self, SEL _cmd) {
    CALayer *root = ((CALayer*(*)(id,SEL))__WALayerKitWindow_layer)(self, _cmd);
    ASDebugLog("WALayerKitWindow layer root: %p", root);
    return root;
}

// Hooked layoutSublayers method
static void _PatchedLayoutSublayers(id self, SEL _cmd) {
    // Call original implementation first
    if (__LayoutSublayers) {
        ((void(*)(id, SEL))__LayoutSublayers)(self, _cmd);
    }
    
    // Only process if we're in the dock and sharpening is enabled
    if (!isDockProcess() || !enableDockSharpener) return;
    
    // Debug: Log all layer classes we encounter
    NSString *className = [self className];
    ASDebugLog("CALayer layout: %s", [className UTF8String]);
    
    // Check if this is the DockCore.ModernFloorLayer we're looking for
    if ([className isEqualToString:@"DockCore.ModernFloorLayer"]) {
        ASDebugLog("Found DockCore.ModernFloorLayer, applying radius=%ld", (long)dockCustomRadius);
        DoDock((CALayer *)self);
    }
    // Also try broader detection for dock-related layers
    else if ([className containsString:@"Dock"] || 
             [className containsString:@"Floor"] ||
             [className containsString:@"Background"] ||
             [className containsString:@"Modern"] ||
             [className containsString:@"Backdrop"] ||
             [className containsString:@"Portal"] ||
             [className containsString:@"SDF"]) {
        ASDebugLog("Found potential dock layer: %s, applying radius=%ld", [className UTF8String], (long)dockCustomRadius);
        DoDock((CALayer *)self);
    }
}

#pragma mark - Public API

void toggleDockCorners(BOOL enable, NSInteger radius) {
    if (!isDockProcess()) return;
    
    enableDockSharpener = enable;
    dockCustomRadius = MAX(0, radius);
    
    // Force layout update on all layers to trigger our hook
    NSArray *windows = [[NSApplication sharedApplication] windows];
    for (NSWindow *window in windows) {
        if (window.contentView && window.contentView.layer) {
            [window.contentView.layer setNeedsLayout];
        }
    }
}

#pragma mark - Dock View Swizzling

// Remove old placeholder swizzling - we're using direct method hooking instead

#pragma mark - Notification Setup

static void setupDockNotifications(void) __attribute__((constructor));
static void setupDockNotifications(void) {
    // Only setup if we're in the Dock process
    if (!isDockProcess()) {
        NSLog(@"[AppleSharpener] Not in Dock process (bundle ID: %@), skipping setup", [[NSBundle mainBundle] bundleIdentifier]);
        return;
    }
    
    NSLog(@"[AppleSharpener] Setting up dock notifications in process: %@", [[NSBundle mainBundle] bundleIdentifier]);
    
    // Hook CALayer's layoutSublayers method
    Class layerClass = [CALayer class];
    Method originalMethod = class_getInstanceMethod(layerClass, @selector(layoutSublayers));
    if (originalMethod) {
        __LayoutSublayers = method_getImplementation(originalMethod);
        method_setImplementation(originalMethod, (IMP)_PatchedLayoutSublayers);
        ASDebugLog("Hooked CALayer layoutSublayers");
    } else {
        ASDebugLog("Failed to find CALayer layoutSublayers");
    }
    
    // Optionally hook WALayerKitWindow - root layer provider for Dock windows
    Class walClass = NSClassFromString(@"WALayerKitWindow");
    if (walClass) {
        Method walLayerMethod = class_getInstanceMethod(walClass, @selector(layer));
        if (walLayerMethod) {
            __WALayerKitWindow_layer = method_getImplementation(walLayerMethod);
            method_setImplementation(walLayerMethod, (IMP)_PatchedWALayerKitWindow_layer);
            ASDebugLog("Hooked WALayerKitWindow layer method");
        } else {
            ASDebugLog("WALayerKitWindow layer method not found");
        }
    } else {
        ASDebugLog("WALayerKitWindow class not present");
    }
    
    dispatch_queue_t queue = dispatch_get_main_queue();
    
    static const char *kNotifyEnabled = "com.aspauldingcode.apple_sharpener.enabled";
    static const char *kNotifyDockRadius = "com.aspauldingcode.apple_sharpener.dock.set_radius";
    
    // Hydrate current state from universal enabled notification
    {
        int tokenEnabled = 0;
        uint64_t enabledState = 1;
        if (notify_register_check(kNotifyEnabled, &tokenEnabled) == NOTIFY_STATUS_OK) {
            notify_get_state(tokenEnabled, &enabledState);
        }
        enableDockSharpener = (enabledState != 0);
        ASDebugLog("Hydrated enabled=%d", enableDockSharpener);
    }
    {
        int tokenRadius = 0;
        uint64_t radiusState = 0;
        if (notify_register_check(kNotifyDockRadius, &tokenRadius) == NOTIFY_STATUS_OK) {
            notify_get_state(tokenRadius, &radiusState);
        }
        dockCustomRadius = (NSInteger)radiusState;
        ASDebugLog("Hydrated dock radius=%ld", (long)dockCustomRadius);
    }
    
    toggleDockCorners(enableDockSharpener, dockCustomRadius);
    
    // Register notification handlers for universal enable/disable
    int tokenEnabled = 0;
    notify_register_dispatch(kNotifyEnabled, &tokenEnabled, queue, ^(int t){
        uint64_t state = 0;
        if (notify_get_state(t, &state) == NOTIFY_STATUS_OK) {
            ASDebugLog("Notify enabled state=%llu", state);
            toggleDockCorners((state != 0), dockCustomRadius);
        }
    });
    
    int tokenSetRadius = 0;
    notify_register_dispatch(kNotifyDockRadius, &tokenSetRadius, queue, ^(int t){
        uint64_t state = 0;
        if (notify_get_state(t, &state) == NOTIFY_STATUS_OK) {
            ASDebugLog("Notify dock radius=%llu", state);
            toggleDockCorners(enableDockSharpener, (NSInteger)state);
        }
    });
}