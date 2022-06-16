#include <UIKit/UIKit.h>
#include <getopt.h>

NSDictionary <NSString *, id> *getVibrationTypes() {
    NSDictionary *dict = @{
        @"light": @(UIImpactFeedbackStyleLight),
        @"heavy": @(UIImpactFeedbackStyleHeavy),
        @"medium": @(UIImpactFeedbackStyleMedium),

        @"warning": @(UINotificationFeedbackTypeWarning),
        @"error": @(UINotificationFeedbackTypeError),
        @"success": @(UINotificationFeedbackTypeSuccess),
    };

    NSMutableDictionary *mutableDict = [NSMutableDictionary dictionaryWithDictionary:dict];

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
    printf("  -t, --type <type>         Type of vibration (medium by default)\n");
    printf("  -d, --duration <duration> Duration of vibration, in seconds\n");
    printf("  -h, --help                Show this help message\n");

    printf("List of vibration types:\n");
    for (NSString *key in getVibrationTypes()) {
        printf("\t%s\n", [key UTF8String]);
    }
    printf("\tselection-change\n"); // Not listed in the dicionary, but is valid
}

int playFeedback(NSString* type) {
    NSDictionary<NSString *, id> *vibrationTypes = getVibrationTypes();

    if ([type isEqualToString:@"light"]  || [type isEqualToString:@"heavy"]  || 
        [type isEqualToString:@"medium"] || [type isEqualToString:@"rigid"]  ||
        [type isEqualToString:@"soft"]) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:[vibrationTypes[type] integerValue]];
        [generator prepare];
        [generator impactOccurred];
    } else if ([type isEqualToString: @"warning"] || [type isEqualToString: @"error"] || [type isEqualToString: @"success"]) {
        UINotificationFeedbackGenerator *generator = [[UINotificationFeedbackGenerator alloc] init];
        [generator prepare];
        [generator notificationOccurred:[vibrationTypes[type] integerValue]];
    } else if ([type isEqualToString: @"selection-change"]) {
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
	{NULL, 0, NULL, 0}};

    @autoreleasepool {
        int ch;
        int duration = 0;
        NSString* feedbackType = @"medium"; // Rigid by default.

        while ((ch = getopt_long(argc, argv, "td:", longopts, NULL)) != -1) {
            switch (ch) {
                case 't':
                    feedbackType = [NSString stringWithUTF8String:optarg];
                    break;
                case 'd':
                    duration = atoi(optarg);
                    break;
                case 'h': 
                    help(); 
                    return 0;
                default: 
                    help();
                    return 1;
            }
        }

        if (duration && duration > 0) {
            for (int i; i < duration; i++) {
                playFeedback(feedbackType);
                sleep(1);
            }
        } else {
            playFeedback(feedbackType);
        }
    }
}
