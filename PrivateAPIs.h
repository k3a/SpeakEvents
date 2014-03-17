//
//  PrivateAPIs.h
//  SpeakEvents
//
//  Created by K3A on 2/12/12.
//  Copyright (c) 2012 K3A. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <SpringBoard/SBMediaController.h>

@interface MailMessage
- (unsigned long long)messageFlags;
- (id)subject;
- (id)mailbox;
- (id)senders; // really?
@end

@interface SBApplication
- (NSString*)displayIdentifier;
-(NSString*)bundleIdentifier;
@end

@protocol CTSenderUnk 
-(NSString*)digits;
@end

@interface CTMessagePart 
@property(copy, nonatomic) NSData *data;
@end

@interface CTMessage
-(id<CTSenderUnk>)sender;
@property(readonly) NSArray *items;
@end

@interface CTMessageCenter
- (CTMessage*)incomingMessageWithId:(unsigned int)arg1;
@end

@interface IMPerson
@end

@interface IMHandle
- (void)setIMPerson:(IMPerson*)arg1;
@property(retain, nonatomic, setter=setIMPerson:) IMPerson *person;
@property(readonly, nonatomic) NSString *lastName;
@property(readonly, nonatomic) NSString *firstName;
@end

@interface IMMessage
@property(readonly, nonatomic) NSAttributedString *text;
@property(readonly, nonatomic) long long messageID;
@property(readonly, nonatomic) BOOL finished;
@property(retain, nonatomic) IMHandle *sender;
@property(readonly, nonatomic) NSString *senderName;
@property(readonly, nonatomic) NSString *plainBody;
@end

@interface SBMediaController (K3ASEAdditions)
- (BOOL)isRingerMuted;
@end

@interface SBAssistantController
+(id)sharedInstance;
- (BOOL)isAssistantVisible;
@end

@interface UILocalNotification (K3ASEAdditions)
-(BOOL)isSystemAlert;
-(int)remainingRepeatCount;
-(BOOL)allowSnooze; 
@end

@interface AVVoiceController : NSObject
{
    void *_impl;
}

- (id)initWithHardwareConfig:(int)arg1 error:(id *)arg2;
- (void)releaseAudioSession;
- (int) hardwareConfiguration;
- (void)setHardwareConfiguration:(int)conf;
- (BOOL)prepareRecordWithSettings:(id)arg1 error:(id *)arg2;
- (BOOL)startPlaying;
- (void)stopPlaying;
- (void)beginPlaybackInterruption;
- (void)beginRecordInterruption;
- (void)endPlaybackInterruption;
@end

extern id AVSystemController_IsSomeoneRecordingAttribute;

#pragma mark - BULLETIN BOARD ------------------------------------------------------------------------------------------
// BulletinBoard

@interface BBSound : NSObject

-(NSString*)ringtoneName;
-(void)setRingtoneName:(NSString*)rn;
-(unsigned long)systemSoundID;
-(void)setSystemSoundID:(unsigned long)ssi;

@end

@interface BBBulletin : NSObject 
-(NSArray *)buttons;
-(void)setButtons:(NSArray*)buttons;
-(NSString*)bulletinID;
-(NSString*)recordID;
-(NSString*)topic;
-(NSString*)message;
-(NSTimeZone*)timeZone;
-(NSString*)subtitle;
-(NSString*)section;
-(void)setSection:(NSString*)sec;
-(NSDictionary*)context;
-(void)setContext:(NSDictionary*)x;
-(NSString*)title;
-(NSDate*)date;
-(NSDate*)lastInterruptDate;
-(BBSound*)sound;
-(id)content;
-(id)attachments;
-(void)setSound:(BBSound*)sound;
-(id)modalAlertContent;
-(NSMutableDictionary*)actions;
-(NSString*)publisherBulletinID;
@end

@class BBObserver;
@protocol BBObserverDelegate
- (void)observer:(BBObserver*)observer addBulletin:(BBBulletin*)bulletin forFeed:(unsigned int)feed;
- (void)observer:(BBObserver*)observer modifyBulletin:(BBBulletin*)bulletin;
- (void)observer:(BBObserver*)observer removeBulletin:(BBBulletin*)bulletin;
@end

@interface BBObserver : NSObject
{
    id _serverProxy;
    struct {
        unsigned int addBulletin:1;
        unsigned int modifyBulletin:1;
        unsigned int removeBulletin:1;
        unsigned int sectionOrderRule:1;
        unsigned int sectionOrder:1;
        unsigned int sectionInfo:1;
        unsigned int sectionParameters:1;
        unsigned int fetchImage:1;
        unsigned int fetchSize:1;
        unsigned int sizeConstraints:1;
        unsigned int multiSizeConstraints:1;
        unsigned int imageForThumbData:1;
        unsigned int sizeForThumbSize:1;
        unsigned int purgeReferences:1;
    } _delegateFlags;
    NSObject *_bulletinLifeAssertions;
    NSMutableDictionary *_sectionParameters;
    NSMutableDictionary *_attachmentInfoByBulletinID;
    unsigned int _numberOfBulletinFetchesUnderway;
    NSMutableSet *_sectionIDsWithUpdatesUnderway;
    NSMutableDictionary *_bulletinUpdateQueuesBySectionID;
    id <BBObserverDelegate> _delegate;
    unsigned int _observerFeed;
}

+ (void)initialize;
- (id)init;
- (void)dealloc;
- (id)proxy:(id)arg1 detailedSignatureForSelector:(SEL)arg2;
@property(nonatomic) unsigned int observerFeed; // @synthesize observerFeed=_observerFeed;
- (void)assertionExpired:(id)arg1 transactionID:(unsigned int)arg2;
- (struct CGSize)attachmentSizeForKey:(id)arg1 forBulletinID:(id)arg2;
- (id)attachmentImageForKey:(id)arg1 forBulletinID:(id)arg2;
- (id)parametersForSectionID:(id)arg1;
- (void)clearSection:(id)arg1;
- (void)getAttachmentImageForBulletin:(id)arg1 withCompletion:(id)arg2;
- (void)getRecentUnacknowledgedBulletinsForFeeds:(unsigned int)arg1 withCompletion:(id)arg2;
- (void)getSortDescriptorsForSectionID:(id)arg1 withCompletion:(id)arg2;
- (void)requestListBulletinsForSectionID:(id)arg1;
- (void)getSectionInfoWithCompletion:(id)arg1;
- (void)getSectionOrderRuleWithCompletion:(id)arg1;
- (void)_performOrEnqueueBulletinUpdate:(id)arg1 forSection:(void)arg2;
- (void)_preFetchAttachmentInfoIfNecessaryForBulletin:(id)arg1 withCompletion:(id)arg2;
- (void)_noteCompletedBulletinUpdateForSection:(id)arg1;
- (void)_dequeueBulletinUpdateIfPossibleForSection:(id)arg1;
- (void)updateSectionParameters:(id)arg1 forSectionID:(id)arg2;
- (void)updateSectionInfo:(id)arg1;
- (void)updateSectionOrder:(id)arg1;
- (void)updateSectionOrderRule:(id)arg1;
- (void)updateBulletin:(id)arg1 forFeeds:(unsigned int)arg2;
- (id)_lifeAssertionForBulletinID:(id)arg1;
- (void)_getAttachmentSizesIfPossibleForBulletins:(id)arg1 withCompletion:(id)arg2;
- (void)_getAttachmentImagesIfPossibleForBulletins:(id)arg1 withCompletion:(id)arg2;
- (void)_getAttachmentSizesIfPossibleForBulletin:(id)arg1 withCompletion:(id)arg2;
- (void)_noteAttachmentSizesFetchedForBulletinID:(id)arg1;
- (void)_setAttachmentSize:(struct CGSize)arg1 forKey:(id)arg2 forBulletinID:(id)arg3;
- (BOOL)_attachmentSizesFetchedForBulletinID:(id)arg1;
- (void)_noteAttachmentImagesFetchedForBulletinID:(id)arg1;
- (void)_fetchAndProcessImageForBulletinID:(id)arg1 withKey:(id)arg2 constraints:(id)arg3 attachmentType:(int)arg4 completion:(id)arg5;
- (id)_reasonableConstraintsForAttachmentType:(int)arg1;
- (BOOL)_attachmentImagesFetchedForBulletinID:(id)arg1;
- (void)_setAttachmentImage:(id)arg1 forKey:(id)arg2 forBulletinID:(id)arg3;
- (id)_attachmentInfoForBulletinID:(id)arg1 create:(BOOL)arg2;
- (void)_getParametersIfNecessaryForSectionID:(id)arg1 withCompletion:(id)arg2;
- (void)_getAttachmentImagesIfPossibleForBulletin:(id)arg1 withCompletion:(id)arg2;
- (void)_performBulletinFetch:(id)arg1;
- (void)_getParametersIfNecessaryForSectionIDs:(id)arg1 withCompletion:(id)arg2;
- (void)_preFetchAttachmentInfoIfNecessaryForBulletins:(id)arg1 withCompletion:(id)arg2;
- (void)_noteCompletedBulletinFetch;
- (void)_registerBulletin:(id)arg1 withTransactionID:(unsigned int)arg2;
- (void)sendResponse:(id)arg1;
- (void)invalidate;
- (void)setDelegate:(id<BBObserverDelegate>)d; // @synthesize delegate=_delegate;
- (id<BBObserverDelegate>)delegate;

@end













