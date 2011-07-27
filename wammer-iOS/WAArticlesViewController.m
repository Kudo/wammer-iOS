//
//  WAArticlesViewController.m
//  wammer-iOS
//
//  Created by Evadne Wu on 7/20/11.
//  Copyright 2011 Iridia Productions. All rights reserved.
//

#import "WADataStore.h"
#import "WAArticlesViewController.h"
#import "WACompositionViewController.h"
#import "WAPaginationSlider.h"

#import "WARemoteInterface.h"

#import "IRPaginatedView.h"
#import "IRBarButtonItem.h"
#import "IRTransparentToolbar.h"
#import "IRActionSheetController.h"
#import "IRActionSheet.h"


@interface WAArticlesViewController () <IRPaginatedViewDelegate, WAPaginationSliderDelegate, NSFetchedResultsControllerDelegate>

@property (nonatomic, readwrite, retain) IRPaginatedView *paginatedView;
@property (nonatomic, readwrite, retain) IRActionSheetController *debugActionSheetController;
@property (nonatomic, readwrite, retain) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, readwrite, retain) NSManagedObjectContext *managedObjectContext;

@property (nonatomic, readwrite, retain) UIView *coachmarkView;
@property (nonatomic, readwrite, retain) WAPaginationSlider *paginationSlider;

- (void) refreshData;

@end


@implementation WAArticlesViewController
@synthesize paginatedView;
@synthesize fetchedResultsController;
@synthesize managedObjectContext;
@synthesize coachmarkView;
@synthesize paginationSlider;
@synthesize debugActionSheetController;

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {

	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	
	if (!self)
		return nil;
		
	IRTransparentToolbar *toolbar = [[[IRTransparentToolbar alloc] initWithFrame:(CGRect){ 0, 0, 100, 44 }] autorelease];
	toolbar.usesCustomLayout = NO;
	toolbar.items = [NSArray arrayWithObjects:
		[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemOrganize target:self action:@selector(handleAction:)] autorelease],
		[IRBarButtonItem itemWithCustomView:[[[UIView alloc] initWithFrame:(CGRect){ 0, 0, 14.0f, 44 }] autorelease]],
		[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose target:self action:@selector(handleCompose:)] autorelease],
		[IRBarButtonItem itemWithCustomView:[[[UIView alloc] initWithFrame:(CGRect){ 0, 0, 8.0f, 44 }] autorelease]],
	nil];
		
	self.title = @"Articles";
	self.navigationItem.rightBarButtonItem = [IRBarButtonItem itemWithCustomView:toolbar];
	
	self.debugActionSheetController = [IRActionSheetController actionSheetControllerWithTitle:nil cancelAction:nil destructiveAction:nil otherActions:[NSArray arrayWithObjects:
	
		[IRAction actionWithTitle:@"Debug Import" block:^(void) {
		
			[[[[UIAlertView alloc] initWithTitle:@"Debug Import" message:@"I should import stuff." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil] autorelease] show];
		
		}],
	
	nil]];
		
	self.managedObjectContext = [[WADataStore defaultStore] disposableMOC];
	self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:((^ {
	
		NSFetchRequest *returnedRequest = [[[NSFetchRequest alloc] init] autorelease];
		returnedRequest.entity = [NSEntityDescription entityForName:@"WAArticle" inManagedObjectContext:self.managedObjectContext];
		returnedRequest.sortDescriptors = [NSArray arrayWithObjects:
			[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES],
		nil];
		
		return returnedRequest;
	
	})()) managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
	
	self.fetchedResultsController.delegate = self;
		
	return self;

}

- (void) dealloc {
	
	[paginatedView release];
	[paginationSlider release];
	[coachmarkView release];
	[managedObjectContext release];
	[fetchedResultsController release];
	[super dealloc];

}

- (void) loadView {

	self.view = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
	self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
	self.view.backgroundColor = [UIColor whiteColor];
	
	self.paginatedView = [[[IRPaginatedView alloc] initWithFrame:(CGRect){ 0, 0, CGRectGetWidth(self.view.frame), 44 }] autorelease];
	self.paginatedView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
	self.paginatedView.backgroundColor = [UIColor whiteColor];
	self.paginatedView.delegate = self;
	[self.paginatedView addObserver:self forKeyPath:@"currentPage" options:NSKeyValueObservingOptionNew context:nil];
	
	self.coachmarkView = [[[UIView alloc] initWithFrame:self.view.bounds] autorelease];
	self.coachmarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
	self.coachmarkView.opaque = NO;
	self.coachmarkView.backgroundColor = [UIColor clearColor];
	[self.coachmarkView addSubview:((^ {
	
		UILabel *returnedLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		returnedLabel.text = @"No Articles";
		returnedLabel.font = [UIFont boldSystemFontOfSize:18.0f];
		returnedLabel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleBottomMargin;
		
		[returnedLabel sizeToFit];
		[returnedLabel setCenter:self.coachmarkView.center];
		
		return returnedLabel;
		
	})())];
	
	
	self.paginationSlider = [[[WAPaginationSlider alloc] initWithFrame:(CGRect){ 0, CGRectGetHeight(self.view.frame) - 44, CGRectGetWidth(self.view.frame), 44 }] autorelease];
	self.paginationSlider.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin;	
	self.paginationSlider.delegate = self;
	
	[self.view addSubview:self.paginatedView];
	[self.view addSubview:self.coachmarkView];
	[self.view addSubview:self.paginationSlider];
	
}

- (void) viewDidUnload {

	[self.paginatedView removeObserver:self forKeyPath:@"currentPage"];
	
	self.paginatedView = nil;
	self.coachmarkView = nil;
	self.paginationSlider = nil;
	
	[super viewDidUnload];

}

- (void) viewWillAppear:(BOOL)animated {

	[super viewWillAppear:animated];
	
	//	I am not really sure this works!
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
	
		[self refreshData];
		
		[self.fetchedResultsController performFetch:nil];
		[self.paginatedView reloadViews];
		
		NSUInteger numberOfFetchedObjects = [[self.fetchedResultsController fetchedObjects] count];
		self.coachmarkView.hidden = (numberOfFetchedObjects > 0);
		self.paginationSlider.hidden = (numberOfFetchedObjects == 0); 
		self.paginationSlider.numberOfPages = numberOfFetchedObjects;
		
		CGRect paginationSliderFrame = self.paginationSlider.frame;
		paginationSliderFrame.size.width = MIN(512, MAX(MIN(300, paginationSliderFrame.size.width), self.paginationSlider.numberOfPages * (self.paginationSlider.dotMargin + self.paginationSlider.dotRadius)));
		
		paginationSliderFrame.origin.x = roundf(0.5f * (CGRectGetWidth(self.paginationSlider.superview.frame) - paginationSliderFrame.size.width));
		self.paginationSlider.frame = paginationSliderFrame;
		self.paginationSlider.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin;
		
	});

}

- (void) viewWillDisappear:(BOOL)animated {

	[super viewWillDisappear:animated];
	
	if (self.debugActionSheetController.managedActionSheet.visible)
		[self.debugActionSheetController.managedActionSheet dismissWithClickedButtonIndex:self.debugActionSheetController.managedActionSheet.cancelButtonIndex animated:animated];

}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {

	if ((object == self.paginatedView) && ([keyPath isEqualToString:@"currentPage"])) {
	
		NSUInteger newPage = [[change objectForKey:NSKeyValueChangeNewKey] unsignedIntValue];
		self.paginationSlider.currentPage = newPage;
	
	}

}

- (NSUInteger) numberOfViewsInPaginatedView:(IRPaginatedView *)paginatedView {

	return [[self.fetchedResultsController fetchedObjects] count];

}

- (UIView *) viewForPaginatedView:(IRPaginatedView *)aPaginatedView atIndex:(NSUInteger)index {

	UIView *returnedView = [[[UIView alloc] initWithFrame:aPaginatedView.bounds] autorelease];
	returnedView.backgroundColor = [UIColor whiteColor];
	
	UILabel *descriptionLabel = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
	descriptionLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleBottomMargin|UIViewAutoresizingFlexibleRightMargin;
	descriptionLabel.textAlignment = UITextAlignmentCenter;
	descriptionLabel.font = [UIFont boldSystemFontOfSize:18.0f];
	descriptionLabel.text = [NSString stringWithFormat:@"<%@ %x> page for article at index %i", NSStringFromClass([self class]), self, index];
	[descriptionLabel sizeToFit];
	
	UILabel *contentLabel = [[[UILabel alloc] initWithFrame:(CGRect){ 0, 0, 512, 512 }] autorelease];
	contentLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleBottomMargin|UIViewAutoresizingFlexibleRightMargin;
	contentLabel.text = [[self.fetchedResultsController objectAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]] description];
	contentLabel.numberOfLines = 0;
	[contentLabel sizeToFit];
	
	CGPoint contentTopCenterOrigin = (CGPoint){ 0.5f * CGRectGetWidth(aPaginatedView.bounds), 256.0f };	//	0.5f * CGRectGetHeight(aPaginatedView.bounds)
	contentTopCenterOrigin.y -= 0.5f * CGRectGetHeight(descriptionLabel.frame);
	contentTopCenterOrigin.y -= 0.5f * 24.0f;
	contentTopCenterOrigin.y -= 0.5f * CGRectGetHeight(contentLabel.frame);
	
	descriptionLabel.frame = CGRectIntegral((CGRect){
		(CGPoint){
			contentTopCenterOrigin.x - 0.5f * descriptionLabel.frame.size.width,
			contentTopCenterOrigin.y
		},
		descriptionLabel.frame.size
	});
	
	contentLabel.frame = CGRectIntegral((CGRect){
		(CGPoint){
			contentTopCenterOrigin.x - 0.5f * contentLabel.frame.size.width,
			contentTopCenterOrigin.y + descriptionLabel.frame.size.height + 24.0f
		},
		contentLabel.frame.size
	});
	
	[returnedView addSubview:descriptionLabel];
	[returnedView addSubview:contentLabel];
	
	return returnedView;

}

- (UIViewController *) viewControllerForSubviewAtIndex:(NSUInteger)index inPaginatedView:(IRPaginatedView *)paginatedView {

	return nil;

}

- (void) paginationSlider:(WAPaginationSlider *)slider didMoveToPage:(NSUInteger)destinationPage {

	//	NSLog(@"%s %@ %i", __PRETTY_FUNCTION__, slider, destinationPage);
	
	if (self.paginatedView.currentPage == destinationPage)
		return;
	
	[[UIApplication sharedApplication] beginIgnoringInteractionEvents];
	
	dispatch_async(dispatch_get_main_queue(), ^ {
	
		[CATransaction begin];
		CATransition *transition = [CATransition animation];
		transition.type = kCATransitionMoveIn;
		transition.subtype = (self.paginatedView.currentPage < destinationPage) ? kCATransitionFromRight : kCATransitionFromLeft;
		transition.duration = 0.25f;
		transition.fillMode = kCAFillModeForwards;
		transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
		transition.removedOnCompletion = YES;
		
		[self.paginatedView scrollToPageAtIndex:destinationPage animated:NO];
		[self.paginatedView.layer addAnimation:transition forKey:@"transition"];
		
		[CATransaction setCompletionBlock: ^ {
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, transition.duration * NSEC_PER_SEC), dispatch_get_main_queue(), ^ {
				[[UIApplication sharedApplication] endIgnoringInteractionEvents];
			});
		}];
		
		[CATransaction commit];
	
	});

}

- (void) handleAction:(UIBarButtonItem *)sender {

	[self.debugActionSheetController.managedActionSheet showFromBarButtonItem:sender animated:YES];

}

- (void) handleCompose:(UIBarButtonItem *)sender {

	WACompositionViewController *compositionVC = [[[WACompositionViewController alloc] init] autorelease];
	
	UINavigationController *wrapperNC = [[[UINavigationController alloc] initWithRootViewController:compositionVC] autorelease];
	wrapperNC.modalPresentationStyle = UIModalPresentationFullScreen;
	
	[(self.navigationController ? self.navigationController : self) presentModalViewController:wrapperNC animated:YES];

}

- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {

	[self.paginatedView setNeedsLayout];

}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)newOrientation {

	if ([[UIApplication sharedApplication] isIgnoringInteractionEvents])
		return (self.interfaceOrientation == newOrientation);

	return YES;
	
}





- (void) refreshData {

	[[WARemoteInterface sharedInterface] retrieveArticlesWithContinuation:nil batchLimit:200 onSuccess:^(NSArray *retrievedArticleReps) {
	
		NSManagedObjectContext *context = [[WADataStore defaultStore] disposableMOC];
		
		[WAArticle insertOrUpdateObjectsUsingContext:context withRemoteResponse:retrievedArticleReps usingMapping:[NSDictionary dictionaryWithObjectsAndKeys:
			@"WAFile", @"files",
			@"WAComment", @"comments",
		nil] options:0];
		
		NSError *savingError = nil;
		if (![context save:&savingError])
			NSLog(@"Saving Error %@", savingError);
		
	} onFailure:^(NSError *error) {
		
		NSLog(@"Fail %@", error);
		
	}];

}

- (void) controllerWillChangeContent:(NSFetchedResultsController *)controller {
	
	NSLog(@"%s %@ %@", __PRETTY_FUNCTION__, [NSThread currentThread], controller);
	
}

- (void) controllerDidChangeContent:(NSFetchedResultsController *)controller {
	
	NSLog(@"%s %@ %@", __PRETTY_FUNCTION__, [NSThread currentThread], controller);
	
}

@end
