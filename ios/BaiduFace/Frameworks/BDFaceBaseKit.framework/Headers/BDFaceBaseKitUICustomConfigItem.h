//
//  BDFaceBaseKitUICustomConfig.h
//  BDFaceBaseKit
//
//  Created by 之哥 on 2021/8/10.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BDFaceBaseKitUICustomConfigItem : NSObject

@property (nonatomic, strong) UIColor* faceLivenessVerifyBg;                            //  采集主页面背颜色
@property (nonatomic, strong) UIColor* faceLivenessInitialBorder;                       //  初始化圆形进度条颜色
@property (nonatomic, strong) UIColor* faceLivenessProgressBorder;                      //  识别过程圆形进度条颜色
@property (nonatomic, strong) UIColor* faceLivenessTipsText;                            //  主标图颜色
@property (nonatomic, strong) UIColor* faceLivenessTipsSmallText;                       //  副标题颜色

@property (nonatomic, strong) UIColor* faceLivenessResultTitleText;                     //  人脸采集成功/失败字体颜色
@property (nonatomic, strong) UIColor* faceLivenessResultSmallTitleText;                //  失败原因提示字体颜色
@property (nonatomic, strong) UIColor* faceLivenessResultScoreText;                     //  活体分值字体颜色
@property (nonatomic, strong) UIColor* faceLivenessResultRecollectText;                 //  重新采集按钮文字颜色
@property (nonatomic, strong) UIColor* faceLivenessResultRecollectBg;                   //  重新采集按钮背景颜色
@property (nonatomic, strong) UIColor* faceLivenessResultRecollectPressedBg;            //  重新采集按钮背景颜色点击态
@property (nonatomic, strong) UIColor* faceLivenessResultReturnText;                    //  回到首页按钮文字颜色
@property (nonatomic, strong) UIColor* faceLivenessResultReturnBg;                      //  回到首页按按钮背景颜色
@property (nonatomic, strong) UIColor* faceLivenessResultbg;                            //  成功/失败主页面背颜色

@property (nonatomic, strong) UIColor* faceLivenessTimeoutDialogTitleText;              //  人脸采集超时文字颜色
@property (nonatomic, strong) UIColor* faceLivenessTimeoutDialogRecollectText;          //  重新采集按钮文字颜色
@property (nonatomic, strong) UIColor* faceLivenessTimeoutDialogRecollectBg;            //  重新采集按钮背景颜色
@property (nonatomic, strong) UIColor* faceLivenessTimeoutDialogRecollectPressedBg;     //  重新采集按钮背景颜色点击态
@property (nonatomic, strong) UIColor* faceLivenessTimeoutDialogReturnText;             //  回到首页按钮文字颜色
@property (nonatomic, strong) UIColor* faceLivenessTimeoutDialogReturnBg;               //  回到首页按按钮背景颜色
@property (nonatomic, strong) UIColor* faceLivenessTimeoutDialogBg;                     //  主页面背颜色



/*
 初始化方法
 */
-(instancetype)initWithUIConfig;

-(instancetype)initWithWhiteUIConfig;

-(instancetype)initWithBlackUIConfig;
@end

NS_ASSUME_NONNULL_END
