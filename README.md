SpeakEvents
===========

iOS tweak for speaking notifications and other events using speech synthesiser.

Official website: http://se.k3a.me/

In order to complile it, set the correct theos symlink to your theos installation and run 'make package' command.

There is also 'make test' makefile rule but it won't work without modifying theos. I used it to automate package creation, installing the packge on the device and respringing the device. This is not needed though as you can install the package standard theos way or via 'dpkg -i path to deb' on the device.

If you have trouble compiling it, you can contact me at 'se (at) k3a . me' and I will try to help you and/or update this readme.
