@class AJKFileSystemObserver;

@protocol AJKFileSystemObserverDelegate

- (void)fileSystemDidChange:(NSArray *)change observer:(AJKFileSystemObserver *)fileSystemObserver;

@end