#ifndef DOCK_H
#define DOCK_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>

/**
 * Dock sharpening API for apple-sharpener
 * Provides functions to control dock corner radius modification
 */

/**
 * Check if the current process is the Dock
 * @return YES if running in Dock process, NO otherwise
 */
BOOL isDockProcess(void);

/**
 * Toggle square corners for the dock
 * @param enable Whether to enable custom corner radius
 * @param radius The corner radius to apply (0 for square corners)
 */
void toggleDockCorners(BOOL enable, NSInteger radius);

#endif /* DOCK_H */