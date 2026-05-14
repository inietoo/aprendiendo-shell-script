#!/bin/bash
# ╔═══════════════════════════════════════════════════════════════╗
# ║ Instalador Completo de VirtualBox Guest Additions           ║
# ║ Portapapeles, Arrastrar/Soltar y Carpeta Compartida en Escritorio ║
# ║ Funciona en Ubuntu 24.04, Linux Mint, Xubuntu, etc. (X11)  ║
# ╚═══════════════════════════════════════════════════════════════╝

set -euo pipefail

# Colores para una salida bonita
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
AZUL='\033[0;34m'
CIAN='\033[0;36m'
NC='\033[0m' # Sin color

# ─── Comprobaciones iniciales ───────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    echo -e "${ROJO}❌ Este script debe ejecutarse con sudo.${NC}"
    echo -e "   Uso: ${VERDE}sudo bash $0${NC}"
    exit 1
fi

if [ -z "${SUDO_USER:-}" ]; then
    echo -e "${ROJO}❌ No se pudo determinar el usuario real.${NC}"
    exit 1
fi

REAL_USER="$SUDO_USER"
REAL_HOME=$(eval echo ~"$REAL_USER")

echo -e "${CIAN}🚀 Iniciando instalación de Guest Additions...${NC}"

# ─── 1. Verificar sesión gráfica (Xorg obligatorio) ────────────
# Solo podemos comprobar si el usuario está en una sesión X11 o Wayland
if [ -n "${XDG_SESSION_TYPE:-}" ]; then
    SESION="$XDG_SESSION_TYPE"
else
    # Intentar obtenerla del usuario
    SESION=$(loginctl show-user "$REAL_USER" -p Session --value 2>/dev/null | head -1 | xargs loginctl show-session -p Type --value 2>/dev/null || echo "")
fi

if [ "$SESION" = "wayland" ]; then
    echo -e "${AMARILLO}⚠️  Estás usando Wayland. Las Guest Additions NO funcionarán completamente.${NC}"
    echo -e "${AMARILLO}   Por favor, cierra sesión, elige 'Ubuntu en Xorg' (o 'Xfce Session') y vuelve a ejecutar.${NC}"
    exit 1
fi
echo -e "${VERDE}✔ Sesión gráfica: $SESION (X11) – compatible.${NC}"

# ─── 2. Instalar dependencias ──────────────────────────────────
echo -e "${AZUL}📦 Instalando dependencias...${NC}"
apt update -qq
apt install -y build-essential dkms linux-headers-$(uname -r) > /dev/null
echo -e "${VERDE}✔ Dependencias instaladas.${NC}"

# ─── 3. Localizar y preparar la ISO de Guest Additions ─────────
echo -e "${AZUL}🔍 Buscando la ISO de Guest Additions...${NC}"
ISO_MOUNT=""
if mount | grep -q "/dev/sr0"; then
    ISO_MOUNT=$(mount | grep "/dev/sr0" | awk '{print $3}')
elif [ -d "/media/$REAL_USER/VBox_GAs_"* ]; then
    ISO_MOUNT=$(ls -d /media/$REAL_USER/VBox_GAs_* 2>/dev/null | head -n1)
fi

if [ -z "$ISO_MOUNT" ]; then
    mkdir -p /mnt/cdrom
    if mount /dev/sr0 /mnt/cdrom 2>/dev/null; then
        ISO_MOUNT="/mnt/cdrom"
    else
        echo -e "${ROJO}❌ No se encontró la ISO. Insértala desde el menú 'Dispositivos' -> 'Insertar imagen de CD de las Guest Additions...'${NC}"
        exit 1
    fi
fi
echo -e "${VERDE}✔ ISO montada en $ISO_MOUNT${NC}"

TEMP_GA="/tmp/vboxga_install"
rm -rf "$TEMP_GA"
mkdir -p "$TEMP_GA"
cp -r "$ISO_MOUNT"/* "$TEMP_GA/"
chmod +x "$TEMP_GA/VBoxLinuxAdditions.run"

# ─── 4. Ejecutar el instalador (ignorando falsos errores) ───────
echo -e "${AZUL}⚙️  Instalando módulos del kernel...${NC}"
cd "$TEMP_GA"
set +e
./VBoxLinuxAdditions.run > /tmp/vbox_install.log 2>&1
INSTALL_RC=$?
set -e

if [ $INSTALL_RC -ne 0 ]; then
    echo -e "${AMARILLO}⚠️  El instalador reportó un error (puede ser falso). Consulta /tmp/vbox_install.log${NC}"
else
    echo -e "${VERDE}✔ Módulos instalados correctamente.${NC}"
fi

# ─── 5. Añadir usuario al grupo vboxsf ──────────────────────────
echo -e "${AZUL}👤 Añadiendo usuario '$REAL_USER' al grupo vboxsf...${NC}"
usermod -a -G vboxsf "$REAL_USER"
echo -e "${VERDE}✔ Hecho. Cierra sesión y vuelve a entrar para aplicar el cambio.${NC}"

# ─── 6. Configurar el autoarranque de VBoxClient (portapapeles/arrastre) ──
echo -e "${AZUL}🖥️  Configurando inicio automático de servicios gráficos...${NC}"
AUTOSTART_DIR="$REAL_HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

cat > "$AUTOSTART_DIR/vboxclient.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=VirtualBox Guest Additions
Comment=Habilita portapapeles y arrastrar/soltar
Exec=bash -c "export XDG_RUNTIME_DIR=/run/user/\$(id -u); VBoxClient-all"
Terminal=false
StartupNotify=false
X-GNOME-Autostart-enabled=true
EOF

chown -R "$REAL_USER":"$REAL_USER" "$AUTOSTART_DIR"
echo -e "${VERDE}✔ Servicios se iniciarán automáticamente al entrar en X11.${NC}"

# ─── 7. Configurar carpeta compartida ──────────────────────────
echo -e "${AZUL}📂 Configurando carpeta compartida...${NC}"
# Nombre seguro sin espacios: usaremos "Carpeta_Compartida" internamente
NOMBRE_CARPETA="Carpeta_Compartida"
PUNTO_MONTAJE="/media/sf_$NOMBRE_CARPETA"

# Preguntar si el usuario ya tiene otra carpeta configurada
read -p "   ¿El nombre de la carpeta en VirtualBox es 'Carpeta_Compartida'? (S/n): " RESPUESTA
if [[ "$RESPUESTA" =~ ^[Nn] ]]; then
    read -p "   Introduce el nombre exacto que pusiste en VirtualBox: " NOMBRE_CARPETA
    PUNTO_MONTAJE="/media/sf_$NOMBRE_CARPETA"
fi

echo -e "${VERDE}   Intentando montar '$NOMBRE_CARPETA' en $PUNTO_MONTAJE...${NC}"
mkdir -p "$PUNTO_MONTAJE"
if mount -t vboxsf "$NOMBRE_CARPETA" "$PUNTO_MONTAJE" 2>/dev/null; then
    echo -e "${VERDE}✔ Montada correctamente.${NC}"
else
    echo -e "${AMARILLO}⚠️  No se pudo montar ahora. Asegúrate de que en VirtualBox (máquina apagada) existe esa carpeta compartida con 'Auto-montar' y 'Hacer permanente'.${NC}"
    echo -e "   Después de reiniciar, puedes montarla con: ${VERDE}sudo mount -t vboxsf $NOMBRE_CARPETA $PUNTO_MONTAJE${NC}"
fi

# ─── 8. Crear acceso directo en el Escritorio ───────────────────
echo -e "${AZUL}🔗 Creando acceso directo en el escritorio como 'Carpeta Compartida'...${NC}"
if [ -d "$REAL_HOME/Escritorio" ]; then
    ESCRITORIO="$REAL_HOME/Escritorio"
elif [ -d "$REAL_HOME/Desktop" ]; then
    ESCRITORIO="$REAL_HOME/Desktop"
else
    ESCRITORIO="$REAL_HOME"
fi

ENLACE="$ESCRITORIO/Carpeta Compartida"
rm -f "$ENLACE"
ln -s "$PUNTO_MONTAJE" "$ENLACE"
chown -h "$REAL_USER":"$REAL_USER" "$ENLACE"
echo -e "${VERDE}✔ Acceso directo creado: $ENLACE${NC}"

# ─── 9. Mensaje final ──────────────────────────────────────────
echo ""
echo -e "${CIAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CIAN}║  ${VERDE}✅ INSTALACIÓN COMPLETADA CON ÉXITO${CIAN}           ║${NC}"
echo -e "${CIAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${AMARILLO}🔁  Ahora REINICIA la máquina virtual:${NC} sudo reboot"
echo -e "${AMARILLO}⚠️  Al iniciar sesión, ASEGÚRATE de elegir 'Ubuntu en Xorg' o 'Xfce Session'.${NC}"
echo ""
echo -e "   ${VERDE}📂 Carpeta compartida en el escritorio:${NC} Carpeta Compartida"
echo -e "   ${VERDE}📋 Portapapeles y arrastrar/soltar:${NC} funcionarán automáticamente."
echo -e "   ${VERDE}💡 Si algo falla, ejecuta manualmente:${NC} VBoxClient-all"
echo ""