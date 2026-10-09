#!/bin/sh
# Установка / обновление / удаление amnezia-box (sing-box + AmneziaWG) на OpenWrt.
#
#   sh install-openwrt.sh                 установить или обновить (скачать из релиза)
#   sh install-openwrt.sh /tmp/amnezia-box установить из локального файла
#   sh install-openwrt.sh uninstall       удалить (конфиг /etc/amnezia-box остаётся)
#
# Переменные:
#   REPO=user/repo    GitHub-репозиторий с релизами (по умолчанию phenomenonRT/amnezia-box)
#   VERSION=tag       конкретный тег релиза (по умолчанию latest)
#   BIN_URL=https://… прямая ссылка на бинарник (вместо REPO)
#   BIN_DIR=/usr/bin  куда класть бинарник (при нехватке флеша: каталог на USB)
#   UPX=1             брать сжатую сборку (-upx); займёт больше ОЗУ при запуске
#   BASE_URL=https://…  зеркало вместо github.com (путь как у GitHub Releases)
#   AUTOSTART=1       запустить службу сразу, если конфиг уже есть
REPO="${REPO:-phenomenonRT/amnezia-box}"
set -eu

NAME=amnezia-box
BIN_DIR="${BIN_DIR:-/usr/bin}"
BIN="$BIN_DIR/$NAME"
CONF_DIR="/etc/$NAME"
INIT="/etc/init.d/$NAME"
WORK_DIR="/usr/share/$NAME"
TMP="/tmp/$NAME-install.$$"

say()  { printf '%s\n' "$*"; }
die()  { printf 'Ошибка: %s\n' "$*" >&2; rm -rf "$TMP"; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

[ "$(id -u)" = 0 ] || die "нужен root"
[ -f /etc/openwrt_release ] || die "это не OpenWrt (нет /etc/openwrt_release); для Keenetic/Entware используйте другой установщик"

# ---------- удаление ----------
if [ "${1:-}" = uninstall ]; then
  [ -x "$INIT" ] && { "$INIT" stop 2>/dev/null || true; "$INIT" disable 2>/dev/null || true; }
  rm -f "$INIT" "$BIN" "/usr/bin/$NAME" "/lib/upgrade/keep.d/$NAME"
  rm -rf "$WORK_DIR"
  say "Удалено. Конфигурация осталась в $CONF_DIR (удалите вручную при необходимости)."
  exit 0
fi

# ---------- архитектура ----------
. /etc/openwrt_release
OWRT_ARCH="${DISTRIB_ARCH:-$(uname -m)}"
case "$OWRT_ARCH" in
  mipsel_*)                         GRP=mipsel ;;
  mips64*|mips64el*)                die "mips64 не поддерживается сборкой ($OWRT_ARCH)" ;;
  mips_*)                           GRP=mips ;;
  aarch64_*|aarch64)                GRP=arm64 ;;
  arm_cortex-a5*|arm_cortex-a7*|arm_cortex-a8*|arm_cortex-a9*|arm_cortex-a15*|armv7*) GRP=armv7 ;;
  arm_*|armv6*|armv5*)              GRP=armv5 ;;
  x86_64)                           GRP=amd64 ;;
  i386_*|i686|i586)                 GRP=386 ;;
  *) die "неизвестная архитектура: $OWRT_ARCH" ;;
esac
say "OpenWrt ${DISTRIB_RELEASE:-?}, архитектура $OWRT_ARCH → сборка linux-$GRP"

# ---------- получение бинарника ----------
mkdir -p "$TMP"
SRC="${1:-}"
if [ -n "$SRC" ]; then
  [ -f "$SRC" ] || die "файл не найден: $SRC"
  cp "$SRC" "$TMP/$NAME"
else
  ASSET="$NAME-linux-$GRP"
  [ "${UPX:-0}" = 1 ] && ASSET="$ASSET-upx"
  if [ -n "${BIN_URL:-}" ]; then
    URL="$BIN_URL"; SUM_URL=""
  else
    [ -n "$REPO" ] || die "укажите REPO, BIN_URL или путь к файлу"
    BASE="${BASE_URL:-https://github.com}/$REPO/releases"
    if [ -n "${VERSION:-}" ]; then P="$BASE/download/$VERSION"; else P="$BASE/latest/download"; fi
    URL="$P/$ASSET"; SUM_URL="$P/$ASSET.sha256"
  fi
  if   have curl;         then dl() { curl -fsSL -o "$2" "$1"; }
  elif have uclient-fetch; then dl() { uclient-fetch -q -O "$2" "$1"; }
  elif have wget;         then dl() { wget -q -O "$2" "$1"; }
  else die "нет curl / uclient-fetch / wget"; fi
  say "Скачиваю $URL"
  dl "$URL" "$TMP/$NAME" || die "не удалось скачать (для HTTPS нужны ca-bundle и libustream-*; проверьте REPO/VERSION, при блокировке GitHub задайте BASE_URL)"
  if [ -n "$SUM_URL" ] && dl "$SUM_URL" "$TMP/sum" 2>/dev/null; then
    want="$(cut -d' ' -f1 "$TMP/sum")"; got="$(sha256sum "$TMP/$NAME" | cut -d' ' -f1)"
    [ "$want" = "$got" ] || die "контрольная сумма не совпала"
    say "SHA256 совпадает"
  else
    say "Предупреждение: .sha256 не получен, проверка пропущена"
  fi
fi
chmod +x "$TMP/$NAME"

# проверка, что бинарник запускается на этом роутере и содержит AWG
OUT="$("$TMP/$NAME" version 2>&1)" || die "бинарник не запускается на этом роутере ($OWRT_ARCH): $OUT"
say "$(printf '%s' "$OUT" | head -n 1)"
printf '%s' "$OUT" | grep -q with_awg || say "Предупреждение: в тегах сборки нет with_awg — узлы типа awg работать не будут"

# ---------- место ----------
mkdir -p "$BIN_DIR"
need_kb=$(( $(wc -c < "$TMP/$NAME") / 1024 + 512 ))
free_kb=$(df -k "$BIN_DIR" | awk 'NR==2{print $4}')
[ -n "$free_kb" ] && [ "$free_kb" -lt "$need_kb" ] && \
  die "мало места в $BIN_DIR (нужно ≈${need_kb} КБ, свободно ${free_kb} КБ). Подключите USB и запустите: BIN_DIR=/mnt/sda1/$NAME sh $0"

# ---------- зависимости ----------
if   have apk;  then pm_has() { apk info -e "$1" >/dev/null 2>&1; }; pm_inst() { apk add "$@"; }; pm_upd() { apk update; }
elif have opkg; then pm_has() { opkg list-installed 2>/dev/null | grep -q "^$1 "; }; pm_inst() { opkg install "$@"; }; pm_upd() { opkg update; }
else pm_has() { return 0; }; pm_inst() { :; }; pm_upd() { :; }; say "Пакетный менеджер не найден — зависимости не проверяю"; fi
MISSING=""
for p in ca-bundle kmod-tun; do pm_has "$p" || MISSING="$MISSING $p"; done
if [ -n "$MISSING" ]; then
  say "Устанавливаю зависимости:$MISSING"
  pm_upd >/dev/null 2>&1 || true
  # shellcheck disable=SC2086
  pm_inst $MISSING || say "Предупреждение: не удалось поставить$MISSING (kmod-tun нужен только для режима TUN)"
fi

# ---------- установка ----------
WAS_RUNNING=0
if [ -x "$INIT" ] && "$INIT" running >/dev/null 2>&1; then WAS_RUNNING=1; "$INIT" stop || true; fi
cp "$TMP/$NAME" "$BIN.new" && mv "$BIN.new" "$BIN"
[ "$BIN" != "/usr/bin/$NAME" ] && ln -sf "$BIN" "/usr/bin/$NAME"
mkdir -p "$CONF_DIR" "$WORK_DIR"

cat > "$INIT" <<'EOF'
#!/bin/sh /etc/rc.common
# amnezia-box (sing-box + AWG)
USE_PROCD=1
START=99
STOP=10

PROG=/usr/bin/amnezia-box
CONF=/etc/amnezia-box/config.json
WORKDIR=/usr/share/amnezia-box

start_service() {
	[ -s "$CONF" ] || { echo "amnezia-box: нет $CONF" >&2; return 1; }
	"$PROG" check -c "$CONF" || { echo "amnezia-box: конфиг не прошёл проверку" >&2; return 1; }
	procd_open_instance
	procd_set_param command "$PROG" run -c "$CONF" -D "$WORKDIR"
	procd_set_param file "$CONF"
	procd_set_param stderr 1
	procd_set_param respawn 3600 5 5
	procd_set_param limits nofile="65535 65535"
	procd_close_instance
}

service_triggers() {
	procd_add_reload_trigger amnezia-box
}
EOF
chmod +x "$INIT"

# сохранять конфиг при sysupgrade
mkdir -p /lib/upgrade/keep.d
printf '%s/\n' "$CONF_DIR" > "/lib/upgrade/keep.d/$NAME"

"$INIT" enable
rm -rf "$TMP"

if [ -s "$CONF_DIR/config.json" ]; then
  if [ "$WAS_RUNNING" = 1 ] || [ "${AUTOSTART:-0}" = 1 ]; then "$INIT" start && say "Служба запущена"; else say "Конфиг найден. Запуск: $INIT start"; fi
else
  say "Конфига ещё нет: создайте $CONF_DIR/config.json (например, из corepanel), проверьте"
  say "  $NAME check -c $CONF_DIR/config.json"
  say "и запустите: $INIT start"
fi
say "Готово: $BIN"
