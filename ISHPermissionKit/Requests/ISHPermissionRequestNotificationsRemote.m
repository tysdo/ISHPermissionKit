//
//  ISHPermissionRequestNotificationsRemote.m
//  Pods
//
//  Created by Catigbe, Karl on 8/18/14.
//
//

#import "ISHPermissionRequestNotificationsRemote.h"

@interface ISHPermissionRequestNotificationsRemote ()
@property (copy) ISHPermissionRequestCompletionBlock completionBlock;
@property (nonatomic, assign) BOOL askState;

- (ISHPermissionState)internalPermissionState;
+ (NSUInteger)systemMajorVersion;
@end

@implementation ISHPermissionRequestNotificationsRemote

+ (NSUInteger)systemMajorVersion {
    
    NSString *sysVer = [[UIDevice currentDevice] systemVersion];
    NSUInteger systemVersion = 0;
    NSString *majorVersion = nil;
    
    @try {
        majorVersion = [[sysVer componentsSeparatedByString:@"."] objectAtIndex:0];
    }
    @catch (NSException *exception) {
        
    }
    @finally {
        if(majorVersion && majorVersion.length > 0) {
            systemVersion = [majorVersion integerValue];
        }
        
        return systemVersion;
    }
}


- (void) setInternalAskState:(BOOL)askState {
    _askState = askState;
    [[NSUserDefaults standardUserDefaults] setValue:@(askState) forKey:@"__ISHPermissionRequestNotificationsRemoteAskState"];
}

- (BOOL) internalAskState {
    NSNumber *askState = [[NSUserDefaults standardUserDefaults] objectForKey:@"__ISHPermissionRequestNotificationsRemoteAskState"];
    return [askState boolValue];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        if([[self class] systemMajorVersion] >= 8 && NSClassFromString(@"UIUserNotificationSettings")) {
            self.notificationSettings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert
                                                                          categories:nil];
        }
        else {
            self.notificationTypes = [[UIApplication sharedApplication] enabledRemoteNotificationTypes];
        }
        
        _askState = [self internalAskState];
    }
    
    return self;
}

- (BOOL)allowsConfiguration {
    return YES;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (ISHPermissionState)permissionState {
    
    ISHPermissionState currentState = ISHPermissionStateUnknown;
    BOOL denied = NO;
    BOOL authorized = NO;
    BOOL askAgain = NO;
    BOOL dontAsk = NO;
    
    dontAsk = [self internalPermissionState] == ISHPermissionStateDoNotAskAgain;
    
    if(!dontAsk) {
        if([[self class] systemMajorVersion] >= 8 && [[UIApplication sharedApplication] respondsToSelector:@selector(currentUserNotificationSettings)]) {
            UIUserNotificationSettings *notificationSettings = [[UIApplication sharedApplication] currentUserNotificationSettings];
            
            denied = (!notificationSettings || (notificationSettings.types == UIUserNotificationTypeNone && [self internalAskState]));
            authorized = (notificationSettings.types != UIUserNotificationTypeNone);
            askAgain = [self internalPermissionState] == ISHPermissionStateAskAgain || ([self internalPermissionState] == ISHPermissionStateUnknown && ![self internalAskState]);
        }
        else {
            UIRemoteNotificationType types = [[UIApplication sharedApplication] enabledRemoteNotificationTypes];
            denied = (types == UIRemoteNotificationTypeNone && [self internalAskState]);
            authorized = (types > UIRemoteNotificationTypeNone);
            askAgain = ([self internalPermissionState] == ISHPermissionStateAskAgain) || ([self internalPermissionState] == ISHPermissionStateUnknown && ![self internalAskState]);
            
        }
    }
    
    if (denied) {
        currentState = ISHPermissionStateDenied;
    }
    else if (authorized) {
        currentState = ISHPermissionStateAuthorized;
    }
    else if (askAgain) {
        currentState = ISHPermissionStateAskAgain;
    }
    else if (dontAsk) {
        currentState = ISHPermissionStateDoNotAskAgain;
    }
    
    // To be discussed: should types/categories differing from self.noticationSettings lead to denied state?
    return currentState;
}

- (void)requestUserPermissionWithCompletionBlock:(ISHPermissionRequestCompletionBlock)completion {
    NSAssert(completion, @"requestUserPermissionWithCompletionBlock requires a completion block");
    if([[self class] systemMajorVersion] >= 8) {
        NSAssert(self.notificationSettings, @"Requested notification settings should be set for request before requesting user permission");
    }
    
    // ensure that the app delegate implements the didRegisterMethods:
    
    
    NSAssert([[[UIApplication sharedApplication] delegate] respondsToSelector:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)], @"AppDelegate must implement application:didRegisterForRemoteNotificationsWithDeviceToken: and post notification ISHPermissionNotificationApplicationDidRegisterUserNotificationSettings");
    
    
    ISHPermissionState currentState = self.permissionState;
    if (!ISHPermissionStateAllowsUserPrompt(currentState)) {
        completion(self, currentState, nil);
        return;
    }
    
    [self setInternalAskState:YES]; //We've asked for permission from the user, so save that state.
    
    
    self.completionBlock = completion;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(ISHPermissionNotificationApplicationDidRegisterUserNotificationSettings:)
                                                 name:ISHPermissionNotificationApplicationDidRegisterUserNotificationSettings
                                               object:nil];
    
    if(self.externalRequestBlock) {
        self.externalRequestBlock(self, self.permissionState, nil);
    }
    else {
        
        if([[self class] systemMajorVersion] >= 8 && [[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)]) {
            [[UIApplication sharedApplication] registerUserNotificationSettings:self.notificationSettings];
        }
        else {
            [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound)];
        }
    }
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resumeFromPrompt:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    
    
}

- (void)ISHPermissionNotificationApplicationDidRegisterUserNotificationSettings:(NSNotification *)note {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    ISHPermissionState state = [self permissionState];
    
    if(note && [note userInfo] && [[note userInfo] objectForKey:@"state"]) {
        state = [[[note userInfo] objectForKey:@"state"] integerValue];
    }
    
    if (self.completionBlock) {
        self.completionBlock(self, state, nil);
        self.completionBlock = nil;
    }
    
}

- (void)resumeFromPrompt:(NSNotification *)note {
    BOOL noResponse = NO;
    
    if([[self class] systemMajorVersion] >= 8  && [[UIApplication sharedApplication] respondsToSelector:@selector(currentUserNotificationSettings)]) {
        self.notificationSettings = [[UIApplication sharedApplication] currentUserNotificationSettings];
        noResponse = self.askState && (!self.notificationSettings || (self.notificationSettings.types == UIUserNotificationTypeNone));
    }
    else {
        self.notificationTypes = [[UIApplication sharedApplication] enabledRemoteNotificationTypes];
        noResponse = self.askState && self.notificationTypes == UIRemoteNotificationTypeNone;
    }
    
    if (noResponse) {
        //We've come back from the prompt, and have no notification type set.
        NSNotification *noResponseNotification = [NSNotification notificationWithName:ISHPermissionNotificationApplicationDidRegisterUserNotificationSettings object:self userInfo:@{@"state" : @(ISHPermissionStateDenied)}];
        [self ISHPermissionNotificationApplicationDidRegisterUserNotificationSettings:noResponseNotification];
    }
}

@end
