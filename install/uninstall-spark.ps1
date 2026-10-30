#Requires -Version 5.1
<#
.SYNOPSIS
    Removes the Spark laboratory environment from the current user.

.DESCRIPTION
    Restores the HKCU variables from install\env-backup.json and deletes the generated files. The downloaded binaries stay in place unless -Purge is used together with -Confirmed.

.PARAMETER Purge
    Delete the Spark, JDK, winutils, Python and virtual environment directories.

.PARAMETER Confirmed
    Required together with -Purge. Confirms that the directories may be deleted.

.EXAMPLE
    .\install\uninstall-spark.ps1

.EXAMPLE
    .\install\uninstall-spark.ps1 -Purge -Confirmed
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot = '',
    [switch]$Purge,
    [switch]$Confirmed
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib\Installer.ps1')

trap {
    Write-Fail $_.Exception.Message
    exit 1
}

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
}
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\')

if ($Purge -and -not $Confirmed) {
    Write-Fail 'Purge deletes downloaded binaries and the virtual environment.'
    Write-Info 'Run the script again with -Purge -Confirmed if that is what you want.'
    exit 2
}

$dependencies = Read-JsonFile -Path (Join-Path $PSScriptRoot 'dependencies.json')
$layout = $dependencies.layout
$state = Read-InstallState -ProjectRoot $ProjectRoot

if ($state) {
    $SparkHome = $state.spark.home
    $JavaHome = $state.java.home
    $HadoopHome = $state.hadoop.home
    $PythonHome = $state.python.home
    $VenvPath = $state.venv.path
    $CachePath = $state.cache
} else {
    $localRoot = [System.Environment]::ExpandEnvironmentVariables($layout.fallbackRoot)
    $SparkHome = Join-Path $localRoot $layout.sparkDir
    $JavaHome = Join-Path $localRoot $layout.javaDir
    $HadoopHome = Join-Path $localRoot $layout.hadoopDir
    $PythonHome = Join-Path $ProjectRoot $layout.pythonDir
    $VenvPath = Join-Path $ProjectRoot $layout.venvDir
    $CachePath = Join-Path $ProjectRoot $layout.cacheDir
}

Write-Step 'Restoring the user environment'
$backupPath = Join-Path $ProjectRoot 'install\env-backup.json'
$restored = $false
if (Test-Path -LiteralPath $backupPath) {
    $backup = Read-JsonFile -Path $backupPath
    $names = @($backup.values.PSObject.Properties.Name)
    foreach ($name in $names) {
        if ($name -eq 'PATH') { continue }
        $oldValue = $backup.values.$name
        $currentValue = [Environment]::GetEnvironmentVariable($name, 'User')
        if ($currentValue -eq $oldValue) { continue }
        [Environment]::SetEnvironmentVariable($name, $oldValue, 'User')
        Write-Info "Restored $name"
    }
    $currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    if (-not [string]::IsNullOrWhiteSpace($currentPath)) {
        $kept = New-Object System.Collections.Generic.List[string]
        foreach ($entry in ($currentPath -split ';')) {
            if ([string]::IsNullOrWhiteSpace($entry)) { continue }
            $clean = $entry.Trim().TrimEnd('\')
            if ($clean -ieq '%SPARK_HOME%\bin') { continue }
            if ($clean -ieq '%HADOOP_HOME%\bin') { continue }
            if ($clean -ieq ($SparkHome + '\bin')) { continue }
            if ($clean -ieq ($HadoopHome + '\bin')) { continue }
            $kept.Add($entry)
        }
        [Environment]::SetEnvironmentVariable('PATH', ($kept -join ';'), 'User')
    }
    Remove-Item -LiteralPath $backupPath -Force
    $restored = $true
    Write-Ok 'User environment restored from the backup.'
} else {
    Write-Info 'No environment backup was found. Nothing to restore.'
}

Write-Step 'Removing generated files'
foreach ($file in @('spark-env.ps1', 'install-state.json')) {
    $path = Join-Path $ProjectRoot ('install\' + $file)
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force
        Write-Ok "Removed $file"
    }
}

if (-not $Purge) {
    Write-Step 'Uninstall complete'
    Write-Info 'The downloaded binaries, the virtual environment and the cache were kept.'
    Write-Info 'Run the script again with -Purge -Confirmed to delete them as well.'
    exit 0
}

Write-Step 'Removing installed components'
if (-not (Test-IsAdmin)) {
    Write-Info 'Running as a standard user. Only user level directories can be removed.'
}

$pythonInstaller = Join-Path $CachePath $dependencies.python.artifact
if ((Test-Path -LiteralPath $pythonInstaller) -and (Test-Path -LiteralPath (Join-Path $PythonHome 'python.exe'))) {
    Write-Info 'Running the Python uninstaller'
    $process = Start-Process -FilePath $pythonInstaller -ArgumentList @('/uninstall', '/quiet') -Wait -PassThru
    if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
        Write-Warn "The Python uninstaller exited with code $($process.ExitCode). The directory will be removed anyway."
    }
}

$targets = @(
    @{ Path = $VenvPath; Label = 'virtual environment' },
    @{ Path = $PythonHome; Label = 'Python' },
    @{ Path = $SparkHome; Label = 'Spark' },
    @{ Path = $JavaHome; Label = 'JDK' },
    @{ Path = $HadoopHome; Label = 'winutils' },
    @{ Path = $CachePath; Label = 'download cache' }
)
foreach ($target in $targets) {
    if ([string]::IsNullOrWhiteSpace($target.Path)) { continue }
    if (-not (Test-Path -LiteralPath $target.Path)) {
        Write-Info "Already absent: $($target.Path)"
        continue
    }
    try {
        Remove-SafeDirectory -Path $target.Path
        Write-Ok "Removed the $($target.Label) at $($target.Path)"
    } catch {
        Write-Warn "Could not remove $($target.Path): $($_.Exception.Message)"
    }
}

$toolsDir = Join-Path $ProjectRoot '.tools'
if ((Test-Path -LiteralPath $toolsDir) -and -not (Get-ChildItem -LiteralPath $toolsDir -Force -ErrorAction SilentlyContinue)) {
    Remove-Item -LiteralPath $toolsDir -Force
}

Write-Step 'Uninstall complete'
if ($restored) {
    Write-Info 'Open a new terminal so the restored user environment is visible.'
}
exit 0
