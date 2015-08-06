#import "CDVParsePlugin.h"
#import <Cordova/CDV.h>
#import <Parse/Parse.h>
#import <objc/runtime.h>
#import <objc/message.h>

CDVParsePlugin *singleton_CDVParsePlugin = NULL;

@implementation CDVParsePlugin

/*
 options:
 appId: "PARSE_APPID"
 clientKey: "PARSE_CLIENT_KEY"
 */
- (void)initialize: (CDVInvokedUrlCommand*)command
{
  singleton_CDVParsePlugin = self;

  NSDictionary *options   = [command.arguments objectAtIndex:0];
  NSString *appId         = [options objectForKey:@"appId"];
  NSString *clientKey     = [options objectForKey:@"clientKey"];

  [Parse setApplicationId:appId clientKey:clientKey];

  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)register: (CDVInvokedUrlCommand*)command
{
  singleton_CDVParsePlugin = self;

  NSLog(@"CDVParsePlugin register 1");
  NSDictionary *options   = [command.arguments objectAtIndex:0];
  NSString *appId         = [options objectForKey:@"appId"];
  NSString *clientKey     = [options objectForKey:@"clientKey"];

  if (appId != nil && clientKey != nil)
    [Parse setApplicationId:appId clientKey:clientKey];

  if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)]) {
    NSLog(@"CDVParsePlugin register 2");
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
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    NSString *installationId = currentInstallation.installationId;

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:installationId];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  }];
}

- (void)getInstallationObjectId:(CDVInvokedUrlCommand*) command
{
  [self.commandDelegate runInBackground:^{
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    NSString *objectId = currentInstallation.objectId;

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:objectId];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  }];
}

- (void)setBadge: (CDVInvokedUrlCommand *)command
{
  NSNumber *badgeNumber = (NSNumber *)[command.arguments objectAtIndex:0];
  PFInstallation *currentInstallation = [PFInstallation currentInstallation];
  currentInstallation[@"badge"] = badgeNumber;
  [currentInstallation saveInBackground];

  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getSubscriptions: (CDVInvokedUrlCommand *)command
{
  NSArray *channels = [PFInstallation currentInstallation].channels;

  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:channels];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)subscribe: (CDVInvokedUrlCommand *)command
{
  PFInstallation *currentInstallation = [PFInstallation currentInstallation];
  NSString *channel = [command.arguments objectAtIndex:0];
  [currentInstallation addUniqueObject:channel forKey:@"channels"];
  [currentInstallation saveInBackground];

  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)unsubscribe: (CDVInvokedUrlCommand *)command
{
  PFInstallation *currentInstallation = [PFInstallation currentInstallation];
  NSString *channel = [command.arguments objectAtIndex:0];
  [currentInstallation removeObject:channel forKey:@"channels"];
  [currentInstallation saveInBackground];

  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

@end

@implementation AppDelegate (CDVParsePlugin)

/*
 DisptachEvent invokes: document.dispatchEvent(new CustomEvent(enventType, {detail: details}))
 intputs:
 eventType
 passed to the webView to define the event-type.
 details
 a valid, non-NULL json-compatible structure (NSArray, NSDictionary, etc...)
 must be true: [NSJSONSerialization isValidJSONObject: details]
 */
void DispatchEvent(NSString *eventType, id details) {
  if (![NSJSONSerialization isValidJSONObject: details]) {
    NSLog(@"CDVParsePlugin DispatchEvent '%@': invalid 'details' value. Not NSJSONSerialization compatible.", eventType);
    return;
  }

  if (!singleton_CDVParsePlugin) {
    NSLog(@"CDVParsePlugin DispatchEvent '%@': internal error. Could not find CDVParsePlugin singleton.", eventType);
    return;
  }

  NSError *error;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject: details options: 0 error: &error];

  if (!jsonData) {
    NSLog(@"CDVParsePlugin DispatchEvent '%@': internal error converting 'details' to json: %@", eventType, error);
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
  // Call existing method
  NSLog(@"CDVParsePlugin didRegisterForRemoteNotificationsWithDeviceToken 1");
  [self swizzled_application:application didRegisterForRemoteNotificationsWithDeviceToken:newDeviceToken];
  // Store the deviceToken in the current installation and save it to Parse.
  PFInstallation *currentInstallation = [PFInstallation currentInstallation];
  [currentInstallation setDeviceTokenFromData:newDeviceToken];
  [currentInstallation saveInBackground];
  NSLog(@"CDVParsePlugin didRegisterForRemoteNotificationsWithDeviceToken done");
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
