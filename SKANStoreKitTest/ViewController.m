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
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *stringWithLineFeeds = [NSString stringWithFormat:@"%@\n", text];
        NSAttributedString* attr = [[NSAttributedString alloc] initWithString:stringWithLineFeeds];
        [[self.resultTextView textStorage] appendAttributedString:attr];
        [self.resultTextView scrollRangeToVisible:NSMakeRange([[self.resultTextView text] length], 0)];
    });
}

- (void)loadProduct:(NSString *) itemID{
    
    __weak typeof(self) weakSelf = self;
    
    __block BOOL timedOut = NO;
    /// 타임아웃 시, 실행할 코드 정의
    dispatch_block_t timeoutWorkItem = dispatch_block_create(0, ^(){
        NSLog(@"timedout");
        timedOut = YES;
        __strong typeof(self) strongSelf = weakSelf;
        if(strongSelf){
            [strongSelf appendToMyTextView:[NSString stringWithFormat:@"timeout"]];
        }
    });
    
    /// 지정된 시간 이후, 타임아웃 디스패치 큐 실행
    dispatch_time_t dispatchTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC));
    dispatch_after(dispatchTime, dispatch_get_main_queue(), timeoutWorkItem);
    
    SKStoreProductViewController *storeKitVC = [[SKStoreProductViewController alloc] init];
    storeKitVC.delegate = self;
    
    /// loadProductWithParameters:completionBlock:  메소드 호출
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        /// loadProductWithParameters
        NSDictionary *dict = @{ SKStoreProductParameterITunesItemIdentifier : itemID, };
        [storeKitVC loadProductWithParameters:dict completionBlock:^(BOOL result, NSError * _Nullable error) {
            dispatch_block_cancel(timeoutWorkItem);
            __strong typeof(self) strongSelf = weakSelf;
            if(!strongSelf || timedOut) { return; }
            if(error || result == NO) {
                [strongSelf appendToMyTextView:[NSString stringWithFormat:@"loadProductWithParameters error: %@", error]];
                return;
            }
            [strongSelf appendToMyTextView:[NSString stringWithFormat: @"present storeKitVC (%@)", itemID]];
            /// presentViewController
            /// 특정 버전에서는 스토어 키트를 present 를 해야지만, loadProductWithParameters의 completionBlock 호출 됨.
            [strongSelf presentViewController:storeKitVC animated:YES completion:nil];
        }];
    });
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

- (void)lookUpStoreItemById:(NSString *)itemIdentifier
                 contryCode:(NSString *)contryCode
                 completion:(void(^)(NSData *, NSError *))completionHandler
{
    // itunesitem 유효성 검증
    // 참조: https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/LookupExamples.html
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/lookup?id=%@", itemIdentifier]];
    if([contryCode length]) {
        url = [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/lookup?id=%@&country=%@", itemIdentifier, contryCode]];
    }
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    sessionConfig.timeoutIntervalForRequest = 2.5;
    sessionConfig.timeoutIntervalForResource = 2.5;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData]; // No-Cache
    [request setTimeoutInterval:2.5];
    [[session dataTaskWithRequest:request
                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        /// There was an exception.
        if(error != nil) {
            completionHandler(nil, error);
            return;
        }
        NSError *jsonError = nil;
        NSDictionary *resDict = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
        /// ERROR CASE #1
        if(resDict[@"resultCount"] == nil) {
            NSLog(@"resDict: %@", resDict);
            completionHandler(nil, error);
            return;
        }
        /// ERROR CASE #2
        NSLog(@"resultCount: %ld", [resDict[@"resultCount"] integerValue]);
        if([resDict[@"resultCount"] integerValue] <= 0) {
            completionHandler(nil, error);
            return;
        }
        /// Success
        completionHandler(data, nil);
    }] resume];
}

@end
