//
//  TSAccountManagement.m
//  TextSecureKit
//
//  Created by Frederic Jacobs on 27/10/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import "Constraints.h"
#import "NSData+Base64.h"
#import "NSData+hexString.h"
#import "NSData+ows_StripToken.h"
#import "NSURLSessionDataTask+StatusCode.h"

#import "SecurityUtils.h"
#import "TSNetworkManager.h"
#import "TSAccountManager.h"
#import "TSSocketManager.h"
#import "TSStorageManager+keyingMaterial.h"
#import "TSPreKeyManager.h"

@interface TSAccountManager ()

@property (nonatomic, retain) NSString *phoneNumberAwaitingVerification;

@end

@implementation TSAccountManager

+ (BOOL)isRegistered {
    return [[TSStorageManager sharedManager] boolForKey:TSStorageIsRegistered inCollection:TSStorageInternalSettingsCollection];
}

+ (void)setRegistered:(BOOL)registered{
    [[TSStorageManager sharedManager] setObject:registered?@YES:@NO forKey:TSStorageIsRegistered inCollection:TSStorageInternalSettingsCollection];
}

+ (NSString *)registeredNumber {
    YapDatabaseConnection *dbConn = [[TSStorageManager sharedManager] newDatabaseConnection];
    __block NSString *phoneNumber;
    
    [dbConn readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        phoneNumber  = [transaction objectForKey:TSStorageRegisteredNumberKey inCollection:TSStorageUserAccountCollection];
    }];
    
    return phoneNumber;
}

+ (uint32_t)getOrGenerateRegistrationId {
    YapDatabaseConnection *dbConn = [[TSStorageManager sharedManager] newDatabaseConnection];
    __block uint32_t registrationID = 0;
    
    [dbConn readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        registrationID  = [[transaction objectForKey:TSStorageLocalRegistrationId inCollection:TSStorageUserAccountCollection] unsignedIntValue];
    }];
    
    if (registrationID == 0) {
        registrationID = (uint32_t)arc4random_uniform(16380)+1;
    
        [dbConn readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
            [transaction setObject:[NSNumber numberWithUnsignedInteger:registrationID]
                            forKey:TSStorageLocalRegistrationId
                      inCollection:TSStorageUserAccountCollection];
        }];
    }
    
    return registrationID;
}

+ (void)registerForPushNotifications:(NSData *)pushToken voipToken:(NSData*)voipToken success:(successCompletionBlock)success failure:(failedVerificationBlock)failureBlock{
    
    NSString *pushTokenString = [pushToken ows_tripToken];
    NSString *voipTokenString = [voipToken ows_tripToken];

    [[TSNetworkManager sharedManager] queueAuthenticatedRequest:[[TSRegisterForPushRequest alloc] initWithPushIdentifier:pushTokenString voipIdentifier:voipTokenString] success:^(NSURLSessionDataTask *task, id responseObject) {
        success();
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSLog(@"NSError: %@", error.debugDescription);
        
        TSRegistrationFailure failureType = kTSRegistrationFailureNetwork;
        switch ([task statusCode]) {
            case 401:
                failureType = kTSRegistrationFailureAuthentication;
                break;
            case 415:
                failureType = kTSRegistrationFailureRequest;
                break;
            default:
                break;
        }
        
        failureBlock([self errorForRegistrationFailure:failureType HTTPStatusCode:[task statusCode]]);
    }];
}

+ (void)registerWithRedPhoneToken:(NSString*)tsToken
                        pushToken:(NSData*)pushToken
                        voipToken:(NSData*)voipToken
                          success:(successCompletionBlock)successBlock
                          failure:(failedVerificationBlock)failureBlock
{
    
    NSString *authToken           = [self generateNewAccountAuthenticationToken];
    NSString *signalingKey        = [self generateNewSignalingKeyToken];
    NSString *phoneNumber         = [[tsToken componentsSeparatedByString:@":"] objectAtIndex:0];
    
    require(phoneNumber != nil);
    require(signalingKey != nil);
    require(authToken != nil);
    require(pushToken != nil);
    
    TSRegisterWithTokenRequest *request = [[TSRegisterWithTokenRequest alloc] initWithVerificationToken:tsToken signalingKey:signalingKey authKey:authToken number:phoneNumber];
    
    [[TSNetworkManager sharedManager] queueAuthenticatedRequest:request success:^(NSURLSessionDataTask *task, id responseObject) {
        
        NSHTTPURLResponse *response   = (NSHTTPURLResponse *)task.response;
        long statuscode               = response.statusCode;
        
        if (statuscode == 200 || statuscode == 204) {

            [TSStorageManager storeServerToken:authToken signalingKey:signalingKey phoneNumber:phoneNumber];
            
            [self registerForPushNotifications:pushToken voipToken:voipToken success:^{
                [self registerPreKeys:^{
                    successBlock();
                    [TSSocketManager becomeActiveFromForeground];
                } failure:failureBlock];
            } failure:^(NSError *error) {
                failureBlock([self errorForRegistrationFailure:kTSRegistrationFailureNetwork HTTPStatusCode:0]);
            }];
            
        } else{
            failureBlock([self errorForRegistrationFailure:kTSRegistrationFailureNetwork HTTPStatusCode:statuscode]);
        }
        
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        DDLogError(@"Error registering with TextSecure: %@", error.debugDescription);
        //TODO: Cover all error types: https://github.com/WhisperSystems/TextSecure-Server/wiki/API-Protocol
        // Above link doesn't appear to document the endpoint /v1/accounts/token/{token} - is it similar to /v1/accounts/code/{code} ?
        failureBlock([self errorForRegistrationFailure:kTSRegistrationFailureNetwork HTTPStatusCode:[task statusCode]]);
    }];
}

+ (void)registerPreKeysAfterPush:(NSData*)pushToken
                       voipToken:(NSData*)voipToken
                         success:(successCompletionBlock)successBlock
                         failure:(failedVerificationBlock)failureBlock
{
        [self registerForPushNotifications:pushToken voipToken:voipToken success:^{
            [self registerPreKeys:successBlock
                          failure:failureBlock];
        } failure:failureBlock];
}

+ (void)registerPreKeys:(successCompletionBlock)successBlock failure:(failedVerificationBlock)failureBlock {
    [TSPreKeyManager registerPreKeysWithSuccess:^{
        [TSAccountManager setRegistered:YES];
        successBlock();
    } failure:failureBlock];
}

#pragma mark Errors

+ (NSError *)errorForRegistrationFailure:(TSRegistrationFailure)failureType HTTPStatusCode:(long)HTTPStatus {
    
    NSString *description = NSLocalizedString(@"REGISTRATION_ERROR", @"");
    NSString *failureReason = nil;
    
    // TODO: Need localized strings for the rest of the values in the TSRegistrationFailure enum
    if (failureType == kTSRegistrationFailureWrongCode) {
        failureReason = NSLocalizedString(@"REGISTER_CHALLENGE_ALERT_VIEW_BODY", @"");
    } else if (failureType == kTSRegistrationFailureRateLimit) {
        failureReason = NSLocalizedString(@"REGISTER_RATE_LIMITING_BODY", @"");
    } else if (failureType == kTSRegistrationFailureNetwork) {
        failureReason = NSLocalizedString(@"REGISTRATION_BODY", @"");
    } else {
        failureReason = NSLocalizedString(@"REGISTER_CHALLENGE_UNKNOWN_ERROR", @"");
    }
    
    NSMutableDictionary *userInfo = NSMutableDictionary.new;
    
    userInfo[NSLocalizedDescriptionKey] = description;
    
    if (failureReason != nil) {
        userInfo[NSLocalizedFailureReasonErrorKey] = failureReason;
    }
    if (HTTPStatus != 0) {
        userInfo[TSRegistrationErrorUserInfoHTTPStatus] = @(HTTPStatus);
    }
    
    NSError *error = [NSError errorWithDomain:TSRegistrationErrorDomain code:failureType userInfo:userInfo];
    
    return error;
}

#pragma mark Server keying material

+ (NSString*)generateNewAccountAuthenticationToken {
    NSData    *authToken              = [SecurityUtils generateRandomBytes:16];
    NSString  *authTokenPrint         = [[NSData dataWithData:authToken] hexadecimalString];
    return authTokenPrint;
}

+ (NSString*)generateNewSignalingKeyToken {
    /*The signalingKey is 32 bytes of AES material (256bit AES) and 20 bytes of Hmac key material (HmacSHA1) concatenated into a 52 byte slug that is base64 encoded. */
    NSData    *signalingKeyToken      = [SecurityUtils generateRandomBytes:52];
    NSString  *signalingKeyTokenPrint = [[NSData dataWithData:signalingKeyToken] base64EncodedString];
    return signalingKeyTokenPrint;
}

+ (void)unregisterTextSecureWithSuccess:(successCompletionBlock)success failure:(failedVerificationBlock)failureBlock{
    [[TSNetworkManager sharedManager] queueAuthenticatedRequest:[[TSUnregisterAccountRequest alloc] init] success:^(NSURLSessionDataTask *task, id responseObject) {
        success();
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failureBlock(error);
    }];
    
}

@end
