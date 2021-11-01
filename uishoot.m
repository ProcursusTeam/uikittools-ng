#import <Foundation/Foundation.h>
#import <Photos/Photos.h>
#import <UIKit/UIKit.h>
#include <err.h>
#include <getopt.h>
#include <stdbool.h>
#include <stdio.h>

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

OBJC_EXTERN UIImage* _UICreateScreenUIImage(void);

// clang-format off
void usage(uint8_t ret) {
	fprintf(stderr, _("Usage: %s [-cp] [-d number] [-f [png | jpeg | heic]] [-o file]\n"), getprogname());
	exit(ret);
}
// clang-format on

int main(int argc, char** argv) {
#ifndef NO_NLS
	setlocale(LC_ALL, "");
	bindtextdomain(PACKAGE, LOCALEDIR);
	textdomain(PACKAGE);
#endif

	bool copyToClipboard = false;
	bool saveToPhotos = false;
	long long int delay = 0;
	NSString* filePath = nil;
	NSString* imageFormat = @"png";
	int c;
	const char* errstr;
	__block int ret = 0;

// clang-format off
	static struct option longopts[] = {
		{"clipboard", no_argument, NULL, 'b'},
		{"photos", no_argument, NULL, 'p'},
		{"delay", required_argument, NULL, 'd'},
		{"format", required_argument, NULL, 'f'},
		{"output", required_argument, NULL, 'o'},
		{NULL, 0, NULL, 0}};
// clang-format on

	while ((c = getopt_long(argc, argv, "cpd:f:o:", longopts, NULL)) != -1) {
		switch (c) {
			case 'c':
				copyToClipboard = true;
				break;
			case 'o':
				filePath = [NSString stringWithUTF8String:optarg];
				break;
			case 'p':
				saveToPhotos = true;
				break;
			case 'd':
				delay = strtonum(optarg, 0, INT_MAX, &errstr);
				if (errstr != NULL)
					errx(1, _("the timout is %s: %s"), errstr, optarg);
				break;
			case 'f':
				imageFormat = [NSString stringWithUTF8String:optarg];
				if (imageFormat && ![imageFormat isEqualToString:@"png"] &&
					![imageFormat isEqualToString:@"jpeg"] &&
					![imageFormat isEqualToString:@"heic"]) {
					fprintf(stderr, _("Invalid image format '%s'\n"),
							imageFormat.UTF8String);
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

	if (optind <= 1) usage(1);

	if (delay) sleep(delay);

	UIImage* screenShot = _UICreateScreenUIImage();
	if (!screenShot) {
		fprintf(stderr, _("Could not capture screenshot!\n"));
		return 2;
	}

	// tvOS doesn't have a clipboard, make this a no-op
#if !TARGET_OS_TV
	if (copyToClipboard) {
		FILE* old_stderr = stderr;
		stderr = fopen("/dev/null", "w");

		[UIPasteboard generalPasteboard].image = screenShot;

		fclose(stderr);
		stderr = old_stderr;
	}
#endif

	if (filePath) {
		NSError* error;
		NSString* imageUTI =
			[NSString stringWithFormat:@"public.%@", imageFormat];

		NSMutableData* imageData = [[NSMutableData alloc] init];
		CGImageDestinationRef destinationRef = CGImageDestinationCreateWithData(
			(CFMutableDataRef)imageData, (CFStringRef)imageUTI, 1, NULL);
		CGImageDestinationAddImage(destinationRef, screenShot.CGImage, NULL);
		if (!CGImageDestinationFinalize(destinationRef)) {
			fprintf(stderr, _("Could not get image data to write to file!\n"));
			ret = 3;
		}

		CFRelease(destinationRef);

		if (ret != 3 && ![imageData writeToFile:filePath
										options:NSDataWritingAtomic
										  error:&error]) {
			fprintf(stderr, _("Could not write image to %s: %s\n"),
					filePath.UTF8String, error.localizedDescription.UTF8String);
			ret = 3;
		}
	}

	if (saveToPhotos) {
		dispatch_semaphore_t sema = dispatch_semaphore_create(0);

		[[PHPhotoLibrary sharedPhotoLibrary]
			performChanges:^{
			  [PHAssetChangeRequest
				  creationRequestForAssetFromImage:screenShot];
			}
			completionHandler:^(BOOL success, NSError* error) {
			  if (!success) {
				  fprintf(stderr, _("Could not save screenshot to Photos: %s\n"),
						  error.localizedDescription.UTF8String);
				  ret = 3;
			  }

			  dispatch_semaphore_signal(sema);
			}];

		dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
	}

	return ret;
}
