//
//  SEHourController.h
//  SEPrefs
//
//  Created by K3A on 2/26/12.
//  Copyright (c) 2012 K3A. All rights reserved.
//
#import "Shared.h"
#import <Preferences/Preferences.h>

@class K3ASEPrefsHourController;

@protocol K3ASEPrefsHourControllerDelegate <NSObject>
@required
-(void)hourController:(K3ASEPrefsHourController*)hc selectedHour:(unsigned)hour;
@end


@interface K3ASEPrefsHourController: PSViewController <UITableViewDataSource,UITableViewDelegate> {
    UITableView* _tableView;
    PSViewController<K3ASEPrefsHourControllerDelegate>* _parent;
    unsigned _tag;
    int _checked;
}
- (id)initWithParent:(PSViewController<K3ASEPrefsHourControllerDelegate>*)parent;

-(unsigned)tag;
-(void)setTag:(unsigned)t;
-(void)setSelectedHour:(unsigned)h;
@end