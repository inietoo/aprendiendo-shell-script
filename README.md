# 🐚 Aprendiendo Shell Script

> Scripts de Shell para automatizar tareas en Linux — pensados para aprender y para usar en el día a día.

![Shell Script](https://img.shields.io/badge/Shell-Script-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![VMware](https://img.shields.io/badge/VMware-607078?style=for-the-badge&logo=vmware&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)

---

## 📋 Tabla de Contenidos

- [¿Qué es este repositorio?](#-qué-es-este-repositorio)
- [Requisitos previos](#-requisitos-previos)
- [Scripts disponibles](#-scripts-disponibles)
  - [Instalar VMware Tools](#-instalar-vmware-tools)
  - [Carpetas Compartidas con VMware](#-carpetas-compartidas-con-vmware)
- [Cómo usar los scripts](#-cómo-usar-los-scripts)
- [Estructura del repositorio](#-estructura-del-repositorio)
- [Contribuir](#-contribuir)
- [Licencia](#-licencia)

---

## 🎯 ¿Qué es este repositorio?

Este repositorio es un proyecto de aprendizaje de **Shell Scripting** con scripts útiles y reales para el día a día. Aquí encontrarás:

- ✅ Scripts bien comentados para entender cómo funciona cada línea
- ✅ Manejo de errores y validaciones
- ✅ Menús interactivos con colores
- ✅ Detección automática del sistema operativo
- ✅ Casos de uso reales con VMware

---

## 🔧 Requisitos previos

- Ubuntu Desktop o Ubuntu Server (20.04 / 22.04 / 24.04)
- Máquina virtual en **VMware Workstation** o **VMware Player**
- Acceso a terminal con permisos `sudo`
- Conexión a Internet (para instalación por `apt`)

---

## 📂 Scripts disponibles

### 🛠️ Instalar VMware Tools

**Archivo:** [`scripts/instalar_vmware_tools.sh`](scripts/instalar_vmware_tools.sh)

Este script detecta automáticamente si estás en **Ubuntu Desktop** o **Ubuntu Server** y te ofrece el método de instalación más adecuado.

**Características:**
- 🔍 Detección automática del entorno (Desktop vs Server)
- 📦 Dos métodos de instalación: `open-vm-tools` (recomendado) o desde el CD de VMware
- 🎨 Menú interactivo con colores y validaciones
- ✔️ Verificación del estado tras la instalación
- 📋 Compatible con Ubuntu 20.04, 22.04 y 24.04

**Vista previa del menú:**
```
╔══════════════════════════════════════╗
║     INSTALADOR DE VMWARE TOOLS       ║
╚══════════════════════════════════════╝

  Sistema detectado: Ubuntu Desktop

  Elige el método de instalación:
  [1] Open-VM-Tools (recomendado, desde repositorios)
  [2] VMware Tools oficial (desde CD/ISO de VMware)
  [3] Salir
```

---

### 📁 Carpetas Compartidas con VMware

**Archivo:** [`scripts/carpetas_compartidas.sh`](scripts/carpetas_compartidas.sh)

Configura las **carpetas compartidas** entre tu máquina física (host) y tu máquina virtual de forma sencilla.

**Características:**
- 📂 Monta automáticamente las carpetas compartidas de VMware (`/mnt/hgfs/`)
- 🔄 Opción para hacer el montaje persistente (se mantiene al reiniciar)
- 🗂️ Muestra las carpetas compartidas disponibles
- 🔗 Crea un enlace simbólico en el escritorio o en home para acceso rápido
- 🛡️ Comprueba que `open-vm-tools` esté instalado antes de continuar

**Vista previa del menú:**
```
╔══════════════════════════════════════╗
║   CARPETAS COMPARTIDAS - VMWARE      ║
╚══════════════════════════════════════╝

  [1] Montar carpetas compartidas ahora
  [2] Configurar montaje automático al inicio
  [3] Ver carpetas compartidas disponibles
  [4] Crear acceso directo en el home
  [5] Salir
```

---

## 🚀 Cómo usar los scripts

### 1. Clona el repositorio

```bash
git clone https://github.com/inietoo/aprendiendo-shell-script.git
cd aprendiendo-shell-script
```

### 2. Dale permisos de ejecución

```bash
chmod +x scripts/*.sh
```

### 3. Ejecuta el script que necesites

```bash
# Instalar VMware Tools
sudo ./scripts/instalar_vmware_tools.sh

# Configurar carpetas compartidas
sudo ./scripts/carpetas_compartidas.sh
```

> ⚠️ **Nota:** Ambos scripts requieren `sudo` ya que realizan cambios en el sistema.

---

## 🗂️ Estructura del repositorio

```
aprendiendo-shell-script/
│
├── 📄 README.md                      ← Estás aquí
│
└── 📂 scripts/
    ├── 🔧 instalar_vmware_tools.sh   ← Instala VMware Tools
    └── 📁 carpetas_compartidas.sh    ← Gestiona carpetas compartidas
```

---

## 🤝 Contribuir

¡Las contribuciones son bienvenidas! Si tienes un script útil o quieres mejorar alguno existente:

1. Haz un **fork** del repositorio
2. Crea una rama nueva: `git checkout -b mi-nuevo-script`
3. Añade tu script en la carpeta `scripts/`
4. Haz commit: `git commit -m '✨ Añadir script para...'`
5. Abre un **Pull Request**

---

## 📜 Licencia

Este proyecto está bajo la licencia **MIT**. Puedes usarlo, modificarlo y distribuirlo libremente.

---

<div align="center">
  Hecho con ❤️ para aprender Shell Script
</div>
