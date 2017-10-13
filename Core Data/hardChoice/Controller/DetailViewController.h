//
//  DetailViewController.h
//  hardChoice
//
//  Created by 郭漫丽 on 2017/10/10.
//  Copyright © 2017年 huangzihao. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import "Question+CoreDataClass.h"
#import "Choice+CoreDataClass.h"
@interface DetailViewController : UITableViewController <NSFetchedResultsControllerDelegate>

@property (strong, nonatomic) Question *detailItem;
@property (strong, nonatomic) NSFetchedResultsController<Choice *> *fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (weak, nonatomic) IBOutlet UILabel *detailDescriptionLabel;

@end

