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
	__block int ret = 0;

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
				if (imageFormat && ![imageFormat isEqualToString:@"png"] && ![imageFormat isEqualToString:@"jpeg"] && ![imageFormat isEqualToString:@"heic"]) {
					fprintf(stderr, "Invalid image format '%s'\n", imageFormat.UTF8String);
					usage(2);
				}
				break;
			case '?':
				usage(1);
				break;
			default:
				usage(1);
		}
	}

	if (optind <= 1)
		usage(1);

	if (delay) sleep(delay);

	UIImage* screenShot = _UICreateScreenUIImage();
	if (!screenShot) {
		fprintf(stderr, "Could not capture screenshot!\n");
		return 2;
	}

	if (copyToClipboard) { 
		FILE* old_stderr = stderr;
		stderr = fopen("/dev/null", "w");

		[UIPasteboard generalPasteboard].image = screenShot;

		fclose(stderr);
		stderr = old_stderr;
	}

	if (filePath) {
		NSError* error;
		NSString* imageUTI = [NSString stringWithFormat:@"public.%@", imageFormat];

		NSMutableData* imageData = [[NSMutableData alloc] init];
		CGImageDestinationRef destinationRef = CGImageDestinationCreateWithData((CFMutableDataRef)imageData, (CFStringRef)imageUTI, 1, NULL);
		CGImageDestinationAddImage(destinationRef, screenShot.CGImage, NULL);
		if (!CGImageDestinationFinalize(destinationRef)) {
			fprintf(stderr, "Could not get image data to write to file!\n");
			ret = 3;
		}

		CFRelease(destinationRef);

		if (ret != 3 && ![imageData writeToFile:filePath options:NSDataWritingAtomic error:&error]) {
			fprintf(stderr, "Could not write image to %s: %s\n", filePath.UTF8String, error.localizedDescription.UTF8String);
			ret = 3;
		}
	}

	if (saveToPhotos) {
		dispatch_semaphore_t sema = dispatch_semaphore_create(0);

		[[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
			[PHAssetChangeRequest creationRequestForAssetFromImage:screenShot];
		} completionHandler:^(BOOL success, NSError* error) {
			if (!success) {
				fprintf(stderr, "Could not save screenshot to Photos: %s\n", error.localizedDescription.UTF8String);
				ret = 3;
			}

			dispatch_semaphore_signal(sema);
		}];

		dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
	}

	return ret;
}
