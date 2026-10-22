//
//  BDFaceDef.h
//  IDLFaceSDK
//
//  Created by v_renshaolei on 2023/9/11.
//  Copyright © 2023 Baidu. All rights reserved.
//

typedef NS_ENUM(NSInteger, FaceLivenessActionType) {
    FaceLivenessActionTypeLiveEye = 0,
    FaceLivenessActionTypeLiveMouth = 1,
    FaceLivenessActionTypeLiveYawRight = 2,
    FaceLivenessActionTypeLiveYawLeft = 3,
    FaceLivenessActionTypeLivePitchUp = 4,
    FaceLivenessActionTypeLivePitchDown = 5,
    FaceLivenessActionTypeLiveUpDown = 6, //向下低头
    FaceLivenessActionTypeShakeHead = 7,
    FaceLivenessActionTypeNoAction = 8,
};

typedef NS_ENUM(NSUInteger, ResultCode) {
    ResultCodeOK,
    ResultCodePitchOutofDownRange,  //头部偏低
    ResultCodePitchOutofUpRange,   //头部偏高
    ResultCodeYawOutofLeftRange,     //头部偏左
    ResultCodeYawOutofRightRange,     //头部偏右
    ResultCodeTooBrightIllumination,   // 光线过亮
    ResultCodePoorIllumination,      //光照不足
    ResultCodeNoFaceDetected,    //没有检测到人脸
    ResultCodeFaceMoreThanOneDetected,    //检测到多个人脸
    ResultCodeDataHitOne, //采集到一张照片
    ResultCodeDataHitLast, //采集到最后一张照片
    ResultCodeImageBlured,     //图像模糊
    ResultCodeOcclusionLeftEye,  //左眼有遮挡
    ResultCodeOcclusionRightEye, //右眼有遮挡
    ResultCodeOcclusionNose,     //鼻子有遮挡
    ResultCodeOcclusionMouth,    //嘴巴有遮挡
    ResultCodeOcclusionLeftContour,  //左脸颊有遮挡
    ResultCodeOcclusionRightContour, //右脸颊有遮挡
    ResultCodeOcclusionChinCoutour,  //下颚有遮挡
    ResultCodeVerifyInitError,          //鉴权失败
    ResultCodeVerifyDecryptError,
    ResultCodeVerifyInfoFormatError,
    ResultCodeVerifyExpired,
    ResultCodeVerifyMissRequiredInfo,
    ResultCodeVerifyInfoCheckError,
    ResultCodeVerifyLocalFileError,
    ResultCodeVerifyRemoteDataError,
    ResultCodeLeftEyeClosed,
    ResultCodeRightEyeClosed,
    ResultCodeUnknowType            //未知类型
};


typedef NS_ENUM(NSUInteger, TrackResultCode) {
    TrackResultCodeOK,
    TrackResultCodeImageBlured,     // 图像模糊
    TrackResultCodePoorIllumination, // 光照不行
    TrackResultCodeNoFaceDetected,    //没有检测到人脸
    TrackResultCodeOcclusionLeftEye,  //左眼有遮挡
    TrackResultCodeOcclusionRightEye, //右眼有遮挡
    TrackResultCodeOcclusionNose,     //鼻子有遮挡
    TrackResultCodeOcclusionMouth,    //嘴巴有遮挡
    TrackResultCodeOcclusionLeftContour,  //左脸颊有遮挡
    TrackResultCodeOcclusionRightContour, //右脸颊有遮挡
    TrackResultCodeOcclusionChinCoutour,  //下颚有遮挡
    TrackResultCodeVerifyInitError,          //鉴权失败
    TrackResultCodeVerifyDecryptError,
    TrackResultCodeVerifyInfoFormatError,
    TrackResultCodeVerifyExpired,
    TrackResultCodeVerifyMissRequiredInfo,
    TrackResultCodeVerifyInfoCheckError,
    TrackResultCodeVerifyLocalFileError,
    TrackResultCodeVerifyRemoteDataError,
    TrackResultCodeUnknowType            //未知类型
};



