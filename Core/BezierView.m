#import "BezierView.h"
#import "AJKPlugin.h"


@implementation BezierView
@synthesize plugin;


- (void)drawRect:(NSRect)frameRect
{
	[[NSColor whiteColor] setFill];
	NSRectFill(frameRect);
	
	[[NSColor lightGrayColor] setFill];
	
	if([plugin pluginType] == AJKViewPluginType) {
		[[plugin variables] setObject:self forKey:@"view"];
		[plugin execute:self];
	}
}

- (BOOL)isFlipped
{
	return TRUE;
}



@end