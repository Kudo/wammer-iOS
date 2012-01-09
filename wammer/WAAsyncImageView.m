//
//  WAAsyncImageView.m
//  wammer
//
//  Created by Evadne Wu on 12/13/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import "WAAsyncImageView.h"
#import "UIImage+IRAdditions.h"


@interface WAAsyncImageView ()

@property (nonatomic, readwrite, assign) void * lastImagePtr;

@end

@implementation WAAsyncImageView
@synthesize lastImagePtr;

- (void) setImage:(UIImage *)newImage {

	if (lastImagePtr == newImage)
		return;
  
  lastImagePtr = newImage;

  if (!newImage) {
  
    [super setImage:nil];
    return;
  
  }  

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^ {

    UIImage *decodedImage = [newImage irDecodedImage];
    dispatch_async(dispatch_get_main_queue(), ^{
    
      if (self.lastImagePtr != decodedImage)
				return;
    
      [super setImage:decodedImage];
      [self.delegate imageViewDidUpdate:self];
      
    });
  
  });

}

@end
