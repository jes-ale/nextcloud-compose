## Implementación de Nextcloud para la Gestión de Notas y archivos ligeros. 
*jes@alejos.dev* | *[alejos.dev](https://www.alejos.dev)* | *Mexicali, Baja California, México* | *Enero de 2025*

* * *

## Historial de cambios

| Versión | Fecha      | Comentario                                    | Autor |
| ------- | ---------- | --------------------------------------------- | ----- |
| 1.0.1   | 03/02/2025 | Primera edición. Marco teorico y cheat sheet. | Jes   |
| 1.0.2    | 16/02/2025 |                                               |   jes    |
| 1.0.3    | 02/03/2025 |Se agregan mas apps al marco teórico           |   jes    |

* * *
### Introducción

Contar con un sistema autohospedado que garantice soberanía, disponibilidad y seguridad ofrece extensas ventajas para profesionales, investigadores, estudiantes y académicos. Este artículo presenta una solución técnica para la gestión y sincronización de notas, documentos academicos, de investigacion, de caracter profesional o personal y en general cualquier tipo de documento ligero de acceso cotidiano ( 50 MB > txt, csv, xlsx, md, docx, codigo de programacion), utilizando tecnologías de código abierto: **Nextcloud** sobre un servidor VPS con **Docker** y **Nginx** como reverse proxy.

La arquitectura propuesta no solo ofrece control total sobre los datos, sino que también evita la dependencia de servicios de terceros, optimizando la portabilidad mediante estándares abiertos. Además, se prioriza la seguridad, la escalabilidad y la eficiencia en el uso de recursos, lo que la hace ideal para usuarios con necesidades avanzadas de personalización y requisitos exigentes de disponibilidad.

Este enfoque es particularmente útil para entornos académicos y profesionales que requieren un sistema resiliente y de alta disponibilidad. Para implementaciones organizacionales o empresariales tambien pueden beneficiarse de esta guia.

### 1. Marco Teórico

#### 1.1 **VPS (Virtual Private Server)**

- **Definición técnica**:  
    Un VPS es una instancia virtualizada que opera sobre un hipervisor (como KVM, Xen o VMware), asignando recursos dedicados (CPU, RAM, almacenamiento NVMe/SSD) dentro de un servidor físico. A diferencia de los contenedores, un VPS tiene un kernel independiente, lo que permite una personalización completa del stack de software, incluyendo el sistema operativo, el firewall y los servicios.
  
- **Ventajas estratégicas**:
    - **Aislamiento de recursos**: Garantiza un rendimiento estable bajo carga, gracias a la asignación exclusiva de CPU y RAM.
    - **Control de seguridad**: Permite la implementación de medidas avanzadas como hardening del SO (AppArmor, SELinux), gestión de parches y configuración de redes privadas (VPN WireGuard/IPsec).
    - **Costo-eficiencia**: Ofrece una alternativa económica frente a los servidores dedicados, con planes que parten desde 5 USD/mes (por ejemplo, en DigitalOcean, Linode o Hetzner).

#### 1.2 **WebDAV (RFC 4918)**

- **Fundamentos**:  
    WebDAV es un protocolo de capa de aplicación que extiende los métodos HTTP (como PUT, DELETE y PROPFIND) para permitir operaciones CRUD sobre archivos. Es compatible con sistemas *nix (a través de `davfs2`) y clientes como Joplin.

- **Implementación en Nextcloud**:  
    Nextcloud integra WebDAV bajo la ruta `https://<dominio>/remote.php/dav/files/<usuario>/`, utilizando autenticación OAuth2/Basic Auth y cifrado TLS 1.3. Esta implementación permite una sincronización eficiente (solo se transfieren los cambios) y bloqueos de archivos para prevenir conflictos.

#### 1.3 **Manejadores de Archivos y su Interconexión con Nextcloud**

Los manejadores de archivos son herramientas esenciales para la gestión de datos en sistemas operativos. Algunos de ellos ofrecen soporte para WebDAV, lo que permite la conexión y gestión de archivos en servidores como Nextcloud. A continuación, se describen algunos de los manejadores de archivos más conocidos y sus capacidades:

1. **FileZilla**:
   - Soporta WebDAV y permite la transferencia de archivos entre el cliente y el servidor Nextcloud. Su interfaz gráfica es intuitiva y facilita la gestión de archivos.

2. **Cyberduck**:
   - Un cliente de transferencia de archivos que soporta múltiples protocolos, incluyendo WebDAV. Su integración con Nextcloud permite a los usuarios gestionar archivos de manera eficiente y segura.

3. **Nautilus** (Archivos):
   - El gestor de archivos predeterminado de GNOME que permite montar unidades WebDAV fácilmente. Su integración con Nextcloud es directa, facilitando la sincronización de archivos.

4. **Dolphin**:
   - El gestor de archivos de KDE que también soporta WebDAV. Ofrece una interfaz completa y es ideal para usuarios de entornos de escritorio KDE que utilizan Nextcloud.

5. **Thunar**:
   - Un gestor de archivos para entornos de escritorio XFCE. Aunque no tiene soporte nativo para WebDAV, se puede habilitar mediante la instalación de paquetes adicionales, permitiendo la conexión a Nextcloud.

6. **Caja**:
   - El gestor de archivos de MATE, que permite la conexión a unidades WebDAV. Su simplicidad y ligereza lo hacen adecuado para usuarios que buscan una experiencia fluida con Nextcloud.

7. **Ranger** y **Midnight Commander**:
   - Aunque son gestores de archivos basados en texto, pueden configurarse para trabajar con WebDAV, permitiendo la gestión de archivos en Nextcloud desde la terminal.

#### 1.4 **Markdown (CommonMark Standard)**

- **Ventajas técnicas**:
    - **Portabilidad**: Los archivos `.md` son legibles en editores de texto plano (como Vim o VSCode) y compatibles con herramientas de DevOps (Git, CI/CD).
    - **Extensibilidad**: Soporta sintaxis avanzada para diagramas (Mermaid), fórmulas matemáticas (LaTeX) y metadatos (YAML frontmatter).
    - **Conversión sin pérdidas**: Puede ser renderizado a HTML o PDF utilizando herramientas como Pandoc o MkDocs.

#### 1.5 **Cliente/Editor de Markdown**
##### 1.5.1 **[Joplin (v2.14.19+)](https://github.com/laurent22/joplin)**
Joplin es un cliente de notas multiplataforma (basado en Electron.js para desktop y React Native para móvil) que utiliza un motor de sincronización delta y cifrado AES-256-GCM (opcional) tanto en reposo como en tránsito. Además, soporta plugins (TypeScript/Node.js) y una CLI para automatización.

- **Integración con WebDAV**:  
    Joplin almacena las notas como archivos `.md` junto con metadatos en archivos `*.json`, organizados en una estructura jerárquica en el servidor. El cliente maneja conflictos mediante timestamps y hashes SHA-256, lo que permite una sincronización eficiente con Nextcloud a través de WebDAV.

##### 1.5.2 **[Obsidian (v1.8.4)](https://obsidian.md/download)**
Obsidian es una herramienta de gestión de conocimiento basada en Markdown, diseñada para crear y organizar notas en un sistema de bóvedas locales. A diferencia de Joplin, Obsidian no tiene un sistema de sincronización por WebDAV nativo, por eso se utiliza el plugin [**Remotely Save**](https://github.com/remotely-save/remotely-save), una solución de sincronización no oficial que permite a los usuarios sincronizar sus bóvedas entre dispositivos utilizando servicios en la nube como Amazon S3, Dropbox, OneDrive, WebDAV y otros. Este plugin soporta cifrado de extremo a extremo mediante OpenSSL/rclone, lo que garantiza la seguridad de los datos durante la transferencia. Además, ofrece opciones para omitir archivos grandes y rutas específicas mediante expresiones regulares, así como detección básica de conflictos en su versión gratuita y manejo avanzado de conflictos en la versión PRO.

#### 1.6 **Nextcloud (v28+)**  
[Nextcloud](https://github.com/nextcloud/server) es una plataforma de colaboración y almacenamiento en la nube que permite a los usuarios gestionar sus archivos de manera segura y privada.

- **Stack tecnológico**:
    - **Backend**: PHP 8.2 con OPcache, y bases de datos como MariaDB Galera Cluster o PostgreSQL para alta disponibilidad.
    - **Almacenamiento**: Soporta S3 Object Storage, FTP-SSL y sistemas de archivos distribuidos como GlusterFS.
    - **Seguridad**: Incluye autenticación 2FA (TOTP, WebAuthn), auditoría de logs vía syslog-ng y políticas de retención compatibles con GDPR.

- **Interconexión con Manejadores de Archivos**:  
    Nextcloud permite la integración con varios manejadores de archivos a través de WebDAV, lo que facilita la gestión de archivos desde diferentes plataformas. Los usuarios pueden acceder, editar y sincronizar sus archivos almacenados en Nextcloud utilizando clientes como FileZilla, Cyberduck, Nautilus, y otros mencionados anteriormente. Esta flexibilidad permite a los usuarios elegir la herramienta que mejor se adapte a sus necesidades y flujos de trabajo.

- **Clientes adicionales para Nextcloud**:  
    Además de Joplin y Obsidian, otros clientes que se comunican con Nextcloud incluyen:
    - **Nextcloud Desktop Client**: Permite la sincronización de archivos entre el escritorio y el servidor Nextcloud.
    - **Collabora Online**: Una suite de oficina que se integra con Nextcloud para la edición de documentos en línea.
    - **OnlyOffice**: Otra opción de suite de oficina que permite la edición colaborativa de documentos directamente en Nextcloud.
    - **Nextcloud Talk**: Para comunicación y colaboración en tiempo real, integrándose con el almacenamiento de archivos de Nextcloud.

--- 

### 2 Implementacion
#### 2.1 Pre-requisitos

1.  **Servidor VPS**:
    - **Especificaciones mínimas**: 1 vCore, 2 GB de RAM, 20 GB de almacenamiento SSD (Ubuntu 22.04 LTS o Debian 12 Bookworm).
    - **Configuración inicial**:
        - Securización SSH: Deshabilitar el acceso root, utilizar claves ed25519 e implementar fail2ban para mitigar ataques de fuerza bruta.
        - Firewall: Configurar reglas UFW/iptables para permitir solo los puertos 80/TCP, 443/TCP y 22/TCP.
        - Recomendado: Esteblecer acceso restringido por IP desde la red virtual de su empresa. Ver [].
  
2.  **Docker Engine & Compose**:
    - **Instalación**: Utilizar el script oficial de Docker (`curl -fsSL https://get.docker.com | sh`) junto con el plugin de Compose V2 (`apt install docker-compose-plugin`).
    - **Hardening**: Ejecutar los contenedores como usuario no-root, habilitar perfiles de AppArmor y limitar las capacidades del contenedor (`--cap-drop ALL`).
  
3.  **Dominio y TLS**:
    - **Requisito crítico**: Obtener un certificado SSL/TLS wildcard (por ejemplo, mediante Let’s Encrypt Certbot o ZeroSSL) para evitar ataques MITM en WebDAV.
    - **DNS**: Configurar un registro A/AAAA que apunte a la IP del VPS, con DNSSEC habilitado.
  
4.  **Reverse Proxy (preferiblemente Nginx)**:
    - Configurar Nginx como reverse proxy con soporte para HTTP/2, HSTS y OCSP stapling, asegurando un tráfico seguro y eficiente.

---

#### 2.2 Estructura docker-compose.syml
Basado en [NextCloud Official Image](https://hub.docker.com/_/nextcloud/).

```yaml
volumes:
  nextcloud:
  db:

services:
  db:
    image: mariadb:10.6
    restart: always
    command: --transaction-isolation=READ-COMMITTED --log-bin=binlog --binlog-format=ROW
    volumes:
      - db:/var/lib/mysql
    env_file: ./.env
    environment:
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud

  app:
    image: nextcloud
    restart: always
    env_file: ./.env
    ports:
      - 8080:80
    links:
      - db
    volumes:
      - nextcloud:/var/www/html
    environment:
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
      - MYSQL_HOST=db
```

Configurar en el archivo `.env` o usar como variables de entorno del sistema operativo, o elija su forma preferida de manejar secretos.

```bash
export MYSQL_PASSWORD=redacted
export MYSQL_ROOT_PASSWORD=redacted
export NEXTCLOUD_ADMIN_USER=myuser@domain.com
export NEXTCLOUD_ADMIN_PASSWORD=redacted
```

---

#### 2.2 Configuración de Reverse Proxy

```nginx
# ./nginx-conf/cloud.tudominio.com.conf
server {
    listen 80;
    server_name cloud.tudominio.com;
   
    location / {
        proxy_pass http://host.docker.internal:8080;  # Conexión al host desde Docker
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    access_log /var/log/nginx/nextcloud_access.log;
    error_log /var/log/nginx/nextcloud_error.log;
}
```
