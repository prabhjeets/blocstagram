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
#import <UICKeyChainStore.h>
#import <AFNetworking/AFNetworking.h>

#define INSTAGRAM_CLIENT_ID "e95cf13d7f3b4e45b59a512e6ec2f909"

@interface BLCDataSource() {

    NSMutableArray *_mediaItems;//Required naming format for Key
}

@property (nonatomic, assign) BOOL isRefreshing;
@property (nonatomic, assign) BOOL isLoadingOlderItems;
@property (nonatomic, assign) BOOL thereAreNoMoreOlderMessages;

@property (nonatomic, strong) NSString *accessToken;
@property (nonatomic, strong) NSArray *mediaItems;

@property (nonatomic, strong) AFHTTPRequestOperationManager *instagramOperationManager;

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

- (instancetype) init {
    self = [super init];
    
    if (self) {
        NSURL *baseURL = [NSURL URLWithString:@"https://api.instagram.com/v1/"];
        self.instagramOperationManager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:baseURL];
        
        AFJSONResponseSerializer *jsonSerializer = [AFJSONResponseSerializer serializer];
        AFImageResponseSerializer *imageSerializer = [AFImageResponseSerializer serializer];
        imageSerializer.imageScale = 1.0;
        
        AFCompoundResponseSerializer *serializer = [AFCompoundResponseSerializer compoundSerializerWithResponseSerializers:@[jsonSerializer, imageSerializer]];
        self.instagramOperationManager.responseSerializer = serializer;
        
        self.accessToken = [UICKeyChainStore stringForKey:@"access token"];
        if (!self.accessToken) {
            [self registerForAccessTokenNotification];
        } else {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSString *fullPath = [self pathForFilename:NSStringFromSelector(@selector(mediaItems))];
                NSArray *storedMediaItems = [NSKeyedUnarchiver unarchiveObjectWithFile:fullPath];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (storedMediaItems.count > 0) {
                        NSMutableArray *mutableMediaItems = [storedMediaItems mutableCopy];
                        
                        [self willChangeValueForKey:@"mediaItems"];
                        self.mediaItems = mutableMediaItems;
                        [self didChangeValueForKey:@"mediaItems"];
                        
                        //The download image code was added by me(PJ) since this was never getting called
                        //and images were not appearing. Not sure if this is right but it works
                        for (BLCMedia *item in self.mediaItems) {
                            [self downloadImageForMediaItem:item];
                        }
                    } else {
                        [self populateDataWithParameters:nil completionHandler:nil];
                    }
                });
            });
        }
    }
    
    return self;
}

//Creates a string containing an absolute path to the users docs directory
- (NSString *)pathForFilename:(NSString *)filename {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths firstObject];
    NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:filename];
    return dataPath;
}

- (void)deleteMediaItem:(BLCMedia *)item {
    //deleting this way notifies observers of the change
    NSMutableArray *mutableArrayWithKVO = [self mutableArrayValueForKey:@"mediaItems"];
    [mutableArrayWithKVO removeObject:item];
}

- (void)requestNewItemsWithCompletionHandler:(BLCNewItemCompletionBlock)completionHandler {
    self.thereAreNoMoreOlderMessages = NO;
    if (!self.isRefreshing) {
        self.isRefreshing = YES;
        
        NSString *minID = [[self.mediaItems firstObject] idNumber];
        
        //If no images, then midID will be nil, set it to ""
        if (!minID) {
            minID = @"";
        }
        
        NSDictionary *parameters = @{@"min_id": minID};
        
        [self populateDataWithParameters:parameters completionHandler:^(NSError *error) {
            self.isRefreshing = NO;
            
            if (completionHandler) {
                completionHandler(error);
            }
        }];
    }
}

- (void)requestOldItemsWithCompletionHandler:(BLCNewItemCompletionBlock)completionHandler {
    if (!self.isLoadingOlderItems && self.thereAreNoMoreOlderMessages == NO) {
        self.isLoadingOlderItems = YES;
        
        NSString *maxID = [[self.mediaItems lastObject] idNumber];
        NSDictionary *parameters = @{@"max_id": maxID};
        
        [self populateDataWithParameters:parameters completionHandler:^(NSError *error) {
            self.isLoadingOlderItems = NO;
            
            if (completionHandler) {
                completionHandler(error);
            }

        }];
        
    }
}

- (void)registerForAccessTokenNotification {
    [[NSNotificationCenter defaultCenter] addObserverForName:BLCLoginViewControllerDidGetAccessTokenNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        self.accessToken = note.object;
        [UICKeyChainStore setString:self.accessToken forKey:@"access token"];
        
        [self populateDataWithParameters:nil completionHandler:nil];
    }];
}

- (void)populateDataWithParameters:(NSDictionary *)parameters completionHandler:(BLCNewItemCompletionBlock)completionHandler {
    if (self.accessToken) {
        NSMutableDictionary *mutableParameters = [@{@"access_token": self.accessToken} mutableCopy];
        
        [mutableParameters addEntriesFromDictionary:parameters];
        
        [self.instagramOperationManager GET:@"users/self/feed" parameters:mutableParameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
            if ([responseObject isKindOfClass:[NSDictionary class]]) {
                [self parseDataFromFeedDictionary:responseObject fromRequestWithParameters:parameters];
                
                if (completionHandler) {
                    completionHandler(nil);
                }
            }
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            if (completionHandler) {
                completionHandler(error);
            }
        }];
    }
}

- (void) parseDataFromFeedDictionary:(NSDictionary *) feedDictionary fromRequestWithParameters:(NSDictionary *)parameters {
    NSArray *mediaArray = feedDictionary[@"data"];
    
    NSMutableArray *tmpMediaItems = [NSMutableArray array];
    
    for (NSDictionary *mediaDictionary in mediaArray) {
        BLCMedia *mediaItem = [[BLCMedia alloc] initWithDictionary:mediaDictionary];
        
        if (mediaItem) {
            [tmpMediaItems addObject:mediaItem];
            //[self downloadImageForMediaItem:mediaItem]; //download images as they arrive
        }
    }
    
    NSMutableArray *mutableArrayWithKVO = [self mutableArrayValueForKey:@"mediaItems"];
    
    if (parameters[@"min_id"]) {
        NSRange rangeOfIndexes = NSMakeRange(0, tmpMediaItems.count);
        NSIndexSet *indexSetOfNewObjects = [NSIndexSet indexSetWithIndexesInRange:rangeOfIndexes];
        
        [mutableArrayWithKVO insertObjects:tmpMediaItems atIndexes:indexSetOfNewObjects];
    } else if (parameters[@"max_id"]) {
        if (tmpMediaItems.count == 0) {
            self.thereAreNoMoreOlderMessages = YES;
        }
        [mutableArrayWithKVO addObjectsFromArray:tmpMediaItems];
    } else {
        [self willChangeValueForKey:@"mediaItems"];
        self.mediaItems = tmpMediaItems;
        [self didChangeValueForKey:@"mediaItems"];
    }
    
    if (tmpMediaItems.count > 0) {
        //Write changes to disc
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSUInteger numberOfItemsToSave = MIN(self.mediaItems.count, 50);
            NSArray *mediaItemsToSave = [self.mediaItems subarrayWithRange:NSMakeRange(0, numberOfItemsToSave)];
            
            NSString *fullPath = [self pathForFilename:NSStringFromSelector(@selector(mediaItems))];
            NSData *mediaItemData = [NSKeyedArchiver archivedDataWithRootObject:mediaItemsToSave];
            
            NSError *dataError;
            BOOL wroteSuccessfully = [mediaItemData writeToFile:fullPath options:NSDataWritingAtomic | NSDataWritingFileProtectionCompleteUnlessOpen error:&dataError];
            
            if (!wroteSuccessfully) {
                NSLog(@"Couldn't write file: %@", dataError);
            }
        });
    }
    
}

- (void)downloadImageForMediaItem:(BLCMedia *)mediaItem {
    if (mediaItem.mediaURL && !mediaItem.image) {
        mediaItem.downloadState = BLCMediaDownloadStateDownloadInProgress;
        
        [self.instagramOperationManager GET:mediaItem.mediaURL.absoluteString parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
            if ([responseObject isKindOfClass:[UIImage class]]) {
                mediaItem.image = responseObject;
                mediaItem.downloadState = BLCMediaDownloadStateHasImage;
                NSMutableArray *mutableArrayWithKVO = [self mutableArrayValueForKey:@"mediaItems"];
                NSUInteger index = [mutableArrayWithKVO indexOfObject:mediaItem];
                [mutableArrayWithKVO replaceObjectAtIndex:index withObject:mediaItem];
            } else {
                mediaItem.downloadState = BLCMediaDownloadStateNonRecoverableError;
            }
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            NSLog(@"Error downloading image: %@", error);
            
            mediaItem.downloadState = BLCMediaDownloadStateNonRecoverableError;
            
            if ([error.domain isEqualToString:NSURLErrorDomain]) {
                //Network error
                if (error.code == NSURLErrorTimedOut ||
                    error.code == NSURLErrorCancelled ||
                    error.code == NSURLErrorCannotConnectToHost ||
                    error.code == NSURLErrorNetworkConnectionLost ||
                    error.code == NSURLErrorNotConnectedToInternet ||
                    error.code == kCFURLErrorInternationalRoamingOff ||
                    error.code == kCFURLErrorCallIsActive ||
                    error.code == kCFURLErrorDataNotAllowed ||
                    error.code == kCFURLErrorRequestBodyStreamExhausted) {
                    
                    mediaItem.downloadState = BLCMediaDownloadStateNeedsImage;
                }
            }
        }];
    }
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
