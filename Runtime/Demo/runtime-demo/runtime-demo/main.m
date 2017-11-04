//
//  main.m
//  runtime-demo
//
//  Created by 郭漫丽 on 2017/11/3.
//  Copyright © 2017年 huangzihao. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "Base.h"
#import "Son.h"
#import "Zhupi.h"

//getter
NSString *sb(id self, SEL _cmd) {
    return objc_getAssociatedObject(self, "sb");
}

//setter
void setSb(id self, SEL _cmd, NSString *value) {
    objc_setAssociatedObject(self, "sb", value, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

//custom setter && getter
void customSetter(id self, SEL _cmd, id value) {
    NSString *propertyStr = NSStringFromSelector(_cmd);
    
    NSString *realProperty = [propertyStr substringFromIndex:3];
    realProperty = [realProperty substringToIndex:realProperty.length - 1];
    realProperty = [realProperty lowercaseString];
    objc_setAssociatedObject(self, NSSelectorFromString(realProperty), value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

id customGetter(id self, SEL _cmd) {
    return objc_getAssociatedObject(self, _cmd);
}

int main(int argc, char * argv[]) {
    @autoreleasepool {
        
        //print property
//        unsigned int count;
//        objc_property_t *properties = class_copyPropertyList([Base class], &count);
//        for (int i = 0; i< count; ++i) {
//            objc_property_t curProperty = properties[i];
//            printf("property name is %s and attribute is %s\n", property_getName(curProperty), property_getAttributes(curProperty));
//        }
        
        //rumtime add property
        objc_property_attribute_t attribute1 = {"T",@encode(NSString *)};
        objc_property_attribute_t attribute2 = {"N", ""};
        objc_property_attribute_t attribute3 = {"&", ""};
        objc_property_attribute_t attribute[] = {attribute1, attribute2, attribute3};
        class_addProperty([Base class], "test", attribute, 3);
        
        //add property getter && setter
//        class_addMethod([Base class], @selector(sb), (IMP)sb, "@@:");
//        class_addMethod([Base class], @selector(setSb:), (IMP)setSb, "v@:@");
        class_addMethod([Base class], @selector(sb), (IMP)customGetter, "@@:");
        class_addMethod([Base class], @selector(setSb:), (IMP)customSetter, "v@:@");
        
        //new Base and set & printf sb
        Base *base = [Base new];
        [base performSelector:NSSelectorFromString(@"setSb:") withObject:@"sb1"];
        NSLog(@"new property is %@",[base performSelector:NSSelectorFromString(@"sb")]);
        
        //resolve
        unsigned int methodCount;
        Method *methodList = class_copyMethodList([Base class],&methodCount);
        for (int j = 0; j < methodCount; ++j) {
            Method curMethod = methodList[j];
            printf("before base method name is %s and type encoding is %s\n",method_getName(curMethod),method_getTypeEncoding(curMethod));
        }
        
        unsigned int methodCountS;
        Method *methodListS = class_copyMethodList([Son class], &methodCountS);
        for (int j = 0; j < methodCountS; j++) {
            Method curMethod = methodListS[j];
            printf("before son method name is %s ant type encoding is %s\n",method_getName(curMethod),method_getTypeEncoding(curMethod));
        }
        
        Son *son = [Son new];
        [son needResolve];
        
        Method *newmethodList = class_copyMethodList([Base class],&methodCount);
        for (int j = 0; j < methodCount; ++j) {
            Method curMethod = newmethodList[j];
            printf("new base method name is %s and type encoding is %s\n",method_getName(curMethod),method_getTypeEncoding(curMethod));
        }
        
        Method *newmethodListS = class_copyMethodList([Son class], &methodCountS);
        for (int j = 0; j < methodCountS; j++) {
            Method curMethod = newmethodListS[j];
            printf("new son method name is %s ant type encoding is %s\n",method_getName(curMethod),method_getTypeEncoding(curMethod));
        }
        
        free(methodListS);
        free(methodList);
        free(newmethodList);
        free(newmethodListS);
        
        
        //forwardingTarget
        [base needForwardTarget];
        
        //final forwarding
        [base needFinalForward];
        
        //method swizzling
        Zhupi *zhupi = [Zhupi new];
        [zhupi lazha];
        [zhupi wanshe];
    }
}
