//
//  SEHourController.m
//  SEPrefs
//
//  Created by K3A on 2/26/12.
//  Copyright (c) 2012 K3A. All rights reserved.
//

#import "SEHourController.h"

@implementation K3ASEPrefsHourController
- (id)initWithParent:(PSViewController<K3ASEPrefsHourControllerDelegate>*)parent
{
    if ( (self = [super init]) )
    {
        _parent = parent;
        _checked = -1;
        
        _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 480-64) style:UITableViewStyleGrouped];
        [_tableView setDelegate:self];
        [_tableView setDataSource:self];
        
        [[self navigationItem] setTitle:@"Select an Hour"];
    }
    
    return self;
}
-(void)dealloc
{
    [_tableView release];
	[super dealloc];
}
- (id) view
{
    return _tableView;
}
-(unsigned)tag
{
    return _tag;
}
-(void)setTag:(unsigned)t
{
    _tag = t;
}
-(void)setSelectedHour:(unsigned)h
{
    _checked = (int)h;
    [_tableView reloadData];
}

- (void)suspend
{
    [_parent hourController:self selectedHour:_checked];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{	
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 24;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 45;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    CGSize sz = tableView.frame.size;
    
    static NSString *CellIdentifier = @"SEHourRow";
    
    cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) 
    {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
    cell.textLabel.text = [NSString stringWithFormat:@"%02u:00", indexPath.row]; 
    if (_checked == indexPath.row)
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    else
        cell.accessoryType = UITableViewCellAccessoryNone;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [_parent hourController:self selectedHour:(unsigned)indexPath.row];
}

@end