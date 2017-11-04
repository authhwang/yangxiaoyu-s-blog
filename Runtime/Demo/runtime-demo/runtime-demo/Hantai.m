//
//  Hantai.m
//  runtime-demo
//
//  Created by 郭漫丽 on 2017/11/3.
//  Copyright © 2017年 huangzihao. All rights reserved.
//

#import "Hantai.h"

@implementation Hantai

- (void)needForwardTarget {
    NSLog(@"hantai 起作用了");
}

- (void)hantaiForwarding:(int)index {
    NSLog(@"hantai 终极鱿鱼之final forwarding起作用了: index is %d",index);
}

@end
