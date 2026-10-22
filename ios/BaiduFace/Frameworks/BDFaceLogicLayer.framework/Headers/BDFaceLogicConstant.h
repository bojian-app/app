//
//  BDFaceLogicConstant.h
//  BDFaceLogicLayer
//
//  Created by Zhang,Jian(MBD) on 2021/10/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    BDLogicCardTypeMainLandIDCard = 0, /// 大陆身份证
    BDLogicCardTypeHongkongIDCard = 1, ///  港澳居民来往内地通行证
    BDLogicCardTypeForeignerPermanentCard = 2, /// 外国人永久居留身份证
    BDLogicCardTypeChinesePassport = 3, /// 定居国外的中国公民护照
} BDLogicCardType;


#pragma mark - 入参传入的参数key 及对应的Value类型

extern NSString *BDFaceLogicServiceNameKey;             ///对应传入姓名，value type NSString
extern NSString *BDFaceLogicServiceCardNumberKey;       ///对应传入证件号，value type NSString
extern NSString *BDFaceLogicServiceCardTypeKey;         ///对应传入证件类型，value type NSNumber
extern NSString *BDFaceLogicServiceTokenKey;            ///对应传入Token，value type NSString
extern NSString *BDFaceLogicServicePlanIdKey;           ///对应传入Plan_id，value type NSString
extern NSString *BDFaceLogicServiceOnlineQualityControlKey;   ///对应传入onelinequalityControl值，为场景类型，value type NSString
extern NSString *BDFaceLogicServiceLivenessQualityControlKey; ///对应传入onelineLivenessControl值，为场景类型，value type NSString

#pragma mark - 返回的dic里的参数
extern NSString *BDFaceLogicServiceReturnKeyForResultMsg;  ///对应结果回调返回的resultMsg，value type NSNumber
extern NSString *BDFaceLogicServiceReturnKeyForResultData; ///对应结果回调返回的resultData，value type NSDictionary

/// BDFaceLogicLayer SDK 的版本号
extern NSString *BDFaceLogicLayerSDKVersion;

@interface BDFaceLogicConstant : NSObject

@end

NS_ASSUME_NONNULL_END
