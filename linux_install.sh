RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_ok()     { echo -e "  ${GREEN}[OK]${NC}     $*"; }
print_err()    { echo -e "  ${RED}[LOI]${NC}    $*"; }
print_warn()   { echo -e "  ${YELLOW}[WARN]${NC}   $*"; }
print_info()   { echo -e "  ${BLUE}[INFO]${NC}   $*"; }
print_skip()   { echo -e "  ${YELLOW}[SKIP]${NC}   $*"; }
print_step()   { echo -e "\n${BOLD}$*${NC}"; }
print_header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "  ================================================================"
    echo "    Lotus Fortress - Linux Installer"
    echo "    (c) FredCentre Software"
    echo "  ================================================================"
    echo -e "${NC}"
}

ask_yn() {
    local prompt="$1"
    local ans
    while true; do
        read -rp "  $prompt (Y/N): " ans
        case "$ans" in
            [Yy]) return 0 ;;
            [Nn]) return 1 ;;
            *) echo "  Vui long nhap Y hoac N." ;;
        esac
    done
}

check_mod_files() {
    print_step "[BUOC 1] Kiem tra file mod..."
    echo ""

    local missing=0
    local files=(
        "tf/resource/tf_english.txt"
        "hl2/resource/chat_english.txt"
        "hl2/resource/gameui_english.txt"
    )

    for f in "${files[@]}"; do
        if [[ -f "$SCRIPT_DIR/$f" ]]; then
            print_ok "Tim thay: $f"
        else
            print_err "Thieu file: $f"
            missing=1
        fi
    done

    if [[ $missing -eq 1 ]]; then
        echo ""
        print_err "Mot so file mod bi thieu. Vui long tai ve ban moi nhat tu GitHub cua Lotus Fortress."
        echo ""
        exit 1
    fi
}

TF2_SUBPATH="steamapps/common/Team Fortress 2"
STEAM_TYPE=""
TF2_PATH=""

_find_tf2_in_root() {
    local root="$1"
    [[ -d "$root" ]] || return 1

    if [[ -f "$root/$TF2_SUBPATH/tf_linux64" ]]; then
        echo "$root/$TF2_SUBPATH"
        return 0
    fi

    local vdf="$root/steamapps/libraryfolders.vdf"
    if [[ -f "$vdf" ]]; then
        local lib_path
        while IFS= read -r lib_path; do
            lib_path="${lib_path//\\\\/\\}"
            lib_path="${lib_path//\\/\/}"
            if [[ -f "$lib_path/$TF2_SUBPATH/tf_linux64" ]]; then
                echo "$lib_path/$TF2_SUBPATH"
                return 0
            fi
        done < <(grep -oP '"path"\s+"\K[^"]+' "$vdf" 2>/dev/null)
    fi

    return 1
}

detect_steam() {
    local found=""

    local native_roots=(
        "$HOME/.steam/steam"
        "$HOME/.local/share/Steam"
    )
    for root in "${native_roots[@]}"; do
        found=$(_find_tf2_in_root "$root") && {
            STEAM_TYPE="native (goi he thong)"
            TF2_PATH="$found"
            return 0
        }
    done

    local flatpak_base="$HOME/.var/app/com.valvesoftware.Steam"
    local flatpak_roots=(
        "$flatpak_base/.steam/steam"
        "$flatpak_base/.local/share/Steam"
    )
    for root in "${flatpak_roots[@]}"; do
        found=$(_find_tf2_in_root "$root") && {
            STEAM_TYPE="Flatpak"
            TF2_PATH="$found"
            return 0
        }
    done

    local snap_base="$HOME/snap/steam/common"
    local snap_roots=(
        "$snap_base/.steam/steam"
        "$snap_base/.local/share/Steam"
    )
    for root in "${snap_roots[@]}"; do
        found=$(_find_tf2_in_root "$root") && {
            STEAM_TYPE="Snap"
            TF2_PATH="$found"
            return 0
        }
    done

    return 1
}

find_tf2() {
    print_step "[BUOC 2] Tim kiem cai dat TF2..."
    echo ""
    echo "  Dang quet..."
    echo ""

    if detect_steam; then
        print_info "Steam   : $STEAM_TYPE"
        print_info "Duong dan TF2: $TF2_PATH"
        echo ""
        if ask_yn "Duong dan nay co chinh xac khong?"; then
            return 0
        fi
    else
        print_warn "Khong the tu dong tim thay TF2."
    fi

    echo ""
    echo "  Vui long nhap thu cong duong dan thu muc TF2:"
    echo "  (Vi du: /home/user/.steam/steam/steamapps/common/Team Fortress 2)"
    echo ""
    while true; do
        read -rp "  Duong dan: " TF2_PATH
        TF2_PATH="${TF2_PATH%/}"
        TF2_PATH="${TF2_PATH//\"/}"

        if [[ -f "$TF2_PATH/tf_linux64" ]]; then
            print_ok "Da xac nhan TF2 tai: $TF2_PATH"
            break
        else
            print_err "Khong tim thay tf_linux64 tai duong dan nay. Thu lai."
        fi
    done
}

confirm_install() {
    print_step "[BUOC 3] Xac nhan cai dat..."
    echo ""
    echo -e "  Nguon (mod) : ${BOLD}$SCRIPT_DIR${NC}"
    echo -e "  Dich (game) : ${BOLD}$TF2_PATH${NC}"
    echo ""

    if ! ask_yn "Tiep tuc cai dat?"; then
        echo ""
        echo "  Da huy cai dat."
        exit 0
    fi
}

request_sudo() {
    print_step "[BUOC 4] Yeu cau quyen sudo..."
    echo ""
    echo "  Quyen sudo can thiet de ghi file vao thu muc game."
    echo ""

    if ! sudo -v; then
        print_err "Xac thuc sudo that bai. Khong the tiep tuc."
        exit 1
    fi

    print_ok "Da xac thuc sudo thanh cong."
}

backup_files() {
    local BACKUP_DIR="$TF2_PATH/Lotus_Backup"
    print_step "[BUOC 5] Tao ban sao luu file goc..."
    echo ""

    sudo mkdir -p "$BACKUP_DIR/tf/resource"
    sudo mkdir -p "$BACKUP_DIR/hl2/resource"

    _backup_one() {
        local src="$1"
        local dst="$2"
        if [[ -f "$src" ]]; then
            if sudo cp -f "$src" "$dst" 2>/dev/null; then
                print_ok "Backup: $(basename "$src")"
            else
                print_warn "Khong the backup: $(basename "$src")"
            fi
        else
            print_skip "File goc khong ton tai: $(basename "$src") (se tao moi)"
        fi
    }

    _backup_one "$TF2_PATH/tf/resource/tf_english.txt"      "$BACKUP_DIR/tf/resource/tf_english.txt"
    _backup_one "$TF2_PATH/hl2/resource/chat_english.txt"    "$BACKUP_DIR/hl2/resource/chat_english.txt"
    _backup_one "$TF2_PATH/hl2/resource/gameui_english.txt"  "$BACKUP_DIR/hl2/resource/gameui_english.txt"
}

INSTALL_ERROR=0

install_files() {
    print_step "[BUOC 6] Cai dat file ban dich..."
    echo ""

    _install_one() {
        local src="$1"
        local dst="$2"
        local display="$3"
        if sudo cp -f "$src" "$dst" 2>/dev/null; then
            print_ok "Da cai dat: $display"
        else
            print_err "Khong the ghi  : $display"
            INSTALL_ERROR=1
        fi
    }

    _install_one \
        "$SCRIPT_DIR/tf/resource/tf_english.txt" \
        "$TF2_PATH/tf/resource/tf_english.txt" \
        "tf/resource/tf_english.txt"

    _install_one \
        "$SCRIPT_DIR/hl2/resource/chat_english.txt" \
        "$TF2_PATH/hl2/resource/chat_english.txt" \
        "hl2/resource/chat_english.txt"

    _install_one \
        "$SCRIPT_DIR/hl2/resource/gameui_english.txt" \
        "$TF2_PATH/hl2/resource/gameui_english.txt" \
        "hl2/resource/gameui_english.txt"
}

print_result() {
    echo ""
    if [[ $INSTALL_ERROR -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}"
        echo "  ================================================================"
        echo "    CAI DAT THANH CONG!"
        echo ""
        echo "    Ban sao luu file goc da duoc luu tai:"
        echo "    $TF2_PATH/Lotus_Backup"
        echo ""
        echo "    Vui long khoi dong lai TF2 de ap dung thay doi"
        echo "    Cam on ban da su dung Lotus Fortress."
        echo "  ================================================================"
        echo -e "${NC}"
    else
        echo -e "${RED}${BOLD}"
        echo "  ================================================================"
        echo "    CAI DAT CO LOI!"
        echo "    Mot so file chua duoc thay the."
        echo "    Hay kiem tra quyen ghi va thu lai."
        echo "  ================================================================"
        echo -e "${NC}"
        exit 1
    fi
}

print_header
check_mod_files
find_tf2
confirm_install
request_sudo
backup_files
install_files
print_result