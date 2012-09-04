//
//  OrderLinkSegue.m
//  SocialCafe
//
//  Created by Christine Abernathy on 9/3/12.
//
//

#import "OrderLinkSegue.h"

@implementation OrderLinkSegue

/*
 * Override to have no animation for this segue
 */
- (void)perform
{    
    [[self.sourceViewController navigationController] pushViewController:self.destinationViewController animated:NO];
}

@end
