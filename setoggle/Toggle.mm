#define PREF_FILE "/var/mobile/Library/Preferences/me.k3a.SpeakEvents.plist"

// Required
extern "C" BOOL isCapable() {
	return YES;
}

// Required
extern "C" BOOL isEnabled() {
	NSDictionary* settings = [NSDictionary dictionaryWithContentsOfFile:@PREF_FILE];
	NSNumber* enabled = [settings objectForKey:@"enabled"];

	return !enabled || [enabled boolValue];
}

// Required
extern "C" void setState(BOOL enabled) {
	NSMutableDictionary* settings = [NSMutableDictionary dictionaryWithContentsOfFile:@PREF_FILE];
	if (!settings)
	{
		NSLog(@"SE: Toggle: Failed to load settings!");
		return;
	}

	[settings setObject:[NSNumber numberWithBool:enabled] forKey:@"enabled"];

	if (![settings writeToFile:@PREF_FILE atomically:YES])
	{
        NSLog(@"SE: Toggle: Failed to save settings");
		return;
	}

	// inform the software
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("me.k3a.SpeakEvents/reloadPrefs"), NULL, NULL, false);
}

// Required
// How long the toggle takes to toggle, in seconds.
extern "C" float getDelayTime() {
	return 0.1f;
}

// vim:ft=objc
