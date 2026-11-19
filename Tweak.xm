//
//  FakePass13 — фейковый экран код-пароля для iOS 13
//
//  Зачем: на устройствах, где после отката/SEP-проблем настоящий код-пароль
//  и Face ID недоступны, твик рисует поверх системного лок-скрина свой экран
//  с клавиатурой. Устройство блокируется по-настоящему (система), а код
//  проверяется по файлу настроек.
//
//  Твик НЕ трогает настоящий код-пароль, НЕ лезет в keybag, НЕ умеет
//  стирать устройство. Максимум вреда — вы забыли свой код (см. README).
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioToolbox.h>

#pragma mark - Конфигурация

static NSString *const FLConfigPath = @"/Library/Preferences/com.mell.fakepass13.plist";
static NSString *const FLDefaultPasscode = @"1234";

static NSDictionary *FLConfig(void) {
    NSDictionary *config = [NSDictionary dictionaryWithContentsOfFile:FLConfigPath];
    if (![config isKindOfClass:[NSDictionary class]]) {
        return @{};
    }
    return config;
}

static NSString *FLPasscode(void) {
    NSString *code = FLConfig()[@"passcode"];
    if (![code isKindOfClass:[NSString class]] || code.length < 4) {
        return FLDefaultPasscode;
    }
    if (code.length > 8) {
        return [code substringToIndex:8];
    }
    return code;
}

static NSUInteger FLPasscodeLength(void) {
    return FLPasscode().length;
}

static BOOL FLConfigBool(NSString *key, BOOL fallback) {
    id value = FLConfig()[key];
    return value ? [value boolValue] : fallback;
}

#pragma mark - Вспомогательные штуки

static UIWindowScene *FLBestWindowScene(void) {
    UIWindowScene *fallback = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }
        if (!fallback) {
            fallback = (UIWindowScene *)scene;
        }
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            return (UIWindowScene *)scene;
        }
    }
    return fallback;
}

static void FLPlayKeySound(void) {
    AudioServicesPlaySystemSound(1104); // системный "клик" клавиатуры
}

static void FLHapticLight(void) {
    UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [generator impactOccurred];
}

static void FLHapticError(void) {
    UINotificationFeedbackGenerator *generator = [[UINotificationFeedbackGenerator alloc] init];
    [generator notificationOccurred:UINotificationFeedbackTypeError];
}

static void FLHapticSuccess(void) {
    UINotificationFeedbackGenerator *generator = [[UINotificationFeedbackGenerator alloc] init];
    [generator notificationOccurred:UINotificationFeedbackTypeSuccess];
}

#pragma mark - Точки код-пароля

@interface FLDotsView : UIView
@property (nonatomic, assign) NSUInteger total;
@property (nonatomic, assign) NSUInteger filled;
@end

@implementation FLDotsView

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        _total = 4;
        _filled = 0;
    }
    return self;
}

- (void)setTotal:(NSUInteger)total {
    _total = total;
    [self setNeedsDisplay];
}

- (void)setFilled:(NSUInteger)filled {
    _filled = filled;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];

    if (self.total == 0) {
        return;
    }

    CGFloat dot = 13.0;
    CGFloat gap = 24.0;
    CGFloat totalWidth = self.total * dot + (self.total - 1) * gap;
    CGFloat x = (CGRectGetWidth(self.bounds) - totalWidth) / 2.0;
    CGFloat y = (CGRectGetHeight(self.bounds) - dot) / 2.0;

    for (NSUInteger i = 0; i < self.total; i++) {
        CGRect dotRect = CGRectMake(x + i * (dot + gap), y, dot, dot);
        UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:dotRect];
        if (i < self.filled) {
            [[UIColor whiteColor] setFill];
            [path fill];
        } else {
            path.lineWidth = 1.5;
            [[UIColor colorWithWhite:1.0 alpha:0.55] setStroke];
            [path stroke];
        }
    }
}

@end

#pragma mark - Кнопка клавиатуры

@interface FLKeyButton : UIButton
@property (nonatomic, copy) NSString *digit;
@property (nonatomic, assign) BOOL isDelete;
@end

@implementation FLKeyButton {
    UILabel *_digitLabel;
    UILabel *_subLabel;
    UIImageView *_iconView;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
        self.layer.masksToBounds = YES;

        _digitLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _digitLabel.textAlignment = NSTextAlignmentCenter;
        _digitLabel.textColor = [UIColor whiteColor];
        _digitLabel.backgroundColor = [UIColor clearColor];
        [self addSubview:_digitLabel];

        _subLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _subLabel.textAlignment = NSTextAlignmentCenter;
        _subLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.75];
        _subLabel.backgroundColor = [UIColor clearColor];
        [self addSubview:_subLabel];
    }
    return self;
}

- (void)setDigit:(NSString *)digit {
    _digit = [digit copy];
    _digitLabel.text = digit;

    static NSDictionary *letters = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        letters = @{
            @"2": @"ABC", @"3": @"DEF", @"4": @"GHI", @"5": @"JKL",
            @"6": @"MNO", @"7": @"PQRS", @"8": @"TUV", @"9": @"WXYZ"
        };
    });
    _subLabel.text = letters[digit] ?: @"";

    _digitLabel.hidden = (_digit.length == 0);
    _subLabel.hidden = (_digit.length == 0);
}

- (void)setIsDelete:(BOOL)isDelete {
    _isDelete = isDelete;

    _digitLabel.hidden = isDelete;
    _subLabel.hidden = isDelete;

    if (isDelete && !_iconView) {
        UIImage *icon = [[UIImage systemImageNamed:@"delete.left"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        _iconView = [[UIImageView alloc] initWithImage:icon];
        _iconView.tintColor = [UIColor whiteColor];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:_iconView];
    }
    _iconView.hidden = !isDelete;
    [self setNeedsLayout];
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.backgroundColor = [UIColor colorWithWhite:1.0 alpha:(highlighted ? 0.42 : 0.14)];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat size = CGRectGetWidth(self.bounds);
    _digitLabel.frame = CGRectMake(0, size * 0.16, size, size * 0.46);
    _digitLabel.font = [UIFont systemFontOfSize:size * 0.40 weight:UIFontWeightRegular];
    _subLabel.frame = CGRectMake(0, size * 0.60, size, size * 0.18);
    _subLabel.font = [UIFont systemFontOfSize:size * 0.13 weight:UIFontWeightSemibold];

    CGFloat iconSize = size * 0.30;
    _iconView.frame = CGRectMake((size - iconSize) / 2.0, (size - iconSize) / 2.0, iconSize, iconSize);
}

@end

#pragma mark - Экран разблокировки

@interface FLPasscodeViewController : UIViewController
@property (nonatomic, copy) void (^onUnlock)(void);
@end

@implementation FLPasscodeViewController {
    CAGradientLayer *_gradientLayer;
    CAGradientLayer *_glowLayer;
    UILabel *_dateLabel;
    UILabel *_timeLabel;
    UIImageView *_lockIcon;
    UILabel *_promptLabel;
    FLDotsView *_dotsView;
    UILabel *_errorLabel;
    UIView *_keypad;
    NSMutableArray<FLKeyButton *> *_keys;
    NSMutableString *_entered;
    NSTimer *_clockTimer;
    NSDateFormatter *_timeFormatter;
    NSDateFormatter *_dateFormatter;
    NSInteger _failedAttempts;
    NSTimeInterval _blockedUntil;
    BOOL _unlocking;
}

- (instancetype)init {
    if ((self = [super init])) {
        _entered = [NSMutableString string];
        _keys = [NSMutableArray array];
        _failedAttempts = 0;
        _blockedUntil = 0;
        _unlocking = NO;
    }
    return self;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (BOOL)shouldAutorotate {
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor blackColor];

    _gradientLayer = [CAGradientLayer layer];
    _gradientLayer.colors = @[
        (id)[UIColor colorWithRed:0.07 green:0.09 blue:0.16 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.13 green:0.14 blue:0.27 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.03 green:0.03 blue:0.06 alpha:1.0].CGColor
    ];
    _gradientLayer.locations = @[ @0.0, @0.45, @1.0 ];
    _gradientLayer.startPoint = CGPointMake(0.2, 0.0);
    _gradientLayer.endPoint = CGPointMake(0.8, 1.0);
    [self.view.layer addSublayer:_gradientLayer];

    _glowLayer = [CAGradientLayer layer];
    _glowLayer.type = kCAGradientLayerRadial;
    _glowLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.12].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    _glowLayer.startPoint = CGPointMake(0.5, 0.22);
    _glowLayer.endPoint = CGPointMake(1.0, 0.22);
    [self.view.layer addSublayer:_glowLayer];

    _dateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _dateLabel.textAlignment = NSTextAlignmentCenter;
    _dateLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.85];
    _dateLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [self.view addSubview:_dateLabel];

    _timeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _timeLabel.textAlignment = NSTextAlignmentCenter;
    _timeLabel.textColor = [UIColor whiteColor];
    _timeLabel.font = [UIFont systemFontOfSize:78 weight:UIFontWeightThin];
    _timeLabel.adjustsFontSizeToFitWidth = YES;
    _timeLabel.minimumScaleFactor = 0.5;
    [self.view addSubview:_timeLabel];

    _lockIcon = [[UIImageView alloc] initWithFrame:CGRectZero];
    _lockIcon.image = [[UIImage systemImageNamed:@"lock.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    _lockIcon.tintColor = [UIColor colorWithWhite:1.0 alpha:0.70];
    _lockIcon.contentMode = UIViewContentModeScaleAspectFit;
    [self.view addSubview:_lockIcon];

    _promptLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _promptLabel.text = @"Введите код-пароль";
    _promptLabel.textAlignment = NSTextAlignmentCenter;
    _promptLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.75];
    _promptLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    [self.view addSubview:_promptLabel];

    _dotsView = [[FLDotsView alloc] initWithFrame:CGRectZero];
    _dotsView.total = FLPasscodeLength();
    [self.view addSubview:_dotsView];

    _errorLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _errorLabel.textAlignment = NSTextAlignmentCenter;
    _errorLabel.textColor = [UIColor systemRedColor];
    _errorLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    _errorLabel.alpha = 0.0;
    [self.view addSubview:_errorLabel];

    _keypad = [[UIView alloc] initWithFrame:CGRectZero];
    _keypad.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_keypad];

    NSArray<NSArray<NSString *> *> *rows = @[
        @[ @"1", @"2", @"3" ],
        @[ @"4", @"5", @"6" ],
        @[ @"7", @"8", @"9" ],
        @[ @"",  @"0", @"del" ]
    ];

    for (NSArray<NSString *> *row in rows) {
        for (NSString *title in row) {
            FLKeyButton *key = [[FLKeyButton alloc] initWithFrame:CGRectZero];
            if ([title isEqualToString:@"del"]) {
                key.isDelete = YES;
            } else {
                key.digit = title;
            }
            key.userInteractionEnabled = (title.length > 0);
            key.hidden = (title.length == 0);
            [key addTarget:self action:@selector(keyPressed:) forControlEvents:UIControlEventTouchUpInside];
            [_keypad addSubview:key];
            [_keys addObject:key];
        }
    }

    _timeFormatter = [[NSDateFormatter alloc] init];
    _timeFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"ru_RU"];
    _timeFormatter.dateFormat = @"HH:mm";

    _dateFormatter = [[NSDateFormatter alloc] init];
    _dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"ru_RU"];
    _dateFormatter.dateFormat = @"EEEE, d MMMM";

    [self updateClock];

    _clockTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                   target:self
                                                 selector:@selector(tick)
                                                 userInfo:nil
                                                  repeats:YES];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [_clockTimer invalidate];
    _clockTimer = nil;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGRect bounds = self.view.bounds;
    _gradientLayer.frame = bounds;
    _glowLayer.frame = bounds;

    UIEdgeInsets insets = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) {
        insets = self.view.safeAreaInsets;
    }

    CGFloat y = insets.top + 40.0;

    _dateLabel.frame = CGRectMake(0, y, CGRectGetWidth(bounds), 22);
    y += 26.0;

    _timeLabel.frame = CGRectMake(0, y, CGRectGetWidth(bounds), 92);
    y += 100.0;

    _lockIcon.frame = CGRectMake((CGRectGetWidth(bounds) - 24.0) / 2.0, y, 24.0, 24.0);
    y += 32.0;

    _promptLabel.frame = CGRectMake(0, y, CGRectGetWidth(bounds), 20);
    y += 26.0;

    _dotsView.frame = CGRectMake(0, y, CGRectGetWidth(bounds), 18);
    y += 24.0;

    _errorLabel.frame = CGRectMake(0, y, CGRectGetWidth(bounds), 18);
    y += 18.0;

    CGFloat gapX = 24.0;
    CGFloat gapY = 16.0;
    CGFloat maxWidth = CGRectGetWidth(bounds) - 48.0;
    CGFloat availableHeight = CGRectGetHeight(bounds) - insets.bottom - 26.0 - y - 20.0;

    CGFloat keySize = 75.0;
    if ((keySize * 3.0 + gapX * 2.0) > maxWidth) {
        keySize = (maxWidth - gapX * 2.0) / 3.0;
    }
    CGFloat heightFit = (availableHeight - gapY * 3.0) / 4.0;
    if (heightFit < keySize) {
        keySize = heightFit;
    }
    if (keySize < 44.0) {
        keySize = 44.0;
    }

    CGFloat padWidth = keySize * 3.0 + gapX * 2.0;
    CGFloat padHeight = keySize * 4.0 + gapY * 3.0;
    CGFloat padX = (CGRectGetWidth(bounds) - padWidth) / 2.0;
    CGFloat padY = CGRectGetHeight(bounds) - insets.bottom - padHeight - 26.0;

    _keypad.frame = CGRectMake(padX, padY, padWidth, padHeight);

    for (NSUInteger i = 0; i < _keys.count; i++) {
        NSUInteger row = i / 3;
        NSUInteger column = i % 3;
        FLKeyButton *key = _keys[i];
        key.frame = CGRectMake(column * (keySize + gapX), row * (keySize + gapY), keySize, keySize);
        key.layer.cornerRadius = keySize / 2.0;
    }
}

#pragma mark - Логика

- (BOOL)isBlocked {
    return (_blockedUntil > 0 && [NSDate date].timeIntervalSince1970 < _blockedUntil);
}

- (void)keyPressed:(FLKeyButton *)sender {
    if (_unlocking || [self isBlocked]) {
        return;
    }

    FLPlayKeySound();
    FLHapticLight();

    if (sender.isDelete) {
        if (_entered.length > 0) {
            [_entered deleteCharactersInRange:NSMakeRange(_entered.length - 1, 1)];
            _dotsView.filled = _entered.length;
        }
        return;
    }

    if (sender.digit.length == 0) {
        return;
    }

    if (_entered.length >= FLPasscodeLength()) {
        return;
    }

    [_entered appendString:sender.digit];
    _dotsView.filled = _entered.length;

    if (_entered.length == FLPasscodeLength()) {
        [self commitPasscode];
    }
}

- (void)commitPasscode {
    if ([_entered isEqualToString:FLPasscode()]) {
        _unlocking = YES;
        _failedAttempts = 0;
        _blockedUntil = 0;

        _errorLabel.text = @"Разблокировано";
        _errorLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.90];
        _errorLabel.alpha = 1.0;

        FLHapticSuccess();

        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            typeof(self) strongSelf = weakSelf;
            if (strongSelf && strongSelf.onUnlock) {
                strongSelf.onUnlock();
            }
        });
        return;
    }

    _failedAttempts += 1;
    [_entered setString:@""];
    _dotsView.filled = 0;

    FLHapticError();
    [self shake];

    [self showError:@"Неверный код-пароль" color:[UIColor systemRedColor]];
    [self applyBlockIfNeeded];
}

- (void)applyBlockIfNeeded {
    if (_failedAttempts < 5) {
        return;
    }

    NSTimeInterval delay = 30.0;
    if (_failedAttempts >= 10) {
        delay = 300.0;
    } else if (_failedAttempts >= 8) {
        delay = 120.0;
    } else if (_failedAttempts >= 7) {
        delay = 60.0;
    } else if (_failedAttempts >= 6) {
        delay = 45.0;
    }

    _blockedUntil = [NSDate date].timeIntervalSince1970 + delay;
    [self updateBlockUI];
}

- (void)updateBlockUI {
    NSTimeInterval left = _blockedUntil - [NSDate date].timeIntervalSince1970;

    if (left <= 0) {
        _blockedUntil = 0;
        _keypad.userInteractionEnabled = YES;
        _keypad.alpha = 1.0;
        [UIView animateWithDuration:0.25 animations:^{
            self->_errorLabel.alpha = 0.0;
        }];
        return;
    }

    _keypad.userInteractionEnabled = NO;
    _keypad.alpha = 0.40;
    _errorLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.85];
    _errorLabel.text = [NSString stringWithFormat:@"Повторите через %d с", (int)ceil(left)];
    _errorLabel.alpha = 1.0;
}

- (void)showError:(NSString *)text color:(UIColor *)color {
    _errorLabel.text = text;
    _errorLabel.textColor = color;
    _errorLabel.alpha = 1.0;

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf || [strongSelf isBlocked]) {
            return;
        }
        [UIView animateWithDuration:0.25 animations:^{
            strongSelf->_errorLabel.alpha = 0.0;
        }];
    });
}

- (void)shake {
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    animation.values = @[ @0.0, @(-14.0), @12.0, @(-10.0), @8.0, @(-5.0), @0.0 ];
    animation.keyTimes = @[ @0.0, @0.12, @0.28, @0.44, @0.60, @0.80, @1.0 ];
    animation.duration = 0.42;
    [self.view.layer addAnimation:animation forKey:@"fakepass.shake"];
}

- (void)tick {
    [self updateClock];
    if (_blockedUntil > 0) {
        [self updateBlockUI];
    }
}

- (void)updateClock {
    NSDate *now = [NSDate date];

    _timeLabel.text = [_timeFormatter stringFromDate:now];

    NSString *dateText = [_dateFormatter stringFromDate:now];
    if (dateText.length > 0) {
        dateText = [[[dateText substringToIndex:1] uppercaseString]
                    stringByAppendingString:[dateText substringFromIndex:1]];
    }
    _dateLabel.text = dateText;
}

@end

#pragma mark - Окно поверх лок-скрина

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isUILocked;
- (BOOL)isLockScreenVisible;
- (void)lockScreenViewControllerRequestsUnlock;
- (void)lockUIFromSource:(int)source withOptions:(id)options;
@end

static UIWindow *gLockWindow = nil;
static FLPasscodeViewController *gLockViewController = nil;
static BOOL gFakeLocked = NO;
static BOOL gShowing = NO;
static int gShowAttempts = 0;

static void FLHideLock(BOOL unlockDevice);

static void FLShowLock(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gLockWindow || gShowing) {
            return;
        }

        UIWindowScene *scene = FLBestWindowScene();
        if (!scene) {
            gShowAttempts += 1;
            if (gShowAttempts < 15) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{
                    FLShowLock();
                });
            }
            return;
        }
        gShowAttempts = 0;
        gShowing = YES;

        UIWindow *window = nil;
        if (@available(iOS 13.0, *)) {
            window = [[UIWindow alloc] initWithWindowScene:scene];
            window.frame = scene.coordinateSpace.bounds;
        } else {
            window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        }
        window.windowLevel = UIWindowLevelAlert + 10000.0;
        window.backgroundColor = [UIColor blackColor];
        window.opaque = YES;
        window.alpha = 0.0;

        FLPasscodeViewController *controller = [[FLPasscodeViewController alloc] init];
        controller.onUnlock = ^{
            FLHideLock(YES);
        };
        window.rootViewController = controller;
        window.hidden = NO;

        [UIView animateWithDuration:0.25 animations:^{
            window.alpha = 1.0;
        }];

        gLockWindow = window;
        gLockViewController = controller;
        gFakeLocked = YES;
        gShowing = NO;
    });
}

static void FLHideLock(BOOL unlockDevice) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = gLockWindow;
        gLockWindow = nil;
        gLockViewController = nil;
        gFakeLocked = NO;

        if (!window) {
            return;
        }

        [UIView animateWithDuration:0.30 animations:^{
            window.alpha = 0.0;
        } completion:^(BOOL finished) {
            window.hidden = YES;
            window.rootViewController = nil;
        }];

        if (!unlockDevice) {
            return;
        }

        SBLockScreenManager *manager = [SBLockScreenManager sharedInstance];
        if (!manager) {
            return;
        }

        if ([manager isUILocked]) {
            [manager lockScreenViewControllerRequestsUnlock];
        }
    });
}

#pragma mark - Хуки

%hook SBLockScreenManager

- (void)lockUIFromSource:(int)source withOptions:(id)options {
    %orig;
    FLShowLock();
}

%end

#pragma mark - Старт

%ctor {
    @autoreleasepool {
        NSLog(@"[FakePass13] загружен");

        if (FLConfigBool(@"lockOnRespring", NO)) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                FLShowLock();
            });
        }
    }
}
