#__________Змінні_____________

# Шлях директорії для експорту 
$exportFolder = "C:\Win11Upgrade" # МОЖНА ЗМІНИТИ ЗА ПОТРЕБИ

# Налаштування
$autoDeleteDuplicates = $false  # $true - для автоматичного видалення без запитань, $false - для ручного контролю.

#_____________________________

# Зчитуємо всі облікові записи користувачів
$systemUsers = Get-WmiObject Win32_UserAccount | Where-Object { $_.LocalAccount -eq $true }
$userSIDMap = @{}
foreach ($user in $systemUsers) {
    $userSIDMap[$user.SID] = $user.Name
}

# Зчитуємо SID-и з реєстру ProfileList
$profileListKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
$registryProfiles = Get-ChildItem -Path $profileListKey
$profilePaths = @{}
$duplicatePaths = @{}
$ghosts = @()

Write-Host "`n _-_-_-_- ПРОФІЛІ -_-_-_-_`n" -BackgroundColor Yellow -ForegroundColor Black

foreach ($sidKey in $registryProfiles) {
    $sid = $sidKey.PSChildName
    $profilePath = (Get-ItemProperty -Path $sidKey.PSPath).ProfileImagePath

    # Збираємо SID ProfilePath
    if ($profilePaths.ContainsKey($profilePath)) {
        $duplicatePaths[$profilePath] += $sid
    } else {
        $profilePaths[$profilePath] = $sid
        $duplicatePaths[$profilePath] = @($sid)
    }

    # Перевірка привидів
    if (-not $userSIDMap.ContainsKey($sid)) {
        $ghosts += [PSCustomObject]@{
            SID = $sid
            ProfilePath = $profilePath
        }
    }
}

# вивід шляхи дублікатів
$hasRealDuplicates = $false
foreach ($pair in $duplicatePaths.GetEnumerator()) {
    if ($pair.Value.Count -gt 1) {
        $hasRealDuplicates = $true
        break
    }
}

if (-not $hasRealDuplicates) {
    Write-Host "🟥 Дублікати профілів не знайдені (ProfileImagePath):" -ForegroundColor Green
}
else {
    Write-Host "🟥 Дублікати профілів (ProfileImagePath):" -ForegroundColor Red
    foreach ($pair in $duplicatePaths.GetEnumerator()) {
        if ($pair.Value.Count -gt 1) {
            Write-Host "`nPath: $($pair.Key)"
            foreach ($dupSID in $pair.Value) {
                if ($userSIDMap.ContainsKey($dupSID)) {
                    Write-Host "  SID: $dupSID  →  User: $($userSIDMap[$dupSID])"
                }
                elseif ($dupSID -eq $pair.Value[0]) {
                    Write-Host "  SID: $dupSID  →  User: [Активний (основний)]"
                }
                else {
                    Write-Host "  SID: $dupSID  →  User: [Неіснуючий дублікат]"
                }
            }
        }
    }
}

# відображення SID-привиди
if ($ghosts.Count -gt 0) {
    Write-Host "`n🟨 Облікові записи-привиди (SID у реєстрі, але немає в системі):" -ForegroundColor Yellow
    foreach ($ghost in $ghosts) {
        Write-Host "  SID: $($ghost.SID)  →  Profile: $($ghost.ProfilePath)"
    }
}
else {
    Write-Host "`n🟩 Облікових записів-привидів не знайдено." -ForegroundColor Green
}

# --- Запит на видалення або автозапуск ---
if ($hasRealDuplicates) {
    if (-not $autoDeleteDuplicates) {
        $userInput = Read-Host "`n Хочете автоматично видалити дублікати профілів? (y/n)"
        if ($userInput -ne 'y') {
            Write-Host "`n Вирішіть проблему вручну та запустіть скрипт повторно." -ForegroundColor Yellow
            return
        }
    }
    else {
        Write-Host "`n Автоматичне видалення дублікатів без підтвердження увімкнено." -ForegroundColor DarkGray
    }
}


# Підготовка до експорту дублікатів
if (-not (Test-Path $exportFolder)) {
    New-Item -Path $exportFolder -ItemType Directory | Out-Null
}
$exportFile = Join-Path $exportFolder "duplicate_profiles.txt"
"Список видалених дублікатів профілів:`n" | Out-File -FilePath $exportFile -Encoding UTF8

# експорт у .reg, логування, видалення
foreach ($pair in $duplicatePaths.GetEnumerator()) {
    $sids = $pair.Value
    if ($sids.Count -gt 1) {
        # Вибір SID, який залишити
        $sidToKeep = $sids | Where-Object { $userSIDMap.ContainsKey($_) } | Select-Object -First 1
        if (-not $sidToKeep) {
            $sidToKeep = $sids[0]
        }

        $sidsToDelete = $sids | Where-Object { $_ -ne $sidToKeep }

        foreach ($sid in $sidsToDelete) {
            $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid"
            $regExportPath = Join-Path $exportFolder "$sid.reg"

            if (Test-Path $regPath) {
                try {
                    # Експорт .reg
                    $cmd = "reg export `"HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid`" `"$regExportPath`" /y"
                    Write-Host "Експорт ключа $sid до $regExportPath"
                    cmd.exe /c $cmd | Out-Null

                    # Лог
                    "Експортовано ключ SID: $sid до файлу: $regExportPath" | Out-File -FilePath $exportFile -Append -Encoding UTF8

                    # Видалення
                    Remove-Item -Path $regPath -Recurse -Force
                    Write-Host "🗑️ Видалено дублікат SID: $sid" -ForegroundColor Magenta
                }
                catch {
                    Write-Host "Помилка при експорті або видаленні $sid : $_" -ForegroundColor Red
                }
            }
        }
    }
}

