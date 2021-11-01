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
	printf(_("Usage: %s [-b body] [-p primary] [--priority 0-3] [-s second] [-t third] [--timeout number] title\n\
Copyright (C) 2021, Procursus Team. All Rights Reserved.\n\n\
Display an alert\n\n"), getprogname());

	printf(_("  -b, --body <text>        Text for alert body\n\
  -p, --primary <text>     Default button text instead of \"OK\"\n\
      --priority 0-3       Alert priority\n\
                           This will change the icon on macOS\n\
  -s, --secondary <text>   Second button text\n\
  -t, --tertiary <text>    Third button text\n\
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
	OPT_PRIORITY,
	OPT_TIMEOUT
};

int main(int argc, char **argv) {
#ifndef NO_NLS
	setlocale(LC_ALL, "");
	bindtextdomain(PACKAGE, LOCALEDIR);
	textdomain(PACKAGE);
#endif

	CFOptionFlags cfRes;
	double timeout = 0;
	int priority = kCFUserNotificationNoteAlertLevel;
	char *message = NULL;
	char *defaultButton = NULL;
	char *alternativeButton = NULL;
	char *otherButton = NULL;
	int ch;
	const char *errstr;

// clang-format off
	static struct option longopts[] = {
		{"body", required_argument, NULL, 'b'},
		{"primary", required_argument, NULL, 'p'},
		{"priority", required_argument, NULL, OPT_PRIORITY},
		{"secondary", required_argument, NULL, 's'},
		{"tertiary", required_argument, NULL, 't'},
		{"timeout", required_argument, NULL, OPT_TIMEOUT},
		{NULL, 0, NULL, 0}};
// clang-format on

	while ((ch = getopt_long(argc, argv, "b:p:s:t:", longopts, NULL)) != -1) {
		switch (ch) {
			case 'b':
				message = optarg;
				break;
			case 'p':
				defaultButton = optarg;
				break;
			case 's':
				alternativeButton = optarg;
				break;
			case 't':
				otherButton = optarg;
				break;
			case OPT_PRIORITY:
				switch (strtonum(optarg, 0, 3, &errstr)) {
					case 0:
						if (errstr != NULL)
							errx(1, _("the priority is %s: %s"), errstr, optarg);
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
					errx(1, _("the timeout is %s: %s"), errstr, optarg);
				break;
			default:
				usage();
		}
	}
	argc -= optind;
	argv += optind;

	if (argc != 1) usage();

	if (argv[0] == NULL) usage();

	CFUserNotificationDisplayAlert(
		timeout, priority, NULL, NULL, NULL,
		(__bridge CFStringRef)[NSString stringWithUTF8String:argv[0]],
		message == NULL
			? NULL
			: (__bridge CFStringRef)[NSString stringWithUTF8String:message],
		defaultButton == NULL
			? NULL
			: (__bridge CFStringRef)
				  [NSString stringWithUTF8String:defaultButton],
		alternativeButton == NULL
			? NULL
			: (__bridge CFStringRef)
				  [NSString stringWithUTF8String:alternativeButton],
		otherButton == NULL
			? NULL
			: (__bridge CFStringRef)[NSString stringWithUTF8String:otherButton],
		&cfRes);
	printf("%lu\n", cfRes);
	return 0;
}
