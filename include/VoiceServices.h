#import  <Foundation/Foundation.h>

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

//ios7
- (id)startSpeakingString:(id)string request:(id *)arg2 error:(id *)arg3;
- (id)startSpeakingString:(id)arg1 withLanguageCode:(id)arg2 request:(id *)arg2 error:(id *)arg3;
- (id)stopSpeakingAtNextBoundary:(int)fp8 error:(id *)arg2;

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