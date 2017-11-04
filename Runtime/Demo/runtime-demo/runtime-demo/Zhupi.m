//
//  Zhupi.m
//  runtime-demo
//
//  Created by 郭漫丽 on 2017/11/4.
//  Copyright © 2017年 huangzihao. All rights reserved.
//

#import "Zhupi.h"
#import <objc/runtime.h>
@implementation Zhupi

+ (void)load {
    SEL lazhaSelector = @selector(lazha);
    SEL wansheSelector = @selector(wanshe);
    
    Method lazhaMethod = class_getInstanceMethod(self, lazhaSelector);
    Method wansheMethod = class_getInstanceMethod(self, wansheSelector);
    if (class_addMethod(self, wansheSelector, method_getImplementation(lazhaMethod), method_getTypeEncoding(lazhaMethod))) {
        class_replaceMethod(self, lazhaSelector, method_getImplementation(wansheMethod), method_getTypeEncoding(wansheMethod));
    } else {
        method_exchangeImplementations(lazhaMethod, wansheMethod);
    }
}

- (void)lazha {
    NSLog(@"拉闸");
}

- (void)wanshe {
    NSLog(@"玩蛇");
}


@end
