//
//  Created by K3A on 5/20/12.
//  Copyright (c) 2012 K3A. 
//  Released under GNU GPL v2
//

// SpeakEvents Source Code

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>
#import <SpringBoard/SBTelephonyManager.h>
#import <SpringBoard/SBMediaController.h>
#import <SpringBoard/SBAwayController.h>
#import <AVFoundation/AVFoundation.h>
#import <Celestial/AVSystemController.h>
#import <SpringBoard/VolumeControl.h>
//#include <sys/statvfs.h> // VFS stat
#include <cld/cld.h>

#import <locale.h>
#import <objc/runtime.h>
#import "substrate.h"

#import "main.h"
#import "log.h"
#include "AntiGDB.h"
#import "KStringAdditions.h"
#import "K3AStringFormatter.h"
#import "PrivateAPIs.h"
#import "SEActivatorSupport.h"
#import <LibDisplay.h>

#include <sys/sysctl.h>
#include <notify.h>

static NSRecursiveLock* s_abLock = nil;
static BOOL s_isDND = NO;

// 0 - normal, 1 - more info, 2 - debug
static void SELog(int level, NSString *format, ...)
{
#ifndef DEBUG
    if (level>1) return; // UNCOMMENT ON OFFICIAL RELEASE
#endif

    if (format == nil) {
        printf("nil\n");
        return;
    }
    // Get a reference to the arguments that follow the format parameter
    va_list argList;
    va_start(argList, format);
    // Perform format string argument substitution, reinstate %% escapes, then print
    NSString *s = [[NSString alloc] initWithFormat:format arguments:argList];
    NSLog(@"SE: %@", s);
    [s release];
    va_end(argList);
}

@implementation SESpeakableMessage
@synthesize messageIdentifier,firstPart,secondPart,thirdPart,numPartsRead;
-(id)initWithApp:(SESpeakableApp*)app
{
    if ((self = [super init]))
    {
        _app = [app retain];
    }
    return self;
}
-(void)dealloc
{
    [_app release];
    [super dealloc];
}
-(SESpeakableApp*)app
{
    return _app;
}
@end

@implementation SESpeakableApp
+(id)speakableAppWithIdentifier:(NSString*)ident
{
    return [[SESpeakableApp alloc] initWithIdentifier:ident];
}
-(id)initWithIdentifier:(NSString*)ident
{
    if ( (self = [super init]) )
    {
        _msgs = [[NSMutableArray alloc] init];
        _appIdent = [ident copy];
    }
    return self;
}
-(void)dealloc
{
    [_msgs release];
    [_appIdent release];
    [super dealloc];
}
-(NSString*)appIdentifier
{
    return _appIdent;
}
-(void)pushMessage:(SESpeakableMessage*)msg
{
    @synchronized(_msgs)
    {
        [_msgs addObject:msg];
    }
}
-(SESpeakableMessage*)popMessage // returns nil if no more messages
{
    @synchronized(_msgs)
    {
        if ([_msgs count] == 0) return nil;
        SESpeakableMessage* obj = [[_msgs objectAtIndex:0] retain];
        [_msgs removeObjectAtIndex:0];
        return [obj autorelease];
    }
}
-(SESpeakableMessage*)findMessage:(NSString*)messageIdentifier // may return nil
{
    if (!messageIdentifier) return nil;
    
    @synchronized(_msgs)
    {
        for (SESpeakableMessage* msg in _msgs)
        {
            if ([msg.messageIdentifier isEqualToString:messageIdentifier])
            {
                return msg;
            }
        }
    }
    return nil;
}
-(void)removeAllMessages
{
    [_msgs removeAllObjects];
}
-(unsigned)numOfRemainingMessages
{
    return [_msgs count];
}
@end


static NSString* getAppIdentifier()
{
    NSString* appIdent = nil;
    if (!appIdent)
    {
        NSString *returnString = nil;
        int mib[4], maxarg = 0, numArgs = 0;
        size_t size = 0;
        char *args = NULL, *namePtr = NULL, *stringPtr = NULL;
        
        mib[0] = CTL_KERN;
        mib[1] = KERN_ARGMAX;
        
        size = sizeof(maxarg);
        if ( sysctl(mib, 2, &maxarg, &size, NULL, 0) == -1 ) {
            return @"Unknown";
        }
        
        args = (char *)malloc( maxarg );
        if ( args == NULL ) {
            return @"Unknown";
        }
        
        mib[0] = CTL_KERN;
        mib[1] = KERN_PROCARGS2;
        mib[2] = getpid();
        
        size = (size_t)maxarg;
        if ( sysctl(mib, 3, args, &size, NULL, 0) == -1 ) {
            free( args );
            return @"Unknown";
        }
        
        memcpy( &numArgs, args, sizeof(numArgs) );
        stringPtr = args + sizeof(numArgs);
        
        if ( (namePtr = strrchr(stringPtr, '/')) != NULL ) {
            namePtr++;
            returnString = [[NSString alloc] initWithUTF8String:namePtr];
        } else {
            returnString = [[NSString alloc] initWithUTF8String:stringPtr];
        }
        
        return [returnString autorelease];
    } 
    
    if (!appIdent) appIdent = [[NSBundle mainBundle] bundleIdentifier];
    
    return appIdent;
}

HOOK(SBApplication, _fireNotification$, void, UILocalNotification* notif)
{
    /*
     SE: Local notification: <UIConcreteLocalNotification: 0xf293190>{fire date = středa, 25. dubna 2012 15:53:27 Středoevropský letní čas, time zone = Europe/Prague (CEST) offset 7200 (Daylight), repeat interval = 0, repeat count = UILocalNotificationInfiniteRepeatCount, next fire date = (null)} alertBody: Local Push Notification Test soundName: UILocalNotificationDefaultSoundName isSystem: N
     */
    
    /*
    SELog(0, @"Local notification: %@ alertBody: %@ soundName: %@ isSystem: %s", notif, notif.alertBody, notif.soundName, notif.isSystemAlert?"Y":"N");*/ 
    
    if (notif.isSystemAlert) // alarm
    {
        [[SESpeakEventsServer sharedInstance] handleSystemNotification:notif];
    }/*
    else // send as a push
    {
        BBBulletin* bul = [[[BBBulletin alloc] init] autorelease];
        bul.section = notif.
        [[SESpeakEventsServer sharedInstance] observer:nil addBulletin:bul forFeed:0];
    }*/
    
    ORIG(notif);
}
END

// Notificator support
HOOK(SBBulletinBannerController, observer$addBulletin$forFeed$, void, BBObserver* observer, BBBulletin* bulletin, unsigned feed)
{
    ORIG(observer, bulletin, feed);
    
    //SELog(0, @"SBBulletinBannerController %@", bulletin);
    if (bulletin && [bulletin.bulletinID isEqualToString:@"NotificatorBulletin"])
    {
        SELog(0, @"Adding Notificator bulletin.");
        [[SESpeakEventsServer sharedInstance] observer:observer addBulletin:bulletin forFeed:feed];
    }
    else if (bulletin && [bulletin.bulletinID isEqualToString:@"NowListeningBulletin"])
    {
        SELog(0, @"Adding NowListening bulletin.");
        [[SESpeakEventsServer sharedInstance] observer:observer addBulletin:bulletin forFeed:feed];
    }
    else if (bulletin && [bulletin.publisherBulletinID isEqualToString:@"AMCbanner"])
    {
        SELog(0, @"Adding AMC bulletin.");
        [bulletin setSection:@"com.apple.mobileipod"];
        [[SESpeakEventsServer sharedInstance] observer:observer addBulletin:bulletin forFeed:feed];
    }
}
END

HOOK(BBServer, publishBulletin$destinations$, void, BBBulletin* bullReq, int dests)
{
    //SELog(3, @"publishBulletin: %@ dests %d", bullReq, dests);
    [[SESpeakEventsServer sharedInstance] observer:nil addBulletin:bullReq forFeed:dests];
    
    return ORIG(bullReq, dests);
}
END

//ios6
HOOK(BBServer, publishBulletin$destinations$alwaysToLockScreen$, void, BBBulletin* bullReq, int dests, BOOL toLock)
{
	[[SESpeakEventsServer sharedInstance] observer:nil addBulletin:bullReq forFeed:dests];
	return ORIG(bullReq, dests, toLock);
}
END

HOOK(SBApplication, launchSucceeded$, void, BOOL success)
{
    NSString* ident = [self displayIdentifier];
    SELog(3, @"launch succeeded %@", ident);
    
    [[SESpeakEventsServer sharedInstance] handleLaunchSucceeded:ident];
    
    return ORIG(success);
}
END
//ios6
HOOK(SBApplication, didBeginLaunch$, void, id app)
{
	NSString* ident = [self displayIdentifier];
	SELog(3, @"launch succeeded %@", ident);
	[[SESpeakEventsServer sharedInstance] handleLaunchSucceeded:ident];
	return ORIG(app);
}
END

/*HOOK(TLToneManager, currentNewMailToneSoundID, int)
{
    SELog(0, @"currentNewMailToneSoundID");
    if ([[SESpeakEventsServer sharedInstance] shouldSuppressNewMailSound])
        return 0;
    else
        return ORIG();
}
END

HOOK(TLToneManager, currentTextToneSoundID, int)
{
    SELog(0, @"currentTextToneSoundID");
    if ([[SESpeakEventsServer sharedInstance] shouldSuppressNewMessageSound])
        return 0;
    else
        return ORIG();
}
END*/

// support code
/*HOOK(MFMailBulletin, bulletinRequest, BBBulletin*)
{
    BBBulletin* b = ORIG();
    
    NSDictionary* origContext = [b context]; 
    NSMutableDictionary* context = nil;
    
    if (origContext)
        context = [NSMutableDictionary dictionaryWithDictionary:origContext];
    else
        context = [NSMutableDictionary dictionary];
    
    if ([self respondsToSelector:@selector(mailAccountId)])
        [context setObject:[self mailAccountId] forKey:@"SEAccountID"];
    
    [b setContext:context];
    
    return b;
}
END*/

/*static BOOL InMessages()
{
    static DSDisplayController* dctrl = nil;
    if (!dctrl) dctrl = [DSDisplayController sharedInstance];
    
    SBApplication *actApp = [dctrl activeApp];
    if (!actApp) return FALSE;
    
    NSString *actAppIdent = [actApp displayIdentifier];
    //SELog(0, @"I am in the %@", actAppIdent);
    BOOL inMessages = [actAppIdent isEqualToString:@"com.apple.MobileSMS"];
    if (inMessages) return TRUE;
    
    BOOL inBiteSMS = [actAppIdent isEqualToString:@"com.bitesms"];
    if (inBiteSMS) return TRUE;
    
    BOOL inReadSMS2 = [actAppIdent isEqualToString:@"com.spiritoflogic.iRealSMS2"];
    if (inReadSMS2) return TRUE;
    
    BOOL inReadSMS3 = [actAppIdent isEqualToString:@"com.spiritoflogic.iRealSMS3"];
    if (inReadSMS3) return TRUE;
    
    BOOL inReadSMS4 = [actAppIdent isEqualToString:@"com.spiritoflogic.iRealSMS4"];
    if (inReadSMS4) return TRUE;
    
    return FALSE;
}*/

static BOOL IsInNotAllowedApp()
{
	@try {

    //static DSDisplayController* dctrl = nil;
    //if (!dctrl) dctrl = [DSDisplayController sharedInstance];
    
    SBApplication *actApp = [LibDisplay sharedInstance].topApplication;
    if (!actApp) {/* SELog(0, @"Failed to get foremost app!");*/ return FALSE;}
    
    NSString *actAppIdent = [actApp bundleIdentifier];
	if (!actAppIdent) return FALSE;

    SELog(3, @"I am in '%@'", actAppIdent);
    BOOL inSkype = [actAppIdent isEqualToString: @"com.skype.skype"];
    if (inSkype) return TRUE;
    
	}@catch(NSException* ex) {
		SELog(0, @"LibDisplay Exception: %@", [ex description]);
	}

    return FALSE;
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

    // try to find the exact language code
    NSArray* langArr = [VSSpeechSynthesizer availableLanguageCodes];
    bool found = false;
    bool exact = false;
    for(NSString* l in langArr)
    {
        const char* cl = [l UTF8String];
        if (!strcmp(cl, lang))
        {
            found = true;
            exact = true;
            break;
        }
    }
    // if not exact, try to find prefix
    if (!found)
    {
        for(NSString* l in langArr)
        {
            const char* cl = [l UTF8String];
            if (!strncmp(cl, lang, sepIdx))
            {
                strcpy(lang, cl);
                found = true;
                break;
            }
        }
    }
    if (!found) strcpy(lang, "en-US");
    
    if (!strcmp(lang, "en-GB") && !exact)
        strcpy(lang, "en-US");
    
    return [NSString stringWithUTF8String:lang];
}

static NSString* MainLangPart(NSString* lang)
{
    NSArray* l = [lang componentsSeparatedByString:@"-"];
    if ([l count] == 1) l = [lang componentsSeparatedByString:@"_"];
    return [l objectAtIndex:0];
}

static NSString* getPhoneticNameByName(NSString* firstName, NSString* lastName)
{
	NSMutableString *ContactName = [[[NSMutableString alloc] initWithFormat:@"%@ %@", firstName, lastName] autorelease];
	
    [s_abLock lock];
    ABAddressBookRef addressBook = ABAddressBookCreate();
    if (!addressBook) { [s_abLock unlock]; return ContactName; }
    NSArray *people = (NSArray *) ABAddressBookCopyArrayOfAllPeople(addressBook);
    
    if ( people==nil )
    {
        if (addressBook) CFRelease(addressBook);
        [s_abLock unlock];
        SELog(0, @"Unable to copy array of all people from AB for phonetic name match");
        return nil;
    }
	
    for (unsigned i=0; i<[people count]; i++ )
	{
        ABRecordRef person = (ABRecordRef)[people objectAtIndex:i];
		BOOL shouldQuit = NO;
		
        CFStringRef firstNameValue = (CFStringRef)ABRecordCopyValue(person, kABPersonFirstNameProperty);
        CFStringRef lastNameValue = (CFStringRef)ABRecordCopyValue(person, kABPersonLastNameProperty);
        CFStringRef firstNamePhoneticValue = nil;
        CFStringRef lastNamePhoneticValue = nil;
        CFStringRef nickValue = nil;
		
        if ( [(NSString*)firstNameValue isEqualToString:firstName] && [(NSString*)lastNameValue isEqualToString:lastName] )
        {
            firstNamePhoneticValue = (CFStringRef)ABRecordCopyValue(person, kABPersonFirstNamePhoneticProperty);
            lastNamePhoneticValue = (CFStringRef)ABRecordCopyValue(person, kABPersonLastNamePhoneticProperty);
            
            if (firstNamePhoneticValue == nil && lastNamePhoneticValue != nil)
            {
                [ContactName setString:(NSString*)lastNamePhoneticValue];
            }
            else if (firstNamePhoneticValue != nil)
            {
                [ContactName setString:(NSString*)firstNamePhoneticValue];
                if (lastNamePhoneticValue != nil)
                    [ContactName appendFormat:@" %@", (NSString*)lastNamePhoneticValue];
            }
            else if (firstNamePhoneticValue == nil && lastNamePhoneticValue == nil)
            {
                if (firstNameValue == nil && lastNameValue == nil)
                {
                    nickValue = (CFStringRef)ABRecordCopyValue(person, kABPersonNicknameProperty);
                    if (nickValue != nil) [ContactName setString:(NSString*)nickValue];
                }
                else if (firstNameValue == nil && lastNameValue != nil)
                    [ContactName setString:(NSString*)lastNameValue];
                else if (firstNameValue != nil)
                {
                    [ContactName setString:(NSString*)firstNameValue];
                    
                    if (lastNameValue != nil)
                        [ContactName appendFormat:@" %@", (NSString*)lastNameValue];
                }
            }
            
            shouldQuit = YES;
        }
        
        if (firstNameValue != nil) CFRelease(firstNameValue);
        if (lastNameValue != nil) CFRelease(lastNameValue);
        if (firstNamePhoneticValue != nil) CFRelease(firstNamePhoneticValue);
        if (lastNamePhoneticValue != nil) CFRelease(lastNamePhoneticValue);
        if (nickValue != nil) CFRelease(nickValue);
		
		if (shouldQuit)
			break;
	}
    
    if (addressBook) CFRelease(addressBook);
	[s_abLock unlock];
	
	[people release];
	
	return ContactName;
}

static NSString* Number2Digits(NSString* number)
{
    const char* inp = [number UTF8String];
    unsigned len = strlen(inp);
    
    char* buf = (char*)malloc(len*3);
    
    for(unsigned i=0; i<len; i++)
    {
        buf[2*i] = inp[i];
        buf[2*i+1] = ' ';
    }
    buf[len*2] = 0;
    
    NSString* outStr = [NSString stringWithUTF8String:buf];
    free(buf);
    
    return outStr;
}

static unsigned NumSameDigits(NSString* first, NSString* second)
{
    if (first == nil || second == nil) return 0;

    char c;
    const char* ac = [first UTF8String];
    const char* bc = [second UTF8String];
    
    unsigned al = strlen(ac);
    char* bufa = (char*)malloc(al+2);
    bufa[0]=0;
    char* ptra = bufa+1;
    while( (c = *(ac++)) ) 
    {
        if (isdigit(c))
            *(ptra++) = c;
    }
    *ptra = 0;
    ptra--;
    
    unsigned bl = strlen(bc);
    char* bufb = (char*)malloc(bl+2);
    bufb[0]=0;
    char* ptrb = bufb+1;
    while( (c = *(bc++)) ) 
    {
        if (isdigit(c)) 
            *(ptrb++) = c;
    }
    *ptrb = 0;
    ptrb--;
    
    //SELog(0, @"Comparing %s %s", bufa+1, bufb+1);
    
    unsigned numMatched = 0;
    while( *ptra && *ptrb && *ptra == *ptrb )
    {
        numMatched++;
        ptra--;
        ptrb--;
    }
    
    free(bufa);
    free(bufb);
    
    return numMatched;
}

static NSString* getPhoneticNameByNumber(NSString* number)
{
    if (!number || ![number length]) return @"Unknown";
    
    unsigned int inputLen = [number length];
	NSMutableString *ContactName = [[Number2Digits(number) mutableCopy] autorelease];
    unsigned longestNumberMatch = 0;
	
    [s_abLock lock];
    ABAddressBookRef addressBook = ABAddressBookCreate();
    if (!addressBook) { [s_abLock unlock]; return @"Unknown";}
    NSArray *people = (NSArray *) ABAddressBookCopyArrayOfAllPeople(addressBook);
    
    if ( people==nil )
    {
        if (addressBook) CFRelease(addressBook);
        [s_abLock unlock];
        SELog(0, @"Unable copy people from addressbook!");
        return nil;
    }
    
    //SELog(3, @"Num people: %d", [people count]);
	
    for (unsigned i=0; i<[people count]; i++ )
	{
        ABRecordRef person = (ABRecordRef)[people objectAtIndex:i];
        
        ABMutableMultiValueRef phoneNumbers = ABRecordCopyValue(person, kABPersonPhoneProperty);
        if (phoneNumbers == nil) continue;
        CFIndex phoneNumberCount = ABMultiValueGetCount( phoneNumbers );
        
        BOOL foundNumberInThisPerson = NO;
        for ( int k=0; k<phoneNumberCount; k++ )
        {
            NSString* phoneNumberValueInput = (NSString*)ABMultiValueCopyValueAtIndex( phoneNumbers, k );
            if (phoneNumberValueInput == nil) continue; // could not get phone value
            
            NSString* phoneNumberValue = [NSString stringWithString:phoneNumberValueInput];
            CFRelease(phoneNumberValueInput);
            
            unsigned strLen = [phoneNumberValue length];
            
            if (strLen < longestNumberMatch) 
                continue; // not interesting, too short
            
            // check length
            unsigned numberMatch = NumSameDigits(phoneNumberValue, number);
            if (numberMatch == 0) continue; // no one digit matched
            else if (numberMatch < inputLen/2) continue; // too low number of digits matched
            
            longestNumberMatch = numberMatch;
            
            foundNumberInThisPerson = YES;
            break;
        }
        
        CFStringRef firstNameValue = nil;
        CFStringRef lastNameValue = nil;
        CFStringRef firstNamePhoneticValue = nil;
        CFStringRef lastNamePhoneticValue = nil;
        CFStringRef nickValue = nil;
        
        if (foundNumberInThisPerson)
        {
            firstNamePhoneticValue = (CFStringRef)ABRecordCopyValue(person, kABPersonFirstNamePhoneticProperty);
            lastNamePhoneticValue = (CFStringRef)ABRecordCopyValue(person, kABPersonLastNamePhoneticProperty);
            
            if (firstNamePhoneticValue == nil && lastNamePhoneticValue != nil)
            {
                [ContactName setString:(NSString*)lastNamePhoneticValue];
            }
            else if (firstNamePhoneticValue != nil)
            {
                [ContactName setString:(NSString*)firstNamePhoneticValue];
                if (lastNamePhoneticValue != nil)
                    [ContactName appendFormat:@" %@", (NSString*)lastNamePhoneticValue];
            }
            else if (firstNamePhoneticValue == nil && lastNamePhoneticValue == nil)
            {
                firstNameValue = (CFStringRef)ABRecordCopyValue(person, kABPersonFirstNameProperty);
                lastNameValue = (CFStringRef)ABRecordCopyValue(person, kABPersonLastNameProperty);
                
                if (firstNameValue == nil && lastNameValue == nil)
                {
                    nickValue = (CFStringRef)ABRecordCopyValue(person, kABPersonNicknameProperty);
                    if (nickValue != nil) [ContactName setString:(NSString*)nickValue];
                }
                else if (firstNameValue == nil && lastNameValue != nil)
                    [ContactName setString:(NSString*)lastNameValue];
                else if (firstNameValue != nil)
                {
                    [ContactName setString:(NSString*)firstNameValue];
                    
                    if (lastNameValue != nil)
                        [ContactName appendFormat:@" %@", (NSString*)lastNameValue];
                }
            }
        }
        
        if (firstNameValue != nil) CFRelease(firstNameValue);
        if (lastNameValue != nil) CFRelease(lastNameValue);
        if (firstNamePhoneticValue != nil) CFRelease(firstNamePhoneticValue);
        if (lastNamePhoneticValue != nil) CFRelease(lastNamePhoneticValue);
        if (nickValue != nil) CFRelease(nickValue);
	}
	
    if (addressBook) CFRelease(addressBook);
    [s_abLock unlock];
    
	[people release];
	
	return ContactName;
}

#pragma mark - SPRINGBOARD PART

HOOK(SBUIController, updateBatteryState$, void, id p1)
{
    //SELog(2, @">> SBUIController::updateBatteryState <%s>", object_getClassName(p1));
    
    [[SESpeakEventsServer sharedInstance] batteryStateChanged:p1];
    
    CALL_ORIG(p1);
}
END

@implementation SESpeakEventsServer

static SESpeakEventsServer* s_ses_instance = nil;

extern id AVController_PickedRouteAttribute;

-(void)handleLaunchSucceeded:(NSString*)ident
{
    NSString* speakIdent = nil;
    if (ident && m_currentlySpeakingObject)
        speakIdent = [[m_currentlySpeakingObject app] appIdentifier];
    
    if (speakIdent && [ident isEqualToString:speakIdent])
        [self stopSpeaking];
}

-(BOOL)shouldSuppressNewMailSound
{
    NSNumber* suppressSound = [m_settings objectForKey:@"suppressSound"];
    return suppressSound && [suppressSound boolValue];
}
-(BOOL)shouldSuppressNewMessageSound
{
    NSNumber* suppressSound = [m_settings objectForKey:@"suppressSound"];
    return suppressSound && [suppressSound boolValue];
}

-(void)startBluetooth
{
    if (m_voiceCtrl) return; // already present
    
    SELog(3, @"Starting bluetooth");

    [synth setMaintainPersistentConnection:YES];
    
    // will create music interruption 
    NSError* err = nil;
    m_voiceCtrl = [AVVoiceController alloc];
	
	if ([m_voiceCtrl respondsToSelector:@selector(initWithHardwareConfig:error:)])
		m_voiceCtrl = [m_voiceCtrl initWithHardwareConfig:2 error:&err];
	else
		m_voiceCtrl = [m_voiceCtrl initWithContext:[NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt:1752132965] forKey:@"activation trigger"] error:&err];

    if (err) SELog(0, @"Audio system problem: %@", [err description]);
    
    // like we needed bluetooth input
    int allowBluetoothInput = 1;
    AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryEnableBluetoothInput, sizeof (allowBluetoothInput), &allowBluetoothInput);
    
    // for sure "select route"
    AVSystemController* sysCtrl = nil;
    if (!sysCtrl) sysCtrl = [AVSystemController sharedAVSystemController];
    
    NSArray* routes = [sysCtrl pickableRoutesForCategory:@"PlayAndRecord_WithBluetooth"];
    for (NSDictionary* route in routes)
    {
        if (![[route objectForKey:@"RouteType"] isEqualToString:@"Override"] && ![[route objectForKey:@"RouteType"] isEqualToString:@"Default"])
        {
            NSError* err = nil;
            [sysCtrl setAttribute:route forKey:AVController_PickedRouteAttribute error:&err];
            SELog(0, @"Selected external audio route");
            break;
        }
    }
    
    // probably not needed, but...
	if ([m_voiceCtrl respondsToSelector:@selector(setHardwareConfiguration:)]) [m_voiceCtrl setHardwareConfiguration:2];
    AudioSessionSetActive(1);
    
    m_bluetoothWasUsed = YES;

}

-(void)stopBluetooth
{
    /*AudioSessionSetActive(0);
    int allowBluetoothInput = 10;
    AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryEnableBluetoothInput, sizeof (allowBluetoothInput), &allowBluetoothInput);*/

    if (!m_voiceCtrl) return; // already stopped
    
    SELog(3, @"Stopping bluetooth");
    
    [synth setMaintainPersistentConnection:NO];
    
    if (m_voiceCtrl)
    {
        // resume from interruption
        [m_voiceCtrl releaseAudioSession];
        [m_voiceCtrl release];
        m_voiceCtrl = nil;
        
        // disable bluetooth just in case...
        int allowBluetoothInput = 0;
        AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryEnableBluetoothInput, sizeof (allowBluetoothInput), &allowBluetoothInput);
    }
    
    m_bluetoothWasUsed = NO;
}

-(NSString*)detectLanguageUsingCLD:(NSString*)str
{
    bool is_plain_text = true;
    bool do_allow_extended_languages = true;
    bool do_pick_summary_language = false;
    bool do_remove_weak_matches = false;
    bool is_reliable;
    const char* tld_hint = NULL;
    int encoding_hint = UNKNOWN_ENCODING;
    Language language_hint = UNKNOWN_LANGUAGE;
    
    double normalized_score3[3];
    Language language3[3];
    int percent3[3];
    int text_bytes;
    
    const char* src = [str UTF8String];
    if (!src) return @"en-US";
    Language lang;
    lang = CompactLangDet::DetectLanguage(0,
                                          src, strlen(src),
                                          is_plain_text,
                                          do_allow_extended_languages,
                                          do_pick_summary_language,
                                          do_remove_weak_matches,
                                          tld_hint,
                                          encoding_hint,
                                          language_hint,
                                          language3,
                                          percent3,
                                          normalized_score3,
                                          &text_bytes,
                                          &is_reliable);
    //printf("LANG=%s\n", LanguageName(lang));
    char lcodec[32];
    strcpy(lcodec, LanguageCodeWithDialects(lang));
    
    SELog(0, @"Langs scores: %s (%.2f), %s (%.2f), %s (%.2f)", LanguageCodeWithDialects(language3[0]), normalized_score3[0], LanguageCodeWithDialects(language3[1]), normalized_score3[1], LanguageCodeWithDialects(language3[2]), normalized_score3[2] );
    
    // is language preference set?
    NSArray* langPrefs = [m_settings objectForKey:@"langPrefs"];
    if (langPrefs)
    {
        const char* clp0 = LanguageCodeWithDialects(language3[0]);
        const char* clp1 = LanguageCodeWithDialects(language3[1]);
        const char* clp2 = LanguageCodeWithDialects(language3[2]);
        
        for (NSString* lp in langPrefs)
        {
            const char* clp = [lp UTF8String];
            if (!strncmp(clp, clp0, 2) || !strncmp(clp, clp1, 2) || !strncmp(clp, clp2, 2))
            {
                strcpy(lcodec, clp);
                SELog(1, @"Prefering lang %s", clp);
                break;
            }
        }
    }
    
    // if default lang set and one of these langs is detected, use the default voice
    if ( m_defaultLang && (!strncmp(lcodec, "en", 2) || !strncmp(lcodec, "pt", 2) || !strncmp(lcodec, "es", 2)) ) 
    {
        // prefer selected default voice if first two chars with detected and default matches
        const char* defaultLang = [m_defaultLang UTF8String];
        if (strlen(defaultLang)>2 && !strncmp(defaultLang, lcodec, 2)) 
        {
            strcpy(lcodec, defaultLang);
        }
    }
    
    if (!strncmp(lcodec, "uk", 2)) return @"ru-RU";
    if (!strncmp(lcodec, "nb", 2)) return @"no-NO";
    
    NSArray* availableLanguageCodes = [VSSpeechSynthesizer availableLanguageCodes];
    char bestLang[8]; bestLang[0]=0;
    for (NSString* l in availableLanguageCodes)
    {
        const char* curLang = [l UTF8String];
        if (!strcasecmp(curLang, lcodec))
            return l; // exact match
        else if (!strncasecmp(curLang, lcodec, 2))
            strcpy(bestLang, curLang);
    }
    
    if (bestLang[0])
        return [NSString stringWithUTF8String:bestLang];
    else
        return @"en-US";
}

-(NSString*)detectLanguageUsingGoogle:(NSString*)str
{
    NSString* url = [NSString stringWithFormat:@"http://www.google.com/uds/GlangDetect?v=1.0&q=%@", [str urlEncodedString]];
    NSURLRequest* req = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    NSURLResponse* resp =  nil;
    NSData* data = [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:nil];
    if (!data)
        return @"en-US";
    else
    {
        NSString* parsedText = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
        const char* cstr = [parsedText UTF8String];
        if (!cstr) return @"en-US";
        const char* languagePos = strstr(cstr, "language\":\"");
        if (!languagePos) return @"en-US";
        languagePos += 11;
        
        int llen = 0;
        for(int i=0; i<10; i++)
        {
            if (languagePos[llen] == '\"' || languagePos[llen] == '\0')
                break;
            llen++;
        }
        
        if (llen < 2) return @"en-US";
        
        if (!strncmp(languagePos, "en", 2)) return @"en-US";
        
        char lcodec[8];
        strncpy(lcodec, languagePos, 2);
        lcodec[2]=0;
        
        NSArray* availableLanguageCodes = [VSSpeechSynthesizer availableLanguageCodes];
        for (NSString* l in availableLanguageCodes)
        {
            if (!strncmp([l UTF8String], lcodec, 2))
                return l;
        }
        
        return @"en-US";
    }
}

-(NSString*)detectLanguage:(NSString*)str
{
    NSNumber* detectLang = [m_settings objectForKey:@"detectLang"];
    if (!detectLang || [detectLang boolValue])
    {
        //old return [self detectLanguageUsingGoogle:str];
        NSString* langDet = [self detectLanguageUsingCLD:str];
        SELog(0, @"Lang detected: %@", langDet);
        return langDet;
    }
    else // autodetect disabled
        return m_defaultLang;
}

-(NSString*)smiley:(NSString*)key
{
	NSString* val = [m_smileys objectForKey:key];
	if (!val) return key;
	return val;
}

-(NSMutableString*)postprocessText:(NSString*)input
{
    NSMutableString* output = [input mutableCopy];
    
    NSError* err = nil;
    
    // ----- Remove URLs -------------------------------------
    static NSRegularExpression* regexpURL = nil;
    if (regexpURL == nil) 
    {
        regexpURL = [[NSRegularExpression alloc] initWithPattern:@"https?://([-\\w\\.]+)+(:\\d+)?(/([\\w/_\\.]*(\\?\\S+)?)?)?" options:NSRegularExpressionCaseInsensitive|NSRegularExpressionDotMatchesLineSeparators error:&err];
        if (err) SELog(0, @"regexpURL error %@", [err description]);
    }
    [regexpURL replaceMatchesInString:output options:0 range:NSMakeRange(0, [output length]) withTemplate:@""];
    
    // ----- Remove unwanted sequences -----------------------
    static NSRegularExpression* doubleSeq = nil;
    if (!doubleSeq)
    {
        doubleSeq = [[NSRegularExpression alloc] initWithPattern:@"==|--|##|$$|\\*\\*|^^|@@" options:NSRegularExpressionCaseInsensitive error:&err];
        if (err) SELog(0, @"doubleSeq error %@", [err description]);
    }
    [doubleSeq replaceMatchesInString:output options:0 range:NSMakeRange(0, [output length]) withTemplate:@""];
    
    // ----- SMILEYS -----------------------
    NSNumber* readEmoticons = [m_settings objectForKey:@"readEmoticons"];
    if (!readEmoticons || [readEmoticons boolValue])
    {
        static NSRegularExpression* rHappy = nil;
        if (rHappy == nil) 
        {
            err = nil;
            rHappy = [[NSRegularExpression alloc] initWithPattern:@"[:=]-?\\)" options:NSRegularExpressionCaseInsensitive error:&err];
            if (err) SELog(0, @"rHappy error %@", [err description]);
        }
        [rHappy replaceMatchesInString:output options:0 range:NSMakeRange(0, [output length]) withTemplate:[self smiley:@"(happy face)"]];
        
        static NSRegularExpression* rSad = nil;
        if (rSad == nil) 
        {
            err = nil;
            rSad = [[NSRegularExpression alloc] initWithPattern:@"[:=]-?\\(" options:NSRegularExpressionCaseInsensitive error:&err];
            if (err) SELog(0, @"rSad error %@", [err description]);
        }
        [rSad replaceMatchesInString:output options:0 range:NSMakeRange(0, [output length]) withTemplate:[self smiley:@"(sad face)"]];
        
        static NSRegularExpression* rSilly = nil;
        if (rSilly == nil) 
        {
            err = nil;
            rSilly = [[NSRegularExpression alloc] initWithPattern:@"[:=]-?P" options:NSRegularExpressionCaseInsensitive error:&err];
            if (err) SELog(0, @"rSilly error %@", [err description]);
        }
        [rSilly replaceMatchesInString:output options:0 range:NSMakeRange(0, [output length]) withTemplate:[self smiley:@"(silly face)"]];
        
        static NSRegularExpression* rAngry = nil;
        if (rAngry == nil) 
        {
            err = nil;
            rAngry = [[NSRegularExpression alloc] initWithPattern:@">-?\\(" options:NSRegularExpressionCaseInsensitive error:&err];
            if (err) SELog(0, @"rAngry error %@", [err description]);
        }
        [rAngry replaceMatchesInString:output options:0 range:NSMakeRange(0, [output length]) withTemplate:[self smiley:@"(angry face)"]];
        
        static NSRegularExpression* rWinky = nil;
        if (rWinky == nil) 
        {
            err = nil;
            rWinky = [[NSRegularExpression alloc] initWithPattern:@";-?\\)" options:NSRegularExpressionCaseInsensitive error:&err];
            if (err) SELog(0, @"rWinky error %@", [err description]);
        }
        [rWinky replaceMatchesInString:output options:0 range:NSMakeRange(0, [output length]) withTemplate:[self smiley:@"(winky face)"]];
        
        static NSRegularExpression* rNotAmused = nil;
        if (rNotAmused == nil) 
        {
            err = nil;
            rNotAmused = [[NSRegularExpression alloc] initWithPattern:@"[:=]-?\\|" options:NSRegularExpressionCaseInsensitive error:&err];
            if (err) SELog(0, @"rNotAmused error %@", [err description]);
        }
        [rNotAmused replaceMatchesInString:output options:0 range:NSMakeRange(0, [output length]) withTemplate:[self smiley:@"(not amused face)"]];
        
        static NSRegularExpression* rSurprised = nil;
        if (rSurprised == nil) 
        {
            err = nil;
            rSurprised = [[NSRegularExpression alloc] initWithPattern:@"[:=]-?O" options:NSRegularExpressionCaseInsensitive error:&err];
            if (err) SELog(0, @"rSurprised error %@", [err description]);
        }
        [rSurprised replaceMatchesInString:output options:0 range:NSMakeRange(0, [output length]) withTemplate:[self smiley:@"(surprised face)"]];
    }
        
    return [output autorelease];
}

-(void)cleanCurrentObject
{
    if (!m_currentlySpeakingObject) return;
    
    SELog(0, @"Cleaning hanging object... Should not happen :P");
    
    [m_currentlySpeakingObject release];
    m_currentlySpeakingObject = nil;
    
    [self stopSpeaking]; // ah...
}

-(void)setupCleaningTimer
{
    [m_cleaningTimer invalidate];
    [m_cleaningTimer release];
    m_cleaningTimer = nil;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        m_cleaningTimer = [[NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(cleanCurrentObject) userInfo:nil repeats:NO] retain];
    });
}

-(void)cleanDuplicateHash
{
    m_duplicateHash = 0;
}

-(BOOL)checkForDuplicate:(unsigned long)hash
{
    [m_repeatTimer invalidate];
    [m_repeatTimer release];
    m_repeatTimer = nil;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        m_repeatTimer = [[NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(cleanDuplicateHash) userInfo:nil repeats:NO] retain];
    });
    
    if (m_duplicateHash && m_duplicateHash == hash)
        return YES;
    else
    {
        m_duplicateHash = hash;
        return NO;
    }
}

-(void)startSpeakingCurrentMessage
{
    [m_delayTimer invalidate];
    [m_delayTimer release];
    m_delayTimer = nil;
    
    if (!m_currentlySpeakingObject) { SELog(3, @"startSpeakingCurrentMessage but no currently speaking object!");  return;}
    
    NSString* msg = nil;
    if (m_currentlySpeakingObject.firstPart)
    {
        msg = m_currentlySpeakingObject.firstPart;
        m_currentlySpeakingObject.numPartsRead = 1;
    }
    else if (m_currentlySpeakingObject.secondPart)
    {
        msg = m_currentlySpeakingObject.secondPart;
        m_currentlySpeakingObject.numPartsRead = 2;
    }
    else if (m_currentlySpeakingObject.thirdPart)
    {
        msg = m_currentlySpeakingObject.thirdPart; 
        m_currentlySpeakingObject.numPartsRead = 3;
    }
    
    if (!msg)
    {
        SELog(0, @"Nothing to speak in the current object!");
        [self cleanCurrentObject];
        return;
    }
    else if (![msg length])
    {
        SELog(0, @"Current object has 0 length!");
        [self cleanCurrentObject];
        return;
    }
        
    [self speakHiPriority:msg];
}

- (void)observer:(BBObserver*)observer addBulletin:(BBBulletin*)bulletin forFeed:(unsigned int)feed
{
    //SELog(2, @"ADD BULLETTIN %s %@ - %@ CONTENT %@ ACTIONS %@ ATTACH %@ MSG %@", object_getClassName(bulletin), [bulletin section], [bulletin title], [bulletin content], [bulletin actions], [bulletin attachments], bulletin.message);

    SELog(0, @"Received bulletin from %@ - %@", [bulletin section], [bulletin recordID]);
    
    if (!m_afterSafeTime)
    {
        if (time(0)-m_initTimestamp < 10)
        {
            SELog(0, @"Ignoring bulletin right after SB load");
            return;
        }
        
        m_afterSafeTime = YES;
    }
    
    unsigned long uberHash = [[bulletin section] hash] + [[bulletin title] hash] +  [[bulletin content] hash];
    if ([self checkForDuplicate:uberHash])
    {
        SELog(0, @"Ignoring bulletin because it seems to be a duplicate in 60 seconds");
        return;
    }
    
    BOOL isNotificator = [bulletin.bulletinID isEqualToString:@"NotificatorBulletin"] || [bulletin.section isEqualToString:@"org.thebigboss.notificatorapp"];
    
    double timeDiff = [bulletin.date timeIntervalSinceNow];
    /*if (timeDiff < -30) 
    {
        SELog(0, @"Not reading old bulletin (%.2f) from %@ with title %@", timeDiff, [bulletin section], [bulletin title]);
        return;
    }
    else*/ if (timeDiff > 4*60)
    {
        SELog(0, @"Not reading future bulletin (%.2f) from %@ with title %@", timeDiff, [bulletin section], [bulletin title]);
        return;
    }
    if ([bulletin lastInterruptDate] == nil && !isNotificator && ![bulletin.bulletinID isEqualToString:@"NowListeningBulletin"] 
        && ![bulletin.publisherBulletinID isEqualToString:@"AMCbanner"] && timeDiff < -30)
    {
        SELog(0, @"Ignoring non-interrupting or old bulletin.");
        return;
    }
        
    NSNumber* suppressSound = [m_settings objectForKey:@"suppressSound"];
    if (suppressSound && [suppressSound boolValue])
    {
        SELog(0, @"Suppressing original sound.");
        [bulletin.sound setRingtoneName:@""];
        [bulletin.sound setSystemSoundID:0];
    }
    
    //SELog(0, @">>> Add bulletin: \n"
    //      "Topic: %@, Title: %@, Subtitle: %@, Section : %@, BulletinID: %@, Buttons: %@, Message: %@", 
    //      bulletin.topic, bulletin.title, bulletin.subtitle, bulletin.section, bulletin.bulletinID, bulletin.buttons, bulletin.message);
    
    if (![self isAllowedToSpeakNow]) { return; } // not allowed to speak
    
    NSNumber* speakNotificatorNum = [m_settings objectForKey:@"speakNotificator"];
    BOOL speakNotificator = !speakNotificatorNum || [speakNotificatorNum boolValue];
    
    if (isNotificator)
    {
        if (!speakNotificator)
        {
            SELog(0, @"Not speaking Notificator event - not enabled");
            return;
        }
    }
    else
    {
        // not enabled app
        if (!bulletin.section || !m_speakApps || ![m_speakApps containsObject:bulletin.section])
        {
            SELog(0, @"Not speaking for app %@ - app not enabled", bulletin.section);
            return;
        }
    }
    
    // no body and subtitle - useless
    //if (bulletin.subtitle == nil && bulletin.message == nil)
     //   return;
    
    gdb_check();
    
    // try to find existing app record
    SESpeakableApp* app = nil;
    for (SESpeakableApp* x in m_speakObjects)
    {
        if ([x.appIdentifier isEqualToString:bulletin.section])
        {
            app = x;
            break;
        }
    }
    if (!app) 
    {
        app = [SESpeakableApp speakableAppWithIdentifier:bulletin.section];
        [m_speakObjects addObject:app];
    }
    
    SESpeakableMessage* sm = m_currentlySpeakingObject;
    BOOL justUpdating = [m_currentlySpeakingObject.messageIdentifier isEqualToString:[bulletin recordID]];
    // new msg record
    if (!justUpdating) 
    {
        sm = [[[SESpeakableMessage alloc] initWithApp:app] autorelease];
        sm.messageIdentifier = [bulletin recordID];
    }
    
    // is mail or message
    NSString* section = bulletin.section;
    BOOL isMail = NO, isMessage = NO, isReminder = NO, isCal = NO, isMusic = NO;
    if ([section isEqualToString:@"com.apple.MobileSMS"])
        isMessage = YES;
    else if ([section isEqualToString:@"com.apple.mobilemail"])
        isMail = YES;
    else if ([section isEqualToString:@"com.apple.reminders"])
        isReminder = YES;
    else if ([section isEqualToString:@"com.apple.mobilecal"])
        isCal = YES;
    else if ([section isEqualToString:@"com.apple.mobileipod"])
        isMusic = YES;

	NSNumber* readSubject = [m_settings objectForKey:@"readSubject"];
	BOOL readSubjectBool = !readSubject || [readSubject boolValue];
    
    if (!justUpdating)
    {
        if (isMessage || isMail) // SMS/iMessage/Mail
        {
            NSArray* senderNames = [bulletin.title componentsSeparatedByString:@" "];
            NSString* senderName = bulletin.title;
            if ([senderNames count] == 2)
                senderName = getPhoneticNameByName([senderNames objectAtIndex:0], [senderNames objectAtIndex:1]);
            
            if (isMessage || (isMail && !bulletin.subtitle) )
            {
                K3AStringFormatter* f = [K3AStringFormatter formatterWithFormat:[self localizedString:@"MESSAGE"]];
                [f addString:senderName];
                sm.firstPart = [f generateString];
            }
            else if (isMail && readSubjectBool)
            {
                K3AStringFormatter* f = [K3AStringFormatter formatterWithFormat:[self localizedString:@"MAIL"]];
                [f addString:senderName];
                [f addString:@""];
                sm.firstPart = [f generateString];
            }
			else if (isMail)
			{
				K3AStringFormatter* f = [K3AStringFormatter formatterWithFormat:[self localizedString:@"MAIL_NO_SUBJ"]];
				[f addString:senderName];
				sm.firstPart = [f generateString];
			}
                
        }
        else if (isReminder) // reminders
        {
            K3AStringFormatter* f = [K3AStringFormatter formatterWithFormat:[self localizedString:@"REMINDER"]];
            [f addString:bulletin.title];
            sm.firstPart = [f generateString];
        }
        else if (isCal)
        {
            K3AStringFormatter* f = [K3AStringFormatter formatterWithFormat:[self localizedString:@"CALENDAR"]];
            [f addString:bulletin.title];
            sm.firstPart = [f generateString];
        }
        else if (isMusic) // music banners
        {
            sm.firstPart = nil;
            sm.secondPart = bulletin.message;
            sm.thirdPart = bulletin.title;
        }
        else // other app/notification
        {
            K3AStringFormatter* f = [K3AStringFormatter formatterWithFormat:[self localizedString:@"NOTIFICATION"]];
            [f addString:bulletin.title];
            sm.firstPart = [f generateString];
        }
    }
    
    NSNumber* readBody = [m_settings objectForKey:@"readBody"];
    BOOL readBodyBool = !readBody || [readBody boolValue];
    
    // set the second part (subject)
    if (readSubjectBool && !isMusic) sm.secondPart = bulletin.subtitle;
    
    // set the third part (body) ------------------
    if (readBodyBool && bulletin.message && !isMusic)
    {
        NSMutableString* body = [self postprocessText:bulletin.message];
        
        NSNumber* shortenBodyNum = [m_settings objectForKey:@"shortenBody"];
        BOOL shortenBody = !shortenBody || [shortenBodyNum boolValue];
        
        // shorten
        if (shortenBody && [body length] > 160) 
            body = [[[body substringToIndex:160] mutableCopy] autorelease];
        
        // include if needed
        sm.thirdPart = body;
    }
    
    //if (justUpdating)
    //    SELog(0, @"Just updating body part to: '%@'", sm.thirdPart);
    
    // remove title if not enabled
    NSNumber* readTitleNum = [m_settings objectForKey:@"readTitle"];
    BOOL readTitle = !readTitleNum || [readTitleNum boolValue];
    if (!readTitle) sm.firstPart = nil;
    
    if (!justUpdating) 
    {
        //SELog(0, @"Reading |%@|%@|%@", sm.firstPart, sm.secondPart, sm.thirdPart);
        
        [m_lastSpokenObject release];
        m_lastSpokenObject = [sm retain];
        
        // if no speaking object, start speaking this one
        if (!m_currentlySpeakingObject) 
        {
            m_currentlySpeakingObject = [sm retain];
            //SELog(0, @"Speaking bulettin %@ (app %@)", bulletin.message, app);
            
            // start speaking now or after the delay
            
            NSNumber* delayBeforeSpeaking = [m_settings objectForKey:@"delayBeforeSpeaking"];
            float delayBeforeSpeakingFloat = [delayBeforeSpeaking floatValue];
            
            if (!delayBeforeSpeaking || delayBeforeSpeakingFloat == 0)
            {
                SELog(3, @"Speaking immediately");
                [self startSpeakingCurrentMessage]; // immediately
            }
            else
            {
                SELog(3, @"Delaying speaking %.2f", delayBeforeSpeakingFloat);
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    m_delayTimer = [[NSTimer scheduledTimerWithTimeInterval:delayBeforeSpeakingFloat target:self selector:@selector(startSpeakingCurrentMessage) userInfo:nil repeats:NO] retain];
                });
            }
        }
        else 
        {
            SELog(3, @"Queuing bulettin %@ for later (app %@)", bulletin.message, app);
            [app pushMessage:sm];
        }
    }
    
}
- (void)observer:(BBObserver*)observer modifyBulletin:(BBBulletin*)bulletin
{
    //SELog(0, @">>> Modify bulletin: %@", bulletin);
}
- (void)observer:(BBObserver*)observer removeBulletin:(BBBulletin*)bulletin
{
    SELog(0, @">>> Remove bulletin: %@", bulletin);
}

- (void)speechSynthesizer:(VSSpeechSynthesizer*)synth didFinishSpeaking:(BOOL)finish withError:(NSError*)err
{
    SELog(3, @"didFinishSpeaking");
    BOOL isAllowed = [self isAllowedToSpeakNow];
    
    //SELog(0, @"SppechSynth didFinishSpeaking:%s error:%@", finish?"yes":"no", err);
    bool hasMore = false;
    if (isAllowed && m_currentlySpeakingObject)
    {
        SESpeakableMessage* msg = m_currentlySpeakingObject;
        NSString* nextUtterance = nil;
        if (msg.numPartsRead == 1) // first one was read
        {
            if (msg.secondPart)
            {
                nextUtterance = msg.secondPart;
                msg.numPartsRead = 2;
                hasMore = true;
            }
            else if (msg.thirdPart)
            {
                nextUtterance = msg.thirdPart;
                msg.numPartsRead = 3;
                hasMore = true;
            }
            else // finished 
                hasMore = false;
                
        }
        else if (msg.numPartsRead == 2) // second one was read
        {
            if (msg.thirdPart)
            {
                nextUtterance = msg.thirdPart;
                msg.numPartsRead = 3;
                hasMore = true;
            }
            else // finished
                hasMore = false;
        }
        else if (msg.numPartsRead == 3) // third (the last) one was read
        {
            // finished
            hasMore = false;
        }
        
        // speak the next part
        if (nextUtterance) 
            [self speakHiPriority:nextUtterance inLang:[self detectLanguage:nextUtterance]];
        
        // current message has finished, take the next one from the queue
        if (!hasMore)
        {
            // remove the currently finished object
            SESpeakableApp* app = [m_currentlySpeakingObject app];
            [m_currentlySpeakingObject release];
            m_currentlySpeakingObject = nil;
            
            // get prefs and next msg of the same app if prefs allows it
            int queueMode = [[m_settings objectForKey:@"queue"] intValue];
            if (queueMode == 0) // read first msg of each app
                [app removeAllMessages];
            else if (queueMode == 1)
                SELog(0, @"Queue mode 1 not implemented yet!!"); //TODO
            else
            {
                //SELog(0, @"Looking for the next message of the same app");
                m_currentlySpeakingObject = [[app popMessage] retain];
            }
            
            // if no message from the current app... 
            if (!m_currentlySpeakingObject)
            {
                //SELog(0, @"Looking for the next app");
                // ...find the first app which has some messages
                for (SESpeakableApp* x in m_speakObjects)
                {
                    m_currentlySpeakingObject = [[x popMessage] retain];
                    if (m_currentlySpeakingObject) break;
                }
            }
            
            // start speaking next object (if any)
            if (m_currentlySpeakingObject)
            {
                m_currentlySpeakingObject.numPartsRead = 1;
                [self speakHiPriority:m_currentlySpeakingObject.firstPart inLang:[self detectLanguage:m_currentlySpeakingObject.firstPart]];
                hasMore = true;
            }
        }
    }
    else if (!isAllowed && m_currentlySpeakingObject) // not allowed to speak now, destroy current object
    {
        [m_currentlySpeakingObject release];
        m_currentlySpeakingObject = nil;
    }
    
    // tear down bluetooth
    if (!hasMore && m_bluetoothWasUsed)
    {
        [self stopBluetooth]; // ...will also set m_bluetoothWasUsed to NO
    }
}
- (void)speechSynthesizerDidStartSpeaking:(VSSpeechSynthesizer*)synth
{
    //SELog(0, @"SppechSynth speechSynthesizerDidStartSpeaking");
}

-(void)speakLastChargeDate
{
    if (!m_lastFullChargeDate) return;
    
    NSDate *now = [NSDate date];
    int delta = (int)[now timeIntervalSinceDate:m_lastFullChargeDate];
    
    int days = delta/(24*60*60);
    delta = delta % (24*60*60);
    int hours = delta/(60*60);
    
    if ([self isAllowedToSpeakNow])
    {
        if (days==0 && hours == 1)
            [self speak:[self localizedString:@"CHARGE_DAY_0_HOUR_1"]];
        else if (days==0 && hours > 1)
        {
            K3AStringFormatter* f = [K3AStringFormatter formatterWithFormat:[self localizedString:@"CHARGE_DAY_0_HOUR_2"]];
            [f addInt:hours];
            [self speak:[f generateString]];
        }
        else if (days==1 && hours == 1)
            [self speak:[self localizedString:@"CHARGE_DAY_1_HOUR_1"]];
        else if (days==1 && hours > 1)
        {
            K3AStringFormatter* f = [K3AStringFormatter formatterWithFormat:[self localizedString:@"CHARGE_DAY_1_HOUR_2"]];
            [f addInt:hours];
            [self speak:[f generateString]];
        }
        else if (days>1 && hours == 1)
        {
            K3AStringFormatter* f = [K3AStringFormatter formatterWithFormat:[self localizedString:@"CHARGE_DAY_2_HOUR_1"]];
            [f addInt:days];
            [self speak:[f generateString]];
        }
        else
        {
            K3AStringFormatter* f = [K3AStringFormatter formatterWithFormat:[self localizedString:@"CHARGE_DAY_2_HOUR_2"]];
            [f addInt:days];
            [f addInt:hours];
            [self speak:[f generateString]];
        }
    }
    
    [m_lastFullChargeDate release];
    m_lastFullChargeDate = nil;
}

-(void)batteryStateChanged:(NSDictionary*)dict
{
    NSNumber* speakBattery = [m_settings objectForKey:@"speakBattery"];
    if (speakBattery && ![speakBattery boolValue]) return; // disabled
    
    int IsCharging = [[dict objectForKey:@"IsCharging"] intValue];
    int FullyCharged = [[dict objectForKey:@"FullyCharged"] intValue];
    //int ExternalChargeCapable = [[dict objectForKey:@"ExternalChargeCapable"] intValue];
    int ExternalConnected = [[dict objectForKey:@"ExternalConnected"] intValue];
    int CurrentCapacity = [[dict objectForKey:@"CurrentCapacity"] intValue];
    int MaxCapacity = [[dict objectForKey:@"MaxCapacity"] intValue];
    
    gdb_check();
    
    /*SELog(2, @">>> IsCharging: %d", IsCharging);
    SELog(2, @">>> FullyCharged: %d", FullyCharged);
    SELog(2, @">>> ExternalChargeCapable: %d", ExternalChargeCapable);
    SELog(2, @">>> ExternalConnected: %d", ExternalConnected);
    SELog(2, @">>> CurrentCapacity: %d", CurrentCapacity);
    SELog(2, @">>> MaxCapacity: %d", MaxCapacity);*/
    
    float perc = 100;
    if (MaxCapacity>0) perc = 100.0f/MaxCapacity*CurrentCapacity;
    
    if (m_firstBatteryEvent)
    {
        m_ExternalConnectedPrevState = ExternalConnected;
        m_lastPercent = perc;
        m_firstBatteryEvent = NO;
    }
    
    bool nowConnected = false;
    bool nowDisconnected = false;
    if (m_ExternalConnectedPrevState == 0 && ExternalConnected == 1)
        nowConnected = true;
    else if (m_ExternalConnectedPrevState == 1 && ExternalConnected == 0)
        nowDisconnected = true;
    m_ExternalConnectedPrevState = ExternalConnected;
    
    if (nowDisconnected && perc < 75.0f)
    {
        if ([self isAllowedToSpeakNow])
        {
            K3AStringFormatter* f = [K3AStringFormatter formatterWithFormat:[self localizedString:@"CHARGE_ONLY_PERCENT"]];
            [f addInt:perc];
            [self speak:[f generateString]];
        }
    }
    else if (nowConnected && perc < 75.0f)
    {
        m_percentWhenExternalConencted = perc;
    }
    
    if (FullyCharged)
    {
        [m_lastFullChargeDate release];
        m_lastFullChargeDate = [[NSDate alloc] initWithTimeIntervalSinceNow:0];
    }
    
    if (IsCharging && m_percentWhenExternalConencted < 75.f && ( 
       (m_lastPercent < 10.0f && perc > 10.0f) || (m_lastPercent < 20.0f && perc > 20.0f) || (m_lastPercent < 30.0f && perc > 30.0f) || (m_lastPercent < 40.0f && perc > 40.0f) || (m_lastPercent < 50.0f && perc > 50.0f) || (m_lastPercent < 60.0f && perc > 60.0f) || (m_lastPercent < 70.0f && perc > 70.0f) || (m_lastPercent < 80.0f && perc > 80.0f) || (m_lastPercent < 90.0f && perc > 90.0f)
    ))
    {
        NSNumber* speakEvery10Perc = [m_settings objectForKey:@"speakEvery10Perc"];
        if (!speakEvery10Perc || [speakEvery10Perc boolValue])
        {
            if ([self isAllowedToSpeakNow]) 
            {
                K3AStringFormatter* f = [K3AStringFormatter formatterWithFormat:[self localizedString:@"CHARGE_PERCENT"]];
                [f addInt:perc];
                [self speak:[f generateString]];
            }
        }
    }
    else if (FullyCharged && m_percentWhenExternalConencted < 75.f)
    {
        if ([self isAllowedToSpeakNow]) 
        {            
            [self speak:[self localizedString:@"CHARGE_FULL"]];
        }
        m_percentWhenExternalConencted = 100.0f;
    }
    else if (perc < 10.1f && !m_lowBattery10Warned && !IsCharging)
    {
        if ([self isAllowedToSpeakNow]) 
        {
            K3AStringFormatter* f = [K3AStringFormatter formatterWithFormat:[self localizedString:@"CHARGE_LOW"]];
            [f addInt:perc];
            [self speak:[f generateString]];
        }
        m_lowBattery10Warned = YES;
    }
    else if (perc < 5.1f && !m_lowBattery5Warned && !IsCharging)
    {
        if ([self isAllowedToSpeakNow]) 
        {
            K3AStringFormatter* f = [K3AStringFormatter formatterWithFormat:[self localizedString:@"CHARGE_VERY_LOW"]];
            [f addInt:perc];
            [self speak:[f generateString]];
        }
        m_lowBattery5Warned = YES;
    }
    else if (IsCharging && m_lowBattery5Warned)
    {
        if ([self isAllowedToSpeakNow]) 
        {
            [self speak:[self localizedString:@"CHARGE_STARTED_THANKS"]];
            [self speakLastChargeDate];
        }
        
        m_lowBattery10Warned = NO;
        m_lowBattery5Warned = NO;
    }
    else if (IsCharging && m_lowBattery10Warned)
    {
        if ([self isAllowedToSpeakNow]) 
        {
            [self speak:[self localizedString:@"CHARGE_STARTED"]];
            [self speakLastChargeDate];
        }
        
        m_lowBattery10Warned = NO;
        m_lowBattery5Warned = NO;
    }
    
    m_lastPercent = perc;
}

static void ReloadPrefs(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    [[SESpeakEventsServer sharedInstance] loadSettings];
}

extern "C" {
    void CPCancelWakeAtDateWithIdentifier(NSDate* d, NSString* ident);
    void CPScheduleWakeAtDateWithIdentifier(NSDate* d, NSString* ident);
}

-(void)scheduleWakeUp:(unsigned)seconds
{
    NSDate* nextWake = [NSDate dateWithTimeIntervalSinceNow:seconds];
    
    //cancel any old wakes
    NSData* data = [NSData dataWithContentsOfFile: @"/private/var/preferences/SystemConfiguration/com.apple.AutoWake.plist"];
    NSString* errorString = nil;
    NSDictionary* dict = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:kCFPropertyListImmutable format:NULL errorDescription:&errorString];
    
    if(errorString)
        SELog(0, @"Failed to read autowake dict %@",errorString);
    
    NSArray* wake = [dict objectForKey:@"wake"];
    for(NSDictionary* item in wake){
        if([[item objectForKey:@"scheduledby"] isEqualToString:@"me.k3a.SpeakEvents"]){
            NSDate* d = [item objectForKey:@"time"];
            //SELog(0, @"Cancelling the old wake up event at %@", d);
            CPCancelWakeAtDateWithIdentifier(d, @"me.k3a.SpeakEvents");
        }
    }
    
    //schedule new wake
    CPScheduleWakeAtDateWithIdentifier(nextWake,@"me.k3a.SpeakEvents");
}

-(void)speakTimeWithMinutes
{
    NSDateComponents* dc = [[NSCalendar currentCalendar] components:(NSHourCalendarUnit | NSMinuteCalendarUnit) 
                                                           fromDate:[NSDate date]];
    
    NSNumber* militaryTime = [m_settings objectForKey:@"militaryTime"];
    
    if (militaryTime && [militaryTime boolValue])
    {
        K3AStringFormatter* f = [K3AStringFormatter formatterWithFormat:[self localizedString:@"CURRENT_TIME_MIN"]];
        [f addInt:dc.hour];
        [f addInt:dc.minute];
        [self speak:[f generateString]];
    }
    else
    {
        int safeHour = dc.hour;
        
        if (safeHour == 0) 
            safeHour = 12;
        else if (safeHour > 12)
            safeHour -= 12;
        
        K3AStringFormatter* f = [K3AStringFormatter formatterWithFormat:[self localizedString:@"CURRENT_TIME_MIN"]];
        [f addInt:safeHour];
        [f addInt:dc.minute];
        [self speak:[f generateString]];
    }
}

-(void)speakTime
{
    NSDateComponents* dc = [[NSCalendar currentCalendar] components:(NSHourCalendarUnit | NSMinuteCalendarUnit) 
                                                           fromDate:[NSDate date]];
    
    NSNumber* militaryTime = [m_settings objectForKey:@"militaryTime"];
    
    if (militaryTime && [militaryTime boolValue])
    {
        K3AStringFormatter* f = [K3AStringFormatter formatterWithFormat:[self localizedString:@"CURRENT_TIME"]];
        [f addInt:dc.hour];
        [self speak:[f generateString]];
    }
    else
    {
        int safeHour = dc.hour;
        
        if (safeHour == 0) 
            safeHour = 12;
        else if (safeHour > 12)
            safeHour -= 12;
        
        K3AStringFormatter* f = [K3AStringFormatter formatterWithFormat:[self localizedString:@"CURRENT_TIME"]];
        [f addInt:safeHour];
        [self speak:[f generateString]];
    }
}

-(void)hourTimerThread // can be called multiple times
{
    NSNumber* speakTimeType = [m_settings objectForKey:@"speakTimeType"];
    unsigned speakTimeTypeInt = [speakTimeType unsignedIntValue];
    
    if (m_timerThreadRunning || speakTimeTypeInt == 0) return;
    
    m_timerThreadRunning = YES;
    int lastSpokenTime = -1;
    while (true)
    {
        NSNumber* speakTimeType = [m_settings objectForKey:@"speakTimeType"]; // 0-disabled, 1-hour, 2-30min, 3-15min
        unsigned speakTimeTypeInt = [speakTimeType unsignedIntValue];
        
        NSDateComponents* dc = [[NSCalendar currentCalendar] components:(NSHourCalendarUnit|NSMinuteCalendarUnit|NSSecondCalendarUnit) 
                                                               fromDate:[NSDate date]];
        int hour = [dc hour];
        int minute = [dc minute];
        int second = [dc minute];
        
        // schedule system wakeup
        if (second < 59)
        {
            if (speakTimeTypeInt == 1)
                [self scheduleWakeUp:(60-minute)*60 + 59-second];
            else if (speakTimeTypeInt == 2)
            {
                unsigned a = 30-minute;
                unsigned b = 60-minute;
                [self scheduleWakeUp:MIN(a,b)*60 + 59-second];
            }
            else if (speakTimeTypeInt == 3)
            {
                unsigned a = 15-minute;
                unsigned b = 30-minute;
                unsigned c = 45-minute;
                unsigned d = 60-minute;
                [self scheduleWakeUp:MIN(MIN(a,b),MIN(c,d))*60 + 59-second];
            }
        }
        
        if (speakTimeTypeInt)
        {
            int currSpokenTime = hour*100+minute;
            if (lastSpokenTime != currSpokenTime) // make sure not to say the same time twice
            {
                // is the right time now?
                bool goodTime = false;
                if (speakTimeTypeInt == 1 && minute == 0)
                    goodTime = true;
                else if (speakTimeTypeInt == 2 && (minute==0||minute==30) )
                    goodTime = true;
                else if (speakTimeTypeInt == 3 && (minute==0||minute==15||minute==30||minute==45) )
                    goodTime = true;
                
                if (goodTime  && [self isAllowedToSpeakNow]) // yes, it's the right time now
                {
                    lastSpokenTime = currSpokenTime;
                    
                    if (minute == 0)
                        [self speakTime];
                    else
                        [self speakTimeWithMinutes];
                }
            }
        }
        sleep(25);
    }
    m_timerThreadRunning = NO;
}

-(void)speakLastMessageAgain
{
    [self stopSpeaking];
    m_currentlySpeakingObject = [m_lastSpokenObject retain];
    m_currentlySpeakingObject.numPartsRead = 1;
    [self speakHiPriority:m_currentlySpeakingObject.firstPart];
}

-(void)handleIncomingCall:(NSString*)caller
{
    NSNumber* speakIncomingCallsNumber = [m_settings objectForKey:@"speakIncomingCalls"];
    BOOL speakIncomingCalls = !speakIncomingCallsNumber || [speakIncomingCallsNumber boolValue];
    
    if (speakIncomingCalls)
    {
        if ([self isAllowedToSpeakNow]) 
        {
            if ([self bluetoothHandsFree]) // use standard method on bluetooth
            {
                K3AStringFormatter* f = [K3AStringFormatter formatterWithFormat:[self localizedString:@"CALL"]];
                [f addString:caller];
                [self speakHiPriority:[f generateString]];
            }
            else // when no bluetooth accessory connected, use old method not pausing anything
            {
                K3AStringFormatter* f = [K3AStringFormatter formatterWithFormat:[self localizedString:@"CALL"]];
                [f addString:caller];
                NSString* text = [f generateString];
                
                SELog(0, @"[%@] Speaking call '%@'",m_defaultLang, text);
                
                if ([synth respondsToSelector:@selector(startSpeakingString:withLanguageCode:request:error:)])
                    [synth startSpeakingString:text withLanguageCode:m_defaultLang request:nil error:nil];
                else
                    [synth startSpeakingString:text withLanguageCode:m_defaultLang];
                [self setupCleaningTimer];
            }
        }
    }
    else 
        SELog(0, @"Not speaking incoming call - disabled in settings");
}

-(void)handleSystemNotification:(UILocalNotification*)notif
{
    if (m_speakApps && [m_speakApps containsObject:@"com.apple.mobiletimer"])
    {
        bool handled = false;
        
        if ([notif.alertBody isEqualToString:@"COUNT_DOWN_TIME_REACHED"])
        {
            handled = true;
            if ([self isAllowedToSpeakNow]) 
                [self speakHiPriority:[self localizedString:@"TIMER_DONE"]];
        }
        else if ([notif allowSnooze])
        {
            handled = true;
            if ([self isAllowedToSpeakNow]) 
            {
                BOOL readTimeInAlarms = [[m_settings objectForKey:@"readTimeInAlarms"] boolValue];
                
                if (readTimeInAlarms) // read time + alarm name
                {
                    NSString* timePart = nil;
                    
                    NSDateComponents* dc = [[NSCalendar currentCalendar] components:(NSHourCalendarUnit | NSMinuteCalendarUnit) 
                                                                           fromDate:[NSDate date]];
                    
                    NSNumber* militaryTime = [m_settings objectForKey:@"militaryTime"];
                    
                    if (militaryTime && [militaryTime boolValue])
                    {
                        K3AStringFormatter* f = [K3AStringFormatter formatterWithFormat:[self localizedString:@"CURRENT_TIME_MIN"]];
                        [f addInt:dc.hour];
                        [f addInt:dc.minute];
                        timePart = [f generateString];
                    }
                    else
                    {
                        int safeHour = dc.hour;
                        
                        if (safeHour == 0) 
                            safeHour = 12;
                        else if (safeHour > 12)
                            safeHour -= 12;
                        
                        K3AStringFormatter* f = [K3AStringFormatter formatterWithFormat:[self localizedString:@"CURRENT_TIME_MIN"]];
                        [f addInt:safeHour];
                        [f addInt:dc.minute];
                        timePart = [f generateString];
                    }
                    
                    K3AStringFormatter* f = [K3AStringFormatter formatterWithFormat:[self localizedString:@"ALARM"]];
                    [f addString:notif.alertBody];
                    NSString* alarmPart = [f generateString];
                    
                    [self speakHiPriority:[NSString stringWithFormat:@"%@. %@", alarmPart, timePart]];
                }
                else // just alarm
                {
                    K3AStringFormatter* f = [K3AStringFormatter formatterWithFormat:[self localizedString:@"ALARM"]];
                    [f addString:notif.alertBody];
                    
                    [self speakHiPriority:[f generateString]];
                }
            }
        }
        
        if (handled)
        {
            NSNumber* suppressSound = [m_settings objectForKey:@"suppressSound"];
            if (suppressSound && [suppressSound boolValue])
            {
                SELog(0, @"Suppressing original sound of system notification.");
                notif.soundName = @"";
            }
        }
        
    }
    else 
        SELog(0, @"Not speaking timer event - disabled in settings");
}

-(void)handleSpeakDirections:(NSString*)name userInfo:(NSDictionary*)dict
{
    NSString* instructions = [dict objectForKey:@"instructions"];
    [self speak:instructions];
}

extern "C" {
    CFStringRef CTCallCopyAddress(CFAllocatorRef , const void* call);
    CFStringRef CTCallCopyName(CFAllocatorRef , const void* call);
}

/*static ABRecordRef findRecord(CFStringRef phoneNumber)
{
    ABAddressBookRef addressBook = ABAddressBookCreate();
    ABRecordRef record = ABCFindPersonMatchingPhoneNumber(addressBook, 
                                                          (NSString*)phoneNumber,0, 0);
    //CFRelease(addressBook);
    return record;
}*/
    
static void CTCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    
    
    //SELog(0, @"CT callback %@ : %@ : %@", name, userInfo, object);
    if ([(NSString*)name isEqualToString:@"SBIncomingCallPendingNotification"])
    {
        NSString* num = (NSString*)CTCallCopyAddress(CFAllocatorGetDefault(), object);
        if (!num) { SELog(0, @"Was not able to get address of incoming call"); return; }
        
        NSString* name = getPhoneticNameByNumber(num);
        if (!name) { SELog(0, @"Was not able to get phonetic name of incoming call"); return; }
        
        //SELog(0, @"AE: incoming call %@", name);
        [[SESpeakEventsServer sharedInstance] handleIncomingCall:name];
        
        CFRelease(num);
    }
}

static void uncaughtExceptionHandler(NSException *exception) {
    SELog(0, @"CRASH DETECTED: %@", exception);
    SELog(0, @"Stack Trace: %@", [exception callStackSymbols]);
    // Internal error reporting
}

- (id)init {
	if((self = [super init])) {
        
        NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
        
        SELog(0, @"Singleton initialization");
        
        s_ses_instance = self;
        m_lowBattery10Warned = NO;
        m_lowBattery5Warned = NO;
        m_firstBatteryEvent = YES;
        m_percentWhenExternalConencted = 100.0f;
        m_speakObjects = [[NSMutableArray alloc] init];
        
        m_initTimestamp = time(0);
        m_afterSafeTime = NO;
        m_timerThreadRunning = NO;
        m_bluetoothWasUsed = NO;
        
        synth = [[VSSpeechSynthesizer alloc] init];
        //[synth setMaintainPersistentConnection:YES];
        [synth setDelegate:self];
        [synth setVoice:@"Samantha"];
        SELog(0, @"Synth inited");
        
        [self loadSettings];
        
        s_abLock = [NSRecursiveLock new];

        // settings reload notif
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), self, ReloadPrefs, CFSTR("me.k3a.SpeakEvents/reloadPrefs"), NULL, CFNotificationSuspensionBehaviorCoalesce);
        
        m_langDict = [[NSDictionary dictionaryWithContentsOfFile:@"/Library/Application Support/SpeakEvents/LanguageStrings.plist"] retain];
        if (!m_langDict)
        {
            SELog(0, @"Failed to load language file!! (/Library/Application Support/SpeakEvents/LanguageStrings.plist).");
            [self release];
            return nil;
        }
        else
            SELog(0, @"Using language: %@", m_defaultLang);

		m_smileys = [[NSMutableDictionary dictionaryWithContentsOfFile:@"/Library/Application Support/SpeakEvents/Smileys.plist"] retain];
		if (!m_smileys)
		{
			SELog(0, @"Failed to load smileys file!! (/Library/Application Support/SpeakEvents/Smileys.plist).");
		}
        
        // setup notification observer 
        /*bbObserver = [[BBObserver alloc] init];
        bbObserver.observerFeed = 0xFFFFFFFF;//0xE;
        bbObserver.delegate = self;
        
        SELog(0, @"Observer created");*/
        
        // register activator events
        [SEActivatorSupport new];
        
        SELog(0, @"Activator support inited");
        
        //id ct = CTTelephonyCenterGetDefault();
        //CTTelephonyCenterAddObserver(ct, NULL, CTCallback, NULL, NULL, CFNotificationSuspensionBehaviorHold);
        
        CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL, CTCallback, NULL, NULL, CFNotificationSuspensionBehaviorHold);
        
        // MS HOOKS ------------
		bool hooked;

        // system local notifications
        GET_CLASS(SBApplication)
        LOAD_HOOK(SBApplication, _fireNotification:, _fireNotification$)
        LOAD_HOOK_SILENT(SBApplication, launchSucceeded:, launchSucceeded$)
		if (!hooked) 
		{
			//LOAD_HOOK(SBApplication, didLaunch:, didBeginLaunch$);
			LOAD_HOOK(SBApplication, didBeginLaunch:, didBeginLaunch$);
		}
        
        // Notificator support
        GET_CLASS(SBBulletinBannerController)
        LOAD_HOOK(SBBulletinBannerController, observer:addBulletin:forFeed:, observer$addBulletin$forFeed$)
        
        GET_CLASS(BBServer)
        LOAD_HOOK_SILENT(BBServer, publishBulletin:destinations:, publishBulletin$destinations$);
		if (!hooked)
		{
			LOAD_HOOK(BBServer, publishBulletin:destinations:alwaysToLockScreen:,  publishBulletin$destinations$alwaysToLockScreen$);
		}

        /*GET_CLASS(TLToneManager)
        LOAD_HOOK(TLToneManager, currentNewMailToneSoundID, currentNewMailToneSoundID);
        LOAD_HOOK(TLToneManager, currentTextToneSoundID, currentTextToneSoundID);*/
        
        // original mail bulletin
        //GET_CLASS(MFMailBulletin)
        //LOAD_HOOK(MFMailBulletin, bulletinRequest, bulletinRequest);
        
        // stop speaking on silent switch when inSilent is NO
        int tok;
        notify_register_dispatch("com.apple.springboard.ringerstate", &tok, dispatch_get_main_queue(), ^(int token)
        {
            NSNumber* inSilent = [m_settings objectForKey:@"inSilent"];
            if (inSilent && [inSilent boolValue] == NO)
                [self stopSpeaking];
        });
        
        SELog(0, @"Msg center");
        
        CPDistributedMessagingCenter* center = [[CPDistributedMessagingCenter centerNamed:@"me.k3a.SpeakEvents.center"] retain];
        [center runServerOnCurrentThread];
        [center registerForMessageName:@"SpeakDirections" target:self selector:@selector(handleSpeakDirections:userInfo:)];

		SELog(0, @"DND");
		id bbGateway = [[objc_getClass("BBSettingsGateway") alloc] init];

		[bbGateway setActiveBehaviorOverrideTypesChangeHandler:^(BOOL enabled) {
			s_isDND = enabled;
		}];
    
        SELog(0, @"Init completed");
        
        /*SELog(0, @"Phonetic name test");
        SELog(0, @"-> %@", getPhoneticNameByNumber(@"+(420) 775 320"));
        SELog(0, @"-> %@", getPhoneticNameByNumber(@"+420 737 112 849"));
        SELog(0, @"-> %@", getPhoneticNameByNumber(@"+(420) 777-875-443"));
        SELog(0, @"-> %@", getPhoneticNameByNumber(@"+(420) 4334-43322-343222-33"));*/
        /*SELog(0, @"Replace Test");
        SELog(0, @"%@", [[[[K3AStringFormatter formatterWithFormat:@"Test %1 second %2 third %3 .and. %4"] addString:@"str"] addInt:2] generateString]);
        SELog(0, @"%@", [[[K3AStringFormatter formatterWithFormat:[self localizedString:@"NOTIFICATION"]] addString:@"TestApp"] generateString]);*/

	}
    
	return self;
}

- (void)dealloc {
    [synth release];
    [m_lastFullChargeDate release];
    [m_settings release];
    [m_defaultLang release];
    [m_langDict release];
    [bbObserver release];
    [m_speakObjects release];
    
    CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(), self);
    
	[super dealloc];
}

+(SESpeakEventsServer*)sharedInstance
{
    return s_ses_instance;
}

-(BOOL)loadSettings
{
    [m_settings release];
    m_settings = [[NSMutableDictionary dictionaryWithContentsOfFile:@SE_PREF_FILE] retain];
    
    // apply defaults
    NSData* speakAppsData = [m_settings objectForKey:@"speakApps"];
    [m_speakApps release]; m_speakApps = nil;
    if (speakAppsData)
    {
        m_speakApps = [[NSKeyedUnarchiver unarchiveObjectWithData:speakAppsData] retain];
        if (!m_speakApps) m_speakApps = [[NSSet alloc] init];
    }
    else
    {
        m_speakApps = [[NSSet setWithObjects:@"com.apple.MobileSMS", @"com.apple.mobilemail", nil] retain];
        [m_settings setObject:[NSKeyedArchiver archivedDataWithRootObject:m_speakApps] forKey:@"speakApps"];
    }
    if (![m_settings objectForKey:@"detectLang"])
        [m_settings setObject:[NSNumber numberWithBool:YES] forKey:@"detectLang"];
    if (![m_settings objectForKey:@"speakBattery"])
        [m_settings setObject:[NSNumber numberWithBool:YES] forKey:@"speakBattery"];
    
    NSString* voice = [m_settings objectForKey:@"voice"];
    [m_defaultLang release];
    if (!voice || [voice isEqualToString:@"system"])
        m_defaultLang = [GetSystemLanguage() copy];
    else
        m_defaultLang = [voice copy];
    
    
    SELog(0, @"Tweak has loaded settings");
    
    // start hour timer (will immediately end if time speaking not enabled)
    [NSThread detachNewThreadSelector:@selector(hourTimerThread) toTarget:self withObject:nil];
    
    // set speed and volume
    NSNumber* voiceSpeed = [m_settings objectForKey:@"voiceSpeed"];
    float voiceSpeedToSet = voiceSpeed?[voiceSpeed floatValue]:1;
    [synth setRate:voiceSpeedToSet];
    
    //NSNumber* enabled = [m_settings objectForKey:@"enabled"];
    //if (enabled && [enabled boolValue] == NO)
    //    [self stopSpeaking];
    
    return TRUE;
}

-(BOOL)saveSettings
{
    return [m_settings writeToFile:@SE_PREF_FILE atomically:YES];
}
-(void)enableSpeakEvents
{
    [m_settings setObject:[NSNumber numberWithBool:YES] forKey:@"enabled"];
    [self saveSettings];
}
-(void)disableSpeakEvents
{
    [self stopSpeaking];
    [m_settings setObject:[NSNumber numberWithBool:NO] forKey:@"enabled"];
    [self saveSettings];
}
-(void)toggleSpeakEvents
{
    NSNumber* enabled = [m_settings objectForKey:@"enabled"];
    BOOL enabledBool = !enabled || [enabled boolValue];
    [m_settings setObject:[NSNumber numberWithBool:!enabledBool] forKey:@"enabled"];
    
    if (enabled) // ... togle to disable
    {
        [self stopSpeaking];
    }
    
    [self saveSettings];
}

-(void)stopSpeaking
{
    SELog(3, @"stopSpeaking");
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [m_delayTimer invalidate];
        [m_delayTimer release];
        m_delayTimer = nil;
        
        [m_currentlySpeakingObject release];
        m_currentlySpeakingObject = nil;
        
        if ([synth respondsToSelector:@selector(stopSpeakingAtNextBoundary:error:)])
            [synth stopSpeakingAtNextBoundary:0 error:nil]; //ios7
        else
            [synth stopSpeakingAtNextBoundary:0];
        
        [self speechSynthesizer:synth didFinishSpeaking:YES withError:nil]; // just in case..
        [self stopBluetooth];
            
    });
}

-(NSString*)localizedString:(NSString*)str
{
    BOOL useUserStrings = [[m_settings objectForKey:@"caEnable"] boolValue];
    if (useUserStrings)
    {
        NSString* tr = [m_settings objectForKey:str];
        if (tr) return tr;
    }
    
    NSDictionary* dict = [m_langDict objectForKey:m_defaultLang];
    if (!dict) dict = [m_langDict objectForKey:MainLangPart(m_defaultLang)];
    if (!dict) dict = [m_langDict objectForKey:@"en-US"];
    if (!dict) dict = [m_langDict objectForKey:@"en"];
    
    NSString* localized = [dict objectForKey:str];
    if (localized)
        return localized;
    else 
        return str;
}

-(NSString*)localizedString:(NSString*)str forLang:(NSString*)lang
{
    BOOL useUserStrings = [[m_settings objectForKey:@"caEnable"] boolValue];
    if (useUserStrings)
    {
        NSString* tr = [m_settings objectForKey:str];
        if (tr) return tr;
    }
    
    NSDictionary* dict = [m_langDict objectForKey:lang];
    if (!dict) dict = [m_langDict objectForKey:MainLangPart(lang)];
    if (!dict) dict = [m_langDict objectForKey:m_defaultLang];
    if (!dict) dict = [m_langDict objectForKey:MainLangPart(m_defaultLang)];
    if (!dict) dict = [m_langDict objectForKey:@"en-US"];
    if (!dict) dict = [m_langDict objectForKey:@"en"];
    
    NSString* localized = [dict objectForKey:str];
    if (localized)
        return localized;
    else 
        return @"";
}

-(BOOL)isInsideAllowedTimeRange
{
    NSDateComponents* dc = [[NSCalendar currentCalendar] components:(NSHourCalendarUnit | NSMinuteCalendarUnit) fromDate:[NSDate date]];
    unsigned currHour = [dc hour];
    NSNumber* fromHourObj = [m_settings objectForKey:@"speakFrom"];
    NSNumber* toHourObj = [m_settings objectForKey:@"speakTo"];
    if (fromHourObj && toHourObj)
    {
        unsigned fromHour = [fromHourObj unsignedIntValue];
        unsigned toHour = [toHourObj unsignedIntValue];
        if (fromHour < toHour)
        {
            if (currHour < fromHour || currHour >= toHour) return NO;
        }
        else if (fromHour != toHour) // = fromHour > toHour
        {
            if (currHour < fromHour && currHour >= toHour) return NO;
        }
    }
    return YES;
}

/*extern id AVController_ActiveAudioRouteAttribute;
-(NSString*)currentAudioRoute
{
    AVSystemController* systemCtrl = [AVSystemController sharedAVSystemController];
    NSString* currRoute = [systemCtrl attributeForKey:AVController_ActiveAudioRouteAttribute];
    return currRoute;
}*/

-(BOOL)bluetoothHandsFree
{
    AVSystemController* systemCtrl = [AVSystemController sharedAVSystemController];
    NSArray* routes = [systemCtrl pickableRoutesForCategory:@"PlayAndRecord_WithBluetooth"];
    for (NSDictionary* route in routes)
    {
        NSString* routeName = [route objectForKey:@"AVAudioRouteName"];
        
        if ([routeName isEqualToString:@"HeadsetBT"] || [routeName isEqualToString:@"HeadphonesBT"])
            return YES;
    }
    return NO;
}

static BOOL HeadphonesPresent()
{
    VolumeControl<VolumeControl>* volCtrl = [objc_getClass("VolumeControl") sharedVolumeControl];
    if ([volCtrl respondsToSelector:@selector(_headphonesPresent)])
        return [volCtrl _headphonesPresent];
    else
        return [volCtrl headphonesPresent];
}

-(BOOL)isAllowedToSpeakNowMainThread // must be run on Main Thread
{
    SBTelephonyManager* telephonyManager = [objc_getClass("SBTelephonyManager") sharedTelephonyManager];
    SBMediaController* mediaController = (SBMediaController*)[objc_getClass("SBMediaController") sharedInstance];
	id _SBAssistantController = objc_getClass("SBAssistantController");
    SBAssistantController* assistantCtrl = [_SBAssistantController sharedInstance];
    SBAwayController* awayCtrl = [objc_getClass("SBAwayController") sharedAwayController];
    
    NSNumber* enabled = [m_settings objectForKey:@"enabled"];
    NSNumber* lockedOnly = [m_settings objectForKey:@"lockedOnly"];
    NSNumber* hpOnly = [m_settings objectForKey:@"hpOnly"];
    BOOL bluetoothPresent = [self bluetoothHandsFree];
    
    if (enabled && [enabled boolValue] == FALSE)
    {
        SELog(0, @"Not speaking - general switch is Off");
        return NO;
    }
    else if ([awayCtrl isLocked] == NO && lockedOnly && [lockedOnly boolValue])
    {
        SELog(0, @"Not speaking - device not locked");
        return NO;
    }
    else if (HeadphonesPresent() == NO && bluetoothPresent == NO && hpOnly && [hpOnly boolValue])
    {
        SELog(0, @"Not speaking - headphones/headset not present");
        return NO;
    }
    else if (IsInNotAllowedApp())
    {
        SELog(0, @"Not speaking - disallowed app is foremost");
        return NO;
    }
    else if ([telephonyManager inCall])
    {
        SELog(0, @"Not speaking - in call");
        return NO;
    }
    else if (([assistantCtrl respondsToSelector:@selector(isAssistantVisible)] && [assistantCtrl isAssistantVisible]) ||
			(/*ios6*/[_SBAssistantController respondsToSelector:@selector(isAssistantVisible)] && [_SBAssistantController isAssistantVisible]))
    {
        SELog(0, @"Not speaking - in assistant");
        return NO;
    }
    else if (![self isInsideAllowedTimeRange])
    {
        SELog(0, @"Not speaking - outside allowed time range");
        return NO;
    }
    else if ([mediaController isRingerMuted] && !bluetoothPresent) // speaks always on bluetooth
    {
        NSNumber* inSilent = [m_settings objectForKey:@"inSilent"];
        if (inSilent && [inSilent boolValue] == NO)
        {
            SELog(0, @"Not speaking - ringer is muted");
            return NO;
        }
    }
	else if (s_isDND)
	{
        SELog(0, @"Not speaking - DND is on");
        return NO;
	}
    
    // check whether some other app is recording
    AVSystemController* systemCtrl = [AVSystemController sharedAVSystemController];
    NSNumber* someoneRecording = [systemCtrl attributeForKey:AVSystemController_IsSomeoneRecordingAttribute];
    if ([someoneRecording boolValue] == YES)
    {
        SELog(0, @"Not speaking - someone is recording audio");
        return NO;
    }
    
    return YES;
}

-(BOOL)isAllowedToSpeakNow
{
    if ([NSThread isMainThread])
        return [self isAllowedToSpeakNowMainThread];
    else
    {
        __block BOOL res = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{
            res = [self isAllowedToSpeakNowMainThread];
        });
        return res;
    }
}

/*static BOOL IsLocalizableString(NSString* str)
{
    const char* cstr = [str UTF8String];
    unsigned len = strlen(cstr);
    for (register unsigned int i=0; i<len; i++)
    {
        if ( islower(cstr[i]) || (i+1<len && cstr[i]=='%' && cstr[i+1]!='%') )
            return NO;
    }
    return YES;
}*/

-(void)setVolumeBeforeSpeaking:(NSString*)lang
{
	BOOL lockVolumeEnabled = [[m_settings objectForKey:@"lockVolumeEnabled"] boolValue];
	if (lockVolumeEnabled) // ..enabled on lockscreen only
	{	
		SBAwayController* awayCtrl = [objc_getClass("SBAwayController") sharedAwayController];
		lockVolumeEnabled = [awayCtrl isLocked]; // enable only if the device is locked
	}

    BOOL setDeviceVol = [[m_settings objectForKey:@"setDeviceVol"] boolValue];
    if (setDeviceVol)
    {
        NSNumber* speechVolume = [m_settings objectForKey:lockVolumeEnabled?@"speechVolumeLocked":@"speechVolume"];
        float speechVolumeToSet = speechVolume?[speechVolume floatValue]:0.8f;
        
        AVSystemController* systemCtrl = [AVSystemController sharedAVSystemController];
        
        NSNumber* speakInBT = [m_settings objectForKey:@"speakInBT"];
        if (speakInBT && [speakInBT boolValue])
        {
            float oldVol = 0;
            [systemCtrl getVolume:&oldVol forCategory:@"VoiceCommand"];
            
            if ( fabsf(oldVol-speechVolumeToSet) > 0.01f || oldVol < 0.1f )
            {
                if (speechVolumeToSet < 0.1f) speechVolumeToSet = 0.1f;
                [systemCtrl setVolumeTo:speechVolumeToSet forCategory:@"VoiceCommand"]; // in BT when using VoiceController
            }
        }
        else
        {
            float oldVol = 0;
            [systemCtrl getVolume:&oldVol forCategory:@"Audio/Video"];
            
            if ( fabsf(oldVol-speechVolumeToSet) > 0.01f || oldVol < 0.1f )
            {
                if (speechVolumeToSet < 0.1f) speechVolumeToSet = 0.1f;
                [systemCtrl setVolumeTo:speechVolumeToSet forCategory:@"Audio/Video"]; // probably used when outside BT
            }
        }
        
        [synth setVolume:normalizedVol(0.9f, lang)]; // set to "default"..
    }
    else // standard (synth-only)
    {
        // set system vol to at least 0.1
        AVSystemController* systemCtrl = [AVSystemController sharedAVSystemController];
        NSNumber* speakInBT = [m_settings objectForKey:@"speakInBT"];
        if (speakInBT && [speakInBT boolValue])
        {
            float oldVol = 0.11f;
            [systemCtrl getVolume:&oldVol forCategory:@"VoiceCommand"];
            
            if ( oldVol < 0.1f )
                [systemCtrl setVolumeTo:0.1f forCategory:@"VoiceCommand"]; // in BT when using VoiceController
        }
        else
        {
            float oldVol = 0.11f;
            [systemCtrl getVolume:&oldVol forCategory:@"Audio/Video"];
            
            if ( oldVol < 0.1f )
                [systemCtrl setVolumeTo:0.1f forCategory:@"Audio/Video"]; // probably used when outside BT
        }
        
        // set synth volume
        NSNumber* speechVolume = [m_settings objectForKey:lockVolumeEnabled?@"speechVolumeLocked":@"speechVolume"];
        float speechVolumeToSet = speechVolume?[speechVolume floatValue]:0.9f;
        [synth setVolume:normalizedVol(speechVolumeToSet, lang)];
    }
}

-(void)speakHiPriority:(NSString*)text
{
    if (!text || ![text length]) 
    { 
        dispatch_async(dispatch_get_main_queue(), ^{
            [self speechSynthesizer:synth didFinishSpeaking:YES withError:nil]; 
        });
        return;
    };
    
    dispatch_async(dispatch_get_main_queue(), ^{
    
        NSNumber* speakInBT = [m_settings objectForKey:@"speakInBT"];
        if (speakInBT && [speakInBT boolValue])
            [self startBluetooth];
     
        SELog(0, @"[%@] Speaking hi-pri '%@'",m_defaultLang, text);
        
        [self setVolumeBeforeSpeaking:m_defaultLang];
        if ([synth respondsToSelector:@selector(startSpeakingString:withLanguageCode:request:error:)])
            [synth startSpeakingString:text withLanguageCode:m_defaultLang request:nil error:nil];
        else
            [synth startSpeakingString:text withLanguageCode:m_defaultLang];
        [self setupCleaningTimer];
        
    });
}
-(void)speakHiPriority:(NSString*)text inLang:(NSString*)lang
{
    if (!text || ![text length]) 
    { 
        dispatch_async(dispatch_get_main_queue(), ^{
            [self speechSynthesizer:synth didFinishSpeaking:YES withError:nil]; 
        });
        return;
    };
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSNumber* speakInBT = [m_settings objectForKey:@"speakInBT"];
        if (speakInBT && [speakInBT boolValue])
            [self startBluetooth];
        
        SELog(0, @"[%@] Speaking hi-pri '%@'",lang, text);
        
        [self setVolumeBeforeSpeaking:lang];
        if ([synth respondsToSelector:@selector(startSpeakingString:withLanguageCode:request:error:)])
            [synth startSpeakingString:text withLanguageCode:lang request:nil error:nil];
        else
            [synth startSpeakingString:text withLanguageCode:lang];
        [self setupCleaningTimer];
        
    });
}

-(void)speak:(NSString*)text
{
    if (!text || ![text length]) 
    { 
        /*dispatch_async(dispatch_get_main_queue(), ^{
            [self speechSynthesizer:synth didFinishSpeaking:YES withError:nil]; 
        });*/
        return;
    };
    
    if (m_currentlySpeakingObject) return; // already speaking notification/mail/sms/...
    
    NSNumber* speakInBT = [m_settings objectForKey:@"speakInBT"];
    if (speakInBT && [speakInBT boolValue])
        [self startBluetooth];
    
    SELog(0, @"[%@] Speaking '%@'.", m_defaultLang, text);
        
    [text retain];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setVolumeBeforeSpeaking:m_defaultLang];
        if ([synth respondsToSelector:@selector(startSpeakingString:withLanguageCode:request:error:)])
            [synth startSpeakingString:text withLanguageCode:m_defaultLang request:nil error:nil];
        else
            [synth startSpeakingString:text withLanguageCode:m_defaultLang];
        [self setupCleaningTimer];
        [text release];
    });
}

-(void)speakLang:(NSString*)lang ident:(NSString*)text
{
    if (!text || ![text length]) 
    { 
        /*dispatch_async(dispatch_get_main_queue(), ^{
            [self speechSynthesizer:synth didFinishSpeaking:YES withError:nil]; 
        });*/
        return;
    };
    
    if (m_currentlySpeakingObject) return; // already speaking notification/mail/sms/...
    
    NSNumber* speakInBT = [m_settings objectForKey:@"speakInBT"];
    if (speakInBT && [speakInBT boolValue])
        [self startBluetooth];
    
    SELog(0, @"[%@] Speaking '%@'.", lang, text);

    [text retain];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setVolumeBeforeSpeaking:lang];
        if ([synth respondsToSelector:@selector(startSpeakingString:withLanguageCode:request:error:)])
            [synth startSpeakingString:text withLanguageCode:lang request:nil error:nil];
        else
            [synth startSpeakingString:text withLanguageCode:lang];
        [self setupCleaningTimer];
        [text release];
    });
}

@end







#pragma mark - COMMON PART


static void Shutdown()
{
    SELog(0, @"************* SpeakEvents ShutDown *************");
}

static __attribute__((constructor)) void Initialize() 
{
	// Init
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    SELog(0, @"SpeakEvents - build %s", __TIMESTAMP__);
    
    gdb_disable();
	
	// bundle identifier
	NSString* bundleIdent = getAppIdentifier();

    gdb_check();
    
    if ( !bundleIdent || 
        (![bundleIdent isEqualToString:@"MobileMail"] && ![bundleIdent isEqualToString:@"SpringBoard"])
        )
	{
        SELog(0, @"( SpeakEvents init for %s )", [bundleIdent UTF8String]);
		[pool release];
		return;
	}
    
    SELog(0, @"************* SpeakEvents init for %s ************* ", [bundleIdent UTF8String]);

#ifdef DEBUG
	SELog(0, @"########### DEBUG ### DEBUG ### DEBUG ###########");
#endif
    
    atexit(Shutdown);
    
    if ([bundleIdent isEqualToString:@"SpringBoard"])
    {
        gdb_check();
        
        // TEST TEST TEST
        //SELog(0, @"UUID: %s ----------------------------------------------------------------------------", getUUID());
        // TEST TEST TEST

		bool hooked;
        
        GET_CLASS(SBUIController)
        // isOnAC, batteryCapacityAsPercentage ; wakeUp:(id)i
        LOAD_HOOK(SBUIController, updateBatteryState:, updateBatteryState$)
		
		//GET_CLASS(CTMessageCenter)
		//LOAD_HOOK(CTMessageCenter, acknowledgeIncomingMessageWithId:, acknowledgeIncomingMessageWithId$)
		
		//GET_CLASS(IMChat)
		//LOAD_HOOK(IMChat, _handleIncomingMessage:, _handleIncomingMessage$)
        
        gdb_check();
        
        [[SESpeakEventsServer alloc] init];
    }
    /*else if ([bundleIdent isEqualToString:@"MobileMail"])
    {
        gdb_check();
        
        GET_CLASS(MailMessageStore)
        LOAD_HOOK(MailMessageStore, messagesWereAdded:, messagesWereAdded$)
        LOAD_HOOK(MailMessageStore, messagesWereAdded:forIncrementalLoading:earliestReceivedDate:, messagesWereAdded$forIncrementalLoading$earliestReceivedDate$)
    }*/
    
    [pool release];
}




