#include <CoreFoundation/CoreFoundation.h>
#include <Foundation/Foundation.h>
#include <err.h>
#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>

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

// clang-format off
void usage() {
	printf(_("Usage: %s [-b body] [-i prompt] [-j] [-p primary] [--priority number] [-s second] [--secure prompt] [-t third] [--timeout number] title\n\
Copyright (C) 2021, Procursus Team. All Rights Reserved.\n\n\
Display an alert\n\n"), getprogname());

	printf(_("  -b, --body <text>        Text for alert body\n\
  -p, --primary <text>     Default button text instead of \"OK\"\n\
      --priority 0-3       Alert priority\n\
                           This will change the icon on macOS\n\
  -s, --secondary <text>   Second button text\n\
  -t, --tertiary <text>    Third button text\n\
  -i, --input <text>       Ask for text input\n\
  -j, --json               Print the output in JSON\n\
      --secure <text>      Show text field as secure\n\
      --timeout <num>      Number of seconds to wait before exiting\n\n"));

	printf(_("Output:\n\
  0 - primary button\n\
  1 - secondary button\n\
  2 - tertiary button\n\
  3 - timeout/cancel\n\n\
Contact the Procursus Team for support.\n"));
	exit(1);
}
// clang-format on

enum {
	OPT_PRIORITY = CHAR_MAX + 1,
	OPT_TIMEOUT,
	OPT_SECURE,
};

int main(int argc, char **argv) {
#ifndef NO_NLS
	setlocale(LC_ALL, "");
	bindtextdomain(PACKAGE, LOCALEDIR);
	textdomain(PACKAGE);
#endif

	CFOptionFlags flags;
	double timeout = 0, index = 0;
	int priority = kCFUserNotificationNoteAlertLevel;
	char *message = NULL;
	char *defaultButton = NULL;
	char *alternativeButton = NULL;
	char *otherButton = NULL;
	int ch;
	const char *errstr;
	bool json = false;
	NSError *error;

	NSMutableDictionary *alert = [[NSMutableDictionary alloc] init];
	NSMutableArray *inputs= [[NSMutableArray alloc] init];

	// clang-format off
	static struct option longopts[] = {
		{"body", required_argument, NULL, 'b'},
		{"primary", required_argument, NULL, 'p'},
		{"priority", required_argument, NULL, OPT_PRIORITY},
		{"secondary", required_argument, NULL, 's'},
		{"tertiary", required_argument, NULL, 't'},
		{"timeout", required_argument, NULL, OPT_TIMEOUT},
		{"input", required_argument, NULL, 'i'},
		{"json", no_argument, NULL, 'j'},
		{"secure", required_argument, NULL, OPT_SECURE},
		{NULL, 0, NULL, 0}};
	// clang-format on

	while ((ch = getopt_long(argc, argv, "b:p:s:t:i:j", longopts, NULL)) != -1) {
		switch (ch) {
			case 'b':
				[alert addEntriesFromDictionary:@{
					(__bridge NSString *)kCFUserNotificationAlertMessageKey:
					[NSString stringWithUTF8String:optarg]}];
				break;
			case 'p':
				[alert addEntriesFromDictionary:@{
					(__bridge NSString *)kCFUserNotificationDefaultButtonTitleKey:
					[NSString stringWithUTF8String:optarg]}];
				break;
			case 's':
				[alert addEntriesFromDictionary:@{
					(__bridge NSString *)kCFUserNotificationAlternateButtonTitleKey:
					[NSString stringWithUTF8String:optarg]}];
				break;
			case 't':
				[alert addEntriesFromDictionary:@{
					(__bridge NSString *)kCFUserNotificationOtherButtonTitleKey:
					[NSString stringWithUTF8String:optarg]}];
				break;
			case OPT_SECURE:
				flags |=
					CFUserNotificationSecureTextField(inputs.count);
			case 'i':
				[inputs addObject:[NSString stringWithUTF8String:optarg]];
				break;
			case 'j':
				json = true;
				break;
			case OPT_PRIORITY:
				switch (strtonum(optarg, 0, 3, &errstr)) {
					case 0:
						if (errstr != NULL)
							err(1, "%s", optarg);
						priority = kCFUserNotificationPlainAlertLevel;
						break;
					case 1:
						priority = kCFUserNotificationNoteAlertLevel;
						break;
					case 2:
						priority = kCFUserNotificationCautionAlertLevel;
						break;
					case 3:
						priority = kCFUserNotificationStopAlertLevel;
						break;
				}
				break;
			case OPT_TIMEOUT:
				timeout = strtonum(optarg, 0, INT_MAX, &errstr);
				if (errstr != NULL)
					err(1, "%s", optarg);
				break;
			default:
				usage();
		}
	}
	argc -= optind;
	argv += optind;

	flags |= priority;

	if (argc != 1) usage();

	if (argv[0] == NULL) usage();

	[alert addEntriesFromDictionary:@{
		(__bridge NSString *)kCFUserNotificationAlertHeaderKey:
		[NSString stringWithUTF8String:argv[0]]}];

	if (inputs.count > 0)
		[alert addEntriesFromDictionary:@{
			(__bridge NSString *)kCFUserNotificationTextFieldTitlesKey:
			inputs}];

	CFUserNotificationRef notif = CFUserNotificationCreate(
		kCFAllocatorDefault, timeout, flags, NULL, (__bridge CFMutableDictionaryRef)alert);

	CFOptionFlags cfRes;

	CFUserNotificationReceiveResponse(notif, 0, &cfRes);

	NSDictionary *response = (__bridge NSDictionary *)CFUserNotificationGetResponseDictionary(notif);

	NSMutableDictionary *out = [[NSMutableDictionary alloc] init];

	if (cfRes != kCFUserNotificationCancelResponse && inputs.count >= 1) {
		NSObject *input = [response valueForKey:(__bridge NSString *)kCFUserNotificationTextFieldValuesKey];

		if ([input isKindOfClass:NSString.class]) {
			[out addEntriesFromDictionary:@{
				@"inputs" : @[(NSString *)input]
			}];
		} else if ([input isKindOfClass:NSArray.class]) {
			[out addEntriesFromDictionary:@{
				@"inputs" : (NSArray *)input
			}];
		}
	}

	[out addEntriesFromDictionary:@{
		@"button" : [NSNumber numberWithUnsignedLong:cfRes]
	}];

	if (json) {
		NSData *jsonData;

		jsonData = [NSJSONSerialization dataWithJSONObject:out options:0 error:&error];

		if (error)
			errx(1, _("JSON formating failed: %s"), error.localizedDescription.UTF8String);

		printf("%s\n", [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding].UTF8String);
	} else {
		for (NSString *item in [out valueForKey:@"inputs"])
			printf("%s\n", item.UTF8String);

		printf("%lu\n",
			   [(NSNumber *)[out valueForKey:@"button"] unsignedLongValue]);
	}

	CFRelease(notif);
	return 0;
}
