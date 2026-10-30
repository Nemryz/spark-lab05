BeforeAll {
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    . (Join-Path $repoRoot 'install\lib\Installer.ps1')
    $script:Dependencies = Read-JsonFile -Path (Join-Path $repoRoot 'install\dependencies.json')
}

Describe 'Merge-PathEntries' {
    It 'places new entries before the current path' {
        $result = Merge-PathEntries -CurrentPath 'C:\Windows;C:\Tools' -Entries @('C:\spark\bin')
        $result | Should -Be 'C:\spark\bin;C:\Windows;C:\Tools'
    }

    It 'removes duplicates while ignoring case and trailing separators' {
        $result = Merge-PathEntries -CurrentPath 'C:\Spark\bin\;c:\windows' -Entries @('C:\spark\bin')
        $result | Should -Be 'C:\spark\bin;c:\windows'
    }

    It 'keeps the original order of the current path' {
        $result = Merge-PathEntries -CurrentPath 'C:\b;C:\a;C:\c' -Entries @()
        $result | Should -Be 'C:\b;C:\a;C:\c'
    }

    It 'ignores empty and whitespace entries' {
        $result = Merge-PathEntries -CurrentPath 'C:\a;;   ;C:\b' -Entries @('  ')
        $result | Should -Be 'C:\a;C:\b'
    }

    It 'returns only the new entries when the current path is empty' {
        $result = Merge-PathEntries -CurrentPath '' -Entries @('C:\spark\bin', 'C:\winutils\bin')
        $result | Should -Be 'C:\spark\bin;C:\winutils\bin'
    }

    It 'returns an empty string when there is nothing to merge' {
        $result = Merge-PathEntries -CurrentPath '' -Entries @()
        $result | Should -Be ''
    }
}

Describe 'Test-AsciiPath' {
    It 'accepts a plain Windows path' {
        Test-AsciiPath -Path 'C:\Users\student\OneDrive\Escritorio\Spark' | Should -BeTrue
    }

    It 'rejects accented characters' {
        $accented = 'C:\Users\Jos' + [char]0x00E9 + '\Spark'
        Test-AsciiPath -Path $accented | Should -BeFalse
    }

    It 'rejects CJK characters' {
        $cjk = 'C:\' + [char]0x7A0B + [char]0x5E8F
        Test-AsciiPath -Path $cjk | Should -BeFalse
    }

    It 'rejects an empty path' {
        Test-AsciiPath -Path '' | Should -BeFalse
    }

    It 'rejects a null path' {
        Test-AsciiPath -Path $null | Should -BeFalse
    }
}

Describe 'Test-SafeWindowsPath' {
    It 'accepts a path with spaces and parentheses' {
        Test-SafeWindowsPath -Path 'D:\University Work\Spark (2026)' | Should -BeTrue
    }

    It 'accepts a drive root' {
        Test-SafeWindowsPath -Path 'C:\' | Should -BeTrue
    }

    It 'rejects an ampersand' {
        Test-SafeWindowsPath -Path 'C:\lab & notes\Spark' | Should -BeFalse
    }

    It 'rejects a percent sign' {
        Test-SafeWindowsPath -Path 'C:\lab%20\Spark' | Should -BeFalse
    }

    It 'rejects pipes and redirection' {
        Test-SafeWindowsPath -Path 'C:\lab|notes\Spark' | Should -BeFalse
        Test-SafeWindowsPath -Path 'C:\lab<notes>\Spark' | Should -BeFalse
        Test-SafeWindowsPath -Path 'C:\lab>notes\Spark' | Should -BeFalse
    }

    It 'rejects an exclamation mark' {
        Test-SafeWindowsPath -Path 'C:\lab!notes\Spark' | Should -BeFalse
    }

    It 'rejects an empty path' {
        Test-SafeWindowsPath -Path '' | Should -BeFalse
    }
}

Describe 'Test-PathWritable' {
    It 'accepts an existing writable directory' {
        Test-PathWritable -Path $env:TEMP | Should -BeTrue
    }

    It 'rejects a path whose parent does not exist' {
        $missing = Join-Path $env:TEMP ([Guid]::NewGuid().ToString('N'))
        Test-PathWritable -Path (Join-Path $missing 'child') | Should -BeFalse
    }

    It 'rejects a file used as a directory' {
        $file = Join-Path $env:TEMP ([Guid]::NewGuid().ToString('N') + '.txt')
        Set-Content -LiteralPath $file -Value 'x'
        try {
            Test-PathWritable -Path $file | Should -BeFalse
        } finally {
            Remove-Item -LiteralPath $file -Force
        }
    }
}

Describe 'Remove-SafeDirectory' {
    It 'refuses a drive root' {
        { Remove-SafeDirectory -Path 'C:\' } | Should -Throw
    }

    It 'refuses an unexpected directory name' {
        $directory = Join-Path $env:TEMP ('keep-me-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
        try {
            { Remove-SafeDirectory -Path $directory } | Should -Throw
        } finally {
            Remove-Item -LiteralPath $directory -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'removes a directory named spark' {
        $parent = Join-Path $env:TEMP ('spark-lab-test-' + [Guid]::NewGuid().ToString('N'))
        $target = Join-Path $parent 'spark'
        New-Item -ItemType Directory -Force -Path $target | Out-Null
        Set-Content -LiteralPath (Join-Path $target 'RELEASE') -Value 'spark'
        try {
            Remove-SafeDirectory -Path $target
            Test-Path -LiteralPath $target | Should -BeFalse
        } finally {
            Remove-Item -LiteralPath $parent -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'does nothing for an absent directory with an allowed name' {
        $missing = Join-Path (Join-Path $env:TEMP ([Guid]::NewGuid().ToString('N'))) 'spark'
        { Remove-SafeDirectory -Path $missing } | Should -Not -Throw
    }
}

Describe 'Version probes' {
    It 'returns null for a missing Java executable' {
        Get-JavaMajor -JavaExe (Join-Path $env:TEMP 'no-java.exe') | Should -BeNullOrEmpty
    }

    It 'returns null for a missing Python executable' {
        Get-PythonVersion -PythonExe (Join-Path $env:TEMP 'no-python.exe') | Should -BeNullOrEmpty
    }

    It 'returns null when spark-submit is missing' {
        Get-SparkVersion -SparkHome (Join-Path $env:TEMP 'no-spark') | Should -BeNullOrEmpty
    }

    It 'reports a positive free space value' {
        Get-FreeSpaceGB -Path $env:TEMP | Should -BeGreaterThan 0
    }

    It 'reports whether long paths are enabled as a boolean' {
        $value = Test-LongPathsEnabled
        ($value -is [bool]) | Should -BeTrue
    }

    It 'reports whether the session is elevated as a boolean' {
        $value = Test-IsAdmin
        ($value -is [bool]) | Should -BeTrue
    }
}

Describe 'Dependency manifest' {
    It 'pins Apache Spark 3.3.4' {
        $script:Dependencies.spark.version | Should -Be '3.3.4'
    }

    It 'pins a JDK 11 release' {
        $script:Dependencies.jdk.major | Should -Be 11
    }

    It 'pins the winutils repository commit and both binaries' {
        $script:Dependencies.hadoop.commit | Should -Match '^[0-9a-f]{40}$'
        @($script:Dependencies.hadoop.files).Count | Should -Be 2
    }

    It 'uses a 128 character SHA512 for the Spark archive' {
        $script:Dependencies.spark.sha512 | Should -Match '^[0-9a-f]{128}$'
    }

    It 'uses 64 character SHA256 hashes for the other archives' {
        $script:Dependencies.jdk.sha256 | Should -Match '^[0-9a-f]{64}$'
        $script:Dependencies.python.sha256 | Should -Match '^[0-9a-f]{64}$'
        foreach ($file in $script:Dependencies.hadoop.files) {
            $file.sha256 | Should -Match '^[0-9a-f]{64}$'
        }
    }

    It 'throws for a missing manifest' {
        $missing = Join-Path $env:TEMP ('missing-' + [Guid]::NewGuid().ToString('N') + '.json')
        { Read-JsonFile -Path $missing } | Should -Throw
    }
}

Describe 'New-SparkEnvFile' {
    It 'writes a loadable file that can be sourced twice without duplicating PATH' {
        $directory = Join-Path $env:TEMP ('spark-env-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
        $path = Join-Path $directory 'spark-env.ps1'
        $savedPath = $env:PATH
        $savedJava = $env:JAVA_HOME
        $savedSpark = $env:SPARK_HOME
        $savedHadoop = $env:HADOOP_HOME
        $savedPython = $env:PYSPARK_PYTHON
        try {
            New-SparkEnvFile -Path $path -JavaHome 'C:\jdk' -SparkHome 'C:\spark' -HadoopHome 'C:\winutils' -VenvPath 'C:\venv'
            Test-Path -LiteralPath $path | Should -BeTrue

            . $path
            $env:JAVA_HOME | Should -Be 'C:\jdk'
            $env:SPARK_HOME | Should -Be 'C:\spark'
            $env:HADOOP_HOME | Should -Be 'C:\winutils'
            $env:PYSPARK_PYTHON | Should -Be 'C:\venv\Scripts\python.exe'
            $env:SPARK_LOCAL_IP | Should -Be '127.0.0.1'
            @($env:PATH -split ';' | Where-Object { $_ -eq 'C:\spark\bin' }).Count | Should -Be 1

            . $path
            @($env:PATH -split ';' | Where-Object { $_ -eq 'C:\spark\bin' }).Count | Should -Be 1
            @($env:PATH -split ';' | Where-Object { $_ -eq 'C:\jdk\bin' }).Count | Should -Be 1
        } finally {
            $env:PATH = $savedPath
            $env:JAVA_HOME = $savedJava
            $env:SPARK_HOME = $savedSpark
            $env:HADOOP_HOME = $savedHadoop
            $env:PYSPARK_PYTHON = $savedPython
            Remove-Item -LiteralPath $directory -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
