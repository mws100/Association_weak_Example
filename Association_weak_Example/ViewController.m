//
//  ViewController.m
//  Association_weak_Example
//
//  Created by 马文帅 on 2020/7/24.
//  Copyright © 2020 马文帅. All rights reserved.
//

#import "ViewController.h"
#import "UIViewController+Category.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor orangeColor];
    
    UILabel *label = [[UILabel alloc] init];
    self.aLabel = label;
    
    NSLog(@"-viewDidLoad-\nself.aLabel = %@", self.aLabel);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    NSLog(@"-viewDidAppear-\nself.aLabel = %@", self.aLabel);
}


@end
