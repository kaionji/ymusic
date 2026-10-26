# Собирает приложение и ставит его как обычную программу:
# ярлык "Моя Музыка" на рабочем столе и в меню Пуск.
# Запуск (из папки проекта):
#   powershell -ExecutionPolicy Bypass -File .\install_windows.ps1

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$AppName    = 'Моя Музыка'
$ExeName    = 'MoyaMuzyka'
$InstallDir = Join-Path $env:LOCALAPPDATA 'MoyaMuzyka'

if (-not (Test-Path 'pubspec.yaml') -or -not (Test-Path 'windows')) {
    throw 'Запустите скрипт из папки проекта (сначала выполните flutter create --platforms=windows,ios .)'
}

$utf8 = New-Object System.Text.UTF8Encoding($false)

# 1. Заголовок окна в C++ делаем простым ASCII (по-русски его задает само приложение при запуске)
Write-Host '1/5 Настраиваю название окна, имя программы и иконку...'
$mainCpp = (Resolve-Path 'windows\runner\main.cpp').Path
$text = [IO.File]::ReadAllText($mainCpp, $utf8)
$text = $text -replace 'window\.Create\(L"[^"]*"', 'window.Create(L"Moya Muzyka"'
[IO.File]::WriteAllText($mainCpp, $text, $utf8)

# 2. Имя exe-файла
$cmake = (Resolve-Path 'windows\CMakeLists.txt').Path
$text = [IO.File]::ReadAllText($cmake, $utf8)
$text = $text -replace 'set\(BINARY_NAME "[^"]*"\)', "set(BINARY_NAME `"$ExeName`")"
[IO.File]::WriteAllText($cmake, $text, $utf8)

# 3. Иконка
if (Test-Path 'tools\app_icon.ico') {
    Copy-Item 'tools\app_icon.ico' 'windows\runner\resources\app_icon.ico' -Force
}

# 4. Сборка
Write-Host '2/5 Собираю релизную версию (несколько минут)...'
& flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'Сборка не удалась. Пришлите текст ошибки выше.' }

$release = 'build\windows\x64\runner\Release'
$exe = Join-Path $release "$ExeName.exe"
if (-not (Test-Path $exe)) { throw "Не найден файл $exe" }

# 5. Установка
Write-Host "3/5 Копирую в $InstallDir ..."
Get-Process $ExeName -ErrorAction SilentlyContinue | Stop-Process -Force
if (Test-Path $InstallDir) { Remove-Item $InstallDir -Recurse -Force }
New-Item -ItemType Directory -Path $InstallDir | Out-Null
Copy-Item (Join-Path $release '*') $InstallDir -Recurse -Force

# 6. Ярлыки
Write-Host '4/5 Создаю ярлыки...'
$target = Join-Path $InstallDir "$ExeName.exe"
function New-AppShortcut([string]$path) {
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($path)
    $lnk.TargetPath = $target
    $lnk.WorkingDirectory = $InstallDir
    $lnk.IconLocation = "$target,0"
    $lnk.Save()
}
New-AppShortcut (Join-Path ([Environment]::GetFolderPath('Desktop')) "$AppName.lnk")
New-AppShortcut (Join-Path ([Environment]::GetFolderPath('Programs')) "$AppName.lnk")

Write-Host "5/5 Готово! Запускайте ярлык '$AppName' на рабочем столе или найдите его в меню Пуск."
