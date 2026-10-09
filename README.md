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

Версия берётся из исходников: workflow определяет последний релиз `hoaxisr/amnezia-box`, собирает его и публикует релиз с тем же тегом. Запускается раз в 8 часов и вручную (Actions → **build-openwrt** → Run workflow); если релиз с таким тегом уже есть, сборка пропускается (`force` пересобирает). При желании можно указать свой `source_repo` и `source_ref` (ветку или тег). Собираются `mipsel`, `mips`, `arm64`, `armv7`, `armv5`, `amd64`, `386` с тегами `with_awg,with_low_memory` (без naive-исходящего).

## Статус

Сборки и установщик ещё не проверены на реальном роутере. Проект не связан с авторами Amnezia и sing-box; лицензия исходного кода — GPLv3.
