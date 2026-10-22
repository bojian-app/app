//
//  BDFaceBaseKitRemindErrorCode.h
//  BDFaceBaseKit
//
//  Created by 之哥 on 2021/8/10.
//

#ifndef BDFaceBaseKitRemindErrorCode_h
#define BDFaceBaseKitRemindErrorCode_h

typedef NS_ENUM(NSInteger, BDFaceCompletionStatusCode) {
    BDFaceStatusSuccess                           = 1,                  // 成功
    BDFaceStatusIsRunning                         = -101,               // 正在采集图像
    BDFaceStatusCancel                            = -102,               // 取消
    BDFaceStatusSDKNotInit                        = -103,               // SDK未初始化
    BDFaceStatusSDKNotLoad                        = -105,               // SDK未加载
    BDFaceStatusNetworkError                      = -106,               // 网络错误
    BDFaceStatusIsRiskDevice                      = -201,               // 风险设备
    BDFaceStatusResultFail                        = -301,               // 构建数据异常
    BDFaceStatusCameraError                       = -302,               // 没有授权镜头
    BDFaceStatusVideoRecordingFail                = -303,               // 视频录制错误
    BDFaceStatusCropImageError                    = -305,               // 抠图失败
    BDFaceStatusEncryptFail                       = -311,               // 加密失败
    BDFaceStatusSystemVideoFail                   = -313,               // 视频录制失败-系统异常
    BDFaceStatusTimeout                           = -401,               // 超时
    BDFaceStatusColorMatchFailed                  = -402,               // 炫彩色彩错误
    BDFaceStatusVideoColorScoreFailed             = -403,               // 炫彩分数错误
    BDFaceStatusDetectSilentNoPass                = -404,               // 静默活体分数未通过
    BDFaceStatusLivenessSilentNoPass              = -405,               // 动作活体分数未通过
    BDFaceStatusLivenessActionNotMatch            = -406,               //连续检测到与提示不符动作
    BDFaceStatusPauseInBackground                 = -601,               // 切换到后台中断采集流程
};
typedef NS_ENUM(NSInteger, BDFaceInitRemindCode) {
    BDFaceInitOK                                  = 1000,              //成功
    //license错误码
    BDFaceLICENSE_NOT_INIT_ERROR                  = 1001,              //license未初始化
    BDFaceLICENSE_DECRYPT_ERROR                   = 1002,              //license数据解密失败
    BDFaceLICENSE_INFO_FORMAT_ERROR               = 1003,              //license数据格式错误
    BDFaceLICENSE_KEY_CHECK_ERROR                 = 1004,              //license-key(api-key)校验错误
    BDFaceLICENSE_ALGORITHM_CHECK_ERROR           = 1005,              //算法ID校验错误
    BDFaceLICENSE_MD5_CHECK_ERROR                 = 1006,              //MD5校验错误
    BDFaceLICENSE_DEVICE_ID_CHECK_ERROR           = 1007,              //设备ID校验错误
    BDFaceLICENSE_PACKAGE_NAME_CHECK_ERROR        = 1008,              //包名(应用名)校验错误
    BDFaceLICENSE_EXPIRED_TIME_CHECK_ERROR        = 1009,              //过期时间不正确
    BDFaceLICENSE_FUNCTION_CHECK_ERROR            = 1010,              //功能未授权
    BDFaceLICENSE_TIME_EXPIRED                    = 1011,              //授权已过期
    BDFaceLICENSE_LOCAL_FILE_ERROR                = 1012,              //本地文件读取失败
    BDFaceLICENSE_REMOTE_DATA_ERROR               = 1013,              //远程数据拉取失败
    BDFaceLICENSE_LOCAL_TIME_ERROR                = 1014,              //本地时间校验错误
    BDFaceOTHER_ERROR                             = 1015,              //其他错误
    //模型错误码
    BDFaceILLEGAL_PARAMS                          = 2001,              // 非法的参数
    BDFaceMEMORY_ALLOCATION_FAILED                = 2002,              // 内存分配失败
    BDFaceINSTANCE_IS_EMPTY                       = 2003,              // 实例对象为空
    BDFaceMODEL_IS_EMPTY                          = 2004,              // 模型内容为空
    BDFaceUNSUPPORT_ABILITY_TYPE                  = 2005,              // 不支持的能力类型
    BDFaceUNSUPPORT_INFER_TYPE                    = 2006,              // 不支持的预测库类型
    BDFaceNN_CREATE_FAILED                        = 2007,              // 预测库对象创建失败
    BDFaceNN_INIT_FAILED                          = 2008,              // 预测库对象初始化失败
    BDFaceIMAGE_IS_EMPTY                          = 2009,              // 图像数据为空
    BDFaceABILITY_INIT_FAILED                     = 2010,              // 人脸能力初始化失败
    BDFaceABILITY_UNLOAD                          = 2011,              // 能力未加载
    BDFaceABILITY_ALREADY_LOADED                  = 2012,              // 人脸能力已加载
    BDFaceNOT_AUTHORIZED                          = 2013,              // 未授权
    BDFaceABILITY_RUN_EXCEPTION                   = 2014,              // 人脸能力运行异常
    BDFaceUNSUPPORT_IMAGE_TYPE                    = 2015,              // 不支持的图像类型
    BDFaceIMAGE_TRANSFORM_FAILED                  = 2016,              // 图像转换失败
};


/**
 @param code 结果返回码
 @param extradata 预留信息
 */
typedef void(^FaceSDKInitResultBlock)(BDFaceInitRemindCode code ,NSDictionary * extradata);

/**
 @param code 结果返回码
 @param result 活体检测结果
 */
typedef void(^FaceSDKManagerResultBlock)(BDFaceCompletionStatusCode code ,NSDictionary * result);

#endif /* BDFaceBaseKitRemindErrorCode_h */
