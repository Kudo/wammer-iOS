//
//  WARemoteInterface+Environment.m
//  wammer
//
//  Created by Evadne Wu on 12/7/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import "WARemoteInterface+Environment.h"
#import "WARemoteInterface.h"
#import "Foundation+IRAdditions.h"
#import "WAReachabilityDetector.h"
#import "WADefines.h"

@implementation WARemoteInterface (Environment)

- (BOOL) areExpensiveOperationsAllowed {

  if ([[NSUserDefaults standardUserDefaults] boolForKey:kWAAlwaysAllowExpensiveRemoteOperations])
    return YES;

  if ([[NSUserDefaults standardUserDefaults] boolForKey:kWAAlwaysDenyExpensiveRemoteOperations])
    return NO;
	
	return ([self hasReachableStation] || [self hasReachableCloud]) && [self hasWiFiConnection];
	
}

+ (NSSet *) keyPathsForValuesAffectingHasReachableStation {

	return [NSSet setWithObject:@"networkState"];

}

- (BOOL) hasReachableStation {

	return (self.networkState & WAStationReachable);

}

+ (NSSet *) keyPathsForValuesAffectingHasReachableCloud {

	return [NSSet setWithObject:@"networkState"];

}

- (BOOL) hasReachableCloud {

	return (self.networkState & WACloudReachable);

}

- (WAReachabilityDetector *) sharedDetectorForLocalWiFi {

	return [WAReachabilityDetector sharedDetectorForLocalWiFi];

}

+ (NSSet *) keyPathsForValuesAffectingHasWiFiConnection {

	return [NSSet setWithObject:@"sharedDetectorForLocalWiFi.networkReachableDirectly"];

}

- (BOOL) hasWiFiConnection {

	return [[WAReachabilityDetector sharedDetectorForLocalWiFi] networkReachableDirectly];
	
}

@end
