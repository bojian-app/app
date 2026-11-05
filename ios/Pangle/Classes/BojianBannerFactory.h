#import <Flutter/Flutter.h>

NS_ASSUME_NONNULL_BEGIN

@interface BojianBannerFactory : NSObject <FlutterPlatformViewFactory>
- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger;
@end


@interface BojianRewardedAdBridge : NSObject
- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger;
@end

NS_ASSUME_NONNULL_END
