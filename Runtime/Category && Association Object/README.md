# 分类与关联对象

关键点：

1. 加载分类的方法
2. 对于系统自带的类和自己创建的类 加载分类的时机不同
3. 加载后 在方法列表上类原本的方法和分类的方法的顺序
4. AssociatedObject的作用

##  category_t

```c
struct category_t {
    const char *name;
    classref_t cls;
    struct method_list_t *instanceMethods;
    struct method_list_t *classMethods;
    struct protocol_list_t *protocols;
    struct property_list_t *instanceProperties;
    // Fields below this point are not always present on disk.
    struct property_list_t *_classProperties;

    method_list_t *methodsForMeta(bool isMeta) {
        if (isMeta) return classMethods;
        else return instanceMethods;
    }

    property_list_t *propertiesForMeta(bool isMeta, struct header_info *hi);
};
```

category_t结构体定义在`objc-runtime-new.h`中 

class： 类的名字

cls：类

instanceMethods： category中所有给类添加的实例方法的列表

classMethods： category中所有添加的类方法的列表

protocols： categ中实现的所有协议的列表

instanceProperties：category中添加的所有属性

## 编译后 runtime之前

一个**NSObject**的分类

```objective-c
#import <Foundation/Foundation.h>

@interface NSObject (vc)

- (void)test;

@end
```

在编译结束后 在调用runtime之前 NSObject会编译成objc_class结构体

而NSObject(vc)会被编译成一个category_t结构体

## runtime后

#### addUnattachedCategoriesForClass()

首先会调用该方法 获取类中还未添加的category列表（这个列表类型为 `locstamped_category_list_t`，它封装了 `category_t` 以及对应的 `header_info`。`header_info` 存储了实体在镜像中的加载和初始化状态，以及一些偏移量，在加载 Mach-O 文件相关函数中经常用到。） 

 然后把类和category做一个关联映射

#### attachCategories()

将`locstamped_category_list_t`列表中的每个`locstamped_category_t.cat`的方法 属性 协议分别添加到该类的`class_rw_t`对应列表中

在调用的过程中:

![break point](http://vanney9.com/lionheart/1706/breakpoint.png)

打印出的category结果如下：

![category](http://vanney9.com/lionheart/1706/category.png)

运行完attachCategories后：

运行`attachCategories` 方法之后，会将category中的所有方法、属性、协议添加到类的`class_rw_t`中。假如是类方法和协议添加到类的元类的中

我们以添加方法为例，在添加任何的分类方法之前，NSObject的`class_rw_t`中的`methods`数组只有一个元素，也就是`class_ro_t`中的`baseMethodList`列表。添加一个分类之后，会往`methods`数组中添加一个元素，该元素的类型是`entsize_list_tt`。

使用lldb查看，发现在添加vc分类后，NSObject里面已经添加了64个分类了；加上`baseMethodList`，`methods`数组已经有65个元素。（**后添加的分类在数组中的位置靠前，baseMethodList元素在最后面**）

![category](http://vanney9.com/lionheart/1706/nsobject.png)

**注意:**

1. category的加载并没有替换掉类原来已经有的方法 在方法列表上会有两个相同名字的方法
2. category的方法被放到新方法列表的前面 而类原本的方法被放倒新方法列表的最后 所以这就是平时所说的category的方法会‘覆盖’掉原本的方法 只是因为运行时查找方法是按着方法列表的顺序查找 当一找到对应名字的方法 就会结束查找
3. 在类的load方法调用时候 可以调用category中声明的方法吗？ （可以 因为附加category到类的工作会优先于load的执行）
4. categroy和类的load方法的调用顺序是如何？(类的load方法是最先调用的 其次category的load方法调用是根据编译时的 越先编译的越先调用其load方法)

### 例外

**对于系统自带的类，才会在runtime时加载分类；但是对于自己创建的类，在编译结束之后就直接将分类的方法添加到baseMethodList中 好像直接结合成一个自定义类一样**

```objective-c
// TestOBJ
@interface TestOBJ : NSObject {
    NSInteger ivatInt;
}
@property (nonatomic, assign) NSInteger propertyInt;
- (void)test;
@end

// TestOBJ+vc
#import "TestOBJ.h"
@interface TestOBJ (vc)
@property (nonatomic, assign) NSInteger vc;
- (void)test;
@end
```

在`_objc_init`里面打上断点，这个方法是runtime的入口函数。在这个时候使用lldb，就发现在TestOBJ的`baseMethodList`里面有2个test方法了，当然分类的test方法在前面，也就是会被先检索到。

## AssociationObject

category是无法添加实例变量 因为在运行时 对象的内存布局就已经确定好 如果添加实例变量就会破坏类的内部布局 这对编译型语言来说时灾难性的

虽然可以添加到属性 但添加属性不添加实例变量是无意义的

### 源码分析

关联对象相关的源码全部放在`objc-reference.h` 和 `objc-reference.mm` 两个文件中。

**关联对象和对象是一一对应的，而不是和类一一对应的**

1. 所有的关联对象都由一个**AssociationsManager**对象来管理，这个对象里面有一个**AssociationsHashMap**。
2. **AssociationsHashMap**由许多key-value构成。key是对象的地址；value是一个**ObjectAssociationMap**，也就是所谓的关联对象。
3. **ObjectAssociationMap**就是关联对象，每个关联对象里面包含多个key-value对。key是属性名；value是**ObjcAssociation**，也就是相当于属性对应的实例变量。
4. **ObjcAssociation**相当于实例变量，该结构体有两个成员：**_policy** 属性的内存管理语义；**_value** 属性的值

![association](http://vanney9.com/lionheart/1706/association.png)

api的调用：

```objective-c
void objc_setAssociatedObject ( id object, const void *key, id value, objc_AssociationPolicy policy );
id objc_getAssociatedObject ( id object, const void *key );
void objc_removeAssociatedObjects ( id object );
```

总结：

1. 加载分类的时候 通常都是在runtime的attachCategories方法执行
2. 对于系统本身的类的category 会在runtime中执行加载 而自己创建的类的分类 则会在编译期就已经加载好
3. 加载后 原本的方法会在新的方法列表的最后面 而分类的方法则会在根据编译顺序 越后编译的方法的顺序越前
4. 由于分类无法添加实例变量 所以需要用到AssociatedObject来添加 