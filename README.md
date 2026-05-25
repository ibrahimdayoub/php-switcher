# PHP Version Switcher for XAMPP

> A PowerShell tool to switch PHP versions in XAMPP by swapping a directory junction.
> Works with **any PHP 7.x / 8.x Thread-Safe (TS) build**.

---

## How It Works (The Core Idea)

XAMPP has PHP installed at `C:\xampp\php`. Instead of moving folders around, this
tool replaces that folder with a **junction** — a directory symlink that acts like
a permanent redirect.

```
C:\xampp\
  ├── php74\          ← PHP 7.4 binaries (downloaded separately)
  ├── php80\          ← PHP 8.0 binaries
  ├── php82\          ← PHP 8.2 binaries (XAMPP's original)
  ├── php83\          ← PHP 8.3 binaries
  └── php\            ← JUNCTION → points to one of the above
```

XAMPP and Apache always look at `C:\xampp\php`. The junction transparently
redirects them to whichever version folder you choose. No files are copied.

---

## The Two Tools

| Tool | What it does |
|------|-------------|
| **`download-php`** | Downloads PHP from the internet and extracts it to `C:\xampp` (e.g. `C:\xampp\php74`) |
| **`switch-php`** | Points the junction to a version folder, fixes Apache config and php.ini |

**You always use `download-php` first, then `switch-php`.**

---

## Real-World Use Case

This is exactly why this project exists:

> I have two Laravel projects:
> - **Old project** — Laravel 8, needs PHP 7.4
> - **New project** — Laravel 12, needs PHP 8.2
>
> Both must run on the same XAMPP installation (which comes with PHP 8.2).
> Instead of manually replacing PHP folders every time I switch projects,
> I run `switch-php.bat`. In 10 seconds Apache is using the right PHP version.

No dual-boot, no Docker, no separate WAMP installs. One XAMPP, two PHP versions,
one click to switch between them.

---

## What `download-php` Does (Step by Step)

This tool downloads a PHP Thread-Safe zip from `windows.php.net` and prepares it
for XAMPP. When you run it, these 4 steps happen automatically:

### [1/4] Download
- Fetches the correct zip file (e.g. `php-8.2.28-Win32-vs16-x64.zip`)
- Shows the download URL and destination folder
- Saves the zip to a temp folder

### [2/4] Extract
- Removes any previous folder at `C:\xampp\phpXX`
- Creates a new folder (e.g. `C:\xampp\php82`)
- Extracts all PHP binaries into it

### [3/4] Create php.ini
- Copies `php.ini-development` → `php.ini`
- Enables common extensions: **curl, fileinfo, gd2, mbstring, mysqli, openssl, pdo_mysql**
- Sets `extension_dir` to `C:\xampp\php\ext` (the junction path — explained below)

### [4/4] Clean up
- Deletes the downloaded zip file

> **Q: Why do I still need `switch-php` after this?**
> A: `download-php` only downloads and extracts. The junction still points to the
> old version. You run `switch-php` to tell XAMPP to actually use the new version.

### Usage

**Double-click** `download-php.bat` → menu appears, pick a number.

**Command line** (run as Admin):
```bat
download-php.bat 7.4
download-php.bat 8.2
download-php.bat 8.3
```

---

## What `switch-php` Does (Step by Step)

This is the main tool. When you select a PHP version, it does 4 things:

### 1. Swap the Junction
- Removes the existing `C:\xampp\php` junction (or backs up the original folder)
- Creates a new junction pointing to the selected version folder

### 2. Fix Apache Config (`httpd-xampp.conf`)
Three fixes are applied automatically:

| Fix | Why |
|-----|-----|
| **LoadModule** | Apache needs the correct module name. PHP 8.x exports `php_module`, PHP 7.4 exports `php7_module`. The script reads the DLL's PE export table to find the right name. |
| **LoadFile** | Each PHP version has a different TS core DLL (`php8ts.dll`, `php7ts.dll`). The script finds it and updates the path. |
| **IfModule block** | `PHPIniDir` is wrapped in `<IfModule php_module>`. If the module is `php7_module`, the block is skipped and PHP has no php.ini. The script updates the block name. |

The module name is detected **dynamically** by parsing the DLL's PE header — no
hardcoded version-to-name mapping. This means it works with any PHP build.

### 3. Create php.ini (if missing)
- If the version folder has no `php.ini`, copies `php.ini-development` → `php.ini`

### 4. Fix extension_dir in php.ini
- PHP extensions are in `C:\xampp\php74\ext`, `C:\xampp\php82\ext`, etc.
- php.ini from PHP 7.4 has `extension_dir = "C:\xampp\php74\ext"` — hardcoded
- When the junction points to PHP 7.4, Apache reads `C:\xampp\php\ext` (through the junction)
  but php.ini says `C:\xampp\php74\ext` — **extensions are missing**
- The script rewrites it to `extension_dir = "C:\xampp\php\ext"` — **works through the junction**
- This is safe because `C:\xampp\php74\ext` = `C:\xampp\php\ext` through the junction

### Usage

**Double-click** `switch-php.bat` → menu appears, pick a number.

**Command line** (run as Admin):
```powershell
.\switch-php.ps1
```

After switching: **restart Apache** from XAMPP Control Panel.

---

## Full Setup Guide (From Zero)

### Step 1: Install XAMPP

Download from [apachefriends.org](https://www.apachefriends.org/) and install to `C:\xampp`.

### Step 2: Download PHP Versions

Each version must be **Thread-Safe (TS) x64**. Open `download-php.bat` and
download the versions you need. Repeat for each:

```bat
download-php.bat 7.4
download-php.bat 8.2
download-php.bat 8.3
```

Or double-click `download-php.bat` and select from the menu.

Each download goes to:
- `C:\xampp\php74` — PHP 7.4
- `C:\xampp\php82` — PHP 8.2
- etc.

### Step 3: Switch PHP Version

Open `switch-php.bat`, select your version. The script:
1. Creates the junction
2. Fixes Apache config
3. Fixes php.ini

### Step 4: Restart Apache

Open XAMPP Control Panel:
- Stop Apache
- Start Apache

### Step 5: Verify

Open your browser: `http://localhost/dashboard/phpinfo.php`

Or run: `C:\xampp\php\php.exe -v`

---

## Complete Workflow Example

```bat
:: Step 1: Download PHP 7.4 and 8.2
download-php.bat 7.4
download-php.bat 8.2

:: Step 2: Activate PHP 7.4 for old Laravel project
switch-php.bat
:: → Select "PHP 7.4"

:: Step 3: Restart Apache in XAMPP Control Panel
:: Step 4: Verify
:: → http://localhost/phpmyadmin should load without errors
:: → Old Laravel project works

:: Later, activate PHP 8.2 for new Laravel project:
switch-php.bat
:: → Select "PHP 8.2"
:: → Restart Apache
:: → New Laravel project works
```

---

## When Something Goes Wrong

### The 4 Problems This Tool Fixes Automatically

| Problem | What happens | How the script fixes it |
|---------|-------------|------------------------|
| Wrong LoadModule | Apache crashes on start: "Can't locate API module structure" | Detects module name from DLL exports (line 243) |
| Wrong LoadFile | Apache fails to load PHP: "The procedure entry point could not be located" | Finds the correct `phpXts.dll` DLL (line 234) |
| IfModule mismatch | PHP runs but ignores php.ini, no extensions load, phpMyAdmin shows mysqli error | Updates `<IfModule>` to match actual module name (line 265) |
| Hardcoded extension_dir | Extensions missing even though php.ini is loaded | Rewrites to `C:\xampp\php\ext` (junction-safe) (line 323) |

---

## File Reference

| File | Type | What it does |
|------|------|-------------|
| `switch-php.ps1` | PowerShell script (384 lines) | Main switching logic: junction, Apache config, php.ini fixes. Contains all functions. |
| `switch-php.bat` | Batch file (17 lines) | Launcher for `switch-php.ps1`. Self-elevates to Admin, runs the PS1, pauses at end. |
| `download-php.ps1` | PowerShell script (146 lines) | Downloads PHP TS zip, extracts to `C:\xampp\phpXX`, creates php.ini with extensions enabled. |
| `download-php.bat` | Batch file (17 lines) | Launcher for `download-php.ps1`. Self-elevates to Admin, passes arguments through, pauses at end. |
| `README.md` | Documentation (this file) | Full setup guide and explanation. |
| `LICENSE` | MIT license | Open source license. |

### How the Batch Files Work

Both `.bat` files follow the same pattern:

```
1. net session check         → Is this running as Administrator?
2. If NOT admin              → Relaunch itself via PowerShell Start-Process -Verb RunAs
3. If admin                  → Run the corresponding .ps1 script
4. After script finishes     → Show "Press any key to exit..." and wait
```

`download-php.bat` also passes `%*` (any command-line arguments) through to the PS1,
so `download-php 7.4` works from the command line.

### How `switch-php.ps1` Works (Code Structure)

```
CONFIGURATION section (lines 15-29)
  → phpVersions array — add new PHP versions here
  → xamppDir — where XAMPP is installed
  → phpSymlinkPath — the junction location

FUNCTIONS section (lines 31-333)
  Show-Header             → Draws the title screen
  Get-CurrentPhpVersion   → Runs php.exe -v to show active version
  Show-Menu               → Lists available PHP versions
  Get-UserChoice          → Reads and validates user menu input
  Switch-PhpVersion       → Main switching: junction + config updates
  Get-ApacheModuleName    → Reads DLL's PE export table to find module name
  Update-ApacheConfig     → Fixes LoadModule, LoadFile, IfModule in httpd-xampp.conf
  Ensure-PhpIni           → Copies php.ini-development if php.ini missing
  Fix-ExtensionDir        → Fixes extension_dir to use junction-safe path

MAIN LOOP (lines 336-384)
  → Shows header, current version, menu
  → Loops until user picks a valid version or exits
```

### How `download-php.ps1` Works (Code Structure)

```
PARAMETERS (line 13-14)
  → -Version [string] — optional, if omitted shows menu

CONFIGURATION (lines 17-36)
  → $versions — array of available PHP versions with labels and URLs
  → $urls — hashtable mapping version keys to download URLs

MENU (lines 38-62)
  → If no -Version argument, show interactive menu with [installed] badges

DOWNLOAD (lines 64-96)
  → Validate version, download zip to temp folder with error handling

EXTRACT (lines 98-112)
  → Remove old folder, create new one, extract zip with error handling

PHP.INI (lines 114-129)
  → Copy php.ini-development → php.ini
  → Uncomment extension=mysqli, curl, pdo_mysql, etc.
  → Set extension_dir to C:\xampp\php\ext (junction-safe)

CLEANUP + DONE (lines 131-146)
  → Delete temp zip, show success message with next steps
```

---

## Adding a New PHP Version

1. **Download** the TS x64 build:
   - `download-php.bat 8.4` (if in the list)
   - Or manually download and extract to `C:\xampp\php84`
2. **Ensure** `php.ini` exists in the folder (download-php does this automatically)
3. **Add** an entry to `switch-php.ps1` line 19-24:

```powershell
$phpVersions = @(
    @{ Id = 1; Label = "PHP 7.4"; Folder = "php74"; MinLaravel = "6.x";  MaxLaravel = "8.x"   },
    @{ Id = 6; Label = "PHP 8.4"; Folder = "php84"; MinLaravel = "12.x"; MaxLaravel = "12.x"  }
)
```

No other code changes needed — the module name detection and config updates work
with any PHP version automatically.

---

## Requirements

- Windows 10 / 11
- PowerShell 5.1+
- XAMPP installed at `C:\xampp`
- Administrator privileges
- Visual C++ Redistributable (install the latest from Microsoft)

---

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| "Access Denied" | Not running as Administrator | Run the `.bat` file, it auto-elevates |
| "Folder does not exist" | Version folder not found | Download PHP first with `download-php.bat` |
| Apache still shows old PHP | Config not reloaded | Stop Apache, wait 5s, start again |
| "The mysqli extension is missing" | mysqli not enabled in php.ini | If using download-php, it enables mysqli automatically. If manual: uncomment `extension=mysqli` in php.ini |
| "Can't locate API module structure" | NTS (Non-Thread-Safe) PHP build | Download the **Thread-Safe** version (the script autodetects the module name, but NTS builds don't have apache2_4.dll at all) |
| "The procedure entry point could not be located" | Missing VC++ Redistributable | Install the latest VC++ from Microsoft |
| Download fails / URL not found | PHP version link changed | Check https://windows.php.net/downloads/releases/ for the correct URL, update `$urls` in `download-php.ps1` |
| php.ini changes not taking effect | extension_dir is wrong | Run `switch-php.bat` — it fixes extension_dir to use the junction path (`C:\xampp\php\ext`) |
| Window closes immediately | Old batch file | Both `.bat` files now have `pause` at the end and use self-elevation |
