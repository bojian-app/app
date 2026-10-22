//
//  BDFaceBaseKitManager.h
//  BDFaceBaseKit
//
//  Created by 之哥 on 2021/8/10.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "BDFaceBaseKitUICustomConfigItem.h"
#import "BDFaceBaseKitParamsCustomConfigItem.h"
#import "BDFaceBaseKitLivenessTipCustomConfigItem.h"
#import "BDFaceBaseKitRemindErrorCode.h"

NS_ASSUME_NONNULL_BEGIN

@interface BDFaceBaseKitManager : NSObject

@property (nonatomic, strong) BDFaceBaseKitUICustomConfigItem *uiCustomConfigItem;

@property (nonatomic, strong) BDFaceBaseKitLivenessTipCustomConfigItem *livenessTipCustomConfigItem;

@property (nonatomic, strong) BDFaceBaseKitParamsCustomConfigItem *paramsCustomConfigItem;
/*
 创建单例对象
 */
+ (instancetype)sharedInstance;

/*
 初始化方法
 */
- (void) initCollectWithLicenseID:(NSString*)licenseID andLocalLicenceName:(NSString*)licenseName andEncryptKeyName:(NSString*)encryptKeyName andExtradata:(NSDictionary *)extradata callback:(FaceSDKInitResultBlock)block;

/*
 初始化会读取默认值，可以调用set方法设置
 UI配置
 */
- (void) setFaceSdkCustomUIConfig:(BDFaceBaseKitUICustomConfigItem *)configItem;

/*
 参数配置
 */
- (void) setFaceSdkCustomParamsConfig:(BDFaceBaseKitParamsCustomConfigItem *)configItem;

/*
 动作活体提示参数配置
 */
- (void) setFaceSdkCustomLivenessTipConfig:(BDFaceBaseKitLivenessTipCustomConfigItem *)configItem;

/*
 私有化参数配置
 @para type 服务下发对应的类型
 */
- (void) setQualityLevel:(NSInteger)type;

/**
 活体检测界面
 @param detectVC 启动检测的当前页面
 @param block 检测结果
 */
- (void) startWithCurrentController:(UIViewController *)detectVC andExtradata:(NSDictionary *)extradata callback:(FaceSDKManagerResultBlock)block;

/**
 * 获取 SDK 版本号信息
 */
- (NSString *)getVersion;

/**
 * 获取 SDK 构建信息
 */
- (NSString *)getSDKBuild;

/**
 * 销毁SDK
 */
- (int)uninitCollect;


/**
 *  数据埋点通知中心
 */
- (NSString *)eventTrackerNotification;

@end

NS_ASSUME_NONNULL_END
