#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#include <TargetConditionals.h>

typedef NS_OPTIONS(NSUInteger, SBSRelaunchActionOptions) {
	SBSRelaunchActionOptionsNone,
	SBSRelaunchActionOptionsRestartRenderServer = 1 << 0,
	SBSRelaunchActionOptionsSnapshotTransition = 1 << 1,
	SBSRelaunchActionOptionsFadeToBlackTransition = 1 << 2
};

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

pid_t springboardPID;
pid_t backboarddPID;

int stopService(const char *ServiceName);
int updatePIDs(void);

int main() {
	@autoreleasepool {
		springboardPID = 0;
		backboarddPID = 0;

		updatePIDs();


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
		[(FBSSystemService *)[objc_getClass("FBSSystemService") sharedService]
			sendActions:[NSSet setWithObject:restartAction]
			 withResult:nil];
#endif
		sleep(2);

		int old_springboardPID = springboardPID;
		int old_backboarddPID = backboarddPID;

		updatePIDs();

		if (springboardPID == old_springboardPID) {
#if TARGET_OS_TV
			stopService("com.apple.PineBoard");
#else
			stopService("com.apple.SpringBoard");
#endif
		}
		if (backboarddPID == old_backboarddPID) {
			stopService("com.apple.backboardd");
		}
	}
	return 0;
}
