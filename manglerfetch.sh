#!/usr/bin/env bash

VERSION="0.1.0"
MODE="normal"
THEME="blue"
COLOR=true

show_help() {
    cat <<EOF
manglerfetch $VERSION

Usage:
  manglerfetch [options]

Options:
  --minimal, -m       Show compact information
  --full, -f          Show extended information
  --theme, -t NAME    Set color theme
  --no-color          Disable colors
  --version, -v       Show version
  --help, -h          Show help

Themes:
  blue cyan green red purple yellow white

Examples:
  manglerfetch
  manglerfetch --minimal
  manglerfetch --full
  manglerfetch --theme cyan
  manglerfetch --no-color
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --minimal|-m)
            MODE="minimal"
            ;;
        --full|-f)
            MODE="full"
            ;;
        --theme|-t)
            [[ -z "${2:-}" ]] && {
                echo "manglerfetch: --theme requires a name"
                exit 1
            }
            THEME="$2"
            shift
            ;;
        --no-color)
            COLOR=false
            ;;
        --version|-v)
            echo "manglerfetch $VERSION"
            exit 0
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "manglerfetch: unknown option '$1'"
            echo "Run 'manglerfetch --help' for help."
            exit 1
            ;;
    esac
    shift
done

setup_colors() {
    RESET=""
    BOLD=""
    DIM=""
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    MAGENTA=""
    CYAN=""
    WHITE=""

    [[ "$COLOR" != true || ! -t 1 ]] && return

    RESET=$'\033[0m'
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    RED=$'\033[38;5;203m'
    GREEN=$'\033[38;5;114m'
    YELLOW=$'\033[38;5;221m'
    BLUE=$'\033[38;5;75m'
    MAGENTA=$'\033[38;5;177m'
    CYAN=$'\033[38;5;81m'
    WHITE=$'\033[97m'
}

setup_colors

case "$THEME" in
    blue)
        ACCENT="$BLUE"
        LOGO="$BLUE"
        ;;
    cyan)
        ACCENT="$CYAN"
        LOGO="$CYAN"
        ;;
    green)
        ACCENT="$GREEN"
        LOGO="$GREEN"
        ;;
    red)
        ACCENT="$RED"
        LOGO="$RED"
        ;;
    purple|magenta)
        ACCENT="$MAGENTA"
        LOGO="$MAGENTA"
        ;;
    yellow)
        ACCENT="$YELLOW"
        LOGO="$YELLOW"
        ;;
    white)
        ACCENT="$WHITE"
        LOGO="$WHITE"
        ;;
    *)
        echo "manglerfetch: unknown theme '$THEME'"
        echo "Available themes: blue, cyan, green, red, purple, yellow, white"
        exit 1
        ;;
esac

PS_CMD=""

if command -v powershell.exe >/dev/null 2>&1; then
    PS_CMD="powershell.exe"
elif command -v pwsh.exe >/dev/null 2>&1; then
    PS_CMD="pwsh.exe"
elif command -v pwsh >/dev/null 2>&1; then
    PS_CMD="pwsh"
fi

if [[ -z "$PS_CMD" ]]; then
    echo "manglerfetch: PowerShell was not found."
    exit 1
fi

if [[ "$MODE" == "minimal" ]]; then
    SYSTEM_DATA="$("$PS_CMD" -NoProfile -NonInteractive -Command '
$ErrorActionPreference="SilentlyContinue"
$os=Get-CimInstance Win32_OperatingSystem
$cpu=Get-CimInstance Win32_Processor|Select-Object -First 1
$computer=Get-CimInstance Win32_ComputerSystem
$gpus=@(Get-CimInstance Win32_VideoController)
$disk=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID=''C:''"
$ramTotal=[math]::Round($computer.TotalPhysicalMemory/1GB,1)
$ramFree=[math]::Round($os.FreePhysicalMemory/1MB,1)
$ramUsed=[math]::Round($ramTotal-$ramFree,1)
$gpuNames=($gpus|Where-Object Name|Select-Object -ExpandProperty Name)-join ", "
if($disk){
$diskTotal=[math]::Round($disk.Size/1GB,1)
$diskUsed=[math]::Round(($disk.Size-$disk.FreeSpace)/1GB,1)
}
$uptime=(Get-Date)-$os.LastBootUpTime
if($uptime.Days -gt 0){$uptimeText="$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"}
elseif($uptime.Hours -gt 0){$uptimeText="$($uptime.Hours)h $($uptime.Minutes)m"}
else{$uptimeText="$($uptime.Minutes)m"}
if($env:WT_SESSION){$terminal="Windows Terminal"}
elseif($env:TERM_PROGRAM){$terminal=$env:TERM_PROGRAM}
elseif($env:ConEmuANSI){$terminal="ConEmu"}
elseif($env:TERM){$terminal=$env:TERM}
else{$terminal="Unknown"}
"USERNAME=$env:USERNAME"
"HOSTNAME=$env:COMPUTERNAME"
"OS=$($os.Caption)"
"VERSION=$($os.Version)"
"BUILD=$($os.BuildNumber)"
"ARCH=$($os.OSArchitecture)"
"CPU=$($cpu.Name)"
"CPU_USAGE=$($cpu.LoadPercentage)"
"GPU=$gpuNames"
"RAM_USED=$ramUsed"
"RAM_TOTAL=$ramTotal"
"DISK_USED=$diskUsed"
"DISK_TOTAL=$diskTotal"
"UPTIME=$uptimeText"
"TERMINAL=$terminal"
' 2>/dev/null)"
else
    SYSTEM_DATA="$("$PS_CMD" -NoProfile -NonInteractive -Command '
$ErrorActionPreference="SilentlyContinue"

$os=Get-CimInstance Win32_OperatingSystem
$cpu=Get-CimInstance Win32_Processor|Select-Object -First 1
$computer=Get-CimInstance Win32_ComputerSystem
$gpus=@(Get-CimInstance Win32_VideoController)
$bios=Get-CimInstance Win32_BIOS
$board=Get-CimInstance Win32_BaseBoard
$memory=@(Get-CimInstance Win32_PhysicalMemory)
$batteries=@(Get-CimInstance Win32_Battery)
$disk=Get-CimInstance Win32_LogicalDisk|Where-Object DeviceID -eq $env:SystemDrive|Select-Object -First 1

$ramTotal=[math]::Round($computer.TotalPhysicalMemory/1GB,1)
$ramFree=[math]::Round($os.FreePhysicalMemory/1MB,1)
$ramUsed=[math]::Round($ramTotal-$ramFree,1)

$gpuNames=($gpus|Where-Object Name|Select-Object -ExpandProperty Name)-join ", "

$gpuVramList = foreach ($gpu in $gpus) {
    $vramBytes = 0
    $pnpId = $gpu.PNPDeviceID
    
    if ($pnpId) {
        $regKeys = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0*" -ErrorAction SilentlyContinue
        foreach ($key in $regKeys) {
            if ($key.MatchingDeviceId -and $pnpId -like "*$($key.MatchingDeviceId)*") {
                if ($key."HardwareInformation.qwMemorySize") {
                    $vramBytes = $key."HardwareInformation.qwMemorySize"
                    break
                }
            }
        }
    }
    
    if (-not $vramBytes -or $vramBytes -eq 0) {
        $regSizes = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0*" -Name "HardwareInformation.qwMemorySize" -ErrorAction SilentlyContinue
        if ($regSizes) {
            $vramBytes = ($regSizes | Select-Object -ExpandProperty "HardwareInformation.qwMemorySize" -First 1)
        }
    }

    if (-not $vramBytes -or $vramBytes -eq 0) {
        $vramBytes = $gpu.AdapterRAM
    }

    if ($vramBytes -and $vramBytes -gt 0) {
        "$([math]::Round($vramBytes / 1GB, 1)) GiB"
    }
}

$gpuVram = ($gpuVramList | Where-Object { $_ }) -join ", "
if (-not $gpuVram) { $gpuVram = "Unknown" }

if($disk){
$diskTotal=[math]::Round($disk.Size/1GB,1)
$diskUsed=[math]::Round(($disk.Size-$disk.FreeSpace)/1GB,1)
$diskFree=[math]::Round($disk.FreeSpace/1GB,1)
}

$uptime=(Get-Date)-$os.LastBootUpTime
if($uptime.Days -gt 0){$uptimeText="$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"}
elseif($uptime.Hours -gt 0){$uptimeText="$($uptime.Hours)h $($uptime.Minutes)m"}
else{$uptimeText="$($uptime.Minutes)m"}

$bootTime=$os.LastBootUpTime.ToString("yyyy-MM-dd HH:mm")

$ramSpeed=if($memory.Count){$memory[0].Speed}
$ramType=if($memory.Count){
switch($memory[0].SMBIOSMemoryType){
20{"DDR"}21{"DDR2"}22{"DDR2 FB-DIMM"}24{"DDR3"}26{"DDR4"}27{"DDR5"}default{"Unknown"}
}}
else{"Unknown"}

try{
$secureBoot=if(Confirm-SecureBootUEFI){"Enabled"}else{"Disabled"}
}catch{$secureBoot="Unavailable"}

try{
$tpm=Get-Tpm
if($tpm.TpmPresent){if($tpm.TpmReady){"Ready"}else{"Present"}}else{"Not Present"}
}catch{$tpm="Unavailable"}

if($batteries.Count){
$batteryPresent="yes"
$batteryPercent=$batteries[0].EstimatedChargeRemaining
$batteryStatus=switch($batteries[0].BatteryStatus){
1{"Discharging"}2{"AC / Charging"}3{"Fully Charged"}4{"Low"}5{"Critical"}6{"Charging"}7{"Charging / High"}8{"Charging / Low"}9{"Charging / Critical"}10{"Undefined"}11{"Partially Charged"}default{"Unknown"}
}
}

$adapter=Get-NetAdapter|Where-Object {$_.Status -eq "Up" -and $_.HardwareInterface}|Select-Object -First 1

if($adapter){
$network=$adapter.Name
$ipv4=Get-NetIPAddress -AddressFamily IPv4|Where-Object {$_.InterfaceIndex -eq $adapter.ifIndex -and $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*"}|Select-Object -First 1
$ipv6=Get-NetIPAddress -AddressFamily IPv6|Where-Object {$_.InterfaceIndex -eq $adapter.ifIndex -and $_.IPAddress -notlike "fe80::*"}|Select-Object -First 1
if($ipv4){$ip4=$ipv4.IPAddress}
if($ipv6){$ip6=$ipv6.IPAddress}
}

if($env:WT_SESSION){$terminal="Windows Terminal"}
elseif($env:TERM_PROGRAM){$terminal=$env:TERM_PROGRAM}
elseif($env:ConEmuANSI){$terminal="ConEmu"}
elseif($env:TERM){$terminal=$env:TERM}
else{$terminal="Unknown"}

if($env:MSYSTEM){$environment="Git Bash / MSYS2 ($env:MSYSTEM)"}
elseif($env:WSL_DISTRO_NAME){$environment="WSL ($env:WSL_DISTRO_NAME)"}
elseif($env:CYGWIN){$environment="Cygwin"}
else{$environment="Windows"}

"USERNAME=$env:USERNAME"
"HOSTNAME=$env:COMPUTERNAME"
"OS=$($os.Caption)"
"VERSION=$($os.Version)"
"BUILD=$($os.BuildNumber)"
"ARCH=$($os.OSArchitecture)"
"MANUFACTURER=$($computer.Manufacturer)"
"MODEL=$($computer.Model)"
"CPU=$($cpu.Name)"
"CPU_USAGE=$($cpu.LoadPercentage)"
"CPU_CORES=$($cpu.NumberOfCores)"
"CPU_THREADS=$($cpu.NumberOfLogicalProcessors)"
"CPU_SPEED=$([math]::Round($cpu.MaxClockSpeed/1000,2))"
"GPU=$gpuNames"
"GPU_VRAM=$gpuVram"
"RAM_USED=$ramUsed"
"RAM_TOTAL=$ramTotal"
"RAM_SPEED=$ramSpeed"
"RAM_TYPE=$ramType"
"DISK_USED=$diskUsed"
"DISK_TOTAL=$diskTotal"
"DISK_FREE=$diskFree"
"UPTIME=$uptimeText"
"BOOT_TIME=$bootTime"
"BIOS_VENDOR=$($bios.Manufacturer)"
"BIOS_VERSION=$($bios.SMBIOSBIOSVersion)"
"BIOS_DATE=$(if($bios.ReleaseDate){$bios.ReleaseDate.ToString("yyyy-MM-dd")})"
"MOTHERBOARD_VENDOR=$($board.Manufacturer)"
"MOTHERBOARD=$($board.Product)"
"SECURE_BOOT=$secureBoot"
"TPM=$tpm"
"BATTERY_PRESENT=$batteryPresent"
"BATTERY_PERCENT=$batteryPercent"
"BATTERY_STATUS=$batteryStatus"
"NETWORK=$network"
"IPV4=$ip4"
"IPV6=$ip6"
"TERMINAL=$terminal"
"ENVIRONMENT=$environment"
' 2>/dev/null)"
fi

# Clean carriage returns from PowerShell string before parsing
SYSTEM_DATA="${SYSTEM_DATA//$'\r'/}"

while IFS='=' read -r key value; do
    case "$key" in
        USERNAME) USERNAME="$value" ;;
        HOSTNAME) HOSTNAME="$value" ;;
        OS) OS="$value" ;;
        VERSION) OS_VERSION="$value" ;;
        BUILD) OS_BUILD="$value" ;;
        ARCH) ARCH="$value" ;;
        MANUFACTURER) MANUFACTURER="$value" ;;
        MODEL) MODEL="$value" ;;
        CPU) CPU="$value" ;;
        CPU_USAGE) CPU_USAGE="$value" ;;
        CPU_CORES) CPU_CORES="$value" ;;
        CPU_THREADS) CPU_THREADS="$value" ;;
        CPU_SPEED) CPU_SPEED="$value" ;;
        GPU) GPU="$value" ;;
        GPU_VRAM) GPU_VRAM="$value" ;;
        RAM_USED) RAM_USED="$value" ;;
        RAM_TOTAL) RAM_TOTAL="$value" ;;
        RAM_SPEED) RAM_SPEED="$value" ;;
        RAM_TYPE) RAM_TYPE="$value" ;;
        DISK_USED) DISK_USED="$value" ;;
        DISK_TOTAL) DISK_TOTAL="$value" ;;
        DISK_FREE) DISK_FREE="$value" ;;
        UPTIME) UPTIME="$value" ;;
        BOOT_TIME) BOOT_TIME="$value" ;;
        BIOS_VENDOR) BIOS_VENDOR="$value" ;;
        BIOS_VERSION) BIOS_VERSION="$value" ;;
        BIOS_DATE) BIOS_DATE="$value" ;;
        MOTHERBOARD_VENDOR) MOTHERBOARD_VENDOR="$value" ;;
        MOTHERBOARD) MOTHERBOARD="$value" ;;
        SECURE_BOOT) SECURE_BOOT="$value" ;;
        TPM) TPM="$value" ;;
        BATTERY_PRESENT) BATTERY_PRESENT="$value" ;;
        BATTERY_PERCENT) BATTERY_PERCENT="$value" ;;
        BATTERY_STATUS) BATTERY_STATUS="$value" ;;
        NETWORK) NETWORK="$value" ;;
        IPV4) IPV4="$value" ;;
        IPV6) IPV6="$value" ;;
        TERMINAL) TERMINAL="$value" ;;
        ENVIRONMENT) ENVIRONMENT="$value" ;;
    esac
done <<< "$SYSTEM_DATA"

USERNAME="${USERNAME:-${USERNAME_WIN:-${USER:-Unknown}}}"
HOSTNAME="${HOSTNAME:-$(hostname 2>/dev/null || echo Unknown)}"
OS="${OS:-Windows}"
OS_VERSION="${OS_VERSION:-Unknown}"
OS_BUILD="${OS_BUILD:-Unknown}"
ARCH="${ARCH:-${PROCESSOR_ARCHITECTURE:-Unknown}}"
MANUFACTURER="${MANUFACTURER:-Unknown}"
MODEL="${MODEL:-Unknown}"
CPU="${CPU:-Unknown}"
CPU_USAGE="${CPU_USAGE:-Unknown}"
CPU_CORES="${CPU_CORES:-Unknown}"
CPU_THREADS="${CPU_THREADS:-Unknown}"
CPU_SPEED="${CPU_SPEED:-Unknown}"
GPU="${GPU:-Unknown}"
GPU_VRAM="${GPU_VRAM:-Unknown}"
RAM_USED="${RAM_USED:-Unknown}"
RAM_TOTAL="${RAM_TOTAL:-Unknown}"
RAM_SPEED="${RAM_SPEED:-Unknown}"
RAM_TYPE="${RAM_TYPE:-Unknown}"
DISK_USED="${DISK_USED:-Unknown}"
DISK_TOTAL="${DISK_TOTAL:-Unknown}"
DISK_FREE="${DISK_FREE:-Unknown}"
UPTIME="${UPTIME:-Unknown}"
BOOT_TIME="${BOOT_TIME:-Unknown}"
BIOS_VENDOR="${BIOS_VENDOR:-Unknown}"
BIOS_VERSION="${BIOS_VERSION:-Unknown}"
BIOS_DATE="${BIOS_DATE:-Unknown}"
MOTHERBOARD_VENDOR="${MOTHERBOARD_VENDOR:-Unknown}"
MOTHERBOARD="${MOTHERBOARD:-Unknown}"
SECURE_BOOT="${SECURE_BOOT:-Unknown}"
TPM="${TPM:-Unknown}"
BATTERY_PRESENT="${BATTERY_PRESENT:-no}"
BATTERY_PERCENT="${BATTERY_PERCENT:-Unknown}"
BATTERY_STATUS="${BATTERY_STATUS:-Unknown}"
NETWORK="${NETWORK:-Unknown}"
IPV4="${IPV4:-Unknown}"
IPV6="${IPV6:-Unknown}"
TERMINAL="${TERMINAL:-Unknown}"
ENVIRONMENT="${ENVIRONMENT:-Windows}"
SHELL_NAME="Bash ${BASH_VERSION%%(*}"

label() {
    local k="$1"
    local v="$2"
    printf "  ${ACCENT}%-14s${RESET} %s\n" "$k:" "$v"
}

separator() {
    printf "  ${DIM}────────────────────────────────────────${RESET}\n"
}

print_logo() {
    printf "${LOGO}  __  __                         _            ${RESET}\n"
    printf "${LOGO} |  \\/  |                       | |           ${RESET}\n"
    printf "${LOGO} | \\  / | __ _ _ __   __ _  ___| | ___ _ __  ${RESET}\n"
    printf "${LOGO} | |\\/| |/ _\` | '_ \\ / _\` |/ _ \\ |/ _ \\ '__| ${RESET}\n"
    printf "${LOGO} | |  | | (_| | | | | (_| |  __/ |  __/ |    ${RESET}\n"
    printf "${LOGO} |_|  |_|\\__,_|_| |_|\\__, |\\___|_|\\___|_|    ${RESET}\n"
    printf "${LOGO}                      __/ |                  ${RESET}\n"
    printf "${LOGO}                     |___/                   ${RESET}\n"
    printf "${LOGO}  _____  _  _       _                        ${RESET}\n"
    printf "${LOGO} |  ___|| || |     | |                       ${RESET}\n"
    printf "${LOGO} | |_   | || |_ ___| |                       ${RESET}\n"
    printf "${LOGO} |  _|  |__   _/ _| ' \\                      ${RESET}\n"
    printf "${LOGO} |_|       |_| \\__|_||_|                     ${RESET}\n"
}

printf "\n"
print_logo
printf "\n"

printf "  ${BOLD}${ACCENT}%s${RESET}@${BOLD}%s${RESET}\n" "$USERNAME" "$HOSTNAME"
separator

if [[ "$MODE" == "minimal" ]]; then
    label "OS" "$OS"
    label "CPU" "$CPU"
    label "GPU" "$GPU"
    label "Memory" "$RAM_USED / $RAM_TOTAL GiB"
    label "Disk" "$DISK_USED / $DISK_TOTAL GiB"
    label "Uptime" "$UPTIME"
    label "Terminal" "$TERMINAL"
else
    label "OS" "$OS"
    label "Version" "$OS_VERSION (Build $OS_BUILD)"
    label "Host" "$MANUFACTURER $MODEL"
    label "Arch" "$ARCH"

    separator

    label "CPU" "$CPU"
    label "Usage" "$CPU_USAGE%"
    label "Cores" "$CPU_CORES cores / $CPU_THREADS threads"
    label "Clock" "$CPU_SPEED GHz"
    label "GPU" "$GPU"
    label "VRAM" "$GPU_VRAM"
    label "Memory" "$RAM_USED / $RAM_TOTAL GiB"

    [[ "$RAM_TYPE" != "Unknown" ]] && label "RAM Type" "$RAM_TYPE"
    [[ "$RAM_SPEED" != "Unknown" ]] && label "RAM Speed" "$RAM_SPEED MHz"

    label "Disk" "$DISK_USED / $DISK_TOTAL GiB"

    separator

    label "Uptime" "$UPTIME"
    label "Boot" "$BOOT_TIME"
    label "BIOS" "$BIOS_VENDOR $BIOS_VERSION"
    label "Board" "$MOTHERBOARD_VENDOR $MOTHERBOARD"

    if [[ "$MODE" == "full" ]]; then
        label "BIOS Date" "$BIOS_DATE"
        label "Secure Boot" "$SECURE_BOOT"
        label "TPM" "$TPM"
        label "Disk Free" "$DISK_FREE GiB"
    fi

    if [[ "$BATTERY_PRESENT" == "yes" ]]; then
        label "Battery" "$BATTERY_PERCENT% ($BATTERY_STATUS)"
    fi

    separator

    label "Network" "$NETWORK"
    label "IPv4" "$IPV4"

    if [[ "$MODE" == "full" && "$IPV6" != "Unknown" ]]; then
        label "IPv6" "$IPV6"
    fi

    label "Terminal" "$TERMINAL"
    label "Environment" "$ENVIRONMENT"
    label "Shell" "$SHELL_NAME"
fi

printf "\n"
printf "  ${RED}███${RESET}"
printf "${YELLOW}███${RESET}"
printf "${GREEN}███${RESET}"
printf "${CYAN}███${RESET}"
printf "${BLUE}███${RESET}"
printf "${MAGENTA}███${RESET}"
printf "${WHITE}███${RESET}"
printf "\n\n"

if [[ "${MANGLERFETCH_NO_PAUSE:-0}" != "1" ]]; then
    read -rp "Press Enter to exit..."
fi