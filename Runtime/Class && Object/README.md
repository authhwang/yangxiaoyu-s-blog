# 类和对象

关键点:

1. 类 = 类对象 --> 元类 --> 根类  (-->指isa指针)
2. 对象本质上是一个objc_object的结构体
3. 类的本质上是一个objc_class的结构体

## objc_object

```c
struct objc_object {
  private:
  		isa_t isa;
  public:
  		//function here
}
```

**objc_object**结构体是定义在`objc-private.h` 该结构体只有一个isa指针 但这个指针可以找到对象所属的类 可是由于它是由isa_t 使用union实现 所以俄能表示多种形态 既可以当成指针 也可以存储标志位  

注意: isa指针不总是指向实例对象所属的类，所以不能依靠它确定类型,而是用`class`方法来确定实力对象的类 例子:kvo的实质就是将被观察对象的isa指针指向一个中间类而不是原本的类 叫**isa-swizzling**  可见[官方文档]()

## isa_t 

isa_t定义在`objc-private.h`

```c
union isa_t 
{
    Class cls;
    uintptr_t bits;

#   define ISA_MASK        0x00007ffffffffff8ULL
#   define ISA_MAGIC_MASK  0x001f800000000001ULL
#   define ISA_MAGIC_VALUE 0x001d800000000001ULL
    struct {
        uintptr_t nonpointer        : 1;
        uintptr_t has_assoc         : 1;
        uintptr_t has_cxx_dtor      : 1;
        uintptr_t shiftcls          : 44; // MACH_VM_MAX_ADDRESS 0x7fffffe00000
        uintptr_t magic             : 6;
        uintptr_t weakly_referenced : 1;
        uintptr_t deallocating      : 1;
        uintptr_t has_sidetable_rc  : 1;
        uintptr_t extra_rc          : 8;
#       define RC_ONE   (1ULL<<56)
#       define RC_HALF  (1ULL<<7)
    };
}
```

#### has_assoc

表示该对象是否有关联对象

#### has_cxx_dtor

表示是否有析构函数

#### shiftcls

表示对象所属的类或者类所属的元类(meta class)的地址，也就是指向一个objc_class的指针，不过该指针只有44位。

64位系统的指针占用64bit的内存，但是使用整个指针大小来存储地址有点浪费。在mac的64位系统上面，使用47位作为指针，其他的17位用于其他目的（iPhone上面只使用33位）。又由于所有对象按照8字节对齐，所以指针都是能被8整除的，也就是后3bit均为0；所以类指针的实际有效位数为 `47 - 3 = 44` 位。这也是shiftcls只有44位的原因

#### initIsa()

是当objc_object创建的时候会调用来初始化isa的方法

例如说一个调用[TestObject new]方法的创建对象 它最后还是会调用到`initIsa`这个方法

![img](http://upload-images.jianshu.io/upload_images/4670835-3b0b3e7e2c45b9e2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

该方法的内部实现是

```c
inline void 
objc_object::initInstanceIsa(Class cls, bool hasCxxDtor)
{
    initIsa(cls, true, hasCxxDtor);
}

inline void 
objc_object::initIsa(Class cls, bool indexed, bool hasCxxDtor) 
{ 
    if (!indexed) {
        isa.cls = cls;
    } else {
        isa.bits = ISA_MAGIC_VALUE;
        isa.has_cxx_dtor = hasCxxDtor;
        isa.shiftcls = (uintptr_t)cls >> 3;
    }
}
```

这里的**indexed**用来标记isa是否有结构体部分：

1. 如果indexed为0，没有结构体部分，直接将对象所属的类的地址赋予cls变量
2. 如果indexed为1，有结构体部分，先使用`ISA_MAGIC_VALUE` 给isa这个64位union初始化，然后在对64位上的每一位单独设置。比如设置是否含有析构函数(*has_cxx_dtor*)，设置对象所属类的地址(*shiftcls*)。注意这里设置类地址的时候是将cls右移3位，再赋值给shiftcls的，原因就是类地址的最后3bit没有实际作用

#### isa()

该方法可以获取对象所属的类的指针 也就是表示该对象是一个什么类

```c
inline Class 
objc_object::ISA() 
{
    return (Class)(isa.bits & ISA_MASK);
}
// #define ISA_MASK 0x00007ffffffffff8ULL
```

返回的是一个64位的指向objc_class结构体的指针，其中的4-47bit为shiftcls的值，其他bit都是0

但其实它就是`object_getclass`的方法实现 所以平时我们在获取一个对象或者类的isa指针指向时 就会根据是类或者对象的不同而有不同的获取方式

类：

```objective-c
+ (Class)class {
    return self;
}
```

对象:

```objective-c
- (Class)class {
    return object_getClass(self);
}
```

`object_getclass`获取的是isa指针的指向的类地址 类调用的`class`方法也是返回自身 所以也就会成立`[testObj class] == [TestObject class]`这种判断

还有别的经常判断类的方法:isMemberOfClass isKindOfClass的方法实现也是差不多

```objective-c
+ (BOOL)isMemberOfClass:(Class)cls {
    return object_getClass((id)self) == cls;
}

- (BOOL)isMemberOfClass:(Class)cls {
    return [self class] == cls;
}

+ (BOOL)isKindOfClass:(Class)cls {
    for (Class tcls = object_getClass((id)self); tcls; tcls = tcls->superclass) {
        if (tcls == cls) return YES;
    }
    return NO;
}

- (BOOL)isKindOfClass:(Class)cls {
    for (Class tcls = [self class]; tcls; tcls = tcls->superclass) {
        if (tcls == cls) return YES;
    }
    return NO;
}

```



## objc_class

**objc_class**结构体是定义在`objc-runtime-new.h` 它继承了**objc_object** 所以除了isa成员外 还有

1. 指向父类的以**objc_object**为结构体的指针**super_class** 它所指向的就是父类的信息（关于继承方面的）
2. 一个包含函数缓存的**cache_t**类型指针的**cache**
3. 一个包含类的方法 属性等信息**class_data_bits_t**类型的变量**bits**

```c
struct objc_class : objc_object {
    Class superclass;
    cache_t cache;             // formerly cache pointer and vtable
    class_data_bits_t bits;
      // method here
  	class_rw_t *data() { 
        return bits.data();
    }
}
```

在编译结束的时候 oc的每个类都是以**objc_class**的结构体形式存在于内存中 而且在内存中的位置已经固定 运行期间时 创建新的对象时 就是创建**objc_object**的结构体

不过 对于类来说 由于它也是继承**objc_object** 所以它也是一个对象

对于这种关系runtime库创建了一个叫做元类(meta class) 类对象所属类型就叫做元类

它用来表述**类对象**本身所具备的**元数据** **类方法**也就是**定义在元类当中** 可以理解成为是**类对象的实例方法**

每个类只有一个类对象 每个类对象也只有一个相关的元类 而所有元类的isa指针其实是指向根元类

所以 当调用[NSObject alloc]的类方法时候 其实就是通过其元类的方法列表找到该方法 并去响应该消息 对该类对象执行方法调用

所以在我的理解里 这个元类就是类对象的**isa指针所指向的地址** 也就是类方法信息所在 

![img](http://7ni3rk.com1.z0.glb.clouddn.com/Runtime/class-diagram.jpg)

由于对于每个类来说 根类肯定是`NSObject`的嘛 所以它的superclass指针为空

根类isa指针指向自己的根元类 而根元类的superclass指针却指回根类 根元类的isa指向了自己 这才是最骚的

总结：

1. oc的对象和类在内存中都是以结构体存在

2. 创建这两个结构体的时候都会初始化isa指针 而isa指针所指向的 是保存了对象（类对象）所属的类（元类）的信息 

3. 看懂`[testObj class] == [TestObject class]`

4. 认清楚类 = 类对象 --> 元类 --> 根类  (-->指isa指针)的关系

   ​