#import <CoreFoundation/CoreFoundation.h>
#include <getopt.h>
#include <stdbool.h>

CFTypeRef MGCopyAnswer(CFStringRef);

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
	CFNumberGetValue(ecidRef, kCFNumberSInt64Type, &ecid);
	printf(hex ? "0x%llX\n" : "%lld\n", ecid);
	CFRelease(ecidRef);
	return 0;
}
