/* DMGDJController */

#import <Cocoa/Cocoa.h>

@interface DMGDJController : NSObject

{
    IBOutlet NSWindow *prefsWindow;
    IBOutlet NSMenu *statusMenu;
    IBOutlet NSArrayController *apps;
    IBOutlet NSArrayController *images;
	IBOutlet NSTableView *appList;
	IBOutlet NSTableView *imgList;
	
	NSWorkspace *workspace;
	NSUserDefaults *defaults;
	NSOpenPanel *openPanel;
	NSArray *appUTIFilter;
	NSArray *imgUTIFilter;
	
	NSMutableDictionary *mountTable;
}

- (void)syncMounts;

- (IBAction)openPrefs:(id)sender;

- (IBAction)quit:(id)sender;

- (IBAction)addApp:(id)sender;
- (void)addingApp:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void  *)contextInfo;

- (IBAction)removeApp:(id)sender;

- (IBAction)revealApp:(id)sender;

- (IBAction)addImg:(id)sender;
- (void)addingImg:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void  *)contextInfo;

- (IBAction)removeImg:(id)sender;

- (IBAction)revealImg:(id)sender;

- (IBAction)imgLoadFlagChanged:(id)sender;

- (void)addAppPaths:(NSArray *)paths;
- (void)addImgPaths:(NSArray *)paths;

- (void)appWillLaunch:(NSNotification *)notification;
- (void)appTerminated:(NSNotification *)notification;

- (void)incrAllForApp:(NSString *)bundleID;
- (void)decrAllForApp:(NSString *)bundleID;
- (BOOL)isRunning:(NSString *)bundleID;

- (void)incrUserCount:(NSString *)imgPath;
- (void)decrUserCount:(NSString *)imgPath;

- (BOOL)mountDiskImage:(NSString *)imgPath;
- (BOOL)unmountDiskImage:(NSString *)imgPath;

- (NSDictionary *)parsePlist:(NSData *)plistData;

- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation;
- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation;

@end