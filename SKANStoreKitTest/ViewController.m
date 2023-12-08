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
    
    __weak typeof(self) weakSelf = self;
    NSMutableArray<NSData *> *resultArray = [NSMutableArray array];
    
    /// Check  with the contry codes
    dispatch_group_t group = dispatch_group_create();
    NSArray *contryCodes = @[@"",[[NSLocale currentLocale] objectForKey:NSLocaleCountryCode]];
    for (NSString *contryCode in contryCodes) {
        dispatch_group_enter(group);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            __strong typeof(self) strongSelf = weakSelf;
            if(!strongSelf) { dispatch_group_leave(group); return; }
            [strongSelf lookUpStoreItemById:itemID contryCode:contryCode completion:^(NSData * data, NSError * error) {
                if(data != nil) { [resultArray addObject:data]; }
                dispatch_group_leave(group);
            }];
        });
    }
    
    
    SKStoreProductViewController *storeKitVC = [[SKStoreProductViewController alloc] init];
    storeKitVC.delegate = self;
    NSDictionary *dict = @{ SKStoreProductParameterITunesItemIdentifier : itemID, };
    
    // waiting for two responses
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"dispatch_group_notify");
        __block BOOL timedOut = YES;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            /// loadProductWithParameters
            [storeKitVC loadProductWithParameters:dict completionBlock:^(BOOL result, NSError * _Nullable error) {
                timedOut = NO;
                __strong typeof(self) strongSelf = weakSelf;
                if(!strongSelf) { return; }
                if(error) {
                    [strongSelf appendToMyTextView:[NSString stringWithFormat:@"loadProductWithParameters error: %@", error]];
                    return;
                }
                [strongSelf appendToMyTextView: result ? @"YES" : @"NO"];
            }];
        });
        
        /// iTunesItem 식별자에 매칭되는 데이터가 없을 경우, 지정된 시간 (3초) 이내  타임아웃 플래그가 NO로 설정되지 않으면, 스토어 키트 VC를 닫고 에러 전달
        if(![resultArray count]) {
            /// 타임아웃 3초
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if(!timedOut) { return; }
                /// 스토어 키트 창 닫기
                [storeKitVC dismissViewControllerAnimated:YES completion:nil];
            });
        }
        
        __strong typeof(self) strongSelf = weakSelf;
        if(!strongSelf) { return; }
        [strongSelf appendToMyTextView:[NSString stringWithFormat: @"present storeKitVC (%@)", itemID]];
        
        /// presentViewController
        /// 특정 버전에서는 스토어 키트를 present 를 해야지만, loadProductWithParameters의 completionBlock 호출 됨.
        /// 버전 호환성을 위해서 loadProductWithParameters 호출 후, 이어서 바로 presentViewController 호출.
        [strongSelf presentViewController:storeKitVC animated:YES completion:nil];
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
        NSLog(@"resDict: %ld", [resDict[@"resultCount"] integerValue]);
        if([resDict[@"resultCount"] integerValue] <= 0) {
            completionHandler(nil, error);
            return;
        }
        /// Success
        completionHandler(data, nil);
    }] resume];
}

@end
