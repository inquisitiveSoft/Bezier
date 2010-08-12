#import "qLog.h"


void superLog(char *sourceFile, int lineNumber, char *functionName, id format, ...)
{
	BOOL shouldLog = TRUE;
	NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
	if(standardUserDefaults)
		shouldLog = ![standardUserDefaults boolForKey:@"suppressLogging"];
	
	if(shouldLog) {
		NSMutableString *log = [[NSMutableString alloc] initWithString:@""];
		[log appendString:[NSString stringWithFormat:@"#%d ", lineNumber]];
		[log appendFormat:@"%s ", functionName];

		if([format isKindOfClass:[NSString class]]) {
			va_list trailingArguments;
			va_start(trailingArguments, format);
			NSString *expandedString = [[NSString alloc] initWithFormat:format arguments:trailingArguments];
			va_end(trailingArguments);
			
			[log appendString:expandedString];
		} else if([format isKindOfClass:[NSURL class]])
			[log appendString:[format path]];
		else if([format isKindOfClass:[NSObject class]])
			[log appendString:[format description]];
		else
			[log appendString:@"(null)"];
		
		if([log rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length != [log length])
			[log appendString:@"\n"];

		printf("%s", [log cStringUsingEncoding:NSUTF8StringEncoding]);
		[log release];
	}
}