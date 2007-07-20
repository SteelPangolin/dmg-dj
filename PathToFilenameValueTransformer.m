//
//  PathToFilenameValueTransformer.m
//  DMG DJ
//

#import "PathToFilenameValueTransformer.h"

@implementation PathToFilenameValueTransformer

+ (Class)transformedValueClass {
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
    return NO;
}

- (id)transformedValue:(id)value {
	return [(NSString *)value lastPathComponent];
}

@end
