#import "PangleAdsPlugin.h"
#import <BUAdSDK/BUAdSDK.h>

static NSString *const kChannelName = @"cn.kelance.bojian/pangle_ads";
static NSString *const kBannerViewType = @"cn.kelance.bojian/pangle_banner";

// 提前声明，供 Banner 视图在实现之前引用。
@interface PangleAdsPlugin (TopViewController)
+ (UIViewController *)topViewController;
@end

#pragma mark - Banner PlatformView

@class PangleBannerView;

@interface PangleBannerView : NSObject <FlutterPlatformView, BUMNativeExpressBannerViewDelegate>
@property(nonatomic, strong) UIView *container;
@property(nonatomic, strong) BUNativeExpressBannerView *bannerAd;
- (instancetype)initWithFrame:(CGRect)frame
                       slotId:(NSString *)slotId
                        width:(CGFloat)width
                       height:(CGFloat)height;
@end

@implementation PangleBannerView

- (instancetype)initWithFrame:(CGRect)frame
                       slotId:(NSString *)slotId
                        width:(CGFloat)width
                       height:(CGFloat)height {
  self = [super init];
  if (self) {
    _container = [[UIView alloc] initWithFrame:frame];
    _container.backgroundColor = [UIColor clearColor];
    if (slotId.length == 0) {
      return self;
    }
    UIViewController *root = [PangleAdsPlugin topViewController];
    _bannerAd = [[BUNativeExpressBannerView alloc]
        initWithSlotID:slotId
        rootViewController:root
        adSize:CGSizeMake(width, height)];
    _bannerAd.delegate = self;
    [_bannerAd loadAdData];
  }
  return self;
}

- (UIView *)view {
  return self.container;
}

- (void)dealloc {
  _bannerAd.delegate = nil;
  [_bannerAd removeFromSuperview];
  _bannerAd = nil;
}

- (void)nativeExpressBannerAdViewDidLoad:(BUNativeExpressBannerView *)bannerAdView {
  bannerAdView.frame = self.container.bounds;
  [self.container addSubview:bannerAdView];
}

- (void)nativeExpressBannerAdView:(BUNativeExpressBannerView *)bannerAdView
           didLoadFailWithError:(NSError *)error {
  NSLog(@"[PangleBanner] load fail: %@", error);
  [self.container removeFromSuperview];
}

- (void)nativeExpressBannerAdViewDidBecomeVisible:(BUNativeExpressBannerView *)bannerAdView {
}

- (void)nativeExpressBannerAdViewDidClick:(BUNativeExpressBannerView *)bannerAdView {
}

- (void)nativeExpressBannerAdView:(BUNativeExpressBannerView *)bannerAdView
             dislikeWithReason:(NSArray<BUDislikeWords *> *)filterwords {
  [bannerAdView removeFromSuperview];
}

- (void)nativeExpressBannerAdViewDidRemoved:(BUNativeExpressBannerView *)nativeExpressAdView {
  [nativeExpressAdView removeFromSuperview];
}

@end

@interface PangleBannerViewFactory : NSObject <FlutterPlatformViewFactory>
@property(nonatomic, weak) NSObject<FlutterBinaryMessenger> *messenger;
@end

@implementation PangleBannerViewFactory

- (NSObject<FlutterMessageCodec> *)createArgsCodec {
  return [FlutterStandardMessageCodec sharedInstance];
}

- (NSObject<FlutterPlatformView> *)createWithFrame:(CGRect)frame
                                    viewIdentifier:(int64_t)viewId
                                         arguments:(id _Nullable)args {
  NSDictionary *params = [args isKindOfClass:[NSDictionary class]] ? args : @{};
  NSString *slotId = params[@"slotId"];
  CGFloat width = [params[@"width"] doubleValue] ?: 300.0;
  CGFloat height = [params[@"height"] doubleValue] ?: 150.0;
  return [[PangleBannerView alloc] initWithFrame:frame
                                          slotId:slotId
                                           width:width
                                          height:height];
}

@end

#pragma mark - Plugin

@interface PangleAdsPlugin () <BUSplashAdDelegate>
@property(nonatomic, weak) NSObject<FlutterBinaryMessenger> *messenger;
@property(nonatomic, strong) BUSplashAd *splashAd;
@property(nonatomic, strong) UIView *splashContainer;
@property(nonatomic, assign) BOOL initializing;
@property(nonatomic, assign) BOOL initialized;
@property(nonatomic, copy) FlutterResult initResult;
@end

@implementation PangleAdsPlugin

+ (UIViewController *)topViewController {
  UIWindow *window = nil;
  for (UIWindow *candidate in [UIApplication sharedApplication].windows) {
    if (candidate.isKeyWindow) {
      window = candidate;
      break;
    }
  }
  UIViewController *controller = window.rootViewController;
  while (controller.presentedViewController) {
    controller = controller.presentedViewController;
  }
  return controller;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:kChannelName
                                  binaryMessenger:[registrar messenger]];
  PangleAdsPlugin *instance = [[PangleAdsPlugin alloc] init];
  instance.messenger = [registrar messenger];
  [registrar addMethodCallDelegate:instance channel:channel];

  PangleBannerViewFactory *factory = [[PangleBannerViewFactory alloc] init];
  factory.messenger = [registrar messenger];
  [registrar registerViewFactory:factory withId:kBannerViewType];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  if ([@"init" isEqualToString:call.method]) {
    [self initAd:call result:result];
  } else if ([@"isInitialized" isEqualToString:call.method]) {
    result(@(self.initialized));
  } else if ([@"showSplash" isEqualToString:call.method]) {
    [self showSplash:call result:result];
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (void)initAd:(FlutterMethodCall *)call result:(FlutterResult)result {
  NSString *appId = call.arguments[@"appId"];
  if (appId.length == 0) {
    result([FlutterError errorWithCode:@"NO_APP_ID" message:@"缺少穿山甲应用 ID" details:nil]);
    return;
  }
  if (self.initialized) {
    result(@(YES));
    return;
  }
  if (self.initializing) {
    result(@(NO));
    return;
  }
  self.initializing = YES;
  self.initResult = result;

  BUAdSDKConfiguration *configuration = [BUAdSDKConfiguration configuration];
  configuration.appID = appId;
  // GroMore 聚合开关在不同 SDK 小版本上的名字有差异，这里用 KVC 兜底，
  // 避免因为单个属性名变动就把编译打断。
  @try {
    [configuration setValue:@(YES) forKey:@"useMediation"];
  } @catch (NSException *exception) {
    NSLog(@"[PangleAds] useMediation 设置失败: %@", exception.reason);
  }

  __weak typeof(self) weakSelf = self;
  [BUAdSDKManager startWithAsyncCompletionHandler:^(BOOL success, NSError *_Nullable error) {
    __strong typeof(weakSelf) self = weakSelf;
    if (!self) return;
    self.initializing = NO;
    self.initialized = success;
    if (!success) {
      NSLog(@"[PangleAds] SDK 初始化失败: %@", error);
    }
    FlutterResult pending = self.initResult;
    self.initResult = nil;
    if (pending) {
      pending(@(success));
    }
  }];
}

- (void)showSplash:(FlutterMethodCall *)call result:(FlutterResult)result {
  NSString *slotId = call.arguments[@"slotId"];
  NSNumber *timeout = call.arguments[@"timeoutMs"];
  if (!self.initialized || slotId.length == 0 || self.splashAd != nil) {
    result(@(NO));
    return;
  }
  UIViewController *root = [PangleAdsPlugin topViewController];
  if (root == nil) {
    result(@(NO));
    return;
  }
  self.splashAd = [[BUSplashAd alloc] initWithSlotID:slotId adSize:CGSizeZero];
  self.splashAd.delegate = self;
  self.splashAd.supportCardView = YES;
  self.splashAd.supportZoomOutView = YES;
  self.splashAd.tolerateTimeout = timeout ? timeout.doubleValue / 1000.0 : 3.0;
  [self.splashAd loadAdData];
  result(@(YES));
}

#pragma mark - BUSplashAdDelegate

- (void)splashAdLoadSuccess:(BUSplashAd *)splashAd {
  [splashAd showSplashViewInRootViewController:[PangleAdsPlugin topViewController]];
}

- (void)splashAdLoadFail:(BUSplashAd *)splashAd error:(BUAdError *_Nullable)error {
  NSLog(@"[PangleAds] 开屏加载失败: %@", error);
  [self releaseSplash];
}

- (void)splashAdDidShow:(BUSplashAd *)splashAd {
}

- (void)splashAdDidClick:(BUSplashAd *)splashAd {
}

- (void)splashAdDidClose:(BUSplashAd *)splashAd closeType:(BUSplashAdCloseType)closeType {
  [self releaseSplash];
}

- (void)splashAdViewControllerDidClose:(BUSplashAd *)splashAd {
  [self releaseSplash];
}

- (void)splashCardReadyToShow:(BUSplashAd *)splashAd {
  [splashAd showSplashViewInRootViewController:[PangleAdsPlugin topViewController]];
}

- (void)splashCardViewDidClose:(BUSplashAd *)splashAd {
  [self releaseSplash];
}

- (void)releaseSplash {
  if (self.splashAd) {
    [self.splashAd.mediation destoryAd];
  }
  self.splashAd.delegate = nil;
  self.splashAd = nil;
}

@end
