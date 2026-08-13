function Resolve-PythonCommand {
  Set-StrictMode -Version Latest

  function Test-PythonCommand {
    param(
      [string]$Command,
      [string[]]$PrefixArgs = @()
    )

    if ($Command -like "*\Microsoft\WindowsApps\python.exe" -or $Command -like "*\Microsoft\WindowsApps\python3.exe") {
      return $false
    }

    $probeArgs = @($PrefixArgs + @("-c", "import sys; print(sys.version_info[0])"))
    try {
      $probe = & $Command @probeArgs 2>$null
      return ($LASTEXITCODE -eq 0 -and (($probe | Out-String).Trim()) -eq "3")
    } catch {
      return $false
    }
  }

  $configuredPython = [Environment]::GetEnvironmentVariable("ZIMEITI_PYTHON")
  if (-not [string]::IsNullOrWhiteSpace($configuredPython)) {
    if (-not (Test-Path -LiteralPath $configuredPython -PathType Leaf)) {
      throw "ZIMEITI_PYTHON does not point to a file: $configuredPython"
    }
    if (Test-PythonCommand -Command $configuredPython) {
      return @{
        Command = (Resolve-Path -LiteralPath $configuredPython).Path
        PrefixArgs = @()
      }
    }
    throw "ZIMEITI_PYTHON is not a usable Python 3 interpreter: $configuredPython"
  }

  $py = Get-Command py -ErrorAction SilentlyContinue
  if ($py -and (Test-PythonCommand -Command $py.Source -PrefixArgs @("-3"))) {
    return @{
      Command = $py.Source
      PrefixArgs = @("-3")
    }
  }

  foreach ($name in @("python", "python3")) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd -and (Test-PythonCommand -Command $cmd.Source)) {
      return @{
        Command = $cmd.Source
        PrefixArgs = @()
      }
    }
  }

  throw "No usable Python 3 interpreter found. Set ZIMEITI_PYTHON or install py, python, or python3 on PATH."
}
