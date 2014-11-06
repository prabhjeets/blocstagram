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

@interface BLCDataSource : NSObject

@property (nonatomic, strong, readonly) NSArray *mediaItems;

+ (instancetype)sharedInstance;

- (void)deleteMediaItem:(BLCMedia *)item;

@end
