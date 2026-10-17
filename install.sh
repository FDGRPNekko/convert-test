#!/usr/bin/env bash
# Remnawave Node + SelfSteal
# FreezeDev — https://github.com/FDGRPNekko

set -euo pipefail

NODE_DIR=/opt/remnanode
STEAL_DIR=/opt/selfsteal
HTML_DIR=/opt/html
CERTS_DIR=$NODE_DIR/xray-certs
SYNC_BIN=$NODE_DIR/sync-certs-selfsteal.sh
HY2_DOMAIN_FILE=$NODE_DIR/.hy2-domain
CRON_TAG='# remnawave-hy2-certs'
SYNC_LOG=/var/log/xray-certs-sync.log
FRZ_BIN=/usr/local/bin/frz-tool
FRZ_LIB=/usr/local/lib/frz-tool
SSHD_CFG=/etc/ssh/sshd_config
CHAIN=0
CADDY_KIND=unknown
CADDY_NOTE=""
STEAL_VULN=0
STEAL_VULN_WHY=""
RESHALA_URL=https://raw.githubusercontent.com/DonMatteoVPN/Reshala-Remnawave-Bedolaga/main/install.sh
STUB_URL=https://github.com/FDGRPNekko/convert-test/archive/refs/heads/main.tar.gz

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
C='\033[0;36m'
D='\033[0;90m'
N='\033[0m'
B='\033[1m'

need_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${R}запусти от root: sudo bash $0${N}"
    exit 1
  fi
}

pause() {
  echo
  read -rp "enter чтобы продолжить... " _
}

maybe_pause() {
  [[ $CHAIN == 1 ]] || pause
}

ask() {
  local p=$1 d=${2:-} a
  if [[ -n $d ]]; then
    read -rp "$p [$d]: " a
    echo "${a:-$d}"
  else
    read -rp "$p: " a
    echo "$a"
  fi
}

yn() {
  local p=$1 d=${2:-n} a
  while true; do
    read -rp "$p (y/n) [$d]: " a
    a=${a:-$d}
    case ${a,,} in
      y|yes|д|да) return 0 ;;
      n|no|н|нет) return 1 ;;
    esac
    echo "y или n"
  done
}

have_docker() {
  command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1
}

# обычный curl, если завис на ipv6 — повтор по ipv4, потом wget -4
fetch_file() {
  local url=$1 dest=$2
  rm -f "$dest"
  if curl -fsSL --connect-timeout 8 --max-time 60 -o "$dest" "$url" && [[ -s $dest ]]; then
    return 0
  fi
  echo -e "${Y}загрузка не пошла, пробую ipv4${N}"
  rm -f "$dest"
  if curl -4 -fsSL --connect-timeout 10 --max-time 90 -o "$dest" "$url" && [[ -s $dest ]]; then
    return 0
  fi
  command -v wget >/dev/null 2>&1 || apt-get install -y -qq wget >/dev/null 2>&1 || true
  if command -v wget >/dev/null 2>&1; then
    rm -f "$dest"
    wget -4 -q -O "$dest" "$url" && [[ -s $dest ]] && return 0
  fi
  rm -f "$dest"
  return 1
}

ensure_docker() {
  if have_docker; then
    echo -e "${G}docker уже есть${N}"
    return
  fi
  echo -e "${Y}ставлю docker...${N}"
  apt-get update -qq
  apt-get install -y -qq curl ca-certificates >/dev/null
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker >/dev/null 2>&1 || true
  if ! have_docker; then
    echo -e "${R}docker не встал, разберись руками${N}"
    exit 1
  fi
  echo -e "${G}docker ок${N}"
}

node_up() {
  docker ps --format '{{.Names}}' 2>/dev/null | grep -qx remnanode
}

steal_up() {
  docker ps --format '{{.Names}}' 2>/dev/null | grep -qx caddy-remnawave
}

node_installed() {
  [[ -f $NODE_DIR/docker-compose.yml ]] || node_up
}

steal_installed() {
  [[ -f $STEAL_DIR/docker-compose.yml ]] || steal_up
}

hy2_ready() {
  [[ -x $SYNC_BIN && -f $CERTS_DIR/fullchain.pem && -f $CERTS_DIR/privkey.pem ]]
}

connector_up() {
  [[ -f /etc/node-connector/config ]] \
    && systemctl is-active --quiet node-connector-link.service 2>/dev/null
}

steal_domain_guess() {
  local d=
  if [[ -f $HY2_DOMAIN_FILE ]]; then
    d=$(tr -d '[:space:]' <"$HY2_DOMAIN_FILE")
  fi
  if [[ -z $d && -f $STEAL_DIR/.env ]]; then
    d=$(grep -E '^SELF_STEAL_DOMAIN=' "$STEAL_DIR/.env" | head -1 | cut -d= -f2-)
    d=${d//\"/}
    d=${d//\'/}
    d=${d// /}
  fi
  printf '%s' "$d"
}

steal_port_guess() {
  local p=9443
  if [[ -f $STEAL_DIR/.env ]]; then
    p=$(grep -E '^SELF_STEAL_PORT=' "$STEAL_DIR/.env" | head -1 | cut -d= -f2- || true)
    p=${p//\"/}
    p=${p// /}
  fi
  [[ $p =~ ^[0-9]+$ ]] || p=9443
  printf '%s' "$p"
}

public_ip() {
  ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}'
}

caddy_names() {
  docker ps -a --format '{{.Names}}' 2>/dev/null | grep -i caddy || true
}

caddy_is_selfsteal() {
  [[ -f $STEAL_DIR/Caddyfile ]] && grep -qE 'SELF_STEAL_DOMAIN|SELF_STEAL_PORT' "$STEAL_DIR/Caddyfile"
}

caddy_is_cloudflare() {
  [[ -f $STEAL_DIR/.env ]] && grep -q '^CF_XHTTP=1$' "$STEAL_DIR/.env"
}

# 0 = по голому IP дырка (204 или внутренний сертификат)
ip_vuln() {
  local ip port http80 http iperr issuer cfg=0
  STEAL_VULN_WHY=""
  ip=$(public_ip)
  port=$(steal_port_guess)
  [[ -n $ip ]] || ip=127.0.0.1
  if [[ -f $STEAL_DIR/Caddyfile ]] && grep -qE 'respond[[:space:]]+204|tls[[:space:]]+internal' "$STEAL_DIR/Caddyfile"; then
    cfg=1
    STEAL_VULN_WHY="в Caddyfile есть respond 204 или tls internal"
  fi
  http80=$(curl -s -o /dev/null -w '%{http_code}' --max-time 4 "http://127.0.0.1/" 2>/dev/null || true)
  http80=${http80:-000}
  http=$(curl --haproxy-protocol -sk --max-time 6 \
    --resolve "${ip}:${port}:127.0.0.1" \
    -o /dev/null -w '%{http_code}' \
    "https://${ip}:${port}/" 2>/dev/null || true)
  http=${http:-000}
  issuer=$(curl -vk --haproxy-protocol --max-time 6 \
    --resolve "${ip}:${port}:127.0.0.1" \
    -o /dev/null \
    "https://${ip}:${port}/" 2>&1 | awk -F'issuer:' '/issuer:/ {gsub(/^[[:space:]]+/, "", $2); print $2; exit}' || true)
  if [[ $http80 == 204 ]]; then
    STEAL_VULN_WHY="порт 80 на IP отвечает 204"
    return 0
  fi
  if [[ $http == 204 ]]; then
    STEAL_VULN_WHY="порт ${port} на IP отвечает 204"
    return 0
  fi
  if printf '%s' "$issuer" | grep -qiE 'caddy|localhost|internal'; then
    STEAL_VULN_WHY="на IP внутренний сертификат: ${issuer}"
    return 0
  fi
  if [[ $cfg == 1 ]]; then
    return 0
  fi
  return 1
}

refresh_caddy_check() {
  local names
  CADDY_KIND=none
  CADDY_NOTE=""
  STEAL_VULN=0
  STEAL_VULN_WHY=""
  names=$(caddy_names | paste -sd, - || true)
  if caddy_is_cloudflare; then
    CADDY_KIND=cloudflare
    CADDY_NOTE=${names:-caddy-remnawave}
    return 0
  fi
  if caddy_is_selfsteal || steal_up; then
    CADDY_KIND=selfsteal
    CADDY_NOTE=${names:-caddy-remnawave}
    if ip_vuln; then
      STEAL_VULN=1
    fi
    return 0
  fi
  if [[ -n $names ]]; then
    CADDY_KIND=other
    CADDY_NOTE=$names
  fi
}

fix_selfsteal_vuln() {
  header
  echo -e "${B}исправить уязвимость selfsteal${N}"
  echo
  refresh_caddy_check
  if [[ $CADDY_KIND == cloudflare ]]; then
    echo -e "${Y}сейчас cloudflare xhttp. этот пункт вернёт старый caddy и снимет проксирование${N}"
    pause
    return
  fi
  if [[ $CADDY_KIND != selfsteal ]]; then
    echo -e "${Y}selfsteal caddy не найден${N}"
    pause
    return
  fi
  if [[ $STEAL_VULN != 1 ]]; then
    echo -e "${G}по IP уже отдаётся сайт, чинить нечего${N}"
    pause
    return
  fi
  echo -e "${R}${STEAL_VULN_WHY}${N}"
  echo

  local domain sport
  domain=$(steal_domain_guess)
  sport=$(steal_port_guess)
  if [[ -z $domain ]]; then
    domain=$(ask "домен selfsteal")
    domain=${domain#https://}
    domain=${domain#http://}
    domain=${domain%%/*}
  fi
  if [[ -z $domain ]]; then
    echo -e "${R}без домена не починить${N}"
    pause
    return
  fi

  if [[ -f $STEAL_DIR/Caddyfile ]]; then
    cp -f "$STEAL_DIR/Caddyfile" "$STEAL_DIR/Caddyfile.bak.vuln"
    echo -e "${D}бэкап: $STEAL_DIR/Caddyfile.bak.vuln${N}"
  fi
  write_steal_files "$domain" "$sport"
  if steal_up || [[ -f $STEAL_DIR/docker-compose.yml ]]; then
    (cd "$STEAL_DIR" && docker compose up -d) || docker restart caddy-remnawave >/dev/null || true
  fi
  sleep 2
  attach_real_cert "$domain" "$sport" || true
  sleep 1

  echo
  if ip_vuln; then
    echo -e "${R}после фикса дырка осталась: ${STEAL_VULN_WHY}${N}"
  else
    echo -e "${G}проверено ещё раз: по IP отдаётся сайт, 204 нет${N}"
    STEAL_VULN=0
  fi
  pause
}

cpu_n() { nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo; }

ram_info() {
  local t u
  t=$(awk '/MemTotal/ {printf "%.1f", $2/1024/1024}' /proc/meminfo)
  u=$(awk '/MemAvailable/ {printf "%.1f", ($2)/1024/1024}' /proc/meminfo)
  echo "${t}G total / ${u}G free"
}

st_badge() {
  if $1; then echo -e "${G}online${N}"; else echo -e "${R}offline${N}"; fi
}

header() {
  clear
  echo -e "${C}╔══════════════════════════════════════════╗${N}"
  echo -e "${C}║${N}  ${B}Remnawave · Node + SelfSteal${N}           ${C}║${N}"
  echo -e "${C}║${N}  ${D}FreezeDev  github.com/FDGRPNekko${N}       ${C}║${N}"
  echo -e "${C}╚══════════════════════════════════════════╝${N}"
  echo
  echo -e "  cpu:  ${B}$(cpu_n)${N} ядер"
  echo -e "  ram:  ${B}$(ram_info)${N}"
  echo -e "  node: $(st_badge node_up)   selfsteal: $(st_badge steal_up)   hy2: $(st_badge hy2_ready)"
  echo -e "  connector: $(st_badge connector_up)   ${D}frz-tool${N}"
  case $CADDY_KIND in
    cloudflare)
      echo -e "  caddy: ${B}cloudflare xhttp${N}  ${CADDY_NOTE}"
      ;;
    selfsteal)
      if [[ $STEAL_VULN == 1 ]]; then
        echo -e "  caddy: ${B}selfsteal${N}  ${CADDY_NOTE}  ${R}по IP уязвим${N}"
      else
        echo -e "  caddy: ${B}selfsteal${N}  ${CADDY_NOTE}  ${G}по IP чисто${N}"
      fi
      ;;
    other)
      echo -e "  caddy: ${Y}${CADDY_NOTE}${N}  ${D}не selfsteal${N}"
      ;;
    none)
      echo -e "  caddy: ${D}нет${N}"
      ;;
  esac
  if stub_old; then
    echo -e "  заглушка: ${R}старая${N}  ${D}${HTML_DIR}${N}"
  elif stub_new; then
    echo -e "  заглушка: ${G}convert-test${N}  ${D}${HTML_DIR}${N}"
  elif [[ -f $HTML_DIR/index.html ]]; then
    echo -e "  заглушка: ${Y}своя${N}  ${D}${HTML_DIR}${N}"
  else
    echo -e "  заглушка: ${D}нет${N}"
  fi
  echo
}

# --- node ---

write_node_compose() {
  local port=$1 key=$2
  mkdir -p "$NODE_DIR"
  # multiline ключ (сертификат) → yaml literal, однострочный — в кавычках
  if printf '%s' "$key" | grep -q $'\n'; then
    {
      echo "services:"
      echo "  remnanode:"
      echo "    container_name: remnanode"
      echo "    hostname: remnanode"
      echo "    image: remnawave/node:latest"
      echo "    restart: always"
      echo "    network_mode: host"
      echo "    environment:"
      echo "      NODE_PORT: \"${port}\""
      echo "      SECRET_KEY: |"
      printf '%s\n' "$key" | sed 's/^/        /'
    } >"$NODE_DIR/docker-compose.yml"
  else
    local esc=${key//\\/\\\\}
    esc=${esc//\"/\\\"}
    cat >"$NODE_DIR/docker-compose.yml" <<EOF
services:
  remnanode:
    container_name: remnanode
    hostname: remnanode
    image: remnawave/node:latest
    restart: always
    network_mode: host
    environment:
      - NODE_PORT=${port}
      - SECRET_KEY="${esc}"
EOF
  fi
}

paste_compose() {
  local dest=$1
  echo
  echo -e "${Y}вставь docker-compose.yml целиком, потом Ctrl+D${N}"
  echo "----------------------------------------"
  mkdir -p "$(dirname "$dest")"
  if ! cat >"$dest"; then
    echo -e "${R}не записалось${N}"
    return 1
  fi
  if [[ ! -s $dest ]]; then
    echo -e "${R}пусто, отмена${N}"
    rm -f "$dest"
    return 1
  fi
  echo "----------------------------------------"
  echo -e "${G}записал $dest${N}"
}

read_secret() {
  echo
  echo -e "${D}вставь SECRET_KEY с панели, потом Ctrl+D${N}"
  echo "----------------------------------------"
  local key
  key=$(cat)
  echo "----------------------------------------"
  key=$(printf '%s' "$key" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  printf '%s' "$key"
}

start_node() {
  cd "$NODE_DIR"
  docker compose pull
  docker compose up -d
  sleep 2
  if node_up; then
    echo
    echo -e "${G}нода поднялась${N}"
    docker compose ps
  else
    echo -e "${Y}контейнер не в online, логи:${N}"
    docker compose logs --tail=40 || true
  fi
}

install_node() {
  header
  echo -e "${B}установка ноды${N}"
  echo
  ensure_docker

  if node_installed && ! yn "нода уже есть, переустановить?" n; then
    return
  fi

  local port
  port=$(ask "порт ноды (NODE_PORT)" "2222")
  if ! [[ $port =~ ^[0-9]+$ ]] || ((port < 1 || port > 65535)); then
    echo -e "${R}кривой порт${N}"
    pause
    return
  fi

  echo
  echo "как кинуть конфиг:"
  echo "  1) секретный ключ с панели"
  echo "  2) целиком docker-compose из Remnawave"
  local m
  m=$(ask "выбор" "1")

  case $m in
    2)
      paste_compose "$NODE_DIR/docker-compose.yml" || { pause; return; }
      # если в compose другой порт — подкрутим под то что ввели
      if grep -q 'NODE_PORT=' "$NODE_DIR/docker-compose.yml"; then
        sed -i -E "s/NODE_PORT=[0-9]+/NODE_PORT=${port}/" "$NODE_DIR/docker-compose.yml"
      fi
      ;;
    *)
      local key
      key=$(read_secret)
      if [[ -z $key ]]; then
        echo -e "${R}без ключа никак${N}"
        pause
        return
      fi
      write_node_compose "$port" "$key"
      ;;
  esac

  echo
  start_node
  echo
  echo -e "порт: ${B}${port}${N}  ·  dir: ${B}${NODE_DIR}${N}"
  echo -e "${D}в фаерволе NODE_PORT лучше открыть только под IP панели${N}"
  maybe_pause
}

drop_hy2_cron() {
  if crontab -l 2>/dev/null | grep -qF "$CRON_TAG"; then
    crontab -l 2>/dev/null | grep -vF "$CRON_TAG" | grep -vF "$SYNC_BIN" | crontab - || true
  fi
}

nuke_node() {
  header
  echo -e "${B}снос ноды${N}"
  if ! node_installed; then
    echo "нечего сносить"
    pause
    return
  fi
  yn "точно снести remnanode?" n || { pause; return; }
  drop_hy2_cron
  if [[ -f $NODE_DIR/docker-compose.yml ]]; then
    (cd "$NODE_DIR" && docker compose down --rmi local 2>/dev/null) || true
  fi
  docker rm -f remnanode 2>/dev/null || true
  rm -rf "$NODE_DIR"
  echo -e "${G}ноды больше нет${N}"
  pause
}

# --- selfsteal ---

write_steal_files() {
  local domain=$1 sport=$2 cert=${3:-} key=${4:-}
  mkdir -p "$STEAL_DIR/logs"

  cat >"$STEAL_DIR/.env" <<EOF
SELF_STEAL_DOMAIN=${domain}
SELF_STEAL_PORT=${sport}
SELF_STEAL_ROOT=/var/www/html
EOF

  cat >"$STEAL_DIR/Caddyfile" <<'EOF'
{
    https_port {$SELF_STEAL_PORT}
    default_bind 127.0.0.1
    default_sni {$SELF_STEAL_DOMAIN}
    fallback_sni {$SELF_STEAL_DOMAIN}
    servers {
        listener_wrappers {
            proxy_protocol {
                allow 127.0.0.1/32
            }
            tls
        }
    }
    auto_https disable_redirects
}

:80 {
    bind 0.0.0.0
    redir https://{host}{uri} permanent
}

https://{$SELF_STEAL_DOMAIN} {
    encode gzip
    root * {$SELF_STEAL_ROOT}
    file_server
}
EOF

  if [[ -n ${cert:-} && -n ${key:-} ]]; then
    cat >>"$STEAL_DIR/Caddyfile" <<EOF

:{\$SELF_STEAL_PORT} {
    tls ${cert} ${key}
    encode gzip
    root * {\$SELF_STEAL_ROOT}
    file_server
}
EOF
  fi

  cat >"$STEAL_DIR/docker-compose.yml" <<EOF
services:
  caddy:
    image: caddy:latest
    container_name: caddy-remnawave
    restart: unless-stopped
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ${HTML_DIR}:/var/www/html
      - ./logs:/var/log/caddy
      - caddy_data_selfsteal:/data
      - caddy_config_selfsteal:/config
    env_file:
      - .env
    network_mode: "host"

volumes:
  caddy_data_selfsteal:
  caddy_config_selfsteal:
EOF
}

stub_old() {
  local f=$HTML_DIR/index.html sz
  [[ -f $f ]] || return 1
  [[ -f $HTML_DIR/.frz-stub ]] && return 1
  [[ -f $HTML_DIR/css/style.css && -f $HTML_DIR/js/main.js ]] && return 1
  if grep -qE 'It works|Server is up|<title>Selfsteal</title>' "$f"; then
    return 0
  fi
  sz=$(wc -c <"$f" 2>/dev/null || echo 0)
  if (( sz < 900 )) && grep -q 'Welcome' "$f"; then
    return 0
  fi
  return 1
}

stub_new() {
  [[ -f $HTML_DIR/index.html && -f $HTML_DIR/css/style.css && -f $HTML_DIR/js/main.js ]]
}

make_stub() {
  local tmp src
  command -v tar >/dev/null 2>&1 || apt-get install -y -qq tar >/dev/null
  tmp=$(mktemp -d /tmp/frz-stub.XXXXXX)
  echo -e "${Y}качаю заглушку convert-test...${N}"
  if ! fetch_file "$STUB_URL" "$tmp/site.tar.gz"; then
    echo -e "${R}не скачал заглушку${N}"
    rm -rf "$tmp"
    return 1
  fi
  if ! tar -xzf "$tmp/site.tar.gz" -C "$tmp"; then
    echo -e "${R}архив битый${N}"
    rm -rf "$tmp"
    return 1
  fi
  src=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -1)
  if [[ -z $src || ! -f $src/index.html ]]; then
    echo -e "${R}в архиве нет index.html${N}"
    rm -rf "$tmp"
    return 1
  fi
  mkdir -p "$HTML_DIR"
  find "$HTML_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  cp -a "$src"/. "$HTML_DIR"/
  printf '%s\n' 'convert-test' >"$HTML_DIR/.frz-stub"
  rm -rf "$tmp"
  echo -e "${G}заглушка convert-test → ${HTML_DIR}${N}"
}

fix_stub() {
  header
  echo -e "${B}заглушка${N}"
  echo
  if stub_old; then
    echo -e "${R}стоит старая заглушка (It works)${N}"
  elif stub_new; then
    echo -e "${G}уже convert-test${N}"
    yn "скачать заново?" n || { pause; return; }
  elif [[ -f $HTML_DIR/index.html ]]; then
    echo -e "${Y}в ${HTML_DIR} свой сайт, это не старая заглушка${N}"
    yn "всё равно заменить на convert-test?" n || { pause; return; }
  else
    echo "заглушки нет, ставлю convert-test"
  fi
  make_stub || true
  pause
}

attach_real_cert() {
  local domain=$1 sport=$2
  local vol crt rel ccrt ckey
  vol=$(docker volume inspect caddy_data_selfsteal -f '{{.Mountpoint}}' 2>/dev/null || true)
  if [[ -z $vol || ! -d $vol ]]; then
    echo -e "${Y}том сертификата не найден, голый IP пока без отдельного блока${N}"
    return 0
  fi
  crt=$(find "$vol/caddy/certificates" -type f -name "${domain}.crt" 2>/dev/null | head -1 || true)
  if [[ -z $crt || ! -f ${crt%.crt}.key ]]; then
    echo -e "${Y}файл сертификата не нашёл${N}"
    return 0
  fi
  rel=${crt#"$vol/"}
  ccrt="/data/${rel}"
  ckey="/data/${rel%.crt}.key"
  write_steal_files "$domain" "$sport" "$ccrt" "$ckey"
  docker restart caddy-remnawave >/dev/null
  echo -e "${G}голый IP отдаёт тот же сайт и публичный сертификат ${domain}${N}"
}

wait_cert() {
  local domain=$1
  echo
  echo -e "${Y}жду сертификат для ${domain}...${N}"
  echo -e "${D}dns A → этот сервер, порт 80 снаружи должен быть живой${N}"
  echo

  local i=0 max=90 hit=0 logs
  while ((i < max)); do
    logs=$(docker logs caddy-remnawave 2>&1 || true)
    if echo "$logs" | grep -qiE 'certificate obtained successfully|successfully obtained certificate|obtained certificate'; then
      hit=1
      break
    fi
    # caddy 2 иногда так
    if echo "$logs" | grep -F "$domain" | grep -qiE 'serving|tls|certificate' \
      && ! echo "$logs" | grep -qiE 'error obtaining|challenge failed|timeout'; then
      if echo "$logs" | grep -qi 'certificate'; then
        hit=1
        break
      fi
    fi
    printf "\r  ждём... %ss   " "$((i * 2))"
    sleep 2
    i=$((i + 1))
  done
  echo

  if ((hit)); then
    echo -e "${G}сертификат успешно получен${N}"
    return 0
  fi

  echo -e "${Y}за $((max * 2))с в логах не поймал успех${N}"
  echo "хвост логов:"
  docker logs --tail=30 caddy-remnawave 2>&1 || true
  yn "пойти в меню всё равно?" y
}

listeners_on() {
  local port=$1
  command -v ss >/dev/null 2>&1 || return 0
  ss -ltnp "sport = :${port}" 2>/dev/null | awk 'NR>1 && $0 !~ /^[[:space:]]*$/ {print}'
}

write_cf_files() {
  local domain=$1 xpath=$2 xport=$3
  mkdir -p "$STEAL_DIR/logs"

  cat >"$STEAL_DIR/.env" <<EOF
SELF_STEAL_DOMAIN=${domain}
SELF_STEAL_PORT=9443
SELF_STEAL_ROOT=/var/www/html
CF_XHTTP=1
CF_XHTTP_PATH=${xpath}
CF_XHTTP_PORT=${xport}
EOF

  cat >"$STEAL_DIR/Caddyfile" <<'EOF'
# cloudflare-xhttp
{
    servers {
        protocols h1 h2
    }
}

{$SELF_STEAL_DOMAIN} {
    tls {
        issuer acme {
            disable_tlsalpn_challenge
        }
    }

    @xhttp path {$CF_XHTTP_PATH}*
    handle @xhttp {
        header Cache-Control "no-store"
        reverse_proxy 127.0.0.1:{$CF_XHTTP_PORT} {
            flush_interval -1
        }
    }

    handle {
        encode gzip
        root * {$SELF_STEAL_ROOT}
        file_server
    }
}
EOF

  cat >"$STEAL_DIR/docker-compose.yml" <<EOF
services:
  caddy:
    image: caddy:latest
    container_name: caddy-remnawave
    restart: unless-stopped
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ${HTML_DIR}:/var/www/html
      - ./logs:/var/log/caddy
      - caddy_data_selfsteal:/data
      - caddy_config_selfsteal:/config
    env_file:
      - .env
    network_mode: "host"

volumes:
  caddy_data_selfsteal:
  caddy_config_selfsteal:
EOF
}

apply_cf_firewall() {
  local v4 v6
  command -v nft >/dev/null 2>&1 || { echo -e "${R}нет nft${N}"; return 1; }
  command -v curl >/dev/null 2>&1 || { echo -e "${R}нет curl${N}"; return 1; }
  v4=$(curl -fsSL --max-time 20 https://www.cloudflare.com/ips-v4) || return 1
  v6=$(curl -fsSL --max-time 20 https://www.cloudflare.com/ips-v6) || return 1
  printf '%s\n' "$v4" >"$STEAL_DIR/cf-ips-v4.txt"
  printf '%s\n' "$v6" >"$STEAL_DIR/cf-ips-v6.txt"

  cat >"$STEAL_DIR/cf-allow.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
nft delete table inet cf_web 2>/dev/null || true
nft add table inet cf_web
nft 'add chain inet cf_web input { type filter hook input priority -10; policy accept; }'
nft 'add set inet cf_web v4 { type ipv4_addr; flags interval; }'
nft 'add set inet cf_web v6 { type ipv6_addr; flags interval; }'
while read -r c; do
  [[ -z ${c:-} || $c =~ ^# ]] && continue
  nft add element inet cf_web v4 "{ $c }"
done < /opt/selfsteal/cf-ips-v4.txt
while read -r c; do
  [[ -z ${c:-} || $c =~ ^# ]] && continue
  nft add element inet cf_web v6 "{ $c }"
done < /opt/selfsteal/cf-ips-v6.txt
nft add rule inet cf_web input iif lo accept
nft 'add rule inet cf_web input tcp dport { 80, 443 } ip saddr @v4 accept'
nft 'add rule inet cf_web input tcp dport { 80, 443 } ip6 saddr @v6 accept'
nft 'add rule inet cf_web input tcp dport { 80, 443 } drop'
EOF
  chmod 755 "$STEAL_DIR/cf-allow.sh"
  bash "$STEAL_DIR/cf-allow.sh"

  local cur line
  line="@reboot /opt/selfsteal/cf-allow.sh # cf-web-allow"
  cur=$(crontab -l 2>/dev/null || true)
  cur=$(grep -vF '# cf-web-allow' <<<"$cur" || true)
  printf '%s\n%s\n' "$cur" "$line" | sed '/^$/d' | crontab -
  echo -e "${G}80 и 443 снаружи принимают только сети Cloudflare, ssh не трогал${N}"
}

print_cf_panel() {
  local domain=$1 xpath=$2 xport=$3
  echo
  echo -e "${B}панель Remnawave, inbound${N}"
  echo -e "  protocol   ${B}vless${N}"
  echo -e "  listen     ${B}127.0.0.1${N}"
  echo -e "  port       ${B}${xport}${N}"
  echo -e "  network    ${B}xhttp${N}"
  echo -e "  security   ${B}none${N}"
  echo -e "  path       ${B}${xpath}${N}"
  echo -e "  mode       ${B}packet-up${N}"
  echo -e "  host       ${B}${domain}${N}"
  echo -e "  flow       пусто"
  echo -e "  noSSEHeader        ${B}true${N}"
  echo -e "  scMaxEachPostBytes ${B}500000${N}"
  echo
  echo -e "${B}клиент${N}"
  echo -e "  address ${B}${domain}${N}   port ${B}443${N}"
  echo -e "  security ${B}tls${N}   sni ${B}${domain}${N}   fp chrome"
  echo -e "  alpn пусто"
  echo -e "  network xhttp   path ${B}${xpath}${N}   mode ${B}packet-up${N}"
  echo -e "  host ${B}${domain}${N}   flow пусто"
  echo
  echo -e "${B}Cloudflare${N}"
  echo "  DNS A на этот сервер, облако оранжевое"
  echo "  SSL/TLS: Full (strict)"
  echo "  Network: WebSockets и gRPC включены"
  echo "  Cache Rule: Bypass cache для пути ${xpath}"
  echo "  если не коннектится — WAF/Bot Fight не должен резать этот путь"
}

install_cloudflare() {
  header
  echo -e "${B}Cloudflare, оранжевое облако${N}"
  echo -e "${D}клиент ходит на IP Cloudflare. на ноде VLESS + xhttp, security none${N}"
  echo
  ensure_docker

  local domain xpath xport held
  domain=$(ask "домен" "$(steal_domain_guess)")
  domain=${domain#https://}
  domain=${domain#http://}
  domain=${domain%%/*}
  if [[ -z $domain || $domain == *[!a-zA-Z0-9.-]* ]]; then
    echo -e "${R}кривой домен${N}"
    pause
    return
  fi

  xpath=$(ask "путь xhttp" "/files/$(openssl rand -hex 6)")
  if [[ $xpath != /* || $xpath == */ || $xpath == *' '* || $xpath == *'*'* ]]; then
    echo -e "${R}путь должен начинаться с / и без пробела, звёздочки и хвостового слэша${N}"
    pause
    return
  fi

  xport=$(ask "порт xray на localhost" "18080")
  if ! [[ $xport =~ ^[0-9]+$ ]] || ((xport < 1 || xport > 65535)); then
    echo -e "${R}кривой порт${N}"
    pause
    return
  fi

  print_cf_panel "$domain" "$xpath" "$xport"
  echo
  held=$(listeners_on 443 || true)
  if [[ -n $held ]] && ! grep -qi caddy <<<"$held"; then
    echo -e "${R}443 занят, Caddy не встанет:${N}"
    echo "$held"
    echo
    echo -e "${Y}сначала сохрани inbound в панели и перезапусти ноду, потом запусти этот пункт снова${N}"
    pause
    return
  fi
  if ! yn "inbound уже на 127.0.0.1:${xport}, продолжать?" y; then
    pause
    return
  fi

  mkdir -p "$HTML_DIR"
  if [[ ! -f $HTML_DIR/index.html ]]; then
    echo -e "${Y}${HTML_DIR} пустой — сайт по домену будет пустым${N}"
  fi
  if [[ -f $STEAL_DIR/Caddyfile ]]; then
    cp -f "$STEAL_DIR/Caddyfile" "$STEAL_DIR/Caddyfile.bak.cf"
    echo -e "${D}бэкап: $STEAL_DIR/Caddyfile.bak.cf${N}"
  fi

  write_cf_files "$domain" "$xpath" "$xport"
  (cd "$STEAL_DIR" && docker compose up -d)
  sleep 2
  if ! steal_up; then
    echo -e "${R}caddy не поднялся${N}"
    docker logs --tail=40 caddy-remnawave 2>&1 || true
    pause
    return
  fi
  echo -e "${G}caddy слушает 443, путь ${xpath} уходит на 127.0.0.1:${xport}${N}"
  wait_cert "$domain" || true

  echo
  if yn "закрыть 80 и 443 для всех, кроме сетей Cloudflare?" y; then
    apply_cf_firewall || echo -e "${Y}файрвол не применился, caddy уже запущен${N}"
  fi
  print_cf_panel "$domain" "$xpath" "$xport"
  pause
}

install_steal() {
  header
  echo -e "${B}установка SelfSteal${N}"
  echo
  ensure_docker

  if caddy_is_cloudflare; then
    echo -e "${Y}сейчас cloudflare xhttp. переустановка вернёт caddy для Reality и снимет проксирование${N}"
    yn "точно переустановить selfsteal?" n || return
  fi

  if steal_installed && ! yn "selfsteal уже стоит, переустановить?" n; then
    return
  fi

  local domain sport
  domain=$(ask "домен для selfsteal")
  if [[ -z $domain ]]; then
    echo -e "${R}домен обязателен${N}"
    pause
    return
  fi
  # прибьём схему если влепили
  domain=${domain#https://}
  domain=${domain#http://}
  domain=${domain%%/*}

  sport=$(ask "порт selfsteal (reality dest)" "9443")
  if ! [[ $sport =~ ^[0-9]+$ ]] || ((sport < 1 || sport > 65535)); then
    echo -e "${R}кривой порт${N}"
    pause
    return
  fi

  echo
  if yn "создать заглушку в ${HTML_DIR}?" y; then
    make_stub
  else
    mkdir -p "$HTML_DIR"
    if [[ ! -f $HTML_DIR/index.html ]]; then
      echo -e "${Y}${HTML_DIR} пустой — кинь туда свой сайт сам${N}"
    fi
  fi

  write_steal_files "$domain" "$sport"

  cd "$STEAL_DIR"
  docker compose pull
  docker compose up -d
  sleep 2

  if steal_up; then
    echo -e "${G}caddy-remnawave запущен${N}"
  else
    echo -e "${R}не поднялся, логи:${N}"
    docker compose logs --tail=40 || true
    pause
    return
  fi

  wait_cert "$domain" || true
  attach_real_cert "$domain" "$sport"

  echo
  echo -e "domain: ${B}${domain}${N}"
  echo -e "dest:   ${B}127.0.0.1:${sport}${N}  (realitySettings.dest, xver 1)"
  echo -e "sni:    ${B}${domain}${N}  (в realitySettings.serverNames)"
  echo -e "dir:    ${B}${STEAL_DIR}${N}"
  maybe_pause
}

nuke_steal() {
  header
  echo -e "${B}снос SelfSteal${N}"
  if ! steal_installed; then
    echo "нечего сносить"
    pause
    return
  fi
  yn "точно снести selfsteal (caddy)?" n || { pause; return; }
  if [[ -f $STEAL_DIR/docker-compose.yml ]]; then
    (cd "$STEAL_DIR" && docker compose down -v 2>/dev/null) || true
  fi
  docker rm -f caddy-remnawave 2>/dev/null || true
  rm -rf "$STEAL_DIR"
  if [[ -d $HTML_DIR ]] && yn "заодно снести ${HTML_DIR}?" n; then
    rm -rf "$HTML_DIR"
  fi
  echo -e "${G}selfsteal снесён${N}"
  pause
}

install_all() {
  CHAIN=1
  install_node
  if ! node_up && ! yn "нода не online — всё равно ставить selfsteal?" n; then
    CHAIN=0
    return
  fi
  install_steal
  echo
  echo -e "${B}проброс сертификатов caddy → xray${N}"
  setup_hy2_certs auto || true
  CHAIN=0
  pause
}

# --- hy2 certs ---

write_sync_script() {
  cat >"$SYNC_BIN" <<'EOS'
#!/bin/bash
set -euo pipefail

# Caddy (caddy-remnawave /data) → /opt/remnanode/xray-certs
# копирует только если crt/key реально поменялись

DOMAIN="${1:-${DOMAIN:-}}"
CONTAINER="${CADDY_CONTAINER:-caddy-remnawave}"
DST_DIR="${DST_DIR:-/opt/remnanode/xray-certs}"

if [ -z "$DOMAIN" ]; then
  echo "usage: $0 [домен]"
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "нужен docker"
  exit 1
fi

if ! docker inspect "$CONTAINER" >/dev/null 2>&1; then
  echo "нет контейнера $CONTAINER"
  docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}' | grep -i caddy || true
  exit 1
fi

STATUS="$(docker inspect -f '{{.State.Status}}' "$CONTAINER")"
RESTARTING="$(docker inspect -f '{{.State.Restarting}}' "$CONTAINER")"
HOST_DATA="$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Source}}{{end}}{{end}}' "$CONTAINER")"

echo "$(date -Is) контейнер=$CONTAINER status=$STATUS restarting=$RESTARTING"
echo "/data на хосте: ${HOST_DATA:-нет}"

if [ "$RESTARTING" = "true" ] || [ "$STATUS" != "running" ]; then
  echo "caddy не healthy — exec не трогаю, читаю том"
  docker logs --tail 20 "$CONTAINER" 2>&1 || true
fi

SRC_DIR=""
if [ -n "$HOST_DATA" ]; then
  if [ -d "$HOST_DATA/caddy/certificates" ]; then
    SRC_DIR="$(find "$HOST_DATA/caddy/certificates" -type d -name "$DOMAIN" 2>/dev/null | head -n 1)"
  fi
  if [ -z "$SRC_DIR" ]; then
    SRC_DIR="$(find "$HOST_DATA" -type d -name "$DOMAIN" 2>/dev/null | head -n 1)"
  fi
fi

if [ -z "$SRC_DIR" ]; then
  echo "Let’s Encrypt для $DOMAIN в томе нет"
  if [ -n "$HOST_DATA" ]; then
    find "$HOST_DATA" -name '*.crt' 2>/dev/null | head -n 20 || true
  fi
  exit 1
fi

CRT="$SRC_DIR/${DOMAIN}.crt"
KEY="$SRC_DIR/${DOMAIN}.key"
if [ ! -f "$CRT" ] || [ ! -f "$KEY" ]; then
  echo "нет файлов $CRT / $KEY"
  ls -la "$SRC_DIR" || true
  exit 1
fi

mkdir -p "$DST_DIR"

if [ -f "$DST_DIR/fullchain.pem" ] && [ -f "$DST_DIR/privkey.pem" ] \
  && cmp -s "$CRT" "$DST_DIR/fullchain.pem" \
  && cmp -s "$KEY" "$DST_DIR/privkey.pem"; then
  echo "$(date -Is) без изменений ($DOMAIN)"
  exit 0
fi

cp -f "$CRT" "$DST_DIR/fullchain.pem"
cp -f "$KEY" "$DST_DIR/privkey.pem"
chmod 644 "$DST_DIR/fullchain.pem"
chmod 600 "$DST_DIR/privkey.pem"

echo "$(date -Is) обновлено → $DST_DIR"
echo "from $SRC_DIR"
if command -v openssl >/dev/null 2>&1; then
  openssl x509 -in "$DST_DIR/fullchain.pem" -noout -subject -dates
fi
EOS
  chmod +x "$SYNC_BIN"
}

ensure_hy2_volumes() {
  local f=$NODE_DIR/docker-compose.yml
  mkdir -p "$CERTS_DIR" "$HTML_DIR"

  if [[ ! -f $f ]]; then
    echo -e "${R}нет $f — сначала поставь ноду${N}"
    return 1
  fi

  if grep -q 'xray-certs:/etc/xray/certs' "$f"; then
    echo -e "${G}volumes для hy2 уже в compose${N}"
    return 0
  fi

  cp -f "$f" "$f.bak.hy2"
  local tmp
  tmp=$(mktemp)

  if grep -qE '^[[:space:]]+volumes:' "$f"; then
    awk -v html="$HTML_DIR" '
      /^[[:space:]]+volumes:/ && !done {
        print
        print "      - /dev/shm:/dev/shm:rw"
        print "      - ./xray-certs:/etc/xray/certs:ro"
        print "      - " html ":/var/www/html:ro"
        done=1
        next
      }
      { print }
    ' "$f" >"$tmp"
  elif grep -qE '^[[:space:]]+network_mode:' "$f"; then
    awk -v html="$HTML_DIR" '
      /^[[:space:]]+network_mode:/ && !done {
        print
        print "    volumes:"
        print "      - /dev/shm:/dev/shm:rw"
        print "      - ./xray-certs:/etc/xray/certs:ro"
        print "      - " html ":/var/www/html:ro"
        done=1
        next
      }
      { print }
    ' "$f" >"$tmp"
  else
    awk -v html="$HTML_DIR" '
      /^[[:space:]]+restart:/ && !done {
        print
        print "    volumes:"
        print "      - /dev/shm:/dev/shm:rw"
        print "      - ./xray-certs:/etc/xray/certs:ro"
        print "      - " html ":/var/www/html:ro"
        done=1
        next
      }
      { print }
    ' "$f" >"$tmp"
  fi

  if ! grep -q 'xray-certs:/etc/xray/certs' "$tmp"; then
    rm -f "$tmp"
    echo -e "${R}не смог вписать volumes — правь compose руками${N}"
    echo "нужно:"
    echo "    volumes:"
    echo "      - /dev/shm:/dev/shm:rw"
    echo "      - ./xray-certs:/etc/xray/certs:ro"
    echo "      - $HTML_DIR:/var/www/html:ro"
    return 1
  fi

  mv "$tmp" "$f"
  echo -e "${G}volumes дописаны (бэкап: $f.bak.hy2)${N}"
}

install_hy2_cron() {
  local domain=$1
  local line="0 */12 * * * $SYNC_BIN $domain >>$SYNC_LOG 2>&1 $CRON_TAG"
  local cur
  cur=$(crontab -l 2>/dev/null || true)
  # вычищаем старые наши джобы
  cur=$(printf '%s\n' "$cur" | grep -vF "$CRON_TAG" | grep -vF "$SYNC_BIN" || true)
  {
    printf '%s\n' "$cur"
    echo "$line"
  } | sed '/^$/d' | crontab -
  echo -e "${G}cron: каждые 12ч → $SYNC_LOG${N}"
}

setup_hy2_certs() {
  local mode=${1:-ask}
  if [[ $mode != auto ]]; then
    header
  fi
  echo -e "${B}проброс сертов в xray${N}"
  echo -e "${D}caddy → $CERTS_DIR → remnanode (/etc/xray/certs)${N}"
  echo

  if ! node_installed; then
    echo -e "${R}сначала нода${N}"
    maybe_pause
    return
  fi
  if ! steal_installed; then
    echo -e "${R}сначала selfsteal (нужен caddy с сертификатом)${N}"
    maybe_pause
    return
  fi

  local guess domain
  guess=$(steal_domain_guess)
  if [[ $mode == auto ]]; then
    domain=$guess
  else
    domain=$(ask "домен сертификата (как в caddy)" "$guess")
  fi
  domain=${domain#https://}
  domain=${domain#http://}
  domain=${domain%%/*}
  if [[ -z $domain ]]; then
    echo -e "${R}домен обязателен${N}"
    maybe_pause
    return
  fi

  write_sync_script
  printf '%s\n' "$domain" >"$HY2_DOMAIN_FILE"

  if ! ensure_hy2_volumes; then
    maybe_pause
    return
  fi

  echo
  echo -e "${Y}первый экспорт...${N}"
  if ! "$SYNC_BIN" "$domain"; then
    echo
    echo -e "${R}не вытащил серт — дождись certificate obtained у caddy и жмакни пункт ещё раз${N}"
    maybe_pause
    return
  fi

  install_hy2_cron "$domain"

  echo
  echo -e "${Y}перезапуск ноды с новыми volumes...${N}"
  (cd "$NODE_DIR" && docker compose up -d) || true
  sleep 2

  echo
  echo -e "${G}готово${N}"
  echo -e "  серты:  ${B}$CERTS_DIR/fullchain.pem${N}"
  echo -e "          ${B}$CERTS_DIR/privkey.pem${N}"
  echo -e "  в ноде: ${B}/etc/xray/certs/${N}"
  echo -e "  sync:   ${B}$SYNC_BIN${N}"
  echo -e "  cron:   ${B}0 */12 * * *${N}"
  echo
  echo -e "${D}в xray/hy2 указывай:${N}"
  echo "  /etc/xray/certs/fullchain.pem"
  echo "  /etc/xray/certs/privkey.pem"
  maybe_pause
}

nuke_hy2_certs() {
  header
  echo -e "${B}убрать Hy2 sync${N}"
  if [[ ! -x $SYNC_BIN ]] && ! crontab -l 2>/dev/null | grep -qF "$CRON_TAG"; then
    echo "нечего убирать"
    pause
    return
  fi
  yn "снять cron и sync-скрипт? (файлы в xray-certs оставлю)" y || { pause; return; }
  drop_hy2_cron
  rm -f "$SYNC_BIN" "$HY2_DOMAIN_FILE"
  echo -e "${G}hy2 sync снят${N}"
  if [[ -d $CERTS_DIR ]] && yn "снести ещё $CERTS_DIR?" n; then
    rm -rf "$CERTS_DIR"
  fi
  pause
}

# --- в систему ---

script_dir() {
  local src
  src=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")
  dirname "$src"
}

embed_self() {
  local src here
  src=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")
  [[ -f $src ]] || return 0
  mkdir -p /usr/local/bin "$FRZ_LIB"
  if [[ $src != "$FRZ_BIN" ]]; then
    install -m 755 "$src" "$FRZ_BIN"
  fi
  here=$(dirname "$src")
  if [[ -f $here/node-connector.sh ]]; then
    install -m 755 "$here/node-connector.sh" "$FRZ_LIB/node-connector.sh"
  fi
}

# --- node-connector (только локальный файл) ---

resolve_node_connector() {
  local here cand
  here=$(script_dir)
  for cand in \
    "$FRZ_LIB/node-connector.sh" \
    "$here/node-connector.sh" \
    ./node-connector.sh
  do
    [[ -f $cand ]] || continue
    printf '%s' "$cand"
    return 0
  done
  return 1
}

run_node_connector() {
  header
  echo -e "${B}node-connector${N}"
  echo -e "${D}вход ↔ выход: проброс портов + мониторинг${N}"
  echo

  local src
  if src=$(resolve_node_connector); then
    bash "$src" || true
    return
  fi
  if [[ -x /usr/local/bin/node-connector ]]; then
    /usr/local/bin/node-connector || true
    return
  fi
  echo -e "${R}нет node-connector.sh рядом со скриптом${N}"
  echo -e "${D}ожидаю $FRZ_LIB/node-connector.sh${N}"
  pause
}

open_sshd() {
  local ed
  if [[ ! -f $SSHD_CFG ]]; then
    header
    echo -e "${R}нет $SSHD_CFG${N}"
    pause
    return
  fi
  if command -v nano >/dev/null 2>&1; then
    ed=nano
  elif command -v vim >/dev/null 2>&1; then
    ed=vim
  else
    ed=vi
  fi
  "$ed" "$SSHD_CFG" || true
  echo
  if yn "перечитать sshd?" n; then
    if sshd -t; then
      systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null \
        || service ssh reload 2>/dev/null || service sshd reload
      echo -e "${G}sshd перечитал конфиг${N}"
    else
      echo -e "${R}sshd -t не прошёл, reload не делал${N}"
    fi
    pause
  fi
}

install_reshala() {
  header
  echo -e "${B}Reshala${N}"
  echo
  local dir
  dir=$(mktemp -d /tmp/reshala.XXXXXX)
  echo -e "${Y}качаю установщик...${N}"
  if ! fetch_file "$RESHALA_URL" "$dir/install.sh"; then
    echo -e "${R}не скачалось${N}"
    rm -rf "$dir"
    pause
    return
  fi
  (cd "$dir" && bash install.sh) || true
  rm -rf "$dir"
  echo
  if command -v reshala >/dev/null 2>&1; then
    reshala || true
  else
    echo -e "${Y}команда reshala не в PATH — глянь вывод выше${N}"
    pause
  fi
}

# --- menu ---

menu() {
  while true; do
    refresh_caddy_check || true
    header
    echo "  1) поставить всё (нода + selfsteal + серты в xray)"
    echo "  2) только ноду"
    echo "  3) только selfsteal"
    echo " 14) cloudflare: трафик через оранжевое облако"
    echo "  4) пробросить серты caddy → xray"
    echo "  5) node-connector"
    echo "  6) sshd_config"
    echo "  7) установить reshala"
    if stub_old; then
      echo -e " 15) ${R}пофиксить заглушку${N}"
    else
      echo " 15) пофиксить заглушку"
    fi
    if [[ $CADDY_KIND == selfsteal && $STEAL_VULN == 1 ]]; then
      echo -e " 13) ${R}исправить уязвимость selfsteal${N}"
    fi
    echo
    if node_installed; then
      echo -e "  8) ${R}снести ноду${N}"
    else
      echo -e "  8) ${D}снести ноду (нет)${N}"
    fi
    if steal_installed; then
      echo -e "  9) ${R}снести selfsteal${N}"
    else
      echo -e "  9) ${D}снести selfsteal (нет)${N}"
    fi
    if hy2_ready || crontab -l 2>/dev/null | grep -qF "$CRON_TAG"; then
      echo -e " 10) ${R}убрать sync сертов${N}"
    else
      echo -e " 10) ${D}убрать sync сертов (нет)${N}"
    fi
    echo
    echo " 11) логи ноды"
    echo " 12) логи selfsteal / sync сертов"
    echo "  0) выход"
    echo
    local c
    c=$(ask "выбор" "1")
    case $c in
      1) install_all ;;
      2) install_node ;;
      3) install_steal ;;
      14) install_cloudflare ;;
      4) setup_hy2_certs ;;
      5) run_node_connector ;;
      6) open_sshd ;;
      7) install_reshala ;;
      15) fix_stub ;;
      13) fix_selfsteal_vuln ;;
      8) nuke_node ;;
      9) nuke_steal ;;
      10) nuke_hy2_certs ;;
      11)
        header
        if [[ -f $NODE_DIR/docker-compose.yml ]]; then
          (cd "$NODE_DIR" && docker compose logs --tail=80 -t) || true
        else
          echo "ноды нет"
        fi
        pause
        ;;
      12)
        header
        echo -e "${B}--- caddy ---${N}"
        if steal_up; then
          docker logs --tail=40 -t caddy-remnawave 2>&1 || true
        else
          echo "selfsteal не запущен"
        fi
        echo
        echo -e "${B}--- hy2 sync ($SYNC_LOG) ---${N}"
        if [[ -f $SYNC_LOG ]]; then
          tail -n 40 "$SYNC_LOG" || true
        else
          echo "лога ещё нет"
        fi
        pause
        ;;
      0|q|Q) echo; exit 0 ;;
      *) echo "нет такого"; sleep 1 ;;
    esac
  done
}

need_root
embed_self
menu
