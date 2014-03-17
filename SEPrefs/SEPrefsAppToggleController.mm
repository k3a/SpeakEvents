//
//  SEPrefsAppToggleController.m
//  SEPrefs
//
//  Created by K3A on 2/25/12.
//  Copyright (c) 2012 K3A. All rights reserved.
//

#import "SEPrefsAppToggleController.h"

@implementation SEPrefsAppToggleController

- (id)initWithParent:(PSViewController<SEPrefsAppToggleControllerDelegate>*)parent
{
    if ( (self = [super init]) )
    {
        _parent = parent;
        
        _dataSource = [[ALApplicationTableDataSource alloc] init];
        _dataSource.sectionDescriptors = [ALApplicationTableDataSource standardSectionDescriptors];
        _selectedIdents = [[NSMutableSet alloc] init];
        
        _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 480-64) style:UITableViewStyleGrouped];
        [_tableView setDelegate:self];
        [_tableView setDataSource:self];
        
        [[self navigationItem] setTitle:@"Select Apps"];
    }
    
    return self;
}
-(void)dealloc
{
    [_parent appToggleController:self didFinishedSelection:_selectedIdents];
    
    [_tableView release];
    [_dataSource release];
	[super dealloc];
}
- (id) view
{
    return _tableView;
}

- (void)suspend
{
    [_parent appToggleController:self didFinishedSelection:_selectedIdents];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{	
	return [_dataSource numberOfSectionsInTableView:tableView];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_dataSource tableView:tableView numberOfRowsInSection:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [_dataSource tableView:tableView cellForRowAtIndexPath:indexPath];
    
    NSString *displayIdentifier = [_dataSource displayIdentifierForIndexPath:indexPath];
    
    if ([_selectedIdents containsObject:displayIdentifier])
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    else
        cell.accessoryType = UITableViewCellAccessoryNone;
    
    return cell;
}

- (void)setSelectedIdents:(NSSet*)idents
{
    [_selectedIdents release];
    _selectedIdents = [idents mutableCopy];
    [_tableView reloadData];
}
- (NSSet*)selectedIdents
{
    return _selectedIdents;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *displayIdentifier = [_dataSource displayIdentifierForIndexPath:indexPath];
    
    if ([_selectedIdents containsObject:displayIdentifier])
    {
        [_selectedIdents removeObject:displayIdentifier];
    }
    else
    {
        [_selectedIdents addObject:displayIdentifier];
    }
    
    [_tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
}



@end
