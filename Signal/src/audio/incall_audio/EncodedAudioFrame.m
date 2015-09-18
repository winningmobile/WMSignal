#import "EncodedAudioFrame.h"
#import "Constraints.h"

@implementation EncodedAudioFrame

+(EncodedAudioFrame*) encodedAudioFrameWithData:(NSData*)audioData {
    require(audioData != nil);
    EncodedAudioFrame* frame = [EncodedAudioFrame new];
    frame->audioData = audioData;
    return frame;
}
+(EncodedAudioFrame*) encodedAudioFrameWithoutData {
    return [EncodedAudioFrame new];
}

-(bool) isMissingAudioData {
    return audioData == nil;
}
-(NSData*) tryGetAudioData {
    return audioData;
}

@end
