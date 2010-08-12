#import "AJKPlugin.h"
#import <FScript/FScript.h>


@interface AJKPlugin ()
@property (assign) NSString *consoleString;
@property (assign) BOOL isValid;
@end


@implementation AJKPlugin
@synthesize url, uniqueIdentifier, pluginDescription, keyEquivalent, modifierFlags, pluginType, variables, consoleString, output, isValid;


- (id)initWithURL:(NSURL *)pluginURL
{
	return [self initWithURL:pluginURL pluginType:AJKUndefinedPluginType];
}


- (id)initWithURL:(NSURL *)pluginURL pluginType:(AJKPluginType)type
{
	self = [super init];
	
	if(self) {
		url = pluginURL;
		pluginType = type;
		keyEquivalent = nil;
		modifierFlags = 0;
		lineNumbersBeforeScriptBegins = 0;
		variables = [[NSMutableDictionary alloc] init];
		
		self.isValid = [self load];
		[[NSNotificationCenter defaultCenter] postNotificationName:AJKPluginResultsDidChangeNotification object:self];
	}
	
	return self;
}


- (BOOL)load
{
	NSString *pluginPath = [[self url] path];
	
	NSError *error = nil;
	NSStringEncoding fileEncoding = 0;
	NSString *fileContents = [NSString stringWithContentsOfFile:pluginPath usedEncoding:&fileEncoding error:&error];
	
	if(error || !([fileContents length])) {
		qLog(@"Couldn't read the plugin from %@, error: '%@'", pluginPath, [error localizedDescription]);
		return FALSE;
	}
	
	// The scanning of plugins is based on the plugins description not containing any extra curly brackets {}
	NSScanner *scanner = [NSScanner scannerWithString:fileContents];
	NSCharacterSet *curlyBracketsCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"{}"];
	NSUInteger bracketDepth = 0;
	BOOL initialOpeningBracket = TRUE;
	NSMutableString *plistString = [[NSMutableString alloc] init];
	NSString *scannedString = nil;
	NSInteger scriptBeginning = 0;
	
	do {
		if([scanner scanUpToCharactersFromSet:curlyBracketsCharacterSet intoString:&scannedString] && [scannedString length] && (bracketDepth > 0))
			[plistString appendString:scannedString];
		
		if([scanner isAtEnd])
			break;
		
		// Get the next character in the string
		scannedString = [[scanner string] substringWithRange:NSMakeRange([scanner scanLocation], 1)];
		
		// Increment the scan location
		NSUInteger scanLocation = [scanner scanLocation] + 1;
		[scanner setScanLocation:scanLocation];
		
		if([scannedString length] && ((bracketDepth > 0) || initialOpeningBracket))
			[plistString appendString:scannedString];
		
		initialOpeningBracket = FALSE;
		
		// Adjust the current bracket depth
		if([scannedString isEqualToString:@"{"])
			bracketDepth++;
		else if([scannedString isEqualToString:@"}"])
			bracketDepth--;
		
		// If we've reach the end of the property list
		if(bracketDepth <= 0)
			break;
	} while(![scanner isAtEnd]);
	
	
	NSDictionary *properties = nil;
	@try {
		properties = [plistString propertyList];
	}
	
	@catch (NSException *exception) {
		// if left, asking for the properties variable causes a crash
		properties = nil;
		
		NSScanner *exceptionScanner = [NSScanner scannerWithString:[exception reason]];
		BOOL scannerSuccess = [exceptionScanner scanUpToString:@"Old-style plist parser error:" intoString:nil];
		scannerSuccess = [exceptionScanner scanString:@"Old-style plist parser error:" intoString:nil];
		
		NSString *exceptionDetails = nil;
		scannerSuccess = [exceptionScanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&exceptionDetails];
		
		if([self pluginType] != AJKViewPluginType) {
			self.consoleString = [NSString stringWithFormat:@"Couldn\'t read the descriptive header of the %@ plugin properly. %@", [self name], exceptionDetails];
			return FALSE;
		}
	}
	
	@finally {
		if(properties) {
			// Read in values from the plugins description
			uniqueIdentifier = [properties valueForKey:@"UniqueIdentifier"];
			
			if(![uniqueIdentifier length]) {
				self.consoleString = [NSString stringWithFormat:@"Couldn't read the unique identifier for the %@ plugin", [self name]];
				return FALSE;
			}
			
			name = [properties valueForKey:@"Name"];
			pluginDescription = [properties valueForKey:@"Description"];
			
			// // Read the key description
			// NSString *keyDescription = [properties valueForKey:@"KeyEquivalent"];
			// if([keyDescription isKindOfClass:[NSString class]] && [keyDescription length])
			// 	(void)[keyDescription getKeyCharactersFromDescription:&keyEquivalent withModifierFlags:&modifierFlags];
			
			// Do a little sanity check to avoid minus version numbers
			float version = [[properties valueForKey:@"Version"] floatValue];
			if(version < 0.0)
				version = 0.0;
			
			versionNumber = [NSNumber numberWithFloat:version];
			
			// Read which kind of script to expect
			NSString *pluginScriptString = [[properties valueForKey:@"ScriptingLanguage"] lowercaseString]; // Make lowercase to prevent annoying typo warnings
			if([pluginScriptString isEqualToString:@"fscript"])
				pluginScript = AJKFScriptPlugin;
			else if([pluginScriptString isEqualToString:@"javascript"])
				pluginScript = AJKJavascriptPlugin;
			else if([pluginScriptString isEqualToString:@"ruby"])
				pluginScript = AJKRubyPlugin;
			else {
				self.consoleString = [NSString stringWithFormat:@"Unexpected executable script type for the '%@' plugin", [self name]];
				return FALSE;
			}
			
			NSString *pluginTypeString = [properties valueForKey:@"PluginType"];
			if([pluginTypeString length]) {
				NSArray *components = [pluginTypeString componentsSeparatedByString:@", "];	
				for(NSString *typeAsString in components) {
					if([typeAsString isEqualToString:@"Menu Item"])
						pluginType += AJKMenuItemPluginType;
					else if([typeAsString isEqualToString:@"Action"])
						pluginType += AJKActionPluginType;
					else if([typeAsString isEqualToString:@"View"])
						pluginType += AJKViewPluginType;
				}
			}
		}
	}

	if(properties)
		scriptBeginning = [scanner scanLocation];
	else
		scriptBeginning = 0;
		
	NSString *rawScript = [fileContents substringFromIndex:scriptBeginning];
	
	// Test if the executable script is empty
	if(![rawScript length]) {
		NSLog(@"The script section of the plugin was empty");
		return FALSE;
	}
	
	if(properties) {
		[scanner setScanLocation:0];
		[scanner setCharactersToBeSkipped:nil];
	
		lineNumbersBeforeScriptBegins = 0;
		NSCharacterSet *newlineCharacterSet = [NSCharacterSet newlineCharacterSet];
		while([scanner scanLocation] < scriptBeginning) {
			[scanner scanUpToCharactersFromSet:newlineCharacterSet intoString:nil];
		
			NSString *tempararyString = nil;
			while(![scanner isAtEnd]
				&& [scanner scanCharactersFromSet:newlineCharacterSet intoString:&tempararyString]
				&& ([scanner scanLocation] < scriptBeginning))
				lineNumbersBeforeScriptBegins += [tempararyString length];
		}
	}
	
	if(pluginScript == AJKFScriptPlugin) {
		if([self parseAsFScript:rawScript])
			return TRUE;
		
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"logPluginErrors"])
			qLog(@"Couldn't parse FScript plugin '%@'", [self name]);
	}
	
	return FALSE;
}


#pragma mark -
#pragma mark Parse

- (BOOL)parseAsFScript:(NSString *)rawScript
{
	BOOL success = TRUE;
	NSString *blockReadyString = [NSString stringWithFormat:@"[\n\n%@\n\n]", rawScript];
	
	@try {
		NSURL *errorBlockURL = [[NSBundle mainBundle] URLForResource:@"Error" withExtension:@"block" subdirectory:nil];
		NSString *errorBlockString = [NSString stringWithContentsOfURL:errorBlockURL usedEncoding:nil error:nil];
		FSBlock *errorBlock = [errorBlockString asBlock];
		[blockReadyString asBlockOnError:errorBlock];
	}
	
	@catch (NSException *exception) {

		if([exception isKindOfClass:NSClassFromString(@"FSReturnSignal")]) {
			id result = [(id)exception result];
			
			if([result isKindOfClass:[NSDictionary class]]) {
				NSDictionary *outputDictionary = (NSDictionary *)result;
				NSString *errorMessage = [outputDictionary valueForKey:@"errorMessage"];
				NSInteger syntaxErrorStart = [[outputDictionary valueForKey:@"syntaxErrorStart"] integerValue];
				NSInteger syntaxErrorEnd = [[outputDictionary valueForKey:@"syntaxErrorEnd"] integerValue];
				
				NSInteger scriptLength = [blockReadyString length] - 2;
				if(syntaxErrorStart < 1)
					syntaxErrorStart = 1;
				else if(syntaxErrorStart > (scriptLength - 1))
					syntaxErrorStart = (scriptLength - 1);
				
				NSInteger errorLength = syntaxErrorEnd - syntaxErrorStart;
				if(errorLength < 0)
					errorLength = 0;
				else if((syntaxErrorStart + errorLength) > scriptLength)
					errorLength = (scriptLength - syntaxErrorStart);
				
				NSRange errorRange = NSMakeRange(syntaxErrorStart, (errorLength >= 0) ? errorLength : 0);
				
				// Scan through and count line numbers
				NSScanner *scanner = [NSScanner scannerWithString:blockReadyString];
				[scanner setCharactersToBeSkipped:nil];
				NSCharacterSet *newlineCharacterSet = [NSCharacterSet newlineCharacterSet];
				NSInteger lineNumber = 0;
				while(![scanner isAtEnd] && ([scanner scanLocation] < syntaxErrorStart)) {
					[scanner scanUpToCharactersFromSet:newlineCharacterSet intoString:nil];
					
					NSString *tempararyString = nil;
					while(![scanner isAtEnd]
						&& [scanner scanCharactersFromSet:newlineCharacterSet intoString:&tempararyString]
						&& ([scanner scanLocation] < syntaxErrorStart))
						lineNumber += [tempararyString length];
				}
				
				lineNumber -= 3;	// To discount for the extra newlines added in the creation of the block
				lineNumber += lineNumbersBeforeScriptBegins;
				
				// Create ranges for the surrounding strings
				NSInteger frontPadding = 40;
				NSInteger endPadding = 60;
				
				NSInteger frontPaddingStart = syntaxErrorStart - frontPadding;
				if(frontPaddingStart <= 1)
					frontPaddingStart = 1;
				else if(frontPaddingStart > ([blockReadyString length] - 2))
					frontPaddingStart = ([blockReadyString length] - 2);

				NSInteger endPaddingEnd = syntaxErrorEnd + endPadding;
				if(endPaddingEnd > ([blockReadyString length] - 2))
					endPaddingEnd = ([blockReadyString length] - 2);
				else if(endPaddingEnd > ([blockReadyString length] - 2))
					endPaddingEnd = ([blockReadyString length] - 2);
				
				[scanner setScanLocation:frontPaddingStart];
				if(![scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:nil])
					[scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:nil];
				frontPaddingStart = [scanner scanLocation];
				
				[scanner setScanLocation:endPaddingEnd];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:nil];
				endPaddingEnd = [scanner scanLocation];
				
				NSRange frontPaddingRange = NSMakeRange(frontPaddingStart, ((syntaxErrorStart-frontPaddingStart) >= 0) ? (syntaxErrorStart-frontPaddingStart) : 0);
				NSRange endPaddingRange = NSMakeRange(syntaxErrorEnd, ((endPaddingEnd - syntaxErrorEnd) >= 0) ? (endPaddingEnd-syntaxErrorEnd) : 0);
				
				// Create the output string
				NSMutableString *outputString = [[NSMutableString alloc] initWithFormat:@"%@ on line %d", errorMessage, lineNumber];
				if(errorLength > 0) {
					[outputString appendString:@"<code>"];
					if(frontPaddingRange.length > 0)
						[outputString appendString:[blockReadyString substringWithRange:frontPaddingRange]];
					
					if(errorRange.length > 0)
						[outputString appendFormat:@"<b>%@</b>", [blockReadyString substringWithRange:errorRange]];
					
					if(endPaddingRange.length > 0)
						[outputString appendString:[blockReadyString substringWithRange:endPaddingRange]];
					
					[outputString appendString:@"</code>"];
				}
				
				NSLog(@"outputString %@", outputString);
				self.consoleString = [outputString copy];
			} else
				qLog(@"Unexpected output from Error.block");
			
			executableScript = nil;
			success = FALSE;
		}
	}
	
	
	@finally {
		if(success)
			executableScript = rawScript;
	}
	
	return success;
}


- (BOOL)parseAsJavascript:(NSString *)rawScript
{
	@try {
		NSInteger rawScriptLength = [rawScript length];
		if(rawScriptLength) {
			// Find a main() function
			NSError *error = nil;
			NSArray *componentsMatched = [rawScript componentsMatchedByRegex:@"function\\\\smain()\\\\s{" options:2 inRange:NSMakeRange(0, rawScriptLength) capture:0 error:&error];
			
			if([componentsMatched count])
				executableScript = rawScript;
			else
				executableScript = [NSString stringWithFormat:@"function main() {\n%@\n}", rawScript];
		} else
			executableScript = nil;
	}
	
	@catch (NSException *exception) {
	}
	
	/*
	@finally {
		
	}
	*/
	
	return FALSE;
}



#pragma mark -
#pragma mark Execute

- (BOOL)execute:(id)sender
{
	if([self isValid]) {
		switch (pluginScript) {
			case AJKFScriptPlugin:
				return [self executeFScript];
				break;
			
			case AJKJavascriptPlugin:
				return [self executeJavascript];
				break;
			
			case AJKRubyPlugin:
				return [self executeRuby];
				break;
		}
	}
	
	return FALSE;
}


- (BOOL)executeFScript
{
	if(![executableScript length])
		return FALSE;
	
	BOOL success = FALSE;
	
	FSInterpreter *interpreter = [[FSInterpreter alloc] init];
	FSInterpreterResult *result = nil;
	
	@try {

		[interpreter setObject:NSApp forIdentifier:@"NSApp"];
		[interpreter setObject:[NSApp delegate] forIdentifier:@"Controller"];
		[interpreter setObject:self forIdentifier:@"plugin"];
		
		for(NSString *key in [variables allKeys]) {
			if([key isKindOfClass:[NSString class]] && [key length]) {
				[interpreter setObject:[variables objectForKey:key] forIdentifier:key];				
			}
		}
		
		result = [interpreter execute:executableScript];
		success = [result isOK];
		
		if(success) {
			// Read and output the log variable
			BOOL found = FALSE;
			id log = [interpreter objectForIdentifier:@"log" found:&found];
			
			if(found && [log isKindOfClass:[NSObject class]]) {
				output = [log description];
				[[NSNotificationCenter defaultCenter] postNotificationName:AJKPluginResultsDidChangeNotification object:self];
			} else
				self.consoleString = @"(empty)";
		} else
			self.consoleString = [NSString stringWithFormat:@"%@ , character %d\n", [result errorMessage], [result errorRange].location];

	}
	
	@catch (NSException *exception) {
		NSString *errorType = @"Unexpected Error";
		if([result isExecutionError])
			errorType = @"execution";
		else if([result isSyntaxError])
			errorType = @"syntax";
		
		self.consoleString = [NSString stringWithFormat:@"Encountered an %@ error while executing the '%@' plugin: %@", errorType, [self name], exception];
	}
	
	return success;
}


- (BOOL)executeJavascript
{
	
	@try {
		//		JSValueRef returnValue = [[JSCocoa sharedController] callJSFunctionNamed:executableScript withArgumentsArray:arguments];
		//	qLog(@"returnValue: %@", returnValue);
	}
	
	@catch(NSException *exception) {
		return FALSE;
	}
	
	return FALSE;
}


- (BOOL)executeRuby
{
//	@try {
//		//		id result = [[MacRuby sharedRuntime] evaluateString:[expressionTextView string]];
//	}
//	
//	@catch (NSException *exception) {
//		qLog(@"Encountered an '%@' error while executing the '%@' plugin. Reason: %@\n%@", exception, [self name], [exception reason], [[[exception userInfo] objectForKey:@"backtrace"] description]);
		return FALSE;
//	}
//	
//	return FALSE;
}



#pragma mark -
#pragma mark Properties


- (NSString *)name
{
	if([name length])
		return name;
	
	return [[[self url] path] lastPathComponent];
}


- (NSString *)description
{
	NSString *scriptingLanguageString = @"Unknown Language";
	switch(pluginScript) {
		case AJKFScriptPlugin:
			scriptingLanguageString = @"FScript";
			break;
		
		case AJKJavascriptPlugin:
			scriptingLanguageString = @"Javascript";
			break;
		
		case AJKRubyPlugin:
			scriptingLanguageString = @"Ruby";
			break;
	}
	
	NSString *pluginTypeString = [NSString stringWithFormat:@"%@%@%@",
	([self pluginType] & AJKMenuItemPluginType) ? @"Menu Item" : @"",
	(([self pluginType] & AJKMenuItemPluginType) && ([self pluginType] & AJKActionPluginType)) ? @", " : @"",
	([self pluginType] & AJKActionPluginType) ? @"Action" : @"",
	nil];
	
	return [NSString stringWithFormat:@"'%@' is a %@ plugin, written in %@", [self name], pluginTypeString, scriptingLanguageString];
}


- (NSNumber *)versionNumber
{
	if(versionNumber)
		return versionNumber;
	
	// Any version number should trump a plugin without one
	return [NSNumber numberWithFloat:0.0];
}


- (void)clearResults
{
	output = nil;
}


#pragma mark -

- (BOOL)isEqual:(id)plugin
{
	if([plugin isKindOfClass:[self class]])
		return [[self uniqueIdentifier] isEqualToString:plugin];
	
	return FALSE;
}


@end