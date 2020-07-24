//
//  UIViewController+Category.m
//
//  Created by 马文帅 on 2020/7/23.
//  Copyright © 2020 马文帅. All rights reserved.
//

#import "UIViewController+Category.h"
#import "NSObject+AssociationWeak.h"
#import "objc/runtime.h"

@implementation UIViewController (Category)

- (void)setALabel:(UILabel *)aLabel {
    objc_setAssociatedObject_weak(self, @selector(aLabel), aLabel);
    
    
    //使用系统的方法会崩溃
    //-[UILabel retain]: message sent to deallocated instance
    
//    objc_setAssociatedObject(self, @selector(aLabel), aLabel, OBJC_ASSOCIATION_ASSIGN);
}

- (UILabel *)aLabel {
    return objc_getAssociatedObject(self, @selector(aLabel));
}

@end
