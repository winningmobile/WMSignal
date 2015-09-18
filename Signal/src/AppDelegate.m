#import "AppDelegate.h"
#import "AppStoreRating.h"
#import "CategorizingLogger.h"
#import "ContactsManager.h"
#import "DebugLogger.h"
#import "Environment.h"
#import "PhoneNumberDirectoryFilterManager.h"
#import "PreferencesUtil.h"
#import "PushManager.h"
#import "Release.h"
#import "TSAccountManager.h"
#import "TSPreKeyManager.h"
#import "TSMessagesManager.h"
#import "TSSocketManager.h"
#import "VersionMigrations.h"
#import "CodeVerificationViewController.h"

static NSString * const kStoryboardName = @"Storyboard";
static NSString * const kInitialViewControllerIdentifier = @"UserInitialViewController";
static NSString * const kURLSchemeSGNLKey = @"sgnl";
static NSString * const kURLHostVerifyPrefix = @"verify";

@interface AppDelegate ()

@property (nonatomic, retain) UIWindow *blankWindow;

@end

@implementation AppDelegate

#pragma mark Detect updates - perform migrations

+ (void)initialize{
    [AppStoreRating setupRatingLibrary];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self setupAppearance];
    [[PushManager sharedManager] registerPushKitNotificationFuture];
    
    if (getenv("runningTests_dontStartApp")) {
        return YES;
    }
    
    CategorizingLogger* logger = [CategorizingLogger categorizingLogger];
    [logger addLoggingCallback:^(NSString *category, id details, NSUInteger index) {}];
    [Environment setCurrent:[Release releaseEnvironmentWithLogging:logger]];
    [Environment.getCurrent.phoneDirectoryManager startUntilCancelled:nil];
    
    if ([TSAccountManager isRegistered]) {
        [Environment.getCurrent.contactsManager doAfterEnvironmentInitSetup];
    }
    
    [Environment.getCurrent initCallListener];
    
    [[TSStorageManager sharedManager] setupDatabase];
    
    BOOL loggingIsEnabled;
    
#ifdef DEBUG
    // Specified at Product -> Scheme -> Edit Scheme -> Test -> Arguments -> Environment to avoid things like
    // the phone directory being looked up during tests.
    loggingIsEnabled = TRUE;
    [DebugLogger.sharedInstance enableTTYLogging];
#elif RELEASE
    loggingIsEnabled = Environment.preferences.loggingIsEnabled;
#endif
    [self verifyBackgroundBeforeKeysAvailableLaunch];
    
    if (loggingIsEnabled) {
        [DebugLogger.sharedInstance enableFileLogging];
    }
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:kStoryboardName bundle:[NSBundle mainBundle]];
    UIViewController *viewController = [storyboard instantiateViewControllerWithIdentifier:kInitialViewControllerIdentifier];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = viewController;
    
    [self.window makeKeyAndVisible];
    
    [VersionMigrations performUpdateCheck]; // this call must be made after environment has been initialized because in general upgrade may depend on environment
    
    //Accept push notification when app is not open
    NSDictionary *remoteNotif = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
    if (remoteNotif) {
        DDLogInfo(@"Application was launched by tapping a push notification.");
        [self application:application didReceiveRemoteNotification:remoteNotif ];
    }
    
    [self prepareScreenshotProtection];
    
    if ([TSAccountManager isRegistered]) {
        if (application.applicationState == UIApplicationStateInactive) {
            [TSSocketManager becomeActiveFromForeground];
        } else if (application.applicationState == UIApplicationStateBackground) {
            [TSSocketManager becomeActiveFromBackgroundExpectMessage:NO];
        } else {
            DDLogWarn(@"The app was launched in an unknown way");
        }
        
        [[PushManager sharedManager] validateUserNotificationSettings];
        [self refreshContacts];
        [TSPreKeyManager refreshPreKeys];
    }
    
    return YES;
}

- (void)application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken {
    [PushManager.sharedManager.pushNotificationFutureSource trySetResult:deviceToken];
}

- (void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error {
#ifdef DEBUG
    DDLogWarn(@"We're in debug mode, and registered a fake push identifier");
    [PushManager.sharedManager.pushNotificationFutureSource trySetResult:[@"aFakePushIdentifier" dataUsingEncoding:NSUTF8StringEncoding]];
#else
    [PushManager.sharedManager.pushNotificationFutureSource trySetFailure:error];
#endif
}

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings{
    [PushManager.sharedManager.userNotificationFutureSource trySetResult:notificationSettings];
}

-(BOOL) application:(UIApplication*)application openURL:(NSURL*)url sourceApplication:(NSString*)sourceApplication annotation:(id)annotation {
    if ([url.scheme isEqualToString:kURLSchemeSGNLKey]) {
        if ([url.host hasPrefix:kURLHostVerifyPrefix] && ![TSAccountManager isRegistered]) {
            id signupController                   = [Environment getCurrent].signUpFlowNavigationController;
            if ([signupController isKindOfClass:[UINavigationController class]]) {
                UINavigationController *navController = (UINavigationController*)signupController;
                UIViewController *controller          = [navController.childViewControllers lastObject];
                if ([controller isKindOfClass:[CodeVerificationViewController class]]) {
                    CodeVerificationViewController *cvvc  = (CodeVerificationViewController*)controller;
                    NSString *verificationCode            = [url.path substringFromIndex:1];
                    
                    cvvc.challengeTextField.text          = verificationCode;
                    [cvvc verifyChallengeAction:nil];
                } else{
                    DDLogWarn(@"Not the verification view controller we expected. Got %@ instead", NSStringFromClass(controller.class));
                }
                
            }
        } else{
            DDLogWarn(@"Application opened with an unknown URL action: %@", url.host);
        }
    } else {
        DDLogWarn(@"Application opened with an unknown URL scheme: %@", url.scheme);
    }
    return NO;
}

-(void)applicationDidBecomeActive:(UIApplication *)application {
    if ([TSAccountManager isRegistered]) {
        // We're double checking that the app is active, to be sure since we can't verify in production env due to code signing.
        [TSSocketManager becomeActiveFromForeground];
        [[Environment getCurrent].contactsManager verifyABPermission];
    }

    [self removeScreenProtection];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    [self protectScreen];

    if ([TSAccountManager isRegistered]) {
        [self updateBadge];
        [TSSocketManager resignActivity];
    }
}

- (void)updateBadge {
    if ([TSAccountManager isRegistered]) {
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:1];
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:(NSInteger)[[TSMessagesManager sharedManager] unreadMessagesCount]];
    }
}

- (void)prepareScreenshotProtection{
    self.blankWindow = ({
        UIWindow *window              = [[UIWindow alloc] initWithFrame:self.window.bounds];
        window.hidden                 = YES;
        window.opaque                 = YES;
        window.userInteractionEnabled = NO;
        window.windowLevel            = CGFLOAT_MAX;
        
        // There appears to be no more reliable way to get the launchscreen image from an asset bundle
        NSDictionary *dict = @{@"320x480" : @"LaunchImage-700",
                               @"320x568" : @"LaunchImage-700-568h",
                               @"375x667" : @"LaunchImage-800-667h",
                               @"414x736" : @"LaunchImage-800-Portrait-736h"};
        
        NSString *key = [NSString stringWithFormat:@"%dx%d", (int)[UIScreen mainScreen].bounds.size.width, (int)[UIScreen mainScreen].bounds.size.height];
        UIImage *launchImage = [UIImage imageNamed:dict[key]];
        UIImageView *imgView = [[UIImageView alloc] initWithImage:launchImage];
        UIViewController *vc = [[UIViewController alloc] initWithNibName:nil bundle:nil];
        vc.view.frame        = [[UIScreen mainScreen] bounds];
        imgView.frame        = [[UIScreen mainScreen] bounds];
        [vc.view addSubview:imgView];
        [vc.view setBackgroundColor:[UIColor ows_blackColor]];
        window.rootViewController = vc;
        
        window;
    });
}

- (void)protectScreen{
    if (Environment.preferences.screenSecurityIsEnabled){
        self.blankWindow.hidden = NO;
    }
}

- (void)removeScreenProtection{
    if (Environment.preferences.screenSecurityIsEnabled) {
        self.blankWindow.hidden = YES;
    }
}

-(void)setupAppearance {
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    [[UINavigationBar appearance] setBarTintColor:[UIColor ows_materialBlueColor]];
    [[UINavigationBar appearance] setTintColor:[UIColor whiteColor]];
    
    [[UIBarButtonItem appearanceWhenContainedIn: [UISearchBar class], nil] setTintColor:[UIColor ows_materialBlueColor]];


    [[UIToolbar appearance] setTintColor:[UIColor ows_materialBlueColor]];
    [[UIBarButtonItem appearance] setTintColor:[UIColor whiteColor]];
    
    NSShadow *shadow = [NSShadow new];
    [shadow setShadowColor:[UIColor clearColor]];
    
    NSDictionary *navbarTitleTextAttributes = @{
                                                NSForegroundColorAttributeName:[UIColor whiteColor],
                                                NSShadowAttributeName:shadow,
                                                };
    
    [[UISwitch appearance] setOnTintColor:[UIColor ows_materialBlueColor]];
    
    [[UINavigationBar appearance] setTitleTextAttributes:navbarTitleTextAttributes];

}

- (void)refreshContacts {
    Environment *env = [Environment getCurrent];
    PhoneNumberDirectoryFilterManager *manager = [env phoneDirectoryManager];
    [manager forceUpdate];
}

#pragma mark Push Notifications Delegate Methods

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    [[PushManager sharedManager] application:application didReceiveRemoteNotification:userInfo];
}
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    [[PushManager sharedManager] application:application didReceiveRemoteNotification:userInfo fetchCompletionHandler:completionHandler];
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification{
    [[PushManager sharedManager] application:application didReceiveLocalNotification:notification];
}

- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forLocalNotification:(UILocalNotification *)notification completionHandler:(void (^)())completionHandler {
    [[PushManager sharedManager] application:application handleActionWithIdentifier:identifier forLocalNotification:notification completionHandler:completionHandler];
}

/**
 *  Signal requires an iPhone to be unlocked after reboot to be able to access keying material.
 */
- (void)verifyBackgroundBeforeKeysAvailableLaunch {
    if ([self applicationIsActive]) {
        return;
    }
    
    if (![[TSStorageManager sharedManager] databasePasswordAccessible]) {
        UILocalNotification *notification = [[UILocalNotification alloc] init];
        notification.alertBody = NSLocalizedString(@"PHONE_NEEDS_UNLOCK", nil);
        [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
        exit(0);
    }
}

- (BOOL)applicationIsActive {
    UIApplication *app = [UIApplication sharedApplication];
    
    if (app.applicationState == UIApplicationStateActive) {
        return YES;
    }
    
    return NO;
}

@end
