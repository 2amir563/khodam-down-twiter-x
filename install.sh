#!/bin/bash

# Telegram Twitter/X Video Downloader Bot Installer
# Fixed Version

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
    cat << "EOF"
╔══════════════════════════════════════════════════╗
║                                                  ║
║     TELEGRAM TWITTER/X DOWNLOADER BOT           ║
║             INSTALLATION SCRIPT                  ║
║                FIXED VERSION                     ║
║                                                  ║
╚══════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Print functions
print_info() { echo -e "${CYAN}[*] $1${NC}"; }
print_success() { echo -e "${GREEN}[✓] $1${NC}"; }
print_warning() { echo -e "${YELLOW}[!] $1${NC}"; }
print_error() { echo -e "${RED}[✗] $1${NC}"; }

# Check root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_warning "Script should run as root. Trying to continue..."
    fi
}

# Install system dependencies
install_dependencies() {
    print_info "Installing system dependencies..."
    
    # Update system
    if command -v apt &> /dev/null; then
        apt update -y
        apt install -y python3 python3-pip python3-venv git ffmpeg curl wget nano
    elif command -v yum &> /dev/null; then
        yum install -y python3 python3-pip git ffmpeg curl wget nano
    elif command -v dnf &> /dev/null; then
        dnf install -y python3 python3-pip git ffmpeg curl wget nano
    else
        print_error "Unsupported OS. Install manually: python3, pip, git, ffmpeg"
        exit 1
    fi
    
    print_success "System dependencies installed"
}

# Install Python packages
install_python_packages() {
    print_info "Installing Python packages..."
    
    pip3 install --upgrade pip
    
    # Install with specific versions for compatibility
    pip3 install "python-telegram-bot==20.7" "yt-dlp>=2023.11.16" requests python-dotenv
    
    print_success "Python packages installed"
}

# Create bot directory
create_directory() {
    print_info "Creating bot directory..."
    
    rm -rf /opt/telegram_twitter_bot
    mkdir -p /opt/telegram_twitter_bot
    mkdir -p /opt/telegram_twitter_bot/downloads
    mkdir -p /opt/telegram_twitter_bot/logs
    
    print_success "Directory created: /opt/telegram_twitter_bot"
}

# Create simple bot script (fixed)
create_bot_script() {
    print_info "Creating bot script..."
    
    cat > /opt/telegram_twitter_bot/bot.py << 'EOF'
#!/usr/bin/env python3
"""
Simple Telegram Twitter/X Video Downloader Bot
Fixed version - No complex dependencies
"""

import os
import logging
import subprocess
import asyncio
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes, CallbackQueryHandler
from dotenv import load_dotenv

# Load environment
load_dotenv()

# Configuration
BOT_TOKEN = os.getenv('BOT_TOKEN', '')
DOWNLOAD_DIR = "/opt/telegram_twitter_bot/downloads"
os.makedirs(DOWNLOAD_DIR, exist_ok=True)

# Setup logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO,
    filename='/opt/telegram_twitter_bot/logs/bot.log'
)
logger = logging.getLogger(__name__)

class SimpleTwitterBot:
    def __init__(self):
        self.user_data = {}
        
    def is_valid_url(self, url):
        """Check if URL is from Twitter/X"""
        return any(domain in url for domain in ['twitter.com', 'x.com', 't.co'])
    
    async def start(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Handle /start command"""
        user = update.effective_user
        text = f"""
👋 Welcome {user.first_name}!

I can download videos from Twitter/X for you.

📌 *How to use:*
1. Send me any Twitter/X link
2. I'll download it for you
3. You'll receive the video

🔗 *Examples:*
• https://twitter.com/user/status/1234567890
• https://x.com/user/status/1234567890

⚡ *Commands:*
/start - Show this message
/help - Help information
        """
        await update.message.reply_text(text, parse_mode='Markdown')
    
    async def help(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Handle /help command"""
        text = """
🤖 *Bot Help*

*Supported URLs:*
• twitter.com/*
• x.com/*
• t.co/* (short links)

*How to download:*
1. Copy Twitter/X video link
2. Send to this bot
3. Wait for download
4. Receive video

*Note:*
• Max file size: 50MB (Telegram limit)
• Download may take 1-2 minutes
• Videos download in best quality
        """
        await update.message.reply_text(text, parse_mode='Markdown')
    
    async def handle_url(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Handle incoming URLs"""
        message = update.message
        url = message.text.strip()
        user_id = message.from_user.id
        
        # Check URL
        if not self.is_valid_url(url):
            await message.reply_text("❌ Please send a valid Twitter/X URL")
            return
        
        # Store URL for this user
        self.user_data[user_id] = {'url': url}
        
        # Show processing message
        status_msg = await message.reply_text("⏳ Processing your request...")
        
        try:
            # Create user directory
            user_dir = os.path.join(DOWNLOAD_DIR, str(user_id))
            os.makedirs(user_dir, exist_ok=True)
            
            # Update status
            await status_msg.edit_text("📥 Downloading video...\nThis may take a minute.")
            
            # Download using yt-dlp
            output_template = os.path.join(user_dir, '%(title)s.%(ext)s')
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
                # Try alternative format
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
                    if file_size > 50 * 1024 * 1024:  # 50MB limit
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
    
    async def error_handler(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Handle errors gracefully"""
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
        print("Please add your bot token to /opt/telegram_twitter_bot/.env")
        exit(1)
    
    # Create bot instance
    bot = SimpleTwitterBot()
    
    # Create application
    app = Application.builder().token(BOT_TOKEN).build()
    
    # Add handlers
    app.add_handler(CommandHandler("start", bot.start))
    app.add_handler(CommandHandler("help", bot.help))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, bot.handle_url))
    app.add_error_handler(bot.error_handler)
    
    print("🤖 Starting Telegram Bot...")
    print(f"📁 Download directory: {DOWNLOAD_DIR}")
    print("📝 Logs: /opt/telegram_twitter_bot/logs/bot.log")
    print("⚡ Bot is running. Press Ctrl+C to stop.")
    
    # Start bot
    app.run_polling()

if __name__ == '__main__':
    main()
EOF
    
    chmod +x /opt/telegram_twitter_bot/bot.py
    print_success "Bot script created"
}

# Create environment file
create_env_file() {
    print_info "Creating environment file..."
    
    cat > /opt/telegram_twitter_bot/.env.example << 'EOF'
# Telegram Bot Token from @BotFather
# Example: 1234567890:ABCdefGhIJKlmNoPQRsTUVwxyZ
BOT_TOKEN=your_bot_token_here

# Optional: Your Telegram User ID for admin commands
# Get it from @userinfobot on Telegram
ADMIN_ID=123456789
EOF
    
    print_success "Environment file template created"
}

# Create systemd service
create_service() {
    print_info "Creating systemd service..."
    
    cat > /etc/systemd/system/twitter-bot.service << 'EOF'
[Unit]
Description=Telegram Twitter/X Video Downloader Bot
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/telegram_twitter_bot
ExecStart=/usr/bin/python3 /opt/telegram_twitter_bot/bot.py
Restart=always
RestartSec=10
StandardOutput=append:/opt/telegram_twitter_bot/logs/bot.log
StandardError=append:/opt/telegram_twitter_bot/logs/error.log
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    print_success "Systemd service created"
}

# Create control script
create_control_script() {
    print_info "Creating control script..."
    
    cat > /usr/local/bin/twitter-bot << 'EOF'
#!/bin/bash
# Twitter Bot Control Script

BOT_DIR="/opt/telegram_twitter_bot"
SERVICE="twitter-bot"

case "$1" in
    start)
        systemctl start $SERVICE
        echo "✅ Bot started"
        ;;
    stop)
        systemctl stop $SERVICE
        echo "🛑 Bot stopped"
        ;;
    restart)
        systemctl restart $SERVICE
        echo "🔄 Bot restarted"
        ;;
    status)
        systemctl status $SERVICE
        ;;
    logs)
        if [[ "$2" == "error" ]]; then
            tail -f $BOT_DIR/logs/error.log
        else
            tail -f $BOT_DIR/logs/bot.log
        fi
        ;;
    setup)
        echo "📝 Setting up bot configuration..."
        cd $BOT_DIR
        if [ ! -f .env ]; then
            cp .env.example .env
            echo "📋 Created .env file. Please edit it:"
            echo "   nano $BOT_DIR/.env"
            echo "📌 Add your BOT_TOKEN from @BotFather"
        else
            echo "✅ .env file already exists"
        fi
        ;;
    config)
        nano $BOT_DIR/.env
        ;;
    update)
        echo "🔄 Updating bot..."
        cd $BOT_DIR
        pip3 install --upgrade python-telegram-bot yt-dlp requests
        systemctl restart $SERVICE
        echo "✅ Bot updated and restarted"
        ;;
    test)
        echo "🧪 Testing bot..."
        if [ -f $BOT_DIR/bot.py ]; then
            python3 $BOT_DIR/bot.py --test
        else
            echo "❌ Bot script not found"
        fi
        ;;
    *)
        echo "🤖 Twitter/X Downloader Bot Control"
        echo ""
        echo "Usage: $0 {start|stop|restart|status|logs|setup|config|update|test}"
        echo ""
        echo "Commands:"
        echo "  start     - Start the bot"
        echo "  stop      - Stop the bot"
        echo "  restart   - Restart the bot"
        echo "  status    - Check bot status"
        echo "  logs      - View bot logs (add 'error' for error logs)"
        echo "  setup     - Initial setup"
        echo "  config    - Edit configuration"
        echo "  update    - Update bot software"
        echo "  test      - Test bot (if available)"
        echo ""
        echo "Examples:"
        echo "  twitter-bot start"
        echo "  twitter-bot logs"
        echo "  twitter-bot setup"
        ;;
esac
EOF
    
    chmod +x /usr/local/bin/twitter-bot
    print_success "Control script created"
}

# Create test script
create_test_script() {
    print_info "Creating test script..."
    
    cat > /opt/telegram_twitter_bot/test_bot.py << 'EOF'
#!/usr/bin/env python3
"""
Test script to verify bot installation
"""

import os
import subprocess
import sys

def test_dependencies():
    print("🧪 Testing dependencies...")
    
    # Test Python
    try:
        import telegram
        print("✅ python-telegram-bot installed")
    except:
        print("❌ python-telegram-bot not installed")
        return False
    
    # Test yt-dlp
    try:
        result = subprocess.run(['yt-dlp', '--version'], capture_output=True, text=True)
        if result.returncode == 0:
            print(f"✅ yt-dlp installed (Version: {result.stdout.strip()})")
        else:
            print("❌ yt-dlp not working")
            return False
    except:
        print("❌ yt-dlp not installed")
        return False
    
    # Test ffmpeg
    try:
        result = subprocess.run(['ffmpeg', '-version'], capture_output=True, text=True)
        if result.returncode == 0:
            print("✅ ffmpeg installed")
        else:
            print("❌ ffmpeg not working")
            return False
    except:
        print("❌ ffmpeg not installed")
        return False
    
    return True

def test_env_file():
    print("\n📁 Testing environment file...")
    
    env_path = "/opt/telegram_twitter_bot/.env"
    if os.path.exists(env_path):
        with open(env_path, 'r') as f:
            content = f.read()
            if 'BOT_TOKEN' in content:
                print("✅ .env file exists with BOT_TOKEN")
                return True
            else:
                print("⚠️  .env file exists but BOT_TOKEN not found")
                return False
    else:
        print("❌ .env file not found")
        return False

def test_directories():
    print("\n📂 Testing directories...")
    
    dirs = [
        "/opt/telegram_twitter_bot",
        "/opt/telegram_twitter_bot/downloads",
        "/opt/telegram_twitter_bot/logs"
    ]
    
    all_ok = True
    for directory in dirs:
        if os.path.exists(directory):
            print(f"✅ {directory}")
        else:
            print(f"❌ {directory} missing")
            all_ok = False
    
    return all_ok

def main():
    print("🤖 Twitter Bot Installation Test")
    print("=" * 40)
    
    tests = [
        ("Dependencies", test_dependencies),
        ("Environment", test_env_file),
        ("Directories", test_directories)
    ]
    
    results = []
    for test_name, test_func in tests:
        print(f"\n🔍 Testing: {test_name}")
        try:
            if test_func():
                results.append((test_name, True))
            else:
                results.append((test_name, False))
        except Exception as e:
            print(f"❌ Test failed: {e}")
            results.append((test_name, False))
    
    print("\n" + "=" * 40)
    print("📊 Test Results:")
    print("=" * 40)
    
    all_passed = True
    for test_name, passed in results:
        if passed:
            print(f"✅ {test_name}: PASSED")
        else:
            print(f"❌ {test_name}: FAILED")
            all_passed = False
    
    print("\n" + "=" * 40)
    if all_passed:
        print("🎉 All tests passed! Bot is ready.")
        print("\nNext steps:")
        print("1. Edit .env file: twitter-bot config")
        print("2. Start bot: twitter-bot start")
        print("3. Check logs: twitter-bot logs")
    else:
        print("⚠️  Some tests failed. Please fix issues.")
        print("\nRun: twitter-bot setup")
    
    return 0 if all_passed else 1

if __name__ == '__main__':
    sys.exit(main())
EOF
    
    chmod +x /opt/telegram_twitter_bot/test_bot.py
    print_success "Test script created"
}

# Create README file
create_readme() {
    print_info "Creating README file..."
    
    cat > /opt/telegram_twitter_bot/README.md << 'EOF'
# Telegram Twitter/X Video Downloader Bot

A simple Telegram bot that downloads videos from Twitter/X and sends them to you.

## Features
- Download videos from Twitter/X
- Auto-detects best quality
- Simple to use - just send a link
- File size limit: 50MB (Telegram limit)
- Automatic cleanup of downloaded files

## Quick Start

1. **Get a Telegram Bot Token:**
   - Open Telegram
   - Search for @BotFather
   - Send `/newbot`
   - Follow instructions
   - Copy the bot token

2. **Configure the Bot:**
   ```bash
   twitter-bot setup
   # Then edit the .env file
   twitter-bot config
