# 属性与方法

在前面的[类和对象]()中 我们了解到objc_object中的isa指针在不同情况会有不同的指向 的情况 所以在这片文章中 我们继续探讨objc_class的另一个指针bits

#### bits

先看回objc_class的结构

![objc_class](http://vanney9.com/lionheart/1706/bits.png)

bits 是含有属性 成员变量 方法 协议等信息 我们来看看`class_data_bits_t`的结构

#### class_data_bits_t

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

在`objc_class`上的`data`方法是直接返回`bits`的`data`方法 在这里可以看到其实现也是返回一个`class_rw_t`结构的

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

其实那块`FAST_DATA_MASK`空间就是用来存储指向`class_rw_t`的指针

对这片内存读写处于并发环境，但并不需要加锁，因为会通过对一些状态（realization or construction）判断来决定是否可读写。

#### class_ro_t 和 class_rw_t

`bjc_class` 包含了 `class_data_bits_t`，`class_data_bits_t` 包含了 `class_rw_t` 的指针，而 `class_rw_t`结构体又包含 `class_ro_t` 的指针。

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

在编译成功时 `class_ro_t`结构体的内容就已经确定好 `objc_class`的`data`方法可以返回存放着该结构体的地址 在类的第一次初始化时 会调用runtime的`realizeClass`方法  创建`class_rw_t`的结构体指针 开辟`class_rw_t`的空间 并将`class_ro_t`赋值给`class_rw_t->ro` 并刷新data部分 换成class_rw_t的地址

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

#### 属性和成员变量

先看下面的例子

```objective-c
@interface TestOBJ : NSObject {
      NSInteger ivarInt;
}
@property (nonatomic, assign) NSInteger propertyInt;
```

这个TestOBJ类有一个实例变量`ivarInt` 和 一个属性`propertyInt` 。使用lldb打印出class_ro_t的ivars：

![ivars list](http://vanney9.com/lionheart/1706/ivars.png)

再使用lldb打印出class_ro_t的baseProperties:

![properties list](http://vanney9.com/lionheart/1706/properties.png)

顺便也把class_ro_t的baseMethodList打印出来吧：

![methods list](http://vanney9.com/lionheart/1706/methods.png)

从上看出TestOBJ类含有2个成员变量 1个属性 2个方法 但是代码里只有一个成员变量和一个属性 原因在于 声明一个属性时 会在编译时同时生成一个成员变量和该成员变量的setter&getter

