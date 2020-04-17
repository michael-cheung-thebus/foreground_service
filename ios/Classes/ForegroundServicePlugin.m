#import "ForegroundServicePlugin.h"
#if __has_include(<foreground_service/foreground_service-Swift.h>)
#import <foreground_service/foreground_service-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "foreground_service-Swift.h"
#endif

@implementation ForegroundServicePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftForegroundServicePlugin registerWithRegistrar:registrar];
}
@end
