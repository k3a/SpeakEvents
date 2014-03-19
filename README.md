SpeakEvents
===========

iOS tweak for speaking notifications and other events using speech synthesiser.

Official website: http://se.k3a.me/ <br/>
Developer & User Forums: http://forum.k3a.me

You may need these files (updated theos and include files): <br/>
 - https://github.com/rpetrich/iphoneheaders
 - https://github.com/rpetrich/theos  

In order to complile it, install Xcode and set the correct theos symlink to your theos installation (or put theos to /theos and keep my simlink) and run 'make package' command.

There is also 'make test' makefile rule but it won't work without modifying theos. I used it to automate package creation, installing the packge on the device and respringing the device. This is not needed though as you can install the package standard theos way or via 'dpkg -i path to deb' on the device.

If you have trouble compiling it, you can contact me and others at http://forum.k3a.me or simply create a github issue. I will try to help you and/or update this readme.
