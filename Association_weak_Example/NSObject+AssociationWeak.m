//
//  NSObject+AssociationWeak.m
//
//  Created by 马文帅 on 2020/7/24.
//  Copyright © 2020 马文帅. All rights reserved.
//

#import "NSObject+AssociationWeak.h"
#import "objc/runtime.h"

@implementation NSObject (AssociationWeak)

void objc_setAssociatedObject_weak(id _Nonnull object, const void * _Nonnull key, id _Nullable value) {
    
    //子类的名字
    NSString *name = [NSString stringWithFormat:@"AssociationWeak_%@", NSStringFromClass([value class])];
    Class class = objc_getClass(name.UTF8String);
    
    //如果子类不存在，动态创建子类
    if (!class) {
        class = objc_allocateClassPair([value class], name.UTF8String, 0);
        objc_registerClassPair(class);
    }
    
    SEL deallocSEL = NSSelectorFromString(@"dealloc");
    Method deallocMethod = class_getInstanceMethod([value class], deallocSEL);
    const char *types = method_getTypeEncoding(deallocMethod);
    
    //在子类dealloc方法中将object的指针置为nil
    IMP imp = imp_implementationWithBlock(^(id _s, int k) {
        
#ifdef DEBUG
        NSLog(@"-dealloc-\nvalue = %@", _s);
#endif
        objc_setAssociatedObject(object, key, nil, OBJC_ASSOCIATION_ASSIGN);
    });
    
    //添加子类的dealloc方法
    class_addMethod(class, deallocSEL, imp, types);
    
    //将value的isa指向动态创建的子类
    object_setClass(value, class);
    
    objc_setAssociatedObject(object, key, value, OBJC_ASSOCIATION_ASSIGN);
}

@end
