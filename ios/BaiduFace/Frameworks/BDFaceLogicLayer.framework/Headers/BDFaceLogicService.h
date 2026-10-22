//
//  BDFaceLogicService.h
//  BDStyleConfig
//
//  Created by Zhang,Jian(MBD) on 2021/9/17.
//

#import <Foundation/Foundation.h>
#import <BDFaceLogicLayer/BDFaceLogicConstant.h>
#import <UIKit/UIKit.h>
#import "OnLoadingListener.h"

NS_ASSUME_NONNULL_BEGIN


/**
 * 请求之前会调用
 */
typedef void(^BDFaceLogicServiceShowLoading)(void);

@interface BDFaceLogicService : NSObject

/**
 * 目前最上面的controller
 */
@property (nonatomic, weak) UIViewController *topController;

/**
 * 是否打开服务端下发开关
 */
@property (nonatomic, assign) BOOL sdkServiceStatus;
/**
 * licenseName
 */
@property (nonatomic, copy) NSString *licenseName;
/**
 * licenseid
 */
@property (nonatomic, copy) NSString *licenseId;

@property (nonatomic, weak) id<OnLoadingListener> onLoadingListener;

/**
BDFaceLogicService 指定初始化方法
@Discussion 必须用这个方法进行初始化
@parameter  response 回调参数
 */
- (instancetype)initWithController:(UIViewController * _Nonnull)controller
                              face:(void(^)(void))initFaceBlock
                               ocr:(void(^)(void))initOcrBlock;
/**
人证核验接口
@Discussion 使用直接传入参数的形式进行人脸识别，页面将直接展示人脸信息采集页面，成功后直接返回结果。
@parameter    dic 参数Dictionary，内部的Key有如下
            必传参数：
            BDFaceLogicServiceTokenKey 对应传入Token, 值为NSString类型;
            BDFaceLogicServiceNameKey 对应传入姓名, 值为NSString类型;
            BDFaceLogicServiceCardNumberKey 应传入证件号, 值为NSString类型;
            可选参数：
            BDFaceLogicServiceCardTypeKey 对应传入证件类型，value type NSNumber
            BDFaceLogicServicePlanIdKe 对应传入Plan_id, 值为NSString类型;
            BDFaceLogicServiceOnlineQualityControlKey onlinequality 值为NSString类型;
            BDFaceLogicServiceLivenessQualityControlKey livenessQuality 值为NSString类型
@Parameter callBack回调信息:
          resultCode 结果回调状态码；
              Type: int类型
                   0 为成功，其余为失败
          resultDic，回调的详细信息
              key: BDFaceLogicServiceReturnKeyForResultData 如果成功，能根据该值，得到最终服务端返回的数据，Dictionary类型;如果失败，那么为空对象；
              key: BDFaceLogicServiceReturnKeyForResultMsg; 根据该Key，调用失败时，返回具体的失败信息
 */
- (void)startRecognize:(NSDictionary *)dic
              callBack:(void(^)(int resultCode, NSDictionary *resultDic))callBack;

/**
活体检测接口，需要先采集人脸信息，之后进行活体检测
@Discussion 集合了本地活体检测和云端活体检测
@Parameter dic 活体检测入参信息asd
@Parameter callBack回调信息:
          resultCode 结果回调状态码；
          Type: int类型
              0 为成功，其余为失败
          resultDic，回调的详细信息
              key: BDFaceLogicServiceReturnKeyForResultData 如果成功，能根据该值，得到最终服务端返回的数据，Dictionary类型;如果失败，那么为空对象；
              key: BDFaceLogicServiceReturnKeyForResultMsg; 根据该Key，调用失败时，返回具体的失败信息
*/
- (void)startRecognizeToCheckLive:(NSDictionary *)dic
                         callBack:(void(^)(int resultCode, NSDictionary *resultDic))callBack;

/**
 * 人脸比对接口，用来采集人脸并获取加密图片，使用的话，需要集合后台集合做进一步开发
 */
- (void)startFaceCollect:(void(^)(int resultCode, NSDictionary *resultDic))callBack;
 
/**
 新版本6.4公共接口
 */
- (void)startCheckLiveCommonAction:(NSDictionary *)dic
                         callBack:(void(^)(int resultCode, NSDictionary *resultDic))callBack;

@end

NS_ASSUME_NONNULL_END
