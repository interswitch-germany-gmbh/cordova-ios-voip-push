#import "VoIPPushNotification.h"
#import <Cordova/CDV.h>
#import <AudioToolbox/AudioToolbox.h>
#import <UserNotifications/UserNotifications.h>

@implementation VoIPPushNotification

@synthesize cordovaCallback;

- (void)init:(CDVInvokedUrlCommand*)command
{
    self.cordovaCallback = command.callbackId;
    NSLog(@"[objC:Cordova] Cordova callback ID: %@", self.cordovaCallback);
    
    PKPushRegistry *pushRegistry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
    pushRegistry.delegate = self;
    pushRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
}

- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type{
    if([credentials.token length] == 0) {
        NSLog(@"[objC:Cordova] Failed to update push credentials");
        return;
    }
    
    if ([UIApplication instancesRespondToSelector:@selector(registerUserNotificationSettings:)]) {
        [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert|UIUserNotificationTypeSound categories:nil]];
    }
    
    NSLog(@"[objC:Cordova] Did update push credentials: %@", credentials.token);
    const unsigned *tokenBytes = [credentials.token bytes];
    NSString *sToken = [NSString stringWithFormat:@"%08x%08x%08x%08x%08x%08x%08x%08x",
                        ntohl(tokenBytes[0]), ntohl(tokenBytes[1]), ntohl(tokenBytes[2]),
                        ntohl(tokenBytes[3]), ntohl(tokenBytes[4]), ntohl(tokenBytes[5]),
                        ntohl(tokenBytes[6]), ntohl(tokenBytes[7])];
    
    NSMutableDictionary* results = [NSMutableDictionary dictionaryWithCapacity:2];
    [results setObject:sToken forKey:@"token"];
    [results setObject:@"true" forKey:@"registration"];
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:results];
    [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId: self.cordovaCallback];
}

- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(NSString *)type
{
    NSLog(@"[objC:Cordova] didReceiveIncomingPushWithPayload: %@", payload.dictionaryPayload);
    
    
    UILocalNotification* notif = [[UILocalNotification alloc] init];
    notif.alertBody = payload.dictionaryPayload[@"aps"][@"alert"];
    [[UIApplication sharedApplication] presentLocalNotificationNow:notif];
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    
    NSMutableDictionary *result = [payload.dictionaryPayload mutableCopy];
    
    if([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive)
    {
        [result setObject:@"read" forKey:@"status"];
    } else {
        [result setValue:@"received" forKey:@"status"];
    }
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:result];
    
    [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId: self.cordovaCallback];
}


- (void)isRegisteredForRemoteNotifications:(CDVInvokedUrlCommand*)command
{
    BOOL registered;
    NSString *result;
    @try {
        if([[[UIDevice currentDevice]systemVersion]floatValue]<10.0){
            registered = [UIApplication sharedApplication].isRegisteredForRemoteNotifications;
            if (registered){
                result = @"enabled";
            } else {
                result = @"disabled";
            }
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:result];
            [self.commandDelegate sendPluginResult:pluginResult callbackId: command.callbackId];
            
        } else {
            UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
            [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
                BOOL registered = settings.authorizationStatus == UNAuthorizationStatusAuthorized;
                NSString *result;
                if (registered){
                    result = @"enabled";
                } else {
                    result = @"disabled";
                }
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:result];
                [self.commandDelegate sendPluginResult:pluginResult callbackId: command.callbackId];
            }];
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Permissions Error.");
    }
}


@end
