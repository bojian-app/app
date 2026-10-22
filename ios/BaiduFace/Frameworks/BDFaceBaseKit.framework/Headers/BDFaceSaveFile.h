//
//  BDFaceSaveFile.h
//  IDLFaceSDK
//
//  Created by 之哥 on 2022/10/18.
//  Copyright © 2022 Baidu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BDFaceSaveFile : NSObject

//-(BOOL)saveStringToFile:(NSString *)str;
    
+(void)saveStringToFile:(NSString *)string;

@end

NS_ASSUME_NONNULL_END
