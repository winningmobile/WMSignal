//
//  TSAttributes.m
//  Signal
//
//  Created by Frederic Jacobs on 22/08/15.
//  Copyright (c) 2015 Open Whisper Systems. All rights reserved.
//

#import "TSAttributes.h"

#import "TSAccountManager.h"
#import "TSStorageHeaders.h"

@implementation TSAttributes


+ (NSDictionary*)attributesFromStorage {
    return [self attributesWithSignalingKey:[TSStorageManager signalingKey]
                            serverAuthToken:[TSStorageManager serverAuthToken]];
}

+ (NSDictionary*)attributesWithSignalingKey:(NSString*)signalingKey
                            serverAuthToken:(NSString*)authToken

{
    return @{@"signalingKey"  : signalingKey,
             @"AuthKey"       : authToken,
             @"voice"         : @YES,
             @"registrationId": [NSString stringWithFormat:@"%i",[TSAccountManager getOrGenerateRegistrationId]]
             };
}

@end
