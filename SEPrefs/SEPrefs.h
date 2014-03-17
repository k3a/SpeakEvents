//
//  SEPrefs.h
//  SEPrefs
//
//  Created by K3A on 3/3/12.
//  Copyright (c) 2012 K3A. All rights reserved.
//

#import <Preferences/PSListController.h>
#import <MessageUI/MessageUI.h>
#import "SEPrefsAppToggleController.h"
#import "SEHourController.h"
#import "SELangPrefs.h"

#define PREF_FILE "/var/mobile/Library/Preferences/me.k3a.SpeakEvents.plist"
#define COLOBUS_PREF_FILE "/var/mobile/Library/Preferences/.me.k3a.SpeakEvents.plist"

@interface K3ASEPrefsController : PSViewController <UITextFieldDelegate,UITableViewDataSource,UITableViewDelegate,
K3ASEPrefsHourControllerDelegate, SEPrefsAppToggleControllerDelegate, SELangPrefsDelegate,
MFMailComposeViewControllerDelegate,UIAlertViewDelegate> {
    UITableView *_tableView;
    NSMutableDictionary *_settings;
    NSMutableDictionary *_colobusSettings;
    NSSet* _speakApps;
    NSString* _softVersion;
    
    unsigned _state; // 0-unknown, 1-success, 2-fail
}
- (id) view;
- (id) navigationTitle;
- (void) dealloc;
- (void)loadFromSpecifier:(PSSpecifier *)spec;
- (void)setSpecifier:(PSSpecifier *)spec;
-(void)saveSettings;

-(void)onSuccess;
-(void)onFail;

@end


@interface SEWhatToRead : PSListController  {

}
@end

@interface SEReadingOptions : PSListController  {
    
}
@end

@interface SEActivatorActions : PSListController  {
    
}
@end

@interface SECustomizedAnnouncements : PSListController  {
    
}
@end

@interface UISwitch (K3ASEAdditions)
- (void)setAlternateColors:(BOOL)alternateColors;
@end
