#include <CoreFoundation/CoreFoundation.h>

int cfversion(void) {
	printf("%.2f\n", kCFCoreFoundationVersionNumber);
	return 0;
}
