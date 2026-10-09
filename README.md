# amnezia-box для OpenWrt

Статические сборки [amnezia-box](https://github.com/hoaxisr/amnezia-box) (sing-box + AmneziaWG) для OpenWrt и установщик со службой procd.

## Установка на роутер

```sh
wget -O /tmp/install-openwrt.sh https://raw.githubusercontent.com/phenomenonRT/amnezia-box/main/install-openwrt.sh
sh /tmp/install-openwrt.sh
```

Для HTTPS нужны `ca-bundle` и `libustream-*` (на стандартной OpenWrt они есть). Скрипт определяет архитектуру по `/etc/openwrt_release`, проверяет SHA256, ставит `ca-bundle` и `kmod-tun`, кладёт бинарник в `/usr/bin/amnezia-box` и создаёт `/etc/init.d/amnezia-box`.

Конфиг: `/etc/amnezia-box/config.json` (сохраняется при sysupgrade). Проверка и запуск:

```sh
amnezia-box check -c /etc/amnezia-box/config.json
/etc/init.d/amnezia-box start
```

Переменные: `VERSION` (тег релиза), `BIN_DIR` (например, каталог на USB), `UPX=1` (сжатая сборка, при запуске занимает больше ОЗУ), `BASE_URL` (зеркало GitHub), `BIN_URL` (прямая ссылка). Установка из файла: `sh install-openwrt.sh /tmp/amnezia-box`. Удаление: `sh install-openwrt.sh uninstall`.

## Сборка

Actions → **build-openwrt** → Run workflow: указать ветку/тег исходников (`source_ref`, по умолчанию `awg-1.14.1`) и `release_tag`. Собираются `mipsel`, `mips`, `arm64`, `armv7`, `armv5`, `amd64`, `386` с тегами `with_awg,with_low_memory` (без naive-исходящего). Результат публикуется в Releases.

## Статус

Сборки и установщик ещё не проверены на реальном роутере. Проект не связан с авторами Amnezia и sing-box; лицензия исходного кода — GPLv3.
