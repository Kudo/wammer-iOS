//
//  WAWebServiceOAuthViewController.m
//  wammer
//
//  Created by kchiu on 12/11/29.
//  Copyright (c) 2012年 Waveface. All rights reserved.
//

#import "WAOAuthViewController.h"
#import "WADefines.h"
#import "WARemoteInterface.h"

@interface WAOAuthViewController ()

@property (nonatomic, strong) NSURL *resultURL;

@end

@implementation WAOAuthViewController

- (void)viewDidLoad {

	[super viewDidLoad];

	__weak WAOAuthViewController *wSelf = self;
	self.navigationItem.leftBarButtonItem = (UIBarButtonItem *)WABackBarButtonItem([UIImage imageNamed:@"back"], @"", ^{
		[wSelf.navigationController popViewControllerAnimated:YES];
	});
	

	self.webView.delegate = self;

}

- (void)viewDidAppear:(BOOL)animated {

	// load request after view controller pushing animation finished
	[self.webView loadRequest:self.request];
	
}

- (void)viewDidDisappear:(BOOL)animated {

	// show alert view after view controller popping animation finished
	self.didCompleteBlock(self.resultURL);

}

- (void)dealloc {

	self.webView.delegate = nil;

}

#pragma mark - UIWebView delegates
- (void)webViewDidStartLoad:(UIWebView *)webView {
  self.title = NSLocalizedString(@"NAVI_TITLE_WEB_LOADING", @"Navigation bar title for web preview while loading");
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {

	NSURL *url = [request URL];
	if ([[url scheme] isEqualToString:@"waveface"] && [[url host] isEqualToString:@"x-callback-url"]) {
		self.resultURL = url;
		[self.navigationController popViewControllerAnimated:YES];
		return NO;
	}

	return YES;

}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
  
  self.title = @"";
  
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {

	if ([[error domain] isEqualToString:@"WebKitErrorDomain"] && [error code] == 102) {
		// dismissing view controller stops loading the web view
		return;
	}
	
	if ([[error domain] isEqualToString:NSURLErrorDomain] && [error code] == -999) {
		// dismissing view controller stops loading the web view
		return;
	}

	[self.navigationController popViewControllerAnimated:YES];

}

@end
