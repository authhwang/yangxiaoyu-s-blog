# 属性与方法

在前面的[类和对象]()中 我们了解到objc_object中的isa指针在不同情况会有不同的指向 的情况 所以在这片文章中 我们继续探讨objc_class的另一个指针bits

关键点: 

1. objc_class通过data方法来返回bit从而返回类的信息 属性 方法
2. bit中的两个结构体 class_ro_t class_rw_t的区别
3. 类的第一次初始化 在realizeClass方法 将class_ro_t的指针赋值给class_rw_t
4. 属性只是生成一个加下划线成员变量和两个setter&getter
5. 健壮的实例变量结构

## bits

先看回objc_class的结构

![objc_class](http://vanney9.com/lionheart/1706/bits.png)

bits 是含有属性 成员变量 方法 协议等信息 我们来看看`class_data_bits_t`的结构

## class_data_bits_t

```c
struct class_data_bits_t {

	// Values are the FAST_ flags above.
	uintptr_t bits;
	class_rw_t* data() {
	   return (class_rw_t *)(bits & FAST_DATA_MASK);
	}
... 省略其他方法
}
```

在`objc_class`上的`data`方法是直接返回`bits`的`data`方法 在这里可以看到其实也是返回一个`class_rw_t`结构的

可以看到`class_data_bits_t`也含有一个`bits` 这个指针需要根不同的`FAST_`前缀的flag掩码做按位与操作 就可以获取不同的数据 `bits`在不同位数的系统下有不同的排列顺序

32 位：

| 0             | 1                   | 2 - 31         |
| ------------- | ------------------- | -------------- |
| FAST_IS_SWIFT | FAST_HAS_DEFAULT_RR | FAST_DATA_MASK |

64 位兼容版：

| 0             | 1                   | 2                     | 3 - 46         | 47 - 63 |
| ------------- | ------------------- | --------------------- | -------------- | ------- |
| FAST_IS_SWIFT | FAST_HAS_DEFAULT_RR | FAST_REQUIRES_RAW_ISA | FAST_DATA_MASK | 空闲      |

64 位不兼容版：

```objective-c
// class is a Swift class
#define FAST_IS_SWIFT           (1UL<<0)
// class's instances requires raw isa
#define FAST_REQUIRES_RAW_ISA   (1UL<<1)
// class or superclass has .cxx_destruct implementation
//   This bit is aligned with isa_t->hasCxxDtor to save an instruction.
#define FAST_HAS_CXX_DTOR       (1UL<<2)
// data pointer
#define FAST_DATA_MASK          0x00007ffffffffff8UL
// class or superclass has .cxx_construct implementation
#define FAST_HAS_CXX_CTOR       (1UL<<47)
// class or superclass has default alloc/allocWithZone: implementation
// Note this is is stored in the metaclass.
#define FAST_HAS_DEFAULT_AWZ    (1UL<<48)
// class or superclass has default retain/release/autorelease/retainCount/
//   _tryRetain/_isDeallocating/retainWeakReference/allowsWeakReference
#define FAST_HAS_DEFAULT_RR     (1UL<<49)
// summary bit for fast alloc path: !hasCxxCtor and 
//   !instancesRequireRawIsa and instanceSize fits into shiftedSize
#define FAST_ALLOC              (1UL<<50)
// instance size in units of 16 bytes
//   or 0 if the instance size is too big in this field
//   This field must be LAST
#define FAST_SHIFTED_SIZE_SHIFT 51
```

所以说除了`FAST_DATA_MASK`是用一段空间来存储数据之外 别的都是1bit来存储bool值

那块`FAST_DATA_MASK`空间就是用来存储指向`class_rw_t`的指针

对这片内存读写处于并发环境，但并不需要加锁，因为会通过对一些状态（realization or construction）判断来决定是否可读写。

## class_ro_t 和 class_rw_t

`objc_class` 包含了 `class_data_bits_t`，`class_data_bits_t` 包含了 `class_rw_t` 的指针，而 `class_rw_t`结构体又包含 `class_ro_t` 的指针。

```c
struct class_rw_t {
    uint32_t flags;
    uint32_t version;

    const class_ro_t *ro;

    method_array_t methods;
    property_array_t properties;
    protocol_array_t protocols;

    Class firstSubclass;
    Class nextSiblingClass;
};

struct class_ro_t {
    uint32_t flags;
    uint32_t instanceStart;
    uint32_t instanceSize;
    uint32_t reserved;

    const uint8_t * ivarLayout;

    const char * name;
    method_list_t * baseMethodList;
    protocol_list_t * baseProtocols;
    const ivar_list_t * ivars;

    const uint8_t * weakIvarLayout;
    property_list_t *baseProperties;
};
```

每个类刚开始都对应有一个`class_ro_t`结构体指针

在编译成功时 `class_ro_t`结构体的内容就已经确定好 `objc_class`的`data`方法可以返回存放着该结构体的地址 在类的第一次初始化时 会调用runtime的`realizeClass`方法  创建`class_rw_t`的结构体指针 开辟`class_rw_t`的空间 并将`class_ro_t`赋值给`class_rw_t->ro`  刷新data部分 换成class_rw_t的地址

```c
ro = (const class_ro_t *)cls->data();
if (ro->flags & RO_FUTURE) {
   // This was a future class. rw data is already allocated.
   rw = cls->data();
   ro = cls->data()->ro;
   cls->changeInfo(RW_REALIZED|RW_REALIZING, RW_FUTURE);
} else {
   // Normal class. Allocate writeable class data.
   rw = (class_rw_t *)calloc(sizeof(class_rw_t), 1);
   rw->ro = ro;
   rw->flags = RW_REALIZED|RW_REALIZING;
   cls->setData(rw);
}
```

换成两张图说明过程

调用`realizeClass`前

![before runtime](http://vanney9.com/lionheart/1706/before_bits.png)

调用`realizeClass`后

![before runtime](http://vanney9.com/lionheart/1706/after_bits.png)

#### entsize_list_tt

`class_ro_t` 中的 `method_list_t`, `ivar_list_t`, `property_list_t` 结构体都继承自 `entsize_list_tt<Element, List, FlagMask>`。该结构实现了non-fragile特性的数据结构 下面章节会有讲到

#### list_array_t

`class_rw_t` 中使用的 `method_array_t`, `property_array_t`, `protocol_array_t` 都继承自 `list_array_tt<Element, List>`, 它可以不断扩张，因为它可以存储 list 指针，内容有三种：

1. 空
2. 一个 `entsize_list_tt` 指针
3. `entsize_list_tt` 指针数组

## 属性和成员变量

先看下面的例子

```objective-c
@interface TestOBJ : NSObject {
      NSInteger ivarInt;
}
@property (nonatomic, assign) NSInteger propertyInt;
```

这个TestOBJ类有一个成员变量`ivarInt` 和 一个属性`propertyInt` 。使用lldb打印出class_ro_t的ivars：

![ivars list](http://vanney9.com/lionheart/1706/ivars.png)

再使用lldb打印出class_ro_t的baseProperties:

![properties list](http://vanney9.com/lionheart/1706/properties.png)

顺便也把class_ro_t的baseMethodList打印出来吧：

![methods list](http://vanney9.com/lionheart/1706/methods.png)

从上看出TestOBJ类含有2个成员变量 1个属性 2个方法 但是代码里只有一个成员变量和一个属性 原因在于 声明一个属性时 会在编译时同时生成一个成员变量和该成员变量的setter&getter

#### property_t 

class_ro_t中的baseProperties是一个存放**property_t**结构体的list  结构如下:

```c
struct property_t {
    const char *name;
    const char *attributes;
};
```

name: 属性名字

attributes: 类型编码(type encoding)

#### ivar_t

class_ro_t中的ivars是存放**ivar_t**结构体的list  结构如下:

```c
struct ivar_t {
    int32_t *offset;
    const char *name;
    const char *type;
    // alignment is sometimes -1; use alignment() instead
    uint32_t alignment_raw;
    uint32_t size;

    uint32_t alignment() const {
        if (alignment_raw == ~(uint32_t)0) return 1U << WORD_SHIFT;
        return 1 << alignment_raw;
    }
};
```

name: 成员变量的名字

type: 成员变量的类型 type encoding

size: 成员变量的内存大小 例如(NSInteger类型 所以就占8个字节)

offset: 成员变量距离对象的首地址的偏移量 (isa_t结构体 + 在该成员变量前面的所有变量大小)

其中 在**class_ro_t**结构体中 还有2个变量需要注意:

instanceStart: 对象开始存放成员变量的地址的偏移量 (8 因为对象的前8字节存放的是`isa_t`结构体)

instanceSize: 对象的大小 （isa_t + 所有实例变量包括属性所提供的成员变量）

## 健壮的实例变量(Non Fragile ivars)

在 Runtime 的现行版本中，最大的特点就是健壮的实例变量。当一个类被**编译**时，实例变量的布局也就形成了，它表明访问类的实例变量的位置。从对象头部开始，实例变量依次根据自己所占空间而产生位移： 

![img](http://7ni3rk.com1.z0.glb.clouddn.com/nf1.png)

上图左边是`NSObject`类的实例变量布局，右边是我们写的类的布局，也就是在超类后面加上我们自己类的实例变量，看起来不错。但试想如果哪天苹果更新了`NSObject`类，发布新版本的系统的话，那就悲剧了： 

![img](http://7ni3rk.com1.z0.glb.clouddn.com/nf2.png)

我们自定义的类被划了两道线，那是因为那块区域跟父类重叠了。唯有苹果将父类改为以前的布局才能拯救我们，但这样也导致它们不能再拓展它们的框架了，因为成员变量布局被死死地固定了。在脆弱的实例变量(Fragile ivars) 环境下我们需要重新编译继承自 Apple 的类来恢复兼容性。那么在健壮的实例变量下会发生什么呢？ 

![img](http://7ni3rk.com1.z0.glb.clouddn.com/nf3.png)

在健壮的实例变量下编译器生成的实例变量布局跟以前一样，但是当 runtime 系统检测到与超类有部分重叠时它会调整你新添加的实例变量的位移，那样你在子类中新添加的成员就被保护起来了。 

在编译期在**class_ro_t**给**instanceStart**和**instanceSize**赋值 确定好每个类的所占内存区域起始偏移量和大小 这样只需将子类和父类的这两个变量对比即可知道子类是否与父类有重叠 如果有 也可以进行通过**ivar_t**的**offset**进行设置

例如：

先看看没有继承关系的类 TestOBJ：

![testObj](http://vanney9.com/lionheart/1706/testObj.png) 

再看看继承TestOBJ的Son类：

```objective-c
@interface Son : TestOBJ
@property (nonatomic, strong) NSString *sonStr
@end
```

它的对象既存储了TestOBJ的成员变量，也存放了Son自己的实例变量

![son](http://vanney9.com/lionheart/1706/son.png)

使用lldb打印son的class_ro_t:

![super](http://vanney9.com/lionheart/1706/super.png)

可以发现Son类的 `instanceStart` 为24，因为Son的实例的前8字节存放isa，后面16字节存放父类的ivarInt和_propertyInt两个NSInteger型实例变量。Son类的 `instanceSize`为32字节，因为他还有自己的一个指向NSString结构体的指针 **_sonStr**，这个指针也占8字节。

另外**_sonStr** 这一个ivar_t的offset是24，也符合分析

## 方法

这里的method都只是针对实例方法 对于类方法只会存在元类中的 (经测试)

编译结束后 类的方法已经存储在了**class_ro_t**里面的**baseMethodList** 当运行完**realizeClass**方法后 就会将**baseMethodList**的指针内容加到**class_rw_t**的**methods**变量上（由于methods的类型是具有可扩张性）

然后再将**category**的方法的指针内容加到**methods**中(category的下一篇再讲)  **这样类的所有方法就都聚集在class_rw_t的methods变量中**

`Method`是一种代表类中的某个方法的类型。

```
typedef struct method_t *Method;

```

而 `objc_method` 在上面的方法列表中提到过，它存储了方法名，方法类型和方法实现： 

```
struct method_t {
    SEL name;
    const char *types;
    IMP imp;

    struct SortBySELAddress :
        public std::binary_function<const method_t&,
                                    const method_t&, bool>
    {
        bool operator() (const method_t& lhs,
                         const method_t& rhs)
        { return lhs.name < rhs.name; }
    };
};
```

- 方法名类型为 `SEL`，前面提到过相同名字的方法即使在不同类中定义，它们的方法选择器也相同。 
- 方法类型 `types` 是个`char`指针，其实存储着方法的参数类型和返回值类型。
- `imp` 指向了方法的实现，本质上是一个函数指针，后面会详细讲到。

总结：

objc_class结构体中的bits变量存放着类的方法 属性 协议 但有些信息是在编译时候就确定的 另外的则在realizeClass方法中添加上去的