//
//  DynamiceCell.m
//  hardChoice
//
//  Created by 郭漫丽 on 2017/10/11.
//  Copyright © 2017年 huangzihao. All rights reserved.
//

#import "DynamiceCell.h"

@implementation DynamiceCell

- (instancetype)init {
    
    self = [super init];
    if (self) {
        self.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        self.textLabel.numberOfLines = 0;
        
        if (self.detailTextLabel != nil) {
            self.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
            self.detailTextLabel.numberOfLines = 0;
        }
    }
    
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    
    self = [super initWithFrame:frame];
    if (self) {
        self.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        self.textLabel.numberOfLines = 0;
        
        if (self.detailTextLabel != nil) {
            self.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
            self.detailTextLabel.numberOfLines = 0;
        }
    }
    
    return self;
}

- (NSArray<NSLayoutConstraint *> *)constraints {
    NSMutableArray <NSLayoutConstraint *>*constraints = [NSMutableArray array];
    [constraints addObjectsFromArray:[self constraintsForView: self.textLabel]];
    
    if (self.detailTextLabel != nil) {
        [constraints addObjectsFromArray:[self constraintsForView:self.detailTextLabel]];
    }
    [constraints addObject: [NSLayoutConstraint constraintWithItem:self.contentView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:self.contentView attribute:NSLayoutAttributeHeight multiplier:0 constant:44]];
    NSArray <NSLayoutConstraint *> *newconstraints = [constraints copy];
    [self.contentView addConstraints:newconstraints];
    return newconstraints;
}

- (NSArray<NSLayoutConstraint *> *)constraintsForView: (UIView *)view {
    NSMutableArray <NSLayoutConstraint *>*constraints = [NSMutableArray array];
    [constraints addObject: [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeFirstBaseline relatedBy:NSLayoutRelationEqual toItem:self.contentView attribute:NSLayoutAttributeTop multiplier:1.8 constant:30]];
    
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.contentView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:view attribute:NSLayoutAttributeBaseline multiplier:1.3 constant:8]];
    return [constraints copy];
}

@end
