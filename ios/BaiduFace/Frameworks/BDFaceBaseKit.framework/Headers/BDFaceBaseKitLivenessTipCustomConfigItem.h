//
//  BDFaceBaseKitLivenessTipCustomConfigItem.h
//  BDFaceBaseKit
//
//  Created by 之哥 on 2021/8/10.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BDFaceBaseKitLivenessTipCustomConfigItem : NSObject

@property (nonatomic, copy) NSString * faceLivenessZoomInText;                 //请将脸部靠近一点
@property (nonatomic, copy) NSString * faceLivenessZoomOutText;                //请将脸部离远一点
@property (nonatomic, copy) NSString * faceLivenessHeadUpText;                 //请略微抬头
@property (nonatomic, copy) NSString * faceLivenessHeadDownText;               //请略微低头
@property (nonatomic, copy) NSString * faceLivenessHeadLeftText;               //请略微向左转头
@property (nonatomic, copy) NSString * faceLivenessHeadRightText;              //请略微向右转头
@property (nonatomic, copy) NSString * faceLivenessLeftEyeOccludedText;        //左眼有遮挡
@property (nonatomic, copy) NSString * faceLivenessRightEyeOccludedText;       //右眼有遮挡
@property (nonatomic, copy) NSString * faceLivenessNoseOccludedText;           //鼻子有遮挡
@property (nonatomic, copy) NSString * faceLivenessMouthOccludedText;          //嘴部有遮挡
@property (nonatomic, copy) NSString * faceLivenessLeftCheekOccludedText;      //左脸颊有遮挡
@property (nonatomic, copy) NSString * faceLivenessRightCheekOccludedText;     //右脸颊有遮挡
@property (nonatomic, copy) NSString * faceLivenessChinOccludedText;           //下巴有遮挡
@property (nonatomic, copy) NSString * faceLivenessIlliumPoorText;             //请使环境光线再亮些
@property (nonatomic, copy) NSString * faceLivenessIlliumMuchText;             //请使环境光线再暗些
@property (nonatomic, copy) NSString * faceLivenessblurredText;                //请握稳手机，视线正对屏幕
@property (nonatomic, copy) NSString * faceLivenessLeftEyeNotOpenText;         //左眼未睁开
@property (nonatomic, copy) NSString * faceLivenessRightEyeNotOpenText;        //右眼未睁开
@property (nonatomic, copy) NSString * faceLivenessActionEyeText;              //眨眨眼
@property (nonatomic, copy) NSString * faceLivenessActionMouthText;            //张张嘴
@property (nonatomic, copy) NSString * faceLivenessActionHeadLeftText;         //向左缓慢转头
@property (nonatomic, copy) NSString * faceLivenessActionHeadRightText;        //向右缓慢转头
@property (nonatomic, copy) NSString * faceLivenessActionHeadUpText;           //缓慢抬头
@property (nonatomic, copy) NSString * faceLivenessActionHeadDownText;         //缓慢低头
@property (nonatomic, copy) NSString * faceLivenessActionUpDownText;           //上下点头
@property (nonatomic, copy) NSString * faceLivenessActionYawText;              //左右摇头
@property (nonatomic, copy) NSString * faceLivenessScreenWillFlash;            //屏幕即将闪烁，请保持正脸
@property (nonatomic, copy) NSString * faceLivenessScreenColorChanging;        //变光中，请保持正脸
@property (nonatomic, copy) NSString * faceLivenessCompletionText;             //非常好
@property (nonatomic, copy) NSString * faceLivenessMovetoFrameText;            //把脸移入框内
@property (nonatomic, copy) NSString * faceLivenessFacialFaceCorrectionText;   //请调整人脸
@property (nonatomic, copy) NSString * faceLivenessVerifyFailedText;           //验证失败
@property (nonatomic, copy) NSString * faceLivenessKeepFace;                   //请保持正脸
@property (nonatomic, copy) NSString * faceLivenessFaceCovered;                //脸部有遮挡
@property (nonatomic, copy) NSString * faceLivenessFaceMoreThan;               //检测多个人脸

@property (nonatomic, copy) NSString * faceLivenessKeepStillText;              //请保持不动
@property (nonatomic, copy) NSString * faceLivenessLittleZoomInText;           //请略微靠近
@property (nonatomic, copy) NSString * faceLivenessLittleZoomOutText;          //请略微远离
@property (nonatomic, copy) NSString * faceLivenessForFaceSlowMoveText;        //将采集远景，请缓慢移动远离
@property (nonatomic, copy) NSString * faceLivenessNearFaceSlowMoveText;       //将采集近景，请缓慢移动靠近


/*
 初始化方法
 */
-(instancetype)initWithLivenessTipConfig;

-(instancetype)initWithEnLivenessTipConfig;

-(instancetype)initWithCnLivenessTipConfig;

@end

NS_ASSUME_NONNULL_END
