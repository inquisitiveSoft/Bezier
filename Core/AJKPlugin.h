#import "RegexKitLite.h"
@class AJKImageCollectionController, AJKImageStore;

#define AJKPluginResultsDidChangeNotification @"AJKPluginResultsDidChangeNotification"

typedef NSInteger AJKPluginScript;
enum {
	AJKFScriptPlugin = 0,
	AJKJavascriptPlugin = 1,
	AJKRubyPlugin = 2
};

typedef NSInteger AJKPluginType;
enum {
	AJKUndefinedPluginType = 0,
	AJKMenuItemPluginType = 1,
	AJKActionPluginType = 2,
	AJKViewPluginType = 4
};


@interface AJKPlugin : NSObject {
	NSURL *url;
	AJKPluginScript pluginScript;
	AJKPluginType pluginType;
	NSString *name, *uniqueIdentifier, *pluginDescription, *keyEquivalent, *consoleString;
	NSUInteger modifierFlags;
	NSNumber *versionNumber;
	id executableScript;
	NSMutableDictionary *variables;
	id output;
	NSInteger lineNumbersBeforeScriptBegins;
	BOOL isValid;
}

@property (readonly) NSURL *url;
@property (assign) NSString *uniqueIdentifier;
@property (readonly) NSString *pluginDescription, *keyEquivalent, *consoleString;
@property (readonly) NSUInteger modifierFlags;
@property (readonly) NSNumber *versionNumber;
@property (readonly) AJKPluginType pluginType;
@property (readonly) NSMutableDictionary *variables;
@property (readonly) id output;
@property (readonly) BOOL isValid;

- (id)initWithURL:(NSURL *)pluginURL;
- (id)initWithURL:(NSURL *)pluginURL pluginType:(AJKPluginType)pluginType;
- (BOOL)load;


// Parse scripts
- (BOOL)parseAsFScript:(NSString *)rawScript;
- (BOOL)parseAsJavascript:(NSString *)rawScript;

// Execute
- (BOOL)execute:(id)sender;
- (BOOL)executeFScript;
- (BOOL)executeJavascript;
- (BOOL)executeRuby;

// Properties
- (NSString *)name;
- (NSString *)description;
- (void)clearResults;

// Compare plugins by their uniqueIdentifiers
- (BOOL)isEqual:(id)plugin;

@end