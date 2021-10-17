#include <getopt.h>
#include <stdio.h>
#include <stdbool.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

OBJC_EXTERN UIImage *_UICreateScreenUIImage(void);

void usage(uint8_t ret) {
	fprintf(stderr, "uishoot [-cp] [-d num] [-f file] [-i [png | jpeg | heic]]\n");
	exit(ret);
}

int main(int argc, char** argv) {
	bool copyToClipboard = false;
	bool saveToPhotos = false;
	long long int delay = 0;
	NSString* filePath = nil;
	NSString* imageFormat = @"png";
	int c;

	while ((c = getopt(argc, argv, "cpf:d:i:")) != -1) {
		switch (c) {
			case 'c':
				copyToClipboard = true;
				break;
			case 'f':
				filePath = [NSString stringWithUTF8String:optarg];
				break;
			case 'p':
				saveToPhotos = true;
				break;
			case 'd':
				delay = strtoll(optarg, NULL, 10);
				break;
			case 'i':
				imageFormat = [NSString stringWithUTF8String:optarg];
				break;
			case '?':
				usage(1);
				break;
			default:
				usage(1);
		}
	}

	if (imageFormat && ![imageFormat isEqualToString:@"png"] && ![imageFormat isEqualToString:@"jpeg"] && ![imageFormat isEqualToString:@"heic"]) {
		usage(2);
	}

	if (delay) sleep(delay);

	UIImage* screenShot = _UICreateScreenUIImage();
	if (!screenShot) {
		fprintf(stderr, "Could not capture screenshot!\n");
		return 1;
	}

	if (copyToClipboard) { 
		FILE* old_stderr = stderr;
		stderr = fopen("/dev/null", "w");

		[UIPasteboard generalPasteboard].image = screenShot;

		fclose(stderr);
		stderr = old_stderr;
	}

	if (filePath) {
		NSString* imageUTI;
		if ([imageFormat isEqualToString:@"png"]) {
			imageUTI = @"public.png";
		}

		else if ([imageFormat isEqualToString:@"jpeg"]) {
			imageUTI = @"public.jpeg";
		}

		else if ([imageFormat isEqualToString:@"heic"]) {
			imageUTI = @"public.heic";
		}

		else {
			imageUTI = @"public.png";
		}

		NSMutableData* imageData = [[NSMutableData alloc] init];
		CGImageDestinationRef destinationRef = CGImageDestinationCreateWithData((CFMutableDataRef)imageData, (CFStringRef)imageUTI, 1, NULL);
		CGImageDestinationAddImage(destinationRef, screenShot.CGImage, NULL);
		CGImageDestinationFinalize(destinationRef);
		[imageData writeToFile:filePath atomically:YES];
	}

	if (saveToPhotos) {
		dispatch_semaphore_t sema = dispatch_semaphore_create(0);

		[[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
	     		[PHAssetChangeRequest creationRequestForAssetFromImage:screenShot];
		} completionHandler:^(BOOL success, NSError* error) {
			if (!success) {
				fprintf(stderr, "Could not save screenshot to Photos.\n");
			}

			dispatch_semaphore_signal(sema);
		}];

		dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
	}

	return 0;
}
