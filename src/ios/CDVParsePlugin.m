#import "CDVParsePlugin.h"
#import <Cordova/CDV.h>
#import <Parse/Parse.h>
#import <objc/runtime.h>
#import <objc/message.h>

#import <pthread.h>

CDVParsePlugin *singleton_CDVParsePlugin = NULL;
pthread_mutex_t parseInstallationObjectMutex;

@implementation CDVParsePlugin

- (CDVPlugin*)initWithWebView:(UIWebView*)theWebView
{
    self = [super initWithWebView:theWebView];
    NSLog(@"CDVParsePlugin initWithWebView 1");
    singleton_CDVParsePlugin = self;
    pthread_mutex_init(&parseInstallationObjectMutex, NULL);
    NSLog(@"CDVParsePlugin initWithWebView done");
    return self;
}

/*
 options:
 appId: "PARSE_APPID"
 clientKey: "PARSE_CLIENT_KEY"
 */
- (void)initialize: (CDVInvokedUrlCommand*)command
{
    NSLog(@"CDVParsePlugin initialize 1");

    NSDictionary *options   = [command.arguments objectAtIndex:0];
    NSString *appId         = [options objectForKey:@"appId"];
    NSString *clientKey     = [options objectForKey:@"clientKey"];

    [Parse setApplicationId:appId clientKey:clientKey];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    NSLog(@"CDVParsePlugin initialize done");
}

- (void)register: (CDVInvokedUrlCommand*)command
{
    NSLog(@"CDVParsePlugin register 1");
    NSDictionary *options   = [command.arguments objectAtIndex:0];
    NSString *appId         = [options objectForKey:@"appId"];
    NSString *clientKey     = [options objectForKey:@"clientKey"];

    if (appId != nil && clientKey != nil)
        [Parse setApplicationId:appId clientKey:clientKey];

    if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        UIUserNotificationSettings *settings =
        [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert |
         UIUserNotificationTypeBadge |
         UIUserNotificationTypeSound
         categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    }
    else {
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:
         UIRemoteNotificationTypeBadge |
         UIRemoteNotificationTypeAlert |
         UIRemoteNotificationTypeSound];
    }

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    NSLog(@"CDVParsePlugin register done");
}

- (void)getInstallationId:(CDVInvokedUrlCommand*) command
{
    [self.commandDelegate runInBackground:^{
        pthread_mutex_lock(&parseInstallationObjectMutex);

        PFInstallation *currentInstallation = [PFInstallation currentInstallation];
        NSString *installationId = currentInstallation.installationId;

        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:installationId];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

        pthread_mutex_unlock(&parseInstallationObjectMutex);
    }];
}

- (void)getInstallationObjectId:(CDVInvokedUrlCommand*) command
{
    [self.commandDelegate runInBackground:^{
        pthread_mutex_lock(&parseInstallationObjectMutex);

        PFInstallation *currentInstallation = [PFInstallation currentInstallation];
        NSString *objectId = currentInstallation.objectId;

        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:objectId];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

        pthread_mutex_unlock(&parseInstallationObjectMutex);
    }];
}

- (void)setBadge: (CDVInvokedUrlCommand *)command
{
    [self.commandDelegate runInBackground:^{
        pthread_mutex_lock(&parseInstallationObjectMutex);
        NSNumber *badgeNumber = (NSNumber *)[command.arguments objectAtIndex:0];
        PFInstallation *currentInstallation = [PFInstallation currentInstallation];
        currentInstallation[@"badge"] = badgeNumber;
        [currentInstallation save];

        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        pthread_mutex_unlock(&parseInstallationObjectMutex);
    }];
}

- (void)getSubscriptions: (CDVInvokedUrlCommand *)command
{
    [self.commandDelegate runInBackground:^{
        pthread_mutex_lock(&parseInstallationObjectMutex);

        NSArray *channels = [PFInstallation currentInstallation].channels;

        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:channels];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

        pthread_mutex_unlock(&parseInstallationObjectMutex);
    }];
}

- (void)subscribe: (CDVInvokedUrlCommand *)command
{
    NSString *channel = [command.arguments objectAtIndex:0];
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    NSArray *channels = [PFInstallation currentInstallation].channels;

    // Threadsafe, async updating is slow, so don't do it if we don't need to.
    if ([channels containsObject:channel]) {return;}

    // Though Parse says PFObject is threadsafe, some sequences of
    //   addUniqueObject, removeObject and saveInBackground
    // OR async sequences of
    //   addUniqueObject, removeObject and save
    // result this exception thrown:
    //   'NSInternalInconsistencyException', reason: 'Operation is invalid after previous operation.'
    [self.commandDelegate runInBackground:^{
        pthread_mutex_lock(&parseInstallationObjectMutex);

        NSLog(@"CDVParsePlugin subscribe channel:%@", channel);
        [currentInstallation addUniqueObject:channel forKey:@"channels"];
        [currentInstallation save];
        pthread_mutex_unlock(&parseInstallationObjectMutex);

        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)unsubscribe: (CDVInvokedUrlCommand *)command
{
    NSString *channel = [command.arguments objectAtIndex:0];
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    NSArray *channels = [PFInstallation currentInstallation].channels;

    // Threadsafe, async updating is slow, so don't do it if we don't need to.
    if (![channels containsObject:channel]) {return;}

    [self.commandDelegate runInBackground:^{
        pthread_mutex_lock(&parseInstallationObjectMutex);

        NSLog(@"CDVParsePlugin unsubscribe channel:%@", channel);
        [currentInstallation removeObject:channel forKey:@"channels"];
        [currentInstallation save];
        pthread_mutex_unlock(&parseInstallationObjectMutex);

        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

@end

@implementation AppDelegate (CDVParsePlugin)

/*
 DisptachEvent invokes: document.dispatchEvent(new CustomEvent(enventType, {detail: details}))
 inputs:
 eventType
 passed to the webView to define the event-type.
 details
 a valid, non-NULL json-compatible structure (NSArray, NSDictionary, etc...)
 must be true: [NSJSONSerialization isValidJSONObject: details]
 */
void DispatchEvent(NSString *eventType, id details) {
    if (![NSJSONSerialization isValidJSONObject: details]) {
        NSLog(@"CDVParsePlugin DispatchEvent '%@': INVALID VALUE for 'details'. Not NSJSONSerialization compatible.", eventType);
        return;
    }

    if (!singleton_CDVParsePlugin) {
        NSLog(@"CDVParsePlugin DispatchEvent '%@': INTERNAL ERROR. Could not find CDVParsePlugin singleton.", eventType);
        return;
    }

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject: details options: 0 error: &error];

    if (!jsonData) {
        NSLog(@"CDVParsePlugin DispatchEvent '%@': INTERNAL ERROR converting 'details' to json: %@", eventType, error);
        return;
    }

    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    // NSLog(@"CDVParsePlugin DispatchEvent '%@': ", eventType);
    NSLog(@"CDVParsePlugin DispatchEvent '%@': jsonString: %@", eventType, jsonString);

    NSString *javascript = [NSString stringWithFormat:@"document.dispatchEvent(new CustomEvent('%@', {detail:%@}));", eventType, jsonString];
    NSLog(@"CDVParsePlugin DispatchEvent '%@': invoking javascript: %@", eventType, javascript);

    [singleton_CDVParsePlugin.commandDelegate evalJs: javascript scheduledOnRunLoop: true];
}

void MethodSwizzle(Class c, SEL originalSelector) {
    NSString *selectorString = NSStringFromSelector(originalSelector);
    SEL newSelector   = NSSelectorFromString([@"swizzled_" stringByAppendingString:selectorString]);
    SEL noopSelector  = NSSelectorFromString([@"noop_" stringByAppendingString:selectorString]);
    Method originalMethod, newMethod, noop;
    originalMethod    = class_getInstanceMethod(c, originalSelector);
    newMethod         = class_getInstanceMethod(c, newSelector);
    noop              = class_getInstanceMethod(c, noopSelector);

    if (class_addMethod(c, originalSelector, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(c, newSelector, method_getImplementation(originalMethod) ?: method_getImplementation(noop), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, newMethod);
    }
}

+ (void)load
{
    NSLog(@"CDVParsePlugin loading...");
    MethodSwizzle([self class], @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:));
    MethodSwizzle([self class], @selector(application:didReceiveRemoteNotification:));
    MethodSwizzle([self class], @selector(application:didFailToRegisterForRemoteNotificationsWithError:));
    NSLog(@"CDVParsePlugin loaded");
}

- (void)noop_application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)newDeviceToken {}
- (void)swizzled_application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)newDeviceToken
{
    if (!singleton_CDVParsePlugin) {
        NSLog(@"CDVParsePlugin didRegisterForRemoteNotificationsWithDeviceToken: INTERNAL ERROR. Could not find CDVParsePlugin singleton.");
        return;
    }

    [singleton_CDVParsePlugin.commandDelegate runInBackground:^{
        pthread_mutex_lock(&parseInstallationObjectMutex);
        NSLog(@"CDVParsePlugin didRegisterForRemoteNotificationsWithDeviceToken 1");
        // Call existing method
        [self swizzled_application:application didRegisterForRemoteNotificationsWithDeviceToken:newDeviceToken];
        // Store the deviceToken in the current installation and save it to Parse.
        PFInstallation *currentInstallation = [PFInstallation currentInstallation];
        [currentInstallation setDeviceTokenFromData:newDeviceToken];
        [currentInstallation save];
        NSLog(@"CDVParsePlugin didRegisterForRemoteNotificationsWithDeviceToken done");
        pthread_mutex_unlock(&parseInstallationObjectMutex);
    }];
}

- (void)noop_application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {}
- (void)swizzled_application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    // Call existing method
    NSLog(@"CDVParsePlugin didReceiveRemoteNotification 1");
    [self swizzled_application:application didReceiveRemoteNotification:userInfo];
    // [PFPush handlePush:userInfo];

    DispatchEvent(@"didReceiveRemoteNotification", userInfo);
    NSLog(@"CDVParsePlugin didReceiveRemoteNotification done");
}


- (void)noop_application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {}
- (void)swizzled_application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"CDVParsePlugin didFailToRegisterForRemoteNotificationsWithError: %@", error);
}


@end
