#import <MobileCoreServices/MobileCoreServices.h>

@interface LSResourceProxy : NSObject
@property(assign) NSString* localizedName;
-(NSData*)iconDataForVariant:(NSInteger)format;
@end

@interface LSApplicationProxy : LSResourceProxy
+(LSApplicationProxy*)applicationProxyForIdentifier:(id)identifier;
-(NSString*)applicationIdentifier;
-(NSURL*)containerURL;
-(NSURL*)resourcesDirectoryURL;
@end

@interface LSOpenOperation : NSOperation
@end

@interface LSApplicationWorkspace : NSObject
+ (LSApplicationWorkspace*)defaultWorkspace;
- (NSArray*)applicationsAvailableForHandlingURLScheme:(NSString*)scheme;
- (LSOpenOperation*)operationToOpenResource:(NSURL*)URL usingApplication:(NSString*)identifier uniqueDocumentIdentifier:(NSString*)document userInfo:(NSDictionary*)userInfo delegate:(id)delegate;
@end

@interface LSApplicationWorkspace (LSPrivate)
- (BOOL)_LSPrivateRebuildApplicationDatabasesForSystemApps:(BOOL)arg1 internal:(BOOL)arg2 user:(BOOL)arg3 ;
@end

int main(int argc, char** argv) {
    @autoreleasepool {
      LSApplicationWorkspace* workspace=[LSApplicationWorkspace defaultWorkspace];
      if(![workspace respondsToSelector:@selector(_LSPrivateRebuildApplicationDatabasesForSystemApps:internal:user:)]){
        fputs("Not supported\n",stderr);
        return -1;
      }
      if(![workspace _LSPrivateRebuildApplicationDatabasesForSystemApps:YES internal:YES user:YES]){
        fputs("RebuildApplicationDatabases\n",stderr);
        return 1;
      }
      return 0;
    }
}
