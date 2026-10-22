#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
@interface BJNativeFace : NSObject
- (BOOL)available;
- (void)verifyToken:(NSString *)token session:(NSString *)session presenter:(UIViewController *)presenter accent:(NSNumber *)accent dark:(BOOL)dark completion:(void(^)(NSInteger code))completion NS_SWIFT_NAME(verify(token:session:presenter:accent:dark:completion:));
- (void)cancel;
@end
NS_ASSUME_NONNULL_END
