#import "BezierAppController.h"


@implementation BezierAppController


- (void)awakeFromNib
{
	NSString *lastDocument = [[NSUserDefaults standardUserDefaults] stringForKey:@"lastDocument"];
	BOOL isDirectory = FALSE;
	if([[NSFileManager defaultManager] fileExistsAtPath:lastDocument isDirectory:&isDirectory] && !isDirectory) {
		NSURL *documentURL = [NSURL fileURLWithPath:lastDocument];
		if(documentURL)
			[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:documentURL display:TRUE error:nil];
	} else
		[[NSDocumentController sharedDocumentController] openDocument:self];
}


@end
