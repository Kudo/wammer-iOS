//
//  WAPaginationSlider.m
//  wammer-iOS
//
//  Created by Evadne Wu on 7/21/11.
//  Copyright 2011 Waveface. All rights reserved.
//

#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

#import "WAPaginationSlider.h"


@interface WAPaginationSlider ()

@property (nonatomic, readwrite, retain) UISlider *slider;
@property (nonatomic, readwrite, retain) UILabel *pageIndicatorLabel; 
@property (nonatomic, readwrite, retain) NSArray *annotations;

+ (UIImage *) transparentImage;
- (void) sharedInit;
- (NSMutableArray *) mutableAnnotations;
- (CGFloat) positionForPageNumber:(NSUInteger)aPageNumber;
@property (nonatomic, readwrite, assign) BOOL needsAnnotationsLayout;

- (void) updateSliderLabelText;

@end


@implementation WAPaginationSlider
@synthesize slider, sliderInsets;
@synthesize dotRadius, dotMargin, edgeInsets, numberOfPages, currentPage, snapsToPages, delegate;
@synthesize pageIndicatorLabel;
@synthesize instantaneousCallbacks;
@synthesize layoutStrategy;
@synthesize annotations, needsAnnotationsLayout;

+ (UIImage *) transparentImage {

	static UIImage *returnedImage = nil;
	static dispatch_once_t onceToken = 0;
	
	dispatch_once(&onceToken, ^ {
    
		UIGraphicsBeginImageContextWithOptions((CGSize){ 1, 1 }, NO, 0.0f);
		returnedImage = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
		
	});

	return returnedImage;

}

- (id) initWithFrame:(CGRect)frame {

	self = [super initWithFrame:frame];
	
	if (!self)
		return nil;
	
	[self sharedInit];
				
	return self;
	
}

- (void) awakeFromNib {

	[super awakeFromNib];
	
	[self sharedInit];

}

- (void) sharedInit {

	self.sliderInsets = UIEdgeInsetsZero;
	self.annotations = [NSArray array];

	self.dotRadius = 3.0f;
	self.dotMargin = 12.0f;
	self.edgeInsets = (UIEdgeInsets){ 0, 12, 0, 12 };
	
	self.numberOfPages = 24;
	self.currentPage = 0;
	self.snapsToPages = YES;
	
	self.slider = [[UISlider alloc] initWithFrame:self.bounds];
	self.slider.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
	self.slider.value = 0;
	
	[self.slider setMinimumTrackImage:[[self class] transparentImage] forState:UIControlStateNormal];
	[self.slider setMaximumTrackImage:[[self class] transparentImage] forState:UIControlStateNormal];
	
	[self.slider setThumbImage:[UIImage imageNamed:@"WASliderKnob"] forState:UIControlStateNormal];
	[self.slider setThumbImage:[UIImage imageNamed:@"WASliderKnobDisabled"] forState:UIControlStateDisabled];
	[self.slider setThumbImage:[UIImage imageNamed:@"WASliderKnobPressed"] forState:UIControlStateSelected];
	[self.slider setThumbImage:[UIImage imageNamed:@"WASliderKnobPressed"] forState:UIControlStateHighlighted];
	
	[self.slider addTarget:self action:@selector(sliderDidMove:) forControlEvents:UIControlEventValueChanged];
	[self.slider addTarget:self action:@selector(sliderTouchDidStart:) forControlEvents:UIControlEventTouchDown];
	[self.slider addTarget:self action:@selector(sliderTouchDidEnd:) forControlEvents:UIControlEventTouchUpInside];
	[self.slider addTarget:self action:@selector(sliderTouchDidEnd:) forControlEvents:UIControlEventTouchUpOutside];
	
	self.pageIndicatorLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.pageIndicatorLabel.font = [UIFont boldSystemFontOfSize:14.0f];
	self.pageIndicatorLabel.textColor = [UIColor whiteColor];
	self.pageIndicatorLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75f];
	self.pageIndicatorLabel.opaque = NO;
	self.pageIndicatorLabel.alpha = 0;
	self.pageIndicatorLabel.userInteractionEnabled = NO;
	self.pageIndicatorLabel.textAlignment = NSTextAlignmentCenter;
	self.pageIndicatorLabel.layer.cornerRadius = 4.0f;
	
	[self addSubview:self.slider];
	[self addSubview:self.pageIndicatorLabel];
	
	[self setNeedsLayout];

}

- (void) setNumberOfPages:(NSUInteger)newNumberOfPages {

	if (numberOfPages == newNumberOfPages)
		return;
	
	[self willChangeValueForKey:@"numberOfPages"];
	numberOfPages = newNumberOfPages;
	[self didChangeValueForKey:@"numberOfPages"];
	
	[self.slider setValue:[self positionForPageNumber:self.currentPage] animated:YES];
	
	[self setNeedsLayout];

}

- (void) setBounds:(CGRect)bounds {

	self.needsAnnotationsLayout = YES;
	[super setBounds:bounds];

}

- (void) setFrame:(CGRect)frame {

	self.needsAnnotationsLayout = YES;
	[super setFrame:frame];

}

- (void) layoutSubviews {

	static int dotTag = 1048576;
	static int annotationViewTag = 2097152;
	
	NSMutableSet *dequeuedDots = [NSMutableSet set];
	NSMutableSet *currentDots = [NSMutableSet set];
	
	self.slider.enabled = !!self.numberOfPages;

	for (UIView *aSubview in self.subviews)
		if (aSubview.tag == dotTag)
			[dequeuedDots addObject:aSubview];
	
	UIEdgeInsets usedSliderInsets = self.sliderInsets;
	UIEdgeInsets usedInsets = self.edgeInsets;
	CGFloat usableWidth = CGRectGetWidth(self.bounds) - usedInsets.left - usedInsets.right;
	NSUInteger numberOfDots = (NSUInteger)floorf(usableWidth / (self.dotRadius + self.dotMargin));
	
	switch (self.layoutStrategy) {
		
		case WAPaginationSliderFillWithDotsLayoutStrategy: {
			break;
		}
		
		case WAPaginationSliderLessDotsLayoutStrategy: {
		
			if (self.numberOfPages)
				numberOfDots = MIN(numberOfDots, self.numberOfPages);
			
			CGFloat minWidth = (numberOfDots - 1) * dotMargin;
			
			if (minWidth < usableWidth) {
			
				CGFloat endowment = roundf(0.5 * (usableWidth - minWidth));
				CGFloat sliderEndowment = MIN(roundf(0.5 * (usableWidth - MAX(2, minWidth))), endowment);
				
				usedInsets.left += endowment;
				usedInsets.right += endowment; 
				
				usedSliderInsets.left += sliderEndowment;
				usedSliderInsets.right += sliderEndowment;
				
				usableWidth = minWidth;
				
			}
		
			break;
		}
		
	}
	
	self.slider.frame = UIEdgeInsetsInsetRect(self.bounds, usedSliderInsets);

	CGFloat dotSpacing = usableWidth / (numberOfDots - 1);
	
	UIImage *dotImage = (( ^ (CGFloat radius, CGFloat alpha) {
	
		UIGraphicsBeginImageContextWithOptions((CGSize){ radius, radius }, NO, 0.0f);
		CGContextRef context = UIGraphicsGetCurrentContext();
		CGContextSetFillColorWithColor(context, [[UIColor blackColor] colorWithAlphaComponent:alpha].CGColor);
		CGContextFillEllipseInRect(context, (CGRect){ 0, 0, radius, radius });
		UIImage *returnedImage = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
		
		return returnedImage;
	
	})(self.dotRadius, 0.35f));
	
	NSInteger numberOfRequiredNewDots = numberOfDots - [dequeuedDots count];
	
	if (numberOfRequiredNewDots)
	for (int i = 0; i < numberOfRequiredNewDots; i++) {
		UIView *dotView = [[UIView alloc] initWithFrame:(CGRect){ 0, 0, self.dotRadius, self.dotRadius }];
		dotView.tag = dotTag;
		dotView.layer.contents = (id)dotImage.CGImage;
		[dequeuedDots addObject:dotView];
	}
	
	CGFloat offsetX = usedInsets.left - 0.5 * self.dotRadius;
	CGFloat offsetY = roundf(0.5f * (CGRectGetHeight(self.bounds) - self.dotRadius));

	int i; for (i = 0; i < numberOfDots; i++) {
	
		UIView *dotView = (UIView *)[dequeuedDots anyObject];
		[dequeuedDots removeObject:dotView];
		
		dotView.frame = (CGRect){ roundf(offsetX), roundf(offsetY), self.dotRadius, self.dotRadius }; 
		[currentDots addObject:dotView];
		[self insertSubview:dotView belowSubview:slider];
		
		offsetX += dotSpacing;
		
	}
	
	for (UIView *unusedDotView in dequeuedDots)
		[unusedDotView removeFromSuperview];
	
	[self bringSubviewToFront:self.slider];
	
	static NSString * const kWAPaginationSliderAnnotationView_HostAnnotation = @"WAPaginationSliderAnnotationView_HostAnnotation";
	
	for (UIView *aSubview in self.subviews) {
		if (aSubview.tag == annotationViewTag) {

			if (![self.annotations containsObject:objc_getAssociatedObject(aSubview, &kWAPaginationSliderAnnotationView_HostAnnotation)]) {
				[aSubview removeFromSuperview];
			}
			
		}
	}
	
	for (WAPaginationSliderAnnotation *anAnnotation in self.annotations) {
		
		NSArray *allFittingAnnotationViews = [self.subviews filteredArrayUsingPredicate:[NSPredicate predicateWithBlock: ^ (UIView *anAnnotationView, NSDictionary *bindings) {
			
			if (anAnnotationView.tag != annotationViewTag)
				return NO;
			
			if (anAnnotation == objc_getAssociatedObject(anAnnotationView, &kWAPaginationSliderAnnotationView_HostAnnotation))
				return YES;
			
			return NO;
			
		}]];
		
		NSParameterAssert([allFittingAnnotationViews count] <= 1);
		
		UIView *annotationView = [allFittingAnnotationViews lastObject];
		
		if (!annotationView) {
			annotationView = [self.delegate viewForAnnotation:anAnnotation inPaginationSlider:self];
			annotationView.tag = annotationViewTag;
			objc_setAssociatedObject(annotationView, &kWAPaginationSliderAnnotationView_HostAnnotation, anAnnotation, OBJC_ASSOCIATION_ASSIGN);
		}
		
		NSAssert1(annotationView, @"Delegate must return a valid annotation view for annotation %@", anAnnotation);
		
		annotationView.center = (CGPoint){
			anAnnotation.centerOffset.x + usedInsets.left + roundf(usableWidth * [self positionForPageNumber:anAnnotation.pageIndex]),
			anAnnotation.centerOffset.y + roundf(0.5f * CGRectGetHeight(self.bounds))
		};
		
		annotationView.frame = CGRectIntegral(annotationView.frame);
		
		for (UIView *aDotView in currentDots) {
			BOOL dotOverlapsAnnotation = !CGRectEqualToRect(CGRectNull, CGRectIntersection(aDotView.frame, annotationView.frame));
			aDotView.hidden = dotOverlapsAnnotation;
		}
		
		if (annotationView.superview != self)
			[self insertSubview:annotationView belowSubview:slider];
		
	}

}

- (NSUInteger) estimatedPageNumberForPosition:(CGFloat)aPosition {

	if (!self.numberOfPages)
		return 0;
		
	CGFloat roughEstimation = ((self.numberOfPages - 1) * aPosition);
	
	if (roughEstimation == 0)
		return (NSUInteger)floorf(roughEstimation);
	else if (roughEstimation == (self.numberOfPages - 1))
		return (NSUInteger)ceilf(roughEstimation);
	else
		return (NSUInteger)roundf(roughEstimation);

}

- (CGFloat) positionForPageNumber:(NSUInteger)aPageNumber {

	if (!aPageNumber)
		return 0;
	
	CGFloat returnedValue = (CGFloat)(1.0f * aPageNumber / (self.numberOfPages - 1));
	return returnedValue;

}

- (void) updateSliderLabelText {

	NSString *baseCaption = [NSString stringWithFormat:@"%i of %i", (self.currentPage + 1), self.numberOfPages];;
	
	if ([self.delegate respondsToSelector:@selector(captionForProposedCaption:forPageAtIndex:inPaginationSlider:)])
		baseCaption = [self.delegate captionForProposedCaption:baseCaption forPageAtIndex:self.currentPage inPaginationSlider:self];
	
	self.pageIndicatorLabel.text = baseCaption;

}

- (CGRect) currentSliderThumbRect {

	CGRect sliderBounds = self.slider.bounds;
	CGRect sliderTrackRect = [self.slider trackRectForBounds:sliderBounds];
	CGFloat sliderValue = self.slider.value;
	
	CGRect prospectiveThumbRect = [self.slider thumbRectForBounds:sliderBounds trackRect:sliderTrackRect value:sliderValue];
	return [self convertRect:prospectiveThumbRect fromView:self.slider];

}

- (void) sliderTouchDidStart:(UISlider *)aSlider {

	[self willChangeValueForKey:@"currentPage"];
	currentPage = [self estimatedPageNumberForPosition:aSlider.value];
	[self didChangeValueForKey:@"currentPage"];
	
	[self updateSliderLabelText];
	
	[self.pageIndicatorLabel sizeToFit];
	self.pageIndicatorLabel.frame = UIEdgeInsetsInsetRect(self.pageIndicatorLabel.frame, (UIEdgeInsets){ -4, -4, -4, -4 });

	self.pageIndicatorLabel.center = (CGPoint){ CGRectGetMidX([self currentSliderThumbRect]), -12.0f };
	
	[UIView animateWithDuration:0.125f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut|UIViewAnimationOptionLayoutSubviews|UIViewAnimationOptionAllowUserInteraction animations: ^ {
		
		self.pageIndicatorLabel.alpha = 1.0f;
	
	} completion:nil];

}

- (void) sliderDidMove:(UISlider *)aSlider {

	[self willChangeValueForKey:@"currentPage"];
	currentPage = [self estimatedPageNumberForPosition:aSlider.value];
	[self didChangeValueForKey:@"currentPage"];
	
	[self updateSliderLabelText];
	
	[self.pageIndicatorLabel sizeToFit];
	self.pageIndicatorLabel.frame = UIEdgeInsetsInsetRect(self.pageIndicatorLabel.frame, (UIEdgeInsets){ -4, -4, -4, -4 });
	
	self.pageIndicatorLabel.center = (CGPoint){ CGRectGetMidX([self currentSliderThumbRect]), -12.0f };
	
	self.pageIndicatorLabel.frame = CGRectIntegral(self.pageIndicatorLabel.frame);
	
	if (instantaneousCallbacks)
		[self.delegate paginationSlider:self didMoveToPage:currentPage];
	
}

- (void) sliderTouchDidEnd:(UISlider *)aSlider {

	[self willChangeValueForKey:@"currentPage"];
	currentPage = [self estimatedPageNumberForPosition:aSlider.value];
	[self didChangeValueForKey:@"currentPage"];
		
	[UIView animateWithDuration:0.125f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut|UIViewAnimationOptionLayoutSubviews|UIViewAnimationOptionAllowUserInteraction animations: ^ {
		
		self.pageIndicatorLabel.alpha = 0.0f;
	
	} completion:nil];
	
	NSUInteger capturedCurrentPage = self.currentPage;
	dispatch_async(dispatch_get_current_queue(), ^ {
	
		[self.delegate paginationSlider:self didMoveToPage:capturedCurrentPage];
		
		if (self.snapsToPages) {
			
			CGFloat inferredSliderSnappingValue = [self positionForPageNumber:capturedCurrentPage];
			if (self.numberOfPages == 1)
				inferredSliderSnappingValue = 0.5;	//	Really?
				
			[aSlider setValue:inferredSliderSnappingValue animated:YES];
			
		}
		
	});

}

- (void) setCurrentPage:(NSUInteger)newPage {

	[self setCurrentPage:newPage animated:YES];

}

- (void) setCurrentPage:(NSUInteger)newPage animated:(BOOL)animate {

	if (currentPage == newPage)
		return;
	
	[self willChangeValueForKey:@"currentPage"];
	
	currentPage = newPage;
	
	if (![self.slider isTracking])
		[self.slider setValue:[self positionForPageNumber:newPage] animated:animate];
			
	[self didChangeValueForKey:@"currentPage"];
	
	[self setNeedsLayout];

}

- (NSMutableArray *) mutableAnnotations {

	return [self mutableArrayValueForKey:@"annotations"];

}

- (void) addAnnotations:(NSSet *)insertedAnnotations {

	[[self mutableAnnotations] addObjectsFromArray:[insertedAnnotations allObjects]];
	[self setNeedsAnnotationsLayout];

}

- (void) addAnnotationsObject:(WAPaginationSliderAnnotation *)anAnnotation {

	[[self mutableAnnotations] addObject:anAnnotation];
	[self setNeedsAnnotationsLayout];

}

- (void) removeAnnotations:(NSSet *)removedAnnotations {

	[[self mutableAnnotations] removeObjectsInArray:[removedAnnotations allObjects]];
	[self setNeedsAnnotationsLayout];

}

- (void) removeAnnotationsAtIndexes:(NSIndexSet *)indexes {

	[[self mutableAnnotations] removeObjectsAtIndexes:indexes];
	[self setNeedsAnnotationsLayout];

}

- (void) removeAnnotationsObject:(WAPaginationSliderAnnotation *)anAnnotation {

	[[self mutableAnnotations] removeObject:anAnnotation];
	[self setNeedsAnnotationsLayout];

}

- (void) setNeedsAnnotationsLayout {

	self.needsAnnotationsLayout = YES;
	[self setNeedsLayout];

}

@end





@implementation WAPaginationSliderAnnotation : NSObject
@synthesize title, pageIndex, centerOffset;

@end
