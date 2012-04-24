//
//  WADefines.h
//  wammer
//
//  Created by Evadne Wu on 10/2/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

extern NSString * const kWAAdvancedFeaturesEnabled;
extern BOOL WAAdvancedFeaturesEnabled (void);

extern BOOL WAApplicationHasDebuggerAttached (void);

extern NSString * const kWARemoteEndpointURL;
extern NSString * const kWARemoteEndpointVersion;
extern NSString * const kWARemoteEndpointCurrentVersion;
extern NSString * const kWALastAuthenticatedUserTokenKeychainItem;
extern NSString * const kWALastAuthenticatedUserPrimaryGroupIdentifier;
extern NSString * const kWALastAuthenticatedUserIdentifier;
extern NSString * const kWAUserRegistrationUsesWebVersion;
extern NSString * const kWAUserRegistrationEndpointURL;
extern NSString * const kWAUserRequiresReauthentication;
extern NSString * const kWAUserPasswordResetEndpointURL;
extern NSString * const kWAAlwaysAllowExpensiveRemoteOperations;
extern NSString * const kWAAlwaysDenyExpensiveRemoteOperations;
extern NSString * const kWADebugAutologinUserIdentifier;
extern NSString * const kWADebugAutologinUserPassword;

extern NSString * const kWADebugLastScanSyncBezelsVisible;
extern NSString * const kWADebugPersistentStoreName;

extern NSString * const kWACompositionSessionRequestedNotification;
extern NSString * const kWAApplicationDidReceiveRemoteURLNotification;
extern NSString * const kWARemoteInterfaceReachableHostsDidChangeNotification;
extern NSString * const kWARemoteInterfaceDidObserveAuthenticationFailureNotification;
extern NSString * const kWASettingsDidRequestActionNotification;

extern NSString * const kWATestflightTeamToken;
extern NSString * const kWACrashlyticsAPIKey;
extern NSString * const kWAGoogleAnalyticsAccountID;
extern NSInteger  const kWAGoogleAnalyticsDispatchInterval;

extern NSString * const kWARemoteEndpointApplicationKeyPhone;
extern NSString * const kWARemoteEndpointApplicationKeyPad;
extern NSString * const kWARemoteEndpointApplicationKeyMac;

extern NSString * const kWACallbackActionDidFinishUserRegistration;
extern NSString * const kWACallbackActionSetAdvancedFeaturesEnabled;
extern NSString * const kWACallbackActionSetRemoteEndpointURL;
extern NSString * const kWACallbackActionSetUserRegistrationEndpointURL;
extern NSString * const kWACallbackActionSetUserPasswordResetEndpointURL;

extern void WARegisterUserDefaults (void);
extern NSDictionary * WAPresetDefaults (void);

extern NSString * const kWACurrentGeneratedDeviceIdentifier;
BOOL WADeviceIdentifierReset (void);
NSString * WADeviceIdentifier (void);

extern NSString * const kWAAppEventNotification;	//	Notification Center key
extern NSString * const kWAAppEventTitle;	//	The eventTitle
extern void WAPostAppEvent (NSString *eventTitle, NSDictionary *userInfo);

extern NSString * const kWADucklingsEnabled;
extern BOOL WADucklingsEnabled (void);

#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
	#import "WADefines+iOS.h"
#else
	#import "WADefines+Mac.h"
#endif
