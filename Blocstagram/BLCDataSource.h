//
//  BLCDataSource.h
//  Blocstagram
//
//  Created by Prabhjeet Singh on 11/3/14.
//  Copyright (c) 2014 PJ. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class BLCMedia;

typedef void (^BLCNewItemCompletionBlock)(NSError *error); //completion handler

@interface BLCDataSource : NSObject

@property (nonatomic, strong, readonly) NSArray *mediaItems;
@property (nonatomic, strong, readonly) NSString *accessToken;

+ (instancetype)sharedInstance;
+ (NSString *)instagramClientID;

- (void)deleteMediaItem:(BLCMedia *)item;

- (void)requestNewItemsWithCompletionHandler:(BLCNewItemCompletionBlock)completionHandler;

- (void)requestOldItemsWithCompletionHandler:(BLCNewItemCompletionBlock)completionHandler;

- (void)downloadImageForMediaItem:(BLCMedia *)mediaItem;

@end
