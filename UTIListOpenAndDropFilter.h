//
//  UTIListOpenAndDropFilter.h
//  DMG DJ
//

#import <Cocoa/Cocoa.h>


@interface UTIListOpenAndDropFilter : NSObject {
	NSMutableArray *utiList;
	NSFileManager *fileManager;
}

- (id)initWithUTIs:(NSString *)firstArg, ...;

- (BOOL)fileConforms:(NSString *)filename;

// NSSavePanel/NSOpenPanel delegate methods

- (BOOL)panel:(id)sender shouldShowFilename:(NSString *)filename;
- (BOOL)panel:(id)sender isValidFilename:(NSString *)filename;

// NSTableDataSource methods

- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation;

@end
