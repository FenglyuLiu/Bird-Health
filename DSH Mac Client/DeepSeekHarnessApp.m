#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

static NSString *const DSHURLString = @"http://127.0.0.1:3080";
static NSString *const DSHWorkspace = @"/Users/liufenglyu/Downloads/09 创业实践/01 笼养动物健康管理";

@interface PasteEnabledWebView : WKWebView
@end

@implementation PasteEnabledWebView
- (BOOL)performKeyEquivalent:(NSEvent *)event {
    if ((event.modifierFlags & NSEventModifierFlagCommand) &&
        [[event.charactersIgnoringModifiers lowercaseString] isEqualToString:@"v"]) {
        [NSApp sendAction:@selector(paste:) to:nil from:self];
        return YES;
    }
    return [super performKeyEquivalent:event];
}
@end

@interface AppDelegate : NSObject <NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate>
@property NSWindow *window;
@property WKWebView *webView;
@property NSView *loadingView;
@property NSTextField *statusLabel;
@property NSButton *retryButton;
@property NSTask *serverTask;
@property BOOL launchedServer;
@property NSInteger attempts;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSString *iconPath = [NSBundle.mainBundle pathForResource:@"AppIcon" ofType:@"icns"];
    if (iconPath) {
        NSImage *icon = [[NSImage alloc] initWithContentsOfFile:iconPath];
        if (icon) NSApp.applicationIconImage = icon;
    }
    [self buildMenu];
    [self buildWindow];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [self connectOrLaunch];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return YES; }

- (void)applicationWillTerminate:(NSNotification *)notification {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    if (self.launchedServer && self.serverTask.running) [self.serverTask terminate];
}

- (void)buildMenu {
    NSMenu *main = [[NSMenu alloc] init];
    NSMenuItem *appItem = [[NSMenuItem alloc] init];
    [main addItem:appItem];
    NSMenu *appMenu = [[NSMenu alloc] init];
    [appMenu addItemWithTitle:@"关于 DeepSeek Harness" action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"退出 DeepSeek Harness" action:@selector(terminate:) keyEquivalent:@"q"];
    appItem.submenu = appMenu;

    NSMenuItem *editItem = [[NSMenuItem alloc] init];
    [main addItem:editItem];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"编辑"];
    [editMenu addItemWithTitle:@"撤销" action:@selector(undo:) keyEquivalent:@"z"];
    [editMenu addItemWithTitle:@"重做" action:@selector(redo:) keyEquivalent:@"Z"];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItemWithTitle:@"剪切" action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"拷贝" action:@selector(copy:) keyEquivalent:@"c"];
    NSMenuItem *pasteItem = [editMenu addItemWithTitle:@"粘贴" action:@selector(pasteIntoWebView:) keyEquivalent:@"v"];
    pasteItem.target = self;
    [editMenu addItemWithTitle:@"粘贴并匹配样式" action:@selector(pasteAsPlainText:) keyEquivalent:@"V"];
    [editMenu addItemWithTitle:@"全选" action:@selector(selectAll:) keyEquivalent:@"a"];
    editItem.submenu = editMenu;

    NSMenuItem *viewItem = [[NSMenuItem alloc] init];
    [main addItem:viewItem];
    NSMenu *viewMenu = [[NSMenu alloc] initWithTitle:@"显示"];
    [viewMenu addItemWithTitle:@"重新载入" action:@selector(reloadPage:) keyEquivalent:@"r"];
    [viewMenu addItem:[NSMenuItem separatorItem]];
    [viewMenu addItemWithTitle:@"放大" action:@selector(zoomIn:) keyEquivalent:@"+"];
    [viewMenu addItemWithTitle:@"缩小" action:@selector(zoomOut:) keyEquivalent:@"-"];
    [viewMenu addItemWithTitle:@"实际大小" action:@selector(zoomReset:) keyEquivalent:@"0"];
    viewItem.submenu = viewMenu;
    NSApp.mainMenu = main;
}

- (void)buildWindow {
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1280, 840)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable | NSWindowStyleMaskFullSizeContentView
        backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"DeepSeek Harness";
    self.window.titlebarAppearsTransparent = YES;
    self.window.minSize = NSMakeSize(760, 560);
    [self.window center];
    [self.window setFrameAutosaveName:@"DeepSeekHarnessMainWindow"];

    NSView *container = [[NSView alloc] initWithFrame:self.window.contentView.bounds];
    container.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.websiteDataStore = WKWebsiteDataStore.defaultDataStore;
    self.webView = [[PasteEnabledWebView alloc] initWithFrame:container.bounds configuration:config];
    self.webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.webView.navigationDelegate = self;
    self.webView.UIDelegate = self;
    self.webView.allowsMagnification = YES;
    [container addSubview:self.webView];

    self.loadingView = [[NSView alloc] initWithFrame:container.bounds];
    self.loadingView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.loadingView.wantsLayer = YES;
    self.loadingView.layer.backgroundColor = NSColor.windowBackgroundColor.CGColor;

    NSProgressIndicator *spinner = [[NSProgressIndicator alloc] init];
    spinner.style = NSProgressIndicatorStyleSpinning;
    spinner.controlSize = NSControlSizeLarge;
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [spinner startAnimation:nil];

    self.statusLabel = [NSTextField labelWithString:@"正在连接本地 DeepSeek Harness…"];
    self.statusLabel.font = [NSFont systemFontOfSize:15 weight:NSFontWeightMedium];
    self.statusLabel.alignment = NSTextAlignmentCenter;
    self.statusLabel.maximumNumberOfLines = 3;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;

    self.retryButton = [NSButton buttonWithTitle:@"重试" target:self action:@selector(retryNow:)];
    self.retryButton.bezelStyle = NSBezelStyleRounded;
    self.retryButton.hidden = YES;
    self.retryButton.translatesAutoresizingMaskIntoConstraints = NO;

    [self.loadingView addSubview:spinner];
    [self.loadingView addSubview:self.statusLabel];
    [self.loadingView addSubview:self.retryButton];
    [NSLayoutConstraint activateConstraints:@[
        [spinner.centerXAnchor constraintEqualToAnchor:self.loadingView.centerXAnchor],
        [spinner.centerYAnchor constraintEqualToAnchor:self.loadingView.centerYAnchor constant:-35],
        [self.statusLabel.topAnchor constraintEqualToAnchor:spinner.bottomAnchor constant:18],
        [self.statusLabel.centerXAnchor constraintEqualToAnchor:self.loadingView.centerXAnchor],
        [self.statusLabel.widthAnchor constraintLessThanOrEqualToConstant:560],
        [self.retryButton.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:18],
        [self.retryButton.centerXAnchor constraintEqualToAnchor:self.loadingView.centerXAnchor]
    ]];
    [container addSubview:self.loadingView];
    self.window.contentView = container;
}

- (void)connectOrLaunch {
    self.attempts = 0;
    self.retryButton.hidden = YES;
    self.loadingView.hidden = NO;
    self.statusLabel.stringValue = @"正在连接本地 DeepSeek Harness…";
    __weak typeof(self) weakSelf = self;
    [self probeServer:^(BOOL available) {
        if (available) [weakSelf loadApp]; else [weakSelf launchServer];
    }];
}

- (void)probeServer:(void (^)(BOOL))completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:DSHURLString]];
    request.timeoutInterval = 1.2;
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger status = [(NSHTTPURLResponse *)response statusCode];
        BOOL ok = !error && status >= 200 && status < 500;
        dispatch_async(dispatch_get_main_queue(), ^{ completion(ok); });
    }] resume];
}

- (void)launchServer {
    NSString *resources = NSBundle.mainBundle.resourcePath;
    NSString *nodeExecutable = [resources stringByAppendingPathComponent:@"runtime/node/bin/node"];
    NSString *dshEntry = [resources stringByAppendingPathComponent:@"runtime/node_modules/@deepseek-ai/dsh/lib/bin.js"];
    if (![[NSFileManager defaultManager] isExecutableFileAtPath:nodeExecutable] ||
        ![[NSFileManager defaultManager] fileExistsAtPath:dshEntry]) {
        [self showFailure:@"应用内置运行环境不完整，请重新安装 DeepSeek Harness。"];
        return;
    }
    self.statusLabel.stringValue = @"正在启动内置本地服务…";

    NSString *logDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/DeepSeek Harness"];
    [[NSFileManager defaultManager] createDirectoryAtPath:logDir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *logPath = [logDir stringByAppendingPathComponent:@"server.log"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:logPath]) [[NSFileManager defaultManager] createFileAtPath:logPath contents:nil attributes:nil];
    NSFileHandle *log = [NSFileHandle fileHandleForWritingAtPath:logPath];
    [log seekToEndOfFile];

    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:nodeExecutable];
    task.arguments = @[dshEntry, @"web", @"--host", @"127.0.0.1", @"--port", @"3080"];
    NSString *workspace = [[NSFileManager defaultManager] fileExistsAtPath:DSHWorkspace] ? DSHWorkspace : NSHomeDirectory();
    task.currentDirectoryURL = [NSURL fileURLWithPath:workspace isDirectory:YES];
    NSMutableDictionary *env = [NSProcessInfo.processInfo.environment mutableCopy];
    NSString *nodeBin = [resources stringByAppendingPathComponent:@"runtime/node/bin"];
    env[@"PATH"] = [NSString stringWithFormat:@"%@:/usr/bin:/bin:/usr/sbin:/sbin", nodeBin];
    env[@"DSH_DESKTOP_BUNDLED_RUNTIME"] = @"1";
    task.environment = env;
    task.standardOutput = log;
    task.standardError = log;
    __weak typeof(self) weakSelf = self;
    task.terminationHandler = ^(NSTask *ended) {
        if (ended.terminationStatus != 0) dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf showFailure:@"本地服务未能启动。可查看日志：~/Library/Logs/DeepSeek Harness/server.log"];
        });
    };
    NSError *error = nil;
    if ([task launchAndReturnError:&error]) {
        self.serverTask = task;
        self.launchedServer = YES;
        [self waitForServer];
    } else {
        [self showFailure:[NSString stringWithFormat:@"无法启动本地服务：%@", error.localizedDescription]];
    }
}

- (void)waitForServer {
    self.attempts += 1;
    __weak typeof(self) weakSelf = self;
    [self probeServer:^(BOOL available) {
        typeof(self) selfRef = weakSelf;
        if (!selfRef) return;
        if (available) { [selfRef loadApp]; return; }
        if (selfRef.attempts >= 40) { [selfRef showFailure:@"本地服务启动超时。请点“重试”，或查看服务日志。"];; return; }
        selfRef.statusLabel.stringValue = [NSString stringWithFormat:@"正在启动本地服务…（%ld/40）", (long)selfRef.attempts];
        [selfRef performSelector:@selector(waitForServer) withObject:nil afterDelay:0.5];
    }];
}

- (void)loadApp {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(waitForServer) object:nil];
    self.statusLabel.stringValue = @"正在载入对话界面…";
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:DSHURLString] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15];
    [self.webView loadRequest:request];
}

- (void)showFailure:(NSString *)message {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    self.loadingView.hidden = NO;
    self.statusLabel.stringValue = message;
    self.retryButton.hidden = NO;
}

- (void)retryNow:(id)sender {
    if (self.serverTask.running) { self.attempts = 0; self.retryButton.hidden = YES; [self waitForServer]; }
    else [self connectOrLaunch];
}

- (void)pasteIntoWebView:(id)sender {
    [NSApp sendAction:@selector(paste:) to:nil from:self.webView];
}

- (void)reloadPage:(id)sender { self.webView.URL ? [self.webView reload] : [self connectOrLaunch]; }
- (void)zoomIn:(id)sender { self.webView.pageZoom = MIN(self.webView.pageZoom + 0.1, 2.0); }
- (void)zoomOut:(id)sender { self.webView.pageZoom = MAX(self.webView.pageZoom - 0.1, 0.5); }
- (void)zoomReset:(id)sender { self.webView.pageZoom = 1.0; }

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation { self.loadingView.hidden = YES; }
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error { [self showFailure:[@"页面载入失败：" stringByAppendingString:error.localizedDescription]]; }
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error { [self showFailure:[@"无法连接本地服务：" stringByAppendingString:error.localizedDescription]]; }

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)action decisionHandler:(void (^)(WKNavigationActionPolicy))handler {
    NSURL *url = action.request.URL;
    if (!url) { handler(WKNavigationActionPolicyCancel); return; }
    BOOL local = [url.host isEqualToString:@"127.0.0.1"] || [url.host isEqualToString:@"localhost"] || [url.scheme isEqualToString:@"about"] || [url.scheme isEqualToString:@"blob"];
    if (local) handler(WKNavigationActionPolicyAllow);
    else if (action.navigationType == WKNavigationTypeLinkActivated) { [[NSWorkspace sharedWorkspace] openURL:url]; handler(WKNavigationActionPolicyCancel); }
    else handler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView runOpenPanelWithParameters:(WKOpenPanelParameters *)parameters initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSArray<NSURL *> *))completionHandler {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = parameters.allowsDirectories;
    panel.allowsMultipleSelection = parameters.allowsMultipleSelection;
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) { completionHandler(result == NSModalResponseOK ? panel.URLs : nil); }];
}
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *application = NSApplication.sharedApplication;
        AppDelegate *delegate = [[AppDelegate alloc] init];
        application.delegate = delegate;
        [application setActivationPolicy:NSApplicationActivationPolicyRegular];
        [application run];
    }
    return 0;
}
