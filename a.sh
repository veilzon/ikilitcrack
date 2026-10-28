#!/bin/bash
set -euo pipefail

SCRIPT_NAME="i-Kilit İzleyici"
VERSION="1.0"
INSTALL_DIR="/opt/ikilit-izleyici"
SCRIPT_PATH="$INSTALL_DIR/ikilit-izleyici.sh"
AUTOSTART_DIR="$HOME/.config/autostart"
AUTOSTART_FILE="$AUTOSTART_DIR/ikilit-izleyici.desktop"
SLEEP_DELAY=15
IKILIT_PATTERNS="ikilit|i-kilit|ikilitd"

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'; C='\033[0;36m'; N='\033[0m'; BO='\033[1m'

clear
cat << 'HEADER'
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║            İ-KİLİT İZLEYİCİ v1.0                        ║
║            Pardus X11 İçin                               ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
HEADER
echo ""

echo -e "${C}▶ Sudo yetkisi kontrol ediliyor...${N}"
if sudo -n true 2>/dev/null; then
    echo -e "${G}✓${N} Sudo yetkisi aktif"
else
    echo -e "${Y}!${N} Şifre gerekli..."
    sudo -v || { echo -e "${R}✗ Sudo yetkisi alınamadı!${N}"; exit 1; }
    echo -e "${G}✓${N} Sudo yetkisi alındı"
fi
echo ""

reboot_sistemi() {
    echo -e "${B}ℹ${N} Bilgisayar yeniden başlatılıyor..."
    sync
    sudo -v
    sudo systemctl reboot 2>/dev/null || \
    sudo shutdown -r now 2>/dev/null || \
    sudo reboot 2>/dev/null || \
    sudo /sbin/reboot 2>/dev/null || {
        echo -e "${R}✗ Yeniden başlatma başarısız!${N}"
        echo "  Manuel: sudo reboot"
        return 1
    }
}

kurulum_yap() {
    echo -e "${C}────────────────────────────────────────────────────────────────${N}"
    echo -e "${BO}▶ ADIM 1/3: Bağımlılık Kontrolü${N}"
    echo -e "${C}────────────────────────────────────────────────────────────────${N}"
    echo ""

    local eksik=()
    for p in zenity wmctrl xdotool procps x11-utils; do
        if dpkg -l "$p" 2>/dev/null | grep -q "^ii"; then
            echo -e "  ${G}✓${N} $p"
        else
            eksik+=("$p")
            echo -e "  ${R}✗${N} $p (eksik)"
        fi
    done

    if [ ${#eksik[@]} -gt 0 ]; then
        echo ""
        read -p "  Eksik paketler yüklensin mi? (E/h): " cevap
        if [[ ! "$cevap" =~ ^[Hh]$ ]]; then
            echo ""
            sudo apt-get update -qq
            sudo apt-get install -y "${eksik[@]}" 2>/dev/null || sudo apt install -y "${eksik[@]}" 2>/dev/null
            echo -e "  ${G}✓${N} Paketler yüklendi"
        fi
    fi

    echo ""
    echo -e "${C}────────────────────────────────────────────────────────────────${N}"
    echo -e "${BO}▶ ADIM 2/3: Kurulum${N}"
    echo -e "${C}────────────────────────────────────────────────────────────────${N}"
    echo ""

    sudo mkdir -p "$INSTALL_DIR"
    sudo cp "$(readlink -f "$0")" "$SCRIPT_PATH"
    sudo chmod +x "$SCRIPT_PATH"
    echo -e "  ${G}✓${N} Script: $SCRIPT_PATH"

    if [ -d "/usr/local/bin" ]; then
        sudo ln -sf "$SCRIPT_PATH" /usr/local/bin/ikilit-izleyici 2>/dev/null
        echo -e "  ${G}✓${N} Komut: ikilit-izleyici"
    fi

    echo ""
    echo -e "${C}────────────────────────────────────────────────────────────────${N}"
    echo -e "${BO}▶ ADIM 3/3: Otomatik Başlangıç${N}"
    echo -e "${C}────────────────────────────────────────────────────────────────${N}"
    echo ""
    echo "  Bilgisayar her açıldığında otomatik olarak i-Kilit'i izler."
    echo ""

    while true; do
        echo "  1) Evet, otomatik başlangıç ekle"
        echo "  2) Hayır, ekleme"
        echo ""
        read -p "  Seçiminiz (1/2): " secim

        case $secim in
            1)
                mkdir -p "$AUTOSTART_DIR"
                cat > "$AUTOSTART_FILE" << EOF
[Desktop Entry]
Type=Application
Name=i-Kilit İzleyici
Comment=i-Kilit izleme ve yönetim aracı
Exec=/bin/bash $SCRIPT_PATH
Icon=utilities-system-monitor
Terminal=false
X-GNOME-Autostart-enabled=true
Categories=System;Monitor;
EOF
                chmod 644 "$AUTOSTART_FILE"
                echo ""
                echo -e "  ${G}✓${N} Otomatik başlangıç eklendi"
                break
                ;;
            2)
                echo ""
                echo -e "  ${Y}!${N} Otomatik başlangıç eklenmedi"
                break
                ;;
            *)
                echo -e "  ${R}✗${N} Geçersiz seçim"
                ;;
        esac
    done

    sync
}

durum_kontrol() {
    local pids=$(pgrep -f "$IKILIT_PATTERNS" 2>/dev/null || true)
    [ -n "$pids" ] && echo "ÇALIŞIYOR (PID: $pids)" || echo "ÇALIŞMIYOR"
    [ -n "$pids" ]
}

ikiliti_oldur() {
    local pids=$(pgrep -f "$IKILIT_PATTERNS" 2>/dev/null || true)

    [ -z "$pids" ] && { zenity --info --title="i-Kilit İzleyici" --text="i-Kilit zaten çalışmıyor!" --no-wrap 2>/dev/null; return 1; }

    zenity --question --title="i-Kilit İzleyici" \
        --text="<b>i-Kilit</b> sonlandırılacak.\n\nPID: $pids\n\nDevam?" \
        --ok-label="Evet, Öldür" --cancel-label="İptal" 2>/dev/null || return 1

    echo "$pids" | xargs kill -9 2>/dev/null && \
        zenity --info --title="i-Kilit İzleyici" --text="i-Kilit sonlandırıldı!" --no-wrap 2>/dev/null || \
        zenity --error --title="i-Kilit İzleyici" --text="Sonlandırılamadı!" --no-wrap 2>/dev/null
}

pencere_yonetimi() {
    local wid="" say=0

    while [ -z "$wid" ] && [ $say -lt 20 ]; do
        sleep 0.5
        wid=$(xdotool search --name "i-Kilit İzleyici" 2>/dev/null | head -1 || true)
        [ -z "$wid" ] && wid=$(xdotool search --class "zenity" 2>/dev/null | head -1 || true)
        say=$((say + 1))
    done

    [ -z "$wid" ] && return

    wmctrl -i -r "$wid" -b add,above,sticky 2>/dev/null || true

    local sw=$(xdotool getdisplaygeometry 2>/dev/null | awk '{print $1}')
    local sh=$(xdotool getdisplaygeometry 2>/dev/null | awk '{print $2}')
    local px=$(( (sw - 450) / 2 )) py=$(( (sh - 280) / 2 ))
    [ $px -lt 0 ] && px=0; [ $py -lt 0 ] && py=0
    wmctrl -i -r "$wid" -e 0,$px,$py,450,280 2>/dev/null || true
    wmctrl -i -a "$wid" 2>/dev/null || true

    while xdotool search --name "i-Kilit İzleyici" 2>/dev/null | grep -q . || \
          xdotool search --class "zenity" 2>/dev/null | grep -q .; do
        wmctrl -i -r "$wid" -b add,above 2>/dev/null || true
        xdotool windowraise "$wid" 2>/dev/null || true
        sleep 1
    done
}

x11_bekle() {
    local say=0
    while [ $say -lt 60 ]; do
        wmctrl -m 2>/dev/null | grep -q "Name:" && return 0
        sleep 1
        say=$((say + 1))
    done
    return 1
}

ana_pencere() {
    while true; do
        durum_kontrol
        local durum=$?
        local ikon="❌"
        [ $durum -eq 0 ] && ikon="✅"

        local secim=$(zenity --list \
            --title="i-Kilit İzleyici" \
            --text="<span font_desc='Sans 12'><b>i-Kilit Durumu:</b> $ikon $(durum_kontrol)</span>" \
            --column="Eylem" --column="Açıklama" \
            "🔄 Yenile" "Durumu yenile" \
            "⚡ Öldür" "i-Kilit'i sonlandır" \
            --buttons-layout=horizontal \
            --ok-label="Seç" --cancel-label="Kapat" \
            --width=450 --height=280 2>&1) || break

        case "$secim" in
            *"Yenile"*) continue ;;
            *"Öldür"*) ikiliti_oldur ;;
            *) break ;;
        esac
    done
}

main() {
    [ "$(id -u)" -eq 0 ] && { echo -e "${R}✗ ROOT olarak çalıştırmayın!${N}"; exit 1; }

    if [ ! -f "$SCRIPT_PATH" ]; then
        echo -e "${Y}!${N} İlk çalıştırma - Kurulum yapılacak"
        echo ""
        read -p "  Devam etmek için ENTER'a basın... "
        kurulum_yap

        echo ""
        echo -e "${G}✓${N} Kurulum tamamlandı!"
        echo ""
        echo -e "${C}────────────────────────────────────────────────────────────────${N}"
        echo -e "${BO}▶ BİLGİSAYARI YENİDEN BAŞLATIN${N}"
        echo -e "${C}────────────────────────────────────────────────────────────────${N}"
        echo ""
        echo "  Uygulama bilgisayar açıldığında otomatik olarak başlayacak."
        echo "  (15 saniye sonra pencere açılacak)"
        echo ""
        read -p "  Bilgisayar yeniden başlatılsın mı? (E/h): " cevap
        echo ""

        if [[ "$cevap" =~ ^[Ee]$ ]]; then
            reboot_sistemi
        else
            echo -e "${Y}!${N} Yeniden başlatma iptal edildi."
            echo "  Yeniden başlatmak için: sudo reboot"
            echo "  Komutla çalıştırmak için: ikilit-izleyici"
            exit 0
        fi
    fi

    echo -e "${G}✓${N} Kurulum mevcut"
    echo ""
    echo -e "${B}ℹ${N} Pencere $SLEEP_DELAY saniye sonra açılacak..."
    x11_bekle || true
    sleep "$SLEEP_DELAY"

    pencere_yonetimi &
    local wm_pid=$!

    ana_pencere

    kill $wm_pid 2>/dev/null || true
    exit 0
}

trap 'exit 0' INT TERM
main "$@"
