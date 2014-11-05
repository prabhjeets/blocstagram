//
//  BLCDataSource.h
//  Blocstagram
//
//  Created by Prabhjeet Singh on 11/3/14.
//  Copyright (c) 2014 PJ. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface BLCDataSource : NSObject

@property (nonatomic, strong) NSArray *mediaItems;

+ (instancetype)sharedInstance;

@end
