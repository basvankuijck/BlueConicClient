/*
 * $LastChangedBy$
 * $LastChangedDate$
 * $LastChangedRevision$
 * $HeadURL$
 *
 * Copyright 2014 BlueConic Inc./BlueConic B.V. All rights reserved.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class BlueConicClient;
@class InteractionContext;
@interface Plugin : NSObject

/**
 * Creates a new Plugin instance with Client and an InteractionContext
 * Function should be overwritten by the Client-plugins
 *
 * @param client The instance of the current BlueConicClient
 * @param context The instance of InteractionContext, which contains variables such as id, type, position and parameter
 */
- (instancetype) initWithClient: (BlueConicClient *)client context:(InteractionContext *)context;

/**
 * Function onLoad will be triggered when Plugin is registered and active on the server.
 * Function should be overwritten by the Client-plugins
 */
- (void) onLoad;

/**
 * Function onDestroy will be triggered when the ViewController gets dismissed.
 * Function should be overwritten by the Client-plugins.
 */
- (void) onDestroy;

@end