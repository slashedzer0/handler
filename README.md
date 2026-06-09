## 🛠️ Handler
Handler is a command line tool to manage AppImages on Linux. It automates installation, extracts embedded icons, and creates desktop entries for your application launcher.

## 📦 Features
- **Interactive Menus**: Navigate installation and uninstallation through a terminal interface.
- **Smart Dependencies**: Checks your operating system and provides commands to install missing FUSE 2 libraries.
- **Icon Extraction**: Scans AppImage internal directories and embedded desktop files to extract the correct application icon.
- **Desktop Integration**: Generates standard desktop entries and updates your local application database automatically.

## ⚙️ Prerequisites
You need FUSE 2 installed on your system to run most AppImages. The handler script detects missing dependencies and provides the correct installation command for other distributions (Arch, Debian, Fedora, openSUSE).

## 🚀 Installation
Save the `handler.sh` script to your computer. Make the file executable and move it to your local user binaries directory so you can access it from your shell environment.
```
chmod +x handler.sh
mv handler.sh ~/.local/bin/handler
```

## 🎯 Usage
Navigate to the directory containing your downloaded AppImage files before running the interactive scanner.
```
cd ~/Downloads
ls -la
handler
```
You can use command line flags to bypass the menus:
- **Install a specific file**: `handler -i /path/to/application.AppImage`
- **Open the uninstall menu**: `handler -u`
- **Show the help screen**: `handler -h`
- **Check the version**: `handler -v`

## 🗺️ Roadmap
The project focuses on packaging the tool for direct installation across all major Linux distributions.
- [ ] Package the script for the Arch User Repository for CachyOS and Arch Linux users.
- [ ] Build native Debian packages for Ubuntu and Pop!_OS systems.
- [ ] Build native RPM packages for Fedora and openSUSE systems.
- [ ] Set up automated continuous integration pipelines for version distribution.

## ⚠️ Limitations
- **Updates**: Handler does not update applications automatically. You must uninstall the old version and install the new file manually.
- **Permissions**: The tool does not sandbox applications. Use a program like Firejail if you need strict permission control.
