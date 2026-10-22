//
//  OnLoadingListener.h
//  BDFaceLogicLayer
//
//  Created by liudezhi02 on 2025/12/4.
//

#ifndef OnLoadingListener_h
#define OnLoadingListener_h

#import <Foundation/Foundation.h>

@protocol OnLoadingListener <NSObject>

- (void)showLoading;
- (void)hideLoading;

@end

#endif
