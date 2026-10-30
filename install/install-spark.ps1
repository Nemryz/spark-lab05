#Requires -Version 5.1
<#
.SYNOPSIS
    Installs the Spark 3.3.4 / JDK 11 / Python 3.10 laboratory environment on Windows.

.DESCRIPTION
    The script is idempotent. It detects what is already installed, downloads only the missing artifacts, verifies every checksum and writes install\spark-env.ps1 so that run.ps1 can prepare a process without touching the machine wide Java installation.

.PARAMETER ProjectRoot
    Repository root. Defaults to the parent directory of this script.

.PARAMETER UserRoot
    Preferred root for the Spark, JDK and winutils directories. Defaults to C:\.

.PARAMETER FallbackRoot
    Root used when UserRoot is not writable. Defaults to %LOCALAPPDATA%\spark-lab.

.PARAMETER NoUserEnv
    Do not write HKCU environment variables. Used by CI and by portable installs.

.PARAMETER Offline
    Use only artifacts that are already present in the cache.

.PARAMETER DryRun
    Print the resolved plan without downloading, extracting or writing anything.

.EXAMPLE
    .\install\install-spark.ps1

.EXAMPLE
    .\install\install-spark.ps1 -UserRoot C:\spark-lab -CachePath C:\spark-lab\cache -NoUserEnv -Ci
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot = '',
    [string]$UserRoot = ($env:SystemDrive + '\'),
    [string]$FallbackRoot = '',
    [string]$SparkHome = '',
    [string]$HadoopHome = '',
    [string]$JavaHome = '',
    [string]$PythonHome = '',
    [string]$VenvPath = '',
    [string]$CachePath = '',
    [switch]$SkipJava,
    [switch]$SkipPython,
    [switch]$SkipSpark,
    [switch]$SkipWinutils,
    [switch]$NoUserEnv,
    [switch]$Offline,
    [switch]$Force,
    [switch]$DryRun,
    [switch]$Ci,
    [switch]$NoGit
)

$ErrorActionPreference = 'Stop'
try {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
} catch {
    # Older runtimes may not expose Tls12. curl.exe handles its own TLS stack.
}

. (Join-Path $PSScriptRoot 'lib\Installer.ps1')

trap {
    Write-Fail $_.Exception.Message
    if (-not [string]::IsNullOrWhiteSpace($_.ScriptStackTrace)) {
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    }
    Write-Host ''
    Write-Host 'Installation aborted. Fix the error above and run the script again.' -ForegroundColor Red
    exit 1
}

function Reset-Directory {
    param(
        [string]$Path,
        [string]$Marker,
        [string]$Description
    )
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $items = @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue)
    if ($items.Count -eq 0) {
        Remove-Item -LiteralPath $Path -Recurse -Force
        return
    }
    if (-not [string]::IsNullOrWhiteSpace($Marker) -and (Test-Path -LiteralPath (Join-Path $Path $Marker))) {
        Remove-Item -LiteralPath $Path -Recurse -Force
        return
    }
    throw "Refusing to replace $Description at $Path. Remove it manually or choose another path."
}

function Get-Artifact {
    param(
        [string]$Url,
        [string]$Artifact,
        [string]$Cache,
        [string]$Hash,
        [string]$Algorithm,
        [long]$SizeBytes
    )
    $destination = Join-Path $Cache $Artifact
    if (Test-Path -LiteralPath $destination) {
        $actual = Get-FileHashValue -Path $destination -Algorithm $Algorithm
        if ($actual -eq $Hash.ToLowerInvariant()) {
            Write-Ok "Cached $Artifact"
            return $destination
        }
        Write-Warn "Cached $Artifact does not match the expected hash. Removing it."
        Remove-Item -LiteralPath $destination -Force
    }
    if ($script:OfflineMode) {
        throw "Offline mode is enabled and $Artifact is not available in $Cache."
    }
    Write-Info ("Downloading {0} ({1:N1} MB)" -f $Artifact, ($SizeBytes / 1MB))
    Invoke-Download -Url $Url -Destination $destination -ExpectedHash $Hash -Algorithm $Algorithm
    Write-Ok "Downloaded $Artifact"
    return $destination
}

function Install-JdkDistribution {
    param([string]$Destination, [string]$Archive, [string]$Cache, [string]$Version)
    if (-not $Force -and (Get-JavaMajor -JavaExe (Join-Path $Destination 'bin\java.exe')) -eq 11) {
        Write-Ok "JDK 11 already present at $Destination"
        return
    }
    $staging = Join-Path $Cache 'staging-jdk'
    if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $staging | Out-Null
    Write-Info 'Extracting the JDK archive'
    Expand-ZipArchive -Archive $Archive -Destination $staging
    $inner = Get-SingleChildDirectory -Path $staging
    if (-not $inner) { throw 'Unexpected JDK archive layout. Expected a single top level directory.' }
    Reset-Directory -Path $Destination -Marker 'bin\java.exe' -Description 'a Java installation'
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Move-Contents -Source $inner -Destination $Destination
    Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
    $major = Get-JavaMajor -JavaExe (Join-Path $Destination 'bin\java.exe')
    if ($major -ne 11) { throw "The JDK at $Destination does not report Java 11." }
    Write-Ok "JDK $Version installed at $Destination"
}

function Install-SparkDistribution {
    param([string]$Destination, [string]$Archive, [string]$Cache, [string]$Version)
    $marker = Join-Path $Destination ('jars\spark-core_2.12-' + $Version + '.jar')
    if (-not $Force -and (Test-Path -LiteralPath $marker)) {
        Write-Ok "Spark $Version already present at $Destination"
        return
    }
    $staging = Join-Path $Cache 'staging-spark'
    if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $staging | Out-Null
    Write-Info 'Extracting the Spark archive (about 430 MB)'
    Expand-TarGz -Archive $Archive -Destination $staging
    $inner = Get-SingleChildDirectory -Path $staging
    if (-not $inner) { throw 'Unexpected Spark archive layout. Expected a single top level directory.' }
    Reset-Directory -Path $Destination -Marker 'RELEASE' -Description 'a Spark installation'
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Move-Contents -Source $inner -Destination $Destination
    Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
    if (-not (Test-Path -LiteralPath $marker)) { throw "Spark extraction did not produce the expected jar at $marker" }
    Write-Ok "Spark $Version installed at $Destination"
}

function Install-WinutilsFiles {
    param([string]$Destination, $Dependency, [string]$Cache)
    $bin = Join-Path $Destination 'bin'
    $valid = $true
    foreach ($file in $Dependency.files) {
        $target = Join-Path $bin $file.name
        if (-not (Test-Path -LiteralPath $target)) { $valid = $false; continue }
        if ((Get-FileHashValue -Path $target -Algorithm 'SHA256') -ne $file.sha256) { $valid = $false }
    }
    if ($valid -and -not $Force) {
        Write-Ok "winutils $($Dependency.version) already present at $Destination"
        return
    }
    if (-not (Test-Path -LiteralPath $bin)) { New-Item -ItemType Directory -Force -Path $bin | Out-Null }

    $copiedFromGit = $false
    $git = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($git -and -not $NoGit) {
        $repository = Join-Path $Cache 'winutils-git'
        try {
            if (-not (Test-Path -LiteralPath (Join-Path $repository '.git'))) {
                if (Test-Path -LiteralPath $repository) { Remove-Item -LiteralPath $repository -Recurse -Force }
                Write-Info 'Cloning the winutils repository (shallow clone)'
                $clone = Invoke-CommandCapture -FilePath $git.Source -Arguments @('clone', '--quiet', '--depth', '1', $Dependency.git, $repository)
                if ($clone.ExitCode -ne 0) { throw "git clone exited with code $($clone.ExitCode): $($clone.Output)" }
            }
            $head = (Invoke-CommandCapture -FilePath $git.Source -Arguments @('-C', $repository, 'rev-parse', 'HEAD')).Output
            if ($head -ne $Dependency.commit) {
                Write-Info "Checking out the pinned commit $($Dependency.commit)"
                $fetch = Invoke-CommandCapture -FilePath $git.Source -Arguments @('-C', $repository, 'fetch', '--quiet', '--depth', '1', 'origin', $Dependency.commit)
                if ($fetch.ExitCode -ne 0) { throw "git fetch exited with code $($fetch.ExitCode): $($fetch.Output)" }
                $checkout = Invoke-CommandCapture -FilePath $git.Source -Arguments @('-C', $repository, 'checkout', '--quiet', $Dependency.commit)
                if ($checkout.ExitCode -ne 0) { throw "git checkout exited with code $($checkout.ExitCode): $($checkout.Output)" }
            }
            $sourceBin = Join-Path $repository ('hadoop-' + $Dependency.version + '\bin')
            foreach ($file in $Dependency.files) {
                $source = Join-Path $sourceBin $file.name
                if (-not (Test-Path -LiteralPath $source)) { throw "The clone does not contain $($file.name)." }
                Copy-Item -LiteralPath $source -Destination (Join-Path $bin $file.name) -Force
            }
            $copiedFromGit = $true
            Write-Ok 'winutils copied from the pinned git commit'
        } catch {
            Write-Warn "The git route failed: $($_.Exception.Message)"
            Write-Warn 'Falling back to a direct download of the two binaries.'
        }
    } elseif (-not $git) {
        Write-Info 'git was not found. Downloading the two winutils files directly.'
    }

    if (-not $copiedFromGit) {
        foreach ($file in $Dependency.files) {
            $target = Join-Path $bin $file.name
            if ((Test-Path -LiteralPath $target) -and ((Get-FileHashValue -Path $target -Algorithm 'SHA256') -eq $file.sha256)) {
                continue
            }
            Invoke-Download -Url ($Dependency.rawBase + '/' + $file.name) -Destination $target -ExpectedHash $file.sha256 -Algorithm 'SHA256'
        }
    }

    foreach ($file in $Dependency.files) {
        $target = Join-Path $bin $file.name
        $actual = Get-FileHashValue -Path $target -Algorithm 'SHA256'
        if ($actual -ne $file.sha256) {
            throw "Checksum mismatch for $($file.name). Expected $($file.sha256) but found $actual."
        }
    }
    Write-Ok "winutils $($Dependency.version) installed at $Destination"
}

function Install-PythonRuntime {
    param([string]$Destination, [string]$Archive, [string]$Cache, $Dependency)
    if (-not $Force -and (Get-PythonVersion -PythonExe (Join-Path $Destination 'python.exe')) -eq '3.10') {
        Write-Ok "Python 3.10 already present at $Destination"
        return
    }
    Reset-Directory -Path $Destination -Marker 'python.exe' -Description 'a Python installation'
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    $arguments = @($Dependency.installerArgs)
    $arguments += ('TargetDir="' + $Destination + '"')
    $arguments += ('/log "' + (Join-Path $Cache 'python-install.log') + '"')
    Write-Info "Running the Python $($Dependency.version) installer"
    $process = Start-Process -FilePath $Archive -ArgumentList $arguments -Wait -PassThru
    if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
        throw "The Python installer exited with code $($process.ExitCode). See $Cache\python-install.log"
    }
    $version = Get-PythonVersion -PythonExe (Join-Path $Destination 'python.exe')
    if ($version -ne '3.10') { throw "The Python installation at $Destination reports version $version instead of 3.10." }
    Write-Ok "Python $($Dependency.version) installed at $Destination"
}

function Install-Venv {
    param([string]$PythonExe, [string]$Venv, [string]$Requirements)
    $venvPython = Join-Path $Venv 'Scripts\python.exe'
    if ($Force -and (Test-Path -LiteralPath $Venv)) {
        Reset-Directory -Path $Venv -Marker 'pyvenv.cfg' -Description 'a virtual environment'
    }
    if (-not (Test-Path -LiteralPath $venvPython)) {
        Write-Info "Creating the virtual environment at $Venv"
        & $PythonExe -m venv $Venv
        if ($LASTEXITCODE -ne 0) { throw "python -m venv exited with code $LASTEXITCODE" }
    }
    $requirementsHash = Get-FileHashValue -Path $Requirements -Algorithm 'SHA256'
    $marker = Join-Path $Venv '.spark-lab-requirements.sha256'
    $installedHash = ''
    if (Test-Path -LiteralPath $marker) { $installedHash = (Get-Content -LiteralPath $marker -Raw).Trim() }
    if ($installedHash -ne $requirementsHash -or $Force) {
        Write-Info 'Installing the Python packages (this can take a few minutes)'
        & $venvPython -m pip install --disable-pip-version-check --no-input --no-warn-script-location -r $Requirements
        if ($LASTEXITCODE -ne 0) { throw "pip install exited with code $LASTEXITCODE" }
        Set-Content -LiteralPath $marker -Value $requirementsHash -Encoding ASCII
        Write-Ok 'Python packages installed'
    } else {
        Write-Ok 'Python packages already up to date'
    }
}

function Update-UserEnvironment {
    param([string]$SparkHome, [string]$HadoopHome, [string]$JavaHome)
    if ($NoUserEnv) {
        Write-Info 'Skipping HKCU environment changes because -NoUserEnv was set.'
        return $false
    }
    $backup = Backup-UserEnvironment -ProjectRoot $ProjectRoot
    Write-Info "Environment backup written to $backup"
    [Environment]::SetEnvironmentVariable('SPARK_HOME', $SparkHome, 'User')
    [Environment]::SetEnvironmentVariable('HADOOP_HOME', $HadoopHome, 'User')
    $currentJava = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')
    if ([string]::IsNullOrWhiteSpace($currentJava)) {
        [Environment]::SetEnvironmentVariable('JAVA_HOME', $JavaHome, 'User')
        Write-Ok 'JAVA_HOME was empty, so the lab JDK was registered.'
    } elseif ($currentJava.TrimEnd('\') -ne $JavaHome.TrimEnd('\')) {
        Write-Warn "Keeping the existing JAVA_HOME ($currentJava). run.ps1 uses the lab JDK only for Spark."
    }
    $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    $merged = Merge-PathEntries -CurrentPath $userPath -Entries @('%SPARK_HOME%\bin', '%HADOOP_HOME%\bin')
    [Environment]::SetEnvironmentVariable('PATH', $merged, 'User')
    Write-Ok 'User PATH updated with the Spark and Hadoop entries.'
    return $true
}

$startedAt = Get-Date
$script:OfflineMode = [bool]$Offline

Write-Step 'Preflight'
Write-Info "PowerShell $($PSVersionTable.PSVersion) on $([System.Environment]::OSVersion.VersionString)"
if (Test-IsAdmin) {
    Write-Info 'Running with administrator rights.'
} else {
    Write-Info 'Running as a standard user. The installer will fall back to %LOCALAPPDATA% if C:\ is not writable.'
}

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
}
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\')
if (-not (Test-Path -LiteralPath $ProjectRoot)) { throw "The project root does not exist: $ProjectRoot" }
$requirements = Join-Path $ProjectRoot 'install\requirements.txt'
if (-not (Test-Path -LiteralPath $requirements)) { throw "Missing requirements file: $requirements" }

$dependencies = Read-JsonFile -Path (Join-Path $PSScriptRoot 'dependencies.json')
$layout = $dependencies.layout

if ([string]::IsNullOrWhiteSpace($FallbackRoot)) {
    $FallbackRoot = [System.Environment]::ExpandEnvironmentVariables($layout.fallbackRoot)
}
$FallbackRoot = [System.IO.Path]::GetFullPath($FallbackRoot)

$preferredRoot = [System.IO.Path]::GetFullPath($UserRoot)
if (Test-PathWritable -Path $preferredRoot) {
    $installRoot = $preferredRoot
} else {
    Write-Warn "$preferredRoot is not writable. Using $FallbackRoot instead."
    $installRoot = $FallbackRoot
}

if ([string]::IsNullOrWhiteSpace($SparkHome)) { $SparkHome = Join-Path $installRoot $layout.sparkDir }
if ([string]::IsNullOrWhiteSpace($JavaHome)) { $JavaHome = Join-Path $installRoot $layout.javaDir }
if ([string]::IsNullOrWhiteSpace($HadoopHome)) { $HadoopHome = Join-Path $installRoot $layout.hadoopDir }
if ([string]::IsNullOrWhiteSpace($PythonHome)) { $PythonHome = Join-Path $ProjectRoot $layout.pythonDir }
if ([string]::IsNullOrWhiteSpace($VenvPath)) { $VenvPath = Join-Path $ProjectRoot $layout.venvDir }
if ([string]::IsNullOrWhiteSpace($CachePath)) { $CachePath = Join-Path $ProjectRoot $layout.cacheDir }

$javaExplicit = $PSBoundParameters.ContainsKey('JavaHome')
if (-not $javaExplicit -and -not $SkipJava -and -not $Force) {
    $existingJdk = Find-Jdk11
    if ($existingJdk) {
        $JavaHome = $existingJdk
        Write-Info "Found an existing JDK 11 at $existingJdk. It will be reused."
    }
}

$SparkHome = [System.IO.Path]::GetFullPath($SparkHome).TrimEnd('\')
$JavaHome = [System.IO.Path]::GetFullPath($JavaHome).TrimEnd('\')
$HadoopHome = [System.IO.Path]::GetFullPath($HadoopHome).TrimEnd('\')
$PythonHome = [System.IO.Path]::GetFullPath($PythonHome).TrimEnd('\')
$VenvPath = [System.IO.Path]::GetFullPath($VenvPath).TrimEnd('\')
$CachePath = [System.IO.Path]::GetFullPath($CachePath).TrimEnd('\')

$pathLabels = @(
    @{ Name = 'project root'; Path = $ProjectRoot },
    @{ Name = 'Spark home'; Path = $SparkHome },
    @{ Name = 'Java home'; Path = $JavaHome },
    @{ Name = 'Hadoop home'; Path = $HadoopHome },
    @{ Name = 'Python home'; Path = $PythonHome },
    @{ Name = 'virtual environment'; Path = $VenvPath },
    @{ Name = 'cache'; Path = $CachePath }
)
foreach ($entry in $pathLabels) {
    if (-not (Test-SafeWindowsPath -Path $entry.Path)) {
        throw "The $($entry.Name) contains a character that Windows command scripts cannot handle: $($entry.Path). Move the repository or pass another path without & | < > ^ % ! and run the installer again."
    }
    if (-not (Test-AsciiPath -Path $entry.Path)) {
        Write-Warn "The $($entry.Name) contains non ASCII characters: $($entry.Path)"
    }
}

Write-Step 'Resolved layout'
Write-Info "Project root : $ProjectRoot"
Write-Info "Install root : $installRoot"
Write-Info "Spark home   : $SparkHome"
Write-Info "Java home    : $JavaHome"
Write-Info "Hadoop home  : $HadoopHome"
Write-Info "Python home  : $PythonHome"
Write-Info "Virtual env  : $VenvPath"
Write-Info "Cache        : $CachePath"

$spaceNeeds = @(
    @{ Path = $installRoot; GB = 1.6 },
    @{ Path = $ProjectRoot; GB = 0.9 },
    @{ Path = $CachePath; GB = 0.6 }
)
$neededByDrive = @{}
foreach ($need in $spaceNeeds) {
    $drive = [System.IO.Path]::GetPathRoot([System.IO.Path]::GetFullPath($need.Path))
    if (-not $neededByDrive.ContainsKey($drive)) { $neededByDrive[$drive] = 0.0 }
    $neededByDrive[$drive] = $neededByDrive[$drive] + [double]$need.GB
}
foreach ($drive in $neededByDrive.Keys) {
    $free = Get-FreeSpaceGB -Path $drive
    if ($free -lt 0) {
        Write-Info "Free space on $drive could not be measured. The download will still be verified."
        continue
    }
    Write-Info ("Free space on {0} {1:N1} GB (needed {2:N1} GB)" -f $drive, $free, $neededByDrive[$drive])
    if ($free -lt $neededByDrive[$drive]) {
        throw "Not enough free space on $drive. Free at least $([math]::Round($neededByDrive[$drive], 1)) GB and try again."
    }
    if ($free -lt [double]$dependencies.space.recommendedGB) {
        Write-Warn "Less than $($dependencies.space.recommendedGB) GB free on $drive. The install will work but leave little headroom."
    }
}

if ($DryRun) {
    Write-Step 'Dry run summary'
    Write-Info 'No file was downloaded, extracted or written.'
    Write-Info ("Spark {0} from {1}" -f $dependencies.spark.version, $dependencies.spark.url)
    Write-Info ("JDK {0} from {1}" -f $dependencies.jdk.version, $dependencies.jdk.url)
    Write-Info ("Python {0} from {1}" -f $dependencies.python.version, $dependencies.python.url)
    Write-Info ("winutils {0} from {1}" -f $dependencies.hadoop.version, $dependencies.hadoop.git)
    if ($NoUserEnv) { Write-Info 'HKCU environment would not be modified.' }
    Write-Host ''
    Write-Ok 'Dry run completed.'
    exit 0
}

if (-not (Test-Path -LiteralPath $CachePath)) { New-Item -ItemType Directory -Force -Path $CachePath | Out-Null }

Write-Step 'Java Development Kit'
if ($SkipJava) {
    Write-Info 'Skipped because -SkipJava was set.'
} elseif (-not $Force -and (Get-JavaMajor -JavaExe (Join-Path $JavaHome 'bin\java.exe')) -eq 11) {
    Write-Ok "JDK 11 already present at $JavaHome"
} else {
    $jdkArchive = Get-Artifact -Url $dependencies.jdk.url -Artifact $dependencies.jdk.artifact -Cache $CachePath -Hash $dependencies.jdk.sha256 -Algorithm 'SHA256' -SizeBytes $dependencies.jdk.sizeBytes
    Install-JdkDistribution -Destination $JavaHome -Archive $jdkArchive -Cache $CachePath -Version $dependencies.jdk.version
}
if (Test-Path -LiteralPath (Join-Path $JavaHome 'bin\java.exe')) {
    $env:JAVA_HOME = $JavaHome
}

Write-Step 'Apache Spark'
$sparkMarker = Join-Path $SparkHome ('jars\spark-core_2.12-' + $dependencies.spark.version + '.jar')
if ($SkipSpark) {
    Write-Info 'Skipped because -SkipSpark was set.'
} elseif (-not $Force -and (Test-Path -LiteralPath $sparkMarker)) {
    Write-Ok "Spark $($dependencies.spark.version) already present at $SparkHome"
} else {
    $sparkArchive = Get-Artifact -Url $dependencies.spark.url -Artifact $dependencies.spark.artifact -Cache $CachePath -Hash $dependencies.spark.sha512 -Algorithm 'SHA512' -SizeBytes $dependencies.spark.sizeBytes
    Install-SparkDistribution -Destination $SparkHome -Archive $sparkArchive -Cache $CachePath -Version $dependencies.spark.version
}

Write-Step 'Hadoop winutils'
if ($SkipWinutils) {
    Write-Info 'Skipped because -SkipWinutils was set.'
} else {
    Install-WinutilsFiles -Destination $HadoopHome -Dependency $dependencies.hadoop -Cache $CachePath
}

Write-Step 'Python 3.10'
if ($SkipPython) {
    Write-Info 'Skipped because -SkipPython was set.'
} else {
    $pythonExisting = Find-Python310
    if ($pythonExisting -and -not $Force) {
        $existingVersion = Get-PythonVersion -PythonExe $pythonExisting
        Write-Info "A Python $existingVersion interpreter was found at $pythonExisting"
        Write-Info "The lab keeps its own interpreter at $PythonHome to stay independent from other courses."
    }
    $localPython = Join-Path $PythonHome 'python.exe'
    if (-not $Force -and (Get-PythonVersion -PythonExe $localPython) -eq '3.10') {
        Write-Ok "Python 3.10 already present at $PythonHome"
    } else {
        $pythonArchive = Get-Artifact -Url $dependencies.python.url -Artifact $dependencies.python.artifact -Cache $CachePath -Hash $dependencies.python.sha256 -Algorithm 'SHA256' -SizeBytes $dependencies.python.sizeBytes
        Install-PythonRuntime -Destination $PythonHome -Archive $pythonArchive -Cache $CachePath -Dependency $dependencies.python
    }
    Install-Venv -PythonExe $localPython -Venv $VenvPath -Requirements $requirements
}

Write-Step 'Process environment'
if (Test-Path -LiteralPath (Join-Path $JavaHome 'bin\java.exe')) { $env:JAVA_HOME = $JavaHome }
if (Test-Path -LiteralPath $SparkHome) { $env:SPARK_HOME = $SparkHome }
if (Test-Path -LiteralPath $HadoopHome) { $env:HADOOP_HOME = $HadoopHome }
$processPrefix = @(
    (Join-Path $JavaHome 'bin'),
    (Join-Path $SparkHome 'bin'),
    (Join-Path $HadoopHome 'bin'),
    (Join-Path $VenvPath 'Scripts')
)
$env:PATH = ($processPrefix -join ';') + ';' + $env:PATH

$sparkReported = $null
if (-not $SkipSpark -and (Test-Path -LiteralPath (Join-Path $SparkHome 'bin\spark-submit.cmd'))) {
    Write-Info 'Checking spark-submit with the lab JDK'
    $sparkReported = Get-SparkVersion -SparkHome $SparkHome
    if ($sparkReported -ne $dependencies.spark.version) {
        throw "spark-submit reported '$sparkReported' instead of $($dependencies.spark.version). Check that $JavaHome contains JDK 11."
    }
    Write-Ok "spark-submit reports Spark $sparkReported"
}

Write-Step 'Environment file'
$envFile = Join-Path $ProjectRoot 'install\spark-env.ps1'
New-SparkEnvFile -Path $envFile -JavaHome $JavaHome -SparkHome $SparkHome -HadoopHome $HadoopHome -VenvPath $VenvPath
Write-Ok "Wrote $envFile"

Write-Step 'User environment'
$userEnvModified = Update-UserEnvironment -SparkHome $SparkHome -HadoopHome $HadoopHome -JavaHome $JavaHome

Write-Step 'Install state'
$state = [ordered]@{
    schemaVersion = 1
    installedAt = (Get-Date).ToString('o')
    durationSeconds = [math]::Round(((Get-Date) - $startedAt).TotalSeconds, 1)
    projectRoot = $ProjectRoot
    installRoot = $installRoot
    spark = [ordered]@{
        version = $dependencies.spark.version
        home = $SparkHome
        reported = $sparkReported
        sha512 = $dependencies.spark.sha512
    }
    java = [ordered]@{
        version = $dependencies.jdk.version
        major = 11
        home = $JavaHome
        sha256 = $dependencies.jdk.sha256
    }
    hadoop = [ordered]@{
        version = $dependencies.hadoop.version
        home = $HadoopHome
        commit = $dependencies.hadoop.commit
    }
    python = [ordered]@{
        version = $dependencies.python.version
        home = $PythonHome
        sha256 = $dependencies.python.sha256
    }
    venv = [ordered]@{
        path = $VenvPath
        requirementsSha256 = (Get-FileHashValue -Path $requirements -Algorithm 'SHA256')
    }
    userEnvironmentModified = $userEnvModified
    cache = $CachePath
}
$statePath = Write-InstallState -ProjectRoot $ProjectRoot -State $state
Write-Ok "Wrote $statePath"

Write-Step 'Installation complete'
Write-Host ''
Write-Info 'Next steps:'
Write-Info '  1. Open a new terminal so the updated user PATH is visible.'
Write-Info '  2. Run: .\install\verify-install.ps1'
Write-Info '  3. Run: .\install\run.ps1 status'
Write-Info '  4. Run: .\install\run.ps1 pyspark'
Write-Host ''
Write-Info 'The machine wide Java installation was not modified. run.ps1 uses JDK 11 only for Spark.'
exit 0
