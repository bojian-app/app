//
//  FaceSSDKLib.h
//  FaceSSDKLib v2.5.17.2
//
//  Created by Gong,Jialiang on 2018/2/26.
//  Copyright © 2018年 Gong,Jialiang. All rights reserved.
//

#import <UIKit/UIKit.h>


typedef NS_ENUM(NSInteger, DeployModeType) {
    DeployModeTypeOffline, // 离线模式
    DeployModeTypeOnline // 在线模式
};

__attribute__((visibility("default")))
@interface FaceSSDKLib : NSObject

/**
 返回单例对象
 */
+ (instancetype)sharedInstance;

/**
 启动FaceSDK

 @param licenseID faceLicenseId
 @param encryptFileName 加密Key文件
 @param readyHandler SDK启动完成，NSError为nil时启动成功
 */
- (void)initSDKWithLicenseID:(NSString *)licenseID encryptFileName:(NSString *)encryptFileName readyHandler:(void (^)(NSError *))ZInfoReadyHandler;

/**
 * 获取安全校验数据
 * @param completion 返回安全校验数据
 *                  (NSInteger)status：1 成功，-103 未初始化SDK，-311 加密失败（未初始化），-301 构建数据异常
 *                  (NSDictionary *)result：状态码为1时才有数据表示成功
 */
- (void)getSafeDataWithCompletion:(void(^)(NSInteger, NSDictionary *))completion;

// TODO: 删除
- (void)startSDKWithAppKey:(NSString *)appKey secretKey:(NSString *)secretKey deployMode:(DeployModeType)deployModeType;
/**
 启动FaceSDK

 @param DeployModeType 运行模式
 */
- (void)startSDKWithDeployMode:(DeployModeType)deployModeType;

/**
 加密模块是否已初始化
 */
- (BOOL)isEncryptInit;

/**
 加密模块初始化，初始化成功后才可进行文件加密

 @param keyBytes 加密Key指针
 @return 加密是否成功
 */
- (BOOL)encryptInitWithKeyBytes:(const char *)keyBytes;

/**
 加密文件

 @param originBytes 文件的数据指针
 @param length 数据长度
 @return 加密后的数据
 */
- (NSData*)encryptWithOriginBytes:(const char *)originBytes length:(NSUInteger)length;

/**
 图片变换加密

 @param originImage 原始图片
 @return 加密后的二进制图片
 */
- (NSData *)safeTransformImage:(NSData *)originImage;

/**
 保存face licenseid，用于后续加密操作

 @param faceLicenseId
 
 */
- (void)setFaceLicenseId:(NSString *)faceLicenseId;

/**
 图片摘要保存

 @param imageBase64 图片base64
 @param length      原始图片长度
 @return 签名图片的数量
 */
- (int)saveSumFlyty:(NSString *)imageBase64 imageLength:(NSUInteger)imageLength;

/**
 图片摘要清空
 */
- (int)clearSummary;

@end
