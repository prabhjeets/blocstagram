//
//  BLCMediaFullScreenAnimator.h
//  Blocstagram
//
//  Created by Prabhjeet Singh on 11/12/14.
//  Copyright (c) 2014 PJ. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface BLCMediaFullScreenAnimator : NSObject <UIViewControllerAnimatedTransitioning>

@property (nonatomic, assign) BOOL presenting;
@property (nonatomic, weak) UIImageView *cellImageView;

@end
