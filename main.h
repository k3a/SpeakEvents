//
//  Created by K3A on 5/20/12.
//  Copyright (c) 2012 K3A. All rights reserved.
//

#pragma once

#include "log.h"

#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

// Apple PT_DENY_ATTACH addition to disallow gdb attachment
#import <dlfcn.h>
#import <sys/types.h>

#include <VoiceServices.h>
#import "PrivateAPIs.h"

typedef int (*ptrace_ptr_t)(int _request, pid_t _pid, caddr_t _addr, int _data);
#if !defined(PT_DENY_ATTACH)
# define PT_DENY_ATTACH 31
#endif  // !defined(PT_DENY_ATTACH)

#define SE_PREF_FILE "/var/mobile/Library/Preferences/me.k3a.SpeakEvents.plist"

// #define DEBUG




typedef bool (*BoolFn)();
typedef bool (*VoidBoolFn)(bool b);

@class SESpeakableApp;
@interface SESpeakableMessage : NSObject {
@private
    SESpeakableApp* _app;
}
-(id)initWithApp:(SESpeakableApp*)app;
-(SESpeakableApp*)app;
@property (nonatomic, copy) NSString* messageIdentifier;
@property (nonatomic, copy) NSString* firstPart;
@property (nonatomic, copy) NSString* secondPart; // can be nil !!
@property (nonatomic, copy) NSString* thirdPart; // can be nil !!
@property (nonatomic, assign) int numPartsRead;
@end

@interface SESpeakableApp : NSObject {
@private
    NSMutableArray* _msgs;
    NSString* _appIdent;
}
+(id)speakableAppWithIdentifier:(NSString*)ident;

-(id)initWithIdentifier:(NSString*)ident;
-(NSString*)appIdentifier;
-(void)pushMessage:(SESpeakableMessage*)msg;
-(SESpeakableMessage*)popMessage; // returns nil if no more messages
-(SESpeakableMessage*)findMessage:(NSString*)messageIdentifier; // returns autoreleased instance or nil
-(void)removeAllMessages;
-(unsigned)numOfRemainingMessages;
@end



@interface SESpeakEventsServer : NSObject <BBObserverDelegate,VSSpeechSynthesizerDelegate> {
    VSSpeechSynthesizer* synth;
    BBObserver* bbObserver;
    NSDate* m_lastFullChargeDate;
    AVVoiceController* m_voiceCtrl;
    
    BOOL m_lowBattery10Warned;
    BOOL m_lowBattery5Warned;
    
    BOOL m_firstBatteryEvent;
    int m_ExternalConnectedPrevState;
    float m_percentWhenExternalConencted;
    float m_lastPercent;
    
    NSMutableDictionary* m_settings;
    NSDictionary* m_langDict;
	NSDictionary* m_smileys;
    NSString* m_defaultLang;
    
    NSSet* m_speakApps;
    NSMutableArray* m_speakObjects; // array of SESpeakableApp objects
    SESpeakableMessage* m_currentlySpeakingObject;
    SESpeakableMessage* m_lastSpokenObject;
    time_t m_initTimestamp;
    BOOL m_afterSafeTime; // safe time during respring 10 seconds
    NSTimer* m_delayTimer;
    NSTimer* m_cleaningTimer; // timer for workaround
    NSTimer* m_repeatTimer; // timer to avoid speaking the same
    unsigned long m_duplicateHash; 
    
    BOOL m_bluetoothWasUsed;
    BOOL m_timerThreadRunning;
}

+(SESpeakEventsServer*)sharedInstance;

-(BOOL)loadSettings;
-(BOOL)saveSettings;
-(void)enableSpeakEvents;
-(void)disableSpeakEvents;
-(void)toggleSpeakEvents;
-(BOOL)bluetoothHandsFree;

-(NSString*)localizedString:(NSString*)str;
-(NSString*)localizedString:(NSString*)str forLang:(NSString*)lang;
-(BOOL)isAllowedToSpeakNow;
-(void)setupCleaningTimer;
-(void)stopSpeaking; // immediately stops speaking
-(void)speakTime; // without checking prefs/allowance
-(void)speakTimeWithMinutes; // without checking prefs/allowance
-(void)speakLastMessageAgain; // without checking prefs/allowance

// high priority speaking without localization, you should localize sting before speaking it with this
-(void)speakHiPriority:(NSString*)text;
-(void)speakHiPriority:(NSString*)text inLang:(NSString*)lang;

// low priority speaking with localization support
// (imessage/sms/mail are high priority and must not use these methods)
-(void)speak:(NSString*)text;
-(void)speakLang:(NSString*)lang ident:(NSString*)text;

-(void)batteryStateChanged:(NSDictionary*)dict;
-(void)handleIncomingCall:(NSString*)caller;
-(void)handleSystemNotification:(UILocalNotification*)notif;
-(void)handleLaunchSucceeded:(NSString*)ident;
-(BOOL)shouldSuppressNewMailSound;
-(BOOL)shouldSuppressNewMessageSound;

@end



#import <malloc/malloc.h>
#import <objc/runtime.h>

static sigjmp_buf sigjmp_env;

inline void PointerReadFailedHandler(int signum)
{
    siglongjmp (sigjmp_env, 1);
}

inline BOOL IsPointerAnObject(const void *testPointer)
{
    BOOL allocatedLargeEnough = NO;
    if (!testPointer) return NO;
    
    // Set up SIGSEGV and SIGBUS handlers
    struct sigaction new_segv_action, old_segv_action;
    struct sigaction new_bus_action, old_bus_action;
    new_segv_action.sa_handler = PointerReadFailedHandler;
    new_bus_action.sa_handler = PointerReadFailedHandler;
    sigemptyset(&new_segv_action.sa_mask);
    sigemptyset(&new_bus_action.sa_mask);
    new_segv_action.sa_flags = 0;
    new_bus_action.sa_flags = 0;
    sigaction (SIGSEGV, &new_segv_action, &old_segv_action);
    sigaction (SIGBUS, &new_bus_action, &old_bus_action);
    
    // The signal handler will return us to here if a signal is raised
    if (sigsetjmp(sigjmp_env, 1))
    {
        sigaction (SIGSEGV, &old_segv_action, NULL);
        sigaction (SIGBUS, &old_bus_action, NULL);
        return NO;
    }
    
    Class testPointerClass = *((Class *)testPointer);
    
    // Get the list of classes and look for testPointerClass
    BOOL isClass = NO;
    NSInteger numClasses = objc_getClassList(NULL, 0);
    Class *classesList = (Class *)malloc(sizeof(Class) * numClasses);
    numClasses = objc_getClassList(classesList, numClasses);
    for (int i = 0; i < numClasses; i++)
    {
        if (classesList[i] == testPointerClass)
        {
            isClass = YES;
            break;
        }
    }
    free(classesList);
    
    // We're done with the signal handlers (install the previous ones)
    sigaction (SIGSEGV, &old_segv_action, NULL);
    sigaction (SIGBUS, &old_bus_action, NULL);
    
    // Pointer does not point to a valid isa pointer
    if (!isClass)
    {
        return NO;
    }
    
    // Check the allocation size
    size_t allocated_size = malloc_size(testPointer);
    size_t instance_size = class_getInstanceSize(testPointerClass);
    if (allocated_size > instance_size)
    {
        allocatedLargeEnough = YES;
    } 
    
    return allocatedLargeEnough;
}

inline float normalizedVol(float vol, NSString* lang)
{
    const char* l = [lang UTF8String];
    if (!strcmp(l, "pt-BR"))
        return vol*0.82f*1.1f;
    else if (!strcmp(l, "th-TH"))
        return vol*0.70f*1.1f;
    else if (!strcmp(l, "sk-SK"))
        return vol*0.79f*1.1f;
    else if (!strcmp(l, "fr-CA"))
        return vol*0.79f*1.1f;
    else if (!strcmp(l, "ro-RO"))
        return vol*0.73f*1.1f;
    else if (!strcmp(l, "no-NO"))
        return vol*0.44f*1.1f;
    else if (!strcmp(l, "fi-FI"))
        return vol*0.68f*1.1f;
    else if (!strcmp(l, "pl-PL"))
        return vol*0.90f*1.1f;
    else if (!strcmp(l, "tr-TR"))
        return vol*0.57f*1.1f;
    else if (!strcmp(l, "de-DE"))
        return vol*0.38f*1.1f;
    else if (!strcmp(l, "nl-NL"))
        return vol*0.57f*1.1f;
    else if (!strcmp(l, "id-ID"))
        return vol*0.55f*1.1f;
    else if (!strcmp(l, "zh-TW"))
        return vol*0.50f*1.1f;
    else if (!strcmp(l, "zh-HK"))
        return vol*0.58f*1.1f;
    else if (!strcmp(l, "fr-FR"))
        return vol*0.53f*1.1f;
    else if (!strcmp(l, "ru-RU"))
        return vol*0.66f*1.1f;
    else if (!strcmp(l, "es-MX"))
        return vol*0.81f*1.1f;
    else if (!strcmp(l, "sv-SE"))
        return vol*0.61f*1.1f;
    else if (!strcmp(l, "hu-HU"))
        return vol*0.59f*1.1f;
    else if (!strcmp(l, "pt-PT"))
        return vol*0.56f*1.1f;
    else if (!strcmp(l, "es-ES"))
        return vol*0.50f*1.1f;
    else if (!strcmp(l, "zh-CN"))
        return vol*0.50f*1.1f;
    else if (!strcmp(l, "nl-BE"))
        return vol*0.58f*1.1f;
    else if (!strcmp(l, "en-GB"))
        return vol*0.49f*1.1f;
    else if (!strcmp(l, "ar-SA"))
        return vol*0.74f*1.1f;
    else if (!strcmp(l, "ko-KR"))
        return vol*0.74f*1.1f;
    else if (!strcmp(l, "cs-CZ"))
        return vol*0.60f*1.1f;
    else if (!strcmp(l, "en-ZA"))
        return vol*0.64f*1.1f;
    else if (!strcmp(l, "en-AU"))
        return vol*0.57f*1.1f;
    else if (!strcmp(l, "da-DK"))
        return vol*0.90f*1.1f;
    else if (!strcmp(l, "en-US"))
        return vol*0.46f*1.1f;
    else if (!strcmp(l, "en-IE"))
        return vol*0.50f*1.1f;
    else if (!strcmp(l, "hi-IN"))
        return vol*0.50f*1.1f;
    else if (!strcmp(l, "el-GR"))
        return vol*0.74f*1.1f;
    else if (!strcmp(l, "ja-JP"))
        return vol*0.74f*1.1f;
    else
        return vol;
}



#pragma mark - K3A's MS HELPER MACROS ------------------------------------------

#define CALL_ORIG(args...) \
return __orig_fn(self, sel, ## args)

#define ORIG(args...) \
__orig_fn(self, sel, ## args)


#define GET_CLASS(class) \
Class $ ## class = objc_getClass(#class); \
if (! $ ## class ) NSLog(@"SE: WARN: Failed to get class %s!", #class);


#define GET_METACLASS(class) \
Class $ ## class = objc_getMetaClass(#class); \
if (! $ ## class ) NSLog(@"SE: WARN: Failed to get metaclass %s!", #class);


#define HOOK(className, name, type, args...) \
@class className; \
static type (*_ ## className ## $ ## name)(className *self, SEL sel, ## args) = NULL; \
static type $ ## className ## $ ## name(className *self, SEL sel, ## args) { \
type (*__orig_fn)(className *self, SEL sel, ## args) = _ ## className ## $ ## name ; __orig_fn=__orig_fn;


#define END }

#define LOAD_HOOK(class, sel, imp) \
hooked = true; \
if ($ ## class) { MSHookMessage($ ## class, @selector(sel), MSHake(class ## $ ## imp)); \
if (! _ ## class ## $ ## imp ) { hooked = false; NSLog(@"SE: WARN: " #class "-" #sel " not found!" ); } }

#define LOAD_HOOK_SILENT(class, sel, imp) \
hooked = true; \
if ($ ## class) { MSHookMessage($ ## class, @selector(sel), MSHake(class ## $ ## imp)); \
if (! _ ## class ## $ ## imp ) { hooked = false; } }





