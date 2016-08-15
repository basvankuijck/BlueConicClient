/*
 * $LastChangedBy$
 * $LastChangedDate$
 * $LastChangedRevision$
 * $HeadURL$
 *
 * Copyright 2014 BlueConic Inc./BlueConic B.V. All rights reserved.
 */

#import "BlueConicPlugin.h"

@implementation Plugin

- (instancetype) initWithClient: (BlueConicClient *)client context:(InteractionContext *)context {
    return self;
}

- (void) onLoad {
}

- (void) onDestroy {
    
}
@end