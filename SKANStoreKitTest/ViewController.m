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
    [self loadProduct:@"535886823"/*Google Chrome*/];
}

- (IBAction)showOverlay:(id)sender {
    [self showOverlayItem:@"535886823"];
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
    [storeKitVC loadProductWithParameters:dict completionBlock:^(BOOL result, NSError * _Nullable error) {
        __strong typeof(self) strongSelf = weakSelf;
        [strongSelf appendToMyTextView:@"completionBlock"];
        if(error) {
            [strongSelf appendToMyTextView:[NSString stringWithFormat:@"loadProductWithParameters error: %@", error]];
            return;
        }
        [strongSelf appendToMyTextView: result ? @"YES" : @"NO"];
    }];
    [self appendToMyTextView:[NSString stringWithFormat: @"present storeKitVC (%@)", itemID]];
    [self presentViewController:storeKitVC animated:YES completion:nil];
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

@end
