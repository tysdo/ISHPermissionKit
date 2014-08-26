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
@end

@implementation ISHPermissionRequestNotificationsRemote

- (void) setInternalAskState:(BOOL)askState {
    _askState = askState;
    [[NSUserDefaults standardUserDefaults] setValue:@(askState) forKey:@"__ISHPermissionRequestNotificationsRemoteAskState"];
}

- (BOOL) internalAskState {
    NSNumber *askState = [[NSUserDefaults standardUserDefaults] objectForKey:@"__ISHPermissionRequestNotificationsRemoteAskState"];
    return [askState boolValue];
}

#ifdef __IPHONE_8_0
- (instancetype)init {
    self = [super init];
    if (self) {
        self.noticationSettings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert
                                                                    categories:nil];
        
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
    if (!NSClassFromString(@"UIUserNotificationSettings")) {
        return ISHPermissionStateAuthorized;
    }
    
    UIUserNotificationSettings *noticationSettings = [[UIApplication sharedApplication] currentUserNotificationSettings];
    
    if (!noticationSettings || (noticationSettings.types == UIUserNotificationTypeNone)) {
        return [self internalPermissionState];
    }
    
    // To be discussed: should types/categories differing from self.noticationSettings lead to denied state?
    return ISHPermissionStateAuthorized;
}

- (void)requestUserPermissionWithCompletionBlock:(ISHPermissionRequestCompletionBlock)completion {
    NSAssert(completion, @"requestUserPermissionWithCompletionBlock requires a completion block");
    NSAssert(self.noticationSettings, @"Requested notification settings should be set for request before requesting user permission");
    // ensure that the app delegate implements the didRegisterMethods:
    NSAssert([[[UIApplication sharedApplication] delegate] respondsToSelector:@selector(application:didRegisterUserNotificationSettings:)], @"AppDelegate must implement application:didRegisterUserNotificationSettings: and post notification ISHPermissionNotificationApplicationDidRegisterUserNotificationSettings");
    
    ISHPermissionState currentState = self.permissionState;
    if (!ISHPermissionStateAllowsUserPrompt(currentState)) {
        completion(self, currentState, nil);
        return;
    }
    
    // avoid asking again (system state does not correctly reflect if we asked already).
//    [self setInternalPermissionState:ISHPermissionStateDoNotAskAgain];
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
        [[UIApplication sharedApplication] registerUserNotificationSettings:self.noticationSettings];
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
    self.notificationSettings = [[UIApplication sharedApplication] currentUserNotificationSettings];
    
    
    if (self.askState && (!self.notificationSettings || (self.notificationSettings.types == UIUserNotificationTypeNone))) {
        //We've come back from the prompt, and have no notification type set.
        NSNotification *noResponseNotification = [NSNotification notificationWithName:ISHPermissionNotificationApplicationDidRegisterUserNotificationSettings object:self userInfo:@{@"state" : @(ISHPermissionStateDenied)}];
        [self ISHPermissionNotificationApplicationDidRegisterUserNotificationSettings:noResponseNotification];
    }
}



#else

- (instancetype)init {
    self = [super init];
    if (self) {
        _notificationTypes = [[UIApplication sharedApplication] enabledRemoteNotificationTypes];
        _askState = [self internalAskState];
    }
    return self;
}

- (void)requestUserPermissionWithCompletionBlock:(ISHPermissionRequestCompletionBlock)completion {
    NSAssert(completion, @"requestUserPermissionWithCompletionBlock requires a completion block");

    // ensure that the app delegate implements the didRegisterMethods:
    NSAssert([[[UIApplication sharedApplication] delegate] respondsToSelector:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)], @"AppDelegate must implement application:didRegisterForRemoteNotificationsWithDeviceToken: and post notification ISHPermissionNotificationApplicationDidRegisterUserNotificationSettings");
    
    ISHPermissionState currentState = self.permissionState;
    if (!ISHPermissionStateAllowsUserPrompt(currentState)) {
        completion(self, currentState, nil);
        return;
    }
    
    // avoid asking again (system state does not correctly reflect if we asked already).
//    [self setInternalPermissionState:ISHPermissionStateDoNotAskAgain];
    [self setInternalAskState:YES]; //We've asked for permission from the user, so save that state.
    
    self.completionBlock = completion;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(ISHPermissionNotificationApplicationDidRegisterUserNotificationSettings:)
                                                 name:ISHPermissionNotificationApplicationDidRegisterUserNotificationSettings
                                               object:nil];
    
    
    //Might need to delegate this out to the client app, some people use 3rd party libs to register notifications (UrbanAirship, etc)

    if(self.externalRequestBlock) {
        self.externalRequestBlock(self, self.permissionState, nil);
    }
    else {
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound)];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resumeFromPrompt:) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (ISHPermissionState)permissionState {

    ISHPermissionState state = ISHPermissionStateUnknown;
    
    if(self.notificationTypes & UIRemoteNotificationTypeAlert) {
        state = ISHPermissionStateAuthorized;
    }
    else {
        //If we've already prompted the user, and the alert type is none, then we can assume they denied (or manually turned off) notifications
        state = self.askState ? ISHPermissionStateDenied : ISHPermissionStateUnknown;
    }
    
    return state;
}

- (void)resumeFromPrompt:(NSNotification *)note {
    self.notificationTypes = [[UIApplication sharedApplication] enabledRemoteNotificationTypes];
    
    if(self.askState && self.notificationTypes == UIRemoteNotificationTypeNone) {
      //We've come back from the prompt, and have no notification type set.
      NSNotification *noResponseNotification = [NSNotification notificationWithName:ISHPermissionNotificationApplicationDidRegisterUserNotificationSettings object:self userInfo:@{@"state" : @(ISHPermissionStateDenied)}];
      [self ISHPermissionNotificationApplicationDidRegisterUserNotificationSettings:noResponseNotification];
    }
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

- (BOOL)allowsConfiguration {
    return YES;
}

#endif
@end
