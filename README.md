# Kit Open Roberta + EV3 (leJOS) para Windows

Kit portátil para conectar robots LEGO EV3 con leJOS al [Open Roberta Lab](https://lab.open-roberta.org) desde PCs con Windows 10/11, sin instalar Java ni compilar nada.

La guía paso a paso para la sala (driver + conexión en clase) está en [Guia-OpenRoberta-EV3.html](https://material-robotica.github.io/openRoberta-ev3/Guia-OpenRoberta-EV3.html). Este README documenta **de dónde sale cada componente** y **cómo rehacer el kit** si hace falta.

Si hay que armar desde cero la tarjeta microSD del EV3, está [Preparar-microSD-EV3.html](https://material-robotica.github.io/openRoberta-ev3/Preparar-microSD-EV3.html).

> Armado: octubre 2026 · Connector v1.7.0 · Java 17.0.20.1 (Temurin)

## Descarga del kit

- **Última versión (descarga directa):** [OpenRoberta-EV3.zip](https://github.com/material-robotica/openRoberta-ev3/releases/latest/download/OpenRoberta-EV3.zip)
- **Todas las versiones:** [Releases](https://github.com/material-robotica/openRoberta-ev3/releases)

> Para publicar una versión nueva: en el repo, columna derecha → *Releases* → *Draft a new release*. Subir el zip en el recuadro *"Attach binaries by dropping them here"* (abajo del cuadro de descripción) y presionar *Publish release*. Mantener el nombre `OpenRoberta-EV3.zip` para que el enlace de descarga directa siga funcionando.
>

## Contenido del kit
 El kit completo se descarga desde la sección Releases. Al descomprimirlo queda esta estructura:

```
OpenRoberta-EV3\
├── 1 - Abrir Open Roberta.bat            abre el Connector con el Java portátil
├── 2 - Verificar EV3.bat                 muestra cómo ve Windows al EV3 + ping a 10.0.1.1
├── 3 - Reiniciar en modo avanzado (driver).bat   lleva al menú donde se aprieta F7
├── connector\                            OpenRobertaConnector.jar + libs\
├── jre\                                  Java 17 portátil (JRE)
├── driver-ev3\ev3-rndis.inf              driver "puente" para el EV3
├── compilar-connector\                    script + guía para compilar el Connector (opcional)
├── Guia-OpenRoberta-EV3.html             guía para la sala
├── LEEME.txt
└── README.md
```

Las carpetas `connector`, `jre` y `driver-ev3` no se deben renombrar: los `.bat` las buscan por nombre usando rutas relativas (`%~dp0`), así que el kit funciona desde cualquier carpeta o pendrive.

---

## 1. Open Roberta Connector

Programa de escritorio (Java) que hace de puente entre el Lab (en el navegador) y el robot conectado por USB. Antes se llamaba *Open Roberta USB Program*.

- Página de descargas: **https://github.com/OpenRoberta/openroberta-connector/releases**
- Código fuente: https://github.com/OpenRoberta/openroberta-connector

En cada versión, la sección **Assets** trae:

| Archivo | Para qué sirve |
|---|---|
| `OpenRobertaConnectorSetupEN-vX.msi` | Instalador para Windows (requiere permisos; a veces Windows lo bloquea). |
| `OpenRobertaConnectorLinux-vX.tar.gz` | **Es el que usa el kit.** Contiene `OpenRobertaConnector.jar` + carpeta `libs\`, que es Java puro y funciona igual en Windows. |
| `OpenRobertaConnectorMacOSX-vX.pkg` | Instalador para macOS. |
| `Source code (zip)` | Código fuente: solo sirve si se va a compilar con Maven (ver sección 4). |

### Actualizar el Connector del kit

1. Descargar el `.tar.gz` de Linux de la versión nueva.
2. Descomprimirlo (con 7-Zip o con `tar -xzf archivo.tar.gz` en PowerShell).
3. Reemplazar el contenido de `connector\` por `OpenRobertaConnector.jar` y la carpeta `libs\` que vienen dentro.

No hace falta tocar el `.bat`: siempre ejecuta `OpenRobertaConnector.jar`.

---

## 2. Java portátil (JRE 17)

El Connector necesita Java 11 o superior. El kit trae un JRE 17 portátil para no tener que instalar Java en cada PC.

- Descarga: **https://adoptium.net** → *Other platforms* → Windows · x64 · **JRE** · **17** · formato **.zip** (no `.msi`).
- También disponible en https://github.com/adoptium/temurin17-binaries/releases (archivo `OpenJDK17U-jre_x64_windows_hotspot_*.zip`).

Para actualizarlo: descomprimir el `.zip`, borrar la carpeta `jre\` del kit y renombrar la carpeta nueva (por ejemplo `jdk-17.0.x+y-jre`) a `jre`.

Si la PC ya tiene Java instalado, también se puede abrir el Connector sin el JRE del kit:

```powershell
cd ruta\al\kit\connector
java -jar OpenRobertaConnector.jar
```

---

## 3. Driver del EV3 (`ev3-rndis.inf`)

### Por qué hace falta

El EV3 con leJOS se conecta por USB como si fuera una **placa de red** (dirección `10.0.1.1`). Windows 10/11 lo detecta con el identificador `USB\VID_0525&PID_A4A2`, pero le asigna por error el driver de **puerto serie** (aparece como *Dispositivo serie USB (COM…)* en *Puertos*). Así el Connector nunca encuentra el robot.

El archivo `ev3-rndis.inf` no trae ningún programa nuevo: le indica a Windows que use para ese identificador el driver de red RNDIS **que Windows ya trae** (`netrndis.inf`). Como el `.inf` no está firmado digitalmente, para instalarlo hay que desactivar la firma de drivers durante un reinicio (tecla **F7** en *Configuración de inicio*). Los pasos completos están en la Parte A de la guía.

### Contenido del archivo (por si hay que recrearlo)

Guardar como `ev3-rndis.inf` en una carpeta propia (por ejemplo `C:\ev3-rndis`):

```ini
[Version]
Signature   = "$Windows NT$"
Class       = Net
ClassGUID   = {4d36e972-e325-11ce-bfc1-08002be10318}
Provider    = %Prov%
DriverVer   = 06/21/2006,6.0.6000.16384

[Manufacturer]
%Prov% = EV3Devices,NTamd64

[EV3Devices.NTamd64]
%EV3Name% = RNDIS.NT.6.0, USB\VID_0525&PID_A4A2

[ControlFlags]
ExcludeFromSelect = *

[RNDIS.NT.6.0]
Characteristics    = 0x84
BusType            = 15
*IfType            = 6
*MediaType         = 0x10
*PhysicalMediaType = 14
include = netrndis.inf
needs   = usbrndis6.ndi

[RNDIS.NT.6.0.Services]
include = netrndis.inf
needs   = usbrndis6.ndi.Services

[Strings]
Prov    = "EV3 leJOS"
EV3Name = "EV3 leJOS RNDIS"
```

### Comandos útiles para diagnosticar

```powershell
# Cómo reconoce Windows al EV3 (Class: Net = bien, Ports = falta el driver)
Get-PnpDevice -PresentOnly | Where-Object InstanceId -like '*VID_0525*' | Select-Object FriendlyName, Class, Status

# Prueba de conexión (debe responder cuando el driver está bien)
ping 10.0.1.1

# Reiniciar directo al menú de inicio avanzado (para la tecla F7)
shutdown /r /o /t 0
```

Una vez instalado, el driver queda para siempre en esa PC y sirve para **todos** los EV3 (usan el mismo identificador).

---

## 4. Alternativa: compilar el Connector con VS Code + Java + Maven

Sirve si no se puede usar el `.tar.gz` ni el `.msi`, o si se quiere una versión de desarrollo.

### Opción A — script reducido (recomendado)

En la carpeta [`compilar-connector/`](compilar-connector/) del kit está `compilar-openroberta-connector.ps1`, con su guía [`Compilar-Connector-Script-terminal.html`](compilar-connector/Compilar-Connector-Script-terminal.html). Instala **solo JDK 17 y Maven** (y únicamente si faltan), compila el Connector y deja el resultado listo en `C:\OpenRoberta-Connector`. No instala Tomcat, VS Code ni extensiones.

```powershell
# PowerShell como administrador
cd C:\recursos-connector
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\compilar-openroberta-connector.ps1 -RecursosPath "C:\recursos-connector"
```

La carpeta `C:\recursos-connector` lleva el script, el `.zip` **Source code** del Connector y, solo si la PC no los tiene, el `.msi` del JDK 17 y la carpeta `apache-maven-3.9.x`. La compilación necesita internet la primera vez (Maven descarga dependencias).

Si la PC ya tiene el entorno completo de Programación Avanzada (JDK 17 + Maven + VS Code), instalado con el [script del entorno Java Web](https://raw.githack.com/eliizquierdo/material_programacion_avanzada2026/main/recursos-instalacion/Instalacion-Automatica-Script-terminal.html), el script reducido lo detecta y pasa directo a compilar.

### Opción B — a mano con VS Code

Requisitos: **JDK 17** y **Maven** instalados (VS Code es opcional: sirve cualquier terminal). Comprobar que estén disponibles:

```powershell
java -version
mvn -version
```

Pasos:

1. Descargar el código fuente: en la página de releases, **Source code (zip)**, o con git:
   ```powershell
   git clone https://github.com/OpenRoberta/openroberta-connector.git
   ```
2. Descomprimir (si es zip) y en VS Code abrir la carpeta `openroberta-connector` (**Archivo → Abrir carpeta**).
3. Abrir la terminal integrada (**Terminal → Nueva terminal** o `Ctrl + ñ`) y compilar:
   ```powershell
   mvn clean install -DskipTests
   ```
   Debe terminar con `BUILD SUCCESS`.
4. Ejecutar desde la carpeta `target`:
   ```powershell
   cd target
   java -jar .\Open      # apretar Tab para completar el nombre del .jar y Enter
   ```

> Error `Unable to access jarfile`: la terminal no está parada en `target` o el nombre no coincide. Revisar con `dir *.jar` y usar Tab para completar.

### Llevarlo a otra PC

No hace falta volver a compilar. Copiar la carpeta `target` completa (el `.jar` necesita lo que hay al lado) y ejecutar con `java -jar`. Para usarlo dentro de este kit: reemplazar el contenido de `connector\` por el de `target\` y ajustar el nombre del `.jar` en `1 - Abrir Open Roberta.bat`.

---

## 5. Alternativa: instalador `.msi`

Si Windows no deja ejecutar el `.msi`:

- **"Windows protegió su PC"** (SmartScreen): *Más información → Ejecutar de todas formas*.
- **No pasa nada / error de seguridad**: clic derecho en el `.msi` → *Propiedades* → marcar **Desbloquear** → Aceptar.
- **Pide contraseña de administrador**: instalar con una cuenta administradora o usar el kit portátil.

Igual que con el kit, el driver del EV3 (sección 3) hace falta de todas formas.

---

## 6. Referencias

- Open Roberta Lab: https://lab.open-roberta.org
- Wiki del proyecto Open Roberta (instalación, EV3 y leJOS): https://github.com/OpenRoberta/openroberta-lab/wiki
- leJOS EV3: https://sourceforge.net/projects/ev3.lejos.p/
