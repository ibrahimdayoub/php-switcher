# PHP Version Switcher for XAMPP

> A PowerShell tool to switch PHP versions in XAMPP — optimized for **Laravel** projects.

---

## Overview

Laravel has different PHP requirements depending on the version:

| Laravel Version | PHP Required |
|-----------------|--------------|
| 8.x             | 7.3 – 8.1    |
| 9.x             | 8.0 – 8.2    |
| 10.x            | 8.1 – 8.3    |
| 11.x            | 8.2 – 8.4    |
| 12.x            | 8.3+         |

If your XAMPP only *has one PHP version*, you may face errors when working on both *legacy and modern* Laravel projects.
This script solves that by **swapping a symlink** to point to whichever PHP version you need.

---

## How It Works

Your XAMPP folder typically looks like this:

```
C:\xampp\
  ├── php74\        ← PHP 7.4 binaries
  ├── php80\        ← PHP 8.0 binaries
  ├── php82\        ← PHP 8.2 binaries
  └── php\          ← SYMLINK → points to one of the above
```

When you run the script, it:

1. Shows the currently active PHP version
2. Lists all available PHP versions with their compatible Laravel range
3. Removes the existing `php` junction
4. Creates a new junction *pointing* to your chosen version
5. Prompts you to restart your terminal

**No** files are copied or deleted — only the directory link changes, making the switch **instant**.

---

## Requirements

- **Windows** 10 / 11
- **PowerShell 5.1+** (comes with Windows)
- **XAMPP** installed at `C:\xampp`
- **PHP folders** inside XAMPP named `php74`, `php80`, `php82`, etc.
- **Administrator privileges** (the script enforces this)

> 💡 If your XAMPP is installed elsewhere, edit `$xamppDir` in `switch-php.ps1`.

---

## Installation

1. Clone or copy the files to your machine:

```
git clone https://github.com/ibrahimdayoub/php-switcher.git
cd php-switcher
```

2. **(Recommended)** Add the folder to your `PATH` so you can run the script from anywhere:

  - Open **System Properties → Environment Variables**
   - Under `System variables` (or `User variables`), select `Path` and click **Edit**
   - Click **new** and add the full path to the `php-switcher` folder
   - Open a **new** PowerShell or CMD window and run:
   ```bash
     switch-php
   ```

3. Add missing PHP versions to XAMPP:

   - Download the desired PHP version from [windows.php.net](https://windows.php.net/download/)
   - Extract it to `C:\xampp\php83` (e.g. for PHP 8.3)
   - Copy `php.ini-development` as `php.ini` and adjust settings

---

## Usage

### Method 1 — Double-click the batch file (auto admin)

- **Option A (Easiest):** Just **double-click** `switch-php.bat`. It will automatically trigger the Windows UAC prompt to elevate to Administrator.
- **Option B:** Right-click `switch-php.bat` and select **Run as administrator**.

### Method 2 — Run PowerShell as Admin manually

```
1. Open PowerShell as Administrator
2. cd "C:\path\to\your\cloned\php-switcher"
3. .\switch-php.ps1
```

---

## Adding a New PHP Version

1. Download the PHP build from [windows.php.net](https://windows.php.net/download/)
2. Extract to `C:\xampp\phpXX` (e.g. `C:\xampp\php84`)
3. Copy `php.ini-development` → `php.ini` and configure it
4. Open `switch-php.ps1` and add an entry to the `$phpVersions` array:

```powershell
$phpVersions = @(
    @{ Id = 1; Label = "PHP 7.4"; Folder = "php74"; MinLaravel = "6.x";  MaxLaravel = "8.x"   },
    @{ Id = 2; Label = "PHP 8.0"; Folder = "php80"; MinLaravel = "8.x";  MaxLaravel = "9.x"   },
    # Add your new version:
    @{ Id = 6; Label = "PHP 8.4"; Folder = "php84"; MinLaravel = "12.x"; MaxLaravel = "12.x"  }
)
```

That's it — the new version will appear in the menu automatically.

---

## Files

| File              | Description                                   |
|-------------------|-----------------------------------------------|
| `switch-php.ps1`  | Main PowerShell script                        |
| `switch-php.bat`  | Batch wrapper (launches the PS script)        |
| `README.md`       | This file                                     |

---

## Troubleshooting

| Problem                          | Solution                                                   |
|----------------------------------|------------------------------------------------------------|
| "Access Denied"                  | Run PowerShell **as Administrator**                        |
| "Folder does not exist"          | Make sure `C:\xampp\phpXX` exists with the PHP binaries    |
| PHP version not showing change   | Restart your terminal / VS Code completely                 |
| "Running scripts is disabled"    | Run `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`  |

---

## License

This project is licensed under the [MIT License](LICENSE).