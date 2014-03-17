//
//  SELangPrefs.m
//  SEPrefs
//
//  Created by K3A on 4/27/12.
//  Copyright (c) 2012 K3A. All rights reserved.
//

#import "SELangPrefs.h"
#import "SEPrefs.h"

@implementation SELangPrefs

- (id)initWithParent:(PSViewController<SELangPrefsDelegate>*)parent
{
    if ((self = [super init]))
    {
        _parent = parent;
        
        _defaultLangDict = [NSMutableDictionary new];
        [_defaultLangDict setObject:@"English (United States)" forKey:@"en-US"];
        [_defaultLangDict setObject:@"English (United Kingdom)" forKey:@"en-GB"];
        [_defaultLangDict setObject:@"English (Ireland)" forKey:@"en-IE"];
        [_defaultLangDict setObject:@"English (Australia)" forKey:@"en-AU"];
        [_defaultLangDict setObject:@"English (South Africa)" forKey:@"en-ZA"];
        [_defaultLangDict setObject:@"French (France)" forKey:@"fr-FR"];
        [_defaultLangDict setObject:@"French (Canada)" forKey:@"fr-CA"];
        [_defaultLangDict setObject:@"Russian" forKey:@"ru-RU"];
        [_defaultLangDict setObject:@"Thai" forKey:@"th-TH"];
        [_defaultLangDict setObject:@"Portuguese (Brazil)" forKey:@"pt-BR"];
        [_defaultLangDict setObject:@"Slovak" forKey:@"sk-SK"];
        [_defaultLangDict setObject:@"Romanian" forKey:@"ro-RO"];
        [_defaultLangDict setObject:@"Norwegian" forKey:@"no-NO"];
        [_defaultLangDict setObject:@"Finnish" forKey:@"fi-FI"];
        [_defaultLangDict setObject:@"Polish" forKey:@"pl-PL"];
        [_defaultLangDict setObject:@"German" forKey:@"de-DE"];
        [_defaultLangDict setObject:@"Dutch" forKey:@"nl-NL"];
        [_defaultLangDict setObject:@"Indonesian" forKey:@"id-ID"];
        [_defaultLangDict setObject:@"Turkish" forKey:@"tr-TR"];
        [_defaultLangDict setObject:@"Italian" forKey:@"it-IT"];
        [_defaultLangDict setObject:@"Portuguese (Portugal)" forKey:@"pt-PT"];
        [_defaultLangDict setObject:@"Spanish (Mexico)" forKey:@"es-MX"];
        [_defaultLangDict setObject:@"Chinese (Hong Kong)" forKey:@"zh-HK"];
        [_defaultLangDict setObject:@"Swedish" forKey:@"sv-SE"];
        [_defaultLangDict setObject:@"Hungarian" forKey:@"hu-HU"];
        [_defaultLangDict setObject:@"Chinese (Taiwan)" forKey:@"zh-TW"];
        [_defaultLangDict setObject:@"Spanish (Spain)" forKey:@"es-ES"];
        [_defaultLangDict setObject:@"Chinese" forKey:@"zh-CN"];
        [_defaultLangDict setObject:@"Dutch (Belgium)" forKey:@"nl-BE"];
        [_defaultLangDict setObject:@"Arabic (Saudi Arabia)" forKey:@"ar-SA"];
        [_defaultLangDict setObject:@"Korean" forKey:@"ko-KR"];
        [_defaultLangDict setObject:@"Czech" forKey:@"cs-CZ"];
        [_defaultLangDict setObject:@"Danish" forKey:@"da-DK"];
        [_defaultLangDict setObject:@"Hindi" forKey:@"hi-IN"];
        [_defaultLangDict setObject:@"Greek" forKey:@"el-GR"];
        [_defaultLangDict setObject:@"Japanese" forKey:@"ja-JP"];
        
        _arr = [[_defaultLangDict allKeys] mutableCopy];
        
        _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 480-64) style:UITableViewStyleGrouped];
        [_tableView setDelegate:self];
        [_tableView setDataSource:self];
        _tableView.editing = YES;
        
        [[self navigationItem] setTitle:@"Language Preference"];
    }
    return self;
}

-(void)dealloc
{
    [_tableView release];
    [_arr release];
    [_defaultLangDict release];
    [super dealloc];
}

- (id) view
{
    return _tableView;
}

-(void)saveOrder
{
    [_parent langPrefs:self changedOrder:_arr];
}

-(NSString*)langCodeToName:(NSString*)code
{
    return [_defaultLangDict objectForKey:code];
}

- (void)suspend
{
    [self saveOrder];
}

-(void)setLanguageArray:(NSArray*)arr
{
    [_arr autorelease];
    _arr = [[NSMutableArray alloc] initWithArray:arr];
    [_tableView reloadData];
}



-(BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath         
{
    return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath 
{
    return UITableViewCellEditingStyleNone;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{	
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_arr count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 45;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    //CGSize sz = tableView.frame.size;
    
    static NSString *CellIdentifier = @"SELPRow";
    
    cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) 
    {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    cell.textLabel.text = [self langCodeToName:[_arr objectAtIndex:indexPath.row]];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
    id obj = [_arr objectAtIndex:[fromIndexPath row]];
	[_arr removeObjectAtIndex:[fromIndexPath row]];
	[_arr insertObject:obj atIndex:[toIndexPath row]];
    
    [self saveOrder];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
}


@end
