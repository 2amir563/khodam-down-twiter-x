#!/bin/bash

# Twitter/X Video Downloader Installer
# Version: 2.0
# Author: 2amir563

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logo
show_logo() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════╗"
    echo "║                                                  ║"
    echo "║         TWITTER/X VIDEO DOWNLOADER              ║"
    echo "║               INSTALLATION SCRIPT                ║"
    echo "║                                                  ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Print functions
print_info() {
    echo -e "${CYAN}[*] $1${NC}"
}

print_success() {
    echo -e "${GREEN}[✓] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[!] $1${NC}"
}

print_error() {
    echo -e "${RED}[✗] $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_warning "This script is recommended to run as root"
        print_info "Continuing with current user..."
    fi
}

# Detect OS and package manager
detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    elif command -v apk &> /dev/null; then
        echo "apk"
    else
        echo "unknown"
    fi
}

# Install system dependencies
install_dependencies() {
    print_info "Installing system dependencies..."
    
    local pm=$(detect_package_manager)
    
    case $pm in
        "apt")
            apt-get update -y
            apt-get install -y python3 python3-pip python3-venv git ffmpeg curl wget
            ;;
        "yum")
            yum install -y epel-release
            yum install -y python3 python3-pip git ffmpeg curl wget
            ;;
        "dnf")
            dnf install -y python3 python3-pip git ffmpeg curl wget
            ;;
        "pacman")
            pacman -Sy --noconfirm python python-pip git ffmpeg curl wget
            ;;
        "apk")
            apk update
            apk add python3 py3-pip git ffmpeg curl wget
            ;;
        *)
            print_error "Unsupported package manager. Please install manually:"
            print_info "Python3, pip3, git, ffmpeg, curl, wget"
            exit 1
            ;;
    esac
    
    print_success "System dependencies installed"
}

# Install Python packages
install_python_packages() {
    print_info "Installing Python packages..."
    
    # Upgrade pip
    pip3 install --upgrade pip
    
    # Install required packages
    pip3 install yt-dlp requests colorama
    
    print_success "Python packages installed"
}

# Create main download script
create_download_script() {
    print_info "Creating download script..."
    
    # Create the main script directory
    mkdir -p /opt/twitter-dl
    
    # Create main Python script
    cat > /opt/twitter-dl/twitter_downloader.py << 'EOF'
#!/usr/bin/env python3
# Twitter/X Video Downloader
# Simple and easy to use

import os
import sys
import subprocess
import json
from datetime import datetime

class TwitterDownloader:
    def __init__(self):
        self.script_dir = "/opt/twitter-dl"
        self.download_dir = os.path.expanduser("~/Downloads/Twitter")
        
        # Create download directory
        os.makedirs(self.download_dir, exist_ok=True)
    
    def clear_screen(self):
        """Clear terminal screen"""
        os.system('clear' if os.name == 'posix' else 'cls')
    
    def show_banner(self):
        """Show application banner"""
        print("\n" + "="*60)
        print("        TWITTER/X VIDEO DOWNLOADER")
        print("="*60 + "\n")
    
    def check_ytdlp(self):
        """Check if yt-dlp is installed"""
        try:
            subprocess.run(['yt-dlp', '--version'], 
                          capture_output=True, check=True)
            return True
        except:
            return False
    
    def get_video_info(self, url):
        """Get video information"""
        print("\n📡 Getting video information...")
        
        try:
            # Get video info in JSON format
            cmd = [
                'yt-dlp',
                '--skip-download',
                '--dump-json',
                '--no-warnings',
                url
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                info = json.loads(result.stdout)
                return info
            else:
                print("❌ Error getting video info")
                return None
                
        except Exception as e:
            print(f"❌ Error: {str(e)}")
            return None
    
    def get_available_formats(self, url):
        """Get available formats"""
        try:
            cmd = ['yt-dlp', '-F', '--no-warnings', url]
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                return result.stdout
            else:
                return None
                
        except Exception as e:
            print(f"❌ Error: {str(e)}")
            return None
    
    def download_video(self, url, format_code):
        """Download video with specified format"""
        print(f"\n⬇️  Downloading video (Format: {format_code})...")
        print("This may take a while depending on video size...\n")
        
        # Change to download directory
        os.chdir(self.download_dir)
        
        try:
            # Download with progress
            cmd = [
                'yt-dlp',
                '-f', format_code,
                '-o', '%(title)s_%(height)sp.%(ext)s',
                '--progress',
                '--no-warnings',
                url
            ]
            
            # Run download
            process = subprocess.Popen(cmd, 
                                     stdout=subprocess.PIPE, 
                                     stderr=subprocess.STDOUT,
                                     text=True,
                                     bufsize=1,
                                     universal_newlines=True)
            
            # Show progress
            for line in process.stdout:
                if '[download]' in line:
                    sys.stdout.write('\r' + line.strip())
                    sys.stdout.flush()
            
            process.wait()
            
            if process.returncode == 0:
                print(f"\n\n✅ Download completed!")
                print(f"📁 Saved in: {self.download_dir}")
                return True
            else:
                print("\n\n❌ Download failed")
                return False
                
        except Exception as e:
            print(f"\n❌ Error: {str(e)}")
            return False
        finally:
            # Return to script directory
            os.chdir(self.script_dir)
    
    def show_help(self):
        """Show help message"""
        print("\n📋 Common Format Codes:")
        print("-" * 40)
        print("best      : Best quality (video + audio)")
        print("worst     : Worst quality (video + audio)")
        print("bestvideo : Best video only")
        print("bestaudio : Best audio only")
        print("137+140   : Specific format (1080p + audio)")
        print("\n💡 Tip: Use 'yt-dlp -F URL' to see all formats")
    
    def run_interactive(self):
        """Run in interactive mode"""
        self.clear_screen()
        self.show_banner()
        
        # Check yt-dlp
        if not self.check_ytdlp():
            print("❌ yt-dlp is not installed!")
            print("Please install it first: pip3 install yt-dlp")
            return
        
        print("Welcome! Enter Twitter/X URLs to download videos.")
        print("Type 'help' for format codes, 'exit' to quit.\n")
        
        while True:
            try:
                # Get URL from user
                url = input("\n🔗 Enter Twitter/X URL: ").strip()
                
                if url.lower() == 'exit':
                    print("\n👋 Goodbye!")
                    break
                
                if url.lower() == 'help':
                    self.show_help()
                    continue
                
                if not url:
                    continue
                
                # Validate URL (basic check)
                if 'twitter.com' not in url and 'x.com' not in url:
                    print("⚠️  Please enter a valid Twitter/X URL")
                    continue
                
                # Get available formats
                formats = self.get_available_formats(url)
                if formats:
                    print("\n📊 Available formats:")
                    print("-" * 60)
                    print(formats)
                    print("-" * 60)
                else:
                    print("❌ Could not get format information")
                    continue
                
                # Get format choice
                format_code = input("\n🎬 Enter format code (default: 'best'): ").strip()
                if not format_code:
                    format_code = "best"
                
                # Get video info
                info = self.get_video_info(url)
                if info:
                    title = info.get('title', 'Unknown')
                    duration = info.get('duration_string', 'Unknown')
                    print(f"\n📝 Title: {title}")
                    print(f"⏱️  Duration: {duration}")
                
                # Confirm download
                confirm = input(f"\n❓ Download with format '{format_code}'? (y/N): ").strip().lower()
                
                if confirm == 'y':
                    # Download video
                    success = self.download_video(url, format_code)
                    
                    if success:
                        # Ask for another download
                        another = input("\n❓ Download another video? (y/N): ").strip().lower()
                        if another != 'y':
                            print("\n👋 Goodbye!")
                            break
                    else:
                        retry = input("\n❓ Download failed. Try again? (y/N): ").strip().lower()
                        if retry != 'y':
                            break
                else:
                    print("⚠️  Download cancelled")
                
                self.clear_screen()
                self.show_banner()
                
            except KeyboardInterrupt:
                print("\n\n⚠️  Interrupted by user")
                break
            except Exception as e:
                print(f"\n❌ Error: {str(e)}")
                continue

def main():
    """Main function"""
    downloader = TwitterDownloader()
    downloader.run_interactive()

if __name__ == "__main__":
    main()
EOF
    
    # Give execute permission
    os.chmod('/opt/twitter-dl/twitter_downloader.py', 0o755)
    
    # Create launcher script
    cat > /usr/local/bin/twitter-dl << 'EOF'
#!/bin/bash
# Twitter/X Video Downloader Launcher

python3 /opt/twitter-dl/twitter_downloader.py "$@"
EOF
    
    # Give execute permission
    chmod +x /usr/local/bin/twitter_downloader.py
    chmod +x /usr/local/bin/twitter-dl
    
    # Create simple bash script alternative
    cat > /usr/local/bin/twitter-download << 'EOF'
#!/bin/bash
# Simple Twitter Download Script

if [ -z "$1" ]; then
    echo "Usage: twitter-download <twitter-url> [format]"
    echo ""
    echo "Examples:"
    echo "  twitter-download https://twitter.com/user/status/123456789"
    echo "  twitter-download https://x.com/user/status/123456789 best"
    echo "  twitter-download https://twitter.com/user/status/123456789 137+140"
    echo ""
    echo "To see available formats:"
    echo "  yt-dlp -F <url>"
    exit 1
fi

URL="$1"
FORMAT="${2:-best}"

echo "Downloading: $URL"
echo "Format: $FORMAT"
echo ""

cd ~/Downloads 2>/dev/null || cd ~

yt-dlp -f "$FORMAT" -o "%(title)s.%(ext)s" "$URL"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Download completed!"
else
    echo ""
    echo "❌ Download failed!"
fi
EOF
    
    chmod +x /usr/local/bin/twitter-download
    
    print_success "Download scripts created"
}

# Create configuration
create_config() {
    print_info "Creating configuration..."
    
    # Create config directory
    mkdir -p /etc/twitter-dl
    
    # Create basic config
    cat > /etc/twitter-dl/config.json << 'EOF'
{
    "download_path": "~/Downloads/Twitter",
    "default_format": "best",
    "enable_progress": true,
    "max_retries": 3,
    "timeout": 30
}
EOF
    
    print_success "Configuration created"
}

# Add to bashrc
setup_aliases() {
    print_info "Setting up aliases..."
    
    # Add aliases to bashrc if they don't exist
    if ! grep -q "twitter-dl" /root/.bashrc 2>/dev/null; then
        echo "" >> /root/.bashrc
        echo "# Twitter Downloader Aliases" >> /root/.bashrc
        echo "alias twitter-dl='/usr/local/bin/twitter-dl'" >> /root/.bashrc
        echo "alias twitter-download='/usr/local/bin/twitter-download'" >> /root/.bashrc
        echo "alias tdl='/usr/local/bin/twitter-dl'" >> /root/.bashrc
    fi
    
    # Also for current user if not root
    if [ "$(whoami)" != "root" ]; then
        if [ -f ~/.bashrc ] && ! grep -q "twitter-dl" ~/.bashrc; then
            echo "" >> ~/.bashrc
            echo "# Twitter Downloader Aliases" >> ~/.bashrc
            echo "alias twitter-dl='/usr/local/bin/twitter-dl'" >> ~/.bashrc
            echo "alias tdl='/usr/local/bin/twitter-dl'" >> ~/.bashrc
        fi
    fi
    
    print_success "Aliases added"
}

# Show completion message
show_completion() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════╗"
    echo "║                                                  ║"
    echo "║           INSTALLATION COMPLETE! 🎉             ║"
    echo "║                                                  ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "\n${CYAN}📦 Available Commands:${NC}"
    echo -e "${GREEN}  twitter-dl${NC}        - Interactive downloader"
    echo -e "${GREEN}  twitter-download${NC}  - Quick download (twitter-download <url> [format])"
    echo -e "${GREEN}  tdl${NC}              - Short alias for twitter-dl"
    
    echo -e "\n${CYAN}🚀 Quick Start:${NC}"
    echo -e "  ${GREEN}1.${NC} Open new terminal or run: ${YELLOW}source ~/.bashrc${NC}"
    echo -e "  ${GREEN}2.${NC} Start downloader: ${YELLOW}twitter-dl${NC}"
    echo -e "  ${GREEN}3.${NC} Enter Twitter/X URL when prompted"
    
    echo -e "\n${CYAN}📝 Examples:${NC}"
    echo -e "  ${YELLOW}twitter-dl${NC}"
    echo -e "  ${YELLOW}twitter-download https://twitter.com/user/status/123456789${NC}"
    echo -e "  ${YELLOW}twitter-download https://x.com/user/status/123456789 'best'${NC}"
    
    echo -e "\n${CYAN}📁 Download Location:${NC}"
    echo -e "  ${YELLOW}~/Downloads/Twitter/${NC}"
    
    echo -e "\n${CYAN}🔧 Manual Download with yt-dlp:${NC}"
    echo -e "  ${YELLOW}yt-dlp -F <url>${NC}               # Show available formats"
    echo -e "  ${YELLOW}yt-dlp -f best <url>${NC}          # Download best quality"
    echo -e "  ${YELLOW}yt-dlp -f '137+140' <url>${NC}     # Download specific format"
    
    echo -e "\n${YELLOW}Need help?${NC} Run ${GREEN}twitter-dl${NC} and type 'help' when prompted.\n"
}

# Main installation function
main_installation() {
    show_logo
    check_root
    install_dependencies
    install_python_packages
    create_download_script
    create_config
    setup_aliases
    show_completion
}

# Handle errors
handle_error() {
    print_error "Installation failed!"
    print_error "Error on line $1"
    exit 1
}

# Set error trap
trap 'handle_error $LINENO' ERR

# Run installation
main_installation

# Load aliases immediately
if [ -f /root/.bashrc ]; then
    source /root/.bashrc 2>/dev/null || true
fi

if [ -f ~/.bashrc ]; then
    source ~/.bashrc 2>/dev/null || true
fi

print_info "Installation finished successfully!"
print_info "You can now use 'twitter-dl' command"
