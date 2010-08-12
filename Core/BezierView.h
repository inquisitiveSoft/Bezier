@class AJKPlugin, AJKFileSystemObserver;


@interface BezierView : NSView {
	AJKPlugin *plugin;
}

@property (assign) AJKPlugin *plugin;

- (void)drawRect:(NSRect)frameRect;

@end