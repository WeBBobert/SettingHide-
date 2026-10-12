#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import "../BHPreferences.h"
#import "../BHInstalledApps.h"

@interface BHRootController : PSListController
@end
@interface BHAppPickerController : PSListController
@end

@implementation BHRootController
- (NSArray *)specifiers {
    if (!_specifiers) {
        BOOL pickerAvailable = BHLoadAltList();
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
        if (!pickerAvailable) {
            for (PSSpecifier *item in _specifiers) {
                if ([[item propertyForKey:@"key"] isEqualToString:@"HiddenBundleIDs"]) {
                    [item setProperty:@"Install AltList, then reopen Settings" forKey:@"footerText"];
                    [item setProperty:@NO forKey:@"enabled"];
                }
            }
        }
    }
    return _specifiers;
}
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (!key) return [specifier propertyForKey:@"default"];
    if ([key isEqualToString:@"HiddenBundleIDs"]) return BHNames(key);
    return BHRead(key, [specifier propertyForKey:@"default"]);
}
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (key) BHWrite(key, value);
}
- (void)refreshBatteryHide { BHNotify(); }
- (void)showEverything {
    BHWrite(@"HiddenBundleIDs", @[]);
    BHWrite(@"HiddenNames", @[]);
    [self reloadSpecifiers];
}
- (void)showDiagnostics {
    NSArray *lines = BHNames(@"Diagnostics");
    NSString *message = lines.count ? [lines componentsJoinedByString:@"\n"] : @"Enable Diagnostic logging, visit a section where hiding does not work, then return here. No app names or usage records are included.";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Settings diagnostics" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end

@implementation BHAppPickerController
- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *items = [[self loadSpecifiersFromPlistName:@"Apps" target:self] mutableCopy];
        if (!items) items = [NSMutableArray array];
        NSMutableSet *names = [NSMutableSet setWithArray:BHNames(@"KnownNames")];
        [names addObjectsFromArray:BHNames(@"HiddenNames")];
        NSArray *sorted = [[names allObjects] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        for (NSString *name in sorted) {
            PSSpecifier *item = [PSSpecifier preferenceSpecifierNamed:name target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
            [item setProperty:name forKey:@"appName"];
            [items addObject:item];
        }
        _specifiers = items;
    }
    return _specifiers;
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _specifiers = nil;
    [self reloadSpecifiers];
}
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *name = [specifier propertyForKey:@"appName"];
    return @([BHNames(@"HiddenNames") containsObject:name]);
}
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *name = [specifier propertyForKey:@"appName"];
    if (!name) return;
    NSMutableArray *selected = [BHNames(@"HiddenNames") mutableCopy];
    if ([value boolValue]) { if (![selected containsObject:name]) [selected addObject:name]; }
    else [selected removeObject:name];
    BHWrite(@"HiddenNames", selected);
}
- (void)addAppName {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Add app name" message:@"Enter the name exactly as it appears in Settings → Battery. The app will be selected for hiding." preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"For example: Photos";
        field.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Add" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action;
        NSString *name = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (!name.length || name.length > 150) return;
        NSMutableArray *known = [BHNames(@"KnownNames") mutableCopy];
        if (![known containsObject:name]) [known addObject:name];
        BHWrite(@"KnownNames", known);
        NSMutableArray *selected = [BHNames(@"HiddenNames") mutableCopy];
        if (![selected containsObject:name]) [selected addObject:name];
        BHWrite(@"HiddenNames", selected);
        BHAppPickerController *controller = weakSelf;
        if (!controller) return;
        controller->_specifiers = nil;
        [controller reloadSpecifiers];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)showAllApps {
    BHWrite(@"HiddenNames", @[]);
    [self reloadSpecifiers];
}
@end
