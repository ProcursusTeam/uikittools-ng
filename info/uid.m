#import <Foundation/Foundation.h>

CFTypeRef MGCopyAnswer(CFStringRef);

int uniqueid(void) {
	printf("%s\n", [(__bridge_transfer NSString *)MGCopyAnswer(CFSTR("UniqueDeviceID")) UTF8String]);
	return 0;
}
