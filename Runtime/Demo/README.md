# Demo

其实demo上我也是跟着这个文档搞的 所以可以直接看这个[文档](http://vanney9.com/2017/06/10/objective-c-runtime-example/)就行了

然后我在做的过程中有几点要注意

1. 父类假如做动态方法解析或者消息转发 子类也是可以用到那些重写的方法(我想应该是继承了或者有可能默认是会调用回父类的)
2. 动态加载的属性或者方法 只能通过performSelector方法去调用
3. int *p 是开了一个int类型的指针 然而不能直接 p = 9 因为9不是一个地址 也不能直接 *p = 9 因为p指针没有地址引用 只是个野指针
4. nsinvocation 可以修改其selector 不会被固定 骚的一批 
5. 添加type encoding时记得两个隐藏参数也要添加 即self和_cmd @: