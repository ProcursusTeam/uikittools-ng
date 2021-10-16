#include <UIKit/UIKit.h>

OBJC_EXTERN UIImage *_UICreateScreenUIImage(void);

int main(int argc, char** argv) {
	bool copyToClipboard = false;
	bool saveToPhotos = false;
	long long int delay = 0;
	NSString* filePath = nil;
	int c;

	while ((c = getopt(argc, argv, "cf:pd:")) != -1) {
		switch (c) {
			case 'c':
				copyToClipboard = true;
				break;
			case 'f'
				filePath = [NSString stringWithCString:optarg];
				break;
			case 'p'
				saveToPhotos = true;
				break;
			case 'd'
				delay = strtoll(optarg, NULL, 10);
				break;
			case '?':
				fprintf(stderr, "Unknown argument.\n");
			default:
				fprintf(stderr, "Unknown argument.\n");
		}
	}

	UIImage* screenShot = _UICreateScreenUIImage();
	if (!screenShot) {
		fprintf(stderr, "Could not capture screenshot!\n");
		return 1;
	}

	if 

	FILE* old_stderr = stderr;
	stderr = fopen("/dev/null", "w");

	if (copyToClipboard) {
		[UIPasteboard generalPasteboard].image = screenShot;
	}

	fclose(stderr);
	stderr = old_stderr;

	return 0;
}
