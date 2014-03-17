//
//  SEPrefsAppToggleController.h
//  SEPrefs
//
//  Created by K3A on 2/25/12.
//  Copyright (c) 2012 K3A. All rights reserved.
//
#import "Shared.h"
#import <Preferences/Preferences.h>
#import <applist.h>

@class SEPrefsAppToggleController;

@protocol SEPrefsAppToggleControllerDelegate <NSObject>
@required
-(void)appToggleController:(SEPrefsAppToggleController*)atc didFinishedSelection:(NSSet*)appIdents;
@end

@interface SEPrefsAppToggleController : PSViewController <UITableViewDataSource,UITableViewDelegate>  {
    UITableView* _tableView;
    PSViewController<SEPrefsAppToggleControllerDelegate>* _parent;
    
    ALApplicationTableDataSource* _dataSource;
    NSMutableSet* _selectedIdents;
}
- (id)initWithParent:(PSViewController<SEPrefsAppToggleControllerDelegate>*)parent;
- (void)setSelectedIdents:(NSSet*)idents;
- (NSSet*)selectedIdents;

@end
