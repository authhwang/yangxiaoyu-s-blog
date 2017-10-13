//
//  Choice+CoreDataProperties.m
//  hardChoice
//
//  Created by 郭漫丽 on 2017/10/10.
//  Copyright © 2017年 huangzihao. All rights reserved.
//
//

#import "Choice+CoreDataProperties.h"

@implementation Choice (CoreDataProperties)

+ (NSFetchRequest<Choice *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"Choice"];
}

@dynamic name;
@dynamic weight;
@dynamic question;

@end
