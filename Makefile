CC      ?= xcrun -sdk iphoneos clang -arch arm64 -miphoneos-version-min=11.0
CFLAGS  ?=
LDFLAGS ?=

STRIP   ?= strip
LDID    ?= ldid
INSTALL ?= install

ALL := gssc ldrestart sbdidlaunch sbreload uicache uiopen deviceinfo uialert uishoot uinotify uisave
MAN := gssc.1 ldrestart.1 sbdidlaunch.1 sbreload.1 uicache.1 uiopen.1 deviceinfo.1 uialert.1 uishoot.1 uinotify.1 uisave.1
ALLMAC := gssc deviceinfo uialert
MANMAC := gssc.1 deviceinfo.1 uialert.1
APP_PATH ?= $(MEMO_PREFIX)/Applications

sign: $(ALL)
	$(STRIP) $(ALL)
	$(LDID) -Sent.plist ldrestart sbdidlaunch deviceinfo
	$(LDID) -Sgssc.plist gssc
	$(LDID) -Ssbreload.plist sbreload
	$(LDID) -Suicache.plist uicache
	$(LDID) -Suiopen.plist uiopen
	$(LDID) -Suishoot.plist uishoot
	$(LDID) -Suinotify.plist uinotify
	$(LDID) -Suisave.plist uisave

all: sign

gssc: gssc.m gssc.plist
	$(CC) -fobjc-arc -O3 $(CFLAGS) $< -o $@ $(LDFLAGS) -framework Foundation -lMobileGestalt

ldrestart: ldrestart.c ent.plist
	$(CC) -O3 $(CFLAGS) $< -o $@ $(LDFLAGS)

sbdidlaunch: sbdidlaunch.c ent.plist
	$(CC) -O3 $(CFLAGS) $< -o $@ $(LDFLAGS) -framework CoreFoundation

uialert: uialert.m strtonum.c ent.plist
	$(CC) -fobjc-arc -O3 $(CFLAGS) $< $(word 2,$^) -o $@ $(LDFLAGS) -framework CoreFoundation

sbreload: sbreload.m sbreload-launchd.c sbreload.plist
	$(CC) -fobjc-arc -O3 $(CFLAGS) $< $(word 2,$^) -o $@ $(LDFLAGS) -framework Foundation

uicache: uicache.m uicache.plist
	$(CC) -fobjc-arc -O3 $(CFLAGS) $< -o $@ -framework Foundation $(LDFLAGS) -framework MobileCoreServices -DAPP_PATH="@\"$(APP_PATH)\""

uiopen: uiopen.m ent.plist
	$(CC) -fobjc-arc -O3 $(CFLAGS) $< -o $@ $(LDFLAGS) -framework Foundation -framework MobileCoreServices

uishoot: uishoot.m strtonum.c uishoot.plist
	$(CC) -fobjc-arc -O3 $(CFLAGS) $< $(word 2,$^) -o $@ $(LDFLAGS) -framework ImageIO -framework Photos -framework UIKit

uinotify: uinotify.m strtonum.c uinotify.plist
	$(CC) -fobjc-arc -O3 $(CFLAGS) $< $(word 2,$^) -o $@ $(LDFLAGS) -framework UserNotifications

uisave: uisave.m uisave.plist
	$(CC) -fobjc-arc -O3 $(CFLAGS) $< -o $@ $(LDFLAGS) -framework Foundation -framework Photos -framework UIKit

deviceinfo: deviceinfo.c ecidecid.m uiduid.m serial.m locale.m cfversion.c
	$(CC) -fobjc-arc -O3 $(CFLAGS) $^ -o $@ $(LDFLAGS) -framework CoreFoundation -lMobileGestalt

install: sign $(ALL)
	$(INSTALL) -d $(DESTDIR)$(PREFIX)/bin/
	$(INSTALL) -s -m755 $(ALL) $(DESTDIR)$(PREFIX)/bin/
	ln -sf deviceinfo $(DESTDIR)$(PREFIX)/bin/cfversion
	ln -sf deviceinfo $(DESTDIR)$(PREFIX)/bin/uiduid
	ln -sf deviceinfo $(DESTDIR)$(PREFIX)/bin/ecidecid
	$(INSTALL) -d $(DESTDIR)$(PREFIX)/share/man/man1/
	$(INSTALL) -d $(DESTDIR)$(PREFIX)/share/man/zh_TW/man1/
	$(INSTALL) -d $(DESTDIR)$(PREFIX)/share/man/zh_CN/man1/
	$(INSTALL) -m644 $(patsubst %,man/%,$(MAN)) $(DESTDIR)$(PREFIX)/share/man/man1/
	$(INSTALL) -m644 $(patsubst %,man/zh_TW/%,$(MAN)) $(DESTDIR)$(PREFIX)/share/man/zh_TW/man1/
	$(INSTALL) -m644 $(patsubst %,man/zh_CN/%,$(MAN)) $(DESTDIR)$(PREFIX)/share/man/zh_CN/man1/

install-macosx: $(ALLMAC)
	$(INSTALL) -d $(DESTDIR)$(PREFIX)/bin/
	$(INSTALL) -s -m755 $(ALLMAC) $(DESTDIR)$(PREFIX)/bin/
	$(INSTALL) -d $(DESTDIR)$(PREFIX)/share/man/man1/
	$(INSTALL) -d $(DESTDIR)$(PREFIX)/share/man/zh_TW/man1/
	$(INSTALL) -d $(DESTDIR)$(PREFIX)/share/man/zh_CN/man1/
	$(INSTALL) -m644 $(patsubst %,man/%,$(MANMAC)) $(DESTDIR)$(PREFIX)/share/man/man1/
	$(INSTALL) -m644 $(patsubst %,man/zh_TW/%,$(MANMAC)) $(DESTDIR)$(PREFIX)/share/man/zh_TW/man1/
	$(INSTALL) -m644 $(patsubst %,man/zh_CN/%,$(MANMAC)) $(DESTDIR)$(PREFIX)/share/man/zh_CN/man1/

clean:
	rm -rf $(ALL) $(ALLMAC) *.dSYM

format:
	find . -type f -name '*.[cm]' -exec clang-format -i {} \;

.PHONY: all clean install install-macosx sign format
