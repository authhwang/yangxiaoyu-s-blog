//
//  Base.m
//  runtime-demo
//
//  Created by 郭漫丽 on 2017/11/3.
//  Copyright © 2017年 huangzihao. All rights reserved.
//

#import "Base.h"
#import <objc/runtime.h>
#import "Hantai.h"

void resolveImp(id self, SEL _cmd) {
    NSLog(@"resolved function");
}

@implementation Base

+ (BOOL)resolveInstanceMethod:(SEL)sel {
    if ([NSStringFromSelector(sel) isEqualToString:@"needResolve"]) {
        class_addMethod(self, sel, (IMP)resolveImp, "v@:");
        return YES;
    }
    return [[self superclass] resolveInstanceMethod:sel];
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    if (aSelector == @selector(needForwardTarget)) {
        NSLog(@"forwaring Target Start");
        Hantai *hantai = [Hantai new];
        return hantai;
    }
    return [super forwardingTargetForSelector:aSelector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    NSLog(@"selector is %@", NSStringFromSelector(aSelector));
    NSMethodSignature *methodSignature = [super methodSignatureForSelector:aSelector];
    if (!methodSignature) {
        NSLog(@"index create method signature");
        methodSignature = [NSMethodSignature signatureWithObjCTypes:"v@:i"];
    }
    
    return methodSignature;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    NSLog(@"forwaring invocation selector is %@", NSStringFromSelector(anInvocation.selector));
    NSLog(@"invocation is %@ and method signaure is %@",anInvocation,anInvocation.methodSignature);
    
    if (anInvocation.selector == @selector(needFinalForward)) {
        NSLog(@"inside forwarding");
        anInvocation.selector = NSSelectorFromString(@"hantaiForwarding:");
        int *a;
        int b = 99;
        a = &b;
        [anInvocation setArgument:a atIndex:2];
        Hantai *hantai = [Hantai new];
        [anInvocation invokeWithTarget:hantai];
    } else {
        NSLog(@"else forwarding");
        [super forwardInvocation:anInvocation];
    }
    
}
@end
