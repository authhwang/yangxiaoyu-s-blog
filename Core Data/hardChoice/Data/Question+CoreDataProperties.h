//
//  Question+CoreDataProperties.h
//  hardChoice
//
//  Created by 郭漫丽 on 2017/10/10.
//  Copyright © 2017年 huangzihao. All rights reserved.
//
//

#import "Question+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface Question (CoreDataProperties)

+ (NSFetchRequest<Question *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *content;
@property (nullable, nonatomic, retain) NSSet<Choice *> *choices;

@end

@interface Question (CoreDataGeneratedAccessors)

- (void)addChoicesObject:(Choice *)value;
- (void)removeChoicesObject:(Choice *)value;
- (void)addChoices:(NSSet<Choice *> *)values;
- (void)removeChoices:(NSSet<Choice *> *)values;

@end

NS_ASSUME_NONNULL_END
