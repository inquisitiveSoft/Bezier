#import <CoreServices/CoreServices.h>
#import "AJKFileSystemObserverDelegate.h"

// Change dictionary keys
#define AJKFileSystemEventEffectedPath @"AJKFileSystemEventEffectedPath"
#define AJKFileSystemEventNewPath @"AJKFileSystemEventNewPath"
#define AJKFileSystemEventType @"AJKFileSystemEventType"
#define AJKFileSystemEventID @"AJKFileSystemEventID"

#define AJKFileSystemEventChangeInDirectory @"AJKFileSystemEventChangeInDirectory"
#define AJKFileSystemEventScanSubdirectories @"AJKFileSystemEventScanSubdirectories"
#define AJKFileSystemEventPathToRootChanged @"AJKFileSystemEventPathToRootChanged"
#define AJKFileSystemEventDidMount @"AJKFileSystemEventDidMount"
#define AJKFileSystemEventDidUnmount @"AJKFileSystemEventDidUnmount"


@interface AJKFileSystemObserver : NSObject {
	NSURL *rootURL;
	FSEventStreamRef eventStream;
	id <AJKFileSystemObserverDelegate> delegate;
	BOOL observing;
}

@property (assign) id <AJKFileSystemObserverDelegate> delegate;
@property (assign, getter=isObserving) BOOL observing;
@property (readonly) NSURL *rootURL;

- (id)initWithURL:(NSURL *)url;

// Update the underlying file system event stream
- (void)createObserver;
- (void)removeObserver;
- (void)updateObserver;	// Replaces the current event stream if the path to the root directory has changed

// Start & Stop file system events
- (void)startObserving;
- (void)stopObserving;
- (void)flushUndeliveredEvents:(BOOL)synchronously;	// Send any events that haven't but been delivered yet

// Clear up the event stream when the observer is no longer required
- (void)finalize;

// The callback function for system events
static void fileSystemEventCallback(ConstFSEventStreamRef streamRef, void *streamContext, size_t numberOfEvents, void *affectedPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[]);


@end