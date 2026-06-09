#!/usr/bin/env bash

set -e

VERSION="1.3.0"
APP_DIR="$HOME/Applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
DESKTOP_DIR="$HOME/.local/share/applications"

print_logo() {
    cat << "EOF"
  _   _                 _ _           
 | | | | __ _ _ __   __| | | ___ _ __ 
 | |_| |/ _` | '_ \ / _` | |/ _ \ '__|
 |  _  | (_| | | | | (_| | |  __/ |   
 |_| |_|\__,_|_| |_|\__,_|_|\___|_|   
EOF
    echo "       AppImage Manager v$VERSION"
    echo ""
}

show_help() {
    print_logo
    echo "Usage: handler [OPTION] [FILE]"
    echo ""
    echo "Options:"
    echo "  -i, --install [FILE]  Install the specified AppImage directly"
    echo "  -u, --uninstall       Open the uninstallation menu"
    echo "  -h, --help            Show this help message"
    echo "  -v, --version         Show the application version"
    echo ""
    echo "Run without arguments to launch the interactive menu."
}

check_dependencies() {
    local has_fuse=0
    if [ -f "/usr/lib/libfuse.so.2" ] || [ -f "/lib/x86_64-linux-gnu/libfuse.so.2" ] || [ -f "/lib64/libfuse.so.2" ]; then
        has_fuse=1
    fi

    if [ "$has_fuse" -eq 0 ]; then
        echo "⚠️ Missing dependency: FUSE 2 is required to run AppImages."
        if [ -f "/etc/os-release" ]; then
            source /etc/os-release
            case "$ID" in
                arch|manjaro|cachyos|endeavouros|artix)
                    echo "💡 Run this command to install it: sudo pacman -S fuse2"
                    ;;
                ubuntu|debian|pop|linuxmint|neon|elementary)
                    echo "💡 Run this command to install it: sudo apt install libfuse2"
                    ;;
                fedora)
                    echo "💡 Run this command to install it: sudo dnf install fuse"
                    ;;
                opensuse*)
                    echo "💡 Run this command to install it: sudo zypper install libfuse2"
                    ;;
                *)
                    echo "💡 Please install the FUSE 2 library using your package manager."
                    ;;
            esac
        fi
        echo "⚠️ Execution fails without this library."
        echo ""
    fi
}

setup_directories() {
    if ! mkdir -p "$APP_DIR" "$ICON_DIR" "$DESKTOP_DIR"; then
        echo "🚨 Error: Failed to create necessary directories in $HOME."
        exit 1
    fi
}

scan_for_appimages() {
    shopt -s nullglob
    local appimages=(*.AppImage *.appimage)
    shopt -u nullglob

    if [ ${#appimages[@]} -eq 0 ]; then
        echo "🚨 Error: No AppImages detected in the current directory."
        exit 1
    fi

    echo "📦 Found AppImages:"
    local index=1
    for app in "${appimages[@]}"; do
        echo "  $index) $app"
        ((index++))
    done
    echo ""

    read -p "🎯 Select an AppImage by number: " selection

    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#appimages[@]} ]; then
        echo "🚨 Error: Invalid selection."
        exit 1
    fi

    target_appimage="${appimages[$((selection-1))]}"
    echo "✅ Selected: $target_appimage"
    echo ""
}

check_icon() {
    if [ -n "$1" ] && [ -f "$1" ]; then
        echo "$1"
        return 0
    fi
    return 1
}

find_best_icon() {
    local tmp_root="$1"
    local safe_name="$2"
    local ext_icon=""

    if [ -f "$tmp_root/.DirIcon" ]; then
        local target=$(readlink -f "$tmp_root/.DirIcon")
        check_icon "$target" && return
    fi

    local desktop_file=$(find "$tmp_root" -maxdepth 2 -name "*.desktop" | head -n 1)
    if [ -n "$desktop_file" ]; then
        local icon_name=$(grep -E "^Icon=" "$desktop_file" | cut -d'=' -f2 | tr -d '[:space:]')
        if [ -n "$icon_name" ]; then
            ext_icon=$(find "$tmp_root" -name "${icon_name}.png" -o -name "${icon_name}.svg" | head -n 1)
            check_icon "$ext_icon" && return
        fi
    fi

    ext_icon=$(find "$tmp_root" -iname "*${safe_name}*.png" -o -iname "*${safe_name}*.svg" | head -n 1)
    check_icon "$ext_icon" && return

    ext_icon=$(find "$tmp_root" -type f \( -name "*.png" -o -name "*.svg" \) -exec du -b {} + | sort -n -r | head -n 1 | cut -f2)
    check_icon "$ext_icon" && return

    echo ""
}

install_application() {
    local source_file="$1"

    if [ ! -f "$source_file" ]; then
        echo "🚨 Error: File '$source_file' does not exist."
        exit 1
    fi

    read -p "🏷️ Enter the application name: " app_name
    if [ -z "$app_name" ]; then
        echo "🚨 Error: Application name cannot be empty."
        exit 1
    fi

    read -p "📂 Enter the application category (e.g., Utility, Game, Development): " app_category
    if [ -z "$app_category" ]; then
        app_category="Utility"
        echo "⚠️ No category provided. Defaulting to 'Utility'."
    fi

    local safe_name=$(echo "$app_name" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
    local dest_file="$APP_DIR/$(basename "$source_file")"

    echo ""
    echo "⚙️ Making AppImage executable..."
    chmod +x "$source_file" || { echo "🚨 Error: Failed to change permissions on $source_file."; exit 1; }

    echo "🚚 Moving AppImage to $APP_DIR..."
    cp "$source_file" "$dest_file" || { echo "🚨 Error: Failed to copy file to $APP_DIR."; exit 1; }

    echo "🖼️ Extracting icon..."
    local temp_dir
    if ! temp_dir=$(mktemp -d); then
        echo "🚨 Error: Failed to create temporary directory."
        exit 1
    fi

    local orig_dir="$PWD"
    
    cp "$dest_file" "$temp_dir/"
    cd "$temp_dir" || exit 1

    local tmp_appimage="$(basename "$dest_file")"
    if ! ./"$tmp_appimage" --appimage-extract > /dev/null 2>&1; then
        echo "⚠️ Warning: Failed to extract AppImage. The icon falls back to system defaults."
    fi

    local icon_path=""
    local final_icon_name="application-x-executable"

    if [ -d "squashfs-root" ]; then
        icon_path=$(find_best_icon "squashfs-root" "$safe_name")
    fi

    if [ -n "$icon_path" ] && [ -f "$icon_path" ]; then
        local ext="${icon_path##*.}"
        final_icon_name="${safe_name}_icon"
        cp "$icon_path" "$ICON_DIR/$final_icon_name.$ext" || echo "⚠️ Warning: Failed to copy icon to $ICON_DIR."
        echo "✅ Icon extracted and saved."
    else
        echo "⚠️ No icon found inside the AppImage. Using system default icon."
    fi

    cd "$orig_dir" || exit 1
    rm -rf "$temp_dir"

    echo "📝 Creating desktop entry..."
    cat <<EOF > "$DESKTOP_DIR/$safe_name.desktop"
[Desktop Entry]
Name=$app_name
Exec="$dest_file"
Icon=$final_icon_name
Type=Application
Categories=$app_category;
Terminal=false
EOF

    echo "🔄 Updating desktop database..."
    if command -v update-desktop-database &> /dev/null; then
        update-desktop-database "$DESKTOP_DIR"
    else
        echo "⚠️ update-desktop-database not found. Restart your launcher to see changes."
    fi

    echo ""
    read -p "🗑️ Do you want to delete the original file ($source_file)? [y/N]: " delete_orig
    if [[ "$delete_orig" =~ ^[Yy]$ ]]; then
        rm -f "$source_file"
        echo "✅ Original file deleted."
    fi

    echo ""
    echo "🎉 Installation complete."
    echo "🚀 You can now launch $app_name from your application menu."
}

uninstall_application() {
    shopt -s nullglob
    local installed_apps=("$APP_DIR"/*.AppImage "$APP_DIR"/*.appimage)
    shopt -u nullglob

    if [ ${#installed_apps[@]} -eq 0 ]; then
        echo "🚨 Error: No installed AppImages found in $APP_DIR."
        exit 1
    fi

    echo "🗑️ Select an application to uninstall:"
    local index=1
    for app in "${installed_apps[@]}"; do
        echo "  $index) $(basename "$app")"
        ((index++))
    done
    echo ""

    read -p "🎯 Select by number: " selection

    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#installed_apps[@]} ]; then
        echo "🚨 Error: Invalid selection."
        exit 1
    fi

    local target_app="${installed_apps[$((selection-1))]}"
    
    local desktop_file=$(grep -l "$target_app" "$DESKTOP_DIR"/*.desktop 2>/dev/null | head -n 1)
    
    local icon_name=""
    if [ -n "$desktop_file" ]; then
        icon_name=$(grep "^Icon=" "$desktop_file" | cut -d'=' -f2 | tr -d '[:space:]')
        echo "🗑️ Removing desktop entry..."
        rm -f "$desktop_file"
    fi
    
    if [ -n "$icon_name" ] && [ "$icon_name" != "application-x-executable" ]; then
        echo "🗑️ Removing icon..."
        find "$ICON_DIR" -name "$icon_name.*" -delete
    fi

    echo "🗑️ Removing AppImage..."
    rm -f "$target_app"

    echo "🔄 Updating desktop database..."
    if command -v update-desktop-database &> /dev/null; then
        update-desktop-database "$DESKTOP_DIR"
    fi

    echo "✅ Uninstallation complete."
}

case "$1" in
    help|--help|-h)
        show_help
        exit 0
        ;;
    --version|-v)
        echo "Handler v$VERSION"
        exit 0
        ;;
    -i|--install)
        if [ -z "$2" ]; then
            echo "🚨 Error: Missing file path for install command."
            echo "Usage: handler -i [FILE]"
            exit 1
        fi
        check_dependencies
        setup_directories
        install_application "$2"
        exit 0
        ;;
    uninstall|-u|--uninstall)
        setup_directories
        uninstall_application
        exit 0
        ;;
    "")
        print_logo
        check_dependencies
        setup_directories
        echo "1) Install AppImage"
        echo "2) Uninstall AppImage"
        read -p "🎯 Select an action (1 or 2): " action
        echo ""

        if [ "$action" = "1" ]; then
            scan_for_appimages
            install_application "$target_appimage"
        elif [ "$action" = "2" ]; then
            uninstall_application
        else
            echo "🚨 Error: Invalid selection."
            exit 1
        fi
        ;;
    *)
        if [ -f "$1" ]; then
            check_dependencies
            setup_directories
            target_appimage="$1"
            echo "✅ Target provided: $target_appimage"
            install_application "$target_appimage"
        else
            echo "🚨 Error: Unknown option or file not found: $1"
            echo "Run 'handler --help' for usage information."
            exit 1
        fi
        ;;
esac
