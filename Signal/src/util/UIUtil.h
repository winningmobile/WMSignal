#import <Foundation/Foundation.h>

#import "UIColor+OWS.h"
#import "UIFont+OWS.h"
#import "UIImage+normalizeImage.h"
#import "UIImage+contentTypes.h"
#import "MIMETypeUtil.h"

typedef void (^completionBlock)(void);

/**
 *
 * UIUtil contains various class methods that centralize common app UI functionality that would otherwise be hardcoded.
 *
 */

@interface UIUtil : NSObject

+ (void)applyRoundedBorderToImageView:(UIImageView *__strong*)imageView;
+ (void)removeRoundedBorderToImageView:(UIImageView *__strong*)imageView;

+ (completionBlock)modalCompletionBlock;
@end
