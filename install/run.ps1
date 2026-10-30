#Requires -Version 5.1
<#
.SYNOPSIS
    Runs the Spark laboratory tools with the lab JDK and the lab virtual environment.

.DESCRIPTION
    The script loads install\spark-env.ps1 into the current process, so the machine wide JAVA_HOME and the global Python installation stay untouched. Arguments after the command are forwarded to the selected tool.

.EXAMPLE
    .\install\run.ps1 status

.EXAMPLE
    .\install\run.ps1 pyspark

.EXAMPLE
    .\install\run.ps1 submit src\rdd_lab.py

.EXAMPLE
    .\install\run.ps1 jupyter
#>
param(
    [string]$Command = 'status'
)

$rest = @($args)

$envFile = Join-Path $PSScriptRoot 'spark-env.ps1'
if (-not (Test-Path -LiteralPath $envFile)) {
    Write-Host 'The environment file is missing. Run .\install\install-spark.ps1 first.' -ForegroundColor Red
    exit 1
}
. $envFile

function Show-Usage {
    Write-Host ''
    Write-Host 'Usage: .\install\run.ps1 <command> [arguments]'
    Write-Host ''
    Write-Host '  status             Show the lab environment.'
    Write-Host '  pyspark            Start the PySpark shell.'
    Write-Host '  submit <args>      Run spark-submit with the given arguments.'
    Write-Host '  python <args>      Run the virtual environment Python.'
    Write-Host '  jupyter [args]     Start JupyterLab.'
    Write-Host '  notebook [args]    Start the classic notebook interface.'
    Write-Host '  shell [args]       Start the Scala shell.'
    Write-Host ''
}

function Show-Status {
    Write-Host ''
    Write-Host 'Spark laboratory environment' -ForegroundColor Cyan
    Write-Host ''
    $javaExe = Join-Path $env:JAVA_HOME 'bin\java.exe'
    if (Test-Path -LiteralPath $javaExe) {
        $javaOutput = (& $javaExe -version 2>&1 | Out-String).Trim()
        Write-Host ("  Java      {0}" -f $env:JAVA_HOME)
        Write-Host ("            {0}" -f ($javaOutput -split "`n" | Select-Object -First 1))
    } else {
        Write-Host ("  Java      missing at {0}" -f $env:JAVA_HOME) -ForegroundColor Yellow
    }
    $venvPython = Join-Path $env:SPARK_LAB_VENV 'Scripts\python.exe'
    if (Test-Path -LiteralPath $venvPython) {
        $pythonVersion = (& $venvPython -c 'import sys; print(sys.version.split()[0])' 2>&1 | Out-String).Trim()
        Write-Host ("  Python    {0} ({1})" -f $pythonVersion, $env:SPARK_LAB_VENV)
    } else {
        Write-Host ("  Python    missing at {0}" -f $env:SPARK_LAB_VENV) -ForegroundColor Yellow
    }
    $sparkSubmit = Join-Path $env:SPARK_HOME 'bin\spark-submit.cmd'
    if (Test-Path -LiteralPath $sparkSubmit) {
        Write-Host ("  Spark     {0}" -f $env:SPARK_HOME)
    } else {
        Write-Host ("  Spark     missing at {0}" -f $env:SPARK_HOME) -ForegroundColor Yellow
    }
    $winutils = Join-Path $env:HADOOP_HOME 'bin\winutils.exe'
    if (Test-Path -LiteralPath $winutils) {
        Write-Host ("  Hadoop    {0}" -f $env:HADOOP_HOME)
    } else {
        Write-Host ("  Hadoop    missing at {0}" -f $env:HADOOP_HOME) -ForegroundColor Yellow
    }
    Write-Host ("  Local IP  {0}" -f $env:SPARK_LOCAL_IP)
    Write-Host ''
}

function Get-SubmitArguments {
    param([string[]]$Arguments)
    foreach ($argument in $Arguments) {
        if ($argument -like '--driver-memory*') { return $Arguments }
    }
    return @('--driver-memory', '1g', '--conf', 'spark.driver.extraJavaOptions=-Xms64m') + $Arguments
}

switch ($Command.ToLowerInvariant()) {
    'status' {
        Show-Status
        exit 0
    }
    'pyspark' {
        & (Join-Path $env:SPARK_HOME 'bin\pyspark.cmd') @rest
        exit $LASTEXITCODE
    }
    'submit' {
        $submitArguments = Get-SubmitArguments -Arguments $rest
        & (Join-Path $env:SPARK_HOME 'bin\spark-submit.cmd') @submitArguments
        exit $LASTEXITCODE
    }
    'python' {
        & (Join-Path $env:SPARK_LAB_VENV 'Scripts\python.exe') @rest
        exit $LASTEXITCODE
    }
    'jupyter' {
        & (Join-Path $env:SPARK_LAB_VENV 'Scripts\jupyter-lab.exe') @rest
        exit $LASTEXITCODE
    }
    'notebook' {
        & (Join-Path $env:SPARK_LAB_VENV 'Scripts\jupyter-notebook.exe') @rest
        exit $LASTEXITCODE
    }
    'shell' {
        & (Join-Path $env:SPARK_HOME 'bin\spark-shell.cmd') @rest
        exit $LASTEXITCODE
    }
    default {
        Write-Host ("Unknown command: {0}" -f $Command) -ForegroundColor Red
        Show-Usage
        exit 2
    }
}
