#import <Photos/Photos.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

void usage(char *name) {
	printf(
		"Usage: %s FILE...\n"
		"Copyright (C) 2021, Procursus Team. All Rights Reserved.\n\n"

		"Save images and videos to the camera roll\n\n"

		"Image and video formats that can be saved to the camera roll\n"
		"vary between iOS versions\n\n"

		"Contact the Procursus Team for support.\n", name);
}

int main(int argc, char *argv[]) {

	if (argc < 2) {
		usage(argv[0]);
		return 1;
	}

	NSMutableArray<NSString *> *images = [NSMutableArray array];
	NSMutableArray<NSString *> *videos = [NSMutableArray array];

	for (int i = 1; i < argc; i++) {
		char *path = argv[i];
		NSString *pathString = [[NSString stringWithUTF8String:path] stringByExpandingTildeInPath];

		BOOL directory;
		BOOL exists = [NSFileManager.defaultManager fileExistsAtPath:pathString isDirectory:&directory];

		if (directory || !exists) {
			fprintf(stderr, "No file at path: %s\n", path);
			return 1;
		}

		if (![NSURL fileURLWithPath:pathString isDirectory:NO]) {
			fprintf(stderr, "Invalid path: %s\n", path);
			return 1;
		}

		if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(pathString)) {
			[videos addObject:pathString];
		} else if ([UIImage imageWithContentsOfFile:pathString]) {
			// imageWithContentsOfFile returns nil if it can't create an image from the file
			[images addObject:pathString];
		} else {
			fprintf(stderr, "No supported image or video format at: %s\n", path);
			return 1;
		}
	}


	NSError *error;
	for (NSString *image in images) {
		NSURL *url = [NSURL fileURLWithPath:image isDirectory:NO];
		BOOL success = [[PHPhotoLibrary sharedPhotoLibrary] performChangesAndWait:^{
			[PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:url];
		} error:&error];

		if (!success) {
			const char *errorString = error.localizedDescription.UTF8String;
			fprintf(stderr, "Failed to save image at %s with error: %s\n", image.UTF8String, errorString);
			return 1;
		}
	}

	for (NSString *video in videos) {
		NSURL *url = [NSURL fileURLWithPath:video isDirectory:NO];
		BOOL success = [[PHPhotoLibrary sharedPhotoLibrary] performChangesAndWait:^{
			[PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
		} error:&error];

		if (!success) {
			const char *errorString = error.localizedDescription.UTF8String;
			fprintf(stderr, "Failed to save video at %s with error: %s\n", video.UTF8String, errorString);
			return 1;
		}
	}

	return 0;
}
