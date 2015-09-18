//
//  TSGroupThread.h
//  TextSecureKit
//
//  Created by Frederic Jacobs on 16/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import "TSThread.h"
#import "TSGroupModel.h"

@interface TSGroupThread : TSThread
@property (nonatomic,strong) TSGroupModel* groupModel;
+ (instancetype)getOrCreateThreadWithGroupModel:(TSGroupModel *)groupModel transaction:(YapDatabaseReadWriteTransaction*)transaction;

+ (instancetype)threadWithGroupModel:(TSGroupModel *)groupModel transaction:(YapDatabaseReadTransaction*)transaction;
- (NSData*)groupId;
- (NSArray *)recipientsWithTransaction:(YapDatabaseReadTransaction*)transaction;

@end
