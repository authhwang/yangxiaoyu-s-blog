//
//  Question+CoreDataProperties.m
//  hardChoice
//
//  Created by 郭漫丽 on 2017/10/10.
//  Copyright © 2017年 huangzihao. All rights reserved.
//
//

#import "Question+CoreDataProperties.h"

@implementation Question (CoreDataProperties)

+ (NSFetchRequest<Question *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"Question"];
}

@dynamic content;
@dynamic choices;

@end
