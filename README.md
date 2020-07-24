## iOS中objc_setAssociatedObject关联对象自动置空

### 前言
有点经验的iOS开发者都知道，ARC中的weak关键字可以在对象销毁时 指针自动置成nil，在OC中向nil发消息是安全的，所以不会造成野指针错误。

在category中扩展属性时，一般会使用runtime的关联对象（AssociatedObject）技术，关联对象的策略（Policy）有5个：

```
OBJC_ASSOCIATION_ASSIGN = 0, //弱引用
OBJC_ASSOCIATION_RETAIN_NONATOMIC = 1,//强引用，非原子性
OBJC_ASSOCIATION_COPY_NONATOMIC = 3,//copy，非原子性
OBJC_ASSOCIATION_RETAIN = 01401,//强引用，原子性
OBJC_ASSOCIATION_COPY = 01403//copy，原子性
```

我们可以发现，在5个策略中并没有weak类型，**OBJC_ASSOCIATION_ASSIGN** 策略虽然可以弱引用，但是在对象销毁的时候不能自动将指针置nil。

### 现象举例
我们使用Category给UIViewController扩展一个UILabel类型的属性aLabel，并使用**OBJC_ASSOCIATION_ASSIGN** 策略，看看会发生什么。代码如下：

```
//  UIViewController+Category.h
@interface UIViewController (Category)

@property (nonatomic, strong) UILabel *aLabel;

@end

//  UIViewController+Category.m
@implementation UIViewController (Category)

- (void)setALabel:(UILabel *)aLabel {
    objc_setAssociatedObject(self, @selector(aLabel), aLabel, OBJC_ASSOCIATION_ASSIGN);
}

- (UILabel *)aLabel {
    return objc_getAssociatedObject(self, @selector(aLabel));
}

@end

```
然后赋值使用：

```
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

```
在viewDidLoad方法中对aLabel进行了赋值，出了viewDidLoad作用域后，aLabel指向的对象会被销毁。运行后，我们发现程序崩溃了。打开僵尸对象调试，报错如下：

```
*** -[UILabel retain]: message sent to deallocated instance
```
对象被销毁了，指针没有置nil，造成了崩溃。

### 解决方案
我们需要做的是在获取到对象销毁的时机，然后将相应的指针指向nil。如果是我们自己创建的类，可以在dealloc方法中进行block回调。但是系统早已创建好的类，开发者没有地方可以写dealloc回调。

与苹果系统对KVO的实现原理[参考我这篇文章](https://www.jianshu.com/p/0bbc0c15add9)类似，我们可以在属性的set方法中，动态创建一个关联对象的子类，重写新类的dealloc方法，在新类的dealloc中将指针置nil，并将关联对象的isa指针指向新类。

沿着这个思路，我们可以写出以下代码：

```
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
        objc_setAssociatedObject(object, key, nil, OBJC_ASSOCIATION_ASSIGN);
    });
    
    //添加子类的dealloc方法
    class_addMethod(class, deallocSEL, imp, types);
    
    //将value的isa指向动态创建的子类
    object_setClass(value, class);
    
    objc_setAssociatedObject(object, key, value, OBJC_ASSOCIATION_ASSIGN);
}
```
在进行关联对象的操作时，我们使用自己新写的方法，不再使用系统关联对象方法：

```
- (void)setALabel:(UILabel *)aLabel {
    objc_setAssociatedObject_weak(self, @selector(aLabel), aLabel);
    
```
再运行程序看看打印结果：

```
-viewDidLoad-
self.aLabel = <AssociationWeak_UILabel: 0x7fd174f0b770; baseClass = UILabel; frame = (0 0; 0 0); userInteractionEnabled = NO; layer = <_UILabelLayer: 0x600000818780>>

-viewDidAppear-
self.aLabel = (null)
```

我们发现这样成功捕捉到了对象被销毁的时机，并将指针指向了nil，没有出现崩溃的情况。

至此，我们成功做到了弱引用对象销毁后，指针自动置空的操作。我将方法封装到了NSObject的分类中。任何继承自NSObject的OC对象，在关联对象时，都可以使用。