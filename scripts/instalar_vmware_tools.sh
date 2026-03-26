#!/bin/bash
# ==============================================================
#  instalar_vmware_tools.sh
#  Instala VMware Tools en Ubuntu Desktop o Ubuntu Server
#  Autor: aprendiendo-shell-script
#  Uso: sudo ./instalar_vmware_tools.sh
# ==============================================================

# ---------- Colores ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # Sin color

# ---------- Funciones de utilidad ----------

print_header() {
    clear
    echo -e "${CYAN}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║       INSTALADOR DE VMWARE TOOLS         ║"
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

# ---------- Comprobaciones previas ----------

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Este script debe ejecutarse con sudo o como root."
        echo -e "  Uso: ${YELLOW}sudo $0${NC}"
        exit 1
    fi
}

check_internet() {
    print_info "Comprobando conexión a Internet..."
    if ping -c 1 archive.ubuntu.com &>/dev/null; then
        print_ok "Conexión a Internet disponible."
        return 0
    else
        print_warn "Sin conexión a Internet. Solo estará disponible la instalación desde CD."
        return 1
    fi
}

# ---------- Detección del entorno ----------

detect_environment() {
    # Detecta si es Desktop o Server mirando si hay entorno gráfico
    if dpkg -l ubuntu-desktop &>/dev/null 2>&1 || \n       dpkg -l ubuntu-desktop-minimal &>/dev/null 2>&1 || \n       [[ -n "$DISPLAY" ]] || [[ -n "$WAYLAND_DISPLAY" ]]; then
        ENVIRONMENT="Desktop"
    else
        ENVIRONMENT="Server"
    fi

    # Obtener versión de Ubuntu
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_NAME="$NAME"
        OS_VERSION="$VERSION_ID"
    else
        OS_NAME="Ubuntu"
        OS_VERSION="desconocida"
    fi
}

# ---------- Método 1: open-vm-tools (recomendado) ----------

install_open_vm_tools() {
    print_header
    echo -e "  ${WHITE}Instalando open-vm-tools...${NC}\n"

    print_info "Actualizando lista de paquetes..."
    apt-get update -qq
    print_ok "Lista de paquetes actualizada."

    if [[ "$ENVIRONMENT" == "Desktop" ]]; then
        print_info "Entorno Desktop detectado. Instalando open-vm-tools-desktop..."
        apt-get install -y open-vm-tools open-vm-tools-desktop
    else
        print_info "Entorno Server detectado. Instalando open-vm-tools..."
        apt-get install -y open-vm-tools
    fi

    if [[ $? -eq 0 ]]; then
        print_ok "open-vm-tools instalado correctamente."
        echo ""
        print_info "Habilitando e iniciando el servicio..."
        systemctl enable open-vm-tools
        systemctl start open-vm-tools
        print_ok "Servicio open-vm-tools activo y habilitado."
        verify_installation
    else
        print_error "Error durante la instalación. Revisa los mensajes anteriores."
        exit 1
    fi

    pause
}

# ---------- Método 2: VMware Tools oficial desde CD ----------

install_from_cd() {
    print_header
    echo -e "  ${WHITE}Instalación desde CD/ISO de VMware Tools${NC}\n"

    print_warn "Antes de continuar, asegúrate de haber montado el CD de VMware Tools:"
    echo "  En VMware: VM → Install VMware Tools..."
    echo ""
    read -rp "  ¿Has montado el CD de VMware Tools? [s/N]: " confirm

    if [[ ! "$confirm" =~ ^[sS]$ ]]; then
        print_warn "Operación cancelada. Monta el CD primero desde el menú de VMware."
        pause
        return
    fi

    # Buscar el punto de montaje del CD
    CD_MOUNT=""
    for mount_point in /media/cdrom /media/cdrom0 /mnt/cdrom /run/media/*; do
        if ls "$mount_point"/VMwareTools-*.tar.gz &>/dev/null 2>&1; then
            CD_MOUNT="$mount_point"
            break
        fi
    done

    if [[ -z "$CD_MOUNT" ]]; then
        # Intentar montar manualmente
        print_info "Intentando montar el CD automáticamente..."
        mkdir -p /mnt/cdrom
        mount /dev/cdrom /mnt/cdrom 2>/dev/null
        if ls /mnt/cdrom/VMwareTools-*.tar.gz &>/dev/null 2>&1; then
            CD_MOUNT="/mnt/cdrom"
        else
            print_error "No se encontró el CD de VMware Tools. Asegúrate de montarlo desde VMware."
            pause
            return
        fi
    fi

    print_ok "CD encontrado en: $CD_MOUNT"

    # Instalar dependencias necesarias
    print_info "Instalando dependencias..."
    apt-get install -y build-essential linux-headers-$(uname -r) -qq

    # Extraer e instalar
    TARBALL=$(ls "$CD_MOUNT"/VMwareTools-*.tar.gz | head -1)
    print_info "Extrayendo $TARBALL..."
    tar -xzf "$TARBALL" -C /tmp/

    print_info "Ejecutando el instalador de VMware Tools..."
    /tmp/vmware-tools-distrib/vmware-install.pl --default

    if [[ $? -eq 0 ]]; then
        print_ok "VMware Tools instalado correctamente desde CD."
        verify_installation
    else
        print_error "La instalación falló. Revisa los mensajes anteriores."
    fi

    # Limpiar
    rm -rf /tmp/vmware-tools-distrib
    umount /mnt/cdrom 2>/dev/null

    pause
}

# ---------- Verificar instalación ----------

verify_installation() {
    echo ""
    print_info "Verificando la instalación..."
    echo ""

    # Comprobar si vmware-checkvm existe y responde
    if command -v vmware-checkvm &>/dev/null; then
        vmware-checkvm &>/dev/null && print_ok "VMware Tools responde correctamente." || print_warn "VMware Tools instalado pero sin respuesta de VMware."
    fi

    # Estado del servicio
    if systemctl is-active --quiet open-vm-tools 2>/dev/null; then
        print_ok "Servicio open-vm-tools: ${GREEN}ACTIVO${NC}"
    elif systemctl is-active --quiet vmware-tools 2>/dev/null; then
        print_ok "Servicio vmware-tools: ${GREEN}ACTIVO${NC}"
    else
        print_warn "No se detecta ningún servicio de VMware Tools activo."
    fi

    # Versión instalada
    if dpkg -l open-vm-tools 2>/dev/null | grep -q '^ii'; then
        VERSION=$(dpkg -l open-vm-tools | awk '/^ii/{print $3}')
        print_ok "Versión instalada: ${CYAN}$VERSION${NC}"
    fi

    echo ""
    print_ok "¡Instalación completada! Se recomienda reiniciar la máquina virtual."
    echo ""
    read -rp "  ¿Deseas reiniciar ahora? [s/N]: " reboot_now
    if [[ "$reboot_now" =~ ^[sS]$ ]]; then
        print_info "Reiniciando..."
        reboot
    fi
}

# ---------- Menú principal ----------

main_menu() {
    local internet_ok
    check_internet && internet_ok=true || internet_ok=false

    while true; do
        print_header
        echo -e "  Sistema detectado: ${GREEN}$OS_NAME $OS_VERSION ($ENVIRONMENT)${NC}"
        echo ""
        echo -e "  ${WHITE}Elige el método de instalación:${NC}"
        echo ""

        if $internet_ok; then
            echo -e "  ${GREEN}[1]${NC} Open-VM-Tools ${GREEN}(recomendado)${NC} — desde repositorios apt"
        else
            echo -e "  ${YELLOW}[1]${NC} Open-VM-Tools ${YELLOW}(sin internet)${NC} — requiere conexión"
        fi

        echo -e "  ${GREEN}[2]${NC} VMware Tools oficial — desde CD/ISO de VMware"
        echo -e "  ${RED}[3]${NC} Salir"
        echo ""
        read -rp "  Elige una opción [1-3]: " choice

        case $choice in
            1)
                if $internet_ok; then
                    install_open_vm_tools
                else
                    print_warn "No hay conexión a Internet. Usa la opción 2."
                    pause
                fi
                ;;
            2) install_from_cd ;;
            3)
                echo ""
                print_info "Saliendo. ¡Hasta pronto!"
                echo ""
                exit 0
                ;;
            *)
                print_error "Opción no válida. Elige entre 1 y 3."
                pause
                ;;
        esac
    done
}

# ---------- Punto de entrada ----------
check_root
detect_environment
main_menu
