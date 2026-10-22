//
//  BDFaceBaseKitFaceParamsCustomConfigItem.h
//  BDFaceBaseKit
//
//  Created by 之哥 on 2021/8/10.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, BDFaceLiveSelectType) {
    BDFaceDetectType              = 0,                // 静默活体
    BDFaceLivenessType            = 1,                // 动作活体
    BDFaceColorType               = 2,                // 炫彩活体
};


typedef NS_ENUM(NSInteger, BDFaceColorSelectType) {
    BDFaceWhiteType               = 0,                // 白色配色
    BDFaceBlackType               = 1,                // 黑色配色
    BDFaceCustomType              = 2,                // 自定义配色
};

@interface BDFaceBaseKitParamsCustomConfigItem : NSObject

/*
 人脸检测底层相关配置
 */
@property (nonatomic, assign) int     BDFACELOGSTATUS;                 //设置Log关闭开启
@property (nonatomic, assign) int     BDFACELOGTYPE;                   // 设置Log类型
@property (nonatomic, assign) int     minFaceSize;                     //需要检测的最小人脸大小
@property (nonatomic, assign) float   notRGBFaceThreshold;             //人脸置信度阈值（检测分值大于该阈值认为是人脸

/*
 人脸属性
 */
/*
【光照最小阈值】=【暗度阈值】阈值范围为0-255，推荐阈值40
阈值越小：代表质量控制越宽松
阈值越大：代表质量控制越严格（大于阈值的图片都会通过）

【光照最大阈值】=【亮度阈值】阈值范围为0-255，推荐阈值220
阈值越小：代表质量控制越严格
阈值越大：代表质量控制越宽松（小于阈值的图片都会通过
*/
@property (nonatomic, assign) float   minIllumThr;                     //光照可信度
@property (nonatomic, assign) float   maxIllumThr;                     //光照可信度
/*
【模糊阈值】阈值范围为0-1，推荐阈值0.80
阈值越小：代表质量控制越严格
阈值越大：代表质量控制越宽松（小于阈值的图片都会通过）
*/
@property (nonatomic, assign) float   blurThr;                         //模糊度
/*
【角度阈值】设置范围0-90，推荐阈值20
推荐调节范围：10~40
阈值越小：较好防御率
阈值越大：较好通过率（小于阈值的通过）
*/
@property (nonatomic, assign) float   pitchThr;                        //俯仰角
@property (nonatomic, assign) float   yawThr;                          //左右角
@property (nonatomic, assign) float   rollThr;                         //旋转角
/*
【遮挡阈值】设置范围0-1，推荐阈值0.80
推荐调节范围：0.4~1
阈值越小：较好防御率
阈值越大：较好通过率（小于阈值的无遮挡）
*/
@property (nonatomic, assign) float   occlusThreshold;                 //遮挡阈值
@property (nonatomic, assign) float   leftEyeOcclus;                   //左眼遮挡置信度
@property (nonatomic, assign) float   rightEyeOcclus;                  //右眼遮挡置信度
@property (nonatomic, assign) float   noseOcclus;                      //鼻子遮挡置信度
@property (nonatomic, assign) float   mouthOcclus;                     //嘴巴遮挡置信度
@property (nonatomic, assign) float   leftCheekOcclus;                 //左脸遮挡置信度
@property (nonatomic, assign) float   rightCheekOcclus;                //右脸遮挡置信度
@property (nonatomic, assign) float   chinOcclus;                      //下巴遮挡置信度
@property (nonatomic, assign) float   eyeCloseValue;                   //质量检测眼睛闭合阈值
/*
【活体阈值】设置范围0-1，推荐阈值0.80
阈值越小：较好通过率
阈值越大：较好防御率
*/
@property (nonatomic, assign) float   silentLiveThr;                    //  静默活体阈值（废弃）
@property (nonatomic, assign) float   LivenessThr;                      //  动作活体阈值（废弃）
@property (nonatomic, assign) float   colorLiveThr;                     //  炫瞳活体阈值（废弃）
@property (nonatomic, assign) float   imageScale;                       //  原始图缩放比例
@property (nonatomic, assign) int     maxCropImageNum;                  //  设置照片采集张数
@property (nonatomic, assign) BOOL    isCheckMouthMask;                 //  口罩开关    （此版本没有该功能）
@property (nonatomic, assign) float   mouthMaskThr;                     //  口罩过滤阈值 （此版本没有该功能）
/*
 图片输出参数
 */
@property (nonatomic, assign) float   forehead_extend;                 //额头扩展，大于等于0，0：不进行扩展
@property (nonatomic, assign) float   chin_extend;                     //下巴扩展，大于等于0，0：不进行扩展
@property (nonatomic, assign) float   enlarge_ratio;                   //人脸框与背景比例，大于等于1，1：不进行扩展
@property (nonatomic, assign) int     width;                           //输出图像宽，设置为有效值(大于0)则对图像进行缩放，否则输出原图抠图结果
@property (nonatomic, assign) int     height;                          //输出图像高，设置为有效值(大于0)则对图像进行缩放，否则输出原图抠图结果
/*
 设置界面参数
 */
@property (nonatomic, assign) BOOL    isSoundMode;                      //  声音开关
@property (nonatomic, assign) BDFaceColorSelectType colorSelectMode;    //  界面外观
@property (nonatomic, assign) BOOL    checkAgreeBtn;                    //  隐私协议开关
@property (nonatomic, assign) int     numOfLiveness;                    //  活体动作池中有几个动作 （动作选取）
@property (nonatomic, assign) int     actionLiveSelectNum;              //  需要从动作活体动作池中抽取几个动作（动作数量）
@property (nonatomic, strong) NSMutableArray  *liveActionArray;         //  动作活体列表
/*
 功能模块
 */
@property (nonatomic, assign) BOOL    isCheckColorfulLive;             //  炫彩活体
@property (nonatomic, assign) CGFloat conditionTimeout;                //  超时时间
@property (nonatomic, assign) CGFloat intervalOfVoiceRemind;           //  语音超时
@property (nonatomic, assign) CGFloat singleActionTime;                //  单个动作超时时间 默认6秒
@property (nonatomic, assign) float   minRectScale;                    //  人脸过远框比例 默认：0.3
@property (nonatomic, assign) float   maxRectScale;                    //  人脸过近框比例 默认：0.7
@property (nonatomic, assign) BOOL    recordAbility;                   //  视频录制能力
@property (nonatomic, assign) BOOL    colorJudgeAbility;               //  炫彩颜色判断能力（废弃）
@property (nonatomic, assign) BOOL    isIntoResultView;                //  进入结果页面开关
@property (nonatomic, assign) BOOL    isOpenRearCamera;                //  后置摄像头开关
@property (nonatomic, assign) BOOL    isCompressImage;                 //  是否压缩图片 默认：压缩
@property (nonatomic, assign) int     compressValue;                   //  压缩图片大小 默认：300kb
@property (nonatomic, assign) BOOL    isPopWindow;                     //  是否超时弹窗 默认：弹窗
@property (nonatomic, assign) int     outputImageType;                 //  返回图片类型 默认：0（原图） 1（抠图）
@property (nonatomic, assign) BOOL    enableUseDefinedCamera;          //  iOS13及以下版本，是否开启自定义配置，默认NO
@property (nonatomic, assign) BOOL    isStrict;                        //  眨眼、张嘴动作添加遮挡判断 默认：不严格
@property (nonatomic, assign) BOOL    isLivenessType;                  //  是否开启动作活体 默认：打开
@property (nonatomic, assign) BOOL    isOpenLocalGlobalLivenessType;   //  是否开启局部全局动作活体 默认：关闭，依赖 isLivenessType
@property (nonatomic, assign) int     localActionRandomNumber;         //  局部动作随机数量 默认为1
@property (nonatomic, assign) int     globalActionRandomNumber;        //  全局动作随机数量 默认为2
@property (nonatomic, assign) BOOL    isColorType;                     //  是否开启炫彩活体 默认：打开
@property (nonatomic, assign) BOOL    isChangeAction;                  //  是否开启动作失败切换动作 默认：关闭
@property (nonatomic, assign) BOOL    isOpenActionAntiCrack;           //  是否开启防暴力动作检测 默认：关闭
@property (nonatomic, assign) BOOL    isLivenessRandom;                //  是否开启随机动活体动作 默认：开启
@property (nonatomic, assign) BOOL    isOpenDistanceLive;              //  是否开启远近活体采集 默认: 关闭
@property (nonatomic, assign) BOOL    isSaveEventLogs;                 //  是否开启数据埋点 默认：不开启
@property (nonatomic, assign) int     recordingDuration;               //  录制长度，默认60s，范围1~60
@property (nonatomic, assign) BOOL    isPauseInBackground;             //  是否切后台中断采集流程
@property (nonatomic, assign) BOOL    enableVideoFileEmpty;           //  是否允许录制的视频文件不存在，默认false
@property (nonatomic, assign) BOOL    enableFaceFailVideo;            //  是否支持保存检测异常时的视频文件，默认false
@property (nonatomic, assign) BOOL    isShowIDCard;                   //  是否显示个人传入信息 默认不传入
@property (nonatomic, assign) BOOL    isShowLanguageSwitch;           // 语言icon显示开关,默认NO展示
@property (nonatomic, strong) NSString * liveness_languageType;       // 初始化语言 默认ZH_CN 目前支持EN英文显示
@property (nonatomic, assign) BOOL    isBrightness; //是否打光

@property (nonatomic, copy) NSString * fileDocPath;               //  模型文件路径

/**
 *  是否使用压缩视频配置，默认为NO不开启
 */
@property (nonatomic, assign) BOOL enableVideoCompressionSettings API_AVAILABLE(ios(14.0));
/**
 *自定义视频清晰度，开启压缩视频配置时生效，设置值越小录制视频体积越小。最小值1，最大值10，默认值4
 */
@property (nonatomic, assign) CGFloat videoBitRate API_AVAILABLE(ios(14.0));

@property (nonatomic, assign) NSInteger qualityLevel;

@property (nonatomic, strong) NSDictionary * qualityCustomDic;

/*
 初始化方法
 */
-(instancetype)initWithParamsConfig;
@end

NS_ASSUME_NONNULL_END
