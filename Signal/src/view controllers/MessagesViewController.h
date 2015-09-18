//
//  MessagesViewController.h
//  Signal
//
//  Created by Dylan Bourgeois on 28/10/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import "JSQMessagesViewController.h"
#import "JSQMessages.h"
#import "TSGroupModel.h"
#import <MediaPlayer/MediaPlayer.h>
#import "APNavigationController.h"
#import <AVFoundation/AVFoundation.h>
@class TSThread;

@interface MessagesViewController : JSQMessagesViewController   <UIImagePickerControllerDelegate,
                                                                UINavigationControllerDelegate,
                                                                UITextViewDelegate,AVAudioRecorderDelegate,AVAudioPlayerDelegate, UIGestureRecognizerDelegate>


@property (nonatomic, retain) APNavigationController *navController;

@property (nonatomic,strong) MPMoviePlayerController* videoPlayer;
@property (nonatomic,strong) AVAudioPlayer* audioPlayer;
@property (nonatomic,strong) AVAudioRecorder* audioRecorder;

- (void)setupWithThread:(TSThread*)thread;
- (void)setupWithTSIdentifier:(NSString*)identifier;
- (void)setupWithTSGroup:(TSGroupModel*)model;

- (void)setComposeOnOpen:(BOOL)compose;

- (TSThread*)thread;
- (void)popKeyBoard;

@end
