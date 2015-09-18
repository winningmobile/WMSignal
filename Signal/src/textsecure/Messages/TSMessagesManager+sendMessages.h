//
//  TSMessagesManager+sendMessages.h
//  TextSecureKit
//
//  Created by Frederic Jacobs on 17/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import "TSMessagesManager.h"

@interface TSMessagesManager (sendMessages)

- (void)sendMessage:(TSOutgoingMessage*)message inThread:(TSThread*)thread;

@end
