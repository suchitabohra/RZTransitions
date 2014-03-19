//
//  RZTransitionsManager.m
//
//  Created by Stephen Barnes on 3/12/14.
//

#import "RZTransitionsManager.h"
#import "RZAnimationControllerProtocol.h"
#import "RZUniqueTransition.h"
#import "RZTransitionInteractionControllerProtocol.h"

static NSString* const kRZTTransitionsAnyViewControllerKey = @"kRZTTransitionsAnyViewControllerKey";
static NSString* const kRZTTransitionsKeySpacer = @"_";

@interface RZTransitionsManager ()

@property (strong, nonatomic) NSMutableDictionary *animationControllers;
@property (strong, nonatomic) NSMutableDictionary *interactionControllers;

@end

@implementation RZTransitionsManager

+ (RZTransitionsManager *)shared
{
    static RZTransitionsManager *_defaultManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _defaultManager = [[[self class] alloc] init];
    });
    
    return _defaultManager;
}

- (id)init
{
    self = [super init];
    if (self) {
        self.animationControllers = [[NSMutableDictionary alloc] init];
        self.interactionControllers = [[NSMutableDictionary alloc] init];
    }
    return self;
}

#pragma mark - Public API Set Animations and Interactions

- (void)setAnimationController:(id<RZAnimationControllerProtocol>)animationController
            fromViewController:(Class)fromViewController
                     forAction:(RZTransitionAction)action
{
    [self setAnimationController:animationController fromViewController:fromViewController toViewController:nil forAction:action];
}

- (void)setAnimationController:(id<RZAnimationControllerProtocol>)animationController
            fromViewController:(Class)fromViewController
              toViewController:(Class)toViewController
                     forAction:(RZTransitionAction)action
{
    for (NSUInteger x = 1; (x < (1 << (kRZTransitionActionCount - 1))); )
    {
        if (action & x) {
            RZUniqueTransition *keyValue = nil;
            if (x & RZTransitionAction_Pop || x & RZTransitionAction_Dismiss) {
                keyValue = [[RZUniqueTransition alloc] initWithAction:x withFromViewControllerClass:toViewController withToViewControllerClass:fromViewController];
            }
            else {
                keyValue = [[RZUniqueTransition alloc] initWithAction:x withFromViewControllerClass:fromViewController withToViewControllerClass:toViewController];
            }
            [self.animationControllers setObject:animationController forKey:keyValue];
        }
        x = x << 1;
    }
}

- (void)setInteractionController:(id<RZTransitionInteractionController>)interactionController
              fromViewController:(Class)fromViewController
                toViewController:(Class)toViewController
                       forAction:(RZTransitionAction)action
{
    for (NSUInteger x = 1; (x < (1 << (kRZTransitionActionCount - 1))); )
    {
        if (action & x) {
            RZUniqueTransition *keyValue = nil;
            if (x & RZTransitionAction_Pop || x & RZTransitionAction_Dismiss) {
                keyValue = [[RZUniqueTransition alloc] initWithAction:x withFromViewControllerClass:toViewController withToViewControllerClass:fromViewController];
            }
            else {
                keyValue = [[RZUniqueTransition alloc] initWithAction:x withFromViewControllerClass:fromViewController withToViewControllerClass:toViewController];
            }
            
            [self.interactionControllers setObject:interactionController forKey:keyValue];
        }
        x = x << 1;
    }
}

#pragma mark - UIViewControllerTransitioningDelegate

- (id <UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source
{    
    RZUniqueTransition *keyValue = [[RZUniqueTransition alloc] initWithAction:RZTransitionAction_Present withFromViewControllerClass:[source class] withToViewControllerClass:[presented class]];
    id<RZAnimationControllerProtocol> animationController = (id<RZAnimationControllerProtocol>)[self.animationControllers objectForKey:keyValue];
    if (animationController == nil) {
        keyValue.toViewControllerClass = nil;
        animationController = (id<RZAnimationControllerProtocol>)[self.animationControllers objectForKey:keyValue];
    }
    if (animationController == nil) {
        animationController = self.defaultPresentDismissAnimationController;
    }
    
    if (animationController) {
        animationController.isPositiveAnimation = YES;
    }

    return animationController;
}

- (id <UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed
{
    RZUniqueTransition *keyValue = [[RZUniqueTransition alloc] initWithAction:RZTransitionAction_Dismiss withFromViewControllerClass:[dismissed class] withToViewControllerClass:nil];
    id<RZAnimationControllerProtocol> animationController = nil;
    
    // Find the dismissed view controller's view controller it is returning to
    UIViewController *presentingViewController = dismissed.presentingViewController;
    if ([presentingViewController isKindOfClass:[UINavigationController class]]) {
        UIViewController *childVC = (UIViewController *)[[presentingViewController childViewControllers] lastObject];
        if (childVC != nil) {
            keyValue.toViewControllerClass = [childVC class];
            animationController = (id<RZAnimationControllerProtocol>)[self.animationControllers objectForKey:keyValue];
            if (animationController == nil) {
                keyValue.toViewControllerClass = nil;
                animationController = (id<RZAnimationControllerProtocol>)[self.animationControllers objectForKey:keyValue];
            }
            if (animationController == nil) {
                keyValue.toViewControllerClass = [childVC class];
                keyValue.fromViewControllerClass = nil;
                animationController = (id<RZAnimationControllerProtocol>)[self.animationControllers objectForKey:keyValue];
            }
        }
    }
    if (animationController == nil) {
        keyValue.toViewControllerClass = nil;
        keyValue.fromViewControllerClass = [dismissed class];
        animationController = (id<RZAnimationControllerProtocol>)[self.animationControllers objectForKey:keyValue];
    }
    if (animationController == nil) {
        animationController = self.defaultPresentDismissAnimationController;
    }
    
    if (animationController != nil) {
        animationController.isPositiveAnimation = NO;
    }
    
    return animationController;
}

- (id <UIViewControllerInteractiveTransitioning>)interactionControllerForPresentation:(id <UIViewControllerAnimatedTransitioning>)animator
{
    // Find the animator in the animationcontrollers list
    // Get **ITS** from and to VC information!
    __block id returnInteraction = nil;
    [self.animationControllers enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        id<RZAnimationControllerProtocol> animationController = (id<RZAnimationControllerProtocol>)obj;
        RZUniqueTransition *keyValue = (RZUniqueTransition *)key;
        if ( animator == animationController && keyValue.transitionAction & RZTransitionAction_Present ) {
            id<RZTransitionInteractionController> interactionController = (id<RZTransitionInteractionController>)[self.interactionControllers objectForKey:keyValue];
            if (interactionController == nil) {
                keyValue.toViewControllerClass = nil;
                interactionController = (id<RZTransitionInteractionController>)[self.interactionControllers objectForKey:keyValue];
            }
            if( (interactionController != nil) && (interactionController.isInteractive)) {
                returnInteraction = interactionController;
                *stop = YES;
            }
        }
    }];
    
    return returnInteraction;
}

- (id <UIViewControllerInteractiveTransitioning>)interactionControllerForDismissal:(id <UIViewControllerAnimatedTransitioning>)animator
{
    __block id returnInteraction = nil;
    [self.animationControllers enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        id<RZAnimationControllerProtocol> animationController = (id<RZAnimationControllerProtocol>)obj;
        RZUniqueTransition *keyValue = (RZUniqueTransition *)key;
        if ( animator == animationController && keyValue.transitionAction & RZTransitionAction_Dismiss ) {
            id<RZTransitionInteractionController> interactionController = (id<RZTransitionInteractionController>)[self.interactionControllers objectForKey:keyValue];
            if (interactionController == nil) {
                keyValue.fromViewControllerClass = nil;
                interactionController = (id<RZTransitionInteractionController>)[self.interactionControllers objectForKey:keyValue];
            }
            if( (interactionController != nil) && (interactionController.isInteractive)) {
                returnInteraction = interactionController;
                *stop = YES;
            }
        }
    }];
    
    return returnInteraction;
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    
}

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{

}

- (id <UIViewControllerInteractiveTransitioning>)navigationController:(UINavigationController *)navigationController
                          interactionControllerForAnimationController:(id <UIViewControllerAnimatedTransitioning>) animationController
{
    return [self interactionControllerForAction:RZTransitionAction_PushPop withAnimationController:animationController];
}

- (id <UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController
                                   animationControllerForOperation:(UINavigationControllerOperation)operation
                                                fromViewController:(UIViewController *)fromVC
                                                  toViewController:(UIViewController *)toVC
{
    RZUniqueTransition *keyValue = [[RZUniqueTransition alloc] initWithAction:(operation == UINavigationControllerOperationPush) ? RZTransitionAction_Push : RZTransitionAction_Pop
                                                  withFromViewControllerClass:[fromVC class]
                                                    withToViewControllerClass:[toVC class]];
	id<RZAnimationControllerProtocol> animationController = (id<RZAnimationControllerProtocol>)[self.animationControllers objectForKey:keyValue];
    if (animationController == nil) {
        keyValue.toViewControllerClass = nil;
        animationController = (id<RZAnimationControllerProtocol>)[self.animationControllers objectForKey:keyValue];
    }
    if (animationController == nil) {
        keyValue.toViewControllerClass = [toVC class];
        keyValue.fromViewControllerClass = nil;
        animationController = (id<RZAnimationControllerProtocol>)[self.animationControllers objectForKey:keyValue];
    }
    if (animationController == nil) {
        animationController = self.defaultPushPopAnimationController;
    }
		
    if (operation == UINavigationControllerOperationPush) {
        animationController.isPositiveAnimation = YES;
    } else if (operation == UINavigationControllerOperationPop)	{
        animationController.isPositiveAnimation = NO;
    }
    
    return animationController;
}

#pragma mark - UIInteractionController Caching

- (id <UIViewControllerInteractiveTransitioning>)interactionControllerForAction:(RZTransitionAction)action withAnimationController:(id <UIViewControllerAnimatedTransitioning>)animationController
{
    for (RZUniqueTransition *key in self.interactionControllers) {
        id<RZTransitionInteractionController> interactionController = [self.interactionControllers objectForKey:key];
        if ((interactionController.action & action) && [interactionController isInteractive]) {
            return interactionController;
        }
    }
    
    return nil;
}

#pragma mark - UITabBarControllerDelegate

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController
{
    
}

- (id <UIViewControllerInteractiveTransitioning>)tabBarController:(UITabBarController *)tabBarController
                      interactionControllerForAnimationController:(id <UIViewControllerAnimatedTransitioning>)animationController
{
    return [self interactionControllerForAction:RZTransitionAction_Tab withAnimationController:animationController];
}

- (id <UIViewControllerAnimatedTransitioning>)tabBarController:(UITabBarController *)tabBarController
            animationControllerForTransitionFromViewController:(UIViewController *)fromVC
                                              toViewController:(UIViewController *)toVC
{
    RZUniqueTransition *keyValue = [[RZUniqueTransition alloc] initWithAction:RZTransitionAction_Tab withFromViewControllerClass:[fromVC class] withToViewControllerClass:[toVC class]];
    id<RZAnimationControllerProtocol> animationController = (id<RZAnimationControllerProtocol>)[self.animationControllers objectForKey:keyValue];
    if (animationController == nil) {
        keyValue.toViewControllerClass = nil;
        animationController = (id<RZAnimationControllerProtocol>)[self.animationControllers objectForKey:keyValue];
    }
    if (animationController == nil) {
        animationController = self.defaultTabBarAnimationController;
    }
    
    NSUInteger fromVCIndex = [tabBarController.viewControllers indexOfObject:fromVC];
    NSUInteger toVCIndex = [tabBarController.viewControllers indexOfObject:toVC];
    
    if (animationController)
    {
        animationController.isPositiveAnimation = (fromVCIndex > toVCIndex);
    }

    return animationController;
}

@end
