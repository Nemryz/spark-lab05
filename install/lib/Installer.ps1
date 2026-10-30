# Shared helpers for the Spark lab installer, written so Windows PowerShell 5.1 can read the file without depending on the console code page.

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Info {
    param([string]$Message)
    Write-Host "    $Message"
}

function Write-Ok {
    param([string]$Message)
    Write-Host "  OK  $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  !!  $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Message)
    Write-Host "  XX  $Message" -ForegroundColor Red
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-AsciiPath {
    param([string]$Path)
    if ([string]::IsNullOrEmpty($Path)) { return $false }
    return ($Path -notmatch '[^\x00-\x7F]')
}

function Test-PathWritable {
    param([string]$Path)
    try {
        if (Test-Path -LiteralPath $Path) {
            $probe = Join-Path $Path ("spark-write-test-" + [Guid]::NewGuid().ToString("N") + ".tmp")
            Set-Content -LiteralPath $probe -Value "x" -ErrorAction Stop
            Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
            return $true
        }
        $parent = Split-Path -Parent $Path
        if ([string]::IsNullOrEmpty($parent) -or -not (Test-Path -LiteralPath $parent)) { return $false }
        $probeDir = Join-Path $parent ("spark-write-test-" + [Guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $probeDir -ErrorAction Stop | Out-Null
        Remove-Item -LiteralPath $probeDir -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        return $false
    }
}

function Resolve-WritableHome {
    param([string]$Preferred, [string]$Fallback)
    if (Test-PathWritable -Path $Preferred) { return $Preferred }
    Write-Warn "Cannot write to $Preferred; using $Fallback"
    return $Fallback
}

function Get-FreeSpaceGB {
    param([string]$Path)
    try {
        $full = [System.IO.Path]::GetFullPath($Path)
        $root = [System.IO.Path]::GetPathRoot($full)
        if ($root.StartsWith('\\')) { return -1 }
        $drive = New-Object -TypeName System.IO.DriveInfo -ArgumentList $root
        return [math]::Round($drive.AvailableFreeSpace / 1GB, 1)
    } catch {
        return -1
    }
}

function Test-SafeWindowsPath {
    param([string]$Path)
    if ([string]::IsNullOrEmpty($Path)) { return $false }
    return ($Path -notmatch '[&|<>^%!]')
}

function Get-JavaMajor {
    param([string]$JavaExe)
    if ([string]::IsNullOrWhiteSpace($JavaExe)) { return $null }
    if (-not (Test-Path -LiteralPath $JavaExe)) { return $null }
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = ''
    try {
        $output = (& $JavaExe -version 2>&1 | Out-String)
    } catch {
        $output = ''
    } finally {
        $ErrorActionPreference = $previous
    }
    if ($output -match 'version "(\d+)(?:\.(\d+))?') {
        $major = [int]$Matches[1]
        if ($major -eq 1 -and $Matches[2]) { $major = [int]$Matches[2] }
        return $major
    }
    return $null
}

function Find-Jdk11 {
    $candidates = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($env:JAVA_HOME)) {
        $candidates.Add((Join-Path $env:JAVA_HOME 'bin\java.exe'))
    }
    $javaCmd = Get-Command java.exe -ErrorAction SilentlyContinue
    if ($javaCmd) { $candidates.Add($javaCmd.Source) }
    if (-not [string]::IsNullOrWhiteSpace($env:SystemDrive)) {
        $candidates.Add((Join-Path $env:SystemDrive 'jdk\bin\java.exe'))
    }
    $bases = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
        $bases.Add((Join-Path $env:ProgramFiles 'Eclipse Adoptium'))
        $bases.Add((Join-Path $env:ProgramFiles 'Java'))
        $bases.Add((Join-Path $env:ProgramFiles 'Microsoft'))
    }
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $bases.Add((Join-Path $env:LOCALAPPDATA 'Programs\Eclipse Adoptium'))
    }
    foreach ($base in $bases) {
        if (Test-Path -LiteralPath $base) {
            $dirs = Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue
            foreach ($dir in $dirs) {
                $candidates.Add((Join-Path $dir.FullName 'bin\java.exe'))
            }
        }
    }
    foreach ($candidate in $candidates) {
        $major = Get-JavaMajor -JavaExe $candidate
        if ($major -eq 11) {
            return (Split-Path -Parent (Split-Path -Parent $candidate))
        }
    }
    return $null
}

function Get-FileHashValue {
    param([string]$Path, [string]$Algorithm = 'SHA256')
    return (Get-FileHash -LiteralPath $Path -Algorithm $Algorithm).Hash.ToLowerInvariant()
}

function Invoke-Download {
    param(
        [string]$Url,
        [string]$Destination,
        [string]$ExpectedHash = '',
        [string]$Algorithm = 'SHA256',
        [int]$Retries = 3
    )
    $parent = Split-Path -Parent $Destination
    if (-not [string]::IsNullOrEmpty($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    if (Test-Path -LiteralPath $Destination) {
        if ([string]::IsNullOrWhiteSpace($ExpectedHash)) {
            if ((Get-Item -LiteralPath $Destination).Length -gt 0) { return }
        } else {
            $actual = Get-FileHashValue -Path $Destination -Algorithm $Algorithm
            if ($actual -eq $ExpectedHash.ToLowerInvariant()) { return }
            Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
        }
    }
    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    for ($attempt = 1; $attempt -le $Retries; $attempt++) {
        try {
            Write-Info "Downloading $Url (attempt $attempt/$Retries)"
            if ($curl) {
                & $curl.Source @('--location', '--fail', '--silent', '--show-error', '--retry', '2', '--retry-delay', '3', '--output', $Destination, $Url)
                if ($LASTEXITCODE -ne 0) { throw "curl.exe failed with exit code $LASTEXITCODE" }
            } else {
                Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -TimeoutSec 900
            }
            if (-not [string]::IsNullOrWhiteSpace($ExpectedHash)) {
                $actual = Get-FileHashValue -Path $Destination -Algorithm $Algorithm
                if ($actual -ne $ExpectedHash.ToLowerInvariant()) {
                    Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
                    throw "Checksum mismatch for $Destination"
                }
            }
            return
        } catch {
            if ($attempt -eq $Retries) { throw }
            Write-Warn "Download failed: $($_.Exception.Message). Retrying in $((5 * $attempt)) seconds."
            Start-Sleep -Seconds (5 * $attempt)
        }
    }
}

function Expand-TarGz {
    param([string]$Archive, [string]$Destination)
    if (-not (Test-Path -LiteralPath $Destination)) {
        New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    }
    $tar = Get-Command tar.exe -ErrorAction SilentlyContinue
    if (-not $tar) { throw 'tar.exe was not found. Windows 10 1803 or newer is required.' }
    & $tar.Source -xzf $Archive -C $Destination | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "tar.exe failed with exit code $LASTEXITCODE" }
}

function Expand-ZipArchive {
    param([string]$Archive, [string]$Destination)
    if (-not (Test-Path -LiteralPath $Destination)) {
        New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    }
    $tar = Get-Command tar.exe -ErrorAction SilentlyContinue
    if ($tar) {
        & $tar.Source -xf $Archive -C $Destination | Out-Null
        if ($LASTEXITCODE -eq 0) { return }
    }
    Expand-Archive -LiteralPath $Archive -DestinationPath $Destination -Force
}

function Get-SingleChildDirectory {
    param([string]$Path)
    $dirs = @(Get-ChildItem -LiteralPath $Path -Directory -Force -ErrorAction SilentlyContinue)
    if ($dirs.Count -eq 1) { return $dirs[0].FullName }
    return $null
}

function Move-Contents {
    param([string]$Source, [string]$Destination)
    if (-not (Test-Path -LiteralPath $Destination)) {
        New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    }
    $items = Get-ChildItem -LiteralPath $Source -Force
    foreach ($item in $items) {
        Move-Item -LiteralPath $item.FullName -Destination $Destination -Force
    }
}

function Merge-PathEntries {
    param([string]$CurrentPath, [string[]]$Entries)
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $result = New-Object 'System.Collections.Generic.List[string]'
    $all = New-Object 'System.Collections.Generic.List[string]'
    if ($null -ne $Entries) {
        foreach ($entry in $Entries) { $all.Add($entry) }
    }
    if (-not [string]::IsNullOrWhiteSpace($CurrentPath)) {
        foreach ($entry in ($CurrentPath -split ';')) { $all.Add($entry) }
    }
    foreach ($entry in $all) {
        if ([string]::IsNullOrWhiteSpace($entry)) { continue }
        $clean = $entry.Trim().TrimEnd('\')
        if ([string]::IsNullOrEmpty($clean)) { continue }
        if ($seen.Add($clean)) { $result.Add($clean) }
    }
    return ($result -join ';')
}

function Write-Utf8BomFile {
    param([string]$Path, [string]$Content)
    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrEmpty($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $encoding = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Backup-UserEnvironment {
    param([string]$ProjectRoot)
    $dir = Join-Path $ProjectRoot 'install'
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    $file = Join-Path $dir 'env-backup.json'
    if (Test-Path -LiteralPath $file) { return $file }
    $names = @('SPARK_HOME', 'HADOOP_HOME', 'JAVA_HOME', 'SPARK_JAVA_HOME', 'PYSPARK_PYTHON', 'PYSPARK_DRIVER_PYTHON', 'PATH')
    $data = [ordered]@{ createdAt = (Get-Date).ToString('o'); values = [ordered]@{} }
    foreach ($name in $names) {
        $data.values[$name] = [Environment]::GetEnvironmentVariable($name, 'User')
    }
    ($data | ConvertTo-Json -Depth 5) | ForEach-Object { Write-Utf8BomFile -Path $file -Content $_ }
    return $file
}

function Set-UserEnvironmentVariable {
    param([string]$Name, [string]$Value)
    [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
}

function Remove-UserEnvironmentVariable {
    param([string]$Name)
    [Environment]::SetEnvironmentVariable($Name, $null, 'User')
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Missing JSON file: $Path" }
    return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

function Invoke-CommandCapture {
    param(
        [string]$FilePath,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory = ''
    )
    $oldPath = (Get-Location).Path
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
        Set-Location -LiteralPath $WorkingDirectory
    }
    try {
        $output = & $FilePath @Arguments 2>&1 | Out-String
        $code = $LASTEXITCODE
        if ($null -eq $code) { $code = 0 }
        return [pscustomobject]@{
            ExitCode = $code
            Output = $output.Trim()
        }
    } finally {
        $ErrorActionPreference = $previous
        Set-Location -LiteralPath $oldPath
    }
}

function Get-PythonVersion {
    param([string]$PythonExe)
    if (-not (Test-Path -LiteralPath $PythonExe)) { return $null }
    $result = Invoke-CommandCapture -FilePath $PythonExe -Arguments @('--version')
    if ($result.ExitCode -ne 0) { return $null }
    if ($result.Output -match 'Python\s+(\d+)\.(\d+)') { return "$($Matches[1]).$($Matches[2])" }
    return $null
}

function Find-Python310 {
    $candidates = New-Object System.Collections.Generic.List[string]
    $py = Get-Command py.exe -ErrorAction SilentlyContinue
    if ($py) {
        $result = Invoke-CommandCapture -FilePath $py.Source -Arguments @('-3.10', '-c', 'import sys; print(sys.executable)')
        if ($result.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($result.Output)) {
            $candidates.Add($result.Output.Trim())
        }
    }
    $python = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($python) { $candidates.Add($python.Source) }
    if (-not [string]::IsNullOrWhiteSpace($env:SystemDrive)) {
        $candidates.Add((Join-Path $env:SystemDrive 'Python310\python.exe'))
    }
    if (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
        $candidates.Add((Join-Path $env:ProgramFiles 'Python310\python.exe'))
    }
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $candidates.Add((Join-Path $env:LOCALAPPDATA 'Programs\Python\Python310\python.exe'))
    }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            $version = Get-PythonVersion -PythonExe $candidate
            if ($version -eq '3.10') { return $candidate }
        }
    }
    return $null
}

function Get-SparkVersion {
    param([string]$SparkHome)
    $submit = Join-Path $SparkHome 'bin\spark-submit.cmd'
    if (-not (Test-Path -LiteralPath $submit)) { return $null }
    $result = Invoke-CommandCapture -FilePath $submit -Arguments @('--version')
    if ($result.ExitCode -ne 0) { return $null }
    if ($result.Output -match 'version\s+([0-9]+\.[0-9]+\.[0-9]+)') {
        return $Matches[1]
    }
    return $null
}

function Test-PortFree {
    param([int]$Port)
    try {
        $listeners = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop)
        return ($listeners.Count -eq 0)
    } catch {
        return $true
    }
}

function Test-LongPathsEnabled {
    try {
        $item = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -ErrorAction Stop
        return ($item.LongPathsEnabled -eq 1)
    } catch {
        return $false
    }
}

function Remove-SafeDirectory {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    $full = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    $root = [System.IO.Path]::GetPathRoot($full).TrimEnd('\')
    if ($full -eq $root) { throw "Refusing to remove a drive root: $full" }
    $leaf = Split-Path -Leaf $full
    $allowed = @('spark', 'winutils', 'jdk', 'python310', '.venv', '.tools', 'cache')
    if ($allowed -notcontains $leaf) { throw "Refusing to remove an unexpected directory: $full" }
    if (Test-Path -LiteralPath $full) {
        Remove-Item -LiteralPath $full -Recurse -Force
    }
}

function Write-InstallState {
    param([string]$ProjectRoot, $State)
    $path = Join-Path $ProjectRoot 'install\install-state.json'
    Write-Utf8BomFile -Path $path -Content ($State | ConvertTo-Json -Depth 6)
    return $path
}

function Read-InstallState {
    param([string]$ProjectRoot)
    $path = Join-Path $ProjectRoot 'install\install-state.json'
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    return (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
}

function New-SparkEnvFile {
    param(
        [string]$Path,
        [string]$JavaHome,
        [string]$SparkHome,
        [string]$HadoopHome,
        [string]$VenvPath
    )
    $python = Join-Path $VenvPath 'Scripts\python.exe'
    $javaBin = Join-Path $JavaHome 'bin'
    $sparkBin = Join-Path $SparkHome 'bin'
    $hadoopBin = Join-Path $HadoopHome 'bin'
    $venvBin = Join-Path $VenvPath 'Scripts'
    $pythonPath = Join-Path $SparkHome 'python'
    $libDir = Join-Path $SparkHome 'python\lib'
    if (Test-Path -LiteralPath $libDir) {
        $py4j = Get-ChildItem -LiteralPath $libDir -Filter 'py4j-*.zip' -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($py4j) { $pythonPath = $pythonPath + ';' + $py4j.FullName }
    }
    $safeJava = $JavaHome.Replace("'", "''")
    $safeSpark = $SparkHome.Replace("'", "''")
    $safeHadoop = $HadoopHome.Replace("'", "''")
    $safeVenv = $VenvPath.Replace("'", "''")
    $safePython = $python.Replace("'", "''")
    $safePythonPath = $pythonPath.Replace("'", "''")
    $managed = @($javaBin, $sparkBin, $hadoopBin, $venvBin)
    $managedLiteral = ($managed | ForEach-Object { "'" + $_.Replace("'", "''") + "'" }) -join ', '
    $pathPrefix = ($managed | ForEach-Object { $_.Replace("'", "''") }) -join ';'
    $lines = @(
        '# Generated by install-spark.ps1. Do not edit by hand.',
        '# Dot-source this file to prepare the current process for Spark.',
        ('$sparkLabManaged = @(' + $managedLiteral + ')'),
        ('$env:JAVA_HOME = ''' + $safeJava + ''''),
        ('$env:SPARK_HOME = ''' + $safeSpark + ''''),
        ('$env:HADOOP_HOME = ''' + $safeHadoop + ''''),
        ('$env:SPARK_LAB_VENV = ''' + $safeVenv + ''''),
        ('$env:PYSPARK_PYTHON = ''' + $safePython + ''''),
        ('$env:PYSPARK_DRIVER_PYTHON = $env:PYSPARK_PYTHON'),
        ('$env:PYTHONPATH = ''' + $safePythonPath + ''''),
        ('$env:SPARK_LOCAL_IP = ''127.0.0.1'''),
        ('$env:PYTHONIOENCODING = ''utf-8'''),
        ('$env:PYSPARK_SUBMIT_ARGS = ''--driver-memory 1g --conf spark.driver.extraJavaOptions=-Xms64m pyspark-shell'''),
        ('$env:PATH = (($env:PATH -split '';'') | Where-Object { $_ -and ($sparkLabManaged -notcontains $_.TrimEnd(''\'')) }) -join '';'''),
        ('$env:PATH = ''' + $pathPrefix + ';'' + $env:PATH')
    )
    Write-Utf8BomFile -Path $Path -Content (($lines -join [Environment]::NewLine) + [Environment]::NewLine)
}
