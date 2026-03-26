#!/bin/bash
# ==============================================================
#  carpetas_compartidas.sh
#  Gestiona carpetas compartidas entre host y VM en VMware
#  Autor: aprendiendo-shell-script
#  Uso: sudo ./carpetas_compartidas.sh
# ==============================================================

# ---------- Colores ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Punto de montaje estándar de VMware hgfs
HGFS_MOUNT="/mnt/hgfs"

# ---------- Funciones de utilidad ----------

print_header() {
    clear
    echo -e "${CYAN}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║     CARPETAS COMPARTIDAS - VMWARE        ║"
    echo "  ║     github.com/inietoo/aprendiendo-      ║"
    echo "  ║           shell-script                   ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_ok()    { echo -e "  ${GREEN}[✔]${NC} $1"; }
print_error() { echo -e "  ${RED}[✘]${NC} $1"; }
print_info()  { echo -e "  ${BLUE}[i]${NC} $1"; }
print_warn()  { echo -e "  ${YELLOW}[!]${NC} $1"; }

pause() {
    echo ""
    read -rp "  Pulsa ENTER para continuar..." _
}

# ---------- Comprobaciones ----------

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Este script debe ejecutarse con sudo o como root."
        echo -e "  Uso: ${YELLOW}sudo $0${NC}"
        exit 1
    fi
}

check_open_vm_tools() {
    if ! dpkg -l open-vm-tools &>/dev/null 2>&1 || ! dpkg -l open-vm-tools | grep -q '^ii'; then
        print_error "open-vm-tools no está instalado."
        print_info "Ejecuta primero: sudo ./instalar_vmware_tools.sh"
        echo ""
        read -rp "  ¿Deseas instalar open-vm-tools ahora? [s/N]: " install_now
        if [[ "$install_now" =~ ^[sS]$ ]]; then
            apt-get update -qq && apt-get install -y open-vm-tools
            systemctl enable open-vm-tools && systemctl start open-vm-tools
            print_ok "open-vm-tools instalado."
        else
            print_warn "Saliendo. Instala open-vm-tools para continuar."
            exit 1
        fi
    else
        print_ok "open-vm-tools está instalado."
    fi
}

check_vmhgfs() {
    # Verifica que el módulo vmhgfs-fuse esté disponible
    if ! command -v vmhgfs-fuse &>/dev/null; then
        print_warn "vmhgfs-fuse no encontrado. Puede que open-vm-tools-desktop sea necesario."
        read -rp "  ¿Instalar open-vm-tools-desktop? [s/N]: " install_desktop
        if [[ "$install_desktop" =~ ^[sS]$ ]]; then
            apt-get install -y open-vm-tools-desktop -qq
            print_ok "open-vm-tools-desktop instalado."
        fi
    fi
}

# ---------- Opción 1: Montar carpetas compartidas ahora ----------

mount_shared_folders() {
    print_header
    echo -e "  ${WHITE}Montando carpetas compartidas...${NC}\n"

    # Crear el punto de montaje si no existe
    if [[ ! -d "$HGFS_MOUNT" ]]; then
        mkdir -p "$HGFS_MOUNT"
        print_ok "Directorio $HGFS_MOUNT creado."
    fi

    # Intentar montar con vmhgfs-fuse
    if command -v vmhgfs-fuse &>/dev/null; then
        print_info "Montando con vmhgfs-fuse..."
        vmhgfs-fuse .host:/ "$HGFS_MOUNT" -o subtype=vmhgfs-fuse,allow_other

        if [[ $? -eq 0 ]]; then
            print_ok "Carpetas compartidas montadas en ${CYAN}$HGFS_MOUNT${NC}"
            list_shared_folders
        else
            print_error "No se pudieron montar las carpetas."
            print_warn "Asegúrate de haber activado las carpetas compartidas en VMware:"
            echo "  VM → Settings → Options → Shared Folders → Always enabled"
        fi
    else
        # Fallback: mount con tipo vmhgfs
        print_info "Intentando montar con mount -t vmhgfs..."
        mount -t vmhgfs .host:/ "$HGFS_MOUNT" -o allow_other

        if [[ $? -eq 0 ]]; then
            print_ok "Carpetas compartidas montadas en ${CYAN}$HGFS_MOUNT${NC}"
            list_shared_folders
        else
            print_error "No se pudieron montar. Verifica la configuración en VMware."
        fi
    fi

    pause
}

# ---------- Opción 2: Montaje automático al inicio ----------

setup_automount() {
    print_header
    echo -e "  ${WHITE}Configurando montaje automático...${NC}\n"

    local FSTAB_ENTRY=".host:/    $HGFS_MOUNT    fuse.vmhgfs-fuse    defaults,allow_other,uid=1000,gid=1000    0    0"
    local FSTAB_FILE="/etc/fstab"

    # Verificar si ya existe la entrada
    if grep -q "vmhgfs" "$FSTAB_FILE"; then
        print_warn "Ya existe una entrada de vmhgfs en $FSTAB_FILE:"
        grep "vmhgfs" "$FSTAB_FILE"
        echo ""
        read -rp "  ¿Deseas reemplazarla? [s/N]: " replace
        if [[ ! "$replace" =~ ^[sS]$ ]]; then
            print_info "Operación cancelada. No se modificó /etc/fstab."
            pause
            return
        fi
        # Eliminar la entrada anterior
        sed -i '/vmhgfs/d' "$FSTAB_FILE"
        print_ok "Entrada anterior eliminada."
    fi

    # Crear el directorio de montaje si no existe
    mkdir -p "$HGFS_MOUNT"

    # Añadir al fstab
    echo "$FSTAB_ENTRY" >> "$FSTAB_FILE"
    print_ok "Entrada añadida a $FSTAB_FILE"

    # Opción adicional: systemd service como alternativa más moderna
    echo ""
    read -rp "  ¿Crear también un servicio systemd como respaldo? [s/N]: " create_service
    if [[ "$create_service" =~ ^[sS]$ ]]; then
        create_systemd_service
    fi

    echo ""
    print_ok "Las carpetas compartidas se montarán automáticamente en el próximo inicio."
    print_info "Puedes probarlo ahora con: mount -a"

    # Intentar montar inmediatamente
    read -rp "  ¿Montar ahora? [s/N]: " mount_now
    if [[ "$mount_now" =~ ^[sS]$ ]]; then
        mount -a 2>/dev/null && print_ok "Montado correctamente." || print_warn "No se pudo montar ahora, pero se hará en el reinicio."
    fi

    pause
}

create_systemd_service() {
    local SERVICE_FILE="/etc/systemd/system/vmhgfs-mount.service"

    cat > "$SERVICE_FILE" << 'EOF'
[Unit]
Description=Montar carpetas compartidas VMware (hgfs)
Requires=open-vm-tools.service
After=open-vm-tools.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/bin/mkdir -p /mnt/hgfs
ExecStart=/usr/bin/vmhgfs-fuse .host:/ /mnt/hgfs -o subtype=vmhgfs-fuse,allow_other
ExecStop=/bin/umount /mnt/hgfs

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable vmhgfs-mount.service
    print_ok "Servicio systemd vmhgfs-mount creado y habilitado."
}

# ---------- Opción 3: Listar carpetas compartidas ----------

list_shared_folders() {
    echo ""
    print_info "Carpetas compartidas disponibles en $HGFS_MOUNT:"
    echo ""

    if mountpoint -q "$HGFS_MOUNT"; then
        local folders
        folders=$(ls -1 "$HGFS_MOUNT" 2>/dev/null)

        if [[ -z "$folders" ]]; then
            print_warn "No hay carpetas compartidas. Actívalas en VMware:"
            echo "  VM → Settings → Options → Shared Folders"
        else
            echo -e "  ${CYAN}Carpeta compartida${NC}         ${CYAN}Ruta en la VM${NC}"
            echo "  ────────────────────────────────────────────"
            while IFS= read -r folder; do
                echo -e "  ${GREEN}$folder${NC}  →  $HGFS_MOUNT/$folder"
            done <<< "$folders"
        fi
    else
        print_warn "$HGFS_MOUNT no está montado. Usa la opción 1 primero."
    fi
}

list_shared_folders_menu() {
    print_header
    echo -e "  ${WHITE}Carpetas compartidas disponibles${NC}\n"
    list_shared_folders
    pause
}

# ---------- Opción 4: Crear acceso directo ----------

create_shortcut() {
    print_header
    echo -e "  ${WHITE}Crear acceso directo a carpeta compartida${NC}\n"

    if ! mountpoint -q "$HGFS_MOUNT"; then
        print_warn "$HGFS_MOUNT no está montado. Monta primero las carpetas (opción 1)."
        pause
        return
    fi

    local folders
    folders=$(ls -1 "$HGFS_MOUNT" 2>/dev/null)

    if [[ -z "$folders" ]]; then
        print_warn "No hay carpetas compartidas disponibles."
        pause
        return
    fi

    echo -e "  ${WHITE}Carpetas disponibles:${NC}"
    echo ""
    local i=1
    declare -A folder_map
    while IFS= read -r folder; do
        echo -e "  ${GREEN}[$i]${NC} $folder"
        folder_map[$i]="$folder"
        ((i++))
    done <<< "$folders"

    echo ""
    read -rp "  Elige el número de la carpeta: " folder_choice
    local selected_folder="${folder_map[$folder_choice]}"

    if [[ -z "$selected_folder" ]]; then
        print_error "Opción no válida."
        pause
        return
    fi

    # Obtener el usuario real (no root aunque se use sudo)
    local REAL_USER
    REAL_USER=$(logname 2>/dev/null || echo "$SUDO_USER" || echo "$USER")
    local REAL_HOME
    REAL_HOME=$(eval echo "~$REAL_USER")

    echo ""
    echo -e "  ${WHITE}¿Dónde crear el acceso directo?${NC}"
    echo -e "  ${GREEN}[1]${NC} En el home del usuario ($REAL_HOME/$selected_folder)"
    echo -e "  ${GREEN}[2]${NC} En el Escritorio ($REAL_HOME/Escritorio/$selected_folder)"
    echo -e "  ${GREEN}[3]${NC} Ruta personalizada"
    echo ""
    read -rp "  Elige una opción [1-3]: " link_choice

    local LINK_PATH
    case $link_choice in
        1) LINK_PATH="$REAL_HOME/$selected_folder" ;;
        2) LINK_PATH="$REAL_HOME/Escritorio/$selected_folder" ;;
        3)
            read -rp "  Introduce la ruta completa: " custom_path
            LINK_PATH="$custom_path"
            ;;
        *)
            print_error "Opción no válida."
            pause
            return
            ;;
    esac

    # Crear enlace simbólico
    if [[ -L "$LINK_PATH" ]]; then
        print_warn "Ya existe un enlace en $LINK_PATH. Eliminando..."
        rm "$LINK_PATH"
    fi

    ln -s "$HGFS_MOUNT/$selected_folder" "$LINK_PATH"
    chown -h "$REAL_USER:$REAL_USER" "$LINK_PATH"

    if [[ $? -eq 0 ]]; then
        print_ok "Acceso directo creado: ${CYAN}$LINK_PATH${NC} → $HGFS_MOUNT/$selected_folder"
    else
        print_error "No se pudo crear el acceso directo."
    fi

    pause
}

# ---------- Menú principal ----------

main_menu() {
    check_open_vm_tools
    check_vmhgfs

    while true; do
        print_header
        echo -e "  ${WHITE}¿Qué deseas hacer?${NC}"
        echo ""
        echo -e "  ${GREEN}[1]${NC} Montar carpetas compartidas ahora"
        echo -e "  ${GREEN}[2]${NC} Configurar montaje automático al inicio"
        echo -e "  ${GREEN}[3]${NC} Ver carpetas compartidas disponibles"
        echo -e "  ${GREEN}[4]${NC} Crear acceso directo en home/Escritorio"
        echo -e "  ${RED}[5]${NC} Salir"
        echo ""
        read -rp "  Elige una opción [1-5]: " choice

        case $choice in
            1) mount_shared_folders ;;
            2) setup_automount ;;
            3) list_shared_folders_menu ;;
            4) create_shortcut ;;
            5)
                echo ""
                print_info "Saliendo. ¡Hasta pronto!"
                echo ""
                exit 0
                ;;
            *)
                print_error "Opción no válida. Elige entre 1 y 5."
                pause
                ;;
        esac
    done
}

# ---------- Punto de entrada ----------
check_root
main_menu
