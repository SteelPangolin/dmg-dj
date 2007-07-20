//
//  BundleIDToIconValueTransformer.m
//  DMG DJ
//

#import "BundleIDToIconValueTransformer.h"

@implementation BundleIDToIconValueTransformer

+ (Class)transformedValueClass {
    return [NSImage class];
}

+ (BOOL)allowsReverseTransformation {
    return NO;
}

- (id)transformedValue:(id)value {
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSString *appPath = [workspace absolutePathForAppBundleWithIdentifier:(NSString *)value];
	NSImage *icon = [workspace iconForFile:appPath];
	[icon setSize:NSMakeSize(16.0, 16.0)];
	return icon;
}

@end
