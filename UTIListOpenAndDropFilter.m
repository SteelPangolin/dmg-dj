//
//  UTIListOpenAndDropFilter.m
//  DMG DJ
//

#import <CoreServices/CoreServices.h>

#import "UTIListOpenAndDropFilter.h"


@implementation UTIListOpenAndDropFilter

- (id)initWithUTIs:(NSString *)firstArg, ... {
	self = [super init];
	fileManager = [[NSFileManager defaultManager] retain];
	utiList = [[NSMutableArray array] retain];

	va_list argList;
	NSString *uti = firstArg;
	va_start(argList, firstArg);
	do {
		[utiList addObject:uti];
	} while (uti = va_arg(argList, NSString*));
	va_end(argList);
	
	return self;
}

- (BOOL)fileConforms:(NSString *)filename {
	// see http://www.cocoadev.com/index.pl?GetUTIForFileAtPath
	
	BOOL conforms = NO;
	FSRef ref;
	FSPathMakeRef((const UInt8 *)[filename fileSystemRepresentation],
		&ref, NULL);
	CFStringRef fileUTI = NULL;
	LSCopyItemAttribute(&ref, kLSRolesAll, kLSItemContentType, (CFTypeRef *)&fileUTI);
	if (fileUTI) {
		NSEnumerator *utiEnmr = [utiList objectEnumerator];
		NSString *uti;
		while ((uti = [utiEnmr nextObject]) && !conforms) {
			conforms = UTTypeConformsTo(fileUTI, (CFStringRef)uti);
		}
		CFRelease(fileUTI);
	}
	return conforms;
}

- (BOOL)panel:(id)sender shouldShowFilename:(NSString *)filename {
	BOOL isDir;
	[fileManager fileExistsAtPath:filename isDirectory:&isDir];
	return isDir || [self fileConforms:filename];
}

- (BOOL)panel:(id)sender isValidFilename:(NSString *)filename {
	return [self fileConforms:filename];
}

- (NSDragOperation)tableView:(NSTableView *)aTableView
	validateDrop:(id <NSDraggingInfo>)info
	proposedRow:(int)row
	proposedDropOperation:(NSTableViewDropOperation)operation {
	
	NSPasteboard *pasteboard = [info draggingPasteboard];
	if ([[pasteboard types] containsObject:NSFilenamesPboardType]) {
		NSArray *files = [pasteboard propertyListForType:NSFilenamesPboardType];
		NSEnumerator *fileEnmr = [files objectEnumerator];
		NSString *filename;
		while (filename = [fileEnmr nextObject]) {
			if (![self fileConforms:filename]) {
				return NSDragOperationNone;
			}
		}
	}
	return NSDragOperationEvery;
}

@end
