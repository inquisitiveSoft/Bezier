#import "AJKFileSystemObserver.h"


@implementation AJKFileSystemObserver
@synthesize rootURL, delegate, observing;


- (id)initWithURL:(NSURL *)url {
	self = [super init];
	
	if(self) {
		rootURL = [url fileReferenceURL];
		
		BOOL isDirectory = FALSE;
		if([[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDirectory] && isDirectory) {
			[self createObserver];
		} else {
			NSLog(@"Couldn't create file system observer. The '%@' directory doesn't exist.", url);
			return nil;
		}
	}
	
	return self;
}


#pragma mark -
#pragma mark Update the underlying FSEventStream


- (void)createObserver
{
	if([self rootURL]) {
		// Create File System Events Stream
		FSEventStreamContext streamContext = {0, (void *)self, NULL, NULL, NULL};
		CFAbsoluteTime secondsBetweenUpdates = (CFAbsoluteTime)[[NSUserDefaults standardUserDefaults] floatForKey:@"timeBetweenFileSystemEvent"];
		eventStream = FSEventStreamCreate(kCFAllocatorDefault, &fileSystemEventCallback, &streamContext, (CFArrayRef)[NSArray arrayWithObject:(id)(CFStringRef *)[[self rootURL] path]], kFSEventStreamEventIdSinceNow, secondsBetweenUpdates, kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagWatchRoot);
		FSEventStreamScheduleWithRunLoop(eventStream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
		// FSEventStreamSetDispatchQueue(eventStream, dispatch_get_concurrent_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
	}
}


- (void)removeObserver
{
	if(eventStream) {
		if([self isObserving])
			[self stopObserving];
		
		// Clean up the FSEventStream
		FSEventStreamInvalidate(eventStream);
		FSEventStreamRelease(eventStream);
		eventStream = nil;
	}
}


- (void)updateObserver
{
	NSArray *watchedPaths = (NSArray *)FSEventStreamCopyPathsBeingWatched(eventStream);
	
	if(watchedPaths != NULL)
		CFMakeCollectable(watchedPaths);
	
	if([watchedPaths count]) {
		NSString *watchedPath = (NSString *)[watchedPaths objectAtIndex:0];
	
		if([watchedPath isEqualToString:[[self rootURL] path]]) {
			BOOL shouldStartObserving = [self isObserving];
			[self removeObserver];
			[self createObserver];
			
			if(shouldStartObserving)
				[self startObserving];
		}
	}
}


#pragma mark -
#pragma mark Start & Stop File System Events


- (void)startObserving
{
	if(eventStream) {
		if(![self isObserving]) {
			FSEventStreamStart(eventStream);
			observing = TRUE;
		}
	}
}


- (void)stopObserving
{
	if(eventStream)
		if([self isObserving])
			FSEventStreamStop(eventStream);
	
	observing = FALSE;
}


- (void)flushUndeliveredEvents:(BOOL)synchronously {
	// Send any events that haven't but been delivered yet
	
	if(synchronously)
		FSEventStreamFlushSync(eventStream);
	else
		FSEventStreamFlushAsync(eventStream);
}


#pragma mark -

- (void)finalize {
	[self removeObserver];
}


#pragma mark -
#pragma mark The callback function

static void fileSystemEventCallback(ConstFSEventStreamRef streamRef, void *streamContext, size_t numberOfEvents, void *effectedPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[]) {
	@try {
		if(streamContext) {
			AJKFileSystemObserver *observer = (AJKFileSystemObserver *)streamContext;
			id <AJKFileSystemObserverDelegate> delegate = [observer delegate];
			//NSLog(@"observer:%@, delegate: %@", observer, delegate);
			
			if([(NSObject *)delegate respondsToSelector:@selector(fileSystemDidChange:observer:)]) {
				NSMutableArray *changes = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)numberOfEvents];
				NSUInteger index = 0;
				
				for(NSString *path in (NSArray *)effectedPaths) {
					NSString *event = nil;
					FSEventStreamEventFlags eventFlag = eventFlags[index];
					
					if((eventFlag & kFSEventStreamEventFlagNone) == kFSEventStreamEventFlagNone)
						event = AJKFileSystemEventChangeInDirectory;
					else if((eventFlag & kFSEventStreamEventFlagMustScanSubDirs) == kFSEventStreamEventFlagMustScanSubDirs)
						event = AJKFileSystemEventScanSubdirectories;
					else if((eventFlag & kFSEventStreamEventFlagMount) == kFSEventStreamEventFlagMount)
						event = AJKFileSystemEventDidMount;
					else if((eventFlag & kFSEventStreamEventFlagUnmount) == kFSEventStreamEventFlagUnmount)
						event = AJKFileSystemEventDidUnmount;
					
					
					if((eventFlag & kFSEventStreamEventFlagRootChanged) == kFSEventStreamEventFlagRootChanged) {
						event = AJKFileSystemEventPathToRootChanged;
						[observer updateObserver];
						
						NSDictionary *change = [[NSDictionary alloc] initWithObjectsAndKeys:
							path, AJKFileSystemEventEffectedPath,
							[[observer rootURL] path], AJKFileSystemEventNewPath,
							event, AJKFileSystemEventType,
							[NSNumber numberWithInteger:(NSInteger)eventIds[index]], AJKFileSystemEventID,
								nil];
						
						[changes addObject:change];
					} else {
						NSDictionary *change = [[NSDictionary alloc] initWithObjectsAndKeys:
							path, AJKFileSystemEventEffectedPath,
							event, AJKFileSystemEventType,
							[NSNumber numberWithInteger:(NSInteger)eventIds[index]], AJKFileSystemEventID,
								nil];
						
						[changes addObject:change];
					}
					
					
					#ifdef DEBUG
					// If we're in debug mode then log user and kernel dropped messages
					if((eventFlag & kFSEventStreamEventFlagUserDropped) == kFSEventStreamEventFlagUserDropped)
						NSLog(@"A file system notification was dropped (kFSEventStreamEventFlagUserDropped) for the '%@' path", path);
					else if((eventFlag & kFSEventStreamEventFlagKernelDropped) == kFSEventStreamEventFlagKernelDropped))
						NSLog(@"A file system notification was dropped (kFSEventStreamEventFlagKernelDropped) for the '%@' path", path);
					#endif
					
					index++;
				}
				
				if([changes count])
					[delegate fileSystemDidChange:[changes copy] observer:observer];
			}
		}
	}
	
	@catch (NSException *exception) {
		NSLog(@"Encountered an exception observing a file system event %@", exception);
	}
}


@end