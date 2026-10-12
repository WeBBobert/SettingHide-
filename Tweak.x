#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "BHPreferences.h"
#import "BHInstalledApps.h"

static NSSet<NSString *> *hiddenNames;
static NSMutableSet<NSString *> *knownNames;
static NSHashTable<UITableViewCell *> *trackedCells;
static BOOL enabled;
static NSDictionary<NSString *, NSNumber *> *sectionFlags;
static NSSet<NSString *> *hiddenIDs;
static BOOL diagnosticLogging;
static BOOL discoveryQueued;
static char savedHiddenKey;

static BOOL ContainsHiddenLabel(UIView *root);

static NSString *SectionForController(UIViewController *controller) {
    NSString *name = NSStringFromClass(controller.class).lowercaseString;
    NSString *bundle = [NSBundle bundleForClass:controller.class].bundlePath.lastPathComponent.lowercaseString;
    if ([bundle containsString:@"batteryhide"] || [bundle containsString:@"settingshide"] || [name hasPrefix:@"atl"] || [name hasPrefix:@"bh"]) return @"OwnSettings";
    if ([bundle containsString:@"battery"] || [bundle containsString:@"powerusage"] || [name containsString:@"battery"]) return @"Battery";
    if ([bundle containsString:@"screentime"] || [name containsString:@"screentime"] || [name hasPrefix:@"stusagereport"] || [name hasPrefix:@"stappusage"]) return @"ScreenTime";
    if ([bundle containsString:@"storage"] || [name containsString:@"storage"] || [name hasPrefix:@"psusage"]) return @"Storage";
    if ([bundle containsString:@"notificationssettings"] || [bundle containsString:@"bulletinboardsettings"] || [name hasPrefix:@"bbsettings"] || [name containsString:@"notificationssettings"]) return @"Notifications";
    if ([bundle containsString:@"appssettings"] || [bundle containsString:@"applicationsettings"] || [name containsString:@"applist"] || [name containsString:@"appssettings"] || [name containsString:@"applicationlist"]) return @"Apps";
    return nil;
}

static NSString *SectionForView(UIView *view) {
    for (UIResponder *r = view; r; r = r.nextResponder) {
        if (![r isKindOfClass:UIViewController.class]) continue;
        NSString *section = SectionForController((UIViewController *)r);
        if ([section isEqualToString:@"OwnSettings"]) return nil;
        if (section) return section;
    }
    return nil;
}

static BOOL ShouldHideCell(UITableViewCell *cell) {
    NSString *section = SectionForView(cell);
    if (!enabled || !section || ![sectionFlags[section] boolValue]) return NO;
    id specifier = BHObject(cell, @"specifier");
    BOOL hasIdentifier = NO;
    for (NSString *key in @[@"applicationIdentifier", @"bundleIdentifier", @"appBundleID", @"bundleID", @"applicationBundleIdentifier"]) {
        id identifier = BHObjectWithArgument(specifier, @"propertyForKey:", key);
        if (![identifier isKindOfClass:NSString.class] || ![identifier length]) continue;
        hasIdentifier = YES;
        if ([hiddenIDs containsObject:identifier]) return YES;
    }
    if (hasIdentifier) return NO; // Prefer identifiers when the row provides them.
    return ContainsHiddenLabel(cell.contentView);
}

static BOOL ContainsHiddenLabel(UIView *root) {
    if ([root isKindOfClass:UILabel.class]) {
        NSString *text = [((UILabel *)root).text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (text && [hiddenNames containsObject:text]) return YES;
    }
    for (UIView *child in root.subviews) if (ContainsHiddenLabel(child)) return YES;
    return NO;
}

static void RestoreCell(UITableViewCell *cell) {
    NSNumber *original = objc_getAssociatedObject(cell, &savedHiddenKey);
    if (!original) return;
    objc_setAssociatedObject(cell, &savedHiddenKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    cell.hidden = original.boolValue;
}

static void QueueKnownName(NSString *name) {
    name = [name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!name.length || name.length > 150 || knownNames.count >= 2000 || [knownNames containsObject:name]) return;
    [knownNames addObject:name];
    if (discoveryQueued) return;
    discoveryQueued = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        discoveryQueued = NO;
        [knownNames addObjectsFromArray:BHNames(@"KnownNames")];
        BHWrite(@"KnownNames", [[knownNames allObjects] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]);
    });
}

static void ReadLabels(UIView *root, NSMutableArray<NSString *> *labels, BOOL *hasImage) {
    if (root.hidden || root.alpha < 0.01) return;
    if ([root isKindOfClass:UIImageView.class] && ((UIImageView *)root).image) *hasImage = YES;
    if ([root isKindOfClass:UILabel.class]) {
        NSString *text = ((UILabel *)root).text;
        if (text.length) [labels addObject:text];
    }
    for (UIView *child in root.subviews) ReadLabels(child, labels, hasImage);
}

static void LearnRow(UITableViewCell *cell) {
    BOOL hasImage = cell.imageView.image != nil;
    NSMutableArray<NSString *> *labels = [NSMutableArray array];
    ReadLabels(cell.contentView, labels, &hasImage);
    if (!hasImage) return; // Only learn icon-bearing rows, not chart/section labels.
    NSString *candidate = cell.textLabel.text;
    if (!candidate.length) {
        for (NSString *label in labels) {
            if ([label rangeOfCharacterFromSet:NSCharacterSet.letterCharacterSet].location != NSNotFound &&
                ![label containsString:@"%"] && ![label containsString:@"\n"]) { candidate = label; break; }
        }
    }
    if (candidate.length) QueueKnownName(candidate);
}

static void RefreshVisibleRows(void) {
    CFPreferencesAppSynchronize(CFSTR("com.example.batteryhide"));
    enabled = [BHRead(@"Enabled", @YES) boolValue];
    hiddenNames = BHSelectedDisplayNames();
    hiddenIDs = [NSSet setWithArray:BHNames(@"HiddenBundleIDs")];
    diagnosticLogging = [BHRead(@"DiagnosticLogging", @NO) boolValue];
    NSMutableDictionary *flags = [NSMutableDictionary dictionary];
    for (NSString *section in @[@"Battery", @"Storage", @"Apps", @"Notifications", @"ScreenTime"])
        flags[section] = @([BHRead([@"Hide" stringByAppendingString:section], [section isEqualToString:@"Battery"] ? @YES : @NO) boolValue]);
    sectionFlags = [flags copy];
    [knownNames addObjectsFromArray:BHNames(@"KnownNames")];
    for (UITableViewCell *cell in trackedCells.allObjects) {
        RestoreCell(cell);
        if (ShouldHideCell(cell)) {
            objc_setAssociatedObject(cell, &savedHiddenKey, @(cell.hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            cell.hidden = YES;
        }
        [cell setNeedsLayout];
    }
}

static void Changed(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    dispatch_async(dispatch_get_main_queue(), ^{ RefreshVisibleRows(); });
}

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!diagnosticLogging) return;
    NSString *section = SectionForController(self);
    if ([section isEqualToString:@"OwnSettings"]) return;
    NSString *bundle = [NSBundle bundleForClass:self.class].bundlePath.lastPathComponent ?: @"unknown";
    NSString *line = [NSString stringWithFormat:@"%@ | %@ | %@", NSStringFromClass(self.class), bundle, section ?: @"Unrecognized"];
    NSMutableArray *lines = [BHNames(@"Diagnostics") mutableCopy];
    if (![lines containsObject:line]) {
        [lines addObject:line];
        if (lines.count > 30) [lines removeObjectAtIndex:0];
        CFPreferencesSetAppValue(CFSTR("Diagnostics"), (__bridge CFArrayRef)lines, CFSTR("com.example.batteryhide"));
        CFPreferencesAppSynchronize(CFSTR("com.example.batteryhide"));
    }
}
%end

%hook UITableViewCell
- (void)layoutSubviews {
    RestoreCell(self);
    %orig;
    NSString *section = SectionForView(self);
    if (!section) return;
    [trackedCells addObject:self];
    if ([section isEqualToString:@"Battery"]) LearnRow(self);
    if (ShouldHideCell(self)) {
        objc_setAssociatedObject(self, &savedHiddenKey, @(self.hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        self.hidden = YES;
    }
}
- (void)prepareForReuse {
    RestoreCell(self);
    [trackedCells removeObject:self];
    %orig;
}
%end

%ctor {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.Preferences"]) return;
        knownNames = [NSMutableSet setWithArray:BHNames(@"KnownNames")];
        trackedCells = [NSHashTable weakObjectsHashTable];
        RefreshVisibleRows();
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, Changed,
            CFSTR("com.example.batteryhide/changed"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        %init;
    }
}
