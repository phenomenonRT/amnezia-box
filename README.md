# amnezia-box для OpenWrt

Статические сборки [amnezia-box](https://github.com/hoaxisr/amnezia-box) (sing-box + AmneziaWG) для OpenWrt и установщик со службой procd.

## Установка на роутер

```sh
wget -O /tmp/install-openwrt.sh https://raw.githubusercontent.com/phenomenonRT/amnezia-box/main/install-openwrt.sh
sh /tmp/install-openwrt.sh
```

Для HTTPS нужны `ca-bundle` и `libustream-*` (на стандартной OpenWrt они есть). Скрипт определяет архитектуру по `/etc/openwrt_release`, ставит `ca-bundle` и `kmod-tun`, кладёт бинарник в `/usr/bin/amnezia-box` и создаёт `/etc/init.d/amnezia-box`.

Конфиг: `/etc/amnezia-box/config.json` (сохраняется при sysupgrade). Проверка и запуск:

```sh
amnezia-box check -c /etc/amnezia-box/config.json
/etc/init.d/amnezia-box start
```

Переменные: `VERSION` (тег релиза, например `1.15.0-alpha.6-awgm.24`), `BIN_DIR` (например, каталог на USB), `PLAIN=1` (несжатая сборка вместо сжатой), `BASE_URL` (зеркало GitHub), `BIN_URL` (прямая ссылка). Установка из файла: `sh install-openwrt.sh /tmp/amnezia-box`. Удаление: `sh install-openwrt.sh uninstall`.

## Установка пакетом (.ipk)

В релизе рядом с бинарниками лежит `amnezia-box_<версия>_<группа>.ipk` (внутри сжатый бинарник и init-скрипт). Его можно загрузить через LuCI (System → Software → Upload Package) или поставить так: `opkg install /tmp/amnezia-box_*.ipk`. Группа выбирается по архитектуре (`cat /etc/openwrt_release | grep ARCH`):

| DISTRIB_ARCH | группа |
|---|---|
| `mipsel_*` | `mipsel` |
| `mips_*` | `mips` |
| `aarch64_*` | `arm64` |
| `arm_cortex-a5/a7/a8/a9/a15*` | `armv7` |
| остальные `arm_*` | `armv5` |

Пакет объявлен как `Architecture: all`, поэтому `opkg` не отвергнет файл не той группы, выбирайте внимательно. `.ipk` рассчитан на `opkg` (OpenWrt 24.10); для OpenWrt 25.x с `apk` используйте скрипт `install-openwrt.sh`. Сами файлы без расширения (`amnezia-box-linux-*`) пакетами не являются, их нельзя загружать как пакет.

## Сборка

Версии берутся из исходников: по умолчанию workflow собирает последний релиз `hoaxisr/amnezia-box` и публикует релиз с тем же тегом. Запускается раз в 8 часов и вручную (Actions → **build-openwrt** → Run workflow). В `source_ref` можно перечислить несколько тегов через запятую, например `1.15.0-alpha.6-awgm.24,1.15.0-alpha.6-awgm.25`; уже собранные версии пропускаются (`force` пересобирает). Основной бинарник сжат UPX (`-9 --lzma`), как в [rndnaame/awg-compressed](https://github.com/rndnaame/awg-compressed); рядом лежит несжатый `-plain`: сжатый экономит флеш, но при запуске распаковывается в ОЗУ. Собираются только роутерные архитектуры: `mipsel`, `mips`, `arm64`, `armv7`, `armv5` (x86 не собирается), с тегами `with_awg,with_low_memory`, без naive-исходящего. Один и тот же бинарник работает на OpenWrt 24.10 (opkg) и 25.x (apk).

## Статус

Сборки и установщик ещё не проверены на реальном роутере. Проект не связан с авторами Amnezia и sing-box; лицензия исходного кода — GPLv3.
