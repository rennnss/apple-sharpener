#import <AppKit/AppKit.h>
#import "Windows/window.h"
#import "Dock/dock.h"

/**
 * Main sharpener coordinator
 * This file serves as the entry point and coordinator for the apple-sharpener tweak.
 * It imports and coordinates between the Windows and Dock modules.
 */

// The actual implementations are now in:
// - Windows/window.m for window corner radius modification
// - Dock/dock.m for dock corner radius modification

// This file serves as the main entry point and ensures both modules are loaded
// when the library is injected into processes.
