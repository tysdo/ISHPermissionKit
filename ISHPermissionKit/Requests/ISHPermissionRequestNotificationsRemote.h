//
//  ISHPermissionRequestNotificationsRemote.h
//  Pods
//
//  Created by Catigbe, Karl on 8/18/14.
//
//

#import "ISHPermissionRequest.h"

@interface ISHPermissionRequestNotificationsRemote : ISHPermissionRequest
#ifdef __IPHONE_8_0
@property (nonatomic) UIUserNotificationSettings *noticationSettings;
#else
@property (nonatomic) UIRemoteNotificationType notificationTypes;
#endif
@end
