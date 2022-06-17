#include <AudioToolbox/AudioToolbox.h>
#include <UIKit/UIKit.h>
#include <getopt.h>

NSDictionary<NSString *, id> *getVibrationTypes(void) {
	NSDictionary *dict = @{
		@"light" : @(UIImpactFeedbackStyleLight),
		@"heavy" : @(UIImpactFeedbackStyleHeavy),
		@"medium" : @(UIImpactFeedbackStyleMedium),

		@"warning" : @(UINotificationFeedbackTypeWarning),
		@"error" : @(UINotificationFeedbackTypeError),
		@"success" : @(UINotificationFeedbackTypeSuccess),
	};

	NSMutableDictionary *mutableDict =
		[NSMutableDictionary dictionaryWithDictionary:dict];

	// Rigid & Soft are iOS 13.0+
	if (@available(iOS 13.0, *)) {
		mutableDict[@"rigid"] = @(UIImpactFeedbackStyleRigid);
		mutableDict[@"soft"] = @(UIImpactFeedbackStyleSoft);
	}

	return [mutableDict copy];
}

void help(void) {
	printf("Usage: uivibrate [options]\n");
	printf("Options:\n");
	printf("  -t, --type type         Type of vibration (medium by default)\n");
	printf("  -d, --duration number[unit] Duration of vibration\n");
	printf("                                  Unit can be 's' (seconds, the default),\n");
	printf("                                  m (minutes), h (hours), or d (days).\n");
	printf("  -h, --help                  Show this help message\n");

	if ([(NSNumber *)[[UIDevice currentDevice]
			valueForKey:@"_feedbackSupportLevel"] intValue] != 1) {
		printf("List of vibration types:\n");
		for (NSString *key in getVibrationTypes()) {
			printf("\t%s\n", [key UTF8String]);
		}
		printf("\tselection-change\n");  // Not listed in the dicionary, but is valid
	}
}

int playFeedback(NSString *type, float intensity) {
	if ([(NSNumber *)[[UIDevice currentDevice] valueForKey:@"_feedbackSupportLevel"] intValue] == 1) {
		AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
		return 0;
	}

	NSDictionary<NSString *, id> *vibrationTypes = getVibrationTypes();

	if ([type isEqualToString:@"light"] || [type isEqualToString:@"heavy"] ||
		[type isEqualToString:@"medium"] || [type isEqualToString:@"rigid"] ||
		[type isEqualToString:@"soft"]) {
		UIImpactFeedbackGenerator *generator =
			[[UIImpactFeedbackGenerator alloc]
				initWithStyle:[vibrationTypes[type] integerValue]];
		[generator prepare];
        if (intensity) {
            [generator impactOccurredWithIntensity: intensity];
        } else {
            [generator impactOccurred];
        }
	} else if ([type isEqualToString:@"warning"] ||
			   [type isEqualToString:@"error"] ||
			   [type isEqualToString:@"success"]) {
		UINotificationFeedbackGenerator *generator =
			[[UINotificationFeedbackGenerator alloc] init];
		[generator prepare];
		[generator notificationOccurred:[vibrationTypes[type] integerValue]];
	} else if ([type isEqualToString:@"selection-change"]) {
		[[UISelectionFeedbackGenerator alloc] selectionChanged];
	} else {
		printf("Unknown feedback type: %s\n", [type UTF8String]);
		return 1;
	}

	return 0;
}

int main(int argc, char *argv[]) {
	struct option longopts[] = {
		{"type", required_argument, 0, 't'},
		{"duration", required_argument, NULL, 'd'},
                {"intensity", required_argument, NULL, 'i'},
		{NULL, 0, NULL, 0}
	};

	@autoreleasepool {
		int ch;
		double duration = 0, d = 0;
        	float intensity;
		char unit;
		char buf[2];
		int matches = 0;
		NSString *feedbackType = @"medium"; // Medium by default.

		while ((ch = getopt_long(argc, argv, "i:t:d:h", longopts, NULL)) != -1) {
			switch (ch) {
				case 'd':
					matches = sscanf(optarg, "%lf%c%1s", &d, &unit, buf);
					if (matches == 2)
						switch (unit) {
							case 'd':
								d *= 24;
								/* FALLTHROUGH */
							case 'h':
								d *= 60;
								/* FALLTHROUGH */
							case 'm':
								d *= 60;
								/* FALLTHROUGH */
							case 's':
								break;
							default:
								help();
						}
					else if (matches != 1)
						help();
					duration += d;
					break;
				case 'h':
					help();
					return 0;
				case 't':
					feedbackType = [NSString stringWithUTF8String:optarg];
					break;
                case 'i':
                    intensity = atof(optarg);
				default:
					help();
					return 1;
			}
		}

		if (duration != 0) {
			for (double i = 0; i < duration; i++) {
				playFeedback(feedbackType, intensity);
				sleep(1);
			}
		} else {
			playFeedback(feedbackType, intensity);
			sleep(1); // We need to give it time to play before exiting
		}
	}
	return 0;
}
