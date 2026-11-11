# Uninstall the Flutter environment

Everything Flutter-related lives on **D:**. Nothing was installed on C:
(no Android Studio, no Android SDK, no Java).

| What | Where |
|------|-------|
| Flutter SDK | `D:\dev\flutter` |
| Pub package cache | `D:\dev\pub-cache` |
| User env var `PUB_CACHE` | `D:\dev\pub-cache` |
| User `PATH` entry | `D:\dev\flutter\bin` |

## 1. Remove the PATH entry and PUB_CACHE (PowerShell)

```powershell
# Remove D:\dev\flutter\bin from the USER PATH (keeps all other entries)
$p = [Environment]::GetEnvironmentVariable("PATH", "User")
$new = ($p -split ';' | Where-Object { $_ -and $_ -ne 'D:\dev\flutter\bin' }) -join ';'
[Environment]::SetEnvironmentVariable("PATH", $new, "User")

# Delete the PUB_CACHE user variable
[Environment]::SetEnvironmentVariable("PUB_CACHE", $null, "User")
```

Do **not** use `setx` — it can truncate a long PATH.

## 2. Delete the files

Close VS Code / terminals using Flutter first, then:

```powershell
Remove-Item -Recurse -Force D:\dev\flutter
Remove-Item -Recurse -Force D:\dev\pub-cache
# Only if D:\dev is now empty:
Remove-Item D:\dev
```

## 3. Optional leftovers (small)

Flutter keeps tiny settings files in your user profile:

```powershell
Remove-Item -Force "$env:USERPROFILE\.flutter" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$env:APPDATA\.flutter" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$env:APPDATA\.dart-tool" -ErrorAction SilentlyContinue
```

Open a new terminal afterwards so the PATH change takes effect.
