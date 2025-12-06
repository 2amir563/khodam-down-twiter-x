#!/bin/bash

# Telegram Twitter/X Video Downloader Bot Installer
# Simple and reliable version

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
    echo "   TELEGRAM TWITTER/X DOWNLOADER BOT"
    echo "         INSTALLATION SCRIPT"
    echo "=============================================="
    echo -e "${NC}"
}

# Print functions
print_info() { echo -e "${BLUE}[*] $1${NC}"; }
print_success() { echo -e "${GREEN}[✓] $1${NC}"; }
print_warning() { echo -e "${YELLOW}[!] $1${NC}"; }
print_error() { echo -e "${RED}[✗] $1${NC}"; }

# Install dependencies
install_deps() {
    print_info "Installing system dependencies..."
    
    if command -v apt &> /dev/null; then
        apt update -y
        apt install -y python3 python3-pip git ffmpeg curl wget nano
    elif command -v yum &> /dev/null; then
        yum install -y python3 python3-pip git ffmpeg curl wget nano
    elif command -v dnf &> /dev/null; then
        dnf install -y python3 python3-pip git ffmpeg curl wget nano
    else
        print_error "Unsupported OS"
        exit 1
    fi
    
    print_success "Dependencies installed"
}

# Install Python packages
install_python_packages() {
    print_info "Installing Python packages..."
    
    pip3 install --upgrade pip
    pip3 install python-telegram-bot yt-dlp requests
    
    print_success "Python packages installed"
}

# Create bot directory
create_bot_dir() {
    print_info "Creating bot directory..."
    
    rm -rf /opt/twitter_bot
    mkdir -p /opt/twitter_bot
    cd /opt/twitter_bot
    
    print_success "Directory created: /opt/twitter_bot"
}

# Create bot.py script
create_bot_script() {
    print_info "Creating bot script..."
    
    cat > /opt/twitter_bot/bot.py << 'EOF'
#!/usr/bin/env python3
"""
Simple Telegram Twitter/X Video Downloader Bot
"""

import os
import logging
import subprocess
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes

# Setup logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# Bot token (will be set from environment or manually)
BOT_TOKEN = os.getenv('BOT_TOKEN', '')

async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command"""
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
    """
    await update.message.reply_text(text)

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /help command"""
    text = """
🤖 Bot Help

📌 How to download:
1. Copy Twitter/X video link
2. Send to this bot
3. Wait for download
4. Receive video

📌 Note:
• Max file size: 50MB
• Download may take 1-2 minutes
    """
    await update.message.reply_text(text)

def is_twitter_url(url):
    """Check if URL is from Twitter/X"""
    return any(domain in url for domain in ['twitter.com', 'x.com', 't.co'])

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle incoming messages"""
    message = update.message
    url = message.text.strip()
    
    if not is_twitter_url(url):
        await message.reply_text("❌ Please send a valid Twitter/X URL")
        return
    
    # Send processing message
    status_msg = await message.reply_text("⏳ Processing your request...")
    
    try:
        # Create temp directory
        os.makedirs('/tmp/twitter_dl', exist_ok=True)
        os.chdir('/tmp/twitter_dl')
        
        # Download video
        await status_msg.edit_text("📥 Downloading video...")
        
        # Use yt-dlp to download
        cmd = [
            'yt-dlp',
            '-f', 'best[filesize<50M]',
            '-o', 'video.%(ext)s',
            '--no-warnings',
            url
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
        
        if result.returncode == 0:
            # Find downloaded file
            files = [f for f in os.listdir('.') if f.startswith('video.')]
            if files:
                video_file = files[0]
                
                # Send video
                await status_msg.edit_text("📤 Sending video...")
                
                with open(video_file, 'rb') as f:
                    await context.bot.send_video(
                        chat_id=message.chat_id,
                        video=f,
                        caption="✅ Downloaded successfully!",
                        supports_streaming=True
                    )
                
                # Cleanup
                os.remove(video_file)
                await status_msg.delete()
            else:
                await status_msg.edit_text("❌ No video file found")
        else:
            error_msg = result.stderr[:100] if result.stderr else "Unknown error"
            await status_msg.edit_text(f"❌ Download failed: {error_msg}")
            
    except subprocess.TimeoutExpired:
        await status_msg.edit_text("❌ Download timeout (3 minutes)")
    except Exception as e:
        logger.error(f"Error: {e}")
        await status_msg.edit_text(f"❌ Error: {str(e)[:100]}")
    finally:
        os.chdir('/')

async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle errors"""
    logger.error(f"Error: {context.error}")

def main():
    """Main function"""
    if not BOT_TOKEN:
        print("❌ ERROR: BOT_TOKEN not set")
        print("Please set your bot token:")
        print("1. export BOT_TOKEN='your_token'")
        print("2. Or add to .env file")
        exit(1)
    
    # Create application
    app = Application.builder().token(BOT_TOKEN).build()
    
    # Add handlers
    app.add_handler(CommandHandler("start", start_command))
    app.add_handler(CommandHandler("help", help_command))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    app.add_error_handler(error_handler)
    
    print("🤖 Bot starting...")
    app.run_polling()

if __name__ == '__main__':
    main()
EOF
    
    chmod +x /opt/twitter_bot/bot.py
    print_success "Bot script created"
}

# Create environment file
create_env_file() {
    print_info "Creating environment file..."
    
    cat > /opt/twitter_bot/.env.example << EOF
# Telegram Bot Token from @BotFather
# Example: 1234567890:ABCdefGhIJKlmNoPQRsTUVwxyZ
BOT_TOKEN=your_bot_token_here
EOF
    
    print_success "Environment file created"
}

# Create service file
create_service_file() {
    print_info "Creating systemd service..."
    
    cat > /etc/systemd/system/twitter-bot.service << EOF
[Unit]
Description=Telegram Twitter/X Video Downloader Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/twitter_bot
Environment=BOT_TOKEN=your_bot_token_here
ExecStart=/usr/bin/python3 /opt/twitter_bot/bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    print_success "Service file created"
}

# Create control script
create_control_script() {
    print_info "Creating control script..."
    
    cat > /usr/local/bin/twitter-bot << 'EOF'
#!/bin/bash

case "$1" in
    start)
        if [ ! -f /opt/twitter_bot/.env ]; then
            echo "❌ Please setup bot first: twitter-bot setup"
            exit 1
        fi
        
        # Load environment
        export $(grep -v '^#' /opt/twitter_bot/.env | xargs)
        
        if [ -z "$BOT_TOKEN" ]; then
            echo "❌ BOT_TOKEN not found in .env file"
            exit 1
        fi
        
        # Update service with token
        sed -i "s|Environment=BOT_TOKEN=.*|Environment=BOT_TOKEN=$BOT_TOKEN|" /etc/systemd/system/twitter-bot.service
        systemctl daemon-reload
        
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
        systemctl status twitter-bot --no-pager -l
        ;;
    logs)
        journalctl -u twitter-bot -f
        ;;
    setup)
        echo "📝 Setting up bot..."
        
        # Check if .env exists
        if [ ! -f /opt/twitter_bot/.env ]; then
            cp /opt/twitter_bot/.env.example /opt/twitter_bot/.env
            echo ""
            echo "📋 Created .env file at /opt/twitter_bot/.env"
            echo "Please edit it and add your BOT_TOKEN:"
            echo ""
            echo "How to get BOT_TOKEN:"
            echo "1. Open Telegram"
            echo "2. Search for @BotFather"
            echo "3. Send /newbot"
            echo "4. Follow instructions"
            echo "5. Copy the token"
            echo ""
            echo "Then edit the file: nano /opt/twitter_bot/.env"
        else
            echo "✅ .env file already exists"
        fi
        ;;
    config)
        nano /opt/twitter_bot/.env
        ;;
    update)
        echo "🔄 Updating packages..."
        pip3 install --upgrade python-telegram-bot yt-dlp requests
        echo "✅ Packages updated"
        ;;
    test)
        echo "🧪 Testing installation..."
        echo ""
        echo "1. Testing Python packages..."
        python3 -c "import telegram; import yt_dlp; import requests; print('✅ All packages imported successfully')"
        echo ""
        echo "2. Testing yt-dlp..."
        yt-dlp --version
        echo ""
        echo "3. Testing bot script..."
        if [ -f /opt/twitter_bot/.env ]; then
            export $(grep -v '^#' /opt/twitter_bot/.env | xargs)
            if [ -n "$BOT_TOKEN" ]; then
                echo "✅ BOT_TOKEN found in .env"
            else
                echo "❌ BOT_TOKEN not found in .env"
            fi
        else
            echo "❌ .env file not found"
        fi
        ;;
    *)
        echo "🤖 Twitter/X Downloader Bot Control"
        echo ""
        echo "Usage: $0 {start|stop|restart|status|logs|setup|config|update|test}"
        echo ""
        echo "Commands:"
        echo "  start     - Start bot"
        echo "  stop      - Stop bot"
        echo "  restart   - Restart bot"
        echo "  status    - Check status"
        echo "  logs      - View logs"
        echo "  setup     - Initial setup (IMPORTANT!)"
        echo "  config    - Edit config"
        echo "  update    - Update packages"
        echo "  test      - Test installation"
        echo ""
        echo "Quick start:"
        echo "  1. twitter-bot setup"
        echo "  2. twitter-bot config  (add your token)"
        echo "  3. twitter-bot start"
        echo "  4. twitter-bot logs    (to monitor)"
        ;;
esac
EOF
    
    chmod +x /usr/local/bin/twitter-bot
    print_success "Control script created"
}

# Show completion message
show_completion() {
    echo ""
    echo -e "${GREEN}==============================================${NC}"
    echo -e "${GREEN}        INSTALLATION COMPLETE!              ${NC}"
    echo -e "${GREEN}==============================================${NC}"
    echo ""
    echo -e "${YELLOW}🚀 QUICK START GUIDE:${NC}"
    echo ""
    echo "1. First, setup the bot:"
    echo "   twitter-bot setup"
    echo ""
    echo "2. Edit the config file and add your bot token:"
    echo "   twitter-bot config"
    echo ""
    echo "3. Test the installation:"
    echo "   twitter-bot test"
    echo ""
    echo "4. Start the bot:"
    echo "   twitter-bot start"
    echo ""
    echo "5. Check status:"
    echo "   twitter-bot status"
    echo "   twitter-bot logs"
    echo ""
    echo -e "${YELLOW}📱 HOW TO USE:${NC}"
    echo ""
    echo "1. Find a Twitter/X video"
    echo "2. Copy the link"
    echo "3. Send to your bot on Telegram"
    echo "4. Wait for download"
    echo "5. Receive video"
    echo ""
    echo -e "${YELLOW}🔧 BOT COMMANDS:${NC}"
    echo "/start - Welcome message"
    echo "/help  - Help information"
    echo ""
    echo -e "${GREEN}✅ Ready to configure!${NC}"
    echo ""
}

# Main installation
main() {
    show_logo
    install_deps
    install_python_packages
    create_bot_dir
    create_bot_script
    create_env_file
    create_service_file
    create_control_script
    show_completion
}

# Run installation
main
