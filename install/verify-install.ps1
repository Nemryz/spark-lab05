#Requires -Version 5.1
<#
.SYNOPSIS
    Verifies that the Spark laboratory environment is usable.

.DESCRIPTION
    Runs twelve checks against the generated environment file, the downloaded binaries, the virtual environment and a real Spark job. Exits with code 1 when any check fails. Warnings do not change the exit code.

.PARAMETER ProjectRoot
    Repository root. Defaults to the parent directory of this script.

.PARAMETER Json
    Emit a machine readable report instead of a table.

.PARAMETER SkipSmoke
    Skip the Spark job and the Spark UI checks.

.PARAMETER TimeoutSeconds
    Maximum time allowed for the smoke test. Defaults to 240 seconds.

.EXAMPLE
    .\install\verify-install.ps1

.EXAMPLE
    .\install\verify-install.ps1 -Json
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot = '',
    [switch]$Json,
    [switch]$SkipSmoke,
    [int]$TimeoutSeconds = 240
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib\Installer.ps1')

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
}
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\')

$results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param([string]$Name, [string]$Status, [string]$Detail)
    $results.Add([pscustomobject]@{
        check = $Name
        status = $Status
        detail = $Detail
    })
}

function Complete-Report {
    $passed = @($results | Where-Object { $_.status -eq 'PASS' }).Count
    $warned = @($results | Where-Object { $_.status -eq 'WARN' }).Count
    $failed = @($results | Where-Object { $_.status -eq 'FAIL' }).Count
    $ok = ($failed -eq 0)
    if ($Json) {
        $payload = [ordered]@{
            ok = $ok
            projectRoot = $ProjectRoot
            checkedAt = (Get-Date).ToString('o')
            passed = $passed
            warnings = $warned
            failed = $failed
            checks = $results
        }
        Write-Host ($payload | ConvertTo-Json -Depth 5)
    } else {
        Write-Host ''
        $results | Format-Table -AutoSize @{ Label = 'Check'; Expression = { $_.check } }, @{ Label = 'Status'; Expression = { $_.status } }, @{ Label = 'Detail'; Expression = { $_.detail } }
        $summary = "{0} checks: {1} passed, {2} warnings, {3} failed" -f $results.Count, $passed, $warned, $failed
        if ($ok) {
            Write-Ok $summary
        } else {
            Write-Fail $summary
        }
    }
    if (-not $ok) { exit 1 }
    exit 0
}

$envFile = Join-Path $ProjectRoot 'install\spark-env.ps1'
if (-not (Test-Path -LiteralPath $envFile)) {
    Add-Result -Name 'env-file' -Status 'FAIL' -Detail "Missing $envFile. Run install\install-spark.ps1 first."
    Complete-Report
}
. $envFile
Add-Result -Name 'env-file' -Status 'PASS' -Detail 'install\spark-env.ps1 was loaded.'

$statePath = Join-Path $ProjectRoot 'install\install-state.json'
if (Test-Path -LiteralPath $statePath) {
    $state = Read-JsonFile -Path $statePath
    Add-Result -Name 'install-state' -Status 'PASS' -Detail ("Installed at {0}" -f $state.installedAt)
} else {
    $state = $null
    Add-Result -Name 'install-state' -Status 'WARN' -Detail 'install\install-state.json is missing.'
}

$dependencies = Read-JsonFile -Path (Join-Path $PSScriptRoot 'dependencies.json')

$javaExe = Join-Path $env:JAVA_HOME 'bin\java.exe'
$javaMajor = Get-JavaMajor -JavaExe $javaExe
if ($javaMajor -eq 11) {
    Add-Result -Name 'java-11' -Status 'PASS' -Detail "$env:JAVA_HOME reports Java 11."
} else {
    Add-Result -Name 'java-11' -Status 'FAIL' -Detail "$javaExe does not report Java 11."
}

$sparkSubmit = Join-Path $env:SPARK_HOME 'bin\spark-submit.cmd'
$sparkCore = Join-Path $env:SPARK_HOME ('jars\spark-core_2.12-' + $dependencies.spark.version + '.jar')
if ((Test-Path -LiteralPath $sparkSubmit) -and (Test-Path -LiteralPath $sparkCore)) {
    Add-Result -Name 'spark-files' -Status 'PASS' -Detail "Spark $($dependencies.spark.version) files are present."
} else {
    Add-Result -Name 'spark-files' -Status 'FAIL' -Detail 'spark-submit.cmd or the Spark core jar is missing.'
}

if (Test-Path -LiteralPath $sparkSubmit) {
    $reported = Get-SparkVersion -SparkHome $env:SPARK_HOME
    if ($reported -eq $dependencies.spark.version) {
        Add-Result -Name 'spark-version' -Status 'PASS' -Detail "spark-submit reports $reported."
    } else {
        Add-Result -Name 'spark-version' -Status 'FAIL' -Detail "spark-submit reported '$reported' instead of $($dependencies.spark.version)."
    }
} else {
    Add-Result -Name 'spark-version' -Status 'FAIL' -Detail 'spark-submit.cmd is missing.'
}

$hadoopOk = $true
$hadoopDetail = New-Object System.Collections.Generic.List[string]
foreach ($file in $dependencies.hadoop.files) {
    $target = Join-Path (Join-Path $env:HADOOP_HOME 'bin') $file.name
    if (-not (Test-Path -LiteralPath $target)) {
        $hadoopOk = $false
        $hadoopDetail.Add("$($file.name) is missing")
        continue
    }
    $actual = Get-FileHashValue -Path $target -Algorithm 'SHA256'
    if ($actual -ne $file.sha256) {
        $hadoopOk = $false
        $hadoopDetail.Add("$($file.name) has a wrong checksum")
    }
}
if ($hadoopOk) {
    Add-Result -Name 'hadoop-files' -Status 'PASS' -Detail 'winutils.exe and hadoop.dll match their checksums.'
} else {
    Add-Result -Name 'hadoop-files' -Status 'FAIL' -Detail ($hadoopDetail -join '; ')
}

$winutils = Join-Path (Join-Path $env:HADOOP_HOME 'bin') 'winutils.exe'
if (Test-Path -LiteralPath $winutils) {
    $probe = Join-Path $env:TEMP ('spark-winutils-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $probe | Out-Null
    $run = Invoke-CommandCapture -FilePath $winutils -Arguments @('ls', $probe) -WorkingDirectory $probe
    Remove-Item -LiteralPath $probe -Recurse -Force -ErrorAction SilentlyContinue
    if ($run.ExitCode -eq 0) {
        Add-Result -Name 'winutils-run' -Status 'PASS' -Detail 'winutils.exe executed against a temporary directory.'
    } else {
        Add-Result -Name 'winutils-run' -Status 'FAIL' -Detail "winutils.exe exited with code $($run.ExitCode). $($run.Output)"
    }
} else {
    Add-Result -Name 'winutils-run' -Status 'FAIL' -Detail 'winutils.exe is missing.'
}

$venvPython = Join-Path $env:SPARK_LAB_VENV 'Scripts\python.exe'
if ((Test-Path -LiteralPath $venvPython) -and ((Get-PythonVersion -PythonExe $venvPython) -eq '3.10')) {
    Add-Result -Name 'python-310' -Status 'PASS' -Detail 'The virtual environment uses Python 3.10.'
} else {
    Add-Result -Name 'python-310' -Status 'FAIL' -Detail 'The virtual environment is missing or does not use Python 3.10.'
}

if (Test-Path -LiteralPath $venvPython) {
    $probeCode = 'import findspark, numpy, pandas, pyarrow, matplotlib, pyspark; print(pyspark.__version__)'
    $packageProbe = Invoke-CommandCapture -FilePath $venvPython -Arguments @('-c', $probeCode) -WorkingDirectory $ProjectRoot
    $expected = $dependencies.spark.version
    if ($packageProbe.ExitCode -eq 0 -and $packageProbe.Output.Trim() -eq $expected) {
        Add-Result -Name 'python-packages' -Status 'PASS' -Detail "pyspark $expected and the data packages import correctly."
    } else {
        Add-Result -Name 'python-packages' -Status 'FAIL' -Detail ("The package probe failed. " + $packageProbe.Output)
    }
} else {
    Add-Result -Name 'python-packages' -Status 'FAIL' -Detail 'The virtual environment is missing.'
}

$smokeOutput = ''
if ($SkipSmoke) {
    Add-Result -Name 'smoke-test' -Status 'WARN' -Detail 'Skipped because -SkipSmoke was set.'
    Add-Result -Name 'spark-ui' -Status 'WARN' -Detail 'Skipped because -SkipSmoke was set.'
} else {
    $smokeScript = Join-Path $ProjectRoot 'tests\smoke_test.py'
    if (-not (Test-Path -LiteralPath $smokeScript)) {
        Add-Result -Name 'smoke-test' -Status 'FAIL' -Detail 'tests\smoke_test.py is missing.'
        Add-Result -Name 'spark-ui' -Status 'FAIL' -Detail 'The smoke test did not run.'
    } else {
        $stdout = Join-Path $env:TEMP ('spark-smoke-' + [Guid]::NewGuid().ToString('N') + '.out')
        $stderr = Join-Path $env:TEMP ('spark-smoke-' + [Guid]::NewGuid().ToString('N') + '.err')
        $process = Start-Process -FilePath $venvPython -ArgumentList @($smokeScript) -WorkingDirectory $ProjectRoot -NoNewWindow -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        $finished = $process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $finished) {
            try { $process.Kill() } catch { }
            $smokeOutput = "The smoke test did not finish within $TimeoutSeconds seconds."
        } else {
            $outText = ''
            $errText = ''
            if (Test-Path -LiteralPath $stdout) { $outText = Get-Content -LiteralPath $stdout -Raw }
            if (Test-Path -LiteralPath $stderr) { $errText = Get-Content -LiteralPath $stderr -Raw }
            $smokeOutput = (($outText + [Environment]::NewLine + $errText).Trim())
        }
        Remove-Item -LiteralPath $stdout -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $stderr -Force -ErrorAction SilentlyContinue
        if ($smokeOutput -match 'SMOKE_OK') {
            Add-Result -Name 'smoke-test' -Status 'PASS' -Detail 'CSV rows, groupBy, Parquet round trip and row count verified.'
        } else {
            $tail = $smokeOutput
            if ($tail.Length -gt 600) { $tail = $tail.Substring($tail.Length - 600) }
            Add-Result -Name 'smoke-test' -Status 'FAIL' -Detail $tail
        }
        if ($smokeOutput -match 'UI_OK') {
            Add-Result -Name 'spark-ui' -Status 'PASS' -Detail 'The Spark UI answered on its local port.'
        } else {
            Add-Result -Name 'spark-ui' -Status 'WARN' -Detail 'The Spark UI did not answer. This does not block local jobs.'
        }
    }
}

$readiness = New-Object System.Collections.Generic.List[string]
$readinessStatus = 'PASS'

$hostName = [System.Net.Dns]::GetHostName()
if (-not (Test-AsciiPath -Path $hostName)) {
    if ([string]::IsNullOrWhiteSpace($env:SPARK_LOCAL_IP)) {
        $readinessStatus = 'FAIL'
        $readiness.Add('The hostname is not ASCII and SPARK_LOCAL_IP is empty')
    } else {
        if ($readinessStatus -eq 'PASS') { $readinessStatus = 'WARN' }
        $readiness.Add("The hostname is not ASCII but SPARK_LOCAL_IP is $env:SPARK_LOCAL_IP")
    }
} else {
    $readiness.Add("Hostname $hostName is ASCII")
}

if (Test-LongPathsEnabled) {
    $readiness.Add('Long paths are enabled')
} else {
    if ($readinessStatus -eq 'PASS') { $readinessStatus = 'WARN' }
    $readiness.Add('Long paths are disabled')
}

$driveRoot = [System.IO.Path]::GetPathRoot($ProjectRoot)
$free = Get-FreeSpaceGB -Path $driveRoot
if ($free -lt 0) {
    $readiness.Add('Free space could not be measured for this path')
} elseif ($free -lt 5) {
    if ($readinessStatus -eq 'PASS') { $readinessStatus = 'WARN' }
    $readiness.Add("Only $free GB free on $driveRoot")
} else {
    $readiness.Add("$free GB free on $driveRoot")
}

if (-not (Test-SafeWindowsPath -Path $ProjectRoot)) {
    $readinessStatus = 'FAIL'
    $readiness.Add('The project path contains a character that breaks Windows command scripts')
}

$managedEntries = @(
    (Join-Path $env:JAVA_HOME 'bin'),
    (Join-Path $env:SPARK_HOME 'bin'),
    (Join-Path $env:HADOOP_HOME 'bin'),
    (Join-Path $env:SPARK_LAB_VENV 'Scripts')
)
$pathEntries = @($env:PATH -split ';' | ForEach-Object { $_.TrimEnd('\') })
$duplicated = @()
foreach ($entry in $managedEntries) {
    $count = @($pathEntries | Where-Object { $_ -eq $entry }).Count
    if ($count -eq 0) {
        $readinessStatus = 'FAIL'
        $readiness.Add("$entry is not on PATH")
    } elseif ($count -gt 1) {
        if ($readinessStatus -eq 'PASS') { $readinessStatus = 'WARN' }
        $readiness.Add("$entry appears $count times on PATH")
    }
}
if ($readinessStatus -ne 'FAIL') { $readiness.Add('Every managed PATH entry appears once') }

Add-Result -Name 'windows-readiness' -Status $readinessStatus -Detail ($readiness -join '; ')

Complete-Report
