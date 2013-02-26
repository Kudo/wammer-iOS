//
//  WAFirstUsePCAdvertisementViewController.m
//  wammer
//
//  Created by kchiu on 13/2/25.
//  Copyright (c) 2013年 Waveface. All rights reserved.
//

#import "WAFirstUsePCAdvertisementViewController.h"

static NSString * const kWASegueSendLinkToDone = @"WASegueSendLinkToDone";

@interface WAFirstUsePCAdvertisementViewController ()

@end

@implementation WAFirstUsePCAdvertisementViewController

- (void)viewDidLoad {

  [super viewDidLoad];
  
  [self localize];

  self.sendLinkButton.backgroundColor = [UIColor colorWithRed:0x76/255.0 green:0xaa/255.0 blue:0xcc/255.0 alpha:1.0];
  self.sendLinkButton.contentEdgeInsets = UIEdgeInsetsMake(10.0, 10.0, 10.0, 10.0);
  self.sendLinkButton.layer.cornerRadius = 20.0;
  [self.sendLinkButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  [self.sendLinkButton setTitleColor:[UIColor whiteColor] forState:UIControlStateDisabled];
  [self.sendLinkButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateHighlighted];

  __weak WAFirstUsePCAdvertisementViewController *wSelf = self;

  self.navigationItem.leftBarButtonItem = (UIBarButtonItem *)WABackBarButtonItem([UIImage imageNamed:@"back"], @"", ^{
    [wSelf.navigationController popViewControllerAnimated:YES];
  });
  
  UIBarButtonItem *nextButton = (UIBarButtonItem *)WABackBarButtonItem([UIImage imageNamed:@"forward"], @"", ^{
    [wSelf performSegueWithIdentifier:kWASegueSendLinkToDone sender:nil];
  });
  
  self.navigationItem.rightBarButtonItem = nextButton;

}

- (void)localize {
  
  self.title = NSLocalizedString(@"PC_ADVERTISEMENT_CONTROLLER_TITLE", @"Title of view controller advertising AOStream Windows");
  
}


@end
