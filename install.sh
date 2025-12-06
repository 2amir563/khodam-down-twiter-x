#!/bin/bash

# Twitter/X Video Downloader Installer
# Simple Version - Fixed Syntax Errors

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logo
show_logo() {
    clear
    echo -e "${BLUE}"
    echo "=============================================="
    echo "     TWITTER/X VIDEO DOWNLOADER"
    echo "         INSTALLATION SCRIPT"
    echo "=============================================="
    echo -e "${NC}"
}

# Print functions
info() { echo -e "${BLUE}[*] $1${NC}"; }
success() { echo -e "${GREEN}[✓] $1${NC}"; }
warning() { echo -e "${YELLOW}[!] $1${NC}"; }
error() { echo -e "${RED}[✗] $1${NC}"; }

# Install dependencies
install_deps() {
    info "Installing system dependencies..."
    
    # Update system
    if command -v apt &> /dev/null; then
        apt update -y
        apt install -y python3 python3-pip python3-venv git ffmpeg curl wget
    elif command -v yum &> /dev/null; then
        yum install -y python3 python3-pip git ffmpeg curl wget
    elif command -v dnf &> /dev/null; then
        dnf install -y python3 python3-pip git ffmpeg curl wget
    elif command -v pacman &> /dev/null; then
        pacman -Sy --noconfirm python python-pip git ffmpeg curl wget
    elif command -v apk &> /dev/null; then
        apk add python3 py3-pip git ffmpeg curl wget
    else
        warning "Could not detect package manager"
        info "Trying to install manually..."
        # Try to install python3 and pip
        if ! command -v python3 &> /dev/null; then
            error "Python3 not found. Please install manually."
            exit 1
        fi
    fi
    
    success "Dependencies installed"
}

# Install Python packages
install_python_packages() {
    info "Installing Python packages..."
    
    pip3 install --upgrade pip
    pip3 install yt-dlp
    
    success "Python packages installed"
}

# Create simple download script
create_simple_script() {
    info "Creating download script..."
    
    # Create directory
    mkdir -p /opt/twitter-downloader
    
    # Create simple Python script
    cat > /opt/twitter-downloader/download.py << 'PYEOF'
#!/usr/bin/env python3
import subprocess
import sys
import os

def main():
    print("Twitter/X Video Downloader")
    print("=" * 40)
    
    if len(sys.argv) > 1:
        # Command line mode
        url = sys.argv[1]
        if len(sys.argv) > 2:
            fmt = sys.argv[2]
        else:
            fmt = "best"
        
        print(f"URL: {url}")
        print(f"Format: {fmt}")
        print("Downloading...")
        
        cmd = f'yt-dlp -f {fmt} -o "%(title)s.%(ext)s" "{url}"'
        result = subprocess.run(cmd, shell=True)
        
        if result.returncode == 0:
            print("Download completed!")
        else:
            print("Download failed!")
        
        sys.exit(result.returncode)
    
    # Interactive mode
    while True:
        print("\nOptions:")
        print("1. Download video")
        print("2. Show available formats")
        print("3. Exit")
        
        try:
            choice = input("\nSelect option (1-3): ").strip()
            
            if choice == "1":
                url = input("Enter Twitter/X URL: ").strip()
                if not url:
                    continue
                
                fmt = input("Enter format (default: best): ").strip()
                if not fmt:
                    fmt = "best"
                
                print(f"\nDownloading with format: {fmt}")
                cmd = f'yt-dlp -f {fmt} -o "%(title)s.%(ext)s" "{url}"'
                subprocess.run(cmd, shell=True)
                
            elif choice == "2":
                url = input("Enter Twitter/X URL: ").strip()
                if url:
                    subprocess.run(f'yt-dlp -F "{url}"', shell=True)
            
            elif choice == "3":
                print("Goodbye!")
                break
            
            else:
                print("Invalid choice!")
                
        except KeyboardInterrupt:
            print("\nGoodbye!")
            break
        except Exception as e:
            print(f"Error: {e}")

if __name__ == "__main__":
    main()
PYEOF
    
    # Give execute permission
    chmod +x /opt/twitter-downloader/download.py
    
    # Create bash wrapper
    cat > /usr/local/bin/twitter-dl << 'EOF'
#!/bin/bash
python3 /opt/twitter-downloader/download.py "$@"
EOF
    
    chmod +x /usr/local/bin/twitter-dl
    
    # Create quick download command
    cat > /usr/local/bin/twitter-download << 'EOF'
#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: twitter-download <url> [format]"
    echo "Example: twitter-download https://twitter.com/... best"
    exit 1
fi

URL="$1"
FORMAT="${2:-best}"

echo "Downloading: $URL"
echo "Format: $FORMAT"
yt-dlp -f "$FORMAT" -o "%(title)s.%(ext)s" "$URL"
EOF
    
    chmod +x /usr/local/bin/twitter-download
    
    success "Scripts created"
}

# Create advanced download script
create_advanced_script() {
    info "Creating advanced download script..."
    
    cat > /opt/twitter-downloader/advanced.py << 'PYEOF'
#!/usr/bin/env python3
import subprocess
import json
import os

class TwitterDownloader:
    def get_formats(self, url):
        """Get available formats"""
        cmd = ['yt-dlp', '-F', '--no-warnings', url]
        result = subprocess.run(cmd, capture_output=True, text=True)
        return result.stdout if result.returncode == 0 else None
    
    def get_info(self, url):
        """Get video info"""
        cmd = ['yt-dlp', '--skip-download', '--dump-json', '--no-warnings', url]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0:
            try:
                return json.loads(result.stdout)
            except:
                return None
        return None
    
    def download(self, url, fmt):
        """Download video"""
        cmd = ['yt-dlp', '-f', fmt, '-o', '%(title)s.%(ext)s', url]
        return subprocess.run(cmd).returncode
    
    def run(self):
        """Run interactive downloader"""
        print("\n" + "="*50)
        print("    TWITTER/X VIDEO DOWNLOADER - ADVANCED")
        print("="*50)
        
        while True:
            print("\nEnter Twitter/X URL (or 'exit' to quit):")
            url = input("> ").strip()
            
            if url.lower() == 'exit':
                break
            
            if not url:
                continue
            
            # Get info
            info = self.get_info(url)
            if info:
                print(f"\nTitle: {info.get('title', 'N/A')}")
                print(f"Duration: {info.get('duration_string', 'N/A')}")
            
            # Get formats
            print("\nGetting available formats...")
            formats = self.get_formats(url)
            if formats:
                print(formats)
            else:
                print("Could not get formats")
                continue
            
            # Get format choice
            fmt = input("\nEnter format code (default: best): ").strip()
            if not fmt:
                fmt = "best"
            
            # Confirm
            confirm = input(f"\nDownload with format '{fmt}'? (y/N): ").strip().lower()
            if confirm == 'y':
                print("\nDownloading...")
                if self.download(url, fmt) == 0:
                    print("\nDownload completed successfully!")
                else:
                    print("\nDownload failed!")
            
            # Another?
            another = input("\nDownload another? (y/N): ").strip().lower()
            if another != 'y':
                break

if __name__ == "__main__":
    dl = TwitterDownloader()
    dl.run()
PYEOF
    
    chmod +x /opt/twitter-downloader/advanced.py
    
    cat > /usr/local/bin/twitter-dl-advanced << 'EOF'
#!/bin/bash
python3 /opt/twitter-downloader/advanced.py
EOF
    
    chmod +x /usr/local/bin/twitter-dl-advanced
    
    success "Advanced script created"
}

# Setup aliases
setup_aliases() {
    info "Setting up aliases..."
    
    # Create aliases in bashrc
    cat >> ~/.bashrc << 'EOF'

# Twitter Downloader Aliases
alias tdl='/usr/local/bin/twitter-dl'
alias twitter-download='/usr/local/bin/twitter-download'
alias tdl-adv='/usr/local/bin/twitter-dl-advanced'
EOF
    
    # Also for root if not already
    if [ -f /root/.bashrc ] && ! grep -q "tdl" /root/.bashrc; then
        cat >> /root/.bashrc << 'EOF'

# Twitter Downloader Aliases
alias tdl='/usr/local/bin/twitter-dl'
alias twitter-download='/usr/local/bin/twitter-download'
EOF
    fi
    
    success "Aliases added"
}

# Show completion
show_completion() {
    echo -e "${GREEN}"
    echo "=============================================="
    echo "     INSTALLATION COMPLETE!"
    echo "=============================================="
    echo -e "${NC}"
    
    echo -e "\n${BLUE}Available Commands:${NC}"
    echo "  tdl                 - Simple downloader"
    echo "  twitter-download    - Quick download"
    echo "  tdl-adv            - Advanced downloader"
    echo "  yt-dlp             - Direct yt-dlp usage"
    
    echo -e "\n${BLUE}Usage Examples:${NC}"
    echo '  tdl'
    echo '  twitter-download "https://twitter.com/user/status/123"'
    echo '  twitter-download "https://x.com/user/status/123" "best"'
    echo '  yt-dlp -F "https://twitter.com/user/status/123"'
    
    echo -e "\n${BLUE}Quick Test:${NC}"
    echo '  tdl'
    echo '  (Then follow prompts)'
    
    echo -e "\n${YELLOW}Note:${NC} Restart terminal or run: ${BLUE}source ~/.bashrc${NC}"
}

# Main installation
main() {
    show_logo
    install_deps
    install_python_packages
    create_simple_script
    create_advanced_script
    setup_aliases
    show_completion
}

# Run
main
