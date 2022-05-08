#import <CoreFoundation/CoreFoundation.h>
#include <getopt.h>
#include <stdbool.h>

CFTypeRef MGCopyAnswer(CFStringRef);

#ifndef NO_NLS
#	include <libintl.h>
#	define _(a) gettext(a)
#	define PACKAGE "uikittools-ng"
#else
#	define _(a) a
#endif

int ecid(int argc, char **argv) {
	bool hex = true;

	int ch;
	while ((ch = getopt(argc, argv, "hd")) != -1) {
		switch (ch) {
			case 'h':
				hex = true;
				break;
			case 'd':
				hex = false;
				break;
		}
	}

	uint64_t ecid;
	CFNumberRef ecidRef = MGCopyAnswer(CFSTR("UniqueChipID"));
	if (!ecidRef) {
		fprintf(stderr, _("Failed to get device ECID.\n"));
		return 1;
	}
	CFNumberGetValue(ecidRef, kCFNumberSInt64Type, &ecid);
	printf(hex ? "0x%llX\n" : "%lld\n", ecid);
	CFRelease(ecidRef);
	return 0;
}
