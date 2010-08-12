/* Licensed under the MIT license: http://www.opensource.org/licenses/mit-license.php */

#import "NSString+EscapeHTMLCharacters.h"

@implementation NSString (AJKEscapeHTMLCharacters)
typedef struct {
	NSString *name;
	unichar character;
} HTMLCharacterDefinition;


// Originally from http://www.w3.org/TR/xhtml1/dtds.html#a_dtd_Special_characters
static HTMLCharacterDefinition mapOfHTMLEquivalentsForCharacters[] = {
	{ @"&quot;",	34 },
	{ @"&amp;",		38 },
	{ @"&apos;",	39 },
	{ @"&lt;",		60 },
	{ @"&gt;",		62 },
	{ @"&OElig;",	338 },
	{ @"&oelig;",	339 },
	{ @"&Scaron;",	352 },
	{ @"&scaron;",	353 },
	{ @"&Yuml;",	376 },
	{ @"&circ;",	710 },
	{ @"&tilde;",	732 },
	{ @"&ensp;",	8194 },
	{ @"&emsp;",	8195 },
	{ @"&thinsp;",	8201 },
	{ @"&zwnj;",	8204 },
	{ @"&zwj;",		8205 },
	{ @"&lrm;",		8206 },
	{ @"&rlm;",		8207 },
	{ @"&ndash;",	8211 },
	{ @"&mdash;",	8212 },
	{ @"&lsquo;",	8216 },
	{ @"&rsquo;",	8217 },
	{ @"&sbquo;",	8218 },
	{ @"&ldquo;",	8220 },
	{ @"&rdquo;",	8221 },
	{ @"&bdquo;",	8222 },
	{ @"&dagger;", 8224 },
	{ @"&Dagger;",	8225 },
	{ @"&permil;",	8240 },
	{ @"&lsaquo;",	8249 },
	{ @"&rsaquo;",	8250 },
	{ @"&euro;",	8364 },
};

static const size_t numberOfHTMLEquivalents = 33;


int compareCharacterDefinitions(void const *firstEquivalent, void const *secondEquivalent) {
	const HTMLCharacterDefinition firstCharacter = *(const HTMLCharacterDefinition *)firstEquivalent;
	const HTMLCharacterDefinition secondCharacter = *(const HTMLCharacterDefinition *)secondEquivalent;
	
	if(firstCharacter.character < secondCharacter.character)
		return -1;
	else if(firstCharacter.character == secondCharacter.character)
		return 0;
	
	return 1;
}


- (NSString *)stringByEscapingHTML
{
	NSInteger length = [self length];
	if(length <= 0)
		return self;
	
	NSMutableString *result = [[[NSMutableString alloc] init] autorelease];
	const char *rawCString = [self cStringUsingEncoding:NSUTF8StringEncoding];
	
	NSInteger character = 0;
	for(character = 0; character < length; ++character) {
		HTMLCharacterDefinition currentCharacter;
		currentCharacter.character = rawCString[character];
		
		HTMLCharacterDefinition *searchResult = bsearch(&currentCharacter, &mapOfHTMLEquivalentsForCharacters, numberOfHTMLEquivalents, sizeof(HTMLCharacterDefinition), compareCharacterDefinitions);
		if(searchResult != NULL) {
			if([searchResult->name isKindOfClass:[NSString class]])
				[result appendString:searchResult->name];
		} else
			[result appendFormat:@"%C", currentCharacter.character];
	}
	
	return [[result copy] autorelease];	// Return an immutable string
}


@end