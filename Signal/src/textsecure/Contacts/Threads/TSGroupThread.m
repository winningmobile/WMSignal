//
//  TSGroupThread.m
//  TextSecureKit
//
//  Created by Frederic Jacobs on 16/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import "TSGroupThread.h"
#import "TSRecipient.h"
#import "NSData+Base64.h"

@implementation TSGroupThread

#define TSGroupThreadPrefix @"g"

- (instancetype)initWithGroupModel:(TSGroupModel *)groupModel{
    
    NSString *uniqueIdentifier = [[self class] threadIdFromGroupId:groupModel.groupId];
    
    self = [super initWithUniqueId:uniqueIdentifier];
    _groupModel = groupModel;
    return self;
}


+ (instancetype)threadWithGroupModel:(TSGroupModel *)groupModel transaction:(YapDatabaseReadTransaction*)transaction {
   return  [self fetchObjectWithUniqueID:[self threadIdFromGroupId:groupModel.groupId] transaction:transaction];
}

+ (instancetype)getOrCreateThreadWithGroupModel:(TSGroupModel *)groupModel transaction:(YapDatabaseReadWriteTransaction*)transaction{
    TSGroupThread *thread = [self fetchObjectWithUniqueID:[self threadIdFromGroupId:groupModel.groupId] transaction:transaction];

    if (!thread) {
        thread = [[TSGroupThread alloc] initWithGroupModel:groupModel];
        [thread saveWithTransaction:transaction];
    }
    return thread;
}

- (BOOL)isGroupThread{
    return true;
}

- (NSData *)groupId{
    return [[self class] groupIdFromThreadId:self.uniqueId];
}

- (NSString*)name{
    return self.groupModel.groupName;
}

+ (NSString*)threadIdFromGroupId:(NSData*)groupId{
    return [TSGroupThreadPrefix stringByAppendingString:[groupId base64EncodedString]];
}

+ (NSData*)groupIdFromThreadId:(NSString*)threadId{
    return [NSData dataFromBase64String:[threadId substringWithRange:NSMakeRange(1, threadId.length-1)]];
}

- (NSArray *)recipientsWithTransaction:(YapDatabaseReadTransaction*)transaction{
    NSMutableArray *recipients = [[NSMutableArray alloc] init];
    
    for(NSString *recipientId in _groupModel.groupMemberIds) {
        TSRecipient *recipient = [TSRecipient recipientWithTextSecureIdentifier:recipientId withTransaction:transaction];
        if (!recipient){
            recipient = [[TSRecipient alloc] initWithTextSecureIdentifier:recipientId relay:nil];
        }
        [recipients addObject:recipient];
    }
    return recipients;
}

@end
