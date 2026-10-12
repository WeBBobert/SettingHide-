SettingsHide 0.2.0 — installed-app chooser and Settings row filters

INSTALL/UPGRADE
The package ID remains com.example.batteryhide so this updates BatteryHide 0.1.0
in place. Its display name and Settings entry are now SettingsHide. Install the
rootless AltList dependency with Sileo if prompted. The framework provides the
installed-app picker; it is not bundled or copied into this project.
Close and reopen Settings after upgrading. This remains an experimental beta.

BUILD USING YOUR IPHONE
Replace .github/workflows/build.yml in your GitHub repository with the supplied
BatteryHide-build.yml. Run Actions > Build BatteryHide rootless. Download the
BatteryHide-rootless artifact, extract its .deb and install with Sileo. The
workflow embeds all source. The build/source filenames are retained for continuity.
For a normal source repository, upload the contents of this BatteryHide folder
and use its .github/workflows/build.yml.

CHOOSE INSTALLED APPS
Settings > SettingsHide > Choose installed apps lists System and User apps with
names and identifiers. Search by either. Turn on an app to select it. One selection
is shared across all sections. It no longer requires visiting Battery first.
Non-launchable hidden services are excluded from these picker sections.
AltList saves identifiers under HiddenBundleIDs in com.example.batteryhide.

Enable the section switches you want. Battery defaults to on. Apps, Storage,
Notifications and Screen Time default to off and are marked experimental.
Tap Apply changes, then revisit the relevant section. If rows appear stale,
close and reopen Settings. Show all apps clears both installed-app and legacy
name selections. The master switch restores rows while retaining selections.
Choices from the previous version remain active under Legacy name selections;
clear those if you want identifier-based selections only.

IMPLEMENTATION AND LIMITS
AltList is loaded from its installed rootless framework with dlopen. Its documented
ATLApplicationListMultiSelectionController handles search, icons and toggles. No
AltList SDK stub is required during compilation. The package declares its dependency.
Source/reference: https://github.com/opa334/AltList (MIT licensed dependency).

Selected LSApplicationProxy records resolve localized display names. The row filter
prefers app identifier metadata on PSSpecifier-backed cells. When unavailable, it
falls back to exact label matching. Two apps sharing a display name can therefore
both match on pages that expose no identifier. Language changes require restarting
Settings so localized names can be resolved again.

Only com.apple.Preferences is injected. Recognized controller/bundle names classify
Battery, Storage, Apps, Notifications and Screen Time pages. Unknown screens are
left unchanged; our own settings and AltList picker are excluded. This is a UIKit
UITableViewCell filter, not a universal iOS 18 model/SwiftUI patch. Some or all added
sections may remain unaffected on this device. Their coverage is not verified.
Hidden rows may leave gaps. The reused-cell restoration fix from 0.1.0 is retained.

This does not erase battery/Screen Time history, change charts or totals, delete
files, free storage, disable notifications, hide notification banners, alter
Settings search results or hide apps in other system surfaces. It is display
filtering, not a guarantee that an installed app cannot be discovered.

DIAGNOSTICS
Enable Diagnostic logging; open a section where rows remain; return and tap Show
diagnostics. Class/bundle names and recognized section are stored locally (last
30 unique entries). No selected identifiers or usage records are logged. Screens
implemented with UIHostingController may require additional native data hooks.
Turn logging off after diagnosis.

VALIDATION
User confirmed BatteryHide 0.1.0 worked on iPhone 11 / iOS 18.6.2 / Dopamine 3.
The installed-app picker and added section filters in 0.2.0 are untested on a device.
Local checks cover plist types, domain/key wiring, dependency declaration, both
YAML workflows, shell syntax, ZIP integrity and exact embedded source contents.
No local iOS SDK/compiler is available. GitHub checks actual compilation.

TEST ON PHONE
- Installed apps appear and search works; selection persists after restarting Settings.
- A selected app disappears in Battery; deselecting/master disable restores it.
- Enable each other section separately and check its actual coverage.
- Scrolling never conceals unrelated reused cells; chooser stays visible.
- Existing records, totals and notification behavior remain unchanged.
