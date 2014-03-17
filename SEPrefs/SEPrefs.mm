#import <Preferences/Preferences.h>
#import <Twitter/Twitter.h>
#import <Accounts/Accounts.h>
#import <UIKit/UIKit.h>
#include <AppSupport/CPDistributedMessagingCenter.h>

#import "Shared.h"
#import "SEPrefs.h"

#include <asl.h>

static void AlertView(NSString* title, NSString* text)
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:text  delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
    [alert release];
}

static NSString* GetSystemLanguage()
{
    NSString *language = [[NSLocale preferredLanguages] objectAtIndex:0];
    /*NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
     NSArray* arrayLanguages = [userDefaults objectForKey:@"AppleLanguages"];
     NSString* language = [arrayLanguages objectAtIndex:0];*/
    
    char lang[16];
    strcpy(lang, [language UTF8String]);
    
    unsigned sepIdx = strlen(lang);
    bool afterSep = false;
    for (unsigned i=0; i<strlen(lang); i++)
    {
        if (lang[i] == '_' || lang[i] == '-')
        {
            lang[i] = '-';
            sepIdx = i;
            afterSep = true;
        }
        else if (afterSep)
            lang[i] = toupper(lang[i]);
    }
    
    return [NSString stringWithUTF8String:lang];
}

// ---------------------------------------------------------------------------------------------------------------------------
#pragma mark - LEGAL CONTROLLER
@interface K3ASEPrefsLegalController: PSViewController {
    UITextView *__view;
}
- (id) view;
- (id) navigationTitle;
@end

@implementation K3ASEPrefsLegalController
- (id)init
{
    if ( (self = [super init]) )
    {
        __view = [[UITextView alloc] initWithFrame:CGRectMake(0,0,320,400)];
        NSString* path = [[NSBundle bundleForClass:[self class]] pathForResource:@"about" ofType:@"txt"];
        __view.text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        __view.editable = NO;
    }
    
    return self;
}
-(void)dealloc
{
    [__view release];
	[super dealloc];
}
- (id) view
{
    return __view;
}
- (id) navigationTitle
{
    return @"About";
}
@end

// ---------------------------------------------------------------------------------------------------------------------------
#pragma mark - BUY CONTROLLER
@interface K3ASEPrefsBuyController: PSViewController {
    UIWebView *__view;
}
- (id) view;
- (id) navigationTitle;
@end

@implementation K3ASEPrefsBuyController
- (id)init
{
    if ( (self = [super init]) )
    {
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage 
                                              sharedHTTPCookieStorage]; 
        [cookieStorage setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
        
        __view = [[UIWebView alloc] initWithFrame:CGRectMake(0,0,320,400)];
        __view.scalesPageToFit = YES;
        [__view loadHTMLString:@"<h3>Loading, please wait...</h3>" baseURL:nil];
    }
    
    return self;
}
-(void)startLoadingForEmail:(NSString*)email
{
    NSString* url = [NSString stringWithFormat:@"http://se.k3a.me/accounts/buy?email=%@", email];
    [__view loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
}
-(void)dealloc
{
    [__view release];
	[super dealloc];
}
- (id) view
{
    return __view;
}
- (id) navigationTitle
{
    return @"Buy";
}
@end


//-------------------------------------------------------------------------------------------------------------------------------

@implementation K3ASEPrefsController

static K3ASEPrefsController* s_singleton = nil;

static void ColobusSuccess(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    NSLog(@"SE: Success");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [s_singleton onSuccess];
    }); 
}

static void ColobusFail(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    NSLog(@"SE: Fail");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [s_singleton onFail];
    }); 
}

-(void)onSuccess
{
    _state = 1;
    [_tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];

	AlertView(@"Thank you!", @"Software activated.");
}
-(void)onFail
{
    _state = 2;
    [_tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
}

-(void)loadSettings
{
    [_settings release];
    _settings = [[NSMutableDictionary alloc] initWithContentsOfFile:@PREF_FILE];
    if (_settings)
        NSLog(@"SE: Prefs: Preferences loaded.");
    else
    {
        NSLog(@"SE: Prefs: Failed to load preferences. Creating...");
        _settings = [[NSMutableDictionary alloc] init];
    }
}

- (id)init
{
    if ( (self = [super init]) )
    {
        s_singleton = self;
        
        [self loadSettings];
        
        _colobusSettings = [[NSMutableDictionary alloc] initWithContentsOfFile:@COLOBUS_PREF_FILE];
        if (_colobusSettings)
            NSLog(@"SE: Prefs: Shadow preferences loaded.");
        else
        {
            NSLog(@"SE: Prefs: Failed to load shadow preferences. Creating...");
            _colobusSettings = [[NSMutableDictionary alloc] init];
        }
        
        // apply defaults
        _speakApps = nil;
        NSData* speakAppsData = [_settings objectForKey:@"speakApps"];
        if (speakAppsData)
        {
            _speakApps = [[NSKeyedUnarchiver unarchiveObjectWithData:speakAppsData] retain];
            if (!_speakApps) _speakApps = [[NSSet alloc] init];
        }
        else
        {
            _speakApps = [[NSSet setWithObjects:@"com.apple.MobileSMS", @"com.apple.mobilemail", nil] retain];
            [_settings setObject:[NSKeyedArchiver archivedDataWithRootObject:_speakApps] forKey:@"speakApps"];
        }
        if (![_settings objectForKey:@"detectLang"])
            [_settings setObject:[NSNumber numberWithBool:YES] forKey:@"detectLang"];
        if (![_settings objectForKey:@"speakBattery"])
            [_settings setObject:[NSNumber numberWithBool:YES] forKey:@"speakBattery"];
        if (![_settings objectForKey:@"speakSilent"])
            [_settings setObject:[NSNumber numberWithBool:YES] forKey:@"speakSilent"];
        
        // save defaults just in case
        [_settings writeToFile:@PREF_FILE atomically:YES];
        
        // add observers
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), self, ColobusSuccess, (CFStringRef)@"me.k3a.SpeakEvents.colobus.success", NULL, CFNotificationSuspensionBehaviorCoalesce);
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), self, ColobusFail, (CFStringRef)@"me.k3a.SpeakEvents.colobus.fail", NULL, CFNotificationSuspensionBehaviorCoalesce);
        
        // get status
        CPDistributedMessagingCenter* msgCenter = [CPDistributedMessagingCenter centerNamed:@"me.k3a.SpeakEvents.colobus"];
        NSDictionary* input = [NSDictionary dictionaryWithObject:@"getStatus" forKey:@"action"];
        NSDictionary* statusOut = [msgCenter sendMessageAndReceiveReplyName:@"message" userInfo:input];
        _state = 0;
        if (statusOut)
        {
            if ([[statusOut objectForKey:@"result"] boolValue])
                _state = 1;
            else
                _state = 2;
        }
    }
    
    return self;
}

- (void) dealloc {
    
    // remove observer
    CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(), self);
    s_singleton = nil;
    
    [_tableView release];
    [_settings release];
    [_colobusSettings release];
    [super dealloc];
}

-(void)followSafari
{
    NSString* followUrl = @"https://twitter.com/intent/follow?original_referer=http%3A%2F%2Fae.k3a.me%2F&region=follow_link&screen_name=kexik&source=followbutton&variant=2.0";
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:followUrl]];
}

- (void)follow
{
    ACAccountStore *accountStore = [[[ACAccountStore alloc] init] autorelease];
    
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    
    [accountStore requestAccessToAccountsWithType:accountType withCompletionHandler:^(BOOL granted, NSError *error) {
        if(granted) {
            // Get the list of Twitter accounts.
            NSArray *accountsArray = [accountStore accountsWithAccountType:accountType];
            
            // For the sake of brevity, we'll assume there is only one Twitter account present.
            // You would ideally ask the user which account they want to tweet from, if there is more than one Twitter account present.
            if ([accountsArray count] > 0) {
                // Grab the initial Twitter account to tweet from.
                ACAccount *twitterAccount = [accountsArray objectAtIndex:0];
                
                NSMutableDictionary *tempDict = [[NSMutableDictionary alloc] init];
                [tempDict setValue:@"kexik" forKey:@"screen_name"];
                [tempDict setValue:@"true" forKey:@"follow"];
                
                TWRequest *postRequest = [[TWRequest alloc] initWithURL:[NSURL URLWithString:@"http://api.twitter.com/1/friendships/create.json"] 
                                                             parameters:tempDict 
                                                          requestMethod:TWRequestMethodPOST];
                
                
                [postRequest setAccount:twitterAccount];
                
                [postRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
                    if ([urlResponse statusCode] != 200)
                    {
                        NSLog(@"SE: Prefs: TWF Status: %i", [urlResponse statusCode]);
                        [self followSafari];
                    }
                    else
                    {
                        NSLog(@"SE: Prefs: TWF Success");
                        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Follow" message:@"Thanks!"  delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
                        [alert show];
                        [alert release];
                    }
                }];
            }
            else
            {
                [self followSafari]; // no accounts
            }
        }
        else
            [self followSafari]; // denied
    }];
}


- (void)setSpecifier:(PSSpecifier *)spec{
	[self loadFromSpecifier:spec];
}

- (void)loadFromSpecifier:(PSSpecifier *)spec{
	_tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 480-64) style:UITableViewStyleGrouped];
	[_tableView setDelegate:self];
	[_tableView setDataSource:self];

	if ([self respondsToSelector:@selector(navigationItem)])
		[[self navigationItem] setTitle:@"SpeakEvents"];
}

- (void)viewWillAppear:(UIView*)view 
{
    //NSLog(@"SE: View will appear");
    [self loadSettings];
}

- (id) view {
	return _tableView;
}
-(id)table {
	return _tableView;
}

- (id) navigationTitle {
	return [super navigationTitle];
}

-(void)saveSettings
{
    if ([_settings writeToFile:@PREF_FILE atomically:YES])
        NSLog(@"SE: Prefs: Settings saved");
    else
        NSLog(@"SE: Prefs: Failed to save settings");
    
    NSString* email = [_settings objectForKey:@"email"];
    if (email) [_colobusSettings setObject:email forKey:@"email"];
    if ([_colobusSettings writeToFile:@COLOBUS_PREF_FILE atomically:YES])
        NSLog(@"SE: Prefs: Shadow settings saved");
    else
        NSLog(@"SE: Prefs: Failed to save shadow settings");
    
    // inform the tweak
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("me.k3a.SpeakEvents/reloadPrefs"), NULL, NULL, false);
}

- (void)suspend
{
    [self saveSettings];
}


static BOOL s_doneShown = NO;
-(void)hideDone
{
    [[self navigationItem] setRightBarButtonItem:nil animated:NO];
    s_doneShown = NO;
}
- (void)onDone:(id)sender
{
    [self.view endEditing:TRUE];
    
    // save preferences
    [self saveSettings];
    
    /*UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Title" message:@"DONE!"  delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
    [alert release];*/
    
    [_tableView beginUpdates];
    [_tableView endUpdates];
    
    [self hideDone];
}
-(void)showDone
{
    if (s_doneShown) return;
    
    UIBarButtonItem *anotherButton = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(onDone:)];
    [[self navigationItem] setRightBarButtonItem:anotherButton animated:YES];
    [anotherButton release];
    
    s_doneShown = YES;
}

// text views
- (void) textFieldDidEndEditing:(UITextField *)textField {
    switch (textField.tag) {
        case 1:
            //NSLog(@"E-Mail: %@", textField.text);
            [_settings setObject:textField.text forKey:@"email"];
			textField.secureTextEntry = YES;
            break;
        default:
            NSLog(@"Unknown textfield %u: %@", textField.tag, textField.text);
            break;
    }
    [self saveSettings];
}
- (void) textFieldDidBeginEditing:(UITextField *)textField {
	textField.secureTextEntry = NO;
    [self showDone];
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{	
	return 5;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    /*if (section == 0)
        return @"Donation";
    else if (section == 1)
        return @"Links";*/
    
    if (section == 1)
        return @"Speak";
    
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 1)
        return @"Setting both values to the same time will disable time limitation.";
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) // license and buttons
        return 0;
    else if (section == 1) // speak
        return 7;
    else if (section == 2) // link cells
        return 6;
    else if (section == 3) // follow and web and notificator
        return 3; /* 3=without notificator*/
    else if (section == 4) // legal
        return 1;
        
	return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
{
    if (indexPath.section == 0)
    {
       // if (indexPath.row == 2)
         //   return 50;
    }
    return 45;
}

-(void)switchChanged:(UISwitch*)sw
{
    if ([sw tag] == 0) 
    {
        NSLog(@"SE: Prefs: Enabled toggle = %u", sw.on);
        [_settings setObject:[NSNumber numberWithBool:sw.on] forKey:@"enabled"];
    }
    else if ([sw tag] == 1)
    {
        NSLog(@"SE: Prefs: HP only = %u", sw.on);
        [_settings setObject:[NSNumber numberWithBool:sw.on] forKey:@"hpOnly"];
    }
    else if ([sw tag] == 2) 
    {
        NSLog(@"SE: Prefs: Speak in bluetooth = %u", sw.on);
        [_settings setObject:[NSNumber numberWithBool:sw.on] forKey:@"speakInBT"];
    }
    else if ([sw tag] == 3)
    {
        NSLog(@"SE: Prefs: Speak when locked only = %u", sw.on);
        [_settings setObject:[NSNumber numberWithBool:sw.on] forKey:@"lockedOnly"];
    }
    else if ([sw tag] == 4) 
    {
        NSLog(@"SE: Prefs: Speak in silent = %u", sw.on);
        [_settings setObject:[NSNumber numberWithBool:sw.on] forKey:@"inSilent"];
    }
    
    [self saveSettings];
}
-(void)hourController:(K3ASEPrefsHourController*)hc selectedHour:(unsigned)hour
{
    if (hc.tag == 5)
    {
        NSLog(@"SE: Selected 'from' hour = %u", hour);
        [_settings setObject:[NSNumber numberWithUnsignedInt:hour] forKey:@"speakFrom"];
    }
    else if (hc.tag == 6)
    {
        NSLog(@"SE: Selected 'to' hour = %u", hour);
        [_settings setObject:[NSNumber numberWithUnsignedInt:hour] forKey:@"speakTo"];
    }
    [self saveSettings];
    [self.navigationController popViewControllerAnimated:YES];
    
    [_tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
}

-(void)langPrefs:(SELangPrefs*)lp changedOrder:(NSArray*)order
{
    [_settings setObject:[[order copy] autorelease] forKey:@"langPrefs"];
    [self saveSettings];
}

-(void)appToggleController:(SEPrefsAppToggleController*)atc didFinishedSelection:(NSSet*)appIdents
{
    //NSLog(@"AppToggle Set: %@", appIdents);
    [_speakApps release];
    _speakApps = [appIdents copy];
    
    [_settings setObject:[NSKeyedArchiver archivedDataWithRootObject:_speakApps] forKey:@"speakApps"];
    [self saveSettings];
    
    [_tableView reloadSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:UITableViewRowAnimationNone];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    CGSize sz = tableView.frame.size;
    
    if (indexPath.section == 1) // switches + speak between...
    {
        if (indexPath.row == 0)
        {
            static NSString *CellIdentifier = @"SESwitchAlternate";
            cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil) 
            {
                cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
                
                UISwitch *switchView = [[UISwitch alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
                switchView.tag = indexPath.row;
                cell.accessoryView = switchView;
                cell.textLabel.text = @"SpeakEvents Enabled";
                [switchView setAlternateColors:YES];
                NSNumber* h = [_settings objectForKey:@"enabled"];
                [switchView setOn:(!h || [h boolValue]) animated:NO];
                [switchView addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
                [switchView release];
            }
        }
        else if (indexPath.row > 0 && indexPath.row < 5)
        {
            static NSString *CellIdentifier = @"SESwitch";
            cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil) 
            {
                cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
                
                UISwitch *switchView = [[UISwitch alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
                switchView.tag = indexPath.row;
                cell.accessoryView = switchView;
                [switchView setOn:NO animated:NO];
                [switchView addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
                [switchView release];
            }
             
            if (indexPath.row == 1)
            {
                NSNumber* prefNum = [_settings objectForKey:@"hpOnly"];
                [(UISwitch*)cell.accessoryView setOn:prefNum && [prefNum boolValue]];
                cell.textLabel.text = @"With Headphones Only";
            }
            if (indexPath.row == 2)
            {
                NSNumber* prefNum = [_settings objectForKey:@"speakInBT"];
                [(UISwitch*)cell.accessoryView setOn:prefNum && [prefNum boolValue]];
                cell.textLabel.text = @"In Bluetooth HF";
            }
            else if (indexPath.row == 3)
            {
                NSNumber* prefNum = [_settings objectForKey:@"lockedOnly"];
                [(UISwitch*)cell.accessoryView setOn:prefNum && [prefNum boolValue]];
                cell.textLabel.text = @"Only When Locked";
            }
            else if (indexPath.row == 4)
            {
                NSNumber* prefNum = [_settings objectForKey:@"inSilent"];
                [(UISwitch*)cell.accessoryView setOn:!prefNum || [prefNum boolValue]];
                cell.textLabel.text = @"In Silent Mode";
            }
        }
        else
        {
            static NSString *CellIdentifier = @"SEMoreCell";
            
            cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil) 
            {
                cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier] autorelease];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }
            
            if (indexPath.row == 5)
            {
                cell.textLabel.text = @"Start Hour";
                
                NSNumber* h = [_settings objectForKey:@"speakFrom"];
                if (h) 
                    [cell.detailTextLabel setText:[NSString stringWithFormat:@"%02u:00", [h unsignedIntValue]]];
                else
                    [cell.detailTextLabel setText:@"Not Set"];
            }
            else if (indexPath.row == 6)
            {
                cell.textLabel.text = @"End Hour";
                
                NSNumber* h = [_settings objectForKey:@"speakTo"];
                if (h) 
                    [cell.detailTextLabel setText:[NSString stringWithFormat:@"%02u:00", [h unsignedIntValue]]];
                else
                    [cell.detailTextLabel setText:@"Not Set"];
            }
        }
    }
    else if (indexPath.section == 2) // switches
    {
        static NSString *CellIdentifier = @"SEMoreCell";
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) 
        {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier] autorelease];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        
        if (indexPath.row == 0)
        {
            cell.textLabel.text = @"Apps to Speak";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%u apps", [_speakApps count]];
        }
        else if (indexPath.row == 1)
        {
            cell.textLabel.text = @"What to Speak";
            cell.detailTextLabel.text = @"";
        }
        else if (indexPath.row == 2)
        {
            cell.textLabel.text = @"Reading Options";
            cell.detailTextLabel.text = @"";
        }
        else if (indexPath.row == 3)
        {
            cell.textLabel.text = @"Activator Actions";
            cell.detailTextLabel.text = @"";
        }
        else if (indexPath.row == 4)
        {
            cell.textLabel.text = @"Language Preference";
            cell.detailTextLabel.text = @"";
        }
        else if (indexPath.row == 5)
        {
            cell.textLabel.text = @"Customized Announcements";
            cell.detailTextLabel.text = @"";
        }
    }
    else if (indexPath.section == 3)
    {
        /*if (indexPath.row == 0)
        {
            static NSString *CellIdentifier = @"AEWeb";
            
            cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil) 
            {
                cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
                
                UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(8,0,sz.width-35, 40)];
                label.font = [UIFont systemFontOfSize:15];
                label.numberOfLines = 0;
                label.backgroundColor = [UIColor clearColor];
                label.textAlignment = UITextAlignmentCenter;
                label.text = @"Website: http://ae.k3a.me";
                
                [cell.contentView addSubview:label];
                [label release];
            }
        }
        else */if (indexPath.row == 0)
        {
            static NSString *CellIdentifier = @"SELink";
            cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil) 
            {
                cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
                
                UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(8,0,sz.width-35, 40)];
                label.font = [UIFont boldSystemFontOfSize:15];
                label.numberOfLines = 0;
                label.backgroundColor = [UIColor clearColor];
                label.textAlignment = UITextAlignmentCenter;
                label.text = @">>  Follow Me @kexik  <<";
                
                [cell.contentView addSubview:label];
                [label release];
            }
        }
        else if (indexPath.row == 1)
        {
            static NSString *CellIdentifier = @"SELink";
            cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil) 
            {
                cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
                
                UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(8,0,sz.width-35, 40)];
                label.font = [UIFont boldSystemFontOfSize:15];
                label.numberOfLines = 0;
                label.backgroundColor = [UIColor clearColor];
                label.textAlignment = UITextAlignmentCenter;
                label.text = @">>  SpeakEvents Website  <<";
                
                [cell.contentView addSubview:label];
                [label release];
            }
        }
        else if (indexPath.row == 2)
        {
            static NSString *CellIdentifier = @"SELink";
            cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil) 
            {
                cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
                
                UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(8,0,sz.width-35, 40)];
                label.font = [UIFont boldSystemFontOfSize:15];
                label.numberOfLines = 0;
                label.backgroundColor = [UIColor clearColor];
                label.textAlignment = UITextAlignmentCenter;
                label.text = @"Send Diagnostic Log";
                
                [cell.contentView addSubview:label];
                [label release];
            }
        }
        else if (indexPath.row == 3)
        {
            static NSString *CellIdentifier = @"SENotificator";
            cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil) 
            {
                cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
                
                UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(50,0,sz.width-85, 40)];
                label.font = [UIFont boldSystemFontOfSize:15];
                label.numberOfLines = 0;
                label.backgroundColor = [UIColor clearColor];
                label.textAlignment = UITextAlignmentLeft;
                label.text = @"Get more speakable\nnotifications with Notificator.";
                
                [cell.contentView addSubview:label];
                cell.imageView.image = [UIImage imageWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"Notificator" ofType:@"png"]];
                [label release];
            }
            
            //Notificator.png
        }
    }
    else if (indexPath.section == 4)
    {
        if (indexPath.row == 0)
        {
            static NSString *CellIdentifier = @"SELegal";
            
            cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil) 
            {
                cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
                
                cell.textLabel.text = @"About";
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;//UITableViewCellAccessoryDetailDisclosureButton;
            }
        }
    }
    
    if (!cell)
    {
        static NSString *CellIdentifier = @"SADefaultCell";
        
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) 
        {
            cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil) 
                cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
        }
    }
 
    return cell;
}

-(BOOL)downloadLicense:(NSString*)email
{
    [self saveSettings];
    
    // try to download lic
    CPDistributedMessagingCenter* msgCenter = [CPDistributedMessagingCenter centerNamed:@"me.k3a.SpeakEvents.colobus"];
    NSDictionary* input = [NSDictionary dictionaryWithObject:@"downloadLicense" forKey:@"action"];
    [msgCenter sendMessageName:@"message" userInfo:input];
	
	/*NSDictionary* output = [msgCenter sendMessageAndReceiveReplyName:@"message" userInfo:input];
    
    if ([[output objectForKey:@"status"] isEqualToString:@"error"])
    {
        NSString* errDesc = [output objectForKey:@"description"];
        NSString* errorMsg = nil;
        if (errDesc && [errDesc length]>0)
            errorMsg = [NSString stringWithFormat:@"%@", errDesc];
        else
            errorMsg = @"Unexpected error! Please try again later.";
        AlertView(@"Error", errorMsg);
    }
    else 
    {
        AlertView(@"Thank you!", @"Software activated.");
        // try load
        NSDictionary* input = [NSDictionary dictionaryWithObject:@"tryLoad" forKey:@"action"];
        [msgCenter sendMessageAndReceiveReplyName:@"message" userInfo:input];
    }*/

    
    //NSLog(@"SE: Server returned dict %@", resp);
    
    return TRUE;
}

-(NSString*)aslLog
{
    NSMutableString *consoleLog = [NSMutableString string];
    
    aslclient client = asl_open(NULL, NULL, ASL_OPT_STDERR);
    
    NSTimeInterval fromTimestamp = [[NSDate date] timeIntervalSince1970]-60*60*24*10;
    char strFrom[128];
    sprintf(strFrom, "%.0f", fromTimestamp);
    
    aslmsg query = asl_new(ASL_TYPE_QUERY);
    //asl_set_query(query, ASL_KEY_SENDER, "SpringBoard", ASL_QUERY_OP_EQUAL);
    //asl_set(query, ASL_KEY_FACILITY, "com.apple.springboard");
    asl_set_query(query, ASL_KEY_TIME, strFrom, ASL_QUERY_OP_GREATER_EQUAL);
    asl_set_query(query, ASL_KEY_MSG, NULL, ASL_QUERY_OP_NOT_EQUAL);
    aslresponse response = asl_search(client, query);
    
    asl_free(query);
    
    aslmsg message;
    while((message = aslresponse_next(response)))
    {
        const char *msg = asl_get(message, ASL_KEY_MSG);
        const char *sender = asl_get(message, ASL_KEY_SENDER);
        if (msg && (!strncmp(msg, "SE: ", 4) || !strncmp(msg, "Colobus:", 8)) )
            [consoleLog appendFormat:@"%s: %s\n", sender, msg];
    }
    
    aslresponse_free(response);
    asl_close(client);
    
    return consoleLog;
}

-(BOOL)syslogEnabled
{
    NSDictionary* syslogDict = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/LaunchDaemons/com.apple.syslogd.plist"];
    if (!syslogDict)
    {
        NSLog(@"SE: Prefs: Could not open syslog daemon definition plist!");
        return NO;
    }
    
    NSArray* args = [syslogDict objectForKey:@"ProgramArguments"];
    if (!args)
    {
        NSLog(@"SE: Prefs: ProgramArguments not found in syslog daemon definition plist!");
        return NO;
    }
    
    for (unsigned idx=0; idx<[args count]; idx++)
    {
        NSString* arg = [args objectAtIndex:idx];
        if ([arg caseInsensitiveCompare:@"-bsd_out"] == NSOrderedSame && idx+1<[args count])
        {
            return [[args objectAtIndex:idx+1] isEqualToString:@"1"];
        }
    }
    
    return NO;
}

-(NSString*)syslog
{
    FILE* fp = fopen("/var/log/syslog", "rb");
    if (!fp)
    {
        NSLog(@"SE: Prefs: Failed to open syslog!");
        return nil;
    }
    
    fseek(fp, 0, SEEK_END);
    size_t len = ftell(fp);
    
    size_t reqLen = 4000*100;
    if (len < reqLen) reqLen = len;
    
    // read into buf
    fseek(fp, len-reqLen, SEEK_SET);
    char* buf = (char*)malloc(reqLen+1);
    fread(buf, 1, reqLen, fp);
    buf[reqLen]=0;
    
    NSMutableString* ret = [NSMutableString string];
    char* line = strtok(buf, "\n");
    while (line) 
    {
        if (strstr(line, "SpringBoard") || strstr(line, "Preferences") || strstr(line, "ReportCrash"))
            [ret appendFormat:@"%s\n", line];
        
        line = strtok(NULL, "\n");
    }
    
    // clean
    free(buf);
    fclose(fp);
    
    return ret;
}

-(NSString*)latestSpringBoardCrash
{
    return [NSString stringWithContentsOfFile:@"/var/mobile/Library/Logs/CrashReporter/LatestCrash-SpringBoard.plist" encoding:NSUTF8StringEncoding error:nil];
}

-(NSString*)listOfPackages
{
    [_softVersion release];
    _softVersion = nil;
    
    FILE* fp = fopen("/var/lib/dpkg/status", "rb");
    if (!fp)
    {
        NSLog(@"SE: Prefs: Failed to open the list of apt packages!");
        return nil;
    }
    else
    {
        NSMutableString* ret = [NSMutableString string];
        
        char line[512];
        int linelen = 0;
        bool packageParsed=false;
        char package[256];
        
        while(!feof(fp))
        {
            fgets(line, 510, fp);
            linelen = strlen(line);
            if (linelen < 3) continue; // probably a new line only => skip
            
            // strip \n and \r in the end
            if (line[linelen-2]=='\r' || line[linelen-2]=='\n')
            {
                line[linelen-2] = 0;
                linelen-=2;
            }
            else if (line[linelen-1]=='\r' || line[linelen-1]=='\n')
            {
                line[linelen-1] = 0;
                linelen-=1;
            }
            line[linelen] = 0; // terminate
            
            // now we have a line
            if (!packageParsed && !strncmp(line, "Package: ", 9))
            {                
                strncpy(package, &line[9], 255);
                package[255]=0;
                packageParsed = true;
            }
            else if (packageParsed && !strncmp(line, "Version: ", 9))
            {
                packageParsed = false;
                char ver[16];
                strncpy(ver, &line[9], 15);
                ver[15]=0;
                
                if (!strcmp(package, "me.k3a.speakevents"))
                    _softVersion = [[NSString alloc] initWithUTF8String:ver];
                
                [ret appendFormat:@"%s: %s\n", package, ver];
            }
            
        }
        
        fclose(fp);
        return ret;
    }
}

-(NSString*)settingsFile
{
    return [NSString stringWithContentsOfFile:@"/var/mobile/Library/Preferences/me.k3a.SpeakEvents.plist" usedEncoding:nil error:nil];
}

-(void)sendDiagnosticLogs
{
    static bool askedForSyslog = false;
    
    BOOL hasSyslog = [self syslogEnabled];
    
    if (!hasSyslog && !askedForSyslog)
    {
        askedForSyslog = true;

        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Syslog not enabled" message:@"If you are reporting a crash, syslog may be useful. Do you want to get more info about syslog?"  delegate:self cancelButtonTitle:@"Report anyway" otherButtonTitles:@"Yes",nil];
        alert.tag = 666;
        [alert show];
        [alert release];
        
        return;
    }
    
    // send diagnostic logs
    MFMailComposeViewController *mail = [[[MFMailComposeViewController alloc] init] autorelease];
    mail.mailComposeDelegate = self;
    
    [mail setToRecipients:[NSArray arrayWithObject:@"se@k3a.me"]];
    [mail setMessageBody:@"Please briefly describe your problem or steps to reproduce it. If you asked for help via Twitter, please specify your username.\r\n\r\n\r\n(If you do not write anything, it will be ignored.)\r\n\r\n" isHTML:NO];
    
    NSString* syslog = [self syslog];
    if (hasSyslog) 
    {
        [mail addAttachmentData:[syslog dataUsingEncoding:NSUTF8StringEncoding] mimeType:@"text/plain" fileName:@"system.log"];
    }
    
    NSString* aslLog = [self aslLog];
    if (aslLog)
    {
        [mail addAttachmentData:[aslLog dataUsingEncoding:NSUTF8StringEncoding] mimeType:@"text/plain" fileName:@"asl.log"];
    }
    
    NSString* latestCrash = [self latestSpringBoardCrash];
    if (latestCrash)
    {
        [mail addAttachmentData:[latestCrash dataUsingEncoding:NSUTF8StringEncoding] mimeType:@"text/plain" fileName:@"LatestCrash-SpringBoard.plist"];
    }
    
    NSString* packages = [self listOfPackages];
    if (packages)
    {
        [mail addAttachmentData:[packages dataUsingEncoding:NSUTF8StringEncoding] mimeType:@"text/plain" fileName:@"packages.txt"];
    }
    
    NSString* settings = [self settingsFile];
    if (settings)
    {
        [mail addAttachmentData:[settings dataUsingEncoding:NSUTF8StringEncoding] mimeType:@"text/plain" fileName:@"settings.plist"];
    }
    
    [mail setSubject:[NSString stringWithFormat:@"Diagnostic Logs - %@", _softVersion]];
    
    [self presentModalViewController:mail animated:YES];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == 666)
    {
        if (buttonIndex == 0)
        {
            [self sendDiagnosticLogs];
        }
        else if (buttonIndex == 1)
        {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://se.k3a.me/syslog.html"]];
        }
    }
}

-(BOOL)checkEmail:(NSString*)checkString
{
   BOOL stricterFilter = YES; // Discussion http://blog.logichigh.com/2010/09/02/validating-an-e-mail-address/
   NSString *stricterFilterString = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}";
   NSString *laxString = @".+@.+\\.[A-Za-z]{2}[A-Za-z]*";
   NSString *emailRegex = stricterFilter ? stricterFilterString : laxString;
   NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
   if (![emailTest evaluateWithObject:checkString])
	{
		AlertView(@"Please Enter Valid E-Mail", @"Please enter an email for license identification. We don't allow nicknames anymore to prevent abuse. If you previously used a nickname, please use your PayPal email address if you have one, otherwise contact support at se@k3a.me.");
		return NO;
	}
	else
		return YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    if (indexPath.section == 0)
    {
        NSString* email = nil;
        if (indexPath.row == 2 || indexPath.row == 3)
        {
            [self.view endEditing:TRUE];
            
            email = [_settings objectForKey:@"email"];
            if ([email length] == 0)
            {
                AlertView(@"E-Mail", @"Please enter an e-mail address.");
                return;
            }
        }
            
        if (indexPath.row == 2) //download license
        {
			if (![self checkEmail:email])
				return;

            [self downloadLicense:email];
            return;
        }
        else if (indexPath.row == 3) //buy license
        {
			if (![self checkEmail:email])
				return;

            // check that cookies are enabled
            NSDictionary* webf = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.apple.WebFoundation.plist"];
            NSString* acceptCookies = [webf objectForKey:@"NSHTTPAcceptCookies"];
            if (acceptCookies && ![acceptCookies isEqualToString:@"always"])
            {
                AlertView(@"Cookies not enabled", @"Please set \"Accept Cookies\" in Settings->Safari to \"Always\" first.");
                return;
            }
            
            NSString* followUrl = [NSString stringWithFormat:@"http://se.k3a.me/accounts/buy?email=%@", email];
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:followUrl]];
            
            /*K3ASEPrefsBuyController* ctrl = [[[K3ASEPrefsBuyController alloc] init] autorelease];
            ctrl.parentController = self; 
            ctrl.rootController = self.rootController;
            [ctrl startLoadingForEmail:email];
            [self pushController:ctrl];*/
        }
    }
    else if (indexPath.section == 1) // from to hours
    {        
        if (indexPath.row == 5)
        {
            K3ASEPrefsHourController* ctrl = [[[K3ASEPrefsHourController alloc] initWithParent:self] autorelease];
            ctrl.parentController = self;
            ctrl.rootController = self.rootController;
            ctrl.tag = indexPath.row;
            
            NSNumber* h = [_settings objectForKey:@"speakFrom"];
            if (h) [ctrl setSelectedHour:[h unsignedIntValue]];
            
            [self pushController:ctrl];
        }
        else if (indexPath.row == 6)
        {
            K3ASEPrefsHourController* ctrl = [[[K3ASEPrefsHourController alloc] initWithParent:self] autorelease];
            ctrl.parentController = self;
            ctrl.rootController = self.rootController;
            ctrl.tag = indexPath.row;
            
            NSNumber* h = [_settings objectForKey:@"speakTo"];
            if (h) [ctrl setSelectedHour:[h unsignedIntValue]];
            
            [self pushController:ctrl];
        }
    }
    else if (indexPath.section == 2) // what to speak (switches)
    {
        if (indexPath.row == 0)
        {
            SEPrefsAppToggleController* ctrl = [[[SEPrefsAppToggleController alloc] initWithParent:self] autorelease];
            ctrl.parentController = self;
            ctrl.rootController = self.rootController;
            if (_speakApps) [ctrl setSelectedIdents:_speakApps];
            [self pushController:ctrl];
        }
        else if (indexPath.row == 1) 
        {
            SEWhatToRead* ctrl = [[[SEWhatToRead alloc] init] autorelease];
            ctrl.parentController = self;
            ctrl.rootController = self.rootController;
            [self pushController:ctrl];
        }
        else if (indexPath.row == 2)
        {
            SEReadingOptions* ctrl = [[[SEReadingOptions alloc] init] autorelease];
            ctrl.parentController = self;
            ctrl.rootController = self.rootController;
            [self pushController:ctrl];
        }
        else if (indexPath.row == 3) 
        {
            SEActivatorActions* ctrl = [[[SEActivatorActions alloc] init] autorelease];
            ctrl.parentController = self;
            ctrl.rootController = self.rootController;
            [self pushController:ctrl];
        }
        else if (indexPath.row == 4) 
        {
            SELangPrefs* ctrl = [[[SELangPrefs alloc] initWithParent:self] autorelease];
            ctrl.parentController = self;
            ctrl.rootController = self.rootController;
            NSArray* langPrefs = [_settings objectForKey:@"langPrefs"];
            if (langPrefs) [ctrl setLanguageArray:langPrefs];
            [self pushController:ctrl];
        }
        else if (indexPath.row == 5) 
        {
            SECustomizedAnnouncements* ctrl = [[[SECustomizedAnnouncements alloc] init] autorelease];
            ctrl.parentController = self;
            ctrl.rootController = self.rootController;
            [self pushController:ctrl];
        }
    }
    else if (indexPath.section == 3) // follow
    {
        if (indexPath.row == 0)
            [self follow];
        else if (indexPath.row == 1)
        {
            NSString* strUrl = @"http://se.k3a.me/";
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:strUrl]];
        }
        else if (indexPath.row == 2)
        {
            [self sendDiagnosticLogs];
        }
        else if (indexPath.row == 3)
        {
            NSString* followUrl = @"cydia://package/org.thebigboss.notificator";
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:followUrl]];
        }
    }
    else if (indexPath.section == 4) // legal
    {
        [self pushController: [[[K3ASEPrefsLegalController alloc] init] autorelease] ];
    }
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    [self dismissModalViewControllerAnimated:YES];
}

@end




@implementation SEWhatToRead

- (id) specifiers 
{
    if (!_specifiers)
    {
        _specifiers = [[self loadSpecifiersFromPlistName:@"WhatToRead" target: self] retain];
    }
    
    return _specifiers;
}

@end



@implementation SEReadingOptions

- (id) specifiers 
{
    if (!_specifiers)
    {
        _specifiers = [[self loadSpecifiersFromPlistName:@"ReadingOptions" target: self] retain];
    }
    
    return _specifiers;
}

@end


@implementation SEActivatorActions

- (id) specifiers 
{
    if (!_specifiers)
    {
        _specifiers = [[self loadSpecifiersFromPlistName:@"ActivatorActions" target: self] retain];
    }
    
    return _specifiers;
}

@end


@implementation SECustomizedAnnouncements

- (id) specifiers 
{
    if (!_specifiers)
    {
        _specifiers = [[self loadSpecifiersFromPlistName:@"CustomizedAnnouncements" target: self] retain];
    }
    
    return _specifiers;
}

static NSString* MainLangPart(NSString* lang)
{
    NSArray* l = [lang componentsSeparatedByString:@"-"];
    if ([l count] == 1) l = [lang componentsSeparatedByString:@"_"];
    return [l objectAtIndex:0];
}

-(NSString*)localizedString:(NSString*)str forLang:(NSString*)lang fromDict:(NSDictionary*)langDict
{
    NSDictionary* dict = [langDict objectForKey:lang];
    if (!dict) dict = [langDict objectForKey:MainLangPart(lang)];
    if (!dict) dict = [langDict objectForKey:@"en-US"];
    if (!dict) dict = [langDict objectForKey:@"en"];
    
    NSString* localized = [dict objectForKey:str];
    if (localized)
        return localized;
    else 
        return str;
}

-(NSString*)caGet:(PSSpecifier*)spec
{
    NSMutableDictionary* settings = [NSMutableDictionary dictionaryWithContentsOfFile:@PREF_FILE];
    if (!settings) settings = [NSMutableDictionary dictionary];
    
    NSString* transl = [settings objectForKey:[spec identifier]];
    if (!transl)
    {
        NSString* voice = [settings objectForKey:@"voice"];
        NSString* lang = nil;
        
        if (!voice || [voice isEqualToString:@"system"])
            lang = GetSystemLanguage();
        else
            lang = voice;
        
        NSMutableDictionary* langDict = [NSMutableDictionary dictionaryWithContentsOfFile:@"/Library/Application Support/SpeakEvents/LanguageStrings.plist"];
        if (langDict)
            transl = [self localizedString:[spec identifier] forLang:lang fromDict:langDict];
        else
        {
            NSLog(@"SE: Prefs: Unable to load lang dict!");
            transl = @"";
        }
    }
    
    return transl;
}

-(void)caSet:(NSString*)val specifier:(PSSpecifier*)spec
{
    NSLog(@"SE: Prefs: Customized announcement %@ -> %@", [spec identifier], val);
    
    NSMutableDictionary* settings = [NSMutableDictionary dictionaryWithContentsOfFile:@PREF_FILE];
    if (!settings) settings = [NSMutableDictionary dictionary];
    
    [settings setObject:val forKey:[spec identifier]];
    
    [settings writeToFile:@PREF_FILE atomically:YES];
    
    // inform the tweak
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("me.k3a.SpeakEvents/reloadPrefs"), NULL, NULL, false);
}

@end



























































// vim:ft=objc
