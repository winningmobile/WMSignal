//
//  TSRequest.m
//  TextSecureiOS
//
//  Created by Frederic Jacobs on 9/27/13.
//  Copyright (c) 2013 Open Whisper Systems. All rights reserved.
//

#import "TSRequest.h"

#import "TSStorageManager+keyingMaterial.h"
#import "TSConstants.h"

@implementation TSRequest

- (id)initWithURL:(NSURL *)URL{
    self = [super initWithURL:URL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:textSecureHTTPTimeOut];
    self.parameters = [NSMutableDictionary dictionary];
  
    return self;
}

- (id)init{
    [NSException raise:NSInternalInconsistencyException
                format:@"You must use the initWithURL: method"];
    return nil;
}

- (id)initWithURL:(NSURL *)URL cachePolicy:(NSURLRequestCachePolicy)cachePolicy timeoutInterval:(NSTimeInterval)timeoutInterval{
    [NSException raise:NSInternalInconsistencyException
                format:@"You must use the initWithURL method"];
    return nil;
}

- (void) makeAuthenticatedRequest{
    [self.parameters addEntriesFromDictionary:@{@"Authorization":[TSStorageManager serverAuthToken]}];
}

- (BOOL) usingExternalServer {
  return NO;
}
@end
