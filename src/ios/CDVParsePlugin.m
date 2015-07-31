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
  [PFPush handlePush:userInfo];

  if (singleton_CDVParsePlugin) {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:userInfo
                                                       options:0 //NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
                                                         error:&error];
    if (jsonData) {
      NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
      NSLog(@"CDVParsePlugin didReceiveRemoteNotification: userInfo: %@", jsonString);
      NSString *callback = @"console.log";
      NSString *jsCallBack = [NSString stringWithFormat:@"%@(%@);", callback, jsonString];
      NSLog(@"CDVParsePlugin didReceiveRemoteNotification: jsCallBack: %@", jsCallBack);

      [singleton_CDVParsePlugin.webView stringByEvaluatingJavaScriptFromString:jsCallBack];
    } else {
      NSLog(@"Error converting Push data to json: %@", error);
    }
  } else {
    NSLog(@"CDVParsePlugin didReceiveRemoteNotification singleton_CDVParsePlugin not set");
  }

  NSLog(@"CDVParsePlugin didReceiveRemoteNotification done");
}


- (void)noop_application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {}
- (void)swizzled_application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
  NSLog(@"CDVParsePlugin didFailToRegisterForRemoteNotificationsWithError: %@", error);
}


@end
