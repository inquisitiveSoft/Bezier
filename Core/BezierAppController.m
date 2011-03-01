#import "BezierAppController.h"
#import "BezierDocument.h"

NSString *const BezierExternalEditorName = @"BezierExternalEditorName";

@implementation BezierAppController
@synthesize editMenuItem, currentDocument;


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
	
	[self bind:@"currentDocument" toObject:[NSDocumentController sharedDocumentController] withKeyPath:@"currentDocument" options:nil];
}


- (IBAction)editInExternalEditor:(id)sender
{
	NSString *externalEditorName = [[NSUserDefaults standardUserDefaults] stringForKey:BezierExternalEditorName];
	
	if([externalEditorName length]) {
		NSURL *documentURL = [[self currentDocument] fileURL];
		
		if(documentURL)
			[[NSWorkspace sharedWorkspace] openFile:[documentURL path] withApplication:externalEditorName];
	} else
		[self chooseExternalEditor:nil];
}


- (IBAction)chooseExternalEditor:(id)sender
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseFiles:TRUE];
	[openPanel setResolvesAliases:TRUE];
	[openPanel setCanChooseDirectories:TRUE];
	[openPanel setAllowsMultipleSelection:TRUE];
	[openPanel setAllowedFileTypes:[NSArray arrayWithObject:@"app"]];
	[openPanel setMessage:NSLocalizedString(@"Choose an application to use editor.", @"")];
	
	[openPanel beginWithCompletionHandler:^(NSInteger result) {
		if(result == NSFileHandlingPanelOKButton) {
			NSString *applicationName = [[[openPanel URL] lastPathComponent] stringByDeletingPathExtension];
			[[NSUserDefaults standardUserDefaults] setObject:applicationName forKey:BezierExternalEditorName];
			
			[self editInExternalEditor:sender];
		}
	}];
	
}


@end