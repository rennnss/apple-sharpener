#ifndef WINDOW_H
#define WINDOW_H

#import <Foundation/Foundation.h>

/**
 * Window sharpening API for apple-sharpener
 * Provides functions to control window corner radius modification
 */

/**
 * Toggle square corners for application windows
 * @param enable Whether to enable custom corner radius
 * @param radius The corner radius to apply (0 for square corners)
 */
void toggleSquareCorners(BOOL enable, NSInteger radius);

#endif /* WINDOW_H */