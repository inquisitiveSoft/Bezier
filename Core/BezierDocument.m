#import "BezierDocument.h"
#import "BezierView.h"
#import "AJKPlugin.h"
#import "AJKFileSystemObserver.h"
#import "NSString+EscapeHTMLCharacters.h"


@implementation BezierDocument
@synthesize fileURL, plugin;


- (void)awakeFromNib
{
	[bezierView bind:@"plugin" toObject:self withKeyPath:@"plugin" options:nil];
	
	// Load consoles HTML template
	NSURL *consoleTemplateURL = [[NSBundle mainBundle] URLForResource:@"Console Template" withExtension:@"html"];
	consoleHTMLTemplate = [NSString stringWithContentsOfURL:consoleTemplateURL usedEncoding:nil error:nil];
	
	[self addObserver:self forKeyPath:@"plugin" options:NSKeyValueObservingOptionNew context:nil];
	[self addObserver:self forKeyPath:@"plugin.consoleString" options:NSKeyValueObservingOptionNew context:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshConsoleView:) name:AJKPluginResultsDidChangeNotification object:nil];
	[self refreshConsoleView:nil];
}


- (NSString *)windowNibName
{
	return @"Bezier Document";
}


- (NSString *)displayName
{
	NSString *displayName = [[bezierView plugin] name];
	if([displayName length])
		return displayName;
	
	return [[fileURL path] lastPathComponent];
}


- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
	BOOL isDirectory = FALSE;
	if(absoluteURL && [[NSFileManager defaultManager] fileExistsAtPath:[absoluteURL path] isDirectory:&isDirectory] && !isDirectory) {
		self.fileURL = absoluteURL;
		[[NSUserDefaults standardUserDefaults] setValue:[absoluteURL path] forKey:@"lastDocument"];
		
		plugin = [[AJKPlugin alloc] initWithURL:absoluteURL pluginType:AJKViewPluginType];
		
		if(plugin) {
			bezierView.plugin = plugin;
			
			directoryURL = [NSURL fileURLWithPath:[[fileURL path] stringByDeletingLastPathComponent]];
			fileSystemObserver = [[AJKFileSystemObserver alloc] initWithURL:directoryURL];	
			fileSystemObserver.delegate = self;
			[fileSystemObserver startObserving];
		
			[self showWindows];
			return TRUE;
		} else
			qLog(@"Couldn't read plugin");
	}
	
	return FALSE;
}



- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if((object == self) && [keyPath isEqualToString:@"plugin"]) {
		if([plugin pluginType] != AJKViewPluginType)
			[plugin execute:self];
	} else if((object == self) && [keyPath isEqualToString:@"plugin.consoleString"]) {
		[self refreshConsoleView:nil];
	} else
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}


- (IBAction)refreshConsoleView:(id)sender
{
	[bezierView setNeedsDisplay:TRUE];
	NSString *consoleString = ([[self plugin] consoleString] ? : @"");
	consoleString = [consoleString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	if(![consoleString length]) {
		consoleString = [[[[self plugin] output] description] stringByEscapingHTML];
		consoleString = [consoleString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	}
	
	// Format console string for HTML
	if([consoleString length]) {
		consoleString = [consoleString stringByReplacingOccurrencesOfString:@"\n" withString:@"<br />\n"];
		consoleString = [consoleString stringByReplacingOccurrencesOfString:@"\t" withString:@"&nbsp;&nbsp;&nbsp;\n"];
	}
	
	// Check that nil values don't slip through
	consoleString = consoleString ? : @"";
	consoleHTMLTemplate = consoleHTMLTemplate ? : @"";
	NSString *htmlString = [NSString stringWithFormat:consoleHTMLTemplate, consoleString];
	[[consoleView mainFrame] loadHTMLString:htmlString baseURL:directoryURL];
}


- (void)fileSystemDidChange:(NSArray *)change observer:(AJKFileSystemObserver *)fileSystemObserver
{
	self.plugin = [[AJKPlugin alloc] initWithURL:[self fileURL] pluginType:AJKViewPluginType];
	[splitView setPosition:300.0 ofDividerAtIndex:0];
	[bezierView setNeedsDisplay:TRUE];
}


@end