/*
 * Copyright 2012 Facebook
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "AppDelegate.h"
#import "MenuViewController.h"

NSString *const FBSessionStateChangedNotification =
@"com.facebook.samples.SocialCafe:FBSessionStateChangedNotification";

NSString *const FBMenuDataChangedNotification =
@"com.facebook.samples.SocialCafe:FBMenuDataChangedNotification";

@interface AppDelegate ()
<MenuDataLoadDelegate>

@property (strong, nonatomic) NSURL *openedURL;

@end

@implementation AppDelegate

@synthesize window = _window;
@synthesize openedURL = _openedURL;
@synthesize menu = _menu;
@synthesize user = _user;

#pragma mark - Helper methods
/*
 * Helper method that initializes the menu items
 */
- (void)initMenuItems {
    self.menu = [[Menu alloc] init];
    self.menu.delegate = self;
}

/**
 * A function for parsing URL parameters.
 */
- (NSDictionary*)parseURLParams:(NSString *)query {
    NSArray *pairs = [query componentsSeparatedByString:@"&"];
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    for (NSString *pair in pairs) {
        NSArray *kv = [pair componentsSeparatedByString:@"="];
        if ([kv count] > 1) {
            NSString *val = [[kv objectAtIndex:1]
                             stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            [params setObject:val forKey:[kv objectAtIndex:0]];
        }
    }
    return params;
}

#pragma mark - Authentication methods
/*
 * Callback for session changes.
 */
- (void)sessionStateChanged:(FBSession *)session
                      state:(FBSessionState) state
                      error:(NSError *)error
{
    switch (state) {
        case FBSessionStateOpen:
            if (!error) {
                // We have a valid session
                //NSLog(@"User session found");
            }
            break;
        case FBSessionStateClosed:
            self.user = nil;
            break;
        case FBSessionStateClosedLoginFailed:
            self.user = nil;
            [FBSession.activeSession closeAndClearTokenInformation];
            break;
        default:
            break;
    }
    
    [[NSNotificationCenter defaultCenter]
     postNotificationName:FBSessionStateChangedNotification
     object:session];
    
    if (error) {
        UIAlertView *alertView = [[UIAlertView alloc]
                                  initWithTitle:@"Error"
                                  message:error.localizedDescription
                                  delegate:nil
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil];
        [alertView show];
    }
}

/*
 * Opens a Facebook session and optionally shows the login UX.
 */
- (BOOL)openSessionWithAllowLoginUI:(BOOL)allowLoginUI {
    // Ask for permissions for getting info about uploaded
    // custom photos.
    NSArray *permissions = [NSArray arrayWithObjects:
                            @"user_photos",
                            nil];
    
    return [FBSession openActiveSessionWithReadPermissions:permissions
                                          allowLoginUI:allowLoginUI
                                     completionHandler:^(FBSession *session,
                                                         FBSessionState state,
                                                         NSError *error) {
                                         [self sessionStateChanged:session
                                                             state:state
                                                             error:error];
                                     }];
}

/*
 * Closes the active Facebook session
 */
- (void) closeSession {
    [FBSession.activeSession closeAndClearTokenInformation];
}

#pragma mark - Personalization methods
/*
 * Makes a request for user data and invokes a callback
 */
- (void)requestUserData:(UserDataLoadedHandler)handler
{
    // If there is saved data, return this.
    if (nil != self.user) {
        if (handler) {
            handler(self, self.user);
        }
    } else if (FBSession.activeSession.isOpen) {
        [FBRequestConnection startForMeWithCompletionHandler:
         ^(FBRequestConnection *connection, NSDictionary<FBGraphUser> *user, NSError *error) {
             if (!error) {
                 // Update menu user info
                 self.menu.profileID = user.id;
                 // Save the user data
                 self.user = user;
                 if (handler) {
                     handler(self, self.user);
                 }
             }
         }];
    }
}

#pragma mark -
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [FBProfilePictureView class];
    [FBPlacePickerViewController class];
    [FBFriendPickerViewController class];
    // Override point for customization after application launch.
    
    // Initialze the beverage menu items
    [self initMenuItems];
    
    return YES;
}

- (BOOL)application:(UIApplication *)application 
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication 
         annotation:(id)annotation {
    
    // Save the incoming URL to test deep links later.
    self.openedURL = url;
    
    // We need to handle URLs by passing them to FBSession in order for SSO authentication
    // to work.
    return [FBSession.activeSession handleOpenURL:url];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    if (FBSession.activeSession.state == FBSessionStateCreatedOpening) {
        //[FBSession.activeSession close]; // so we close our session and start over
    }
    
    // Check for an incoming deep link and set the info in the Menu View Controller
    // Process the saved URL
    NSString *query = [self.openedURL fragment];
    if (!query) {
        query = [self.openedURL query];
    }
    NSDictionary *params = [self parseURLParams:query];
    // Check if target URL exists
    if ([params valueForKey:@"target_url"]) {
        // If the incoming link is a deep link then set things up to take the user to
        // the menu view controller (if necessary), then pass along the deep link. The
        // menu controller will take care of sending the user to the correct experience.
        NSString *targetURL = [params valueForKey:@"target_url"];
        
        // Get the navigation controller.
        UINavigationController *navController = (UINavigationController *) self.window.rootViewController;
        // Get the menu view controller, the first view controller
        MenuViewController *menuViewController =
        (MenuViewController *) [[navController viewControllers] objectAtIndex:0];
        
        // Call the view controller method to set the deep link
        [menuViewController initMenuFromUrl:targetURL];
        id currentController = [navController topViewController];
        // If necessary, pop to the menu view controller that is the
        // root view controller.
        if (![currentController isKindOfClass:[MenuViewController class]]) {
            // The menu view controller will handle the redirect
            [navController popToRootViewControllerAnimated:NO];
        } else {
            [menuViewController goToSelectedMenu];
        }
    }
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // if the app is going away, we close the session object
    [FBSession.activeSession close];
}

#pragma mark - Menu Data Load Delegate
- (void)menu:(Menu *)menu didLoadData:(NSDictionary *)results index:(NSUInteger)index
{
    [[NSNotificationCenter defaultCenter]
     postNotificationName:FBMenuDataChangedNotification
     object:results];
}

@end
