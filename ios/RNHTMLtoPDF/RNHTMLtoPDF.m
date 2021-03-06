
//  Created by Christopher on 9/3/15.

#import <UIKit/UIKit.h>
#import <React/RCTConvert.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTView.h>
#import <React/UIView+React.h>
#import <React/RCTUtils.h>
#import "RNHTMLtoPDF.h"

#define PDFSize CGSizeMake(612,792)

@implementation UIPrintPageRenderer (PDF)
- (NSData*) printToPDF:(NSInteger**)_numberOfPages
{
    NSMutableData *pdfData = [NSMutableData data];
    UIGraphicsBeginPDFContextToData( pdfData, self.paperRect, nil );

    [self prepareForDrawingPages: NSMakeRange(0, self.numberOfPages)];

    CGRect bounds = UIGraphicsGetPDFContextBounds();

    for ( int i = 0 ; i < self.numberOfPages ; i++ )
    {
        UIGraphicsBeginPDFPage();
        [self drawPageAtIndex: i inRect: bounds];
    }
    
    *_numberOfPages = self.numberOfPages;

    UIGraphicsEndPDFContext();
    return pdfData;
}
@end

@implementation RNHTMLtoPDF {
    RCTEventDispatcher *_eventDispatcher;
    RCTPromiseResolveBlock _resolveBlock;
    RCTPromiseRejectBlock _rejectBlock;
    NSString *_html;
    NSString *_fileName;
    NSString *_filePath;
    NSInteger *_numberOfPages;
    CGSize _PDFSize;
    UIWebView *_webView;
    float _paddingVertical;
    float _paddingHorizontal;
    BOOL _base64;
    BOOL autoHeight;
}

RCT_EXPORT_MODULE();

+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

@synthesize bridge = _bridge;

- (instancetype)init
{
    if (self = [super init]) {
        _webView = [[UIWebView alloc] initWithFrame:self.bounds];
        _webView.delegate = self;
        [self addSubview:_webView];
        autoHeight = false;
    }
    return self;
}

RCT_EXPORT_METHOD(convert:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {

    if (options[@"html"]){
        _html = [RCTConvert NSString:options[@"html"]];
    }

    if (options[@"fileName"]){
        _fileName = [RCTConvert NSString:options[@"fileName"]];
    } else {
        _fileName = [[NSProcessInfo processInfo] globallyUniqueString];
    }

    if (options[@"directory"] && [options[@"directory"] isEqualToString:@"docs"]){
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsPath = [paths objectAtIndex:0];

        _filePath = [NSString stringWithFormat:@"%@/%@.pdf", documentsPath, _fileName];
    } else {
        _filePath = [NSString stringWithFormat:@"%@%@.pdf", NSTemporaryDirectory(), _fileName];
    }

    if (options[@"base64"] && [options[@"base64"] boolValue]) {
        _base64 = true;   
    } else {
        _base64 = false;   
    }
    
    if (options[@"height"] && options[@"width"]) {
        float width = [RCTConvert float:options[@"width"]];
        float height = [RCTConvert float:options[@"height"]];
        _PDFSize = CGSizeMake(width, height);
    } else {
        _PDFSize = PDFSize;
    }

    if (options[@"paddingVertical"]) {
        _paddingVertical = [RCTConvert float:options[@"paddingVertical"]];
    } else {
        _paddingVertical = 10.0f;
    }

    if (options[@"paddingHorizontal"]) {
        _paddingHorizontal = [RCTConvert float:options[@"paddingHorizontal"]];
    } else {
        _paddingHorizontal = 10.0f;
    }

    NSString *path = [[NSBundle mainBundle] bundlePath];
    NSURL *baseURL = [NSURL fileURLWithPath:path];

    [_webView loadHTMLString:_html baseURL:baseURL];

    _resolveBlock = resolve;
    _rejectBlock = reject;

}

- (void)webViewDidFinishLoad:(UIWebView *)awebView
{
    if (awebView.isLoading)
        return;

    UIPrintPageRenderer *render = [[UIPrintPageRenderer alloc] init];
    [render addPrintFormatter:awebView.viewPrintFormatter startingAtPageAtIndex:0];

    // Define the printableRect and paperRect
    // If the printableRect defines the printable area of the page
    CGRect paperRect = CGRectMake(0, 0, _PDFSize.width, _PDFSize.height);
    CGRect printableRect = CGRectMake(_paddingHorizontal, _paddingVertical, _PDFSize.width-(_paddingHorizontal * 2), _PDFSize.height-(_paddingVertical * 2));


    [render setValue:[NSValue valueWithCGRect:paperRect] forKey:@"paperRect"];
    [render setValue:[NSValue valueWithCGRect:printableRect] forKey:@"printableRect"];

    NSData * pdfData = [render printToPDF:&_numberOfPages];

    if (pdfData) {
        NSString *pdfBase64 = @"";
        
        [pdfData writeToFile:_filePath atomically:YES];
        if (_base64) {
            pdfBase64 = [pdfData base64EncodedStringWithOptions:0];   
        }
        NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:
                             pdfBase64, @"base64",
                             [NSString stringWithFormat: @"%ld", (long)_numberOfPages], @"numberOfPages",
                             _filePath, @"filePath", nil];
        _resolveBlock(data);
    } else {
        NSError *error;
        _rejectBlock(RCTErrorUnspecified, nil, RCTErrorWithMessage(error.description));
    }
}

@end
