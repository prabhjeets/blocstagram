//
//  BLCMediaFullScreenViewController.h
//  Blocstagram
//
//  Created by Prabhjeet Singh on 11/11/14.
//  Copyright (c) 2014 PJ. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BLCMedia;

@interface BLCMediaFullScreenViewController : UIViewController

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *imageView;

- (instancetype)initWithMedia:(BLCMedia *)media;

- (void)centerScrollView;

@end
