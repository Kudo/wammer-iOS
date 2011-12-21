//
//  WAArticleController_PlaintextCell.h
//  wammer
//
//  Created by Evadne Wu on 12/19/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface WAArticleTextStackCell : UITableViewCell

+ (id) cellFromNib;

- (CGSize) sizeThatFits:(CGSize)size;
@property (nonatomic, readwrite, copy) CGSize (^onSizeThatFits)(CGSize proposedSize, CGSize superAnswer);

@end
