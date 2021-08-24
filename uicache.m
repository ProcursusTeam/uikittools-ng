#import <stdio.h>
#import <getopt.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <Foundation/NSURL.h>

@interface _LSApplicationState : NSObject
-(BOOL)isValid;
@end

@interface LSApplicationProxy : NSObject
+(id)applicationProxyForIdentifier:(id)arg1;
-(id)localizedNameForContext:(id)arg1;
-(_LSApplicationState *)appState;
-(NSURL *)bundleURL;
-(NSURL *)containerURL;
-(NSString *)bundleExecutable;
-(NSString *)bundleIdentifier;
-(NSString *)vendorName;
-(NSString *)teamID;
-(NSString *)applicationType;
-(NSSet *)claimedURLSchemes;
-(BOOL)isDeletable;
@end

@interface LSApplicationWorkspace : NSObject
+ (id)defaultWorkspace;
- (BOOL)_LSPrivateRebuildApplicationDatabasesForSystemApps:(BOOL)arg1 internal:(BOOL)arg2 user:(BOOL)arg3;
- (BOOL)registerApplicationDictionary:(NSDictionary *)applicationDictionary;
- (BOOL)registerBundleWithInfo:(NSDictionary *)bundleInfo options:(NSDictionary *)options type:(unsigned long long)arg3 progress:(id)arg4 ;
- (BOOL)registerApplication:(NSURL *)url;
- (BOOL)registerPlugin:(NSURL *)url;
- (BOOL)unregisterApplication:(NSURL *)url;
- (NSArray *)installedPlugins;
-(void)_LSPrivateSyncWithMobileInstallation;
-(NSArray <LSApplicationProxy*> *)allApplications;
@end

typedef NS_OPTIONS(NSUInteger, SBSRelaunchActionOptions) {
	SBSRelaunchActionOptionsNone,
	SBSRelaunchActionOptionsRestartRenderServer = 1 << 0,
	SBSRelaunchActionOptionsSnapshotTransition = 1 << 1,
	SBSRelaunchActionOptionsFadeToBlackTransition = 1 << 2
};

@interface MCMContainer : NSObject
+ (instancetype)containerWithIdentifier:(NSString *)identifier createIfNecessary:(BOOL)createIfNecessary existed:(BOOL *)existed error:(NSError **)error;
- (NSURL *)url;
@end

@interface MCMAppDataContainer : MCMContainer
@end

@interface MCMPluginKitPluginDataContainer : MCMContainer
@end

@interface SBSRelaunchAction : NSObject
+ (instancetype)actionWithReason:(NSString *)reason options:(SBSRelaunchActionOptions)options targetURL:(NSURL *)targetURL;
@end

@interface FBSSystemService : NSObject
+ (instancetype)sharedService;
- (void)sendActions:(NSSet *)actions withResult:(id)result;
@end

#define	CS_OPS_CDHASH		5	/* get code directory hash */
int csops(pid_t pid, unsigned int  ops, void * useraddr, size_t usersize);

int force = 0;

void help(char *name) {
	printf(
		"Usage: %s [OPTION...]\n"
		"Modified work Copyright (C) 2021, Procursus Team. All Rights Reserved.\n\n"
		"Update iOS registered applications and optionally restart SpringBoard\n\n"

		"  --all                    Update all system and internal applications\n"
		"                              (replicates the old uicache behavior)\n"
		"  -f, --force              Update application bundle at the specified path\n"
		"  -p, --path <path>        Update application bundle at the specified path\n"
		"  -u, --unregister <path>  Unregister application bundle at the specified path\n"
		"  -r, --respring           Restart SpringBoard and backboardd after\n"
		"                              updating applications.\n"
		"  -l, --list               List the bundle ids of installed apps\n"
		"  -i, --info <bundleid>    Give information about given bundle id\n"
		"  -h, --help               Give this help list.\n\n"

		"Contact the Procursus Team for support.\n", name);
}

void registerPath(char *path, int unregister) {
	dlopen("/System/Library/PrivateFrameworks/MobileContainerManager.framework/MobileContainerManager", RTLD_NOW);

	LSApplicationWorkspace *workspace = [LSApplicationWorkspace defaultWorkspace];
	if (unregister && ![[NSString stringWithUTF8String:path] hasPrefix:@"/"]) {
		LSApplicationProxy *app = [LSApplicationProxy applicationProxyForIdentifier:[NSString stringWithUTF8String:path]];
		path = (char *)[[app bundleURL] fileSystemRepresentation];
	}
	NSString *rawPath = [NSString stringWithUTF8String:path];
	rawPath = [rawPath stringByResolvingSymlinksInPath];

	NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:[rawPath stringByAppendingPathComponent:@"Info.plist"]];
	NSString *bundleID = [infoPlist objectForKey:@"CFBundleIdentifier"];

	NSURL *url = [NSURL fileURLWithPath:rawPath];

	if (bundleID && !unregister){
		MCMContainer *appContainer = [objc_getClass("MCMAppDataContainer") containerWithIdentifier:bundleID createIfNecessary:YES existed:nil error:nil];
		NSString *containerPath = [appContainer url].path;

		NSMutableDictionary *plist = [NSMutableDictionary dictionary];
		[plist setObject:@"System" forKey:@"ApplicationType"];
		[plist setObject:@1 forKey:@"BundleNameIsLocalized"];
		[plist setObject:bundleID forKey:@"CFBundleIdentifier"];
		[plist setObject:@0 forKey:@"CompatibilityState"];
		if (containerPath)
			[plist setObject:containerPath forKey:@"Container"];
		[plist setObject:@0 forKey:@"IsDeletable"];
		[plist setObject:rawPath forKey:@"Path"];

		NSString *pluginsPath = [rawPath stringByAppendingPathComponent:@"PlugIns"];
		NSArray *plugins = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:pluginsPath error:nil];

		NSMutableDictionary *bundlePlugins = [NSMutableDictionary dictionary];
		for (NSString *pluginName in plugins){
			NSString *fullPath = [pluginsPath stringByAppendingPathComponent:pluginName];

			NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:[fullPath stringByAppendingPathComponent:@"Info.plist"]];
			NSString *pluginBundleID = [infoPlist objectForKey:@"CFBundleIdentifier"];
			if (!pluginBundleID)
				continue;
			MCMContainer *pluginContainer = [objc_getClass("MCMPluginKitPluginDataContainer") containerWithIdentifier:pluginBundleID createIfNecessary:YES existed:nil error:nil];
			NSString *pluginContainerPath = [pluginContainer url].path;

			NSMutableDictionary *pluginPlist = [NSMutableDictionary dictionary];
			[pluginPlist setObject:@"PluginKitPlugin" forKey:@"ApplicationType"];
			[pluginPlist setObject:@1 forKey:@"BundleNameIsLocalized"];
			[pluginPlist setObject:pluginBundleID forKey:@"CFBundleIdentifier"];
			[pluginPlist setObject:@0 forKey:@"CompatibilityState"];
			[pluginPlist setObject:pluginContainerPath forKey:@"Container"];
			[pluginPlist setObject:fullPath forKey:@"Path"];
			[pluginPlist setObject:bundleID forKey:@"PluginOwnerBundleID"];
			[bundlePlugins setObject:pluginPlist forKey:pluginBundleID];
		}
		[plist setObject:bundlePlugins forKey:@"_LSBundlePlugins"];
		if (![workspace registerApplicationDictionary:plist]){
			fprintf(stderr, "Error: Unable to register %s\n", path);
		}
	} else {
		if (![workspace unregisterApplication:url]){
			fprintf(stderr, "Error: Unable to unregister %s\n", path);
		}
	}
}

void listBundleID() {
	LSApplicationWorkspace *workspace = [LSApplicationWorkspace defaultWorkspace];
	for (LSApplicationProxy *app in [workspace allApplications]) {
		printf("%s : %s\n", [[app bundleIdentifier] UTF8String], [[app bundleURL] fileSystemRepresentation]);
	}
}

void infoForBundleID(NSString *bundleID) {
	LSApplicationWorkspace *workspace = [LSApplicationWorkspace defaultWorkspace];
	LSApplicationProxy *app = [LSApplicationProxy applicationProxyForIdentifier:bundleID];
	if ([[app appState] isValid]) {
		printf(
				"Name: %s\n"
				"BundleID: %s\n"
				"ExecutableName: %s\n"
				"Path: %s\n"
			 	"Container Path: %s\n"
				"VendorName: %s\n"
				"TeamID: %s\n"
				"Type: %s\n"
				"Removeable: %s\n",
				[[app localizedNameForContext:nil] UTF8String],
				[[app bundleIdentifier] UTF8String],
				[[app bundleExecutable] UTF8String],
				[[app bundleURL] fileSystemRepresentation],
				[[app containerURL] fileSystemRepresentation],
				[[app vendorName] UTF8String],
				[[app teamID] UTF8String],
				[[app applicationType] UTF8String],
				[app isDeletable]? "true" : "false"
		);
		if ([app respondsToSelector:@selector(claimedURLSchemes)]) {
			for (NSString *scheme in [app claimedURLSchemes]) {
				printf("URLScheme: %s\n", [scheme UTF8String]);
			}
		} else {
			NSArray<NSDictionary *> *appURLS = [[NSBundle bundleWithURL:[app bundleURL]] objectForInfoDictionaryKey:@"CFBundleURLTypes"];
			for (NSDictionary *urlInfo in appURLS) {
				for (NSString *urlScheme in urlInfo[@"CFBundleURLSchemes"]) {
					printf("URLScheme: %s\n", [urlScheme UTF8String]);
				}
			}
		}
	} else {
		printf("%s is an invalid bundle id\n", [[app bundleIdentifier] UTF8String]);
	}
}

void registerAll() {
	if (force) {
		[[LSApplicationWorkspace defaultWorkspace] _LSPrivateRebuildApplicationDatabasesForSystemApps:YES internal:YES user:NO];
		return;
	}

	NSArray<NSString *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/Applications" error:nil];

	NSMutableSet<NSString*> *installed = [[NSMutableSet alloc] init];

	for (NSString *file in files) {
		if ([file hasSuffix:@".app"] &&
		    [[NSFileManager defaultManager]
		        fileExistsAtPath:[NSString
		        stringWithFormat:@"/Applications/%@/Info.plist", file]] &&
		    [[NSFileManager defaultManager]
		        fileExistsAtPath:[NSString stringWithFormat:@"/Applications/%@/%@",
		        file, [[NSDictionary dictionaryWithContentsOfURL:[NSURL
		        fileURLWithPath:[NSString stringWithFormat:@"/Applications/%@/Info.plist", file]] error:nil]
		        valueForKey:@"CFBundleExecutable"]]])
		{
			[installed addObject:[NSString stringWithFormat:@"/Applications/%@", file]];
		}
	}

	NSMutableSet<NSString*> *registered = [[NSMutableSet alloc] init];

	LSApplicationWorkspace *workspace = [LSApplicationWorkspace defaultWorkspace];
	for (LSApplicationProxy *app in [workspace allApplications]) {
		if ([[NSString stringWithUTF8String:[[app bundleURL] fileSystemRepresentation]] hasPrefix:@"/Applications"]) {
			[registered addObject:[NSString stringWithUTF8String:[[app bundleURL] fileSystemRepresentation]]];
		}
	}

	NSMutableSet<NSString*> *toRegister = [[NSMutableSet alloc] init];
	for (NSString *app in installed) {
		if (![registered containsObject:app]) {
			[toRegister addObject:app];
		}
	}

	NSMutableSet<NSString*> *toUnregister = [[NSMutableSet alloc] init];
	for (NSString *app in registered) {
		if (![installed containsObject:app]) {
			[toUnregister addObject:app];
		}
	}
	for (NSString *app in toRegister)
		registerPath((char *)[app UTF8String], 0);
	for (NSString *app in toUnregister)
		registerPath((char *)[app UTF8String], 1);
}

int main(int argc, char *argv[]){
	@autoreleasepool {
		int all = 0;
		int respring = 0;
		NSMutableSet *registerSet = [[NSMutableSet alloc] init];
		NSMutableSet *unregisterSet = [[NSMutableSet alloc] init];
		char *path;
		int list = 0;
		NSMutableSet *infoSet = [[NSMutableSet alloc] init];
		int showhelp = 0;

		struct option longOptions[] = {
			{ "all" , no_argument, 0, 'a'},
			{ "path", required_argument, 0, 'p'},
			{ "unregister", required_argument, 0, 'u'},
			{ "respring", no_argument, 0, 'r' },
			{ "list", optional_argument, 0, 'l' },
			{ "info", required_argument, 0, 'i' },
			{ "help", no_argument, 0, 'h' },
			{ "verbose", no_argument, 0, 'v' }, // verbose and force are added to maintain compatibility to old uikittools
			{ "force", no_argument, 0, 'f' },
			{ NULL, 0, NULL, 0 }
		};

		int index = 0, code = 0;

		while ((code = getopt_long(argc, argv, "ap:u:rl::i:hfv", longOptions, &index)) != -1) {
			switch (code) {
				printf("Code: %c\n", code);
				case 'a':
					all = 1;
					break;
				case 'p':
					[registerSet addObject:[NSString stringWithUTF8String:strdup(optarg)]];
					break;
				case 'u':
					[unregisterSet addObject:[NSString stringWithUTF8String:strdup(optarg)]];
					break;
				case 'r':
					respring = 1;
					break;
				case 'h':
					showhelp = 1;
					break;
				case 'l':
					if (optarg)
						[infoSet addObject:[NSString stringWithUTF8String:strdup(optarg)]];
					else if (NULL != argv[optind] && '-' != argv[optind][0] )
						[infoSet addObject:[NSString stringWithUTF8String:strdup(argv[optind++])]];
					else
						list = 1;
					break;
				case 'i':
					[infoSet addObject:[NSString stringWithUTF8String:strdup(optarg)]];
					break;
				case 'f':
					force = 1;
					break;
			}
		}

		if (showhelp || argc == 1){
			help(argv[0]);
			return 0;
		}

		if (list)
			listBundleID();

		for (NSString *bundleID in infoSet) {
			infoForBundleID(bundleID);
		}

		for(NSString *path in registerSet) {
			registerPath((char *)[path UTF8String], 0);
		}

		for(NSString *path in unregisterSet) {
			registerPath((char *)[path UTF8String], 1);
		}

		if (argc == 1){
			if (!(getenv("SILEO") || isatty(STDOUT_FILENO) || isatty(STDIN_FILENO) || isatty(STDERR_FILENO))){
				printf("\n");
				fprintf(stderr, "Warning uicache: No arguments detected.\n");
			}
		}
		
		if (all){
			if (getenv("SILEO"))
				fprintf(stderr, "Error: -a may not be used while installing/uninstalling in Sileo. Ignoring.\n");
			else
				registerAll();
		}

		if (respring){
			dlopen("/System/Library/PrivateFrameworks/FrontBoardServices.framework/FrontBoardServices", RTLD_NOW);
			dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_NOW);

			SBSRelaunchAction *restartAction = [objc_getClass("SBSRelaunchAction") actionWithReason:@"respring" options:(SBSRelaunchActionOptionsRestartRenderServer | SBSRelaunchActionOptionsFadeToBlackTransition) targetURL:nil];
			[(FBSSystemService *)[objc_getClass("FBSSystemService") sharedService] sendActions:[NSSet setWithObject:restartAction] withResult:nil];
			sleep(2);
		}

		return 0;
	}
}
