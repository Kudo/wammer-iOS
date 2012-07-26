//
//  WAAppDelegate_iOS.m
//  wammer
//
//  Created by Evadne Wu on 12/17/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

#import "WAAppDelegate_iOS.h"

#import "WADefines.h"
#import "WAAppDelegate.h"

#import "WARemoteInterface.h"

#import "WADataStore.h"
#import "WADataStore+WARemoteInterfaceAdditions.h"

#import "WANavigationController.h"
#import "WAApplicationRootViewControllerDelegate.h"
#import "WANavigationBar.h"
#import "WAOverviewController.h"
#import "WATimelineViewControllerPhone.h"
#import "WAUserInfoViewController.h"
#import "WAOverlayBezel.h"

#import "Foundation+IRAdditions.h"
#import "UIKit+IRAdditions.h"

#import "IRSlidingSplitViewController.h"
#import "WASlidingSplitViewController.h"

#import "IASKSettingsReader.h"
#import	"DCIntrospect.h"

#import "WAFacebookInterface.h"
#import "WAFacebookInterfaceSubclass.h"

#import "WAWelcomeViewController.h"
#import "WATutorialViewController.h"


@interface WAAppDelegate_iOS () <WAApplicationRootViewControllerDelegate>

- (void) handleObservedAuthenticationFailure:(NSNotification *)aNotification;
- (void) handleObservedRemoteURLNotification:(NSNotification *)aNotification;
- (void) handleIASKSettingsChanged:(NSNotification *)aNotification;
- (void) handleIASKSettingsDidRequestAction:(NSNotification *)aNotification;

@property (nonatomic, readwrite, assign) BOOL alreadyRequestingAuthentication;

- (void) clearViewHierarchy;
- (void) recreateViewHierarchy;
- (void) handleDebugModeToggled;

- (void) handleAuthRequest:(NSString *)reason withOptions:(NSDictionary *)options completion:(void(^)(BOOL didFinish, NSError *error))block;
- (BOOL) isRunningAuthRequest;

@end

@implementation WAAppDelegate_iOS
@synthesize window = _window;
@synthesize alreadyRequestingAuthentication;

- (void) bootstrap {
	
	[super bootstrap];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleObservedAuthenticationFailure:) name:kWARemoteInterfaceDidObserveAuthenticationFailureNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleObservedRemoteURLNotification:) name:kWAApplicationDidReceiveRemoteURLNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleIASKSettingsChanged:) name:kIASKAppSettingChanged object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleIASKSettingsDidRequestAction:) name:kWASettingsDidRequestActionNotification object:nil];
	
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
		[WARemoteInterface sharedInterface].apiKey = kWARemoteEndpointApplicationKeyPad;
	else {
		[WARemoteInterface sharedInterface].apiKey = kWARemoteEndpointApplicationKeyPhone;
	}

	if (!WAApplicationHasDebuggerAttached()) {
		
		WF_TESTFLIGHT(^ {
			
			[TestFlight setOptions:[NSDictionary dictionaryWithObjectsAndKeys:
				(id)kCFBooleanFalse, @"sendLogOnlyOnCrash",
			nil]];
			
			[TestFlight takeOff:kWATestflightTeamToken];
			
			id observer = [[NSNotificationCenter defaultCenter] addObserverForName:kWAAppEventNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
				
				NSString *eventTitle = [[note userInfo] objectForKey:kWAAppEventTitle];
				[TestFlight passCheckpoint:eventTitle];
				
			}];
			
			objc_setAssociatedObject([TestFlight class], &kWAAppEventNotification, observer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			
		});
		
		WF_CRASHLYTICS(^ {
			
			[Crashlytics startWithAPIKey:kWACrashlyticsAPIKey];
			[Crashlytics sharedInstance].debugMode = YES;
			
		});
	
		WF_GOOGLEANALYTICS(^ {
		
			[[GANTracker sharedTracker] startTrackerWithAccountID:kWAGoogleAnalyticsAccountID dispatchPeriod:kWAGoogleAnalyticsDispatchInterval delegate:nil];
			[GANTracker sharedTracker].debug = YES;
			
			id observer = [[NSNotificationCenter defaultCenter] addObserverForName:kWAAppEventNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			
				NSDictionary *userInfo = [note userInfo];
				id category = [userInfo objectForKey:@"category"];
				id action = [userInfo objectForKey:@"action"];
				id label = [userInfo objectForKey:@"label"];
				id value = [userInfo objectForKey:@"value"];
				
				[[GANTracker sharedTracker] trackEvent:category action:action label:label value:value withError:nil];
				
			}];
			
			objc_setAssociatedObject([GANTracker class], &kWAAppEventNotification, observer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		
		});
		
	}
	
	AVAudioSession * const audioSession = [AVAudioSession sharedInstance];
	[audioSession setCategory:AVAudioSessionCategoryAmbient error:nil];
	[audioSession setActive:YES error:nil];
	
	WADefaultBarButtonInitialize();
	
}

- (BOOL) application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

	[self bootstrap];
	
	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	self.window.backgroundColor = [UIColor colorWithRed:0.87 green:0.87 blue:0.84 alpha:1.0];
	
	[self.window makeKeyAndVisible];
	
	if ([[NSUserDefaults standardUserDefaults] stringForKey:kWADebugPersistentStoreName]) {
	
		NSString *identifier = [[NSUserDefaults standardUserDefaults] stringForKey:kWADebugPersistentStoreName];
		[self bootstrapPersistentStoreWithUserIdentifier:identifier];
		
		[self recreateViewHierarchy];
	
	} else if (![self hasAuthenticationData]) {
	
		[self applicationRootViewControllerDidRequestReauthentication:nil];
					
	} else {
	
		NSString *lastAuthenticatedUserIdentifier = [[NSUserDefaults standardUserDefaults] stringForKey:kWALastAuthenticatedUserIdentifier];
		
		if (lastAuthenticatedUserIdentifier)
			[self bootstrapPersistentStoreWithUserIdentifier:lastAuthenticatedUserIdentifier];
		
		[self recreateViewHierarchy];
		
	}

	WAPostAppEvent(@"AppVisit", [NSDictionary dictionaryWithObjectsAndKeys:@"app",@"category",@"visit", @"action", nil]);
	
	[[WARemoteInterface sharedInterface] performAutomaticRemoteUpdatesNow];
	
	return YES;
	
}

- (void) clearViewHierarchy {

	UIViewController *rootVC = self.window.rootViewController;
	
	__block void (^zapModal)(UIViewController *) = [^ (UIViewController *aVC) {
	
		if (aVC.presentedViewController)
			zapModal(aVC.presentedViewController);
		
		[aVC dismissViewControllerAnimated:NO completion:nil];
	
	} copy];
	
	zapModal(rootVC);
	
	
	IRViewController *emptyVC = [[IRViewController alloc] init];
	__weak IRViewController *wEmptyVC = emptyVC;
	
	emptyVC.onShouldAutorotateToInterfaceOrientation = ^ (UIInterfaceOrientation toOrientation) {
		
		return YES;
		
	};
	
	emptyVC.onLoadView = ^ {
	
		wEmptyVC.view = [[UIView alloc] initWithFrame:(CGRect){ 0, 0, 1024, 1024 }];
		wEmptyVC.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"WAPatternBlackPaper"]];
		
	};
	
	self.window.rootViewController = emptyVC;
	
	[rootVC didReceiveMemoryWarning];
	
}

- (void) recreateViewHierarchy {

	[[IRRemoteResourcesManager sharedManager].queue cancelAllOperations];
	
	switch (UI_USER_INTERFACE_IDIOM()) {
	
		case UIUserInterfaceIdiomPad: {
		
			IRSlidingSplitViewController *ssVC = [WASlidingSplitViewController new];
		
			WAOverviewController *presentedViewController = [[WAOverviewController alloc] init];
			WANavigationController *rootNavC = [[WANavigationController alloc] initWithRootViewController:presentedViewController];
			
			[presentedViewController setDelegate:self];
			
			ssVC.masterViewController = rootNavC;
			self.window.rootViewController = ssVC;
		
			break;
		
		}
		
		case UIUserInterfaceIdiomPhone: {
			
			WATimelineViewControllerPhone *timelineVC = [[WATimelineViewControllerPhone alloc] init];
			WANavigationController *timelineNavC = [[WANavigationController alloc] initWithRootViewController:timelineVC];
			
			[timelineVC setDelegate:self];
						
			self.window.rootViewController = timelineNavC;
		
			break;
		
		}
	
	}
	
	UIViewController *vc = self.window.rootViewController;
	
	[vc willRotateToInterfaceOrientation:vc.interfaceOrientation duration:0];
	[vc willAnimateRotationToInterfaceOrientation:vc.interfaceOrientation duration:0];
	[vc didRotateFromInterfaceOrientation:vc.interfaceOrientation];

			
}

- (void) applicationRootViewControllerDidRequestReauthentication:(id<WAApplicationRootViewController>)controller {

	dispatch_async(dispatch_get_main_queue(), ^ {

		[self presentAuthenticationRequestWithReason:nil allowingCancellation:NO removingPriorData:YES clearingNavigationHierarchy:YES onAuthSuccess:^(NSString *userIdentifier, NSString *userToken, NSString *primaryGroupIdentifier) {
		
			[self updateCurrentCredentialsWithUserIdentifier:userIdentifier token:userToken primaryGroup:primaryGroupIdentifier];
			[self bootstrapPersistentStoreWithUserIdentifier:userIdentifier];
			
		} runningOnboardingProcess:YES];
		
	});

}

- (void) handleObservedAuthenticationFailure:(NSNotification *)aNotification {

	NSError *error = [[aNotification userInfo] objectForKey:@"error"];

  dispatch_async(dispatch_get_main_queue(), ^{

		[self presentAuthenticationRequestWithReason:[error localizedDescription] allowingCancellation:YES removingPriorData:NO clearingNavigationHierarchy:NO onAuthSuccess:^(NSString *userIdentifier, NSString *userToken, NSString *primaryGroupIdentifier) {
			
			[self updateCurrentCredentialsWithUserIdentifier:userIdentifier token:userToken primaryGroup:primaryGroupIdentifier];
			[self bootstrapPersistentStoreWithUserIdentifier:userIdentifier];
			
		} runningOnboardingProcess:NO];

  });
  
}

- (void) handleObservedRemoteURLNotification:(NSNotification *)aNotification {
	
	NSString *command = nil;
	NSDictionary *params = nil;
	
	if (!WAIsXCallbackURL([[aNotification userInfo] objectForKey:@"url"], &command, &params))
		return;
	
	if ([command isEqualToString:kWACallbackActionSetAdvancedFeaturesEnabled]) {
		
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		if ([defaults boolForKey:kWAAdvancedFeaturesEnabled])
			return;
		
		[defaults setBool:YES forKey:kWAAdvancedFeaturesEnabled];
		
		if (![defaults synchronize])
			return;
		
		[self handleDebugModeToggled];
		
		return;
		
	}
	
	if ([command isEqualToString:kWACallbackActionSetRemoteEndpointURL]) {
		
		__block __typeof__(self) nrSelf = self;
		void (^zapAndRequestReauthentication)() = ^ {

			[[NSUserDefaults standardUserDefaults] setObject:[params objectForKey:@"url"] forKey:kWARemoteEndpointURL];
			[[NSUserDefaults standardUserDefaults] setObject:[params objectForKey:@"RegistrationUrl"] forKey:kWAUserRegistrationEndpointURL];
			[[NSUserDefaults standardUserDefaults] setObject:[params objectForKey:@"PasswordResetUrl"] forKey:kWAUserPasswordResetEndpointURL];
			[[NSUserDefaults standardUserDefaults] setObject:[params objectForKey:@"FacebookAuthUrl"] forKey:kWAUserFacebookAuthenticationEndpointURL];
			[[NSUserDefaults standardUserDefaults] setObject:[params objectForKey:@"FacebookAppID"] forKey:kWAFacebookAppID];
			[[NSUserDefaults standardUserDefaults] synchronize];

			if (nrSelf.alreadyRequestingAuthentication) {
				nrSelf.alreadyRequestingAuthentication = NO;
				[nrSelf clearViewHierarchy];
			}
			
			[nrSelf applicationRootViewControllerDidRequestReauthentication:nil];
			
		};
		
		NSString *alertTitle = @"Switch endpoint to";
		NSString *alertText = [params objectForKey:@"url"];
		
		IRAction *cancelAction = [IRAction actionWithTitle:@"Cancel" block:nil];
		IRAction *confirmAction = [IRAction actionWithTitle:@"Yes, Switch" block:zapAndRequestReauthentication];
		
		[[IRAlertView alertViewWithTitle:alertTitle message:alertText cancelAction:cancelAction otherActions:[NSArray arrayWithObjects:
			confirmAction,
		nil]] show];
	}
	
}

- (void) handleIASKSettingsChanged:(NSNotification *)aNotification {

	if ([[[aNotification userInfo] allKeys] containsObject:kWAAdvancedFeaturesEnabled])
		[self handleDebugModeToggled];

}

- (void) handleIASKSettingsDidRequestAction:(NSNotification *)aNotification {

	NSString *action = [[aNotification userInfo] objectForKey:@"key"];
	
	if ([action isEqualToString:@"WASettingsActionResetDefaults"]) {
	
		__weak WAAppDelegate_iOS *wSelf = self;
		
		NSString *alertTitle = NSLocalizedString(@"RESET_SETTINGS_CONFIRMATION_TITLE", nil);
		NSString *alertText = NSLocalizedString(@"RESET_SETTINGS_CONFIRMATION_DESCRIPTION", nil);
	
		IRAction *cancelAction = [IRAction actionWithTitle:NSLocalizedString(@"ACTION_CANCEL", nil) block:nil];
		IRAction *resetAction = [IRAction actionWithTitle:NSLocalizedString(@"ACTION_RESET", nil) block: ^ {
		
			NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		
			for (NSString *key in [[defaults dictionaryRepresentation] allKeys])
				[defaults removeObjectForKey:key];
				
			[defaults synchronize];
			
			[wSelf clearViewHierarchy];
			[wSelf recreateViewHierarchy];
		
		}];
		
		IRAlertView *alertView = [IRAlertView alertViewWithTitle:alertTitle message:alertText cancelAction:cancelAction otherActions:[NSArray arrayWithObjects:
			
			resetAction,
			
		nil]];
		
		[alertView show];
	
	}

}

- (void) handleDebugModeToggled {

	__weak WAAppDelegate_iOS *wSelf = self;
	
	BOOL isNowEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:kWAAdvancedFeaturesEnabled];
	
	NSString *alertTitle;
	NSString *alertText;
	IRAlertView *alertView = nil;
	
	void (^zapAndRequestReauthentication)() = ^ {
	
		if (self.alreadyRequestingAuthentication) {
			wSelf.alreadyRequestingAuthentication = NO;
			[wSelf clearViewHierarchy];
		}
		
		[wSelf applicationRootViewControllerDidRequestReauthentication:nil];
		
	};
	
	if (isNowEnabled) {
		alertTitle = NSLocalizedString(@"ADVANCED_FEATURES_ENABLED_TITLE", nil);
		alertText = NSLocalizedString(@"ADVANCED_FEATURES_ENABLED_DESCRIPTION", nil);
	} else {
		alertTitle = NSLocalizedString(@"ADVANCED_FEATURES_DISABLED_TITLE", nil);
		alertText = NSLocalizedString(@"ADVANCED_FEATURES_DISABLED_DESCRIPTION", nil);
	}

	IRAction *okayAction = [IRAction actionWithTitle:NSLocalizedString(@"ACTION_OKAY", nil) block:nil];
	IRAction *okayAndZapAction = [IRAction actionWithTitle:NSLocalizedString(@"ACTION_OKAY", nil) block:zapAndRequestReauthentication];
	IRAction *laterAction = [IRAction actionWithTitle:NSLocalizedString(@"ACTION_LATER", nil) block:nil];
	IRAction *signOutAction = [IRAction actionWithTitle:NSLocalizedString(@"ACTION_SIGN_OUT", nil) block:zapAndRequestReauthentication];
	
	if (self.alreadyRequestingAuthentication) {
		
		//	User is not authenticated, and also we’re already at the auth view
		//	Can zap
		
		alertView = [IRAlertView alertViewWithTitle:alertTitle message:alertText cancelAction:nil otherActions:[NSArray arrayWithObjects:
			okayAndZapAction,
		nil]];
	
	} else if (![self hasAuthenticationData]) {
	
		//	In the middle of an active auth session, not safe to zap
		
		alertView = [IRAlertView alertViewWithTitle:alertTitle message:alertText cancelAction:okayAction otherActions:nil];
	
	} else {
	
		//	Can zap
	
		alertView = [IRAlertView alertViewWithTitle:alertTitle message:alertText cancelAction:laterAction otherActions:[NSArray arrayWithObjects:
			signOutAction,
		nil]];
	
	}
	
	[alertView show];

}

- (BOOL) presentAuthenticationRequestWithReason:(NSString *)aReason allowingCancellation:(BOOL)allowsCancellation removingPriorData:(BOOL)eraseAuthInfo clearingNavigationHierarchy:(BOOL)zapEverything onAuthSuccess:(void (^)(NSString *userIdentifier, NSString *userToken, NSString *primaryGroupIdentifier))successBlock runningOnboardingProcess:(BOOL)shouldRunOnboardingChecksIfUserUnchanged {

	if ([self isRunningAuthRequest])
		return NO;
	
  if (allowsCancellation)
    NSParameterAssert(!eraseAuthInfo);

	if (eraseAuthInfo)
    [self removeAuthenticationData];
	
	if (zapEverything)
		[self clearViewHierarchy];
	
	[self handleAuthRequest:aReason withOptions:nil completion:^(BOOL didFinish, NSError *error) {
	
		WARemoteInterface * const ri = [WARemoteInterface sharedInterface];
	
		if (didFinish)
			if (successBlock)
				successBlock(ri.userIdentifier, ri.userToken, ri.primaryGroupIdentifier);
		
	}];
	
	return YES;

}

- (void) handleAuthRequest:(NSString *)reason withOptions:(NSDictionary *)options completion:(void(^)(BOOL didFinish, NSError *error))block {

	WARemoteInterface * const ri = [WARemoteInterface sharedInterface];
	__weak WAAppDelegate_iOS *wAppDelegate = self;
	
	[ri.engine.queue cancelAllOperations];
	
	NSParameterAssert(!self.alreadyRequestingAuthentication);
	self.alreadyRequestingAuthentication = YES;

	NSString *lastUserID = [WARemoteInterface sharedInterface].userIdentifier;
	BOOL (^userIDChanged)() = ^ {
		
		NSString *currentID = [WARemoteInterface sharedInterface].userIdentifier;
		return (BOOL)![currentID isEqualToString:lastUserID];
		
	};
	
	void (^handleAuthSuccess)(void) = ^ {
	
		if (block)
			block(YES, nil);
			
		wAppDelegate.alreadyRequestingAuthentication = NO;
		
	};
	
	__block WAWelcomeViewController *welcomeVC = [WAWelcomeViewController controllerWithCompletion:^(NSString *token, NSDictionary *userRep, NSArray *groupReps, NSError *error) {
	
		if (error) {
		
			NSString *message = [error localizedDescription];
			IRAction *okAction = [IRAction actionWithTitle:NSLocalizedString(@"ACTION_OKAY", @"Alert Dismissal Action") block:nil];
		
			IRAlertView *alertView = [IRAlertView alertViewWithTitle:nil message:message cancelAction:okAction otherActions:nil];
			[alertView show];
		
			welcomeVC = nil;
			return;
			
		}
		
		NSString *userStatus = [userRep valueForKeyPath:@"state"];
		NSString *userID = [userRep valueForKeyPath:@"user_id"];
		
		BOOL userNewlyCreated = [userStatus isEqual:@"created"];
		BOOL userIsFromFacebook = ![[userRep valueForKeyPath:@"sns.@count"] isEqual:[NSNumber numberWithUnsignedInteger:0]];
		
		NSString *primaryGroupID = [[[groupReps filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
		
			return [[evaluatedObject valueForKeyPath:@"creator_id"] isEqual:userID];
			
		}]] lastObject] valueForKeyPath:@"group_id"];
		
		WARemoteInterface * const ri = [WARemoteInterface sharedInterface];
		
		ri.userIdentifier = userID;
		ri.userToken = token;
		ri.primaryGroupIdentifier = primaryGroupID;
		
		if (userIDChanged()) {
		
			if (userNewlyCreated) {
			
				WATutorialInstantiationOption options = userIsFromFacebook ? WATutorialInstantiationOptionShowFacebookIntegrationToggle : WATutorialInstantiationOptionDefault;
				
				WATutorialViewController *tutorialVC = [WATutorialViewController controllerWithOption:options completion:^(BOOL didFinish, NSError *error) {

					handleAuthSuccess();
					[wAppDelegate recreateViewHierarchy];
					
				}];
				
				switch ([UIDevice currentDevice].userInterfaceIdiom) {
				
					case UIUserInterfaceIdiomPad: {
						tutorialVC.modalPresentationStyle = UIModalPresentationFormSheet;
						break;
					}
					
					case UIUserInterfaceIdiomPhone:
					default: {
						tutorialVC.modalPresentationStyle = UIModalPresentationCurrentContext;
					}

				}

			
				[wAppDelegate clearViewHierarchy];
				[wAppDelegate.window.rootViewController presentViewController:tutorialVC animated:NO completion:nil];

			} else {
			
				handleAuthSuccess();
				[wAppDelegate recreateViewHierarchy];
			
			}
			
		} else {
			
			handleAuthSuccess();
			
		}
		
		return;
		
		[welcomeVC dismissViewControllerAnimated:NO completion:^{
			
			UIViewController *rootVC = wAppDelegate.window.rootViewController;
			
			[rootVC presentViewController:welcomeVC.navigationController animated:NO completion:^{
				
				[welcomeVC dismissViewControllerAnimated:YES completion:^{
					
					//	?
					
					welcomeVC = nil;
					
				}];
				
			}];
			
		}];
				
	}];
	
	UINavigationController *authRequestWrapperVC = [[UINavigationController alloc] initWithRootViewController:welcomeVC];
	
	switch ([UIDevice currentDevice].userInterfaceIdiom) {
	
		case UIUserInterfaceIdiomPad: {
			authRequestWrapperVC.modalPresentationStyle = UIModalPresentationFormSheet;
			break;
		}
		
		case UIUserInterfaceIdiomPhone:
		default: {
			authRequestWrapperVC.modalPresentationStyle = UIModalPresentationCurrentContext;
		}

	}
	
	authRequestWrapperVC.navigationBar.tintColor =  [UIColor colorWithRed:98.0/255.0 green:176.0/255.0 blue:195.0/255.0 alpha:0.0];
	
	[self.window.rootViewController presentViewController:authRequestWrapperVC animated:NO completion:nil];
	
}

- (BOOL) isRunningAuthRequest {

	return self.alreadyRequestingAuthentication;

}

static unsigned int networkActivityStackingCount = 0;

- (void) beginNetworkActivity {

	if (![NSThread isMainThread]) {
		dispatch_async(dispatch_get_main_queue(), ^ {
			[self beginNetworkActivity];
		});
		return;
	}
	
	networkActivityStackingCount++;
	
	if (networkActivityStackingCount > 0)
		[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

}

- (void) endNetworkActivity {

	if (![NSThread isMainThread]) {
		dispatch_async(dispatch_get_main_queue(), ^ {
			[self endNetworkActivity];
		});
		return;
	}

	NSParameterAssert(networkActivityStackingCount > 0);
	networkActivityStackingCount--;
	
	if (networkActivityStackingCount == 0)
		[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

}

- (BOOL) application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {

	if ([[url scheme] hasPrefix:@"fb"]) {
	
		//	fb357087874306060://authorize/#access_token=BAAFExPZCm0AwBAE0Rrkx45WrF9P9rSjttvmKqWCHFXCiflQCCaaA57AxiD4SUxjESg0VdMilsRcynBzIaxljzcmenZAXephyorGP7h3Eg7o6lahje3ox5f8bRJf99FPkmUKaTVWQZDZD&expires_in=5105534&code=AQDk-SBy1kclksewM5uX1W0GlTd0_Jc8VQT6gXb0grblRTPBSN8YPgdTVqYmi1Vuv0hnmskQpIxkjTOKBxRt__VQ4IdiJdThklKvzcZprTjD5Lhgid2U-O9lZ6JFclAyNQGbpy1cdsMWEkHoW0vDLNTiJqyAk2qZ5qbi0atfKNdxHFDtK9ee7338KoDR_8nOaxMeymONNrceZfzrRj48EYYy

		[[WAFacebookInterface sharedInterface].facebook handleOpenURL:url];
		
	} else {
	
		NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
			url, @"url",
			sourceApplication, @"sourceApplication",
			annotation, @"annotation",
		nil];

		[[NSNotificationCenter defaultCenter] postNotificationName:kWAApplicationDidReceiveRemoteURLNotification object:url userInfo:userInfo];
		
	}
	
  return YES;

}

- (void) applicationDidReceiveMemoryWarning:(UIApplication *)application {

	WAPostAppEvent(@"did-receive-memory-warning", [NSDictionary dictionaryWithObjectsAndKeys:
	
		//	TBD
	
	nil]);

}

@end
