//
//  SELangPrefs.h
//  SEPrefs
//
//  Created by K3A on 4/27/12.
//  Copyright (c) 2012 K3A. All rights reserved.
//
#import <Preferences/Preferences.h>

@class SELangPrefs;

@protocol SELangPrefsDelegate <NSObject>
@required
-(void)langPrefs:(SELangPrefs*)lp changedOrder:(NSArray*)order;
@end

@interface SELangPrefs: PSViewController <UITableViewDataSource,UITableViewDelegate> {
    UITableView* _tableView;
    PSViewController<SELangPrefsDelegate>* _parent;
    NSMutableArray* _arr;
    NSMutableDictionary* _defaultLangDict;
}
- (id)initWithParent:(PSViewController<SELangPrefsDelegate>*)parent;

-(void)setLanguageArray:(NSArray*)arr;
@end