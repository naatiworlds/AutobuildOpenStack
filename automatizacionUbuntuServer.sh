#!/bin/bash

# 1. Configuración del teclado en español
echo "Configurando el teclado a español..."
sudo sed -i 's/XKBLAYOUT=.*/XKBLAYOUT="es"/' /etc/default/keyboard
sudo dpkg-reconfigure -f noninteractive keyboard-configuration

# 2. Actualizar el sistema
echo "Actualizando el sistema..."
sudo apt update && sudo apt upgrade -y

# 3. Instalar herramientas básicas
echo "Instalando herramientas esenciales..."
sudo apt install -y git wget net-tools curl vim build-essential

# 4. Pregunta al usuario sobre la instalación de OpenStack o Apache
echo "¿Qué deseas configurar?"
echo "1. Instalar OpenStack (DevStack)"
echo "2. Instalar y configurar Apache"
echo "3. Salir"
read -p "Elige una opción [1-3]: " opcion

case $opcion in
    1)
        echo "Instalando OpenStack (DevStack)..."
        install_openstack
        ;;
    2)
        echo "Instalando y configurando Apache..."
        install_apache
        ;;
    3)
        echo "Saliendo..."
        exit 0
        ;;
    *)
        echo "Opción no válida. Saliendo..."
        exit 1
        ;;
esac

# Función para instalar OpenStack (DevStack)
install_openstack() {
    echo "Clonando el repositorio de DevStack..."
    git clone https://opendev.org/openstack/devstack
    cd devstack

    echo "Creando el archivo de configuración local.conf..."
    cat <<EOL > local.conf
[[local|localrc]]
ADMIN_PASSWORD=password
DATABASE_PASSWORD=password
RABBIT_PASSWORD=password
SERVICE_PASSWORD=password
HOST_IP=127.0.0.1
EOL

    echo "Ejecutando el script de instalación ./stack.sh..."
    ./stack.sh

    echo "OpenStack (DevStack) instalado correctamente."
}

# Función para instalar y configurar Apache
install_apache() {
    echo "Instalando Apache..."
    sudo apt install -y apache2

    echo "Configurando el puerto por defecto..."
    read -p "Introduce el nuevo puerto para Apache (por defecto 80): " nuevo_puerto
    sudo sed -i "s/Listen 80/Listen $nuevo_puerto/" /etc/apache2/ports.conf
    sudo sed -i "s/:80/:$nuevo_puerto/" /etc/apache2/sites-available/000-default.conf

    echo "Configurando el directorio raíz..."
    read -p "Introduce el nuevo directorio raíz para Apache (por defecto /var/www/html): " nuevo_directorio
    sudo sed -i "s|DocumentRoot /var/www/html|DocumentRoot $nuevo_directorio|" /etc/apache2/sites-available/000-default.conf

    echo "Ocultando la versión de Apache..."
    sudo sed -i 's/ServerTokens OS/ServerTokens Prod/' /etc/apache2/conf-available/security.conf
    sudo sed -i 's/ServerSignature On/ServerSignature Off/' /etc/apache2/conf-available/security.conf

    # Habilitar o deshabilitar módulos de Apache
    echo "¿Deseas habilitar o deshabilitar módulos de Apache?"
    echo "1. Habilitar un módulo"
    echo "2. Deshabilitar un módulo"
    echo "3. Saltar esta opción"
    read -p "Elige una opción [1-3]: " modulo_opcion

    case $modulo_opcion in
        1)
            read -p "Introduce el nombre del módulo que deseas habilitar: " modulo
            sudo a2enmod $modulo
            sudo systemctl restart apache2
            echo "Módulo $modulo habilitado."
            ;;
        2)
            read -p "Introduce el nombre del módulo que deseas deshabilitar: " modulo
            sudo a2dismod $modulo
            sudo systemctl restart apache2
            echo "Módulo $modulo deshabilitado."
            ;;
        3)
            echo "Saliendo de la opción de módulos."
            ;;
        *)
            echo "Opción no válida. Saliendo..."
            ;;
    esac

    # Crear un nuevo host virtual
    echo "¿Deseas crear un nuevo host virtual?"
    read -p "¿Deseas crear un nuevo host virtual? (s/n): " crear_vhost

    if [ "$crear_vhost" == "s" ]; then
        read -p "Introduce el nombre del dominio (ejemplo.com): " dominio
        read -p "Introduce el directorio raíz del dominio (/var/www/ejemplo): " docroot
        sudo mkdir -p $docroot

        cat <<EOL | sudo tee /etc/apache2/sites-available/$dominio.conf
<VirtualHost *:$nuevo_puerto>
    ServerAdmin webmaster@$dominio
    ServerName $dominio
    DocumentRoot $docroot
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOL

        sudo a2ensite $dominio.conf
        sudo systemctl reload apache2
        echo "Host virtual $dominio creado y habilitado."
    fi

    # Consultar los hosts virtuales activos
    echo "¿Deseas consultar los hosts virtuales activos?"
    read -p "¿Mostrar hosts virtuales activos? (s/n): " mostrar_vhosts

    if [ "$mostrar_vhosts" == "s" ]; then
        apache2ctl -S
    fi

    sudo systemctl restart apache2
    echo "Apache configurado correctamente."
}
