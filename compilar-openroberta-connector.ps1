<#
.SYNOPSIS
  Instala solo lo necesario (JDK 17 + Maven) y compila el Open Roberta Connector.

.DESCRIPTION
  Version reducida del script del entorno Java Web: NO instala Tomcat, VS Code
  ni extensiones. Reutiliza Java y Maven si ya estan instalados.

  Carpeta de recursos esperada (-RecursosPath):
    recursos-connector\
      OpenJDK17U-jdk_x64_windows_hotspot_*.msi   (solo si la PC no tiene JDK 17)
      apache-maven-3.9.x\                         (solo si la PC no tiene Maven)
      openroberta-connector-*.zip  o  carpeta openroberta-connector\  (codigo fuente)
      compilar-openroberta-connector.ps1

  Resultado: carpeta -Destino con OpenRobertaConnector.jar + libs\ + "Abrir Open Roberta.bat".
  Esa carpeta puede reemplazar a la carpeta connector\ del kit OpenRoberta-EV3.

  IMPORTANTE: la compilacion (mvn) descarga dependencias de internet la primera vez.

.EXAMPLE
  .\compilar-openroberta-connector.ps1 -RecursosPath "C:\recursos-connector"
#>
param(
  [string]$RecursosPath = "C:\recursos-connector",
  [string]$Destino      = "C:\OpenRoberta-Connector"
)

$ErrorActionPreference = "Stop"

function Paso($t)  { Write-Host ""; Write-Host "==> $t" -ForegroundColor Cyan }
function Ok($t)    { Write-Host "    [OK] $t" -ForegroundColor Green }
function Aviso($t) { Write-Host "    [!]  $t" -ForegroundColor Yellow }
function Falla($t) { Write-Host "    [X]  $t" -ForegroundColor Red; exit 1 }

function Recargar-Path {
  $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
              [Environment]::GetEnvironmentVariable("Path","User")
  $jh = [Environment]::GetEnvironmentVariable("JAVA_HOME","Machine")
  if ($jh) { $env:JAVA_HOME = $jh }
}

# java -version y mvn -version escriben en stderr: con "Stop" cortarian el script.
function Ejecutar-Silencioso([scriptblock]$bloque) {
  $prev = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try { & $bloque 2>&1 | ForEach-Object { "$_" } } catch { $null }
  finally { $ErrorActionPreference = $prev }
}

function Version-Java {
  if (-not (Get-Command java -ErrorAction SilentlyContinue)) { return 0 }
  $salida = (Ejecutar-Silencioso { java -version }) -join " "
  if ($salida -match 'version "(\d+)') { return [int]$Matches[1] }
  return 0
}

# ---------------------------------------------------------------------------
Paso "0. Verificaciones iniciales"
$esAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $esAdmin) { Falla "Abrir PowerShell con 'Ejecutar como administrador'." }
if (-not (Test-Path $RecursosPath)) { Falla "No existe la carpeta de recursos: $RecursosPath" }
Ok "Administrador y carpeta de recursos: $RecursosPath"

# ---------------------------------------------------------------------------
Paso "1. Java (JDK 17 o superior)"
Recargar-Path
$v = Version-Java
if ($v -ge 17) {
  Ok "Ya hay Java $v instalado. No se instala nada."
} else {
  $msi = Get-ChildItem $RecursosPath -Filter "*jdk*17*.msi" | Select-Object -First 1
  if (-not $msi) { Falla "No hay Java 17 en la PC ni un .msi del JDK 17 en $RecursosPath" }
  Write-Host "    Instalando $($msi.Name) ..."
  $p = Start-Process msiexec.exe -Wait -PassThru -ArgumentList @(
        "/i", "`"$($msi.FullName)`"",
        "ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome",
        "/qn")
  if ($p.ExitCode -ne 0) { Falla "msiexec termino con codigo $($p.ExitCode)" }
  Recargar-Path
  $v = Version-Java
  if ($v -lt 17) { Falla "Se instalo el JDK pero 'java' no responde. Cerrar y abrir PowerShell y reintentar." }
  Ok "Java $v instalado."
}

# ---------------------------------------------------------------------------
Paso "2. Maven"
if (Get-Command mvn -ErrorAction SilentlyContinue) {
  Ok "Maven ya esta instalado. No se instala nada."
} else {
  $mvnSrc = Get-ChildItem $RecursosPath -Directory -Filter "apache-maven-*" | Select-Object -First 1
  if (-not $mvnSrc) { Falla "No hay Maven en la PC ni una carpeta apache-maven-* en $RecursosPath" }
  $mvnDst = Join-Path $env:ProgramFiles $mvnSrc.Name
  if (-not (Test-Path $mvnDst)) { Copy-Item $mvnSrc.FullName $mvnDst -Recurse }
  [Environment]::SetEnvironmentVariable("MAVEN_HOME", $mvnDst, "Machine")
  $pathM = [Environment]::GetEnvironmentVariable("Path","Machine")
  if ($pathM -notlike "*$mvnDst\bin*") {
    [Environment]::SetEnvironmentVariable("Path", "$pathM;$mvnDst\bin", "Machine")
  }
  Recargar-Path
  if (-not (Get-Command mvn -ErrorAction SilentlyContinue)) { Falla "Maven copiado pero 'mvn' no responde." }
  Ok "Maven instalado en $mvnDst"
}

# ---------------------------------------------------------------------------
Paso "3. Codigo fuente del Connector"
$fuente = Get-ChildItem $RecursosPath -Directory |
          Where-Object { Test-Path (Join-Path $_.FullName "pom.xml") } |
          Where-Object { $_.Name -like "openroberta-connector*" } | Select-Object -First 1
if (-not $fuente) {
  $zip = Get-ChildItem $RecursosPath -Filter "openroberta-connector*.zip" | Select-Object -First 1
  if (-not $zip) { Falla "No hay carpeta ni .zip openroberta-connector* en $RecursosPath" }
  $tmp = Join-Path $env:TEMP "openroberta-connector-src"
  if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
  Write-Host "    Descomprimiendo $($zip.Name) ..."
  Expand-Archive $zip.FullName -DestinationPath $tmp
  $pom = Get-ChildItem $tmp -Recurse -Filter pom.xml | Sort-Object { $_.FullName.Length } | Select-Object -First 1
  if (-not $pom) { Falla "El .zip no contiene un pom.xml" }
  $fuente = $pom.Directory
}
Ok "Fuente: $($fuente.FullName)"

# ---------------------------------------------------------------------------
Paso "4. Compilar con Maven (la primera vez descarga dependencias: necesita internet)"
Push-Location $fuente.FullName
$prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
& mvn -B clean install -DskipTests
$codigo = $LASTEXITCODE
$ErrorActionPreference = $prev
Pop-Location
if ($codigo -ne 0) { Falla "La compilacion fallo (codigo $codigo). Revisar los mensajes de Maven arriba." }
Ok "BUILD SUCCESS"

# ---------------------------------------------------------------------------
Paso "5. Copiar el resultado a $Destino"
$target = Join-Path $fuente.FullName "target"
$jar = Get-ChildItem $target -Filter "*.jar" |
       Where-Object { $_.Name -notmatch "sources|javadoc|^original-" } |
       Sort-Object Length -Descending | Select-Object -First 1
if (-not $jar) { Falla "No se encontro el .jar en $target" }

if (Test-Path $Destino) { Remove-Item $Destino -Recurse -Force }
New-Item -ItemType Directory $Destino | Out-Null
Copy-Item $jar.FullName (Join-Path $Destino "OpenRobertaConnector.jar")
Get-ChildItem $target -Directory |
  Where-Object { $_.Name -notin @("classes","test-classes","maven-status","maven-archiver","generated-sources","generated-test-sources","surefire-reports") } |
  ForEach-Object { Copy-Item $_.FullName $Destino -Recurse }

$bat = @"
@echo off
cd /d "%~dp0"
start "" javaw -jar OpenRobertaConnector.jar
"@
Set-Content -Path (Join-Path $Destino "Abrir Open Roberta.bat") -Value $bat -Encoding ASCII
Ok "Listo: $Destino"

# ---------------------------------------------------------------------------
Paso "Resumen"
Ejecutar-Silencioso { java -version } | Select-Object -First 1 | ForEach-Object { Write-Host "    $_" }
Ejecutar-Silencioso { mvn -version }  | Select-Object -First 1 | ForEach-Object { Write-Host "    $_" }
Write-Host ""
Write-Host "    Abrir el Connector: doble clic en '$Destino\Abrir Open Roberta.bat'" -ForegroundColor Green
Write-Host "    Para el kit portatil: reemplazar el contenido de OpenRoberta-EV3\connector\ por el de $Destino" -ForegroundColor Green
