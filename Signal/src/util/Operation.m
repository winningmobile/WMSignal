#import "Util.h"

@implementation Operation

+(Operation*) operation:(Action)block {
    require(block != NULL);
    Operation* a = [Operation new];
    a->_callback = block;
    return a;
}

+(void) asyncRun:(Action)action
        onThread:(NSThread*)thread {
    
    require(action != nil);
    require(thread != nil);
    
    [[Operation operation:action] performOnThread:thread];
}

+(void) asyncRunAndWaitUntilDone:(Action)action
                        onThread:(NSThread*)thread {
    
    require(action != nil);
    require(thread != nil);
    
    [[Operation operation:action] performOnThreadAndWaitUntilDone:thread];
}

+(void) asyncRunOnNewThread:(Action)action {
    require(action != nil);
    [[Operation operation:action] performOnNewThread];
}

-(SEL) selectorToRun {
    return @selector(run);
}

-(void) performOnThread:(NSThread*)thread {
    require(thread != nil);
    [self performSelector:@selector(run) onThread:thread withObject:nil waitUntilDone:thread == NSThread.currentThread];
}

-(void) performOnThreadAndWaitUntilDone:(NSThread*)thread {
    require(thread != nil);
    [self performSelector:@selector(run) onThread:thread withObject:nil waitUntilDone:true];
}

-(void) performOnNewThread {
    [NSThread detachNewThreadSelector:[self selectorToRun] toTarget:self withObject:nil];
}

-(void) run {
    _callback();
}

@end
