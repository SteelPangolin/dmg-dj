#import "NDResourceFork.h"

#import "DMGDJController.h"
#import "BundleIDToAppNameValueTransformer.h"
#import "BundleIDToIconValueTransformer.h"
#import "PathToFilenameValueTransformer.h"
#import "UTIListOpenAndDropFilter.h"

@implementation DMGDJController

+ (void)initialize {
	// register value transformers used by our nib
		
	BundleIDToAppNameValueTransformer *bundleIDToAppNameValueTransformer
		= [[[BundleIDToAppNameValueTransformer alloc] init] autorelease];
	[NSValueTransformer
		setValueTransformer:bundleIDToAppNameValueTransformer
		forName:@"BundleIDToAppNameValueTransformer"];
		
	BundleIDToIconValueTransformer *bundleIDToIconValueTransformer
		= [[[BundleIDToIconValueTransformer alloc] init] autorelease];
	[NSValueTransformer
		setValueTransformer:bundleIDToIconValueTransformer
		forName:@"BundleIDToIconValueTransformer"];
		
	PathToFilenameValueTransformer *pathToFilenameValueTransformer
		= [[[PathToFilenameValueTransformer alloc] init] autorelease];
	[NSValueTransformer
		setValueTransformer:pathToFilenameValueTransformer
		forName:@"PathToFilenameValueTransformer"];
}

- (id)init {
	self = [super init];
	
	workspace = [[NSWorkspace sharedWorkspace] retain];
	defaults = [[NSUserDefaults standardUserDefaults] retain];
	
	// create working data structures
	mountTable = [[NSMutableDictionary dictionary] retain];
	
	return self;
}

- (void)awakeFromNib {
	// create system menu status item
    NSStatusItem *statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength] retain];
	[statusItem setImage:[NSImage imageNamed:@"dmg-dj-menuIcon"]];
	[statusItem setAlternateImage:[NSImage imageNamed:@"dmg-dj-menuIconSelected"]];
	[statusItem setHighlightMode:YES];
    [statusItem setMenu:statusMenu];
	
	// register app launch/quit listeners
	NSNotificationCenter *notCenter = [workspace notificationCenter];
	[notCenter addObserver:self
		selector:@selector(appWillLaunch:)
		name:NSWorkspaceWillLaunchApplicationNotification
		object:nil];
	[notCenter addObserver:self
		selector:@selector(appTerminated:)
		name:NSWorkspaceDidTerminateApplicationNotification
		object:nil];
	
	// set up open dialog
	openPanel = [[NSOpenPanel openPanel] retain];
	[openPanel setAllowsMultipleSelection:YES];
	appUTIFilter = [[UTIListOpenAndDropFilter alloc] initWithUTIs:
		@"com.apple.application",
		nil];
	imgUTIFilter = [[UTIListOpenAndDropFilter alloc] initWithUTIs:
		@"public.disk-image",
		nil];
	
	// register for file drag and drop
	[appList registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
	[imgList registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
	
	[self syncMounts];
}

- (void) syncMounts {
	NSEnumerator *runningAppsEnmr = [[workspace launchedApplications] objectEnumerator];
	NSDictionary *runningApp;
	while (runningApp = [runningAppsEnmr nextObject]) {
		NSString *bundleID = [runningApp valueForKey:@"NSApplicationBundleIdentifier"];
		[self incrAllForApp:bundleID];
	}
}

- (IBAction)openPrefs:(id)sender {
	[NSApp activateIgnoringOtherApps:YES];
	[prefsWindow makeKeyAndOrderFront:sender];
}

- (IBAction)quit:(id)sender {
	[NSApp terminate:sender];
}

- (IBAction)addApp:(id)sender {
	[openPanel setDelegate:appUTIFilter];
	[openPanel
		beginSheetForDirectory:nil
		file:nil
		modalForWindow:prefsWindow
		modalDelegate:self
		didEndSelector:@selector(addingApp: returnCode: contextInfo:)
		contextInfo:NULL];
}

- (void)addingApp:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void  *)contextInfo {
	if (returnCode != NSOKButton) return;
	[self addAppPaths:[openPanel filenames]];
}

- (void)addAppPaths:(NSArray *)paths {
	NSEnumerator *pathEnmr = [paths objectEnumerator];
	NSString *path;
	while (path = [pathEnmr nextObject]) {
		NSBundle *bundle = [NSBundle bundleWithPath:path];
		NSString *bundleID;
		if (bundle) {
			bundleID = [bundle bundleIdentifier];
		} else {
			// application isn't a bundle? go fishing in the resource fork for an XML plist
			NDResourceFork *rsrcFork = [NDResourceFork resourceForkForReadingAtPath:path];
			NSData *plistRsrc = [rsrcFork dataForType:'plst' Id:0];
			NSDictionary *plistDict = [self parsePlist:plistRsrc];
			bundleID = [plistDict objectForKey:@"CFBundleIdentifier"];
		}
		[apps addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
			bundleID, @"bundleID",
			path, @"path",
			[NSMutableArray array], @"imgTable",
			nil]];
	}
}

- (IBAction)removeApp:(id)sender {
	NSString *bundleID = [apps valueForKeyPath:@"selection.bundleID"];
	if ([self isRunning:bundleID]) {
		[self decrAllForApp:bundleID];
	}
	[apps remove:sender];
}

- (IBAction)revealApp:(id)sender {
	NSString *bundleID = [[apps selection] valueForKeyPath:@"bundleID"];
	NSString *appPath = [workspace absolutePathForAppBundleWithIdentifier:bundleID];
	[workspace selectFile:appPath inFileViewerRootedAtPath:@""];
}

- (IBAction)addImg:(id)sender {
	[openPanel setDelegate:imgUTIFilter];
	[openPanel
		beginSheetForDirectory:nil
		file:nil
		modalForWindow:prefsWindow
		modalDelegate:self
		didEndSelector:@selector(addingImg: returnCode: contextInfo:)
		contextInfo:NULL];
}

- (void)addingImg:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void  *)contextInfo {
	if (returnCode != NSOKButton) return;
	[self addImgPaths:[openPanel filenames]];
}

- (void)addImgPaths:(NSArray *)paths {
	NSEnumerator *pathEnmr = [paths objectEnumerator];
	NSString *path;
	NSString *userBundleID = [apps valueForKeyPath:@"selection.bundleID"];
	BOOL userIsRunning = [self isRunning:userBundleID];
	while (path = [pathEnmr nextObject]) {
		[images addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
			path, @"path",
			[NSNumber numberWithBool:YES], @"load",
			nil]];
		if (userIsRunning) {
			[self incrUserCount:path];
		}
	}
}

- (void)appWillLaunch:(NSNotification *)notification {
	NSString *bundleID = [[notification userInfo]
		valueForKey:@"NSApplicationBundleIdentifier"];
	[self incrAllForApp:bundleID];
}

- (void)appTerminated:(NSNotification *)notification {
	NSString *bundleID = [[notification userInfo]
		valueForKey:@"NSApplicationBundleIdentifier"];
	[self decrAllForApp:bundleID];
}

- (void)incrAllForApp:(NSString *)bundleID {
	NSEnumerator *appEnmr = [[defaults valueForKey:@"appTable"] objectEnumerator];
	NSDictionary *app;
	while (app = [appEnmr nextObject]) {
		if ([[app valueForKey:@"bundleID"] isEqual:bundleID]) {
			break;
		}
	}
	if (app) {
		NSEnumerator *imgEnmr = [[app valueForKey:@"imgTable"] objectEnumerator];
		NSDictionary *img;
		while (img = [imgEnmr nextObject]) {
			if ([(NSNumber *)[img valueForKey:@"load"] intValue]) {
				[self incrUserCount:[img valueForKey:@"path"]];
			}
		}
	}
}

- (void)decrAllForApp:(NSString *)bundleID {
	NSEnumerator *appEnmr = [[defaults valueForKey:@"appTable"] objectEnumerator];
	NSDictionary *app;
	while (app = [appEnmr nextObject]) {
		if ([[app valueForKey:@"bundleID"] isEqual:bundleID]) {
			break;
		}
	}
	if (app) {
		NSEnumerator *imgEnmr = [[app valueForKey:@"imgTable"] objectEnumerator];
		NSDictionary *img;
		while (img = [imgEnmr nextObject]) {
			if ([(NSNumber *)[img valueForKey:@"load"] intValue]) {
				[self decrUserCount:[img valueForKey:@"path"]];
			}
		}
	}
}

- (BOOL)isRunning:(NSString *)bundleID {
	NSEnumerator *runningAppsEnmr = [[workspace launchedApplications] objectEnumerator];
	NSDictionary *runningApp;
	BOOL isRunning = NO;
	while ((runningApp = [runningAppsEnmr nextObject]) && !isRunning) {
		NSString *runningAppBundleID = [runningApp valueForKey:@"NSApplicationBundleIdentifier"];
		isRunning = [bundleID isEqual:runningAppBundleID];
	}
	return isRunning;
}

- (IBAction)removeImg:(id)sender {
	NSString *path = [images valueForKeyPath:@"selection.path"];
	NSString *userBundleID = [apps valueForKeyPath:@"selection.bundleID"];
	if ([self isRunning:userBundleID]) {
		if ([[images valueForKeyPath:@"selection.load"] boolValue]) {
			[self decrUserCount:path];
		}
	}
	[images remove:sender];
}

- (IBAction)revealImg:(id)sender {
	[workspace selectFile:[[images selection] valueForKeyPath:@"path"] inFileViewerRootedAtPath:@""];
}

- (IBAction)imgLoadFlagChanged:(id)sender {
	NSString *path = [images valueForKeyPath:@"selection.path"];
	NSString *userBundleID = [apps valueForKeyPath:@"selection.bundleID"];
	if ([self isRunning:userBundleID]) {
		if ([[images valueForKeyPath:@"selection.load"] boolValue]) {
			[self incrUserCount:path];
		} else {
			[self decrUserCount:path];
		}
	}
}

- (NSDictionary *) parsePlist:(NSData *)plistData {
	NSString *plistDeserializationError;
	NSDictionary *plistDict = [NSPropertyListSerialization
		propertyListFromData:plistData
		mutabilityOption:NSPropertyListImmutable
		format:NULL
		errorDescription:&plistDeserializationError];
	if (plistDeserializationError) {
		[NSException raise:@"PlistDeserializationException" format:plistDeserializationError];
	}
	return plistDict;
}

- (void)incrUserCount:(NSString *)imgPath {
	NSNumber *userCountObj = [mountTable objectForKey:imgPath];
	int userCount = 0;
	if (!userCountObj) {
		[mountTable setValue:[NSNumber numberWithInt:userCount] forKey:imgPath];
	} else {
		userCount = [userCountObj intValue];
	}
	if (userCount == 0) {
		if (![self mountDiskImage:imgPath]) {
			[NSException raise:@"DiskImageException"
				format:@"incrUserCount: failed to mount %@",
					imgPath];
		}
	}
	[mountTable setValue:[NSNumber numberWithInt:(userCount + 1)] forKey:imgPath];
}

- (void)decrUserCount:(NSString *)imgPath {
	NSNumber *userCountObj = [mountTable objectForKey:imgPath];
	assert(userCountObj);
	int userCount = [userCountObj intValue];
	if (userCount == 1) {
		if (![self unmountDiskImage:imgPath]) {
			[NSException raise:@"DiskImageException"
				format:@"decrUserCount: failed to unmount %@",
					imgPath];
		}
	}
	[mountTable setValue:[NSNumber numberWithInt:(userCount - 1)] forKey:imgPath];
}

- (BOOL)mountDiskImage:(NSString *)imgPath {
	NSString *progPath = @"/usr/bin/hdiutil";
	NSArray *args = [NSArray arrayWithObjects:
		@"attach",
		@"-noautofsck",
		@"-noverify",
		@"-noautoopen",
		@"-quiet",
		imgPath,
		nil];
	NSTask *task = [NSTask
		launchedTaskWithLaunchPath:progPath
		arguments:args];
	[task waitUntilExit];
	int exitCode = [task terminationStatus];
	if (exitCode) {
		NSLog(@"mountDiskImage: %@ with arguments %@ failed with exit code %d",
			progPath, args, exitCode);
		return NO;
	}
	return YES;
}

- (BOOL)unmountDiskImage:(NSString *)imgPath {
	NSString *progPath = @"/usr/bin/hdiutil";
	
	// get the device entries associated with this image
	NSArray *args = [NSArray arrayWithObjects:
		@"info",
		@"-plist",
		nil];
	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath:progPath];
	[task setArguments:args];
	NSPipe *taskOutPipe = [NSPipe pipe];
	[task setStandardOutput:taskOutPipe];
	NSFileHandle *taskOutHandle = [taskOutPipe fileHandleForReading];
	[task launch];
	NSData *taskOutput = [taskOutHandle readDataToEndOfFile];
	[task waitUntilExit];
	int exitCode = [task terminationStatus];
	if (exitCode) {
		NSLog(@"unmountDiskImage: %@ with arguments %@ failed with exit code %d",
			progPath, args, exitCode);
		return NO;
	}
	NSDictionary *mountsInfo = [self parsePlist:taskOutput];
	NSEnumerator *imageEnmr = [[mountsInfo valueForKey:@"images"] objectEnumerator];
	NSDictionary *mountedImage;
	BOOL foundImage = NO;
	while (mountedImage = [imageEnmr nextObject]) {
		if ([[mountedImage valueForKey:@"image-path"] isEqual:imgPath]) {
			foundImage = YES;
			break;
		}
	}
	if (!foundImage) {
		NSLog(@"unmountDiskImage: tried to unmount %@ but it's not mounted",
			imgPath);
		return NO;
	}
	NSString *firstDevEntry = [[((NSArray *)[mountedImage
		valueForKey:@"system-entities"])
		objectAtIndex:0]
		valueForKey:@"dev-entry"];
		
	// unmount the image with one of its device entries
	args = [NSArray arrayWithObjects:
		@"detach",
		@"-quiet",
		firstDevEntry,
		nil];
	task = [NSTask
		launchedTaskWithLaunchPath:progPath
		arguments:args];
	[task waitUntilExit];
	exitCode = [task terminationStatus];
	if (exitCode) {
		NSLog(@"unmountDiskImage: %@ with arguments %@ failed with exit code %d",
			progPath, args, exitCode);
		return NO;
	}
	
	return YES;
}

- (NSDragOperation)tableView:(NSTableView *)aTableView
	validateDrop:(id <NSDraggingInfo>)info
	proposedRow:(int)row
	proposedDropOperation:(NSTableViewDropOperation)operation {
	
	if (aTableView == appList) {
		return [appUTIFilter
			tableView:aTableView
			validateDrop:info
			proposedRow:row
			proposedDropOperation:operation];
	} else if (aTableView == imgList) {
		if ([apps valueForKeyPath:@"selection.imgTable"]) {
			return [imgUTIFilter
				tableView:aTableView
				validateDrop:info
				proposedRow:row
				proposedDropOperation:operation];
		} else {
			return NSDragOperationNone;
		}
	} else {
		assert(NO); // bad pointer
		return NSDragOperationNone;
	}
}

- (BOOL)tableView:(NSTableView *)aTableView
	acceptDrop:(id <NSDraggingInfo>)info
	row:(int)row
	dropOperation:(NSTableViewDropOperation)operation {
	
	NSPasteboard *pasteboard = [info draggingPasteboard];
	if (![[pasteboard types] containsObject:NSFilenamesPboardType]) {
		assert(NO); // got types we didn't register for
		return NO;
	}
	NSArray *files = [pasteboard propertyListForType:NSFilenamesPboardType];
	if (aTableView == appList) {
		[self addAppPaths:files];
		return YES;
	} else if (aTableView == imgList) {
		if ([apps valueForKeyPath:@"selection.imgTable"]) {
			[self addImgPaths:files];
			return YES;
		} else {
			return NO;
		}
	} else {
		assert(NO); // bad pointer
		return NO;
	}
}

@end
