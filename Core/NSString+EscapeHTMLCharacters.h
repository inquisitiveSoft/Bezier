/* Licensed under the MIT license: http://www.opensource.org/licenses/mit-license.php */
// Heavily inspired by http://google-toolbox-for-mac.googlecode.com/svn/trunk/Foundation/GTMNSString+HTML.m
// in fact the mapOfHTMLEquivalentsForCharacters table is a directly copy

@interface NSString (AJKEscapeHTMLCharacters)

- (NSString *)stringByEscapingHTML;

@end