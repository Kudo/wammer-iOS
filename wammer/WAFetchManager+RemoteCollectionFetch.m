//
//  WAFetchManager+RemoteCollectionFetch.m
//  wammer
//
//  Created by kchiu on 12/12/27.
//  Copyright (c) 2012年 Waveface. All rights reserved.
//

#import "WAFetchManager+RemoteCollectionFetch.h"
#import "Foundation+IRAdditions.h"
#import "WARemoteInterface.h"
#import "WACollection.h"
#import "WADataStore.h"
#import "WADefines.h"

@implementation WAFetchManager (RemoteCollectionFetch)

- (IRAsyncOperation *)remoteCollectionFetchOperationPrototype {

  __weak WAFetchManager *wSelf = self;
  
  IRAsyncOperation *operation = [IRAsyncOperation operationWithWorker:^(IRAsyncOperationCallback callback) {
  
    if (![wSelf canPerformCollectionFetch]) {
      callback(nil);
      return;
    }

    [wSelf beginPostponingFetch];

    WARemoteInterface *ri = [WARemoteInterface sharedInterface];
    [ri.engine fireAPIRequestNamed:@"collections/getAll" withArguments:nil options:nil validator:WARemoteInterfaceGenericNoErrorValidator() successHandler:^(NSDictionary *response, IRWebAPIRequestContext *context) {

      WADataStore *ds = [WADataStore defaultStore];
      NSArray *collections = [response objectForKey:@"collections"];
      for (NSDictionary *collectionResp in collections) {

        [wSelf.collectionInsertOperationQueue addOperation:[NSBlockOperation blockOperationWithBlock:^{
          
          [ds performBlock:^{
          
            NSManagedObjectContext *moc = [ds autoUpdatingMOC];
            [WACollection insertOrUpdateObjectsUsingContext:moc
                                         withRemoteResponse:@[collectionResp]
                                               usingMapping:nil
                                                    options:IRManagedObjectOptionIndividualOperations];
            
            NSError *error = nil;
            if (![moc save:&error])
              NSLog(@"Error on saving collection: %@", error);
          } waitUntilDone:YES];
          
        }]];
        
      }

      NSOperation *tailOp = [NSBlockOperation blockOperationWithBlock:^{
        
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kWAAllCollectionsFetchOnce];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
      }];
      
      for (NSOperation *op in wSelf.collectionInsertOperationQueue.operations) {
        [tailOp addDependency:op];
      }
      [wSelf.collectionInsertOperationQueue addOperation:tailOp];
  
      [wSelf endPostponingFetch];

    } failureHandler:WARemoteInterfaceGenericFailureHandler(^(NSError *error) {

      NSLog(@"Unable to fetch collection, error:%@", error);
      [wSelf endPostponingFetch];

    })];

    callback(nil);

  } trampoline:^(IRAsyncOperationInvoker callback) {

    NSCParameterAssert(![NSThread isMainThread]);
    callback();

  } callback:^(id results) {

    // NO OP

  } callbackTrampoline:^(IRAsyncOperationInvoker callback) {

    NSCParameterAssert(![NSThread isMainThread]);
    callback();

  }];

  return operation;

}

- (BOOL)canPerformCollectionFetch {

  if (![WARemoteInterface sharedInterface].userToken) {
    return NO;
  }
  
  if ([self.collectionInsertOperationQueue operationCount])
    return NO;//insert or merge ongoing
  
  if (![[NSUserDefaults standardUserDefaults] boolForKey:kWAAllCollectionsFetchOnce]) {
    return NO;
  }
  
  return YES;

}

@end
