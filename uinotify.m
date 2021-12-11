#import <UserNotifications/UserNotifications.h>
#include <err.h>
#include <getopt.h>

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

@interface UNUserNotificationCenter (Private)
- (id)initWithBundleIdentifier:(id)arg1;
@end

// clang-format off
void usage() {
	fprintf(stderr, _("Usage: %s [-b body] [-d number] [-i bundleid] [-s subtitle] title\n"), getprogname());
	exit(1);
}
// clang-format on

void authorize(UNUserNotificationCenter *center) {
	__block CFRunLoopRef runLoop = CFRunLoopGetCurrent();
	[center requestAuthorizationWithOptions:UNAuthorizationOptionAlert
						  completionHandler:^(BOOL success, NSError *error) {
							if (error) {
								fprintf(stderr,
										_("Authorization request failed: %s\n"),
										error.localizedDescription.UTF8String);
								exit(1);
							}
							CFRunLoopStop(runLoop);
						  }];
	CFRunLoopRun();
}

void sendNotification(UNUserNotificationCenter *center,
					  UNNotificationRequest *request) {
	__block CFRunLoopRef runLoop = CFRunLoopGetCurrent();
	[center addNotificationRequest:request
			 withCompletionHandler:^(NSError *error) {
			   if (error) {
				   fprintf(stderr, _("Failed to add notification: %s\n"),
						   error.localizedDescription.UTF8String);
				   exit(1);
			   }
			   CFRunLoopStop(runLoop);
			 }];
	CFRunLoopRun();
}

int main(int argc, char *argv[]) {
#ifndef NO_NLS
	setlocale(LC_ALL, "");
	bindtextdomain(PACKAGE, LOCALEDIR);
	textdomain(PACKAGE);
#endif

	char *subtitle, *body, *bundleid;
	long long delay = 0;
	int ch, actionIndex = 0;
	const char *errstr;

// clang-format off
	static struct option longopts[] = {
		{"body", required_argument, NULL, 'b'},
		{"delay", required_argument, NULL, 'd'},
		{"identifier", required_argument, NULL, 'i'},
		{"subtitle", required_argument, NULL, 's'},
		{NULL, 0, NULL, 0}};
// clang-format on

	while ((ch = getopt_long(argc, argv, "a:b:d:i:s:u:", longopts, NULL)) != -1) {
		switch (ch) {
			case 'b':
				body = optarg;
				break;
			case 'i':
				bundleid = optarg;
				break;
			case 's':
				subtitle = optarg;
				break;
			case 'd':
				delay = strtonum(optarg, 0, INT_MAX, &errstr);
				if (errstr != NULL)
					err(1, "%s", optarg);
				break;
			default:
				usage();
		}
	}
	argc -= optind;
	argv += optind;

	if (argc != 1) usage();

	if (argv[0] == NULL) usage();

	UNUserNotificationCenter *center = [[UNUserNotificationCenter alloc]
		initWithBundleIdentifier:((bundleid != NULL)
									  ? [NSString stringWithUTF8String:bundleid]
									  : @"com.apple.Preferences")];
	UNMutableNotificationContent *content =
		[[UNMutableNotificationContent alloc] init];

	content.title = [NSString stringWithUTF8String:argv[0]];

	if (body != NULL) content.body = [NSString stringWithUTF8String:body];

	if (subtitle != NULL)
		content.subtitle = [NSString stringWithUTF8String:subtitle];

	authorize(center);

	content.threadIdentifier =
		((bundleid != NULL) ? [NSString stringWithUTF8String:bundleid]
							: @"com.apple.Preferences");

	UNNotificationRequest *request = [UNNotificationRequest
		requestWithIdentifier:[[NSUUID UUID] UUIDString]
					  content:content
					  trigger:(delay == 0) ? nil
										   : [UNTimeIntervalNotificationTrigger
												 triggerWithTimeInterval:delay
																 repeats:NO]];

	sendNotification(center, request);
	return 0;
}
