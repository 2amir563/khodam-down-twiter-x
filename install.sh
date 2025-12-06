#!/bin/bash

# Telegram Twitter/X Video Downloader Bot Installer
# Fixed EOF Error Version

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logo
show_logo() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════╗"
    echo "║                                                  ║"
    echo "║     TELEGRAM TWITTER/X DOWNLOADER BOT           ║"
    echo "║             INSTALLATION SCRIPT                  ║"
    echo "║               FIXED VERSION 2.0                  ║"
    echo "║                                                  ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Print functions
print_info() { echo -e "${CYAN}[*] $1${NC}"; }
print_success() { echo -e "${GREEN}[✓] $1${NC}"; }
print_warning() { echo -e "${YELLOW}[!] $1${NC}"; }
print_error() { echo -e "${RED}[✗] $1${NC}"; }

# Install dependencies
install_dependencies() {
    print_info "Installing system dependencies..."
    
    if command -v apt &> /dev/null; then
        apt update -y
        apt install -y python3 python3-pip git ffmpeg curl wget nano
    elif command -v yum &> /dev/null; then
        yum install -y python3 python3-pip git ffmpeg curl wget nano
    elif command -v dnf &> /dev/null; then
        dnf install -y python3 python3-pip git ffmpeg curl wget nano
    else
        print_error "Unsupported OS. Please install manually."
        exit 1
    fi
    
    print_success "System dependencies installed"
}

# Install Python packages
install_python_packages() {
    print_info "Installing Python packages..."
    
    pip3 install --upgrade pip
    pip3 install python-telegram-bot==20.7 yt-dlp requests python-dotenv
    
    print_success "Python packages installed"
}

# Create bot directory
create_directory() {
    print_info "Creating bot directory..."
    
    rm -rf /opt/twitter_bot
    mkdir -p /opt/twitter_bot
    mkdir -p /opt/twitter_bot/downloads
    mkdir -p /opt/twitter_bot/logs
    
    print_success "Directory created: /opt/twitter_bot"
}

# Create bot.py
create_bot_script() {
    print_info "Creating bot script..."
    
    cat > /opt/twitter_bot/bot.py << 'BOTEOF'
#!/usr/bin/env python3
"""
Telegram Twitter/X Video Downloader Bot
Simple and reliable version
"""

import os
import logging
import subprocess
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes
from dotenv import load_dotenv

# Load environment
load_dotenv()

# Configuration
BOT_TOKEN = os.getenv('BOT_TOKEN')
DOWNLOAD_DIR = "/opt/twitter_bot/downloads"
os.makedirs(DOWNLOAD_DIR, exist_ok=True)

# Setup logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO,
    filename='/opt/twitter_bot/logs/bot.log'
)
logger = logging.getLogger(__name__)

async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    text = f"""
👋 Welcome {user.first_name}!

I can download videos from Twitter/X for you.

📌 How to use:
1. Send me any Twitter/X link
2. I'll download it for you
3. You'll receive the video

🔗 Examples:
• https://twitter.com/user/status/1234567890
• https://x.com/user/status/1234567890

⚡ Commands:
/start - Show this message
/help - Help information

Made with ❤️ by khodam-down-twiter-x
    """
    await update.message.reply_text(text)

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    text = """
🤖 Bot Help

📌 Supported URLs:
• twitter.com/*
• x.com/*
• t.co/* (short links)

📌 How to download:
1. Copy Twitter/X video link
2. Send to this bot
3. Wait for download
4. Receive video

📌 Note:
• Max file size: 50MB (Telegram limit)
• Download may take 1-2 minutes
• Videos download in best quality
    """
    await update.message.reply_text(text)

def is_twitter_url(url):
    """Check if URL is from Twitter/X"""
    return any(domain in url for domain in ['twitter.com', 'x.com', 't.co'])

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    message = update.message
    url = message.text.strip()
    user_id = message.from_user.id
    
    if not is_twitter_url(url):
        await message.reply_text("❌ Please send a valid Twitter/X URL")
        return
    
    # Create user directory
    user_dir = os.path.join(DOWNLOAD_DIR, str(user_id))
    os.makedirs(user_dir, exist_ok=True)
    
    # Send processing message
    status_msg = await message.reply_text("⏳ Processing your request...")
    
    try:
        # Update status
        await status_msg.edit_text("📥 Downloading video...\nThis may take a minute.")
        
        # Download using yt-dlp
        output_template = os.path.join(user_dir, '%(title)s.%(ext)s')
        
        # Try best quality under 50MB
        cmd = [
            'yt-dlp',
            '-f', 'best[filesize<50M]',
            '-o', output_template,
            '--no-warnings',
            url
        ]
        
        # Run download
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        
        if result.returncode != 0:
            # Try alternative
            cmd = [
                'yt-dlp',
                '-f', 'best',
                '-o', output_template,
                '--no-warnings',
                '--max-filesize', '50M',
                url
            ]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        
        if result.returncode == 0:
            # Find downloaded file
            files = [f for f in os.listdir(user_dir) if f.endswith(('.mp4', '.mkv', '.webm'))]
            if files:
                latest_file = max([os.path.join(user_dir, f) for f in files], key=os.path.getctime)
                
                # Check file size
                file_size = os.path.getsize(latest_file)
                if file_size > 50 * 1024 * 1024:
                    await status_msg.edit_text("❌ File too large (>50MB). Try a shorter video.")
                    os.remove(latest_file)
                    return
                
                # Send video
                await status_msg.edit_text("📤 Sending video...")
                
                with open(latest_file, 'rb') as video_file:
                    await context.bot.send_video(
                        chat_id=user_id,
                        video=video_file,
                        caption="✅ Downloaded successfully!",
                        supports_streaming=True
                    )
                
                # Clean up
                os.remove(latest_file)
                await status_msg.delete()
                
            else:
                await status_msg.edit_text("❌ No video file found after download")
        else:
            error_msg = result.stderr[:200] if result.stderr else "Unknown error"
            await status_msg.edit_text(f"❌ Download failed:\n{error_msg}")
            
    except subprocess.TimeoutExpired:
        await status_msg.edit_text("❌ Download timeout (5 minutes)")
    except Exception as e:
        logger.error(f"Error: {str(e)}")
        await status_msg.edit_text(f"❌ Error: {str(e)[:200]}")

async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle errors"""
    logger.error(f"Error: {context.error}")
    if update and update.effective_message:
        try:
            await update.effective_message.reply_text("⚠️ An error occurred. Please try again.")
        except:
            pass

def main():
    """Main function"""
    if not BOT_TOKEN:
        print("❌ ERROR: BOT_TOKEN not found in .env file")
        print("Please add your bot token to /opt/twitter_bot/.env")
        exit(1)
    
    # Create application
    app = Application.builder().token(BOT_TOKEN).build()
    
    # Add handlers
    app.add_handler(CommandHandler("start", start_command))
    app.add_handler(CommandHandler("help", help_command))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    app.add_error_handler(error_handler)
    
    print("🤖 Starting Telegram Bot...")
    print("📁 Download directory: /opt/twitter_bot/downloads")
    print("📝 Logs: /opt/twitter_bot/logs/bot.log")
    print("⚡ Bot is running. Press Ctrl+C to stop.")
    
    # Start bot
    app.run_polling()

if __name__ == '__main__':
    main()
BOTEOF

    chmod +x /opt/twitter_bot/bot.py
    print_success "Bot script created"
}

# Create .env file
create_env_file() {
    print_info "Creating environment file..."
    
    cat > /opt/twitter_bot/.env.example << 'ENVEOF'
# Telegram Bot Token from @BotFather
# Example: 1234567890:ABCdefGhIJKlmNoPQRsTUVwxyZ
BOT_TOKEN=your_bot_token_here

# Optional: Your Telegram User ID
# Get it from @userinfobot on Telegram
ADMIN_ID=123456789
ENVEOF

    print_success "Environment file created"
}

# Create service file
create_service() {
    print_info "Creating systemd service..."
    
    cat > /etc/systemd/system/twitter-bot.service << 'SERVICEEOF'
[Unit]
Description=Telegram Twitter/X Video Downloader Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/twitter_bot
ExecStart=/usr/bin/python3 /opt/twitter_bot/bot.py
Restart=always
RestartSec=10
StandardOutput=append:/opt/twitter_bot/logs/bot.log
StandardError=append:/opt/twitter_bot/logs/error.log

[Install]
WantedBy=multi-user.target
SERVICEEOF

    systemctl daemon-reload
    print_success "Systemd service created"
}

# Create control script
create_control_script() {
    print_info "Creating control script..."
    
    cat > /usr/local/bin/twitter-bot << 'CONTROLEOF'
#!/bin/bash
# Twitter Bot Control Script

case "$1" in
    start)
        systemctl start twitter-bot
        echo "✅ Bot started"
        ;;
    stop)
        systemctl stop twitter-bot
        echo "🛑 Bot stopped"
        ;;
    restart)
        systemctl restart twitter-bot
        echo "🔄 Bot restarted"
        ;;
    status)
        systemctl status twitter-bot
        ;;
    logs)
        tail -f /opt/twitter_bot/logs/bot.log
        ;;
    errors)
        tail -f /opt/twitter_bot/logs/error.log
        ;;
    setup)
        echo "📝 Setting up bot..."
        cd /opt/twitter_bot
        if [ ! -f .env ]; then
            cp .env.example .env
            echo ""
            echo "📋 Created .env file."
            echo "Please edit it and add your BOT_TOKEN:"
            echo "   nano /opt/twitter_bot/.env"
            echo ""
            echo "📌 How to get BOT_TOKEN:"
            echo "1. Open Telegram"
            echo "2. Search for @BotFather"
            echo "3. Send /newbot"
            echo "4. Follow instructions"
            echo "5. Copy the token"
        else
            echo "✅ .env file already exists"
        fi
        ;;
    config)
        nano /opt/twitter_bot/.env
        ;;
    update)
        echo "🔄 Updating bot..."
        pip3 install --upgrade python-telegram-bot yt-dlp requests
        systemctl restart twitter-bot
        echo "✅ Bot updated and restarted"
        ;;
    test)
        echo "🧪 Testing installation..."
        echo ""
        echo "1. Checking Python packages..."
        pip3 list | grep -E "(telegram|yt-dlp|requests|dotenv)"
        echo ""
        echo "2. Checking yt-dlp..."
        yt-dlp --version
        echo ""
        echo "3. Checking service..."
        systemctl status twitter-bot --no-pager -l
        echo ""
        echo "4. Checking logs..."
        tail -5 /opt/twitter_bot/logs/bot.log 2>/dev/null || echo "No logs yet"
        ;;
    *)
        echo "🤖 Twitter/X Downloader Bot Control"
        echo ""
        echo "Usage: $0 {start|stop|restart|status|logs|errors|setup|config|update|test}"
        echo ""
        echo "Commands:"
        echo "  start     - Start the bot"
        echo "  stop      - Stop the bot"
        echo "  restart   - Restart the bot"
        echo "  status    - Check bot status"
        echo "  logs      - View bot logs"
        echo "  errors    - View error logs"
        echo "  setup     - Initial setup (IMPORTANT!)"
        echo "  config    - Edit configuration"
        echo "  update    - Update bot software"
        echo "  test      - Test installation"
        echo ""
        echo "Quick start:"
        echo "  1. twitter-bot setup"
        echo "  2. twitter-bot config  (add your token)"
        echo "  3. twitter-bot start"
        echo "  4. twitter-bot logs    (to monitor)"
        ;;
esac
CONTROLEOF

    chmod +x /usr/local/bin/twitter-bot
    print_success "Control script created"
}

# Create test script
create_test_script() {
    print_info "Creating test script..."
    
    cat > /opt/twitter_bot/test.py << 'TESTEOF'
#!/usr/bin/env python3
print("Testing Twitter Bot Installation")
print("=" * 40)

import sys
import subprocess

print("1. Checking Python version...")
print(f"Python {sys.version}")

print("\n2. Checking packages...")
try:
    import telegram
    print("✅ python-telegram-bot installed")
except:
    print("❌ python-telegram-bot missing")

try:
    import yt_dlp
    print("✅ yt-dlp installed")
except:
    print("❌ yt-dlp missing")

try:
    import requests
    print("✅ requests installed")
except:
    print("❌ requests missing")

print("\n3. Checking external commands...")
try:
    result = subprocess.run(['yt-dlp', '--version'], capture_output=True, text=True)
    print(f"✅ yt-dlp version: {result.stdout.strip()}")
except:
    print("❌ yt-dlp not found in PATH")

try:
    result = subprocess.run(['ffmpeg', '-version'], capture_output=True, text=True)
    print("✅ ffmpeg installed")
except:
    print("❌ ffmpeg not found")

print("\n4. Checking files...")
import os
files_to_check = [
    ('/opt/twitter_bot/bot.py', 'Bot script'),
    ('/opt/twitter_bot/.env.example', 'Env template'),
]

for filepath, desc in files_to_check:
    if os.path.exists(filepath):
        print(f"✅ {desc}: Found")
    else:
        print(f"❌ {desc}: Missing")

print("\n" + "=" * 40)
print("Test complete!")
TESTEOF

    chmod +x /opt/twitter_bot/test.py
    print_success "Test script created"
}

# Show completion
show_completion() {
    echo -e "${GREEN}"
    echo "=============================================="
    echo "     INSTALLATION COMPLETE!"
    echo "=============================================="
    echo -e "${NC}"
    
    echo -e "\n${YELLOW}🚀 QUICK START:${NC}"
    echo "1. First, run setup:"
    echo "   twitter-bot setup"
    echo ""
    echo "2. Edit config file:"
    echo "   twitter-bot config"
    echo "   • Add your BOT_TOKEN from @BotFather"
    echo ""
    echo "3. Start the bot:"
    echo "   twitter-bot start"
    echo ""
    echo "4. Check status:"
    echo "   twitter-bot status"
    echo ""
    
    echo -e "${YELLOW}📱 HOW TO USE:${NC}"
    echo "1. Find Twitter/X video"
    echo "2. Copy link"
    echo "3. Send to your bot on Telegram"
    echo "4. Wait for download"
    echo "5. Receive video"
    echo ""
    
    echo -e "${YELLOW}🔧 MANAGEMENT:${NC}"
    echo "twitter-bot start    # Start bot"
    echo "twitter-bot stop     # Stop bot"
    echo "twitter-bot restart  # Restart bot"
    echo "twitter-bot status   # Check status"
    echo "twitter-bot logs     # View logs"
    echo "twitter-bot config   # Edit config"
    echo ""
    
    echo -e "${YELLOW}📁 LOCATIONS:${NC}"
    echo "Bot: /opt/twitter_bot"
    echo "Config: /opt/twitter_bot/.env"
    echo "Logs: /opt/twitter_bot/logs/"
    echo ""
    
    echo -e "${GREEN}✅ Ready to configure!${NC}"
    echo ""
    echo -e "Run this command to begin:"
    echo -e "${CYAN}twitter-bot setup${NC}"
}

# Main installation
main() {
    show_logo
    print_info "Starting installation..."
    
    install_dependencies
    install_python_packages
    create_directory
    create_bot_script
    create_env_file
    create_service
    create_control_script
    create_test_script
    show_completion
}

# Run
main
