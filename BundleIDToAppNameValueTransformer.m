//
//  BundleIDToAppNameValueTransformer.m
//  DMG DJ
//

#import "BundleIDToAppNameValueTransformer.h"


@implementation BundleIDToAppNameValueTransformer

+ (Class)transformedValueClass {
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
    return NO;
}

- (id)transformedValue:(id)value {
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSString *appPath = [workspace absolutePathForAppBundleWithIdentifier:(NSString *)value];
	NSBundle *appBundle = [NSBundle bundleWithPath:appPath];
	NSString *appName;
	if (appBundle) {
		appName = [appBundle objectForInfoDictionaryKey:@"CFBundleName"];
	} else {
		// not a bundle
		appName = [[appPath lastPathComponent] stringByDeletingPathExtension];
	}
	return appName;
}

@end
