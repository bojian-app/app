//
//  FaceSDKManager.h
//  IDLFaceSDK
//
//  Created by Tong,Shasha on 2017/5/15.
//  Copyright © 2017年 Baidu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "BDFaceDef.h"

@class FaceInfo;
@class FaceLivenessState;
@class FaceCropImageInfo;

@interface FaceSDKManager : NSObject
/* 超时时间 */
@property (nonatomic, assign) CGFloat conditionTimeout;
/* 语音超时*/
@property (nonatomic, assign) CGFloat intervalOfVoiceRemind;
/* 单个动作超时时间 默认6秒 */
@property (nonatomic, assign) CGFloat singleActionTime;
/* 单个动作剩余时间 */
@property (nonatomic, assign) CGFloat singleActionRemainTime;
/* 输出图像个数 */
@property (nonatomic, assign) int imageNum;
/* 图像加密类型，默认0
 0：输出未加密图片
 1：输出加密图片
 2：输出加密和未加密图片
 */
@property (nonatomic, assign) int imageEncrypteType;
/*  人脸过远框比例 默认：0.3 */
@property (nonatomic, assign) float minRectScale;
/*  人脸过近框比例 默认：0.5 */
@property (nonatomic, assign) float maxRectScale;
/*  视频录制能力 */
@property (nonatomic, assign) BOOL recordAbility;
/*  炫彩颜色判断能力 */
@property (nonatomic, assign) BOOL colorJudgeAbility;
/* 图片计数器，用来计当前图片的数量*/
@property (nonatomic, assign) int currentNum;
/*  活体检测阈值 默认：0.8 */
@property (nonatomic, assign) float silentLiveThresholdValue;
/*  活体检测阈值 默认：0.8 */
@property (nonatomic, assign) float livenessThresholdValue;
/*  活体检测阈值 默认：0.8 */
@property (nonatomic, assign) float colorLiveThresholdValue;
/*  是否压缩图片 默认：压缩 */
@property (nonatomic, assign) BOOL isCompressImage;
/*  压缩图片大小 默认：300kb */
@property (nonatomic, assign) int compressValue;
/*  是否超时弹窗 默认：弹窗 */
@property (nonatomic, assign) BOOL isPopWindow;
/*  眨眼、张嘴动作添加遮挡判断 默认：不严格 */
@property (nonatomic, assign) BOOL isStrict;
/*  数据埋点 默认：不开启 */
@property (nonatomic, assign) BOOL isSaveEventLogs;

/*  是否开启动作失败切换动作 默认：关闭 */
@property (nonatomic, assign) BOOL isChangeAction;

/*  是否开启防暴力动作检测 默认：关闭 */
@property (nonatomic, assign) BOOL isOpenActionAntiCrack;

/*  是否开启随机动活体动作 默认：开启 */
@property (nonatomic, assign) BOOL  isLivenessRandom;

/* 中英文切换标识  默认 ZH_CN*/
@property (nonatomic, copy) NSString *languageType;
/*  安全加密key 默认：idl-key.face-ios */
@property (nonatomic ,strong) NSString *encryptKey;
/* 活体、炫彩剩余时间*/
@property (nonatomic, assign) CGFloat livenessColorTime;

/*是否开启局部动作活体 默认：关闭*/
@property (nonatomic, assign) BOOL isOpenLocalGlobalLivenessType;

/*局部动作随机数量 默认为1*/
@property (nonatomic, assign) int localActionRandomNumber;

/*全局动作随机数量 默认为2*/
@property (nonatomic, assign) int globalActionRandomNumber;

/*  远程拉取模型沙盒地址 */
@property (nonatomic, copy) NSString * fileDocPath;



+ (instancetype)sharedInstance;

/**
 * 获取版本号
 */
- (NSString *)getVersion;

/**
 *  重置计数器
 */
- (void)reset;


- (void)resetDelay;

/**
 *  重置时间
 */
- (void)resetTime;

/**
 *  SDK鉴权方法-文件授权
 *  SDK鉴权方法 必须在使用其他方法之前设置，否则会导致SDK不可用
 *
 *  @param licenseID 授权ID
 *  @param licensePath 本地鉴权文件路径
 *  @param remoteAuthorize 是否远程更新过期鉴权文件
 */
- (int)setLicenseID:(NSString *)licenseID andLocalLicenceFile:(NSString *)licensePath andRemoteAuthorize:(BOOL)remoteAuthorize;
/**
 *  设置clientId
 */
- (void)setBCEClientId:(NSString *)clientId clientSecret:(NSString *)clientSecret;
/**
 *  初始化采集功能
 */
- (int) initCollect;

/**
 *  卸载采集功能
 */
- (int)uninitCollect;

/**
 *  判断授权是否通过，true 表示通过，false 表示不通过
 */
- (BOOL)canWork;

/**
 *  设置预测库耗能模式
 *  默认 LITE_POWER_NO_BIND
 */
- (void)setLitePower:(int)litePower;

/**
 *  需要检测的最大人脸数目
 *  默认1
 */
- (void)setMaxDetectNum:(int)detectNum ;

/**
 *  需要检测的最小人脸大小
 *  默认100
 */
- (void)setMinFaceSize:(int)width;

/**
 *  人脸置信度阈值（检测分值大于该阈值认为是人脸
 *  RGB
 *  默认 0.5f
 */
- (void)setNotFaceThreshold:(CGFloat)thr ;

/**
 *  质量检测遮挡阈值
 *  默认0.5
 */
- (void)setOccluThreshold:(CGFloat)thr ;

/**
 * 质量检测遮挡阈值-左眼遮挡置信度
 * 默认0.31
 */
-(void)setOccluLeftEyeThreshold:(CGFloat)thr ;

/**
 * 眼睛闭合置信度
 * 默认0.7
 */
-(void)setEyeCloseThreshold:(CGFloat)thr ;

/**
 * 质量检测遮挡阈值- 右眼遮挡置信度
 * 默认0.31
 */
-(void)setOccluRightEyeThreshold:(CGFloat)thr ;

/**
 * 质量检测遮挡阈值-鼻子遮挡置信度
 * 默认0.27
 */
-(void)setOccluNoseThreshold:(CGFloat)thr ;

/**
 * 质量检测遮挡阈值-嘴巴遮挡置信度
 * 默认0.2
 */
-(void)setOccluMouthThreshold:(CGFloat)thr ;

/**
 * 质量检测遮挡阈值-左脸遮挡置信度
 * 默认0.48
 */
-(void)setOccluLeftCheekThreshold:(CGFloat)thr ;

/**
 * 质量检测遮挡阈值-右脸遮挡置信度
 * 默认0.48
 */
-(void)setOccluRightCheekThreshold:(CGFloat)thr ;

/**
 * 质量检测遮挡阈值-下巴遮挡置信度
 * 默认0.4
 */
-(void)setOccluChinThreshold:(CGFloat)thr ;


/**
 * 最大光照阈值
 */
- (void)setMaxIllumThreshold:(CGFloat)thr;

/**
 * 最小光照阈值
 */
- (void)setMinIllumThreshold:(CGFloat)thr ;

/**
 *  质量检测模糊阈值
 *  默认0.5
 */
- (void)setBlurThreshold:(CGFloat)thr ;

/**
 *  姿态检测阈值
 *  默认pitch=12，yaw=12，row=10
 */
- (void)setEulurAngleThrPitch:(float)pitch yaw:(float)yaw roll:(float)roll ;

/**
 * 输出图像个数
 * 默认3
 */
- (void)setMaxCropImageNum:(int)imageNum ;

/**
 * 输出图像宽，设置为有效值(大于0)则对图像进行缩放，否则输出原图抠图结果
 * 默认 480
 */
- (void)setCropFaceSizeWidth:(CGFloat)width ;

/**
 * 输出图像高，设置为有效值(大于0)则对图像进行缩放，否则输出原图抠图结果
 * 默认 680
 */
- (void)setCropFaceSizeHeight:(CGFloat)height ;

/**
 * 输出图像，下巴扩展，大于等于0，0：不进行扩展
 * 默认0.1
 */
- (void)setCropChinExtend:(CGFloat)chinExtend ;

/**
 * 输出图像，额头扩展，大于等于0，0：不进行扩展
 * 默认0.2
 */
- (void)setCropForeheadExtend:(CGFloat)foreheadExtend ;

/**
 * 输出图像，人脸框与背景比例，大于等于1，1：不进行扩展
 * 默认1.5f
 */
- (void)setCropEnlargeRatio:(float)cropEnlargeRatio;

/**
 * 动作超时配置
 */
- (void)setConditionTimeout:(CGFloat)timeout ;

/**
 * 语音间隔提醒配置
 */
- (void)setIntervalOfVoiceRemind:(CGFloat)timeout;

/**
 * 是否开启静默活体，默认false
 */
// - (void)setIsCheckSilentLive:(BOOL)isCheck;

/**
 * 静默活体阈值配置，默认0.8。
 * 大于阈值返回图片，低于阈值返回未检测到人脸
 */
// - (void)setSilentLiveThreshold:(CGFloat)thr ;

/**
 * 是否开启口罩检测，非动作活体检测模型true，动作活体检测模型false
 */
- (void)setIsCheckMouthMask:(BOOL)isCheck;

/**
 * 口罩检测阈值配置，默认0.8。
 * 大于阈值判定为戴口罩，低于阈值判定为未戴口罩
 */
- (void)setMouthMaskThreshold:(CGFloat)thr ;

/**
 * 设置原始图片缩放比例，默认1不缩放，scale 阈值0~1
 */
- (void)setImageWithScale:(CGFloat)scale;


/**
 *  人脸过远框比例 默认：0.4
 */
- (void)setMinRect:(float) minRectScale;
/**
 *  人脸过近框比例 默认：0.5
 */
- (void)setMaxRect:(float) maxRectScale;

/**
 *  活体检测阈值 默认：0.8
 */
- (void)setSilentLiveThresholdValue:(float) liveThresholdValue;

/**
 *  活体检测阈值 默认：0.8
 */
- (void)setlivenessThresholdValue:(float) liveThresholdValue;

/**
 *  活体检测阈值 默认：0.8
 */
- (void)setcolorliveThresholdValue:(float) liveThresholdValue;

/**
 *  视频录制能力 默认：关闭
 */
- (void)setRecordAbility:(BOOL) recordAbility;

/**
 *  炫彩颜色判断能力 默认：关闭
 */
- (void)setColorJudgeAbility:(BOOL) colorJudgeAbility;

/**
 *  图片是否压缩 默认：压缩
 */
- (void)setIsCompressImage:(BOOL)isCompressImage;

/**
 *  图片压缩系数单位KB 默认：300Kb
 */
- (void)setCompressValue:(int) compressValue;

/**
 *  是否超时弹窗 默认：弹窗
 */
- (void)setIsPopWindow:(BOOL) isPopWindow;

/**
 *  质量检测闭眼阈值设置 默认：0.8
 */
- (void)setEyeCloseValue:(float) eyeCloseValue;

/**
 *  眨眼、张嘴动作添加遮挡判断 默认：不严格
 */
- (void)setIsStrict:(BOOL) isStrict;
/**
 *  数据埋点 默认：不开启
 */
-(void)setIsSaveEventLogs:(BOOL) isSaveEventLogs;
/**
 *  安全加密key 默认：idl-key.face-ios
 */
-(void)setEncryptKey:(NSString *) encryptKey;

/*  是否开启防暴力动作检测 默认：关闭 */
- (void)setIsOpenActionAntiCrack:(BOOL)isOpenActionAntiCrack;

/*  是否开启动作失败切换动作 默认：关闭 */
- (void)setIsChangeAction:(BOOL)isChangeAction;

/*  中英文切换 默认：ZH_CN*/
- (void)setLanguageType:(NSString *)languageType;
/**
 * 采集动作验证
 * @param image 检测的图片
 * @param isOriginal 是否返回原始图片
 * @param completion 判断采集是否完成，人脸信息状态是否正常
 */
- (void)detectWithImage:(UIImage *)image isRreturnOriginalValue:(BOOL) isOriginal completion:(void (^)(FaceInfo *faceinfo, ResultCode resultCode))completion;

/**
 * 动作活体动作验证
 * @param image 检测的图片
 * @param actionLiveType 当前要求做的动作
 * @param completion 判断当前动作是否完成，人脸信息状态是否正常
 */
- (void)livenessWithImage:(UIImage *)image withAction:(FaceLivenessActionType)actionLiveType completion:(void (^)(FaceInfo *faceinfo, FaceLivenessState *state, ResultCode resultCode))completion;

/**
 * 炫彩动作验证
 * @param image 检测的图片
 * @param isOriginal 是否返回原始图片
 * @param colorQuality 炫彩当前颜色是否通过质量检测
 * @param livenessFinished 活体动作是否完成，YES表示在动作+炫彩 NO  表示单独炫彩
 * @param completion 判断采集是否完成，人脸信息状态是否正常
 */
- (void)colorWithImage:(UIImage *)image isRreturnOriginalValue:(BOOL) isOriginal isColorQuality:(BOOL)colorQuality livenessFinished:(BOOL)livenessFinished completion:(void (^)(FaceInfo *faceinfo, ResultCode resultCode))completion;

/**
 * 六颜色炫彩图片得分接口
 * @param image 当前采集图片
 * @param color 当前采集图片对应颜色
 * @param completion 返回错误码，0为成功
 */
- (void)colorWithImage:(UIImage *)image color:(NSString *)color completion:(void (^)(FaceInfo *faceinfo, ResultCode resultCode))completion;


/**
 * 远近活体动作验证
 * @param image 检测的图片
 * @param isOriginal 是否返回原始图片
 * @param completion 判断采集是否完成，人脸信息状态是否正常
 */
- (void)distanceLivenessWithImage:(UIImage *)image isRreturnOriginalValue:(BOOL)isOriginal isQuality:(BOOL)isQuality completion:(void (^)(FaceInfo *faceinfo, ResultCode resultCode))completion;

/**
 * 远近活体动作验证 例如 眨眼 张张嘴
 * @param image 检测的图片
 * @param actionLiveType  活体动作类型
 * return   ResultCode   状态码
 */
- (ResultCode)distanceLivenessActionWithImage:(UIImage *)image ActionLiveType:(FaceLivenessActionType)actionLiveType;

- (void)colorLiveGetDataCompletion:(void (^)(FaceInfo *faceinfo, ResultCode resultCode))completion;

/*
 图片压缩
 */
- (NSData *)compressImageDataWithMaxLength:(NSUInteger)maxLength image:(UIImage *)image;

@end

@interface FaceLivenessState : NSObject
/**
 *  动作活体-眨眨眼
 */
@property(nonatomic, assign) BOOL isLiveEye;
/**
 *  动作活体-张张嘴
 */
@property(nonatomic, assign) BOOL isLiveMouth;
/**
 *  动作活体-向左转头
 */
@property(nonatomic, assign) BOOL isLiveYawLeft;
/**
 *  动作活体-向右转头
 */
@property(nonatomic, assign) BOOL isLiveYawRight;
/**
 *  动作活体-抬头
 */
@property(nonatomic, assign) BOOL isLivePitchUp;
/**
 *  动作活体-低头
 */
@property(nonatomic, assign) BOOL isLivePitchDown;
/**
 * 动作活体-摇摇头
 */
@property(nonatomic, assign) BOOL isLiveShakeHead;
/**
 * 动作活体-点点头
 */
@property(nonatomic, assign) BOOL isLiveUpDown;
@end

@interface FaceCropImageInfo : NSObject
/**
 *  基于质量检测，姿态角度，对图片得分
 */
@property (nonatomic, assign) float qualityScore;
/**
 *  离线RGB 静默活体得分
 */
@property (nonatomic,assign) float silentliveScore;
/**
 *  炫彩活体RGB 炫彩活体当前颜色
 */
@property (nonatomic,assign) int  outPutColorFace;

/**
 *  炫彩活体RGB 炫彩活体当前颜色
 */
@property (nonatomic,assign) float  outPutColorScore;
/**
 *  炫彩活体RGB 炫彩活体得分
 */
@property (nonatomic,assign) float colorAuraliveScore;
/**
 *  采集到的矫正，调整宽高图片，会有宽高
 */
@property (nonatomic ,strong) UIImage *cropImageWithBlack;
/**
 *  加密采集到的矫正，调整宽高图片，会有宽高
 */
@property (nonatomic ,strong) NSString *cropImageWithBlackEncryptStr;
/**
 *  未加密采集到的矫正，调整宽高图片，会有宽高
 */
@property (nonatomic ,strong) NSString *cropImageWithBlackStr;
/**
 *  原始图片
 */
@property (nonatomic ,strong) UIImage *originalImage;
/**
 *  加密原始图片
 */
@property (nonatomic ,strong) NSString *originalImageEncryptStr;
/**
 *  原始图片
 */
@property (nonatomic ,strong) NSString *originalImageStr;
/*
 * bestimage生成 时间戳
 */
@property (nonatomic ,assign) NSTimeInterval ts;
/**
 * 标签 : 远近 near far / 质量  0 1 2
 */
@property (nonatomic ,copy) NSString *tag;

/**
 *  排序规则
 */
- (NSComparisonResult)compareWithImageInfo:(FaceCropImageInfo *)info;
/*
 输出bestimage属性,qualityScore、silentliveScore、ts
 */
- (NSDictionary *)toDictioanry;
@end

@interface FaceInfo : NSObject
/**
 *  人脸在图片中的位置
 */
@property (nonatomic, assign) CGRect faceRect;
/**
 *  人脸track 中的faceid
 */
@property (nonatomic, assign) NSInteger faceId;
/**
 *  人脸72关键点
 */
@property (nonatomic, strong) NSArray * landMarks;
/**
 *  人脸角度
 */
@property (nonatomic, assign) float angle;
/**
 *  人脸质量-光照置信度，通过quality 方法调用获取
 */
@property (nonatomic,assign) float illum;

/**
 *  人脸质量-模糊置信度，通过quality 方法调用获取
 */
@property (nonatomic,assign) float blur;
/**
 * 人脸上下偏转角，通过headpose 方法调用获取
 */
@property (nonatomic, assign) float pitch;

/**
 * 人脸左右偏转角，通过headpose 方法调用获取
 */
@property (nonatomic, assign) float yaw;

/**
 * 人脸平行平面内的头部旋转角，通过headpose 方法调用获取
 */
@property (nonatomic, assign) float roll;

/**
 *  离线RGB 静默活体得分
 */
@property (nonatomic,assign) float silentliveScore;

/**
 *  炫彩活体RGB 炫彩活体当前颜色
 */
@property (nonatomic,assign) int  outPutColorFace;

/**
 *  炫彩活体RGB 炫彩活体当前颜色
 */
@property (nonatomic,assign) float  outPutColorScore;

/**
 *  炫彩活体RGB 炫彩活体结果
 */
@property (nonatomic,assign) float  outPutColorResult;

/**
 *  炫彩活体RGB 炫彩活体得分
 */
@property (nonatomic,assign) float colorAuraliveScore;

/**
 *  人脸检测得分
 */
@property (nonatomic, assign) CGFloat score;

/**
 * 输出图片结构体，包含图片质量分数，裁剪没有黑边的图片，裁剪有黑边的图片，未裁剪图片，原始图
 */
@property (nonatomic, strong) FaceCropImageInfo * cropImageInfo;

/**
 *  炫彩活体-标志炫彩活体当前的质量检测通过
 */
@property(nonatomic, assign) BOOL colorQuality;

/*
 输出faceinfo基本信息
 */
- (NSDictionary *)toDictioanry;


@end

@interface FaceDetectObject : NSObject

@property (nonatomic, strong) UIImage *faceImage;
@property (nonatomic, copy) NSString *color;
@property (nonatomic, assign) FaceLivenessActionType actionLiveType;
@property (nonatomic, assign) BOOL originalValue;
@property (nonatomic, assign) BOOL isColorQuality;
@property (nonatomic, assign) BOOL isDistanceQuality;
@property (nonatomic, assign) BOOL livenessFinished;


@end
