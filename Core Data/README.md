# Core Data

以下是我用来作为笔记的内容

iOS 10之前appDelegate上会有三个东西 `managedObjectContext` `managedObjectModel`和`persistentStoreCoordinator` 这三个东西分别是管理数据内容、管理数据模型、持久性数据协调器 至于详细的东西可以看[这篇文章](http://yulingtianxia.com/blog/2014/05/01/chu-shi-core-data-1/)

iOS 10之后 他把三个东西都封装在一个NSPersistentContainer上 想要的属性都可以在这里面拿到 相对比以前清晰很多

每当需要做什么处理 都要先给相应的controller传递managedObjectContext 用来保存所有sql操作在内容的作用 然后在controller里面创建你想获得的表所对应的NSFetchedResultsController 这里就等于去获取表数据了

在创建NSFetchedResultsController的时候要注意三点

1.在iOS 10前后获取会有不同 要注意留意 我这里用的是iOS 10后的例子

2.创建NSFetchRequset等于sql中的from,以NSFetchRequset的属性predicate等于sql中的where(要注意他的写法！！！别被他坑),NSSortDescriptor等于orderBy

3.这只是对应一个表的数据 假如想要别的表数据只能再创建一个

获取数据数量

```objective-c
id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
```

删除数据

```objective-c
NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        [context deleteObject:[self.fetchedResultsController objectAtIndexPath:indexPath]];

```

添加数据

旧版:

```objective-c
NSManagedObjectContext *context = self.fetchedResultsController.managedObjectContext;
        NSEntityDescription *entity = self.fetchedResultsController.fetchRequest.entity;
Choice *choice;

choice = [NSEntityDescription insertNewObjectForEntityForName:entity.name inManagedObjectContext:context];
```

新版:

```objective-c
NSManagedObjectContext *context = self.fetchedResultsController.managedObjectContext;
Question *question;

question = [[Question alloc]initWithContext:context];
```

修改单条数据

直接获取该条数据的对象直接改 改完直接保存即可

修改多条数据  不需要加载到内存 直接处理数据库

```objective-c
//创建批量更新对象 并指明Choice表
NSBatchUpdateRequest *batchUpdateRequest = [NSBatchUpdateRequest batchUpdateRequestWithEntityName:@"Choice"];
//设置返回值类型 默认是什么都不返回 这里设置返回每个发生改变的对象id
batchUpdateRequest.resultType = NSUpdatedObjectIDsResultType;
//设置发生改变字段
batchUpdateRequest.propertiesToUpdate = @{@"weight": @(1)};
    
 NSError *batchUpdateRequestError = nil;
 NSBatchUpdateResult *result = [self.managedObjectContext executeRequest:batchUpdateRequest error:&batchUpdateRequestError];

```

修改完有一个需要注意的地方 由于直接处理数据库 需要将本地数据同步

有的做法是

```objective-c
[context refreshAllObject];
```

上面例子的中杨大大的做法是

```objective-c
NSArray <NSManagedObjectID*>*objectIds = result.result;
        
        for (NSManagedObjectID *objectID in objectIds) {
            NSManagedObject *managedObject = [self.managedObjectContext objectWithID:objectID];
            if (managedObject) {
                [self.managedObjectContext performBlock:^{
                    [self.managedObjectContext refreshObject:managedObject mergeChanges:false];
                }];
            }
        }
```

我觉得两种中 可能相对第二种容错性高些(不过也有可能是旧的做法)

基本上的功能就是差不多 至于说`NSFetchedResultsControllerDelegate`里面的内容可以跟着官方提供的demo修改即可