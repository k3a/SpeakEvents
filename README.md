SpeakEvents
===========

iOS tweak for speaking notifications and other events using speech synthesiser.

Official website: http://se.k3a.me/ <br/>
Developer & User Forums: http://forum.k3a.me

In order to complile it, set the correct theos symlink to your theos installation and run 'make package' command.

There is also 'make test' makefile rule but it won't work without modifying theos. I used it to automate package creation, installing the packge on the device and respringing the device. This is not needed though as you can install the package standard theos way or via 'dpkg -i path to deb' on the device.

If you have trouble compiling it, you can contact me at 'se (at) k3a . me' and I will try to help you and/or update this readme.

For some reason I was unable to compile fat armv7/arm64 preference bundle.
When loading such a bundle in the Preferences, this was shown in the syslog:
Preferences[1514]: Error loading /Library/PreferenceBundles/SEPrefs.bundle/SEPrefs:  dlopen(/Library/PreferenceBundles/SEPrefs.bundle/SEPrefs, 265): bad rebase opcode 222 in /Library/PreferenceBundles/SEPrefs.bundle/SEPrefs
