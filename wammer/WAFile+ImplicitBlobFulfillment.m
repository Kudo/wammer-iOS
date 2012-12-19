//
//  WAFile+ImplicitBlobFulfillment.m
//  wammer
//
//  Created by Evadne Wu on 5/21/12.
//  Copyright (c) 2012 Waveface. All rights reserved.
//

#import "WAFile+WAConstants.h"
#import "WAFile+CoreDataGeneratedPrimitiveAccessors.h"
#import "WAFile+ImplicitBlobFulfillment.h"

#import "WARemoteInterface.h"
#import "WADataStore.h"
#import "WAImageProcessing.h"

@implementation WAFile (ImplicitBlobFulfillment)

- (void) setDisplayingSmallThumbnail:(BOOL)displayingSmallThumbnail {
	[self irAssociateObject:(id)(displayingSmallThumbnail ? kCFBooleanTrue : kCFBooleanFalse) usingKey:&kWAFileDisplayingSmallThumbnail policy:OBJC_ASSOCIATION_ASSIGN changingObservedKey:nil];
}

- (BOOL) displayingSmallThumbnail {
	return [objc_getAssociatedObject(self, &kWAFileDisplayingSmallThumbnail) boolValue];
}

- (void)setDisplayingThumbnail:(BOOL)displayingThumbnail {
	[self irAssociateObject:(id)(displayingThumbnail ? kCFBooleanTrue : kCFBooleanFalse) usingKey:&kWAFileDisplayingThumbnail policy:OBJC_ASSOCIATION_ASSIGN changingObservedKey:nil];
}

- (BOOL)displayingThumbnail {
	return [objc_getAssociatedObject(self, &kWAFileDisplayingThumbnail) boolValue];
}

- (BOOL) attemptsBlobRetrieval {

	return [objc_getAssociatedObject(self, &kWAFileAttemptsBlobRetrieval) boolValue];
	
}

- (void) setAttemptsBlobRetrieval:(BOOL)newFlag notify:(BOOL)firesKVONotifications {

	[self irAssociateObject:(id)(newFlag ? kCFBooleanTrue : kCFBooleanFalse) usingKey:&kWAFileAttemptsBlobRetrieval policy:OBJC_ASSOCIATION_ASSIGN changingObservedKey:(firesKVONotifications ? kWAFileAttemptsBlobRetrieval : nil)];

}

- (void) performBlockSuppressingBlobRetrieval:(void(^)(void))aBlock {

	if (!aBlock)
		return;

	BOOL couldHaveAttempteBlobRetrieval = [self attemptsBlobRetrieval];
	
	[self setAttemptsBlobRetrieval:NO notify:NO];

	aBlock();
	
	[self setAttemptsBlobRetrieval:couldHaveAttempteBlobRetrieval notify:NO];

}

- (NSOperationQueuePriority) retrievalPriorityForBlobFilePathKey:(NSString *)key {

	if ([key isEqualToString:kWAFileResourceFilePath])
		return NSOperationQueuePriorityVeryLow;
		
	if ([key isEqualToString:kWAFileLargeThumbnailFilePath])
		return NSOperationQueuePriorityLow;
	
	if ([key isEqualToString:kWAFileThumbnailFilePath]) {
		if ([self displayingThumbnail]) {
			return NSOperationQueuePriorityHigh;
		}
		return NSOperationQueuePriorityNormal;
	}
	
	if ([key isEqualToString:kWAFileSmallThumbnailFilePath]) {
		if ([self displayingSmallThumbnail]) {
			return NSOperationQueuePriorityHigh;
		}
		return NSOperationQueuePriorityNormal;
	}
	
	return NSOperationQueuePriorityNormal;

}

- (BOOL) canRetrieveBlobForFilePathKeyPath:(NSString *)keyPath {

	if ([[self objectID] isTemporaryID])
		return NO;
	
	if ([self isDeleted])
		return NO;
	
	if (![self attemptsBlobRetrieval])
		return NO;
	
	if ([keyPath isEqualToString:kWAFileResourceFilePath])
		if (![[WARemoteInterface sharedInterface] areExpensiveOperationsAllowed])
			return NO;
	
	return YES;

}

- (void) retrieveBlobWithURLString:(NSString *)urlString URLStringKey:(NSString *)urlStringKey filePathKey:(NSString *)filePathKey {

	NSURL *url = [NSURL URLWithString:urlString];
	NSOperationQueuePriority priority = [self retrievalPriorityForBlobFilePathKey:filePathKey];

	[self scheduleRetrievalForBlobURL:url blobKeyPath:urlStringKey filePathKeyPath:filePathKey usingPriority:priority];

}

- (void) scheduleRetrievalForBlobURL:(NSURL *)blobURL blobKeyPath:(NSString *)blobURLKeyPath filePathKeyPath:(NSString *)filePathKeyPath usingPriority:(NSOperationQueuePriority)priority {

	if (![self canRetrieveBlobForFilePathKeyPath:filePathKeyPath])
		return;
	
	NSURL *ownURL = [[self objectID] URIRepresentation];
	Class class = [self class];
	
	[[IRRemoteResourcesManager sharedManager] retrieveResourceAtURL:blobURL usingPriority:priority forced:NO withCompletionBlock:^(NSURL *tempFileURLOrNil) {

		if (!tempFileURLOrNil) {
			return;
		}

		if (!class)
			return;

		if (![UIImage imageWithContentsOfFile:[tempFileURLOrNil path]]) {
			__weak WAFile *wSelf = self;
			int64_t delayInSeconds = 3.0;
			dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
			dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
				[wSelf scheduleRetrievalForBlobURL:blobURL blobKeyPath:blobURLKeyPath filePathKeyPath:filePathKeyPath usingPriority:priority];
			});
			return;
		}
		
		[WAImageProcessing makeThumbnailWithImageFilePath:[tempFileURLOrNil path] options:WAThumbnailMakeOptionExtraSmall completeBlock:^(UIImage *image) {

			NSManagedObjectContext *context = [[WADataStore defaultStore] autoUpdatingMOC];
			context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
			WAFile *file = (WAFile *)[context irManagedObjectForURI:ownURL];
			if (!file.extraSmallThumbnailFilePath) {
				file.extraSmallThumbnailFilePath = [[[WADataStore defaultStore] persistentFileURLForData:UIImageJPEGRepresentation(image, 0.85f) extension:@"jpeg"] path];
				[context save:nil];
			}

		}];
		
		dispatch_async([class sharedResourceHandlingQueue], ^ {

			NSManagedObjectContext *context = [[WADataStore defaultStore] autoUpdatingMOC];
			WAFile *file = (WAFile *)[context irManagedObjectForURI:ownURL];
			
			if ([file takeBlobFromTemporaryFile:[tempFileURLOrNil path] forKeyPath:filePathKeyPath matchingURL:blobURL forKeyPath:blobURLKeyPath]) {
			
				context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
			
				NSError *savingError = nil;
				if (![context save:&savingError])
					NSLog(@"Error saving: %@", savingError);

			}

		});
		
	}];

}

- (BOOL) takeBlobFromTemporaryFile:(NSString *)aPath forKeyPath:(NSString *)fileKeyPath matchingURL:(NSURL *)anURL forKeyPath:(NSString *)urlKeyPath {

	NSError *error = nil;
	WADataStore *ds = [WADataStore defaultStore];

	if (![ds updateObject:self inContext:self.managedObjectContext takingBlobFromTemporaryFile:aPath usingResourceType:self.resourceType forKeyPath:fileKeyPath matchingURL:anURL forKeyPath:urlKeyPath error:&error]) {
		
		NSLog(@"%s: %@", __PRETTY_FUNCTION__, error);
		return NO;
		
	}
	
	return YES;

}

+ (dispatch_queue_t) sharedResourceHandlingQueue {

  static dispatch_queue_t queue = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
      queue = dispatch_queue_create("com.waveface.wammer.WAFile.resourceHandlingQueue", DISPATCH_QUEUE_SERIAL);
  });
  
  return queue;

}


@end
