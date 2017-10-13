//
//  DetailViewController.m
//  hardChoice
//
//  Created by 郭漫丽 on 2017/10/10.
//  Copyright © 2017年 huangzihao. All rights reserved.
//

#import "DetailViewController.h"
#import "DynamiceCell.h"
#define rollup CATransform3DMakeRotation((CGFloat)M_PI_2, (CGFloat)0, (CGFloat)0.7, (CGFloat)0.4)
#define rolldown CATransform3DMakeRotation( (CGFloat)-M_PI_2, (CGFloat)0, (CGFloat)0.7, (CGFloat)0.4)

@interface DetailViewController ()<UITextFieldDelegate>

@property (nonatomic, assign) long lastVisualRow;
@property (nonatomic, strong) NSIndexPath *selectedIndexPath;

@end

@implementation DetailViewController

- (void)configureView {
    // Update the user interface for the detail item.
    if (self.detailItem) {
        self.detailDescriptionLabel.text = self.detailItem.content;
    }
    
    UIButton *headerBtn = [[UIButton alloc]initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 50)];
    self.tableView.tableFooterView = UIView.new;
    [headerBtn setTitle:NSLocalizedString(@"Reset Weight", @"") forState:UIControlStateNormal];
    [headerBtn setBackgroundColor:[UIColor redColor]];
    [headerBtn addTarget:self action:@selector(resetWeight) forControlEvents:UIControlEventTouchUpInside];
    self.tableView.tableHeaderView = headerBtn;
    self.navigationController.hidesBarsOnSwipe = true;
    
}


- (void)viewDidLoad {
    [super viewDidLoad];
    self.lastVisualRow = 0;
    // Do any additional setup after loading the view, typically from a nib.
    [self configureView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)motionBegan:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    if (motion == UIEventSubtypeMotionShake) {
        NSInteger count = self.fetchedResultsController.fetchedObjects.count;
        NSArray <Choice *>*arr = self.fetchedResultsController.fetchedObjects;
        int sum = 0;
        for (Choice *choice in arr) {
            sum += choice.weight;
        }
        if (sum > 0) {
            UInt32 lucknum = arc4random()%((UInt32)sum)+1;
            UInt32 n = 0;
            int num = 0;
            while (lucknum >0) {
                Choice *choice = arr[num];
                n = (UInt32)(choice.weight);
                if (lucknum <= n) {
                    break;
                } else {
                    lucknum -= n;
                    num++;
                    if (num >= count) {
                        num--;
                        break;
                    }
                }
            }
            Choice *choice = arr[num];
            NSString *message = choice.name;
            UIAlertView *alertView = [UIAlertView new];
            alertView.alertViewStyle = UIAlertViewStyleDefault;
            alertView.message = message;
            [alertView addButtonWithTitle:@"OK"];
            [alertView show];
        }
    }
}

- (void)resetWeight {
    NSBatchUpdateRequest *batchUpdateRequest = [NSBatchUpdateRequest batchUpdateRequestWithEntityName:@"Choice"];
    
    batchUpdateRequest.resultType = NSBatchDeleteResultTypeObjectIDs;
    batchUpdateRequest.propertiesToUpdate = @{@"weight": @(1)};
    
    NSError *batchUpdateRequestError = nil;
    NSBatchUpdateResult *result = [self.managedObjectContext executeRequest:batchUpdateRequest error:&batchUpdateRequestError];
    if (batchUpdateRequestError != nil) {
        NSLog(@"Unable to execute batch update request");
    } else {
        NSArray <NSManagedObjectID*>*objectIds = result.result;
        
        for (NSManagedObjectID *objectID in objectIds) {
            NSManagedObject *managedObject = [self.managedObjectContext objectWithID:objectID];
            if (managedObject) {
                [self.managedObjectContext performBlock:^{
                    [self.managedObjectContext refreshObject:managedObject mergeChanges:false];
                }];
            }
        }
        
        NSError *fetchError = nil;
        if (![self.fetchedResultsController performFetch:&fetchError]) {
            NSLog(@"Unable to perform fetch");
        }
    }
}

- (IBAction)insertNewObject:(id)sender {
    [self showEditAlertWithInsert:YES];
}

- (void)showEditAlertWithInsert: (BOOL)isNew {
    
    NSString *title = NSLocalizedString(@"Enter Choices of the Trouble", @"");
    NSString *message = self.detailItem.content;
    NSString *okbtn = NSLocalizedString(@"OK", @"");
    NSString *cancelbtn = NSLocalizedString(@"Cancel", @"");
    
    UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:okbtn style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
        NSManagedObjectContext *context = self.fetchedResultsController.managedObjectContext;
        NSEntityDescription *entity = self.fetchedResultsController.fetchRequest.entity;
        Choice *choice;
        if (isNew) {
            choice = [NSEntityDescription insertNewObjectForEntityForName:entity.name inManagedObjectContext:context];
            
        } else {
            choice = [self.fetchedResultsController objectAtIndexPath:self.selectedIndexPath];
        }
        
        choice.name = alertVC.textFields.firstObject.text;
        if (alertVC.textFields[1].text.length > 0) {
            int weight = [alertVC.textFields[1].text intValue];
            choice.weight = weight;
        }
        //将问题与选择关联一起的重要一步
        self.detailItem.choices = [self.detailItem.choices setByAddingObject:choice];
        
        NSError *error = nil;
        if (![context save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, error.userInfo);
            abort();
        }
        
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancelbtn style:UIAlertActionStyleCancel handler:nil];
    
    [alertVC addAction:okAction];
    [alertVC addAction:cancelAction];
    
    [alertVC addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        if (!isNew) {
            Choice *choice = [self.fetchedResultsController objectAtIndexPath:self.selectedIndexPath];
            textField.text = choice.name;
        }
        textField.borderStyle = UITextBorderStyleNone;
        textField.placeholder = NSLocalizedString(@"An answer of your trouble", @"");
        textField.delegate = self;
        [textField becomeFirstResponder];
    }];
    
    [alertVC addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        if (!isNew) {
            Choice *choice = [self.fetchedResultsController objectAtIndexPath:self.selectedIndexPath];
            textField.text = [NSString stringWithFormat:@"%d",choice.weight];
        }
        textField.borderStyle = UITextBorderStyleNone;
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.placeholder = NSLocalizedString(@"Weight can only be an integer", @"");
        textField.delegate = self;
    }];
    
    [self presentViewController:alertVC animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return self.fetchedResultsController.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = self.fetchedResultsController.sections[section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DynamiceCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ChoiceCell" forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        [context deleteObject:[self.fetchedResultsController objectAtIndexPath:indexPath]];
        
        NSError *error = nil;
        if (![context save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, error.userInfo);
            abort();
        }
    }
}

- (void)configureCell:(DynamiceCell *)cell atIndexPath: (NSIndexPath *)indexPath {
    Choice *choice = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = choice.name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%d",choice.weight];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    self.selectedIndexPath = indexPath;
    [self showEditAlertWithInsert:NO];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (self.lastVisualRow <= indexPath.row) {
        cell.layer.transform = rollup;
    } else {
        cell.layer.transform = rolldown;
    }
    self.lastVisualRow = indexPath.row;
    
    cell.layer.shadowColor = [UIColor blackColor].CGColor;
    cell.layer.shadowOffset = CGSizeMake(10, 10);
    cell.alpha = 0;
    cell.layer.anchorPoint = CGPointMake(0, 0.5);
    cell.layer.position = CGPointMake(0, cell.layer.position.y);
    
    [UIView animateWithDuration:0.8 animations:^{
        cell.alpha = 1;
        cell.layer.transform = CATransform3DIdentity;
        cell.layer.shadowOffset = CGSizeMake(0, 0);
    }];
    
}

#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldEndEditing:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Fetched results controller

- (NSFetchedResultsController<Choice *> *)fetchedResultsController {
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    //sql中的from
    NSFetchRequest<Choice *> *fetchRequest = Choice.fetchRequest;
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    
    //sql中的where 要注意他的写法！！！！
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"question.content = %@",self.detailItem.content];
    
    // Edit the sort key as appropriate.
    //sql中的orderBy
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:true];
    
    [fetchRequest setSortDescriptors:@[sortDescriptor]];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController<Choice *> *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
    aFetchedResultsController.delegate = self;
    
    NSError *error = nil;
    if (![aFetchedResultsController performFetch:&error]) {
        // Replace this implementation with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        NSLog(@"Unresolved error %@, %@", error, error.userInfo);
        abort();
    }
    
    _fetchedResultsController = aFetchedResultsController;
    return _fetchedResultsController;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        default:
            return;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {
    UITableView *tableView = self.tableView;
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            [tableView moveRowAtIndexPath:indexPath toIndexPath:newIndexPath];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
}



#pragma mark - Managing the detail item


@end
