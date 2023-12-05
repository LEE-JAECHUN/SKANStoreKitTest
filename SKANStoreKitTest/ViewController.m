//
//  ViewController.m
//  SKANStoreKitTest
//
//  Created by JCLEE on 11/1/23.
//

#import <StoreKit/StoreKit.h>
#import "ViewController.h"

@interface ViewController ()<SKStoreProductViewControllerDelegate>
@property (strong, nonatomic) IBOutlet UITextView *resultTextView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.resultTextView.text = @"";
}

- (IBAction)showStoreKitVC:(id)sender {
    // 880047117 : Angry Bird2
    // 364709193 : Google Chrome
    [self loadProduct:@"880047117"];
}

- (IBAction)showOverlay:(id)sender {
    // 880047117 : Angry Bird2
    // 364709193 : Google Chrome
    [self showOverlayItem:@"880047117"];
}

- (IBAction)dismissOverlay:(id)sender {
    [self dismissOverlayItem];
}


- (void)appendToMyTextView:(NSString*)text {
    NSLog(@"%@", text);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *stringWithLineFeeds = [NSString stringWithFormat:@"%@\n", text];
        NSAttributedString* attr = [[NSAttributedString alloc] initWithString:stringWithLineFeeds];
        [[self.resultTextView textStorage] appendAttributedString:attr];
        [self.resultTextView scrollRangeToVisible:NSMakeRange([[self.resultTextView text] length], 0)];
    });
}

- (void)loadProduct:(NSString *) itemID{
    
    SKStoreProductViewController *storeKitVC = [[SKStoreProductViewController alloc] init];
    storeKitVC.delegate = self;
    
    NSDictionary *dict = @{
        SKStoreProductParameterITunesItemIdentifier : itemID,   // Google Chrome
    };
    
    __weak typeof(self) weakSelf = self;
    
    [self lookUpStoreItemById:itemID completion:^(NSData * data, NSError * error) {
        // itemID 유효성 검증
        // 참조: https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/LookupExamples.html
        if(error) { return; }
        NSError *jsonError = nil;
        NSDictionary *resDict = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
        if(resDict[@"resultCount"] == nil) { return; }
        if([resDict[@"resultCount"] integerValue] <= 0) { return; }
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [storeKitVC loadProductWithParameters:dict completionBlock:^(BOOL result, NSError * _Nullable error) {
                __strong typeof(self) strongSelf = weakSelf;
                if(!strongSelf) { return; }
                if(error) {
                    [strongSelf appendToMyTextView:[NSString stringWithFormat:@"loadProductWithParameters error: %@", error]];
                    return;
                }
                [strongSelf appendToMyTextView: result ? @"YES" : @"NO"];
            }];
        });
        
        __strong typeof(self) strongSelf = weakSelf;
        if(!strongSelf) { return; }
        [strongSelf appendToMyTextView:[NSString stringWithFormat: @"present storeKitVC (%@)", itemID]];
        /// iOS 특정 버전에서는 스토어 키트를 present 를 해야지만, loadProductWithParameters의 completionBlock 호출 됨.
        /// 버전 호환성을 위해서 loadProductWithParameters 호출 후, 이어서 바로 presentViewController 호출.
        [strongSelf presentViewController:storeKitVC animated:YES completion:nil];
    }];
}


- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController {
    [self appendToMyTextView:@"productViewControllerDidFinish"];
}

- (void)showOverlayItem:(NSString *)itemID {
    if (@available(iOS 14.0, *)) {
        UIWindowScene *windowScene = self.view.window.windowScene;
        if(!windowScene) {
            [self appendToMyTextView:@"windowScene is nil"];
            return;
        }
        SKOverlayAppConfiguration *config = [[SKOverlayAppConfiguration alloc] initWithAppIdentifier:itemID
                                                                                            position:SKOverlayPositionBottom];
        SKOverlay *overLay = [[SKOverlay alloc] initWithConfiguration:config];
        [self appendToMyTextView: [NSString stringWithFormat:@"present Overlay (%@)", itemID]];
        [overLay presentInScene:windowScene];
    } else {
        // Fallback on earlier versions
        return;
    }
}

- (void)dismissOverlayItem{
    if (@available(iOS 14.0, *)) {
        UIWindowScene *windowScene = self.view.window.windowScene;
        if(!windowScene) {
            [self appendToMyTextView:@"windowScene is nil"];
            return;
        }
        [self appendToMyTextView:@"dismiss Overlay"];
        [SKOverlay dismissOverlayInScene:windowScene];
    } else {
        // Fallback on earlier versions
        return;
    }
}

- (void)lookUpStoreItemById:(NSString *)itemIdentifier completion:(void(^)(NSData *, NSError *))completionHandler {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/lookup?id=%@", itemIdentifier]];
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    sessionConfig.timeoutIntervalForRequest = 3.0;
    sessionConfig.timeoutIntervalForResource = 3.0;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData]; // No-Cache
    [request setTimeoutInterval:3.0];
    [[session dataTaskWithRequest:request
                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (completionHandler) {
            // 메인 쓰레드에서 실행
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(data, error);
            });
        }
    }] resume];
}

@end
