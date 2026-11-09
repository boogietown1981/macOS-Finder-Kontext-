#import <Cocoa/Cocoa.h>
#import <FinderSync/FinderSync.h>

@interface FinderExtrasSync : FIFinderSync
@end
@implementation FinderExtrasSync
- (instancetype)init {
    self = [super init];
    if (self) {
        // Observe local and mounted folders, but perform no scans or badge work.
        [FIFinderSyncController defaultController].directoryURLs = [NSSet setWithObject:[NSURL fileURLWithPath:@"/"]];
    }
    return self;
}
- (NSMenu *)menuForMenuKind:(FIMenuKind)kind {
    FIFinderSyncController *controller = [FIFinderSyncController defaultController];
    NSArray<NSURL *> *selected = [controller selectedItemURLs] ?: @[];
    NSURL *target = [controller targetedURL];
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"FinderExtras"];
    if (kind == FIMenuKindContextualMenuForItems && selected.count > 0) {
        [self add:@"Ausschneiden" action:@"cut" urls:selected target:nil menu:menu];
        [self add:@"Kopieren · FinderExtras" action:@"copy" urls:selected target:nil menu:menu];
        [self add:@"Pfade kopieren" action:@"paths" urls:selected target:nil menu:menu];
    }
    NSNumber *directory = nil;
    [target getResourceValue:&directory forKey:NSURLIsDirectoryKey error:nil];
    if (directory.boolValue) {
        [self add:@"Hier einfügen · FinderExtras" action:@"paste" urls:@[] target:target menu:menu];
        [self add:@"Hierher verschieben" action:@"move" urls:@[] target:target menu:menu];
    }
    return menu;
}
- (void)add:(NSString *)title action:(NSString *)action urls:(NSArray<NSURL *> *)urls target:(NSURL *)target menu:(NSMenu *)menu {
    NSMutableArray *paths = [NSMutableArray array];
    for (NSURL *url in urls) if (url.isFileURL) [paths addObject:url.path];
    NSMutableDictionary *payload = [@{@"action":action, @"paths":paths} mutableCopy];
    if (target) payload[@"target"] = target.path;
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(invoke:) keyEquivalent:@""];
    item.target = self;
    item.representedObject = payload;
    [menu addItem:item];
}
- (void)invoke:(NSMenuItem *)sender {
    NSData *data = [NSJSONSerialization dataWithJSONObject:sender.representedObject options:0 error:nil];
    if (!data || data.length > 500000) return;
    NSURLComponents *components = [[NSURLComponents alloc] init];
    components.scheme = @"finderextras";
    components.host = @"action";
    components.queryItems = @[[NSURLQueryItem queryItemWithName:@"payload" value:[data base64EncodedStringWithOptions:0]]];
    [[NSWorkspace sharedWorkspace] openURL:components.URL];
}
@end
