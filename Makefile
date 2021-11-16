CC      ?= xcrun -sdk iphoneos clang -arch arm64 -miphoneos-version-min=11.0
CFLAGS  ?=
LDFLAGS ?=

STRIP   ?= strip
LDID    ?= ldid

ifneq (,$(findstring bridgeos,$(CC) $(CFLAGS)))
ALL := ldrestart mgask
else ifneq (,$(findstring iphoneos,$(CC) $(CFLAGS)))
ALL := ldrestart sbdidlaunch sbreload uicache uiopen deviceinfo uialert uishoot uinotify uisave lsrebuild uidisplay mgask
else ifneq (,$(findstring appletvos,$(CC) $(CFLAGS)))
ALL := ldrestart sbreload uicache uiopen deviceinfo uialert uishoot lsrebuild mgask
else
ALL := deviceinfo uialert mgask
endif
MAN := $(patsubst %,%.1,$(ALL))

MANLANGS := zh_CN zh_TW

ifeq ($(NLS),1)
ifneq ($(LOCALEDIR),)
CFLAGS  += -DLOCALEDIR=\"$(LOCALEDIR)\"
endif
LDFLAGS += -lintl
else
CFLAGS  += -DNO_NLS
endif

CFLAGS  += -Wno-unguarded-availability-new

APP_PATH ?= $(MEMO_PREFIX)/Applications

all: sign po

sign: $(ALL)
	$(STRIP) $(ALL)
ifeq (,$(findstring macosx,$(CC) $(CFLAGS)))
	for tool in $(ALL); do \
		if [ -f $$tool.plist ]; then \
			$(LDID) -S$${tool}.plist $$tool; \
		else \
			$(LDID) -Sent.plist $$tool; \
		fi; \
	done
endif

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

lsrebuild: lsrebuild.m lsrebuild.plist
	$(CC) -fobjc-arc -O3 $(CFLAGS) $< -o $@ $(LDFLAGS) -framework Foundation -framework MobileCoreServices

uidisplay: uidisplay.m strtonum.c uidisplay.plist
	$(CC) -fobjc-arc -O3 $(CFLAGS) $< $(word 2,$^) -o $@ $(LDFLAGS) -framework Foundation -lAccessibility -framework UIKit -framework CoreGraphics -framework IOKit

deviceinfo: info/deviceinfo.c info/ecid.m info/uid.m info/serial.m info/locale.m info/cfversion.c
	$(CC) -fobjc-arc -O3 $(CFLAGS) $^ -o $@ $(LDFLAGS) -framework CoreFoundation -lMobileGestalt

mgask: mgask.m mgask.plist
	$(CC) -fobjc-arc -O3 $(CFLAGS) $< -o $@ $(LDFLAGS) -framework CoreFoundation -framework Foundation -lMobileGestalt

install: $(ALL) sign install-po
	install -d $(DESTDIR)$(PREFIX)/bin/
	install -m755 $(ALL) $(DESTDIR)$(PREFIX)/bin/
	ln -sf deviceinfo $(DESTDIR)$(PREFIX)/bin/cfversion
	ln -sf deviceinfo $(DESTDIR)$(PREFIX)/bin/uiduid
	ln -sf deviceinfo $(DESTDIR)$(PREFIX)/bin/ecidecid
	ln -sf mgask $(DESTDIR)$(PREFIX)/bin/gssc
	install -d $(DESTDIR)$(PREFIX)/share/man/man1/
	install -m644 $(patsubst %,man/%,$(MAN)) $(DESTDIR)$(PREFIX)/share/man/man1/
	for lang in $(MANLANGS); do \
		install -d $(DESTDIR)$(PREFIX)/share/man/$$lang/man1/; \
		install -m644 $(patsubst %,man/$$lang/%,$(MAN)) $(DESTDIR)$(PREFIX)/share/man/$$lang/man1/ || true; \
	done

po:
ifeq ($(NLS),1)
	$(MAKE) -C po
endif

install-po: po
ifeq ($(NLS),1)
	$(MAKE) -C po install LOCALEDIR="$(LOCALEDIR)"
endif

clean:
	rm -rf $(ALL) *.dSYM
	$(MAKE) -C po clean

format:
	find . -type f -name '*.[cm]' -exec clang-format -i {} \;

man-lint:
	find man -type f -name '*.[1-9]' -exec mandoc -Tlint {} \;

.PHONY: all clean install sign format po install-po man-lint
