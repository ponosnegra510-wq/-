//
//  FakePass13RootListController.m
//  Панель настроек FakePass13 в приложении «Настройки»
//

#import <UIKit/UIKit.h>

#if __has_include(<Preferences/PSListController.h>)
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#else
// Резервные объявления на случай, если в SDK нет заголовков Preferences.
typedef NS_ENUM(NSInteger, PSCellType) {
    PSGroupCell = 0, PSLinkCell = 1, PSLinkListCell = 2, PSListItemCell = 3,
    PSTitleValueCell = 4, PSSliderCell = 5, PSSwitchCell = 6, PSStaticTextCell = 7,
    PSEditTextCell = 8, PSSegmentCell = 9, PSGiantIconCell = 10, PSGiantCell = 11,
    PSSecureEditTextCell = 12, PSButtonCell = 13, PSEditTextViewCell = 14
};

@interface PSSpecifier : NSObject
+ (instancetype)preferenceSpecifierNamed:(NSString *)name
                                  target:(id)target
                                     set:(SEL)set
                                     get:(SEL)get
                                  detail:(Class)detail
                                    cell:(PSCellType)cell
                                    edit:(Class)edit;
+ (instancetype)emptyGroupSpecifier;
- (void)setProperty:(id)value forKey:(NSString *)key;
- (id)propertyForKey:(NSString *)key;
- (void)setName:(NSString *)name;
- (void)setButtonAction:(SEL)action;
@end

@interface PSListController : UIViewController {
    NSArray *_specifiers;
}
- (NSArray *)specifiers;
- (id)readPreferenceValue:(PSSpecifier *)specifier;
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier;
- (void)reloadSpecifier:(PSSpecifier *)specifier;
@end
#endif

#import <notify.h>

static NSString *const FLDomain = @"com.mell.fakepass13";
static NSString *const FLNotifyChanged = @"com.mell.fakepass13/prefs-changed";
static NSString *const FLNotifyLockNow = @"com.mell.fakepass13/lock-now";

@interface FakePass13RootListController : PSListController
@end

@implementation FakePass13RootListController {
    NSUserDefaults *_flDefaults;
    PSSpecifier *_passcodeSpecifier;
}

#pragma mark - Настройки

- (NSUserDefaults *)flDefaults {
    if (!_flDefaults) {
        _flDefaults = [[NSUserDefaults alloc] initWithSuiteName:FLDomain];
    }
    return _flDefaults;
}

- (void)flSync {
    [[self flDefaults] synchronize];
    notify_post([FLNotifyChanged UTF8String]);
}

- (NSString *)flString:(NSString *)key fallback:(NSString *)fallback {
    id value = [[self flDefaults] objectForKey:key];
    if ([value isKindOfClass:[NSString class]] && [value length] > 0) {
        return value;
    }
    return fallback;
}

- (BOOL)flBool:(NSString *)key fallback:(BOOL)fallback {
    id value = [[self flDefaults] objectForKey:key];
    return value ? [value boolValue] : fallback;
}

- (id)flLegacyValue:(NSString *)key {
    // старый файл-конфиг, если панель ставят на уже настроенный твик
    NSDictionary *legacy = [NSDictionary dictionaryWithContentsOfFile:@"/Library/Preferences/com.mell.fakepass13.plist"];
    if ([legacy isKindOfClass:[NSDictionary class]]) {
        id value = legacy[key];
        if (value != nil) {
            return value;
        }
    }
    return nil;
}

- (NSString *)flPasscode {
    id value = [[self flDefaults] objectForKey:@"passcode"];
    if (![value isKindOfClass:[NSString class]] || [value length] < 4) {
        value = [self flLegacyValue:@"passcode"];
    }
    if ([value isKindOfClass:[NSString class]] && [value length] >= 4) {
        return value;
    }
    return @"1234";
}

- (NSString *)flDigitsOnly:(NSString *)text max:(NSUInteger)max {
    NSMutableString *digits = [NSMutableString string];
    for (NSUInteger i = 0; i < [text length] && [digits length] < max; i++) {
        unichar c = [text characterAtIndex:i];
        if (c >= '0' && c <= '9') {
            [digits appendFormat:@"%C", c];
        }
    }
    return digits;
}

#pragma mark - Спецификаторы

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specifiers = [NSMutableArray array];

        PSSpecifier *intro = [PSSpecifier emptyGroupSpecifier];
        [intro setProperty:@"FakePass13 рисует собственный экран код-пароля поверх системного лок-скрина. "
                           @"Настоящий код-пароль и Face ID при этом не используются."
                   forKey:@"footerText"];
        [specifiers addObject:intro];

        PSSpecifier *enabled = [PSSpecifier preferenceSpecifierNamed:@"Включено"
                                                             target:self
                                                                set:@selector(setPreferenceValue:specifier:)
                                                                get:@selector(readPreferenceValue:)
                                                             detail:nil
                                                               cell:PSSwitchCell
                                                               edit:nil];
        [enabled setProperty:@"enabled" forKey:@"key"];
        [enabled setProperty:@YES forKey:@"default"];
        [specifiers addObject:enabled];

        _passcodeSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Код-пароль"
                                                            target:self
                                                               set:nil
                                                               get:nil
                                                            detail:nil
                                                              cell:PSButtonCell
                                                              edit:nil];
        [_passcodeSpecifier setProperty:NSStringFromSelector(@selector(changePasscode:)) forKey:@"action"];
        [_passcodeSpecifier setButtonAction:@selector(changePasscode:)];
        [specifiers addObject:_passcodeSpecifier];

        PSSpecifier *respringGroup = [PSSpecifier emptyGroupSpecifier];
        [respringGroup setProperty:@"Показывать экран код-пароля автоматически после перезагрузки SpringBoard. "
                                   @"Включайте, только когда код точно запомнен."
                            forKey:@"footerText"];
        [specifiers addObject:respringGroup];

        PSSpecifier *lockOnRespring = [PSSpecifier preferenceSpecifierNamed:@"Показывать после respring"
                                                                    target:self
                                                                       set:@selector(setPreferenceValue:specifier:)
                                                                       get:@selector(readPreferenceValue:)
                                                                    detail:nil
                                                                      cell:PSSwitchCell
                                                                      edit:nil];
        [lockOnRespring setProperty:@"lockOnRespring" forKey:@"key"];
        [lockOnRespring setProperty:@NO forKey:@"default"];
        [specifiers addObject:lockOnRespring];

        PSSpecifier *testGroup = [PSSpecifier emptyGroupSpecifier];
        [testGroup setProperty:@"Проверка: экран код-пароля появится сразу, без respring."
                        forKey:@"footerText"];
        [specifiers addObject:testGroup];

        PSSpecifier *lockNow = [PSSpecifier preferenceSpecifierNamed:@"Заблокировать сейчас"
                                                              target:self
                                                                 set:nil
                                                                 get:nil
                                                              detail:nil
                                                                cell:PSButtonCell
                                                                edit:nil];
        [lockNow setProperty:NSStringFromSelector(@selector(lockNow:)) forKey:@"action"];
        [lockNow setButtonAction:@selector(lockNow:)];
        [specifiers addObject:lockNow];

        PSSpecifier *resetGroup = [PSSpecifier emptyGroupSpecifier];
        [resetGroup setProperty:@"Если код забыт: сбросьте его здесь либо удалите твик из Cydia/Zebra "
                                @"(по SSH или через Filza удалите /Library/Preferences/com.mell.fakepass13.plist)."
                         forKey:@"footerText"];
        [specifiers addObject:resetGroup];

        PSSpecifier *reset = [PSSpecifier preferenceSpecifierNamed:@"Сбросить код на 1234"
                                                            target:self
                                                               set:nil
                                                               get:nil
                                                            detail:nil
                                                              cell:PSButtonCell
                                                              edit:nil];
        [reset setProperty:NSStringFromSelector(@selector(resetPasscode:)) forKey:@"action"];
        [reset setButtonAction:@selector(resetPasscode:)];
        [specifiers addObject:reset];

        _specifiers = specifiers;
    }

    [self updatePasscodeTitle];
    return _specifiers;
}

- (void)updatePasscodeTitle {
    [_passcodeSpecifier setName:[NSString stringWithFormat:@"Код-пароль: %@", [self flPasscode]]];
}

#pragma mark - Чтение и запись значений

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (![key isKindOfClass:[NSString class]]) {
        return nil;
    }

    id value = [[self flDefaults] objectForKey:key];
    if (value != nil) {
        return value;
    }

    value = [self flLegacyValue:key];
    if (value != nil) {
        return value;
    }

    return [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (![key isKindOfClass:[NSString class]]) {
        return;
    }

    [[self flDefaults] setObject:value forKey:key];
    [self flSync];
}

#pragma mark - Действия

- (void)showAlert:(NSString *)text {
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"FakePass13"
                                                                      message:text
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Ок" style:UIAlertActionStyleDefault handler:nil]];
        [strongSelf presentViewController:alert animated:YES completion:nil];
    });
}

- (void)changePasscode:(PSSpecifier *)specifier {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Код-пароль"
                                                                  message:@"Введите от 4 до 8 цифр. Этот код будет запрашиваться на экране блокировки."
                                                           preferredStyle:UIAlertControllerStyleAlert];

    __weak typeof(self) weakSelf = self;
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.placeholder = @"1234";
        textField.text = [weakSelf flPasscode];
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Сохранить" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        NSString *text = [strongSelf flDigitsOnly:(alert.textFields.firstObject.text ?: @"") max:8];
        if ([text length] < 4) {
            [strongSelf showAlert:@"Код должен состоять из 4–8 цифр."];
            return;
        }

        [[strongSelf flDefaults] setObject:text forKey:@"passcode"];
        [strongSelf flSync];
        [strongSelf updatePasscodeTitle];
        [strongSelf reloadSpecifier:strongSelf->_passcodeSpecifier];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)lockNow:(PSSpecifier *)specifier {
    notify_post([FLNotifyLockNow UTF8String]);
}

- (void)resetPasscode:(PSSpecifier *)specifier {
    [[self flDefaults] setObject:@"1234" forKey:@"passcode"];
    [self flSync];
    [self updatePasscodeTitle];
    [self reloadSpecifier:_passcodeSpecifier];
    [self showAlert:@"Код сброшен на 1234."];
}

@end
