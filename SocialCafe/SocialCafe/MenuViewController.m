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

#import "MenuViewController.h"
#import "AppDelegate.h"
#import "OrderViewController.h"

@interface MenuViewController () 
<UITableViewDataSource,
UITableViewDelegate>

@property (strong, nonatomic) IBOutlet FBProfilePictureView *userProfilePictureView;
@property (strong, nonatomic) IBOutlet UILabel *userNameLabel;
@property (weak, nonatomic) IBOutlet UITableView *menuTableView;
@property (strong, nonatomic) NSDictionary<FBGraphUser> *user;
@property (strong, nonatomic) NSString *menuLink;
@property (assign, nonatomic) NSUInteger selectedMenuIndex;

- (void)sessionStateChanged:(NSNotification*)notification;
- (void)populateUserDetails;

@end

@implementation MenuViewController
@synthesize userProfilePictureView;
@synthesize userNameLabel;
@synthesize menuTableView;
@synthesize user = _user;
@synthesize menuLink = _menuLink;
@synthesize selectedMenuIndex = _selectedMenuIndex;

#pragma mark - Helper methods
/*
 * Configure the logged in versus logged out UX
 */
- (void)sessionStateChanged:(NSNotification*)notification {
    if (FBSession.activeSession.isOpen) {
        // If a deep link, go to the seleceted menu
        if (self.menuLink) {
            [self goToSelectedMenu];
        } else {
            [self populateUserDetails];
        }
    } else {
        [self performSegueWithIdentifier:@"SegueToLogin" sender:self];
    }
}

/*
 * Update the table view
 */
- (void)menuDataChanged:(NSNotification*)notification {
    [self.menuTableView reloadData];
}

- (void)populateUserDetails {
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    [appDelegate requestUserData:^(id sender, id<FBGraphUser> user) {
        self.userNameLabel.text = user.name;
        self.userProfilePictureView.profileID = [user objectForKey:@"id"];
    }];
}

/*
 * Set up the deep link URL
 */
- (void) initMenuFromUrl:(NSString *)url{
    self.menuLink = url;
}

/*
 * Go to a selected menu page due to a deep link
 */

- (void) goToSelectedMenu {
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    NSURL *menuLinkURL = [NSURL URLWithString:self.menuLink];

    // Find the menu that matches the deep link URL
    NSInteger menuIndex = -1;
    for (NSInteger i = 0; i < [appDelegate.menu.items count]; i++) {
        NSURL *checkURL = [NSURL URLWithString:
                           [[appDelegate.menu.items objectAtIndex:i]
                            objectForKey:@"url"]];
        if ([[menuLinkURL path] isEqualToString:[checkURL path]]) {
            menuIndex = i;
            break;
        }
    }
    self.menuLink = nil;
    // If a menu match found go to the order view controller
    if (menuIndex >= 0) {
        self.selectedMenuIndex = menuIndex;
        // Use the custom segue that does not have animation
        [self performSegueWithIdentifier:@"SegueToOrderLink" sender:self];
    }
}

#pragma mark - View life cycle
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    // Register for notifications on FB session state changes
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(sessionStateChanged:)
     name:FBSessionStateChangedNotification
     object:nil];
    
    // Register for notifications on menu data changes
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(menuDataChanged:)
     name:FBMenuDataChangedNotification
     object:nil];
}

- (void)viewDidUnload
{
    [self setUserProfilePictureView:nil];
    [self setUserNameLabel:nil];
    [self setMenuTableView:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (FBSession.activeSession.isOpen && (nil == self.menuLink)) {
        // If the user's session is active, personalize, but
        // only if this is not deep linking into the order view.
        [self populateUserDetails];
    } else if (FBSession.activeSession.state == FBSessionStateCreatedTokenLoaded) {
        // Check the session for a cached token to show the proper authenticated
        // UI. However, since this is not user intitiated, do not show the login UX.
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        [appDelegate openSessionWithAllowLoginUI:NO];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Present login modal if necessary after the view has been
    // displayed, not in viewWillAppear: so as to allow display
    // stack to "unwind"
    if (FBSession.activeSession.isOpen && self.menuLink) {
        [self goToSelectedMenu];
    } else if (FBSession.activeSession.isOpen ||
        FBSession.activeSession.state == FBSessionStateCreatedTokenLoaded ||
        FBSession.activeSession.state == FBSessionStateCreatedOpening) {
    } else {
        [self performSegueWithIdentifier:@"SegueToLogin" sender:self];
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation = UIInterfaceOrientationPortrait);
}

#pragma mark - UITableViewDatasource and UITableViewDelegate Methods
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 80.0;
}

// Customize the number of sections in the table view.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    return [appDelegate.menu.items count];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView
                             dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:CellIdentifier];
    }
    cell.imageView.image = [UIImage imageNamed:[[appDelegate.menu.items objectAtIndex:indexPath.row]
                                                objectForKey:@"picture"]];
    cell.textLabel.text = [[appDelegate.menu.items objectAtIndex:indexPath.row] objectForKey:@"title"];
    cell.textLabel.font = [UIFont fontWithName:@"Helvetica" size:20.0];
    if ([[appDelegate.menu.items objectAtIndex:indexPath.row] objectForKey:@"likeCount"] &&
        [[appDelegate.menu.items objectAtIndex:indexPath.row] objectForKey:@"orderCount"]) {
        int likePercentage =
        ([[[appDelegate.menu.items objectAtIndex:indexPath.row] objectForKey:@"likeCount"] doubleValue] /
         [[[appDelegate.menu.items objectAtIndex:indexPath.row] objectForKey:@"orderCount"] doubleValue]) * 100.0;
        cell.detailTextLabel.numberOfLines = 2;
        cell.detailTextLabel.text =
            [NSString stringWithFormat:@"%@ others enjoyed this.\n%d%% of orders enjoyed this.",
                                     [[appDelegate.menu.items
                                       objectAtIndex:indexPath.row]
                                      objectForKey:@"likeCount"],
                                     likePercentage];
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    self.selectedMenuIndex = [indexPath row];
    [self performSegueWithIdentifier:@"SegueToOrder" sender:self];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"SegueToOrder"] ||
        [segue.identifier isEqualToString:@"SegueToOrderLink"]) {
        // Go to the selected menu
        OrderViewController *ovc = (OrderViewController *)segue.destinationViewController;
        ovc.selectedMenuIndex = self.selectedMenuIndex;
        [self.menuTableView deselectRowAtIndexPath:[self.menuTableView indexPathForSelectedRow] animated:NO];
    }
}

#pragma mark - Action methods
- (IBAction)logoutButtonClicked:(id)sender {
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    [appDelegate closeSession];
}


@end
