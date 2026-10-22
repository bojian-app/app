//
//  AipCaptureCardVC.h
//  OCRLib
//  卡片识别VewController
//  Created by Yan,Xiangda on 16/11/9.
//  Copyright © 2016年 Baidu Passport. All rights reserved.
//

#ifndef AIP_CAPTURE_CARD_VC_H
#define AIP_CAPTURE_CARD_VC_H

#import <UIKit/UIKit.h>
@class BDAipOCRConfig;
@class AipNavigationController;

typedef NS_ENUM(NSInteger, CardType) {
    
    CardTypeIdCardFont = 0,
    CardTypeIdCardBack,
    CardTypeBankCard,
    CardTypeLocalIdCardFont ,
    CardTypeLocalIdCardBack,
    CardTypeLocalBankCard
};

typedef void(^AipCaptureCardVCBackAction)(void);

@interface AipCaptureCardVC : UIViewController

@property (nonatomic, assign) CardType cardType;
@property (nonatomic, copy) void (^handler)(UIImage *);
@property (nonatomic, copy) AipCaptureCardVCBackAction backAction;


/**
 * 检测身份证正面信息，并返回图片结果
 * config: 页面配置信息, 支持传空，空的话为默认配置
 */
+ (AipNavigationController *)viewControllerToDetectIdCard:(nullable BDAipOCRConfig *)config handler:(void (^)(UIImage *image))handler;
/**
 * 清空缓存
 */
+ (void) clearIdCard;

@end
#endif
