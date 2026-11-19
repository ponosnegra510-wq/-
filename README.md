# FakePass13

Фейковый экран код-пароля для **iOS 13** (iPhone 11 / A13 и другие arm64-устройства).

Сделан для ситуации, когда после отката (SEP не работает) настоящий код-пароль и Face ID
недоступны, но хочется, чтобы телефон выглядел заблокированным: часы, дата, замок и
клавиатура, а без кода дальше не пройти.

Твик **не является защитой**. Это ровно та «иллюзия безопасности», которая и нужна:
от человека, который просто взял телефон в руки — да; от того, у кого есть Filza/SSH — нет.

---

## Что делает

* ловит блокировку устройства (`SBLockScreenManager -lockUIFromSource:withOptions:`);
* показывает своё полноэкранное окно поверх системного лок-скрина (уровень `UIWindowLevelAlert + 10000`);
* рисует часы, дату, иконку замка, точки и цифровую клавиатуру (4–8 цифр);
* при верном коде гасит окно и дёргает системную разблокировку
  (`SBLockScreenManager -lockScreenViewControllerRequestsUnlock`);
* при неверном — трясёт экран, показывает «Неверный код-пароль» и включает паузы
  после 5/6/7/8/10 попыток (30 с → 5 мин).

## Чего НЕ делает (специально)

* не трогает keybag, SEP и настоящий код-пароль;
* **не умеет стирать устройство** (в оригинальном FakePass есть ветка с `SBDataReset` —
  на iOS 13 её классов нет, и тащить такое вслепую нельзя);
* не работает внутри приложений: он живёт в SpringBoard, поэтому и рассчитан на
  реально заблокированное устройство (тогда лок-скрин и так выше всех приложений);
* после перезагрузки без джейлбрейка, само собой, не работает.

---

## Требования

* iOS **13.0 – 13.7**;
* джейлбрейк с Substrate/Substitute/libhooker (unc0ver, Odyssey, Chimera…);
* arm64 / arm64e.

## Установка

1. Собрать `.deb` (см. «Сборка»).
2. Установить: Sileo/Zebra → `FakePass13.deb`, либо `dpkg -i FakePass13.deb` по SSH,
   либо открыть `.deb` в Filza.
3. Respring (после установки он и так будет).

## Настройка

Файл: `/Library/Preferences/com.mell.fakepass13.plist`

```xml
<key>passcode</key>       <string>1234</string>   <!-- твой код, 4–8 цифр -->
<key>lockOnRespring</key> <false/>                <!-- блокироваться сразу после respring -->
```

Редактируется в Filza (открыть как Property List / текст). После правки — respring.

> **Важно:** по умолчанию `lockOnRespring = false`. Это сделано, чтобы после установки
> ты не оказался заперт на экране, код от которого ещё не проверил. Сначала убедись,
> что код работает (см. ниже), и только потом включай `true`.

### Как проверить

1. Оставь `lockOnRespring = false`, сделай respring.
2. Нажми кнопку питания (экран выключится), затем включи — должен появиться замок.
3. Введи код из plist — телефон разблокируется.
4. Если всё ок — поставь `lockOnRespring = true` и сделай respring.

## Если залочился и код не помнишь

1. Перезагрузка → джейлбрейк **без загрузки твиков**
   (в unc0ver выключи `Load Tweaks`), затем Filza → поправь/удали
   `/Library/Preferences/com.mell.fakepass13.plist` → перезагрузись и включи твики.
2. Либо по SSH: `rm /Library/Preferences/com.mell.fakepass13.plist`.
3. Либо Safe Mode (в unc0ver: удержание кнопки громкости вверх во время respring).

Данные при этом не теряются — твик ничего не стирает.

---

## Сборка

### Вариант 1 — GitHub Actions (ничего устанавливать не надо)

1. Залей папку `FakePass13` в свой репозиторий на GitHub (можно приватный).
2. Workflow уже лежит в `.github/workflows/build.yml` — он соберёт пакет сам.
3. Вкладка **Actions** → последний запуск → артефакт **FakePass13** → внутри `.deb`.
4. Скачай и установи на телефон.

### Вариант 2 — локально (macOS, либо WSL/Linux)

macOS:

```sh
brew install ldid
export THEOS=~/theos
git clone --recursive https://github.com/theos/theos.git $THEOS
mkdir -p $THEOS/sdks
curl -L https://github.com/theos/sdks/archive/master.tar.gz | tar xz -C $THEOS/sdks --strip-components=1
make package FINALPACKAGE=1
```

Linux/WSL:

```sh
sudo apt install -y make git curl xz-utils libssl-dev
export THEOS=~/theos
git clone --recursive https://github.com/theos/theos.git $THEOS
mkdir -p $THEOS/sdks
curl -L https://github.com/theos/sdks/archive/master.tar.gz | tar xz -C $THEOS/sdks --strip-components=1
# ldid: положи бинарник в $THEOS/bin и сделай chmod +x
make package FINALPACKAGE=1
```

Готовый пакет — в `packages/`.

### Если сборка ругается на arm64e

Убери `arm64e` из `ARCHS` в `Makefile` — на iOS 13 arm64-твики прекрасно грузятся
в arm64e-процессы.

---

## Файлы

```
Tweak.xm                     — весь код (UI + хук)
FakePass13.plist             — фильтр: только com.apple.springboard
Makefile / control           — Theos-пакет
layout/Library/Preferences/  — дефолтный конфиг (код 1234)
.github/workflows/build.yml  — сборка .deb в облаке
```

## Ограничения / нюансы

* Это оверлей, а не системный лок-скрин: уведомлений, камеры и виджетов там нет.
* Если во время блокировки придёт звонок или сработает будильник, системный UI
  может оказаться выше замка.
* Siri/уведомления в редких случаях могут вытащить приложение наверх — нажми
  питание, замок вернётся.
* Не ставь настоящий FakePass (он для checkm8 + iOS 14+) — они будут конфликтовать.

## Благодарности

Идея и поведение вдохновлены [FakePass](https://github.com/lunaynx/fakepass) (alexia, MIT).
Код здесь самостоятельный: под iOS 13 и без потенциально опасных веток.
