@class BezierDocument;
extern NSString *const BezierExternalEditorName;

@interface BezierAppController : NSObject {
}

@property (assign) IBOutlet NSMenuItem *editMenuItem;
@property (assign) BezierDocument *currentDocument;

- (void)awakeFromNib;

- (IBAction)editInExternalEditor:(id)sender;
- (IBAction)chooseExternalEditor:(id)sender;

@end
