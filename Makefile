CC      ?= xcrun -sdk iphoneos clang -arch arm64 -miphoneos-version-min=11.0
CFLAGS  ?=
LDFLAGS ?=

STRIP   ?= strip
LDID    ?= ldid
INSTALL ?= install

ALL := gssc ldrestart sbdidlaunch sbreload uicache uiopen deviceinfo uialert uishoot
MAN := gssc.1 ldrestart.1 sbdidlaunch.1 sbreload.1 uicache.1 uiopen.1 deviceinfo.1 uialert.1 uishoot.1
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

all: sign

gssc: gssc.m gssc.plist
	$(CC) -fobjc-arc -O3 $(CFLAGS) gssc.m -o gssc $(LDFLAGS) -framework Foundation -lMobileGestalt
	
ldrestart: ldrestart.c ent.plist
	$(CC) -O3 $(CFLAGS) ldrestart.c -o ldrestart $(LDFLAGS)

sbdidlaunch: sbdidlaunch.c ent.plist
	$(CC) -O3 $(CFLAGS) sbdidlaunch.c -o sbdidlaunch $(LDFLAGS) -framework CoreFoundation

uialert: uialert.m strtonum.c ent.plist
	$(CC) -fobjc-arc -O3 $(CFLAGS) uialert.m strtonum.c -o uialert $(LDFLAGS) -framework CoreFoundation

sbreload: sbreload.m sbreload-launchd.c sbreload.plist
	$(CC) -fobjc-arc -O3 $(CFLAGS) sbreload.m sbreload-launchd.c -o sbreload $(LDFLAGS) -framework Foundation

uicache: uicache.m uicache.plist
	$(CC) -fobjc-arc -O3 $(CFLAGS) uicache.m -o uicache -framework Foundation $(LDFLAGS) -framework MobileCoreServices -DAPP_PATH="@\"$(APP_PATH)\""

uiopen: uiopen.m ent.plist
	$(CC) -fobjc-arc -O3 $(CFLAGS) uiopen.m -o uiopen $(LDFLAGS) -framework Foundation -framework MobileCoreServices

uishoot: uishoot.m strtonum.c uishoot.plist
	$(CC) -fobjc-arc -O3 $(CFLAGS) uishoot.m strtonum.c -o uishoot $(LDFLAGS) -framework ImageIO -framework Photos -framework UIKit

deviceinfo: deviceinfo.c ecidecid.m uiduid.m serial.m locale.m cfversion.c
	$(CC) -fobjc-arc -O3 $(CFLAGS) $^ -o $@ $(LDFLAGS) -framework CoreFoundation -lMobileGestalt

install: sign $(ALL) $(MAN)
	$(INSTALL) -d $(DESTDIR)$(PREFIX)/bin/
	$(INSTALL) -s -m755 $(ALL) $(DESTDIR)$(PREFIX)/bin/
	ln -sf deviceinfo $(DESTDIR)$(PREFIX)/bin/cfversion
	ln -sf deviceinfo $(DESTDIR)$(PREFIX)/bin/uiduid
	ln -sf deviceinfo $(DESTDIR)$(PREFIX)/bin/ecidecid
	$(INSTALL) -d $(DESTDIR)$(PREFIX)/share/man/man1/
	$(INSTALL) -m644 $(MAN) $(DESTDIR)$(PREFIX)/share/man/man1/

install-macosx: $(ALLMAC) $(MANMAC)
	$(INSTALL) -d $(DESTDIR)$(PREFIX)/bin/
	$(INSTALL) -s -m755 $(ALLMAC) $(DESTDIR)$(PREFIX)/bin/
	$(INSTALL) -d $(DESTDIR)$(PREFIX)/share/man/man1/
	$(INSTALL) -m644 $(MANMAC) $(DESTDIR)$(PREFIX)/share/man/man1/

clean:
	rm -rf gssc ldrestart sbdidlaunch sbreload uicache uiopen deviceinfo uialert *.dSYM
