#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <err.h>
#import <getopt.h>
#import <objc/runtime.h>

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

#define OPTIONAL_ARGUMENT_IS_PRESENT                             \
	((optarg == NULL && optind < argc && argv[optind][0] != '-') \
		 ? (bool)(optarg = argv[optind++])                       \
		 : (optarg != NULL))

typedef struct {
	NSInteger style;
	NSInteger time;
} DarkModeOverride;

@interface UISUserInterfaceStyleMode : NSObject
@property(assign, nonatomic) NSInteger modeValue;

- (void)setOverride:(DarkModeOverride)override;
@end

typedef struct {
	int hour;
	int minute;
} Time;

typedef struct {
	Time fromTime;
	Time toTime;
} Schedule;

typedef struct {
	BOOL active;
	BOOL enabled;
	BOOL sunSchedulePermitted;
	int mode;
	Schedule schedule;
	NSUInteger disableFlags;
	BOOL available;
} Status;

@interface CBBlueLightClient : NSObject
- (void)setEnabled:(BOOL)arg1;
+ (BOOL)supportsBlueLightReduction;
- (BOOL)getBlueLightStatus:(Status *)arg1;
@end

@interface CBAdaptationClient : NSObject
- (void)setEnabled:(BOOL)arg1;
- (BOOL)getEnabled;
+ (BOOL)supportsAdaptation;
@end

BOOL _AXSAutoBrightnessEnabled();
void _AXSSetReduceWhitePointEnabled(BOOL enabled);
BOOL _AXSReduceWhitePointEnabled();


typedef enum { sOn, sOff, sUnspecified } state;

typedef enum {
	iNope,
	iEverything,
	iAutoBrightness,
	iBrightness,
	iDarkMode,
	iNightShift,
	iTrueTone,
	iReduceWhitePoint,
	iHeight,
	iWidth,
	iScale
} infoType;

// clang-format off
void usage() {
	printf(_("Usage: %s [-a state] [-b [+|-]num] [-d state] [-h] [-i [key]] [-j] [-n state] [-t state] [-w state]\n"), getprogname());
}
// clang-format on

state stateFromString(char *stringState, char *argName) {
	if (strcmp("0", stringState) == 0 || strcmp("off", stringState) == 0) {
		return sOff;
	} else if (strcmp("1", stringState) == 0 ||
			   strcmp("on", stringState) == 0) {
		return sOn;
	} else {
		errx(1, _("Invalid %s value: '%s', permitted values: 0, off, 1, on\n"),
			 argName, stringState);
	}
}

char *stateAsString(state theState) {
	switch (theState) {
		case sOn:
			return _("on");
		case sOff:
			return _("off");
		case sUnspecified:
			return _("not supported");
	}
}

id stateAsJSONType(state theState) {
	switch (theState) {
		case sOn:
			return @YES;
		case sOff:
			return @NO;
		case sUnspecified:
			return nil;
	}
}

void setAutoBrightness(state newState) {
	void *backBoardServices = dlopen(
		"/System/Library/PrivateFrameworks/BackBoardServices.framework/"
		"BackBoardServices",
		RTLD_NOW);

	void (*BKSDisplayBrightnessSetAutoBrightnessEnabled)(BOOL) = dlsym(
		backBoardServices, "BKSDisplayBrightnessSetAutoBrightnessEnabled");

	BKSDisplayBrightnessSetAutoBrightnessEnabled(newState == sOn);

	dlclose(backBoardServices);
}


state getAutoBrightness() {
	return _AXSAutoBrightnessEnabled() ? sOn : sOff;
}

void setDarkMode(state newState) {
	void *UIKitServices = dlopen(
		"/System/Library/PrivateFrameworks/UIKitServices.framework/"
		"UIKitServices",
		RTLD_NOW);
	if (objc_lookUpClass("UISUserInterfaceStyleMode") != nil) {
		UISUserInterfaceStyleMode *styleMode =
			[objc_getClass("UISUserInterfaceStyleMode") new];

		BOOL(*UISUserInterfaceStyleModeValueIsAutomatic)
		(NSInteger) =
			dlsym(UIKitServices, "UISUserInterfaceStyleModeValueIsAutomatic");

		if (UISUserInterfaceStyleModeValueIsAutomatic(styleMode.modeValue)) {
			DarkModeOverride override = {.style = (newState == sOn) ? 2 : 1,
										 .time = 1};
			[styleMode setOverride:override];
		} else {
			styleMode.modeValue = (newState == sOn) ? 2 : 1;
		}

		dlclose(UIKitServices);
	} else {
		errx(2, _("Dark Mode is only supported on iOS 13 and higher.\n"));
	}
}

state getDarkMode() {
	void *UIKitServices = dlopen(
		"/System/Library/PrivateFrameworks/UIKitServices.framework/"
		"UIKitServices",
		RTLD_NOW);

	if (objc_lookUpClass("UISUserInterfaceStyleMode") != nil) {
		UISUserInterfaceStyleMode *styleMode =
			[objc_getClass("UISUserInterfaceStyleMode") new];

		dlclose(UIKitServices);

		return styleMode.modeValue != 1 ? sOn : sOff;
	} else {
		return sUnspecified;
	}
}

void setNightShift(state newState) {
	void *coreBrightness = dlopen(
		"/System/Library/PrivateFrameworks/CoreBrightness.framework/"
		"CoreBrightness",
		RTLD_NOW);
	Class classCBBlueLightClient = objc_getClass("CBBlueLightClient");

	if ([classCBBlueLightClient supportsBlueLightReduction]) {
		[[classCBBlueLightClient new] setEnabled:(newState == sOn)];
	} else {
		dlclose(coreBrightness);
		errx(2, _("Night Shift is not supported on this device.\n"));
	}
	dlclose(coreBrightness);
}

state getNightShift() {
	void *coreBrightness = dlopen(
		"/System/Library/PrivateFrameworks/CoreBrightness.framework/"
		"CoreBrightness",
		RTLD_NOW);
	Class classCBBlueLightClient = objc_getClass("CBBlueLightClient");

	state theState = sUnspecified;
	if ([classCBBlueLightClient supportsBlueLightReduction]) {
		Status status;
		[[classCBBlueLightClient new] getBlueLightStatus:&status];

		theState = status.enabled ? sOn : sOff;
	}

	dlclose(coreBrightness);

	return theState;
}

void setTrueTone(state newState) {
	void *coreBrightness = dlopen(
		"/System/Library/PrivateFrameworks/CoreBrightness.framework/"
		"CoreBrightness",
		RTLD_NOW);
	Class classCBAdaptationClient = objc_getClass("CBAdaptationClient");

	if ([classCBAdaptationClient supportsAdaptation]) {
		[[classCBAdaptationClient new] setEnabled:(newState == sOn)];
	} else {
		dlclose(coreBrightness);
		errx(2, _("True Tone is not supported on this device.\n"));
	}
	dlclose(coreBrightness);
}

state getTrueTone() {
	void *coreBrightness = dlopen(
		"/System/Library/PrivateFrameworks/CoreBrightness.framework/"
		"CoreBrightness",
		RTLD_NOW);
	Class classCBAdaptationClient = objc_getClass("CBAdaptationClient");

	state theState = sUnspecified;
	if ([classCBAdaptationClient supportsAdaptation]) {
		theState = [[classCBAdaptationClient new] getEnabled] ? sOn : sOff;
	}

	dlclose(coreBrightness);

	return theState;
}

void setBrightness(char *value) {
	BOOL increase = NO;
	BOOL decrease = NO;

	if (value[0] == '+') {
		increase = YES;
	} else if (value[0] == '-') {
		decrease = YES;
	}

	size_t length = strlen(value);
	int number;
	const char *errstr;

	if (value[length - 1] == '%')
		value[length - 1] = '\0';

	if (increase || decrease) {
		if (length < 2) {
			errx(1, _("Invalid brightness value: %s\n"), value);
		}

		char *onlyValue = malloc(length - 1);
		strncpy(onlyValue, value + 1, length - 1);

		number = (int)strtonum(onlyValue, 0, 100, &errstr);

		free(onlyValue);
	} else {
		number = (int)strtonum(value, 0, 100, &errstr);
	}

	if (errstr != NULL) {
		errx(1, _("Invalid brightness value: %s, %s\n"), value, errstr);
	}

	if (number == 0 && (increase || decrease)) return;

	float brightness = ((float)number) / 100;

	void *backBoardServices = dlopen(
		"/System/Library/PrivateFrameworks/BackBoardServices.framework/"
		"BackBoardServices",
		RTLD_NOW);

	float (*BKSDisplayBrightnessGetCurrent)(void) =
		dlsym(backBoardServices, "BKSDisplayBrightnessGetCurrent");

	if (increase) {
		float (*BKSDisplayBrightnessGetCurrent)(void) =
			dlsym(backBoardServices, "BKSDisplayBrightnessGetCurrent");

		brightness += BKSDisplayBrightnessGetCurrent();

		if (brightness > 1.0) {
			dlclose(backBoardServices);
			errx(1, _("Unable to increase the brightness by %d, %.6g.\n"), number,
				 brightness * 100);
		}

	} else if (decrease) {
		float (*BKSDisplayBrightnessGetCurrent)(void) =
			dlsym(backBoardServices, "BKSDisplayBrightnessGetCurrent");

		brightness = BKSDisplayBrightnessGetCurrent() - brightness;

		if (brightness < 0.0) {
			dlclose(backBoardServices);
			errx(1, _("Unable to decrease the brightness by %d, %.6g.\n"), number,
				 brightness * 100);
		}
	}

	void *(*BKSDisplayBrightnessTransactionCreate)(CFAllocatorRef allocator) =
		dlsym(backBoardServices, "BKSDisplayBrightnessTransactionCreate");
	void (*BKSDisplayBrightnessSet)(float brightness, long unknown) =
		dlsym(backBoardServices, "BKSDisplayBrightnessSet");

	void *transaction =
		BKSDisplayBrightnessTransactionCreate(kCFAllocatorDefault);

	BKSDisplayBrightnessSet(brightness, 1);
	CFRelease(transaction);

	dlclose(backBoardServices);
}

float getBrightness() {
	void *backBoardServices = dlopen(
		"/System/Library/PrivateFrameworks/BackBoardServices.framework/"
		"BackBoardServices",
		RTLD_NOW);

	float (*BKSDisplayBrightnessGetCurrent)(void) =
		dlsym(backBoardServices, "BKSDisplayBrightnessGetCurrent");

	float brightness = BKSDisplayBrightnessGetCurrent() * 100;

	dlclose(backBoardServices);

	return brightness;
}

void printJSON(id notJSON) {
	NSError *error;
	NSData *jsonData;

	jsonData = [NSJSONSerialization dataWithJSONObject:notJSON options:0 error:&error];

	if (error)
		errx(1, _("JSON formating failed: %s"), error.localizedDescription.UTF8String);

	printf("%s\n", [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding].UTF8String);
}

int main(int argc, char *argv[]) {
#ifndef NO_NLS
	setlocale(LC_ALL, "");
	bindtextdomain(PACKAGE, LOCALEDIR);
	textdomain(PACKAGE);
#endif

	if (argc == 1) {
		usage();
		return 0;
	}

	// clang-format off
	static struct option longOptions[] = {
		{"help", no_argument, 0, 'h'},
		{"info", optional_argument, 0, 'i'},
		{"json", no_argument, 0, 'j'},
		{"autobrightness", required_argument, 0, 'a'},
		{"brightness", required_argument, 0, 'b'},
		{"darkmode", required_argument, 0, 'd'},
		{"nightshift", required_argument, 0, 'n'},
		{"truetone", required_argument, 0, 't'},
		{"reducewhitepoint", required_argument, 0, 'w'},
		{NULL, 0, NULL, 0}};
	// clang-format on

	BOOL json = NO;
	infoType info = iNope;

	int code = 0;
	while ((code = getopt_long(argc, argv, "hi::ja:b:d:n:t:w:", longOptions,
							   NULL)) != -1) {
		switch (code) {
			case 'h':
				usage();
				return 0;
			case 'i': {
				if (OPTIONAL_ARGUMENT_IS_PRESENT) {
					if (strcmp(optarg, "autobrightness") == 0 || strcmp(optarg, "auto-brightness") == 0) {
						info = iAutoBrightness;
					} else if (strcmp(optarg, "brightness") == 0) {
						info = iBrightness;
					} else if (strcmp(optarg, "darkmode") == 0) {
						info = iDarkMode;
					} else if (strcmp(optarg, "nightshift") == 0) {
						info = iNightShift;
					} else if (strcmp(optarg, "truetone") == 0) {
						info = iTrueTone;
					} else if (strcmp(optarg, "reducewhitepoint") == 0 || strcmp(optarg, "whitepoint") == 0) {
						info = iReduceWhitePoint;
					} else if (strcmp(optarg, "height") == 0) {
						info = iHeight;
					} else if (strcmp(optarg, "width") == 0) {
						info = iWidth;
					} else if (strcmp(optarg, "scale") == 0) {
						info = iScale;
					} else {
						errx(1, _("Unknown information type: %s\n"), optarg);
					}
				} else
					info = iEverything;
				break;
			}
			case 'j':
				json = YES;
				break;
			case 'a': {
				state newState = stateFromString(strdup(optarg), "Auto-Brightness");
				setAutoBrightness(newState);
				break;
			}
			case 'b':
				setBrightness(strdup(optarg));
				break;
			case 'd': {
				state newState = stateFromString(strdup(optarg), "Dark Mode");
				setDarkMode(newState);
				break;
			}
			case 'n': {
				state newState = stateFromString(strdup(optarg), "Night Shift");
				setNightShift(newState);
				break;
			}
			case 't': {
				state newState = stateFromString(strdup(optarg), "True Tone");
				setTrueTone(newState);
				break;
			}
			case 'w': {
				state newState = stateFromString(strdup(optarg), "Reduce White Point");
				_AXSSetReduceWhitePointEnabled(newState == sOn);
				break;
			}
			case '*':
				usage();
				return 1;
		}
	}

	if (info != iNope) {
		UIScreen *screen = [UIScreen mainScreen];

		if (json) {
			switch (info) {
				case iAutoBrightness:
					printJSON(@{
						@"autoBrightness": stateAsJSONType(getAutoBrightness()),
						@"displayName": [NSString stringWithUTF8String:_("Auto-Brightness")]
					});
					break;
				case iBrightness:
					printJSON(@{
						@"brightness": @(getBrightness()),
						@"displayName": [NSString stringWithUTF8String:_("Brightness")]
					});
					break;
				case iDarkMode:
					printJSON(@{
						@"darkMode": stateAsJSONType(getDarkMode()),
						@"displayName": [NSString stringWithUTF8String:_("Dark Mode")]
					});
					break;
				case iNightShift:
					printJSON(@{
						@"nightShift": stateAsJSONType(getNightShift()),
						@"displayName": [NSString stringWithUTF8String:_("Night Shift")]
					});
					break;
				case iTrueTone:
					printJSON(@{
						@"trueTone": stateAsJSONType(getNightShift()),
						@"displayName": [NSString stringWithUTF8String:_("True Tone")]
					});
					break;
				case iReduceWhitePoint:
					printJSON(@{
						@"trueTone": @(_AXSReduceWhitePointEnabled()),
						@"displayName": [NSString stringWithUTF8String:_("Reduce White Point")]
					});
					break;
				case iHeight:
					printJSON(@{
						@"height": @(CGRectGetHeight([screen bounds])),
						@"displayName": [NSString stringWithUTF8String:_("Height")]
					});
					break;
				case iWidth:
					printJSON(@{
						@"width": @(_AXSReduceWhitePointEnabled()),
						@"displayName": [NSString stringWithUTF8String:_("Width")]
					});
					break;
				case iScale:
					printJSON(@{
						@"scale": @(_AXSReduceWhitePointEnabled()),
						@"displayName": [NSString stringWithUTF8String:_("Scale")]
					});
					break;
				default:
					printJSON(@[
						@{
							@"autoBrightness": stateAsJSONType(getAutoBrightness()),
							@"displayName": [NSString stringWithUTF8String:_("Auto-Brightness")]
						},
						@{
							@"brightness": @(getBrightness()),
							@"displayName": [NSString stringWithUTF8String:_("Brightness")]
						},
						@{
							@"darkMode": stateAsJSONType(getDarkMode()),
							@"displayName": [NSString stringWithUTF8String:_("Dark Mode")]
						},
						@{
							@"nightShift": stateAsJSONType(getNightShift()),
							@"displayName": [NSString stringWithUTF8String:_("Night Shift")]
						},
						@{
							@"trueTone": stateAsJSONType(getNightShift()),
							@"displayName": [NSString stringWithUTF8String:_("True Tone")]
						},
						@{
							@"reduceWhitePoint": @(_AXSReduceWhitePointEnabled()),
							@"displayName": [NSString stringWithUTF8String:_("Reduce White Point")]
						},
						@{
							@"height": @(CGRectGetHeight([screen bounds])),
							@"displayName": [NSString stringWithUTF8String:_("Height")]
						},
						@{
							@"width": @(_AXSReduceWhitePointEnabled()),
							@"displayName": [NSString stringWithUTF8String:_("Width")]
						},
						@{
							@"scale": @(_AXSReduceWhitePointEnabled()),
							@"displayName": [NSString stringWithUTF8String:_("Scale")]
						}
					]);
					break;
			}
		}
		else {
			switch (info) {
				case iAutoBrightness:
					printf("%s: %s\n", _("Auto-Brightness") stateAsString(getAutoBrightness()));
					break;
				case iBrightness:
					printf("%s: %.6g\n", _("Brightness"), getBrightness());
					break;
				case iDarkMode:
					printf("%s: %s\n", _("Dark Mode"), stateAsString(getDarkMode()));
					break;
				case iNightShift:
					printf("%s: %s\n", _("Night Shift"), stateAsString(getNightShift()));
					break;
				case iTrueTone:
					printf("%s: %s\n", _("True Tone"), stateAsString(getTrueTone()));
					break;
				case iReduceWhitePoint:
					printf("%s: %s\n", _("Reduce White Point") stateAsString(_AXSReduceWhitePointEnabled() ? sOn : sOff));
					break;
				case iHeight:
					printf("%s: %f\n", _("Height"), CGRectGetHeight([screen bounds]));
					break;
				case iWidth:
					printf("%s: %f\n", _("Width"), CGRectGetWidth([screen bounds]));
					break;
				case iScale:
					printf("%s: %f\n", _("Scale"), [screen scale]);
					break;
				default:
					printf("%s: %.6g\n", _("Brightness"), getBrightness());
					printf("%s: %s\n", _("Auto-Brightness") stateAsString(getAutoBrightness()));
					printf("%s: %s\n", _("Dark Mode"), stateAsString(getDarkMode()));
					printf("%s: %s\n", _("Night Shift"), stateAsString(getNightShift()));
					printf("%s: %s\n", _("True Tone"), stateAsString(getTrueTone()));
					printf("%s: %s\n" _("Reduce White Point") stateAsString(_AXSReduceWhitePointEnabled() ? sOn : sOff));
					printf("%s: %f\n", _("Height"), CGRectGetHeight([screen bounds]));
					printf("%s: %f\n", _("Width"), CGRectGetWidth([screen bounds]));
					printf("%s: %f\n", _("Scale"), [screen scale]);
					break;
			}
		}
	} else if (json) {
		errx(1, _("-j/--json may only be used in combination with -i/--info"));
	}

	return 0;
}
