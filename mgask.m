#import <Foundation/Foundation.h>
#include <err.h>
#include <getopt.h>
#include <stdbool.h>
#include <stdio.h>

#ifndef NO_NLS
#	include <libintl.h>
#	define _(a) gettext(a)
#	define PACKAGE "uikittools-ng"
#else
#	define _(a) a
#endif

#ifndef LOCALEDIR
#	define LOCALEDIR "/usr/share/locale"
#endif

CFTypeRef MGCopyAnswer(CFStringRef);

const char *toJson(NSObject *object, bool prettyprint) {
	NSError *error;
	NSData *json;

	json = [NSJSONSerialization
		dataWithJSONObject:object
				   options:prettyprint ? NSJSONWritingPrettyPrinted : 0
					 error:&error];

	if (error)
		errx(1, _("JSON formating failed: %s"),
			 error.localizedDescription.UTF8String);

	return [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]
		.UTF8String;
}

int main(int argc, char **argv) {
#ifndef NO_NLS
	setlocale(LC_ALL, "");
	bindtextdomain(PACKAGE, LOCALEDIR);
	textdomain(PACKAGE);
#endif

	bool json = false;
	bool prettyprint = false;
	bool quiet = false;
	int ch, index;

	struct option longopts[] = {
		{"json", no_argument, 0, 'j'},
		{"pretty", no_argument, 0, 'p'},
		{"quiet", no_argument, 0, 'q'},
		{NULL, 0, NULL, 0}};

	while ((ch = getopt_long(argc, argv, "jpq", longopts, &index)) != -1) {
		switch (ch) {
			case 'j':
				json = true;
				break;
			case 'p':
				prettyprint = true;
				break;
			case 'q':
				quiet = true;
				break;
		}
	}
	argv += optind;
	argc -= optind;

	if (argc == 0) {
		fprintf(stderr, _("Usage: %s [-jp] question ...\n"), getprogname());
		return 1;
	}

	int i = 0;
	NSMutableDictionary *outDict = [[NSMutableDictionary alloc] init];

	for (i = 0; i < argc; i++) {
		const char *answer;
		CFTypeRef mganswer;
		mganswer = MGCopyAnswer(
			(__bridge CFStringRef)[NSString stringWithUTF8String:argv[i]]);

		if (mganswer == NULL) {
			if (!quiet)
				fprintf(stderr, _("Cannot find key %s\n"), argv[i]);
			goto skipprint;
		}

		CFTypeID typeid = CFGetTypeID(mganswer);

		if (typeid == CFStringGetTypeID()) {
			if (!json)
				answer = [(__bridge_transfer NSString *)mganswer UTF8String];
			else
				[outDict addEntriesFromDictionary:@{
					[NSString stringWithUTF8String:argv[i]] :
						(__bridge_transfer NSString *)mganswer
				}];
		} else if (typeid == CFBooleanGetTypeID()) {
			if (!json)
				answer = CFBooleanGetValue(mganswer) ? _("true") : _("false");
			else
				[outDict addEntriesFromDictionary:@{
					[NSString stringWithUTF8String:argv[i]] :
							CFBooleanGetValue(mganswer) ? @YES : @NO
				}];
		} else if (typeid == CFNumberGetTypeID()) {
			if (!json)
				answer = [(__bridge_transfer NSNumber *)mganswer stringValue]
							 .UTF8String;
			else
				[outDict addEntriesFromDictionary:@{
					[NSString stringWithUTF8String:argv[i]] :
						(__bridge_transfer NSNumber *)mganswer
				}];
		} else if (typeid == CFDictionaryGetTypeID()) {
			if (!json)
				answer = toJson((__bridge NSObject *)mganswer, prettyprint);
			else
				[outDict addEntriesFromDictionary:@{
					[NSString stringWithUTF8String:argv[i]] :
						(__bridge_transfer NSDictionary *)mganswer
				}];
		} else if (typeid == CFArrayGetTypeID()) {
			if (!json)
				answer = toJson((__bridge NSObject *)mganswer, prettyprint);
			else
				[outDict addEntriesFromDictionary:@{
					[NSString stringWithUTF8String:argv[i]] :
						(__bridge_transfer NSArray *)mganswer
				}];
		} else {
			if (!quiet)
				fprintf(stderr, "%s has an unknown answer type\n", argv[i]);
			goto skipprint;
		}

		if (!json) {
			if (argc != 1)
				printf("%s: ", argv[i]);

			printf("%s\n", answer);
		}

	skipprint:
		if (mganswer != NULL) CFRelease(mganswer);
	}

	if (json)
		printf("%s\n", toJson(outDict, prettyprint));

	return 0;
}
