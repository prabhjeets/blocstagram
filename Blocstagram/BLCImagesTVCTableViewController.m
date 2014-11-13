//
//  BLCImagesTVCTableViewController.m
//  Blocstagram
//
//  Created by Prabhjeet Singh on 11/2/14.
//  Copyright (c) 2014 PJ. All rights reserved.
//

#import "BLCImagesTVCTableViewController.h"
#import "BLCDataSource.h"
#import "BLCUser.h"
#import "BLCMedia.h"
#import "BLCComment.h"
#import "BLCMediaTableViewCell.h"
#import "BLCMediaFullScreenViewController.h"
#import "BLCMediaFullScreenAnimator.h"

@interface BLCImagesTVCTableViewController () <BLCMediaTableViewCellDelegate, UIViewControllerTransitioningDelegate>

@property (nonatomic, weak) UIImageView *lastTappedImageView;

@end

@implementation BLCImagesTVCTableViewController

- (void)dealloc {
    //Remove observervation
    [[BLCDataSource sharedInstance] removeObserver:self forKeyPath:@"mediaItems"];
}

- (id)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    
    if (self) {
    
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //Register KVO - Add controller as observer of Datasource for key mediaItems
    [[BLCDataSource sharedInstance] addObserver:self forKeyPath:@"mediaItems" options:0 context:nil];
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshControlDidFire:) forControlEvents:UIControlEventValueChanged];
    
    
    [self.tableView registerClass:[BLCMediaTableViewCell class] forCellReuseIdentifier:@"mediaCell"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)refreshControlDidFire:(UIRefreshControl *)sender {
    [[BLCDataSource sharedInstance] requestNewItemsWithCompletionHandler:^(NSError *error) {
        [sender endRefreshing];
    }];
}

- (void)infiniteScrollIfNecessary {
    NSIndexPath *bottomIndexPath = [[self.tableView indexPathsForVisibleRows] lastObject];
    
    if (bottomIndexPath && bottomIndexPath.row == [BLCDataSource sharedInstance].mediaItems.count - 1) {
    //if (bottomIndexPath) {
        [[BLCDataSource sharedInstance] requestOldItemsWithCompletionHandler:nil];
    }
}

- (void) scrollViewDidScroll:(UIScrollView *)scrollView {
    //[self infiniteScrollIfNecessary];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self infiniteScrollIfNecessary];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [BLCDataSource sharedInstance].mediaItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    BLCMediaTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"mediaCell" forIndexPath:indexPath];
    cell.delegate = self;
    cell.mediaItem = [BLCDataSource sharedInstance].mediaItems[indexPath.row];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    BLCMedia *item = [BLCDataSource sharedInstance].mediaItems[indexPath.row];
    
    return [BLCMediaTableViewCell heightForMediaItem:item width:CGRectGetWidth(self.view.frame)];
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

//All Key-Value observation notifications are sent to this method
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == [BLCDataSource sharedInstance] && [keyPath isEqualToString:@"mediaItems"]) {
        int kindOfChange = [change[NSKeyValueChangeKindKey] intValue];
        
        if (kindOfChange == NSKeyValueChangeSetting) {
            //entire object replaced, reload the data
            [self.tableView reloadData];
        } else if (kindOfChange == NSKeyValueChangeInsertion || kindOfChange == NSKeyValueChangeRemoval || kindOfChange == NSKeyValueChangeReplacement) {
            //incremental change
            
            //get list of indexes that changed
            NSIndexSet *indexSetOfChanges = change[NSKeyValueChangeIndexesKey];
            
            //convert this to an array of index paths which is what tableview animation methods require
            NSMutableArray *indexPathsThatChanged = [NSMutableArray array];
            [indexSetOfChanges enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
                NSIndexPath *newIndexPath = [NSIndexPath indexPathForRow:idx inSection:0];
                [indexPathsThatChanged addObject:newIndexPath];
            }];
            
            //Call begin updates to tell table view of changes
            [self.tableView beginUpdates];
            
            if (kindOfChange == NSKeyValueChangeInsertion) {
                [self.tableView insertRowsAtIndexPaths:indexPathsThatChanged withRowAnimation:UITableViewRowAnimationAutomatic];
            } else if (kindOfChange == NSKeyValueChangeRemoval) {
                [self.tableView deleteRowsAtIndexPaths:indexPathsThatChanged withRowAnimation:UITableViewRowAnimationAutomatic];
            } else if (kindOfChange == NSKeyValueChangeReplacement) {
                [self.tableView reloadRowsAtIndexPaths:indexPathsThatChanged withRowAnimation:UITableViewRowAnimationAutomatic];
            }
            
            [self.tableView endUpdates];
        }
    }
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        BLCMedia *item = [BLCDataSource sharedInstance].mediaItems[indexPath.row];
        
        [[BLCDataSource sharedInstance] deleteMediaItem:item];
        
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    BLCMedia *mediaItem = [BLCDataSource sharedInstance].mediaItems[indexPath.row];
    if (mediaItem.downloadState == BLCMediaDownloadStateNeedsImage) {
        [[BLCDataSource sharedInstance] downloadImageForMediaItem:mediaItem];
    }
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {

    BLCMedia *item = [BLCDataSource sharedInstance].mediaItems[indexPath.row];
                      
    if (item.image) {
        return 350;
    } else {
        return 150;
    }
}

#pragma mark - BLCMediaTableViewCellDelegate

- (void)cell:(BLCMediaTableViewCell *)cell didTapImageView:(UIImageView *)imageView {
    
    self.lastTappedImageView = imageView;
    
    BLCMediaFullScreenViewController *fullScreenVC = [[BLCMediaFullScreenViewController alloc] initWithMedia:cell.mediaItem];
    
    fullScreenVC.transitioningDelegate = self;
    fullScreenVC.modalPresentationStyle = UIModalPresentationCustom;
    
    [self presentViewController:fullScreenVC animated:YES completion:nil];
}

- (void)cell:(BLCMediaTableViewCell *)cell didLongPressImageView:(UIImageView *)imageView {
    NSMutableArray *itemsToShare = [NSMutableArray array];
    
    if (cell.mediaItem.caption.length > 0) {
        [itemsToShare addObject:cell.mediaItem.caption];
    }
    
    if (cell.mediaItem.image) {
        [itemsToShare addObject:cell.mediaItem.image];
    }
    
    if (itemsToShare.count > 0) {
        UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:itemsToShare applicationActivities:nil];
        [self presentViewController:activityVC animated:YES completion:nil];
    }
}

#pragma mark - UIViewControllerTransitioningDelegate

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source {
    BLCMediaFullScreenAnimator *animator = [BLCMediaFullScreenAnimator new];
    animator.presenting = YES;
    animator.cellImageView = self.lastTappedImageView;
    return animator;
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed {
    BLCMediaFullScreenAnimator *animator = [BLCMediaFullScreenAnimator new];
    animator.cellImageView = self.lastTappedImageView;
    return animator;
}
@end
