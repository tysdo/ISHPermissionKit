//
//  ISHPermissionRequestNotificationsRemote.h
//  Pods
//
//  Created by Catigbe, Karl on 8/18/14.
//
//

#import "ISHPermissionRequest.h"

@interface ISHPermissionRequestNotificationsRemote : ISHPermissionRequest
@property (nonatomic) UIUserNotificationSettings *notificationSettings;
@property (nonatomic) UIRemoteNotificationType notificationTypes;
@end
