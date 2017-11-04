//
//  Base.h
//  runtime-demo
//
//  Created by 郭漫丽 on 2017/11/3.
//  Copyright © 2017年 huangzihao. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Base : NSObject

//@property (nonatomic, strong) NSString *lulu;
//@property (nonatomic, copy) NSString *manni;
//@property (nonatomic, assign) int auth;

- (void)needResolve;
- (void)needForwardTarget;
- (void)needFinalForward;

@end
