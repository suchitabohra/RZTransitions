//
//  RZSimpleViewController.m
//  RZTransitions-Demo
//
//  Created by Stephen Barnes on 12/3/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import "RZSimpleViewController.h"
#import "RZSimpleColorViewController.h"
#import "RZSimpleCollectionViewController.h"

#import "RZTransitionsInteractionControllers.h"
#import "RZTransitionsAnimationControllers.h"
#import "RZTransitionInteractionControllerProtocol.h"
#import "RZTransitionsManager.h"

@interface RZSimpleViewController () <RZTransitionInteractionControllerDelegate>

@property (weak, nonatomic) IBOutlet UIButton *popButton;
@property (weak, nonatomic) IBOutlet UIButton *pushButton;
@property (weak, nonatomic) IBOutlet UIButton *modalButton;
@property (weak, nonatomic) IBOutlet UIButton *collectionViewButton;

@property (nonatomic, strong) id<RZTransitionInteractionController> pushPopInteractionController;
@property (nonatomic, strong) id<RZTransitionInteractionController> presentInteractionController;

@end

@implementation RZSimpleViewController

- (void)viewDidLoad
{
	// Create the push and pop interaction controller that allows a custom gesture
	// to control pushing and popping from the navigation controller
    self.pushPopInteractionController = [[RZHorizontalInteractionController alloc] init];
    [self.pushPopInteractionController setNextViewControllerDelegate:self];
    [self.pushPopInteractionController attachViewController:self withAction:RZTransitionAction_PushPop];
    [[RZTransitionsManager shared] setInteractionController:self.pushPopInteractionController
                                         fromViewController:[self class]
                                           toViewController:nil
                                                  forAction:RZTransitionAction_PushPop];
    

	// Create the presentation interaction controller that allows a custom gesture
	// to control presenting a new VC via a presentViewController
    self.presentInteractionController = [[RZVerticalSwipeInteractionController alloc] init];
    [self.presentInteractionController setNextViewControllerDelegate:self];
    [self.presentInteractionController attachViewController:self withAction:RZTransitionAction_Present];
//    [[RZTransitionsManager shared] setInteractionController:self.presentInteractionController
//                                         fromViewController:[self class]
//                                           toViewController:nil
//                                                  forAction:RZTransitionAction_Present];
    
	// Setup the push & pop animations as well as a special animation for pushing a
	// RZSimpleCollectionViewController
    [[RZTransitionsManager shared] setAnimationController:[[RZCardSlideAnimationController alloc] init]
                                       fromViewController:[self class]
                                                forAction:RZTransitionAction_PushPop];
    [[RZTransitionsManager shared] setAnimationController:[[RZZoomPushAnimationController alloc] init]
                                       fromViewController:[self class]
                                         toViewController:[RZSimpleCollectionViewController class]
                                                forAction:RZTransitionAction_PushPop];
    
	// Setup the animations for presenting and dismissing a new VC
    [[RZTransitionsManager shared] setAnimationController:[[RZCirclePushAnimationController alloc] init]
                                       fromViewController:[self class]
                                                forAction:RZTransitionAction_PresentDismiss];
}

- (void)viewWillAppear:(BOOL)animated
{
    [[RZTransitionsManager shared] setInteractionController:self.presentInteractionController
                                         fromViewController:[self class]
                                           toViewController:nil
                                                  forAction:RZTransitionAction_Present];
}

#pragma mark - Button Actions

- (IBAction)pushNewViewController:(id)sender
{
    [[self navigationController] pushViewController:[self nextSimpleViewController] animated:YES];
}

- (IBAction)popViewController:(id)sender
{
    [[self navigationController] popViewControllerAnimated:YES];
}

- (IBAction)showModal:(id)sender
{
    [self presentViewController:[self nextSimpleColorViewController] animated:YES completion:nil];
}

- (IBAction)showCollectionView:(id)sender
{
    [[self navigationController] pushViewController:[[RZSimpleCollectionViewController alloc] init] animated:YES];
}

#pragma mark - Next View Controller Logic

- (UIViewController *)nextSimpleViewController
{
    RZSimpleViewController* newVC = [[RZSimpleViewController alloc] init];
    [newVC setTransitioningDelegate:[RZTransitionsManager shared]];
    return newVC;
}

- (UIViewController *)nextSimpleColorViewController
{
    RZSimpleColorViewController* newColorVC = [[RZSimpleColorViewController alloc] init];
    [newColorVC setTransitioningDelegate:[RZTransitionsManager shared]];
    
    // Create a dismiss interaction controller that will be attached to the presented
	// view controller to allow for a custom dismissal
    RZVerticalSwipeInteractionController *dismissInteractionController = [[RZVerticalSwipeInteractionController alloc] init];
    [dismissInteractionController attachViewController:newColorVC withAction:RZTransitionAction_Dismiss];
    [[RZTransitionsManager shared] setInteractionController:dismissInteractionController
                                         fromViewController:[self class]
                                           toViewController:nil
                                                  forAction:RZTransitionAction_Dismiss];
    return newColorVC;
}

#pragma mark - RZTransitionInteractorDelegate

- (UIViewController *)nextViewControllerForInteractor:(id<RZTransitionInteractionController>)interactor
{
    // TODO: Check if it is a vertical or a horizontal and return the appropriate VC for the interactor
    if ([interactor isKindOfClass:[RZVerticalSwipeInteractionController class]]) {
        return [self nextSimpleColorViewController];
    }
	else {
        return [self nextSimpleViewController];
    }
}

@end
