#!/usr/bin/env bash

set -uo pipefail

CONFIG_FILE="$HOME/.mangler_config"

if [[ ! -f "$CONFIG_FILE" ]]; then
    cat <<EOF > "$CONFIG_FILE"
# Mangler-HUB Configuration File
CITY="Lelystad"
THEME="default"
EOF
fi

CITY=$(grep -E '^CITY=' "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '"' || echo "Lelystad")
THEME=$(grep -E '^THEME=' "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '"' || echo "default")

case "$THEME" in
    "cyberpunk")
        RED='\033[0;31m'; GREEN='\033[0;35m'; YELLOW='\033[1;33m'
        BLUE='\033[0;36m'; MAGENTA='\033[1;35m'; CYAN='\033[1;36m'
        BOLD='\033[1m'; RESET='\033[0m'
        ;;
    "matrix")
        RED='\033[0;32m'; GREEN='\033[1;32m'; YELLOW='\033[0;32m'
        BLUE='\033[0;32m'; MAGENTA='\033[1;32m'; CYAN='\033[0;32m'
        BOLD='\033[1m'; RESET='\033[0m'
        ;;
    "monochrome")
        RED=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; CYAN=''; BOLD=''; RESET=''
        ;;
    *) # Default Theme
        if [[ -t 1 ]]; then
            RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
            BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; CYAN='\033[0;36m'
            BOLD='\033[1m'; RESET='\033[0m'
        else
            RED=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; CYAN=''; BOLD=''; RESET=''
        fi
        ;;
esac

get_cols() {
    local cols
    cols=$(tput cols 2>/dev/null || echo "${COLUMNS:-60}")
    echo "$cols"
}

line() {
    local width
    width=$(get_cols)
    printf '%*s\n' "$width" '' | tr ' ' '='
}

header() {
    clear 2>/dev/null || true
    local width title padding
    width=$(get_cols)
    title="Mangler-HUB v1.0"
    padding=$(( (width + ${#title}) / 2 ))

    echo -e "${GREEN}"
    line
    printf "%*s\n" "$padding" "$title"
    line
    echo -e "${RESET}"
}

pause() {
    echo
    read -rp "Press [Enter] to continue..." || true
}

have() {
    command -v "$1" >/dev/null 2>&1
}

fetch() {
    curl -fsSL --connect-timeout 5 --max-time 10 "$1" 2>/dev/null
}

open_url() {
    local url="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open "$url"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        start "$url" 2>/dev/null || explorer "$url"
    elif have xdg-open; then
        xdg-open "$url" >/dev/null 2>&1 &
    else
        echo -e "${YELLOW}Could not detect a default browser launcher.${RESET}"
        echo "Please visit: $url"
    fi
}

show_weather() {
    header
    echo -e "${CYAN}${BOLD}Local Weather (${CITY:-Default})${RESET}\n"

    if have curl; then
        fetch "https://wttr.in/${CITY}?format=4" || fetch "https://wttr.in/?format=4" || echo "Unable to retrieve weather data."
    else
        echo "curl is not installed."
    fi

    pause
}

show_quote() {
    header
    echo -e "${MAGENTA}${BOLD}Daily Motivation${RESET}\n"

    if ! have curl; then
        echo "curl is not installed."
        pause
        return
    fi

    if have jq; then
        fetch "https://zenquotes.io/api/random" |
            jq -r '.[0] | "\"\(.q)\"\n— \(.a)"' 2>/dev/null ||
            echo "Unable to retrieve a quote."
    else
        echo "Tip: Install 'jq' for formatted quotes."
        fetch "https://zenquotes.io/api/random" || echo "Unable to retrieve a quote."
    fi

    pause
}

memory_info() {
    if have free; then
        free -h | awk '/^Mem:/ {printf "Used: %s / %s (Free: %s)\n", $3, $2, $4}'
    elif [[ "$OSTYPE" == darwin* ]]; then
        local pages_free pages_active pages_inactive page_size
        pages_free=$(vm_stat | awk '/Pages free/ {print $3}' | tr -d '.')
        pages_active=$(vm_stat | awk '/Pages active/ {print $3}' | tr -d '.')
        pages_inactive=$(vm_stat | awk '/Pages inactive/ {print $3}' | tr -d '.')
        page_size=4096
        local free_mb=$((pages_free * page_size / 1024 / 1024))
        local used_mb=$(((pages_active + pages_inactive) * page_size / 1024 / 1024))
        printf "Used: %d MB | Free: %d MB\n" "$used_mb" "$free_mb"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        powershell.exe -Command "Get-CimInstance Win32_OperatingSystem | Select-Object @{N='FreeRAM';E={[math]::round(\$_.FreePhysicalMemory/1MB,2)}}, @{N='TotalRAM';E={[math]::round(\$_.TotalVisibleMemorySize/1MB,2)}}" 2>/dev/null || echo "Memory info unavailable on Windows."
    else
        echo "Memory information unavailable."
    fi
}

cpu_load() {
    if [[ "$OSTYPE" == darwin* ]]; then
        uptime | sed 's/^.*load averages: //'
    else
        uptime | sed 's/^.*load average: //'
    fi
}

uptime_info() {
    uptime | sed 's/^.*up \([^,]*\),.*/Up: \1/'
}

show_sysmon() {
    header
    echo -e "${GREEN}${BOLD}System Monitor${RESET}\n"

    echo -e "${YELLOW}Hostname:${RESET}   $(hostname)"
    echo -e "${YELLOW}OS:${RESET}         $(uname -sr)"
    echo -e "${YELLOW}Kernel:${RESET}     $(uname -r)"
    echo -e "${YELLOW}Uptime:${RESET}     $(uptime_info)"
    echo -e "${YELLOW}CPU Load:${RESET}   $(cpu_load)"

    echo
    echo -e "${YELLOW}Memory:${RESET}"
    memory_info

    echo
    echo -e "${YELLOW}Disk Usage:${RESET}"
    df -h / | awk 'NR==2 {printf "Root: %s used of %s (%s)\n", $3, $2, $5}'

    echo
    echo -e "${YELLOW}Top CPU Processes:${RESET}"
    if [[ "$OSTYPE" == darwin* ]]; then
        ps -eo pid,comm,%cpu,%mem -c -r | head -n 6
    else
        ps -eo pid,comm,%cpu,%mem --sort=-%cpu 2>/dev/null | head -n 6 || ps aux | head -n 6
    fi

    pause
}

show_thermals() {
    header
    echo -e "${CYAN}${BOLD}System Temperatures${RESET}\n"

    if have sensors; then
        sensors
    elif [[ "$OSTYPE" == darwin* ]]; then
        if have osx-cpu-temp; then
            osx-cpu-temp
        else
            echo "Install 'osx-cpu-temp' for CPU temperature."
            echo "Run: brew install osx-cpu-temp"
        fi
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        powershell.exe -Command "Get-CimInstance -Namespace root/WMI -ClassName MSAcpi_ThermalZoneTemperature 2>\$null | Select-Object @{N='CPU Temp (°C)';E={(\$_.CurrentTemperature - 2732) / 10}}" || echo "Thermal data unavailable on this Windows machine."
    else
        echo "Temperature monitoring not available."
        echo "Install 'lm-sensors' and run: sudo sensors-detect"
    fi

    pause
}

show_network() {
    header
    echo -e "${BLUE}${BOLD}Network Information${RESET}\n"

    if have curl; then
        echo -e "${YELLOW}Public IP:${RESET}"
        fetch "https://ifconfig.me" || echo "Unavailable"
        echo
    else
        echo "curl is not installed."
    fi

    echo -e "${YELLOW}Interface Summary:${RESET}"
    if have ip; then
        ip -brief address
    elif have ifconfig; then
        ifconfig | grep -E '^[a-z0-9]+|inet '
    elif have ipconfig; then
        ipconfig | grep -E "IPv4 Address|Adapter"
    else
        echo "Network interface tools unavailable."
    fi

    pause
}

show_latency() {
    header
    echo -e "${CYAN}${BOLD}Network Latency & Speed Test${RESET}\n"

    echo -e "${YELLOW}Testing latency to Cloudflare (1.1.1.1)...${RESET}"
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        ping -n 4 1.1.1.1 | grep -E "Average|Loss" || echo "Ping failed."
    else
        ping -c 4 1.1.1.1 | grep -E "packets transmitted|rtt|min/avg/max" || echo "Ping failed."
    fi

    echo
    echo -e "${YELLOW}Testing latency to Google DNS (8.8.8.8)...${RESET}"
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        ping -n 4 8.8.8.8 | grep -E "Average|Loss" || echo "Ping failed."
    else
        ping -c 4 8.8.8.8 | grep -E "packets transmitted|rtt|min/avg/max" || echo "Ping failed."
    fi

    pause
}

edit_config() {
    header
    echo -e "${MAGENTA}${BOLD}Script Settings / Config${RESET}\n"
    echo -e "Config path: ${YELLOW}$CONFIG_FILE${RESET}\n"
    echo "Current Settings:"
    echo -e "  • City:  ${CYAN}$CITY${RESET}"
    echo -e "  • Theme: ${CYAN}$THEME${RESET}"
    echo
    echo "To edit options, change the text inside $CONFIG_FILE"
    echo "Themes available: default, cyberpunk, matrix, monochrome"
    echo

    if have nano; then
        read -rp "Open config file in nano? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            nano "$CONFIG_FILE"
            echo -e "${GREEN}Config saved! Restart script to apply all changes.${RESET}"
        fi
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        read -rp "Open config in Notepad? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            notepad.exe "$CONFIG_FILE"
            echo -e "${GREEN}Config saved! Restart script to apply all changes.${RESET}"
        fi
    else
        echo "Edit '$CONFIG_FILE' using your preferred text editor."
    fi

    pause
}

open_github() {
    local url="https://github.com/TheMangler47/BashScripts"
    header
    echo -e "${MAGENTA}${BOLD}Open GitHub Repository${RESET}\n"
    echo -e "${CYAN}Opening link in default browser...${RESET}"
    echo -e "${YELLOW}$url${RESET}\n"
    open_url "$url"
    pause
}

while true; do
    header
    echo -e "${BOLD}Choose an option${RESET}\n"
    echo "1) Weather"
    echo "2) Motivational Quote"
    echo "3) System Monitor"
    echo "4) System Thermals"
    echo "5) Network Info"
    echo "6) Latency / Ping Test"
    echo "7) Settings / Edit Config"
    echo "8) Open GitHub Repo"
    echo "9) Refresh Dashboard"
    echo "10) Quit"
    echo

    read -rp "Selection [1-10]: " choice || exit 0

    case "$choice" in
        1) show_weather ;;
        2) show_quote ;;
        3) show_sysmon ;;
        4) show_thermals ;;
        5) show_network ;;
        6) show_latency ;;
        7) edit_config ;;
        8) open_github ;;
        9) continue ;;
        10|q|Q|quit|exit)
            echo -e "\n${YELLOW}Goodbye!${RESET}\n"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid selection.${RESET}"
            sleep 1
            ;;
    esac
done