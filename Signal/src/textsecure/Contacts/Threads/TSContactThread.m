//
//  TSContactThread.m
//  TextSecureKit
//
//  Created by Frederic Jacobs on 16/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import "TSContactThread.h"

#import "Environment.h"
#import "IncomingPushMessageSignal.pb.h"
#import "ContactsManager.h"

#define TSContactThreadPrefix @"c"

@implementation TSContactThread

- (instancetype)initWithContactId:(NSString*)contactId{
    
    NSString *uniqueIdentifier = [[self class] threadIdFromContactId:contactId];
    
    self = [super initWithUniqueId:uniqueIdentifier];
    
    return self;
}

+ (instancetype)getOrCreateThreadWithContactId:(NSString*)contactId transaction:(YapDatabaseReadWriteTransaction*)transaction pushSignal:(IncomingPushMessageSignal*)pushSignal{
    TSRecipient *recipient = [TSRecipient recipientWithTextSecureIdentifier:contactId withTransaction:transaction];
    
    if (!recipient) {
        NSString *relay = pushSignal.hasRelay && ![pushSignal.relay isEqualToString:@""]?pushSignal.relay:nil;
        recipient = [[TSRecipient alloc] initWithTextSecureIdentifier:contactId relay:relay];
        [recipient saveWithTransaction:transaction];
    }
    
    return [self getOrCreateThreadWithContactId:contactId transaction:transaction];
}

+ (instancetype)getOrCreateThreadWithContactId:(NSString*)contactId transaction:(YapDatabaseReadWriteTransaction*)transaction {
    
    TSContactThread *thread = [self fetchObjectWithUniqueID:[self threadIdFromContactId:contactId] transaction:transaction];
    
    if (!thread) {
        thread = [[TSContactThread alloc] initWithContactId:contactId];
        [thread saveWithTransaction:transaction];
    }
    
    return thread;
}

- (NSString*)contactIdentifier{
    return [[self class]contactIdFromThreadId:self.uniqueId];
}

- (BOOL)isGroupThread{
    return false;
}

- (NSString*)name{
    NSString *contactId = [self contactIdentifier];
    NSString *name      = [[Environment getCurrent].contactsManager nameStringForPhoneIdentifier:contactId];
    
    if (!name) {
        name = contactId;
    }
    
    return name;
}

- (UIImage*)image{
    UIImage *image = [[Environment getCurrent].contactsManager imageForPhoneIdentifier:self.contactIdentifier];
    return image;
}

+ (NSString*)threadIdFromContactId:(NSString*)contactId{
    return [TSContactThreadPrefix stringByAppendingString:contactId];
}

+ (NSString*)contactIdFromThreadId:(NSString*)threadId{
    return [threadId substringWithRange:NSMakeRange(1, threadId.length-1)];
}

- (TSRecipient *)recipientWithTransaction:(YapDatabaseReadTransaction*)transaction{
    TSRecipient *recipient = [TSRecipient recipientWithTextSecureIdentifier:self.contactIdentifier withTransaction:transaction];
    if (!recipient){
        recipient = [[TSRecipient alloc] initWithTextSecureIdentifier:self.contactIdentifier relay:nil];
    }
    return recipient;
}

@end
