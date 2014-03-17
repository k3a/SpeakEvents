
@class VSSpeechSynthesizer;

@protocol VSSpeechSynthesizerDelegate <NSObject>
- (void)speechSynthesizer:(VSSpeechSynthesizer*)synth didFinishSpeaking:(BOOL)finish withError:(NSError*)err;
- (void)speechSynthesizerDidStartSpeaking:(VSSpeechSynthesizer*)synth;
@end


@interface VSSpeechSynthesizer : NSObject 
{ 
} 
+ (id)availableVoices;
+ (id)availableVoicesForLanguageCode:(id)fp8;
+ (id)availableLanguageCodes; 
+ (BOOL)isSystemSpeaking; 
- (void)setDelegate:(id <VSSpeechSynthesizerDelegate>)fp8;
- (id)startSpeakingString:(id)string; 
- (id)startSpeakingString:(id)arg1 withLanguageCode:(id)arg2;
- (id)startSpeakingString:(id)string toURL:(id)url; 
- (id)startSpeakingString:(id)string toURL:(id)url withLanguageCode:(id)code; 
- (float)rate;             // default rate: 1 
- (id)setRate:(float)rate; 
- (float)pitch;           // default pitch: 0.5
- (id)setPitch:(float)pitch; 
- (void)setVoice:(id)fp8;
- (id)voice;
- (float)volume;       // default volume: 0.8
- (id)setVolume:(float)volume; 

- (id)pauseSpeakingAtNextBoundary:(int)fp8;
- (id)pauseSpeakingAtNextBoundary:(int)fp8 synchronously:(BOOL)fp12;
- (id)stopSpeakingAtNextBoundary:(int)fp8;
- (id)stopSpeakingAtNextBoundary:(int)fp8 synchronously:(BOOL)fp12;
- (id)continueSpeaking;
- (void)setMaintainPersistentConnection:(BOOL)fp8;

@end





#import <AppSupport/CPDistributedMessagingCenter.h>
#import <MapKit/MapKit.h>

@protocol SEMKRouteStep <NSObject>
-(NSString*)instructions;
-(CLLocationCoordinate2D)coordinate;
@end

@protocol SEDirectionsManager
-(id<SEMKRouteStep>)step;
@end

%hook MapViewControllerPhone

#define SE_PREF_FILE "/var/mobile/Library/Preferences/me.k3a.SpeakEvents.plist"

BOOL shouldSpeakLocation()
{
	NSDictionary* settings = [NSDictionary dictionaryWithContentsOfFile:@SE_PREF_FILE];
	return [[settings objectForKey:@"speakDirections"] boolValue];
}

BOOL shouldAutoForward()
{
	NSDictionary* settings = [NSDictionary dictionaryWithContentsOfFile:@SE_PREF_FILE];
    return [[settings objectForKey:@"autoForward"] boolValue];
}

-(void)directionsManagerDidChangeStep:(id<SEDirectionsManager>)mgr
{
	if ( shouldSpeakLocation() )
	{

		NSString* instructions = [[mgr step] instructions];
		if (instructions)
		{
			//NSLog(@"STEP: %@", instructions);
			dispatch_async(dispatch_get_main_queue(), ^{

				CPDistributedMessagingCenter* center = [CPDistributedMessagingCenter centerNamed:@"me.k3a.SpeakEvents.center"];
	
				NSDictionary* dict = [NSDictionary dictionaryWithObject:instructions forKey:@"instructions"];
				[center sendMessageName:@"SpeakDirections" userInfo:dict];
			});
		}
	}

	%orig;
}

- (void)mapView:(id)mapView didUpdateUserLocation:(MKUserLocation*)location
{
	if ( shouldAutoForward() )
	{
		static Class DirectionsManager_ = objc_getClass("DirectionsManager");

		CLLocation* loc = [location location];
		CLLocationCoordinate2D userCoord = [loc coordinate];

		//NSLog(@"USER LOC: %f %f", userCoord.latitude, userCoord.longitude);

		id<SEDirectionsManager> mgr = (id<SEDirectionsManager>)[DirectionsManager_ sharedDirectionsManager];
		id<SEMKRouteStep> currStep = [mgr step];
		if (currStep) 
		{
			CLLocationCoordinate2D coor = [currStep coordinate];
			float dist = sqrtf( (userCoord.latitude-coor.latitude)*(userCoord.latitude-coor.latitude)  
							 +  (userCoord.longitude-coor.longitude)*(userCoord.longitude-coor.longitude) );

			//NSLog(@"CURR STEP: %f %f dist %f", coor.latitude, coor.longitude, dist);

			if (dist < 0.00025f)
			{
				[mgr stepForward];
			}
		}
	}

	%orig;
}

%end








static void FirstRun(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	VSSpeechSynthesizer* synth = [[VSSpeechSynthesizer alloc] init];
	[synth setVoice:@"Samantha"];
	[synth startSpeakingString:@"SpeakEvents is now installed. Please go to Settings to download or buy a full license." withLanguageCode:@"en-US"];
}

__attribute__((constructor)) void Init()
{
//	NSLog(@"SE: BEFORE");
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), nil, FirstRun, CFSTR("me.k3a.SpeakEvents/firstRun"), NULL, CFNotificationSuspensionBehaviorCoalesce);
//	NSLog(@"SE: AFTER");
}


