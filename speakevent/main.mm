#include <stdio.h>
#import <AppSupport/CPDistributedMessagingCenter.h>

int main(int argc, char **argv, char **envp) {
	if (argc <= 1)
	{
		printf("Usage: %s speaktext\n", argv[0]);
		return 1;
	}

	@autoreleasepool {

		NSString* instructions = [NSString stringWithUTF8String:argv[1]];

		//dispatch_async(dispatch_get_main_queue(), ^{

			CPDistributedMessagingCenter* center = [CPDistributedMessagingCenter centerNamed:@"me.k3a.SpeakEvents.center"];

			NSDictionary* dict = [NSDictionary dictionaryWithObject:instructions forKey:@"instructions"];
			[center sendMessageName:@"SpeakDirections" userInfo:dict];
		//});

	}

	return 0;
}

// vim:ft=objc
