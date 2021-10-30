#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <err.h>
#import <getopt.h>
#import <objc/runtime.h>

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
+ (BOOL)supportsBlueLightReduction;

- (BOOL)setEnabled:(BOOL)arg1;
- (BOOL)getBlueLightStatus:(Status *)arg1;
@end

@interface CBAdaptationClient : NSObject
+ (BOOL)supportsAdaptation;
- (BOOL)getEnabled;
- (BOOL)setEnabled:(BOOL)arg1;
@end

BOOL _AXSAutoBrightnessEnabled();


typedef enum { sOn, sOff, sUnspecified } state;

// clang-format off
void usage() {
	printf(
		"Usage: %s [brightness]\n"
		"Copyright (C) 2021, Procursus Team. All Rights Reserved.\n\n"

		"Gets or sets the brightness of the display\n\n"

		"Contact the Procursus Team for support.\n", getprogname());
}
// clang-format on

state stateFromString(char *stringState, char *argName) {
	if (strcmp("0", stringState) == 0 || strcmp("off", stringState) == 0) {
		return sOff;
	} else if (strcmp("1", stringState) == 0 ||
			   strcmp("on", stringState) == 0) {
		return sOn;
	} else {
		errx(1, "Invalid %s value: '%s', permitted values: 0, off, 1, on\n",
			 argName, stringState);
	}
}

char *stateAsString(state theState) {
	switch (theState) {
		case sOn:
			return "on";
		case sOff:
			return "off";
		case sUnspecified:
			return "not supported";
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
	if (@available(iOS 13, *)) {
		void *uiKitServices = dlopen(
			"/System/Library/PrivateFrameworks/UIKitServices.framework/"
			"UIKitServices",
			RTLD_NOW);
		UISUserInterfaceStyleMode *styleMode =
			[objc_getClass("UISUserInterfaceStyleMode") new];

		BOOL(*UISUserInterfaceStyleModeValueIsAutomatic)
		(NSInteger) =
			dlsym(uiKitServices, "UISUserInterfaceStyleModeValueIsAutomatic");

		if (UISUserInterfaceStyleModeValueIsAutomatic(styleMode.modeValue)) {
			DarkModeOverride override = {.style = (newState == sOn) ? 2 : 1,
										 .time = 1};
			[styleMode setOverride:override];
		} else {
			styleMode.modeValue = (newState == sOn) ? 2 : 1;
		}

		dlclose(uiKitServices);
	} else {
		errx(2, "Night Mode is only supported on iOS 13 and higher.\n");
	}
}

state getDarkMode() {
	if (@available(iOS 13, *)) {
		void *uiKitServices = dlopen(
			"/System/Library/PrivateFrameworks/UIKitServices.framework/"
			"UIKitServices",
			RTLD_NOW);

		UISUserInterfaceStyleMode *styleMode =
			[objc_getClass("UISUserInterfaceStyleMode") new];

		dlclose(uiKitServices);

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
		errx(2, "Night Shift is not supported on this device.\n");
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
		errx(2, "True Tone is not supported on this device.\n");
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

	if (increase || decrease) {
		if (length < 2) {
			errx(1, "Invalid brightness value: %s\n", value);
		}

		char *onlyValue = malloc(length - 1);
		strncpy(onlyValue, value + 1, length - 1);

		number = (int)strtonum(onlyValue, 0, 100, &errstr);

		free(onlyValue);
	} else {
		number = (int)strtonum(value, 0, 100, &errstr);
	}

	if (errstr != NULL) {
		errx(1, "Invalid brightness value: %s, %s\n", value, errstr);
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
			errx(1, "Unable to increase the brightness by %d, %.6g.\n", number,
				 brightness * 100);
		}

	} else if (decrease) {
		float (*BKSDisplayBrightnessGetCurrent)(void) =
			dlsym(backBoardServices, "BKSDisplayBrightnessGetCurrent");

		brightness = BKSDisplayBrightnessGetCurrent() - brightness;

		if (brightness < 0.0) {
			dlclose(backBoardServices);
			errx(1, "Unable to decrease the brightness by %d, %.6g.\n", number,
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

int main(int argc, char *argv[]) {
	// clang-format off
	static struct option longOptions[] = {
		{"help", no_argument, 0, 'h'},
		{"info", optional_argument, 0, 'i'},
		{"autobrightness", required_argument, 0, 'a'},
		{"brightness", required_argument, 0, 'b'},
		{"darkmode", required_argument, 0, 'd'},
		{"nightshift", required_argument, 0, 'n'},
		{"truetone", required_argument, 0, 't'},
		{NULL, 0, NULL, 0}};
	// clang-format on

	BOOL showhelp = NO;

	int code = 0;

	while ((code = getopt_long(argc, argv, "hi::a:b:d:n:t:", longOptions,
							   NULL)) != -1) {
		switch (code) {
			case 'h':
				usage();
				return 0;
			case 'i': {
				if (OPTIONAL_ARGUMENT_IS_PRESENT) {
					if (strcmp(optarg, "autobrightness") == 0) {
						printf("%s\n", stateAsString(getAutoBrightness()));
					} else if (strcmp(optarg, "brightness") == 0) {
						printf("%.6g\n", getBrightness());
					} else if (strcmp(optarg, "darkmode") == 0) {
						printf("%s\n", stateAsString(getDarkMode()));
					} else if (strcmp(optarg, "nightshift") == 0) {
						printf("%s", stateAsString(getNightShift()));
					} else if (strcmp(optarg, "truetone") == 0) {
						printf("%s\n", stateAsString(getTrueTone()));
					} else {
						errx(1, "Unknown information type: %s\n", optarg);
					}
				} else {
					printf(
						"Brightness: %.6g\n"
						"Auto-Brightness: %s\n"
						"Dark Mode: %s\n"
						"Night Shift: %s\n"
						"True Tone: %s\n",
						getBrightness(), stateAsString(getAutoBrightness()),
						stateAsString(getDarkMode()),
						stateAsString(getNightShift()),
						stateAsString(getTrueTone()));
				}
				break;
			}
			case 'a': {
				state newState =
					stateFromString(strdup(optarg), "Auto-Brightness");
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
			case '*':
				usage();
				return 1;
		}
	}

	return 0;
}
