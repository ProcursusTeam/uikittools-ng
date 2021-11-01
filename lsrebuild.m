#import <Foundation/Foundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#include <err.h>

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

@interface LSResourceProxy : NSObject
@property(assign) NSString* localizedName;
- (NSData*)iconDataForVariant:(NSInteger)format;
@end

@interface LSApplicationProxy : LSResourceProxy
+ (LSApplicationProxy*)applicationProxyForIdentifier:(id)identifier;
- (NSString*)applicationIdentifier;
- (NSURL*)containerURL;
- (NSURL*)resourcesDirectoryURL;
@end

@interface LSOpenOperation : NSOperation
@end

@interface LSApplicationWorkspace : NSObject
+ (LSApplicationWorkspace*)defaultWorkspace;
- (NSArray*)applicationsAvailableForHandlingURLScheme:(NSString*)scheme;
- (LSOpenOperation*)operationToOpenResource:(NSURL*)URL
						   usingApplication:(NSString*)identifier
				   uniqueDocumentIdentifier:(NSString*)document
								   userInfo:(NSDictionary*)userInfo
								   delegate:(id)delegate;
@end

@interface LSApplicationWorkspace (LSPrivate)
- (BOOL)_LSPrivateRebuildApplicationDatabasesForSystemApps:(BOOL)arg1
												  internal:(BOOL)arg2
													  user:(BOOL)arg3;
@end

int main(int argc, char** argv) {
#ifndef NO_NLS
	setlocale(LC_ALL, "");
	bindtextdomain(PACKAGE, LOCALEDIR);
	textdomain(PACKAGE);
#endif

	@autoreleasepool {
		LSApplicationWorkspace* workspace = [LSApplicationWorkspace defaultWorkspace];
		if (![workspace
				respondsToSelector:@selector
				(_LSPrivateRebuildApplicationDatabasesForSystemApps:internal:user:)]) {
			errx(1, _("missing necessary method"));
		}
		if (![workspace
				_LSPrivateRebuildApplicationDatabasesForSystemApps:YES
														  internal:YES
															  user:YES]) {
			errx(1, _("RebuildApplicationDatabases failed"));
		}
		return 0;
	}
}
