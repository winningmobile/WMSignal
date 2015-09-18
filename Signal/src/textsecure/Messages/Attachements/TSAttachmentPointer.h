//
//  TSAttachementPointer.h
//  Signal
//
//  Created by Frederic Jacobs on 17/12/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "TSAttachment.h"

@interface TSAttachmentPointer : TSAttachment

- (instancetype)initWithIdentifier:(uint64_t)identifier
                               key:(NSData*)key
                       contentType:(NSString*)contentType
                             relay:(NSString*)relay NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithIdentifier:(uint64_t)identifier
                               key:(NSData*)key
                       contentType:(NSString*)contentType
                             relay:(NSString*)relay
                   avatarOfGroupId:(NSData*)avatarOfGroupId;

@property NSString *relay;
@property NSData *avatarOfGroupId;

@property (getter=isDownloading) BOOL downloading;
@property (getter=hasFailed)     BOOL failed;

@end
