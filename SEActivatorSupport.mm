//
//  SEActivatorSupport.m
//  SpeakEvents
//
//  Created by K3A on 3/4/12.
//  Copyright (c) 2012 K3A. All rights reserved.
//

#import "SEActivatorSupport.h"
#include "main.h"

#import <libactivator/libactivator.h> 

@interface SEActivatorRepeat : NSObject<LAListener> { }
@end
@implementation SEActivatorRepeat
- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
	[event setHandled:YES];
    
    // event activation
    [[SESpeakEventsServer sharedInstance] speakLastMessageAgain];
}
- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event
{
	// event cancelation
}

+ (void)load
{
    [[LAActivator sharedInstance] registerListener:[self new] forName:@"me.k3a.se.repeat"];
}
@end


@interface SEActivatorStop : NSObject<LAListener> { }
@end 
@implementation SEActivatorStop
- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
	[event setHandled:YES];
    
    // event activation
    [[SESpeakEventsServer sharedInstance] stopSpeaking];
}
- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event
{
	// event cancelation
}

+ (void)load
{
    [[LAActivator sharedInstance] registerListener:[self new] forName:@"me.k3a.se.stop"];
}
@end

@interface SEActivatorTime : NSObject<LAListener> { }
@end
@implementation SEActivatorTime
- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
	[event setHandled:YES];
    
    // event activation
    [[SESpeakEventsServer sharedInstance] speakTimeWithMinutes];
}
- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event
{
	// event cancelation
}

+ (void)load
{
    [[LAActivator sharedInstance] registerListener:[self new] forName:@"me.k3a.se.time"];
}
@end

@interface SEActivatorEnable : NSObject<LAListener> { }
@end
@implementation SEActivatorEnable
- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
	[event setHandled:YES];
    
    // event activation
    [[SESpeakEventsServer sharedInstance] enableSpeakEvents];
}
- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event
{
	// event cancelation
}

+ (void)load
{
    [[LAActivator sharedInstance] registerListener:[self new] forName:@"me.k3a.se.enable"];
}
@end

@interface SEActivatorDisable : NSObject<LAListener> { }
@end
@implementation SEActivatorDisable
- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
	[event setHandled:YES];
    
    // event activation
    [[SESpeakEventsServer sharedInstance] disableSpeakEvents];
}
- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event
{
	// event cancelation
}

+ (void)load
{
    [[LAActivator sharedInstance] registerListener:[self new] forName:@"me.k3a.se.disable"];
}
@end

@interface SEActivatorToggle : NSObject<LAListener> { }
@end
@implementation SEActivatorToggle
- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
	[event setHandled:YES];
    
    // event activation
    [[SESpeakEventsServer sharedInstance] toggleSpeakEvents];
}
- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event
{
	// event cancelation
}

+ (void)load
{
    [[LAActivator sharedInstance] registerListener:[self new] forName:@"me.k3a.se.toggle"];
}
@end




@implementation SEActivatorSupport
-(id)init 
{
    if ( (self = [super init]) )
    {
        // register activator events
        [SEActivatorRepeat load];
        [SEActivatorStop load];
        [SEActivatorTime load];
        [SEActivatorEnable load];
        [SEActivatorDisable load];
        [SEActivatorToggle load];
    }
    return self;
}
@end
