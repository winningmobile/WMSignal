#import "Constraints.h"
#import "FutureUtil.h"

@implementation TOCCancelToken (FutureUtil)

-(void) whenCancelledTerminate:(id<Terminable>)terminable {
    require(terminable != nil);
    [self whenCancelledDo:^{ [terminable terminate]; }];
}

@end

@implementation TOCFuture (FutureUtil)

+(TOCUntilOperation) operationTry:(TOCUntilOperation)operation {
    require(operation != nil);
    return ^(TOCCancelToken* until) {
        @try {
            return operation(until);
        } @catch (id ex) {
            return [TOCFuture futureWithFailure:ex];
        }
    };
}

-(TOCFuture*) thenValue:(id)value {
    return [self then:^(id _) { return value; }];
}

-(TOCFuture*) finallyTry:(TOCFutureFinallyContinuation)completionContinuation {
    require(completionContinuation != nil);
    
    return [self finally:^id(TOCFuture* completed){
        @try {
            return completionContinuation(completed);
        } @catch (id ex) {
            return [TOCFuture futureWithFailure:ex];
        }
    }];
}

-(TOCFuture*) thenTry:(TOCFutureThenContinuation)resultContinuation {
    require(resultContinuation != nil);

    return [self then:^id(id result){
        @try {
            return resultContinuation(result);
        } @catch (id ex) {
            return [TOCFuture futureWithFailure:ex];
        }
    }];
}

-(TOCFuture*) catchTry:(TOCFutureCatchContinuation)failureContinuation {
    require(failureContinuation != nil);
    
    return [self catch:^id(id failure){
        @try {
            return failureContinuation(failure);
        } @catch (id ex) {
            return [TOCFuture futureWithFailure:ex];
        }
    }];
}

+(TOCFuture*) retry:(TOCUntilOperation)operation
         upToNTimes:(NSUInteger)maxTryCount
    withBaseTimeout:(NSTimeInterval)baseTimeout
     andRetryFactor:(NSTimeInterval)timeoutRetryFactor
     untilCancelled:(TOCCancelToken*)untilCancelledToken {
    
    require(operation != nil);
    require(maxTryCount >= 0);
    require(baseTimeout >= 0);
    require(timeoutRetryFactor >= 0);
    
    if (maxTryCount == 0) return TOCFuture.futureWithTimeoutFailure;
    
    TOCFuture* futureResult = [TOCFuture futureFromUntilOperation:operation
                                             withOperationTimeout:baseTimeout
                                                            until:untilCancelledToken];
    
    return [futureResult catchTry:^(id error) {
        bool operationCancelled = untilCancelledToken.isAlreadyCancelled;
        bool operationDidNotTimeout = !futureResult.hasFailedWithTimeout;
        if (operationCancelled || operationDidNotTimeout) {
            return [TOCFuture futureWithFailure:error];
        }
        
        return [self retry:operation
                upToNTimes:maxTryCount - 1
           withBaseTimeout:baseTimeout * timeoutRetryFactor
            andRetryFactor:timeoutRetryFactor
            untilCancelled:untilCancelledToken];
    }];
}

@end
