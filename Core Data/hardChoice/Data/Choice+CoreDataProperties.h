//
//  Choice+CoreDataProperties.h
//  hardChoice
//
//  Created by 郭漫丽 on 2017/10/10.
//  Copyright © 2017年 huangzihao. All rights reserved.
//
//

#import "Choice+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface Choice (CoreDataProperties)

+ (NSFetchRequest<Choice *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *name;
@property (nonatomic) int32_t weight;
@property (nullable, nonatomic, retain) Question *question;

@end

NS_ASSUME_NONNULL_END
