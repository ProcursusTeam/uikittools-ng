#import <Foundation/Foundation.h>
#import <Foundation/NSURL.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <dlfcn.h>
#import <getopt.h>
#import <objc/runtime.h>
#import <stdio.h>

#ifndef APP_PATH
#define APP_PATH @"/private/preboot/procursus/Applications"
#endif

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

@interface _LSApplicationState : NSObject
- (BOOL)isValid;
@end

@interface LSApplicationProxy : NSObject
+ (id)applicationProxyForIdentifier:(id)arg1;
- (id)localizedNameForContext:(id)arg1;
- (_LSApplicationState *)appState;
- (NSURL *)bundleURL;
- (NSURL *)containerURL;
- (NSString *)bundleExecutable;
- (NSString *)bundleIdentifier;
- (NSString *)vendorName;
- (NSString *)teamID;
- (NSString *)applicationType;
- (NSSet *)claimedURLSchemes;
- (BOOL)isDeletable;
@end

@interface LSApplicationWorkspace : NSObject
+ (id)defaultWorkspace;
- (BOOL)_LSPrivateRebuildApplicationDatabasesForSystemApps:(BOOL)arg1
												  internal:(BOOL)arg2
													  user:(BOOL)arg3;
- (BOOL)registerApplicationDictionary:(NSDictionary *)applicationDictionary;
- (BOOL)registerBundleWithInfo:(NSDictionary *)bundleInfo
					   options:(NSDictionary *)options
						  type:(unsigned long long)arg3
					  progress:(id)arg4;
- (BOOL)registerApplication:(NSURL *)url;
- (BOOL)registerPlugin:(NSURL *)url;
- (BOOL)unregisterApplication:(NSURL *)url;
- (NSArray *)installedPlugins;
- (void)_LSPrivateSyncWithMobileInstallation;
- (NSArray<LSApplicationProxy *> *)allApplications;
@end

typedef NS_OPTIONS(NSUInteger, SBSRelaunchActionOptions) {
	SBSRelaunchActionOptionsNone,
	SBSRelaunchActionOptionsRestartRenderServer = 1 << 0,
	SBSRelaunchActionOptionsSnapshotTransition = 1 << 1,
	SBSRelaunchActionOptionsFadeToBlackTransition = 1 << 2
};

@interface MCMContainer : NSObject
+ (instancetype)containerWithIdentifier:(NSString *)identifier
					  createIfNecessary:(BOOL)createIfNecessary
								existed:(BOOL *)existed
								  error:(NSError **)error;
- (NSURL *)url;
@end

@interface MCMAppDataContainer : MCMContainer
@end

@interface MCMPluginKitPluginDataContainer : MCMContainer
@end

@interface SBSRelaunchAction : NSObject
+ (instancetype)actionWithReason:(NSString *)reason
						 options:(SBSRelaunchActionOptions)options
					   targetURL:(NSURL *)targetURL;
@end

@interface FBSSystemService : NSObject
+ (instancetype)sharedService;
- (void)sendActions:(NSSet *)actions withResult:(id)result;
@end

@interface PBSSystemService : NSObject
+ (instancetype)sharedInstance;
- (void)relaunch;
@end

int force = 0;
int verbose = 0;

// clang-format off
void help() {
	printf(_("Usage: %s [-afhlr] [-i id] [-p path] [-u path]\n\
Modified work Copyright (C) 2021, Procursus Team. All Rights Reserved.\n\n"), getprogname());
	printf(_("Update iOS registered applications and optionally restart SpringBoard\n\n"));

	printf(_("  -a, --all                Update all system and internal applications\n"));
	printf(_("  -f, --force              Force -a to reregister all Applications\n\
                              and modify App Store apps\n"));
	printf(_("  -p, --path <path>        Update application bundle at the specified path\n"));
	printf(_("  -u, --unregister <path>  Unregister application bundle at the specified path\n"));
	printf(_("  -r, --respring           Restart SpringBoard and backboardd after\n\
                              updating applications\n"));
	printf(_("  -l, --list               List the bundle ids of installed apps\n"));
	printf(_("  -i, --info <bundleid>    Give information about given bundle id\n"));
	printf(_("  -h, --help               Give this help list.\n\n"));

	printf(_("Contact the Procursus Team for support.\n"));
}
// clang-format on

void registerPath(char *path, int unregister) {
	dlopen(
		"/System/Library/PrivateFrameworks/MobileContainerManager.framework/"
		"MobileContainerManager",
		RTLD_NOW);

	LSApplicationWorkspace *workspace =
		[LSApplicationWorkspace defaultWorkspace];
	if (unregister && ![[NSString stringWithUTF8String:path] hasPrefix:@"/"]) {
		LSApplicationProxy *app = [LSApplicationProxy
			applicationProxyForIdentifier:[NSString stringWithUTF8String:path]];
		path = (char *)[[app bundleURL] fileSystemRepresentation];
	}

	if ([[NSString stringWithUTF8String:path]
			hasPrefix:@"/private/var/containers/Bundle/Application"] ||
		[[NSString stringWithUTF8String:path]
			hasPrefix:@"/var/containers/Bundle/Application"]) {
		printf(_("uicache does not support App Store apps.\n"));
		if (force)
			printf(_("Continuing anyway...\n"));
		else
			return;
	}

	NSString *rawPath = [NSString stringWithUTF8String:path];
	rawPath = [rawPath stringByResolvingSymlinksInPath];

	NSDictionary *infoPlist = [NSDictionary
		dictionaryWithContentsOfFile:
			[rawPath stringByAppendingPathComponent:@"Info.plist"]];
	NSString *bundleID = [infoPlist objectForKey:@"CFBundleIdentifier"];

	NSURL *url = [NSURL fileURLWithPath:rawPath];

	if (bundleID && !unregister) {
		MCMContainer *appContainer = [objc_getClass("MCMAppDataContainer")
			containerWithIdentifier:bundleID
				  createIfNecessary:YES
							existed:nil
							  error:nil];
		NSString *containerPath = [appContainer url].path;

		NSMutableDictionary *plist = [NSMutableDictionary dictionary];
		[plist setObject:@"System" forKey:@"ApplicationType"];
		[plist setObject:@1 forKey:@"BundleNameIsLocalized"];
		[plist setObject:bundleID forKey:@"CFBundleIdentifier"];
		[plist setObject:@0 forKey:@"CompatibilityState"];
		if (containerPath) [plist setObject:containerPath forKey:@"Container"];
		[plist setObject:@0 forKey:@"IsDeletable"];
		[plist setObject:rawPath forKey:@"Path"];

		NSString *pluginsPath =
			[rawPath stringByAppendingPathComponent:@"PlugIns"];
		NSArray *plugins = [[NSFileManager defaultManager]
			contentsOfDirectoryAtPath:pluginsPath
								error:nil];

		NSMutableDictionary *bundlePlugins = [NSMutableDictionary dictionary];
		for (NSString *pluginName in plugins) {
			NSString *fullPath =
				[pluginsPath stringByAppendingPathComponent:pluginName];

			NSDictionary *infoPlist = [NSDictionary
				dictionaryWithContentsOfFile:
					[fullPath stringByAppendingPathComponent:@"Info.plist"]];
			NSString *pluginBundleID =
				[infoPlist objectForKey:@"CFBundleIdentifier"];
			if (!pluginBundleID) continue;
			MCMContainer *pluginContainer =
				[objc_getClass("MCMPluginKitPluginDataContainer")
					containerWithIdentifier:pluginBundleID
						  createIfNecessary:YES
									existed:nil
									  error:nil];
			NSString *pluginContainerPath = [pluginContainer url].path;

			NSMutableDictionary *pluginPlist = [NSMutableDictionary dictionary];
			[pluginPlist setObject:@"PluginKitPlugin"
							forKey:@"ApplicationType"];
			[pluginPlist setObject:@1 forKey:@"BundleNameIsLocalized"];
			[pluginPlist setObject:pluginBundleID forKey:@"CFBundleIdentifier"];
			[pluginPlist setObject:@0 forKey:@"CompatibilityState"];
			[pluginPlist setObject:pluginContainerPath forKey:@"Container"];
			[pluginPlist setObject:fullPath forKey:@"Path"];
			[pluginPlist setObject:bundleID forKey:@"PluginOwnerBundleID"];
			[bundlePlugins setObject:pluginPlist forKey:pluginBundleID];
		}
		[plist setObject:bundlePlugins forKey:@"_LSBundlePlugins"];
		if (![workspace registerApplicationDictionary:plist]) {
			fprintf(stderr, _("Error: Unable to register %s\n"), path);
		}
	} else {
		if (![workspace unregisterApplication:url]) {
			fprintf(stderr, _("Error: Unable to unregister %s\n"), path);
		}
	}
}

void listBundleID() {
	LSApplicationWorkspace *workspace =
		[LSApplicationWorkspace defaultWorkspace];
	for (LSApplicationProxy *app in [workspace allApplications]) {
		printf("%s : %s\n", [[app bundleIdentifier] UTF8String],
			   [[app bundleURL] fileSystemRepresentation]);
	}
}

void infoForBundleID(NSString *bundleID) {
	LSApplicationWorkspace *workspace =
		[LSApplicationWorkspace defaultWorkspace];
	LSApplicationProxy *app =
		[LSApplicationProxy applicationProxyForIdentifier:bundleID];
	if ([[app appState] isValid]) {
		printf(_("Name: %s\n\
BundleID: %s\n\
ExecutableName: %s\n\
Path: %s\n\
Container Path: %s\n\
VendorName: %s\n\
TeamID: %s\n\
Type: %s\n\
Removeable: %s\n"),
			[[app localizedNameForContext:nil] UTF8String],
			[[app bundleIdentifier] UTF8String],
			[[app bundleExecutable] UTF8String],
			[[app bundleURL] fileSystemRepresentation],
			[[app containerURL] fileSystemRepresentation],
			[[app vendorName] UTF8String], [[app teamID] UTF8String],
			[[app applicationType] UTF8String],
			[app isDeletable] ? _("true") : _("false"));
		if ([app respondsToSelector:@selector(claimedURLSchemes)]) {
			for (NSString *scheme in [app claimedURLSchemes]) {
				printf(_("URLScheme: %s\n"), [scheme UTF8String]);
			}
		} else {
			NSArray<NSDictionary *> *appURLS =
				[[NSBundle bundleWithURL:[app bundleURL]]
					objectForInfoDictionaryKey:@"CFBundleURLTypes"];
			for (NSDictionary *urlInfo in appURLS) {
				for (NSString *urlScheme in urlInfo[@"CFBundleURLSchemes"]) {
					printf(_("URLScheme: %s\n"), [urlScheme UTF8String]);
				}
			}
		}
	} else {
		printf(_("%s is an invalid bundle id\n"),
			   [[app bundleIdentifier] UTF8String]);
	}
}

void registerAll() {
	if (force) {
		[[LSApplicationWorkspace defaultWorkspace]
			_LSPrivateRebuildApplicationDatabasesForSystemApps:YES
													  internal:YES
														  user:NO];
		return;
	}

	NSArray<NSString *> *files = [[NSFileManager defaultManager]
		contentsOfDirectoryAtPath:@"/Applications"
							error:nil];
	NSArray<NSString *> *filesSecondary =
		[[NSFileManager defaultManager] contentsOfDirectoryAtPath:APP_PATH
															error:nil];

	NSMutableSet<NSString *> *installed = [[NSMutableSet alloc] init];

	for (NSString *file in files) {
		if ([file hasSuffix:@".app"] &&
			[[NSFileManager defaultManager]
				fileExistsAtPath:
					[NSString stringWithFormat:@"/Applications/%@/Info.plist",
											   file]] &&
			[[NSFileManager defaultManager]
				fileExistsAtPath:
					[NSString
						stringWithFormat:
							@"/Applications/%@/%@", file,
							[[NSDictionary
								dictionaryWithContentsOfURL:
									[NSURL fileURLWithPath:
											   [NSString stringWithFormat:
															 @"/Applications/"
															 @"%@/Info.plist",
															 file]]
													  error:nil]
								valueForKey:@"CFBundleExecutable"]]]) {
			[installed addObject:[NSString stringWithFormat:@"/Applications/%@",
															file]];
		}
	}

	for (NSString *file in filesSecondary) {
		if ([file hasSuffix:@".app"] &&
			[[NSFileManager defaultManager]
				fileExistsAtPath:[NSString stringWithFormat:@"%@/%@/Info.plist",
															APP_PATH, file]] &&
			[[NSFileManager defaultManager]
				fileExistsAtPath:
					[NSString
						stringWithFormat:
							@"%@/%@/%@", APP_PATH, file,
							[[NSDictionary
								dictionaryWithContentsOfURL:
									[NSURL
										fileURLWithPath:
											[NSString stringWithFormat:
														  @"%@/%@/Info.plist",
														  APP_PATH, file]]
													  error:nil]
								valueForKey:@"CFBundleExecutable"]]]) {
			[installed
				addObject:[NSString stringWithFormat:@"%@/%@", APP_PATH, file]];
		}
	}

	NSMutableSet<NSString *> *registered = [[NSMutableSet alloc] init];

	LSApplicationWorkspace *workspace =
		[LSApplicationWorkspace defaultWorkspace];
	for (LSApplicationProxy *app in [workspace allApplications]) {
		if ([[NSString
				stringWithUTF8String:[[app bundleURL] fileSystemRepresentation]]
				hasPrefix:@"/Applications"] ||
			[[NSString
				stringWithUTF8String:[[app bundleURL] fileSystemRepresentation]]
				hasPrefix:APP_PATH]) {
			[registered addObject:[NSString stringWithUTF8String:
												[[app bundleURL]
													fileSystemRepresentation]]];
		}
	}

	NSMutableSet<NSString *> *toRegister = [[NSMutableSet alloc] init];
	for (NSString *app in installed) {
		if (![registered containsObject:app]) {
			[toRegister addObject:app];
		}
	}

	NSMutableSet<NSString *> *toUnregister = [[NSMutableSet alloc] init];
	for (NSString *app in registered) {
		if (![installed containsObject:app]) {
			[toUnregister addObject:app];
		}
	}
	for (NSString *app in toRegister) {
		if (verbose)
			printf(_("registering %s\n"), app.UTF8String);
		registerPath((char *)[app UTF8String], 0);
	}
	for (NSString *app in toUnregister) {
		if (verbose)
			printf(_("unregistering %s\n"), app.UTF8String);
		registerPath((char *)[app UTF8String], 1);
	}
}

int main(int argc, char *argv[]) {
#ifndef NO_NLS
	setlocale(LC_ALL, "");
	bindtextdomain(PACKAGE, LOCALEDIR);
	textdomain(PACKAGE);
#endif

	@autoreleasepool {
		int all = 0;
		int respring = 0;
		NSMutableSet *registerSet = [[NSMutableSet alloc] init];
		NSMutableSet *unregisterSet = [[NSMutableSet alloc] init];
		char *path;
		int list = 0;
		NSMutableSet *infoSet = [[NSMutableSet alloc] init];
		int showhelp = 0;

// clang-format off
		struct option longOptions[] = {
			{"all", no_argument, 0, 'a'},
			{"path", required_argument, 0, 'p'},
			{"unregister", required_argument, 0, 'u'},
			{"respring", no_argument, 0, 'r'},
			{"list", optional_argument, 0, 'l'},
			{"info", required_argument, 0, 'i'},
			{"help", no_argument, 0, 'h'},
			{"verbose", no_argument, 0, 'v'},	// verbose was added to maintain compatibility with old uikittools
			{"force", no_argument, 0, 'f'},
			{NULL, 0, NULL, 0}};
// clang-format on

		int index = 0, code = 0;

		while ((code = getopt_long(argc, argv, "ap:u:rl::i:hfv", longOptions, &index)) != -1) {
			switch (code) {
				case 'a':
					all = 1;
					break;
				case 'p':
					[registerSet
						addObject:[NSString
									  stringWithUTF8String:strdup(optarg)]];
					break;
				case 'u':
					[unregisterSet
						addObject:[NSString
									  stringWithUTF8String:strdup(optarg)]];
					break;
				case 'r':
					respring = 1;
					break;
				case 'h':
					showhelp = 1;
					break;
				case 'l':
					if (optarg)
						[infoSet
							addObject:[NSString
										  stringWithUTF8String:strdup(optarg)]];
					else if (NULL != argv[optind] && '-' != argv[optind][0])
						[infoSet
							addObject:[NSString stringWithUTF8String:
													strdup(argv[optind++])]];
					else
						list = 1;
					break;
				case 'i':
					[infoSet
						addObject:[NSString
									  stringWithUTF8String:strdup(optarg)]];
					break;
				case 'f':
					force = 1;
					break;
				case 'v':
					verbose = 1;
					break;
			}
		}

		if (showhelp || argc == 1) {
			help();
			return 0;
		}

		if (list) listBundleID();

		for (NSString *bundleID in infoSet) {
			infoForBundleID(bundleID);
		}

		for (NSString *path in registerSet) {
			registerPath((char *)[path UTF8String], 0);
		}

		for (NSString *path in unregisterSet) {
			registerPath((char *)[path UTF8String], 1);
		}

		if (all)
			registerAll();

		if (respring) {
			dlopen("/System/Library/PrivateFrameworks/FrontBoardServices.framework/FrontBoardServices", RTLD_NOW);
#if TARGET_OS_TV
		dlopen("/System/Library/PrivateFrameworks/PineBoardServices.framework/PineBoardServices", RTLD_NOW);
		[[objc_getClass("PBSSystemService") sharedInstance] relaunch];
#else
			dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_NOW);

			SBSRelaunchAction *restartAction = [objc_getClass("SBSRelaunchAction")
				actionWithReason:@"respring"
						 options:(SBSRelaunchActionOptionsRestartRenderServer |
								  SBSRelaunchActionOptionsFadeToBlackTransition)
					   targetURL:nil];
			[(FBSSystemService *)[objc_getClass("FBSSystemService")
				sharedService] sendActions:[NSSet setWithObject:restartAction]
								withResult:nil];
#endif
			sleep(2);
		}

		return 0;
	}
}
