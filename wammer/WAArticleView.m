//
//  WAArticleView.m
//  wammer-iOS
//
//  Created by Evadne Wu on 10/11/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import "WAArticleView.h"
#import "WAImageStackView.h"
#import "WAPreviewBadge.h"
#import "WAArticleTextEmphasisLabel.h"
#import "WADataStore.h"

#import "IRRelativeDateFormatter.h"
#import "WAArticleViewController.h"

#import "IRLifetimeHelper.h"


@interface WAArticleView ()

- (void) waInit;
- (void) associateBindings;
- (void) disassociateBindings;

+ (IRRelativeDateFormatter *) relativeDateFormatter;

@property (nonatomic, readwrite, assign) WAArticleViewControllerPresentationStyle presentationStyle;

@end


@implementation WAArticleView

@synthesize article;

@synthesize presentationStyle;

@synthesize contextInfoContainer, imageStackView, previewBadge, textEmphasisView, avatarView, relativeCreationDateLabel, userNameLabel, articleDescriptionLabel, deviceDescriptionLabel, contextTextView, mainImageView;

- (id) initWithFrame:(CGRect)frame {

	self = [super initWithFrame:frame];
	if (!self)
		return nil;
	
	[self waInit];
	
	return self;

}

- (void) awakeFromNib {

	[super awakeFromNib];
	
	[self waInit];

}

- (void) waInit {

	self.exclusiveTouch = YES;

	if (self.avatarView) {

		self.avatarView.layer.masksToBounds = YES;
		self.avatarView.backgroundColor = [UIColor colorWithRed:0.85f green:0.85f blue:0.85f alpha:1];
		UIView *avatarContainingView = [[UIView alloc] initWithFrame:self.avatarView.frame];
		avatarContainingView.autoresizingMask = self.avatarView.autoresizingMask;
		self.avatarView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
		[self.avatarView.superview insertSubview:avatarContainingView belowSubview:self.avatarView];
		[avatarContainingView addSubview:self.avatarView];
		self.avatarView.center = (CGPoint){ CGRectGetMidX(self.avatarView.superview.bounds), CGRectGetMidY(self.avatarView.superview.bounds) };
		//	avatarContainingView.layer.shadowPath = [UIBezierPath bezierPathWithRect:avatarContainingView.bounds].CGPath;
		//	avatarContainingView.layer.shadowOpacity = 0.25f;
		//	avatarContainingView.layer.shadowOffset = (CGSize){ 0, 1 };
		//	avatarContainingView.layer.shadowRadius = 1.0f;
		avatarContainingView.layer.borderColor = [UIColor whiteColor].CGColor;
		avatarContainingView.layer.borderWidth = 1.0f;
	
	}
	
	self.mainImageView.contentMode = UIViewContentModeScaleAspectFill;
	
	if (self.textEmphasisView) {
	
		self.textEmphasisView.backgroundView = [[UIView alloc] initWithFrame:self.textEmphasisView.bounds];
		self.textEmphasisView.backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
		self.textEmphasisView.font = [UIFont fontWithName:@"HelevticaNeue-Light" size:16.0];
		
		UIView *bubbleView = [[UIView alloc] initWithFrame:self.textEmphasisView.backgroundView.bounds];
		bubbleView.layer.contents = (id)[UIImage imageNamed:@"WASpeechBubble"].CGImage;
		bubbleView.layer.contentsCenter = (CGRect){ 80.0/128.0, 32.0/88.0, 1.0/128.0, 8.0/88.0 };
		bubbleView.frame = UIEdgeInsetsInsetRect(bubbleView.frame, (UIEdgeInsets){ -28, -32, -44, -32 });
		bubbleView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
		[self.textEmphasisView.backgroundView addSubview:bubbleView];
	
	}

}

- (void) dealloc {

	[self disassociateBindings];

}




- (void) setPresentationStyle:(WAArticleViewControllerPresentationStyle)newPresentationStyle {

	if (presentationStyle == newPresentationStyle)
		return;
	
	presentationStyle = newPresentationStyle;
	
	switch (presentationStyle) {

		case WADiscreteSingleImageArticleStyle: {
			self.userNameLabel.font = [UIFont fontWithName:@"Sansus Webissimo" size:16.0f];
			//	self.articleDescriptionLabel.layer.shadowOpacity = 1;
			//	self.articleDescriptionLabel.layer.shadowOffset = (CGSize){ 0, 1 };
			break;
		}
		
		case WADiscretePlaintextArticleStyle: {
			self.userNameLabel.font = [UIFont fontWithName:@"Sansus Webissimo" size:20.0f];
			self.textEmphasisView.backgroundView = nil;
			self.textEmphasisView.backgroundColor = nil;
			break;
		}
		
		case WADiscretePreviewArticleStyle: {
			self.previewBadge.backgroundView = nil;
			self.previewBadge.titleColor = [UIColor grayColor];
			self.previewBadge.userInteractionEnabled = NO;			
			self.previewBadge.titlePlaceholder = nil;
			self.previewBadge.providerNamePlaceholder = nil;
			self.previewBadge.textPlaceholder = nil;
			break;
		}
		
		default:
			break;
		
	}


}





- (void) setArticle:(WAArticle *)newArticle {

	if (newArticle == article)
		return;
	
	[self disassociateBindings];
	
	article = newArticle;
	
	[self associateBindings];
	
}


- (void) associateBindings {

	__weak WAArticleView *nrSelf = self;
	
	[self disassociateBindings];
	
	WAArticle *boundArticle = self.article;

	if (!boundArticle)
		return;
	
	void (^bind)(id, NSString *, id, NSString *, IRBindingsValueTransformer) = ^ (id object, NSString *objectKeyPath,  id boundObject, NSString *boundKeypath, IRBindingsValueTransformer transformerBlock) {
	
		[object irBind:objectKeyPath toObject:boundObject keyPath:boundKeypath options:[NSDictionary dictionaryWithObjectsAndKeys:
			(id)kCFBooleanTrue, kIRBindingsAssignOnMainThreadOption,
			[transformerBlock copy], kIRBindingsValueTransformerBlock,
		nil]];
		
	};
	
	bind(self.userNameLabel, @"text", boundArticle, @"owner.nickname", nil);
	
	bind(self.relativeCreationDateLabel, @"text", boundArticle, @"creationDate", ^ (id inOldValue, id inNewValue, NSString *changeKind) {
		return [[[nrSelf class] relativeDateFormatter] stringFromDate:inNewValue];
	});
	
	bind(self.articleDescriptionLabel, @"text", boundArticle, @"text", nil);
	
	bind(self.previewBadge, @"preview", boundArticle, @"previews", ^ (id inOldValue, id inNewValue, NSString *changeKind) {
		return (WAPreview *)[[[inNewValue allObjects] sortedArrayUsingDescriptors:[NSArray arrayWithObjects:
			[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES],
		nil]] lastObject];
	});
	
	bind(self.imageStackView, @"images", boundArticle, @"representingFile.thumbnailImage", ^ (id inOldValue, id inNewValue, NSString *changeKind) {
		return inNewValue ? [NSArray arrayWithObject:inNewValue] : nil;
	});
	
	bind(self.mainImageView, @"image", boundArticle, @"representingFile.thumbnailImage", ^ (id inOldValue, id inNewValue, NSString *changeKind) {
		return inNewValue;
	});
	
	bind(self.mainImageView, @"backgroundColor", boundArticle, @"representingFile.thumbnailImage", ^ (id inOldValue, id inNewValue, NSString *changeKind) {
		return inNewValue ? [UIColor clearColor] : [UIColor colorWithWhite:0.5 alpha:1];
	});
	
	bind(self.avatarView, @"image", boundArticle, @"owner.avatar", ^ (id inOldValue, id inNewValue, NSString *changeKind) {
		return [inNewValue isEqual:[NSNull null]] ? nil : inNewValue;
	});
	
	bind(self.deviceDescriptionLabel, @"text", boundArticle, @"creationDeviceName", ^ (id inOldValue, id inNewValue, NSString *changeKind) {
		return inNewValue ? inNewValue : @"an unknown device";
	});
	
	bind(self.textEmphasisView, @"text", boundArticle, @"text", nil);
	
	bind(self.textEmphasisView, @"hidden", boundArticle, @"files", ^ (id inOldValue, id inNewValue, NSString *changeKind) {
		return [NSNumber numberWithBool:!![inNewValue count]];
	});
	
}


- (void) disassociateBindings {

	[self.userNameLabel irUnbind:@"text"];
	[self.relativeCreationDateLabel irUnbind:@"text"];
	[self.articleDescriptionLabel irUnbind:@"text"];
	[self.previewBadge irUnbind:@"preview"];
	[self.imageStackView irUnbind:@"images"];
	[self.mainImageView irUnbind:@"image"];
	[self.mainImageView irUnbind:@"backgroundColor"];
	[self.avatarView irUnbind:@"image"];
	[self.deviceDescriptionLabel irUnbind:@"text"];
	[self.textEmphasisView irUnbind:@"text"];
	[self.textEmphasisView irUnbind:@"hidden"];

}


- (void) layoutSubviews {

	[super layoutSubviews];
	
	__weak WAArticleView *wSelf = self;

	CGPoint centerOffset = CGPointZero;

	CGRect usableRect = UIEdgeInsetsInsetRect(wSelf.bounds, (UIEdgeInsets){ 10, 10, 32, 10 });
	
	const CGFloat maximumTextWidth = CGRectGetWidth(usableRect);
	const CGFloat minimumTextWidth = CGRectGetWidth(usableRect);

	if (usableRect.size.width > maximumTextWidth) {
		usableRect.origin.x += roundf(0.5f * (usableRect.size.width - maximumTextWidth));
		usableRect.size.width = maximumTextWidth;
	}
	usableRect.size.width = MAX(usableRect.size.width, minimumTextWidth);
	
	CGRect textRect = usableRect;
	textRect.size.height = 1;
	textEmphasisView.frame = textRect;
	[textEmphasisView sizeToFit];
	textRect = wSelf.textEmphasisView.frame;
	textRect.size.height = MIN(textRect.size.height, usableRect.size.height - 16 );
	textEmphasisView.frame = textRect;
	
	BOOL contextInfoAnchorsPlaintextBubble = NO;
	
	switch (presentationStyle) {
	
		case WAFullFramePlaintextArticleStyle: {
			
			centerOffset.y -= 0.5f * CGRectGetHeight(wSelf.contextInfoContainer.frame) + 24;
			contextInfoAnchorsPlaintextBubble = NO;
			//	Fall through
			
		}
		case WAFullFrameImageStackArticleStyle:
		case WAFullFramePreviewArticleStyle: {
			
			wSelf.previewBadge.minimumAcceptibleFullFrameAspectRatio = 0.01f;
			wSelf.imageStackView.maxNumberOfImages = 2;
			
			break;
		
		}

		case WADiscretePlaintextArticleStyle: {
		
			wSelf.imageStackView.maxNumberOfImages = 1;
			centerOffset.y -= 16;
		
			previewBadge.frame = UIEdgeInsetsInsetRect(self.bounds, (UIEdgeInsets){ 0, 0, 32, 0 });
			previewBadge.backgroundView = nil;
			contextInfoAnchorsPlaintextBubble = NO;
			
			break;
			
		}
		
		case WADiscreteSingleImageArticleStyle:
		case WADiscretePreviewArticleStyle: {
		
			contextInfoContainer.hidden = ![self.article.text length];
			
			[userNameLabel sizeToFit];
			[relativeCreationDateLabel sizeToFit];
			[relativeCreationDateLabel irPlaceBehindLabel:userNameLabel withEdgeInsets:(UIEdgeInsets){ 0, -8, 0, -8 }];
			[deviceDescriptionLabel sizeToFit];
			[deviceDescriptionLabel irPlaceBehindLabel:relativeCreationDateLabel withEdgeInsets:(UIEdgeInsets){ 0, -8, 0, -8 }];
			
			previewBadge.style = WAPreviewBadgeImageAndTextStyle;
			
			previewBadge.titleFont = [UIFont fontWithName:@"Georgia-BoldItalic" size:18.0];
			previewBadge.titleColor = [UIColor colorWithWhite:0.25 alpha:1];
			previewBadge.providerNameFont = [UIFont fontWithName:@"HelveticaNeue-Regular" size:18.0];
			
			previewBadge.textFont = [UIFont fontWithName:@"Georgia" size:18.0];
			
			break;
			
		}
		
		default:
			break;
	}
	
	CGPoint center = (CGPoint){
		roundf(CGRectGetMidX(wSelf.bounds)),
		roundf(CGRectGetMidY(wSelf.bounds))
	};
	
	wSelf.textEmphasisView.center = irCGPointAddPoint(center, centerOffset);
	wSelf.textEmphasisView.frame = CGRectIntegral(wSelf.textEmphasisView.frame);
	
	if (contextInfoAnchorsPlaintextBubble) {
		wSelf.contextInfoContainer.frame = (CGRect){
			(CGPoint){
				CGRectGetMinX(wSelf.textEmphasisView.frame),
				CGRectGetMaxY(wSelf.textEmphasisView.frame) + 32
			},
			wSelf.contextInfoContainer.frame.size
		};
	}
	
	CGRect oldDescriptionFrame = wSelf.articleDescriptionLabel.frame;
	
	CGSize fitSize = [wSelf.articleDescriptionLabel sizeThatFits:(CGSize){
		wSelf.contextInfoContainer.frame.size.width - 16,
		64
	}];
	
	fitSize.height = MAX(24, MIN(fitSize.height, 64));
	CGFloat heightDelta = fitSize.height - CGRectGetHeight(wSelf.articleDescriptionLabel.frame);
	wSelf.articleDescriptionLabel.frame = IRGravitize(oldDescriptionFrame, fitSize, kCAGravityBottomLeft);
	
	CGSize newContextInfoContainerSize = wSelf.contextInfoContainer.frame.size;
	newContextInfoContainerSize.height += heightDelta;
	
	wSelf.contextInfoContainer.frame = IRGravitize(wSelf.contextInfoContainer.frame, newContextInfoContainerSize, kCAGravityBottomLeft);

}




+ (IRRelativeDateFormatter *) relativeDateFormatter {

	static IRRelativeDateFormatter *formatter = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{

		formatter = [[IRRelativeDateFormatter alloc] init];
		formatter.approximationMaxTokenCount = 1;
			
	});

	return formatter;

}

@end
