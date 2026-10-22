#import "BJNativeFace.h"
#import <AVFoundation/AVFoundation.h>
#import <BDFaceBaseKit/BDFaceBaseKit.h>
#import <BDFaceLogicLayer/BDFaceLogicLayer.h>

@interface BJFaceHost : UIViewController
@property(nonatomic,copy) void(^cancelAction)(void);
@property(nonatomic,assign) BOOL started;
@end
@implementation BJFaceHost
- (void)viewDidLoad {
    [super viewDidLoad]; self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.title = @"人脸核验";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    spinner.center = self.view.center; spinner.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:spinner]; [spinner startAnimating];
}
- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; if (self.started && self.navigationController.viewControllers.count == 1) [self cancel]; }
- (void)cancel { if(self.cancelAction) self.cancelAction(); }
@end

@interface BJNativeFace ()
@property(nonatomic,strong) UINavigationController *navigation;
@property(nonatomic,strong) BJFaceHost *host;
@property(nonatomic,strong) BDFaceLogicService *service;
@property(nonatomic,copy) NSString *session;
@property(nonatomic,copy) NSString *attempt;
@property(nonatomic,copy) void(^completion)(NSInteger);
@end
@implementation BJNativeFace
- (BOOL)available { return [NSBundle.mainBundle pathForResource:@"idl-license" ofType:@"face-ios"] != nil && [NSBundle.mainBundle pathForResource:@"idl-key" ofType:@"face-ios"] != nil; }
- (void)verifyToken:(NSString *)token session:(NSString *)session presenter:(UIViewController *)presenter accent:(NSNumber *)accent dark:(BOOL)dark completion:(void (^)(NSInteger))completion {
    if (self.completion) { completion(-103); return; }
    if (![self available] || presenter.presentedViewController) { completion(-103); return; }
    self.session = session; self.completion = completion;
    NSString *attempt = NSUUID.UUID.UUIDString; self.attempt = attempt;
    __weak typeof(self) weakSelf = self;
    void(^begin)(void) = ^{ dispatch_async(dispatch_get_main_queue(), ^{
        typeof(self) self = weakSelf; if (!self.completion || ![self.attempt isEqualToString:attempt]) return;
        self.host = [BJFaceHost new]; self.host.cancelAction = ^{ [weakSelf cancel]; };
        self.navigation = [[UINavigationController alloc] initWithRootViewController:self.host]; self.navigation.modalPresentationStyle = UIModalPresentationFullScreen;
        uint32_t rgb = accent.unsignedIntValue;
        UIColor *theme = [UIColor colorWithRed:((rgb >> 16) & 255)/255.0 green:((rgb >> 8) & 255)/255.0 blue:(rgb & 255)/255.0 alpha:1];
        self.navigation.navigationBar.tintColor = theme;
        [presenter presentViewController:self.navigation animated:YES completion:^{
            if (![self.attempt isEqualToString:attempt] || !self.completion) return;
            self.service = [[BDFaceLogicService alloc] initWithController:self.host face:^{} ocr:^{}];
            [[BDFaceBaseKitManager sharedInstance] initCollectWithLicenseID:@"bojian-app-face-face-ios" andLocalLicenceName:@"idl-license.face-ios" andEncryptKeyName:@"idl-key.face-ios" andExtradata:@{} callback:^(BDFaceInitRemindCode code, NSDictionary *extra) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (![self.attempt isEqualToString:attempt] || !self.completion) return;
                    if (code != 1000) { [self finish:code]; return; }
                    BDFaceBaseKitUICustomConfigItem *ui = dark ? [[BDFaceBaseKitUICustomConfigItem alloc] initWithBlackUIConfig] : [[BDFaceBaseKitUICustomConfigItem alloc] initWithWhiteUIConfig];
                    ui.faceLivenessInitialBorder = theme; ui.faceLivenessProgressBorder = theme;
                    [[BDFaceBaseKitManager sharedInstance] setFaceSdkCustomUIConfig:ui];
                    BDFaceBaseKitParamsCustomConfigItem *params = [BDFaceBaseKitManager sharedInstance].paramsCustomConfigItem;
                    params.liveness_languageType = @"ZH_CN"; params.isShowLanguageSwitch = NO;
                    params.recordAbility = NO; params.enableFaceFailVideo = NO; params.isIntoResultView = NO; params.isSaveEventLogs = NO; params.BDFACELOGSTATUS = 0;
                    [[BDFaceBaseKitManager sharedInstance] setFaceSdkCustomParamsConfig:params];
                    self.host.started = YES;
                    [self.service startCheckLiveCommonAction:@{BDFaceLogicServiceTokenKey:token, @"match_source":@0} callBack:^(int resultCode, NSDictionary *data) {
                        dispatch_async(dispatch_get_main_queue(), ^{ if ([self.attempt isEqualToString:attempt] && self.completion) [self finish:resultCode]; });
                    }];
                });
            }];
        }];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 240 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ if ([weakSelf.attempt isEqualToString:attempt]) [weakSelf finish:-401]; });
    }); };
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (status == AVAuthorizationStatusAuthorized) begin();
    else if (status == AVAuthorizationStatusNotDetermined) [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted){ if(granted) begin(); else dispatch_async(dispatch_get_main_queue(), ^{ if ([weakSelf.attempt isEqualToString:attempt]) [weakSelf finish:-302]; }); }];
    else [self finish:-302];
}
- (void)finish:(NSInteger)code {
    void(^callback)(NSInteger) = self.completion; if (!callback) return;
    self.completion = nil; self.session = nil; self.attempt = nil;
    UINavigationController *navigation = self.navigation;
    self.navigation = nil; self.host = nil; self.service = nil;
    [[BDFaceBaseKitManager sharedInstance] uninitCollect];
    if (navigation.presentingViewController) [navigation dismissViewControllerAnimated:YES completion:^{callback(code);}]; else callback(code);
}
- (void)cancel { [self finish:-102]; }
@end
