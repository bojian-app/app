//
//  AipNavigationController.h
//  BaiduOCR
//
//  Created by 闫祥达 on 2017/2/16.
//  Copyright © 2017年 Baidu. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AipCaptureCardVC.h"

@interface AipNavigationController : UINavigationController

@property(nonatomic, weak)AipCaptureCardVC *captureController;

@end
