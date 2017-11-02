# 消息

关键点:

1. 方法调用 = 消息接收
2. 消息发送的机制 （即`lookUpImpOrForward`方法的处理逻辑）
3. 动态方法的解析
4. 消息转发的机制（即重定向和`forwardInvocation:`）
5. 利用消息转发可以做的骚事情

## objc_msgSend(id self, SEL op)

当我们在代码上调用某个方法时 例如[receiver message] 其实在经过编译后 会转化为:

objc_msgSend(receiver,@selector(message))

**方法调用**其实是**消息接收** 如果消息的接受者能够找到对应的`selector` 那么就等于直接执行接收者这个对象的特定方法；否则，消息要么临时向接收者动态添加这个`selector`对应的实现内容 或是消息被转发 或者最后直接崩溃掉

所以说当调用[receiver message]时 只是向接受者发送`message`消息 而receiver要怎么相应该消息 就要看运行时发生的情况来判断了

#### id

`objc_msgSend`函数第一个参数为`id`  它是一个指向结构体为`objc_object`的指针

#### SEL

`objc_msgSend`函数第二个参数类型为`SEL`  可以理解是方法的ID 而这个ID的数据结构为SEL(也会被称为方法选择器)

```c
typedef struct objc_object *id;
```

不同类中相同名字的方法所对应的方法选择器是相同的 即使方法名字相同而变量类型不同也会导致它们具有相同的方法选择器，于是Objc中方法命名有时候会带上参数类型

#### IMP

在上一篇Property && Method中的`Method_t`的结构体提到过 现在回来补充啦～

```c
typedef void (*IMP)(void /* id, SEL, ... */ );
```

它就是一个函数指针 由编译器生成的 当你发起一个Objc消息之后 最终它会执行的那段代码 就是由这个函数指针指定的。而`IMP`这个函数指针就指向了这个方法的**实现** 既然得到了执行某个实例某个方法的入口，我们就可以绕开消息传递阶段 直接执行方法 这在后面会提到

你会发现`IMP`指向的方法与`objc_msgSend`函数类型相同，参数都包含`id`和`SEL`类型，每个方法名对应一个`SEL`类型的方法选择器 而每个实例对象中`SEL`对应的**方法实现**肯定是唯一的 所以通过一组`id`和`SEL`参数就能确定唯一的方法实现地址

#### cache

之前在Property && Method中有讲过`objc_class`的结构

![objc_class](http://vanney9.com/lionheart/1706/bits.png)

`cache` 为方法调用的性能进行优化，通俗地讲，每当实例对象接收到一个消息时，它不会直接在`isa`指向的类的方法列表中遍历查找能够响应消息的方法，因为这样效率太低了，而是优先在 `cache` 中查找。Runtime 系统会把被调用的方法存到 `cache` 中（理论上讲一个方法如果被调用，那么它有可能今后还会被调用），下次查找的时候效率更高。

## 消息发送的机制

消息发送的步骤：（即lookUpImpOrForward方法的执行步骤）

1. 检测这个 `selector` 是不是要忽略的。比如 Mac OS X 开发，有了垃圾回收就不理会 `retain`, `release` 这些函数了。
2. 检测这个 target 是不是 `nil` 对象。ObjC 的特性是允许对一个 `nil` 对象执行任何一个方法不会 Crash，因为会被忽略掉。
3. 如果上面两个都过了，那就开始查找这个类的 `IMP`，先从 `cache` 里面找，完了找得到就跳到对应的函数去执行。
4. 如果 `cache` 找不到就找一下方法分发表。
5. 如果分发表找不到就到父类找，也是先去父类的`cache`里面找 然后再到方法分发表 一直找，直到找到`NSObject`类为止。 
6. 如果还找不到就要开始进入**动态方法**解析了，后面会提到。

PS:这里说的分发表其实就是`Class`中的方法列表，它将方法选择器和方法实现地址联系起来。 

![img](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Art/messaging1.gif)

#### 方法中的隐藏参数

我们经常在方法中使用`self`关键字来引用实例本身，但从没有想过为什么`self`就能取到调用当前方法的对象吧。其实`self`的内容是在方法运行时被偷偷的动态传入的。 

当`objc_msgSend`找到方法对应的实现时，它将直接调用该方法实现，并将消息中所有的参数都传递给方法实现,同时,它还将传递两个隐藏的参数: 

- 接收消息的对象（也就是`self`指向的内容）
- 方法选择器（`_cmd`指向的内容）

之所以说它们是隐藏的是因为在源代码方法的定义中并没有声明这两个参数。它们是在代码被编译时被插入实现中的。尽管这些参数没有被明确声明，在源代码中我们仍然可以引用它们。在下面的例子中，`self`引用了接收者对象，而`_cmd`引用了方法本身的选择器：

```objective-c
- strange
{
    id  target = getTheReceiver();
    SEL method = getTheMethod();
 
    if ( target == self || method == _cmd )
        return nil;
    return [target performSelector:method];
}
```

在这两个参数中，`self` 更有用。实际上,它是在方法实现中访问消息接收者对象的实例变量的途径。 

####  获取方法地址

在`IMP`那节提到过可以避开消息绑定而直接获取方法的地址并调用方法。这种做法很少用，除非是需要持续大量重复调用某方法的极端情况，避开消息发送泛滥而直接调用该方法会更高效。 

`NSObject`类中有个`methodForSelector:`实例方法，你可以用它来获取某个方法选择器对应的`IMP`，举个栗子：

```objective-c
void (*setter)(id, SEL, BOOL);
int i;
 
setter = (void (*)(id, SEL, BOOL))[target
    methodForSelector:@selector(setFilled:)];
for ( i = 0 ; i < 1000 ; i++ )
    setter(targetList[i], @selector(setFilled:), YES);

```

## 动态方法解析

你可以动态地提供一个方法的实现。例如我们可以用`@dynamic`关键字在类的实现文件中修饰一个属性： 

```objective-c
@dynamic propertyName;
```

这表明我们会为这个属性动态提供存取方法，也就是说编译器不会再默认为我们生成`setPropertyName:`和`propertyName`方法，而需要我们动态提供。我们可以通过分别重载`resolveInstanceMethod:`和`resolveClassMethod:`方法分别添加实例方法实现和类方法实现。

因为当 Runtime 系统在`Cache`和方法分发表中（包括超类）找不到要执行的方法时，Runtime会调用`resolveInstanceMethod:`或`resolveClassMethod:`来给程序员一次动态添加方法实现的机会。

我们需要用`class_addMethod`函数完成向特定类添加特定方法实现的操作：

```objective-c
void dynamicMethodIMP(id self, SEL _cmd) {
    // implementation ....
}
@implementation MyClass
+ (BOOL)resolveInstanceMethod:(SEL)aSEL
{
    if (aSEL == @selector(resolveThisMethodDynamically)) {
          class_addMethod([self class], aSEL, (IMP) dynamicMethodIMP, "v@:");
          return YES;
    }
    return [super resolveInstanceMethod:aSEL];
}
@end
```

在这一个resolve方法里面，给类新增加了一个方法。

执行完resolve方法之后，会重新进行一次方法的查找。如果找到方法了，执行

上面的例子为`resolveThisMethodDynamically`方法添加了实现内容，也就是`dynamicMethodIMP`方法中的代码。其中 “`v@:`” 表示返回值和参数

PS：动态方法解析会在消息转发机制浸入前执行。如果 `respondsToSelector:` 或 `instancesRespondToSelector:`方法被执行，动态方法解析器将会被调用 首先给予一个提供该方法选择器对应的`IMP`的机会。如果你想让该方法选择器被传送到转发机制，那么就让`resolveInstanceMethod:`返回**NO**

针对类方法的动态方法替换 看下面的例子：

```objective-c
+ (BOOL)resolveClassMethod:(SEL)sel {
    if (sel == @selector(learnClass:)) {
        class_addMethod(object_getClass(self), sel, class_getMethodImplementation(object_getClass(self), @selector(myClassMethod:)), "v@:");
        return YES;
    }
    return [class_getSuperclass(self) resolveClassMethod:sel];
}

+ (BOOL)resolveInstanceMethod:(SEL)aSEL
{
    if (aSEL == @selector(goToSchool:)) {
        class_addMethod([self class], aSEL, class_getMethodImplementation([self class], @selector(myInstanceMethod:)), "v@:");
        return YES;
    }
    return [super resolveInstanceMethod:aSEL];
}
```

问题出在于 对于类和实例对象的时候 是应该用[self class]还是object_getClass(self)

其实对于实例对象来说 增加方法其实是在类中增加 即objc_class中

对于类来说 增加方法就是在元类中增加 所以主要是获取元类

不过在处理上是要看`self`的类型

1. 当`self`是实例对象时 `[self class]` 与 `object_getClass(self)` 等价，因为前者会调用后者 获得到的即是类对象 object_getClass([self class])则获取到的是元类
2. 当`self`是类时 [self class] 返回自身 即`self `    `object_getClass(self)` 与 `object_getClass([self class])` 等价 即获取到的是元类

## 消息转发

![img](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20141113-1@2x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)

#### 重定向(备援对象)

在消息转发机制前，Runtime 系统会再给我们一次偷梁换柱的机会，即通过重载`- (id)forwardingTargetForSelector:(SEL)aSelector`方法替换消息的接收者为其他对象：

```objective-c
- (id)forwardingTargetForSelector:(SEL)aSelector
{
    if(aSelector == @selector(mysteriousMethod:)){
        return alternateObject;
    }
    return [super forwardingTargetForSelector:aSelector];
}
```

注意：这个被替换的对象需要要有这个方法！！

如果想替换**类方法**的接受者，需要覆写 `+ (id)forwardingTargetForSelector:(SEL)aSelector` 方法，并返回**类对象**：

```objective-c
+ (id)forwardingTargetForSelector:(SEL)aSelector {
	if(aSelector == @selector(xxx)) {
		return NSClassFromString(@"Class name");
	}
	return [super forwardingTargetForSelector:aSelector];
}
```

## 转发

当重定向返回nil时 就会进入最终的消息转发机制会被调用`forwardInvocation:`我们可以重写这个方法来定义我们的转发逻辑

```objective-c
- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    if ([someOtherObject respondsToSelector:
            [anInvocation selector]])
        [anInvocation invokeWithTarget:someOtherObject];
    else
        [super forwardInvocation:anInvocation];
}
```

该消息的唯一参数是个`NSInvocation`类型的对象——该对象封装了原始的消息和消息的参数。我们可以实现`forwardInvocation:`方法来对不能处理的消息做一些默认的处理，也可以将消息转发给其他对象来处理，而不抛出错误。 

这里需要注意的是参数`anInvocation`是从哪的来的呢？其实在`forwardInvocation:`消息发送前，Runtime系统会向对象发送`methodSignatureForSelector:`消息，并取到返回的方法签名用于生成`NSInvocation`对象。所以我们在重写`forwardInvocation:`的同时也要重写`methodSignatureForSelector:`方法，否则会抛异常。 

```objective-c
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    NSLog(@"vanney code log : selector is %@", NSStringFromSelector(aSelector));
    NSMethodSignature *methodSignature = [super methodSignatureForSelector:aSelector];
    if (!methodSignature) {
        NSLog(@"vanney code log : inside create method signature");
        methodSignature = [NSMethodSignature signatureWithObjCTypes:"v@:i"];
    }

    return methodSignature;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    NSLog(@"vanney code log : forwarding invocation selector is %@", NSStringFromSelector(anInvocation.selector));
    NSLog(@"vanney code log : invocation is %@, and method signature is %@", anInvocation, anInvocation.methodSignature);

    if (anInvocation.selector == @selector(needFinalForward)) {
        NSLog(@"vanney code log : inside forwarding");
        anInvocation.selector = NSSelectorFromString(@"beitaiForwarding:");
        int *a;
        *a = 99;
        [anInvocation setArgument:a atIndex:2];
        HCBeiTai *beiTai = [[HCBeiTai alloc] init];
        [anInvocation invokeWithTarget:beiTai];
    } else {
        NSLog(@"vanney code log : else forwarding");
        [super forwardInvocation:anInvocation];
    }

}
```

而且注意一点： 在给方法做签名的时候 假如没实现的方法 签名是空的 签名不为空 才会调用 `forwardInvocation`方法 而且给方法签名时 类似**@@:**

`forwardInvocation:`方法就像一个不能识别的消息的分发中心，将这些消息转发给不同接收对象。或者它也可以象一个运输站将所有的消息都发送给同一个接收对象。它可以将一个消息翻译成另外一个消息，或者简单的”吃掉“某些消息，因此没有响应也没有错误。`forwardInvocation:`方法也可以对不同的消息提供同样的响应，这一切都取决于方法的具体实现。该方法所提供是将不同的对象链接到消息链的能力。 

**区别** 我觉得跟重定向的不同在于 重定向转发的消息接收者需要是有所转发的方法的实现 而`forwardInvocation`却是没有任何限制 想怎么转发都可以

**整个流程**：

1. 先看看这个`selector`是不是要被忽略的
2. 然后看看这个`id`是不是nil
3. 然后就去当前类的`cache`寻找 有就调用
4. 没有就去方法列表寻找 有就调用
5. 然后就去父类的`cache`寻找 有就调用
6. 没有就去父类的方法列表寻找 有就调用
7. 假如到了根类了没找到 就进入动态方法解析 （就是给特定类给予特定方法实现）
8. 动态方法假如返回 No 则进入重定向 (就是转换接收者为拥有该`selector`的其他对象)
9. 假如重定向返回nil 则进入最终的消息转发 （即`forwardInvocation:`）
10. 假如在这里都没有任何措施 则直接崩溃处理

## 通过利用消息转发的案例

### 1.多继承

![img](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Art/forwarding.gif)

比如说 通过消息转发 让本来不是在同一继承体系下的两个类 warrior和diplomat  在warrios并没有negotiate方法的情况下转发给Diplomat并调用 [Diplomat negotlate] 从而看上去好像继承一样

这样的处理 它既弥补了Objc不支持多继承的性质 也避免了因为多继承导致单个类变得拥挤复杂 它将问题分解得很细 只针对想要借鉴的方法才转发 而且转发机制是透明的

### 2.替代者对象(Surrogate Objects)

消息转发 不仅参照了多继承，它还让用轻量级对象代替重量级对象成为了可能。
通过代理（Surrogate）可以为对象筛选消息。

代理管理发送到接收者的消息,确定参数值被复制，拯救等等。但是它不企图去做很多其他的，它不重复对象的功能只是简单地提供对象一个可以接收来自其他应用消息的地址。

举个例子，有一个重量级对象，里面加入了许多大型数据，如图片视频等，每次使用这个对象的时候都需要读取磁盘上的内容，需要消耗很多时间（time-consuming），所以我们更偏向于采用懒加载模式。

在这样的情况下，你可以初始化一个简单的轻量级对象来代理(surrogate)它。利用代理对象可以做到例如查询数据信息等，而不用加载一整个重量级对象。如果是直接用重量级对象的话，它会一直被持有占用资源。当代理的forwardInvocation:方法第一次接收消息的时候，它会确保对象是否存在，如果不存在边创建一个。
当这个代理对象发送的消息覆盖了这个重量级对象的所有功能时，这个代理对象就相当于和重量级对象一样。

创建一个轻量级的对象来代理一个重量级对象，完成相对应的功能，而不用一直持有着重量级对象，从而可以减少资源占用。

**我认为应该是在delegate上重写forwardInvocation: 方法 在里面再去调用重量级对象的功能**

### 3.转发与继承

尽管转发很像继承，但是`NSObject`类不会将两者混淆。像`respondsToSelector:` 和 `isKindOfClass:`这类方法只会考虑继承体系，不会考虑转发链。比如上图中一个`Warrior`对象如果被问到是否能响应`negotiate`消息： 

```objective-c
if ( [aWarrior respondsToSelector:@selector(negotiate)] )
    ...
```

结果是`NO`，尽管它能够接受`negotiate`消息而不报错，因为它靠转发消息给`Diplomat`类来响应消息。 

如果你为了某些意图偏要“弄虚作假”让别人以为`Warrior`继承到了`Diplomat`的`negotiate`方法，你得重新实现 `respondsToSelector:` 和 `isKindOfClass:`来加入你的转发算法：

```objective-c
- (BOOL)respondsToSelector:(SEL)aSelector
{
    if ( [super respondsToSelector:aSelector] )
        return YES;
    else {
        /* Here, test whether the aSelector message can     *
         * be forwarded to another object and whether that  *
         * object can respond to it. Return YES if it can.  */
    }
    return NO;
}
```

除了`respondsToSelector:` 和 `isKindOfClass:`之外，`instancesRespondToSelector:`中也应该写一份转发算法。如果使用了协议，`conformsToProtocol:`同样也要加入到这一行列中。类似地，如果一个对象转发它接受的任何远程消息，它得给出一个`methodSignatureForSelector:`来返回准确的方法描述，这个方法会最终响应被转发的消息。比如一个对象能给它的替代者对象转发消息，它需要像下面这样实现`methodSignatureForSelector:`： 

```objective-c
- (NSMethodSignature*)methodSignatureForSelector:(SEL)selector
{
    NSMethodSignature* signature = [super methodSignatureForSelector:selector];
    if (!signature) {
       signature = [surrogate methodSignatureForSelector:selector];
    }
    return signature;
}
```

**结论:**

在整个消息发送的机制下 既有各种的判断  也会有一定的优化 而且还能再某个时机下转换接收者 甚至向别的接收者发送别的消息 只有一个字形容 **无敌**

