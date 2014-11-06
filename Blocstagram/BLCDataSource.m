//
//  BLCDataSource.m
//  Blocstagram
//
//  Created by Prabhjeet Singh on 11/3/14.
//  Copyright (c) 2014 PJ. All rights reserved.
//

#import "BLCDataSource.h"
#import "BLCUser.h"
#import "BLCMedia.h"
#import "BLCComment.h"
#import "BLCLoginViewController.h"

#define INSTAGRAM_CLIENT_ID "e95cf13d7f3b4e45b59a512e6ec2f909"

@interface BLCDataSource() {

    NSMutableArray *_mediaItems;//Required naming format for Key
}

@property (nonatomic, assign) BOOL isRefreshing;
@property (nonatomic, assign) BOOL isLoadingOlderItems;

@property (nonatomic, strong) NSString *accessToken;

@end



@implementation BLCDataSource

+ (instancetype)sharedInstance {
    //this variable stores the completion status of the dispatch_once task
    static dispatch_once_t once;
    //this variable holds the instance once it is created
    static id sharedInstance;
    //this function takes a block of code and runs only once
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}

- (void)deleteMediaItem:(BLCMedia *)item {
    //deleting this way notifies observers of the change
    NSMutableArray *mutableArrayWithKVO = [self mutableArrayValueForKey:@"mediaItems"];
    [mutableArrayWithKVO removeObject:item];
}

- (void)requestNewItemsWithCompletionHandler:(BLCNewItemCompletionBlock)completionHandler {
    if (!self.isRefreshing) {
        self.isRefreshing = YES;
        
        
        self.isRefreshing = NO;
        if (completionHandler) {
            completionHandler(nil);
        }
    }
}

- (void)requestOldItemsWithCompletionHandler:(BLCNewItemCompletionBlock)completionHandler {
    if (!self.isLoadingOlderItems) {
        self.isLoadingOlderItems = YES;
        
        
        self.isLoadingOlderItems = NO;

        if (completionHandler) {
            completionHandler(nil);
        }
    }
}

- (instancetype) init {
    self = [super init];
    
    if (self) {
        [self registerForAccessTokenNotification];
    }
    
    return self;
}

- (void)registerForAccessTokenNotification {
    [[NSNotificationCenter defaultCenter] addObserverForName:BLCLoginViewControllerDidGetAccessTokenNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        self.accessToken = note.object;
        
        [self populateDataWithParameters:nil];
    }];
}

- (void)populateDataWithParameters:(NSDictionary *)parameters {
    if (self.accessToken) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            NSMutableString *urlString = [NSMutableString stringWithFormat:@"https://api.instagram.com/v1/users/self/feed?access_token=%@", self.accessToken];
            
            for (NSString *parameterName in parameters) {
                [urlString appendFormat:@"&%@=%@", parameterName, parameters[parameterName]];
            }
            
            NSURL *url = [NSURL URLWithString:urlString];
            
            if (url) {
                NSURLRequest *request = [NSURLRequest requestWithURL:url];
                
                NSURLResponse *response;
                NSError *webError;
                NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&webError];
                
                NSError *jsonError;
                NSDictionary *feedDictionary = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&jsonError];
                
                if (feedDictionary) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self parseDataFromFeedDictionary:feedDictionary fromRequestWithParameters:parameters];
                    });
                }
            }
        });
    }
}

- (void) parseDataFromFeedDictionary:(NSDictionary *) feedDictionary fromRequestWithParameters:(NSDictionary *)parameters {
    NSLog(@"%@", feedDictionary);
}

#pragma mark - Key/Value Observing

- (NSUInteger)countOfMediaItems {
    return self.mediaItems.count;
}

- (id)objectInMediaItemsAtIndex:(NSUInteger)index {
    return [self.mediaItems objectAtIndex:index];
}

- (NSArray *)mediaItemsAtIndexes:(NSIndexSet *)indexes {
    return [self.mediaItems objectsAtIndexes:indexes];
}


- (void)insertObject:(BLCMedia *)object inMediaItemsAtIndex:(NSUInteger)index {
    [_mediaItems insertObject:object atIndex:index];
}

- (void)removeObjectFromMediaItemsAtIndex:(NSUInteger)index {
    [_mediaItems removeObjectAtIndex:index];
}

- (void)replaceObjectInMediaItemsAtIndex:(NSUInteger)index withObject:(id)object {
    [_mediaItems replaceObjectAtIndex:index withObject:object];
}

+ (NSString *)instagramClientID {
    return @INSTAGRAM_CLIENT_ID;
}

@end
