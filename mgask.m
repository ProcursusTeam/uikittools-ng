#import <Foundation/Foundation.h>
#include <err.h>
#include <stdio.h>

CFTypeRef MGCopyAnswer(CFStringRef);

const char *toJson(NSObject *object) {
	NSError *error;
	NSData *json;

	json = [NSJSONSerialization dataWithJSONObject:object
										   options:NSJSONWritingPrettyPrinted
											 error:&error];

	if (error)
		errx(1, "JSON formating failed: %s",
			 error.localizedDescription.UTF8String);

	return [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]
		.UTF8String;
}

int main(int argc, char **argv) {
	if (argc == 1) {
		fprintf(stderr, "Usage: %s [questions ...]\n", getprogname());
		return 1;
	}
	argv += 1;
	argc -= 1;

	int i = 0;

	for (i = 0; i < argc; i++) {
		const char *answer;
		CFTypeRef mganswer;
		mganswer = MGCopyAnswer(
			(__bridge CFStringRef)[NSString stringWithUTF8String:argv[i]]);

		if (mganswer == NULL) {
			fprintf(stderr, "Cannot find key %s\n", argv[i]);
			goto skipprint;
		}

		CFTypeID typeid = CFGetTypeID(mganswer);

		if (typeid == CFStringGetTypeID())
			answer = CFStringGetCStringPtr(mganswer, kCFStringEncodingUTF8);
		else if (typeid == CFBooleanGetTypeID())
			answer = CFBooleanGetValue(mganswer) ? "true" : "false";
		else if (typeid == CFNumberGetTypeID())
			answer =
				[(__bridge_transfer NSNumber *)mganswer stringValue].UTF8String;
		else if (typeid == CFDictionaryGetTypeID())
			answer = toJson((__bridge NSObject *)mganswer);
		else if (typeid == CFArrayGetTypeID())
			answer = toJson((__bridge NSObject *)mganswer);
		else {
			fprintf(stderr, "%s has an unknown answer type\n", argv[i]);
			goto skipprint;
		}

		if (argc != 1)
			printf("%s: ", argv[i]);

		printf("%s\n", answer);

	skipprint:
		if (mganswer != NULL) CFRelease(mganswer);
	}

	return 0;
}
