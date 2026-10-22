//
//  BDAipOCRConfig.h
//  AipOcrSdk
//
//  Created by Zhang,Jian(MBD) on 2021/10/11.
//  Copyright © 2021 baidu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIkit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BDAipOCRConfig : NSObject

/**
 * 页面标题文字
 * 默认内容：“身份信息采集"
 */
@property(nonatomic, copy) NSString *pageTitle;

/**
 * 页面标题文字颜色
 * 默认: 黑色, [UIColor colorWithRed:0 / 255.0 green:0 / 255.0 blue:0 / 255.0 alpha:1 / 1.0]
 */
@property(nonatomic, strong) UIColor *pageTitleTextColor;

/**
 * 标题后面背景View的背景颜色
 * 默认: [UIColor colorWithRed:240/255.0 green:241/255.0 blue:242/255.0 alpha:1.0]
 */
@property(nonatomic, strong) UIColor *titleViewBgColor;

/**
 * 相框上面的提升文字
 * 默认内容："请将您本人的\n身份证人像面放入框内";
 */
@property(nonatomic, copy) NSString *topTipText;

/**
 * 相框上面提示文字的文字颜色
 * 默认颜色： [UIColor colorWithRed:255/255.0 green:255/255.0 blue:255/255.0 alpha:1/1.0];
 */
@property(nonatomic, strong) UIColor *topTipTextColor;

/**
 * 相框下面红色提升内容文字颜色，也就是页面中间的提升文字的文字颜色
 * 默认：红色，[UIColor colorWithRed:243/255.0 green:75/255.0 blue:86/255.0 alpha:1/1.0];
 */
@property(nonatomic, strong) UIColor *middleTipTextColor;

/**
 * 底部提示信息
 * 默认信息："— 百度大脑技术支持 —"
 */
@property(nonatomic, copy) NSString *bottomTipText;

@end

NS_ASSUME_NONNULL_END
