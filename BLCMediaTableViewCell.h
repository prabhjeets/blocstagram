//
//  BLCMediaTableViewCell.h
//  Blocstagram
//
//  Created by Prabhjeet Singh on 11/4/14.
//  Copyright (c) 2014 PJ. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BLCMedia;

@interface BLCMediaTableViewCell : UITableViewCell

@property (nonatomic, strong) BLCMedia *mediaItem;

+ (CGFloat)heightForMediaItem:(BLCMedia *)mediaItem width:(CGFloat)width;

@end
