#import "BojianBannerFactory.h"
#import <BUAdSDK/BUAdSDK.h>
#import <math.h>

@interface BojianAdPrivacy : NSObject <BUAdSDKPrivacyProvider>
@end
@implementation BojianAdPrivacy
- (BOOL)canUseLocation { return NO; }
- (BOOL)canUseWiFiBSSID { return NO; }
- (NSDictionary *)privacyConfig {
  return @{@"motion_info": @"0", @"bum_advertiser_tracking_enabled": @"0",
           @"bum_disable_use_phone_status": @"1", @"kBUMPrivacyCanUseCarrier": @0};
}
@end

typedef void (^BojianAdReady)(NSString *error);

@interface BojianAdSDK : NSObject
@property(nonatomic) BOOL started, complete, mediation;
@property(nonatomic, copy) NSString *appID;
@property(nonatomic, copy) NSString *failure;
@property(nonatomic, strong) NSMutableArray<BojianAdReady> *waiters;
@property(nonatomic, strong) NSTimer *deadline;
+ (instancetype)shared;
- (void)start:(NSString *)appID mediation:(BOOL)mediation ready:(BojianAdReady)ready;
@end

@implementation BojianAdSDK
+ (instancetype)shared {
  static BojianAdSDK *sdk;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ sdk = [BojianAdSDK new]; sdk.waiters = [NSMutableArray new]; });
  return sdk;
}
- (void)finish:(NSString *)failure {
  if (self.complete) return;
  self.complete = YES;
  self.failure = failure;
  [self.deadline invalidate];
  self.deadline = nil;
  NSArray<BojianAdReady> *callbacks = [self.waiters copy];
  [self.waiters removeAllObjects];
  for (BojianAdReady callback in callbacks) callback(failure);
}
- (void)start:(NSString *)appID mediation:(BOOL)mediation ready:(BojianAdReady)ready {
  NSAssert(NSThread.isMainThread, @"Ad lifecycle must run on the main thread");
  if (self.started && (![self.appID isEqualToString:appID] || self.mediation != mediation)) {
    ready(@"configuration_changed");
    return;
  }
  if (self.complete) { ready(self.failure); return; }
  [self.waiters addObject:[ready copy]];
  if (self.started) return;
  self.started = YES;
  self.appID = appID;
  self.mediation = mediation;
  self.deadline = [NSTimer scheduledTimerWithTimeInterval:8 repeats:NO block:^(NSTimer *timer) {
    [self finish:@"init_timeout"];
  }];
  BUAdSDKConfiguration *config = [BUAdSDKConfiguration configuration];
  config.appID = appID;
  config.useMediation = mediation;
  config.privacyProvider = [BojianAdPrivacy new];
  config.customIdfa = @"00000000-0000-0000-0000-000000000000";
  config.allowModifyAudioSessionSetting = NO;
  config.mediation.limitPersonalAds = @1;
  config.mediation.limitProgrammaticAds = @1;
  config.mediation.forbiddenIDFA = @1;
  config.mediation.allowUploadDeviceInfo = NO;
  config.debugLog = @0;
  [BUAdSDKManager startWithAsyncCompletionHandler:^(BOOL success, NSError *error) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self finish:success ? nil : [NSString stringWithFormat:@"init_failed:%ld", (long)error.code]];
    });
  }];
}
@end

@interface BojianBannerView : NSObject <FlutterPlatformView, BUMNativeExpressBannerViewDelegate>
@property(nonatomic, strong) UIView *container;
@property(nonatomic, strong) FlutterMethodChannel *channel;
@property(nonatomic, strong) BUNativeExpressBannerView *banner;
@property(nonatomic, strong) NSTimer *deadline;
@property(nonatomic) BOOL requested, ended, rendered, mediation;
- (instancetype)initWithFrame:(CGRect)frame identifier:(int64_t)identifier messenger:(NSObject<FlutterBinaryMessenger> *)messenger;
@end

@implementation BojianBannerView
- (instancetype)initWithFrame:(CGRect)frame identifier:(int64_t)identifier messenger:(NSObject<FlutterBinaryMessenger> *)messenger {
  self = [super init];
  if (!self) return nil;
  _container = [[UIView alloc] initWithFrame:frame];
  _container.hidden = YES;
  _container.clipsToBounds = YES;
  _channel = [FlutterMethodChannel methodChannelWithName:[NSString stringWithFormat:@"cn.kelance.bojian/banner/%lld", identifier] binaryMessenger:messenger];
  __weak typeof(self) weakSelf = self;
  [_channel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
    BojianBannerView *view = weakSelf;
    if (!view) { result(nil); return; }
    if ([call.method isEqualToString:@"show"]) {
      if (view.rendered && !view.ended) view.container.hidden = NO;
      result(nil);
    } else if ([call.method isEqualToString:@"hide"]) {
      view.container.hidden = YES;
      result(nil);
    } else if ([call.method isEqualToString:@"load"]) {
      result(nil);
      if (view.requested || view.ended) return;
      view.requested = YES;
      NSDictionary *args = [call.arguments isKindOfClass:NSDictionary.class] ? call.arguments : @{};
      NSString *appID = [args[@"appId"] isKindOfClass:NSString.class] ? args[@"appId"] : @"";
      NSString *slotID = [args[@"slotId"] isKindOfClass:NSString.class] ? args[@"slotId"] : @"";
      if (![args[@"consent"] isEqual:@YES] || !appID.length || !slotID.length) {
        [view end:@"failed" reason:@"not_permitted"];
        return;
      }
      view.mediation = [args[@"useMediation"] isEqual:@YES];
      view.deadline = [NSTimer scheduledTimerWithTimeInterval:12 repeats:NO block:^(NSTimer *timer) {
        [weakSelf end:@"failed" reason:@"load_timeout"];
      }];
      [[BojianAdSDK shared] start:appID mediation:view.mediation ready:^(NSString *error) {
        if (!weakSelf || weakSelf.ended) return;
        if (error) [weakSelf end:@"failed" reason:error];
        else [weakSelf load:slotID];
      }];
    } else result(FlutterMethodNotImplemented);
  }];
  return self;
}
- (UIView *)view { return self.container; }
- (UIViewController *)presenter {
  UIViewController *controller = self.container.window.rootViewController;
  if (!controller) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
      if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
      for (UIWindow *window in ((UIWindowScene *)scene).windows) {
        if (window.isKeyWindow) { controller = window.rootViewController; break; }
      }
      if (controller) break;
    }
  }
  while (controller.presentedViewController && !controller.presentedViewController.isBeingDismissed) {
    controller = controller.presentedViewController;
  }
  return controller;
}
- (void)load:(NSString *)slotID {
  UIViewController *controller = [self presenter];
  if (!controller) { [self end:@"failed" reason:@"view_controller_unavailable"]; return; }
  BUAdSlot *slot = [BUAdSlot new];
  slot.ID = slotID;
  slot.mediation.mutedIfCan = YES;
  self.banner = [[BUNativeExpressBannerView alloc] initWithSlot:slot rootViewController:controller adSize:CGSizeMake(300, 150)];
  self.banner.frame = CGRectMake(0, 0, 300, 150);
  self.banner.delegate = self;
  [self.container addSubview:self.banner];
  [self.banner loadAdData];
}
- (void)markReady:(BUNativeExpressBannerView *)banner {
  if (!NSThread.isMainThread) {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf markReady:banner]; });
    return;
  }
  if (self.ended || self.rendered || banner != self.banner) return;
  CGFloat height = CGRectGetHeight(banner.bounds);
  if (!isfinite(height) || height <= 0 || height > 600) {
    [self end:@"failed" reason:@"invalid_ad_size"];
    return;
  }
  self.rendered = YES;
  [self.deadline invalidate];
  self.deadline = nil;
  NSLog(@"BojianBannerAds: banner ready (300 x %.1f)", height);
  [self.channel invokeMethod:@"loaded" arguments:@{@"height": @(height)}];
}
- (void)releaseAd {
  self.ended = YES;
  self.container.hidden = YES;
  [self.deadline invalidate];
  self.deadline = nil;
  self.banner.delegate = nil;
  [self.banner.mediation destory];
  [self.banner removeFromSuperview];
  self.banner = nil;
}
- (void)end:(NSString *)event reason:(NSString *)reason {
  if (!NSThread.isMainThread) {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf end:event reason:reason]; });
    return;
  }
  if (self.ended) return;
  [self releaseAd];
  NSLog(@"BojianBannerAds: %@ %@", event, reason);
  [self.channel invokeMethod:event arguments:reason];
}
- (void)dealloc {
  [self releaseAd];
  [self.channel setMethodCallHandler:nil];
}
- (void)nativeExpressBannerAdViewDidLoad:(BUNativeExpressBannerView *)banner {
  if (self.mediation) [self markReady:banner];
}
- (void)nativeExpressBannerAdViewRenderSuccess:(BUNativeExpressBannerView *)banner {
  [self markReady:banner];
}
- (void)nativeExpressBannerAdView:(BUNativeExpressBannerView *)banner didLoadFailWithError:(NSError *)error {
  [self end:@"failed" reason:[NSString stringWithFormat:@"load_failed:%ld", (long)error.code]];
}
- (void)nativeExpressBannerAdViewRenderFail:(BUNativeExpressBannerView *)banner error:(NSError *)error {
  [self end:@"failed" reason:[NSString stringWithFormat:@"render_failed:%ld", (long)error.code]];
}
- (void)nativeExpressBannerAdView:(BUNativeExpressBannerView *)banner dislikeWithReason:(NSArray<BUDislikeWords *> *)reasons {
  [self end:@"closed" reason:@"disliked"];
}
- (void)nativeExpressBannerAdViewDidRemoved:(BUNativeExpressBannerView *)banner {
  [self end:@"closed" reason:@"removed"];
}
- (void)nativeExpressBannerAdNeedLayoutUI:(BUNativeExpressBannerView *)banner canvasView:(BUMCanvasView *)canvas {
  // This placement uses SDK-rendered banners, never an empty native creative.
  [self end:@"failed" reason:@"native_feed_creative_not_supported"];
}
@end

@implementation BojianBannerFactory {
  NSObject<FlutterBinaryMessenger> *_messenger;
}
- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger {
  self = [super init];
  if (self) _messenger = messenger;
  return self;
}
- (NSObject<FlutterPlatformView> *)createWithFrame:(CGRect)frame viewIdentifier:(int64_t)viewId arguments:(id)args {
  return [[BojianBannerView alloc] initWithFrame:frame identifier:viewId messenger:_messenger];
}
@end
