#!/bin/bash

# Telegram Twitter/X Video Downloader Bot Installer
# For fresh Linux servers

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
    echo "║                                                  ║"
    echo "╚══════════════════════════════════════════════════╝"
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
        print_warning "This script should be run as root"
        print_info "Trying to continue anyway..."
    fi
}

# Install system dependencies
install_dependencies() {
    print_info "Installing system dependencies..."
    
    # Update system
    if command -v apt &> /dev/null; then
        apt update -y
        apt upgrade -y
        apt install -y python3 python3-pip python3-venv git ffmpeg curl wget tmux
    elif command -v yum &> /dev/null; then
        yum update -y
        yum install -y python3 python3-pip git ffmpeg curl wget tmux
    elif command -v dnf &> /dev/null; then
        dnf update -y
        dnf install -y python3 python3-pip git ffmpeg curl wget tmux
    else
        print_error "Unsupported package manager"
        exit 1
    fi
    
    print_success "System dependencies installed"
}

# Install Python packages
install_python_packages() {
    print_info "Installing Python packages..."
    
    pip3 install --upgrade pip
    
    # Install Telegram bot and downloader packages
    pip3 install python-telegram-bot yt-dlp requests python-dotenv
    
    print_success "Python packages installed"
}

# Create bot directory structure
create_directory() {
    print_info "Creating directory structure..."
    
    mkdir -p /opt/telegram-twitter-bot
    mkdir -p /opt/telegram-twitter-bot/downloads
    mkdir -p /opt/telegram-twitter-bot/logs
    
    print_success "Directories created"
}

# Create Telegram bot Python script
create_bot_script() {
    print_info "Creating Telegram bot script..."
    
    cat > /opt/telegram-twitter-bot/bot.py << 'EOF'
#!/usr/bin/env python3
"""
Telegram Twitter/X Video Downloader Bot
Send Twitter/X links to download videos
"""

import os
import logging
import subprocess
import json
from datetime import datetime
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application,
    CommandHandler,
    MessageHandler,
    CallbackQueryHandler,
    filters,
    ContextTypes
)
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Bot configuration
BOT_TOKEN = os.getenv('BOT_TOKEN')
ADMIN_IDS = [int(id.strip()) for id in os.getenv('ADMIN_IDS', '').split(',') if id.strip()]
DOWNLOAD_PATH = '/opt/telegram-twitter-bot/downloads'
MAX_FILE_SIZE = 2000 * 1024 * 1024  # 2GB

# Setup logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO,
    filename='/opt/telegram-twitter-bot/logs/bot.log'
)
logger = logging.getLogger(__name__)

class TwitterDownloaderBot:
    def __init__(self):
        self.quality_options = {
            'best': 'Best Quality',
            'worst': 'Worst Quality',
            '360': '360p',
            '480': '480p',
            '720': '720p',
            '1080': '1080p',
            '1440': '1440p',
            '2160': '4K (2160p)'
        }
    
    def is_admin(self, user_id: int) -> bool:
        """Check if user is admin"""
        return user_id in ADMIN_IDS if ADMIN_IDS else True
    
    def is_twitter_url(self, url: str) -> bool:
        """Check if URL is from Twitter/X"""
        twitter_domains = ['twitter.com', 'x.com', 't.co']
        return any(domain in url.lower() for domain in twitter_domains)
    
    def get_video_info(self, url: str):
        """Get video information using yt-dlp"""
        try:
            cmd = ['yt-dlp', '--skip-download', '--dump-json', url]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                info = json.loads(result.stdout)
                return {
                    'success': True,
                    'title': info.get('title', 'Unknown'),
                    'duration': info.get('duration_string', 'Unknown'),
                    'thumbnail': info.get('thumbnail', None),
                    'formats': info.get('formats', []),
                    'filesize': info.get('filesize', info.get('filesize_approx', 0))
                }
            else:
                return {'success': False, 'error': result.stderr}
                
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    def get_available_formats(self, url: str):
        """Get available formats list"""
        try:
            cmd = ['yt-dlp', '-F', url]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            return result.stdout if result.returncode == 0 else None
        except:
            return None
    
    def download_video(self, url: str, quality: str, chat_id: int):
        """Download video with specified quality"""
        try:
            # Create download directory for this chat
            chat_dir = os.path.join(DOWNLOAD_PATH, str(chat_id))
            os.makedirs(chat_dir, exist_ok=True)
            
            # Change to chat directory
            os.chdir(chat_dir)
            
            # Build download command
            if quality in ['best', 'worst']:
                format_code = quality
            else:
                format_code = f"bestvideo[height<={quality}]+bestaudio/best[height<={quality}]"
            
            # Output template
            output_template = f'%(title)s_{quality}p.%(ext)s'
            
            # Download command
            cmd = [
                'yt-dlp',
                '-f', format_code,
                '-o', output_template,
                '--progress',
                '--no-warnings',
                url
            ]
            
            # Run download
            logger.info(f"Downloading: {url} with quality: {quality}")
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=3600)
            
            if result.returncode == 0:
                # Find downloaded file
                downloaded_files = [f for f in os.listdir(chat_dir) if f.endswith(('.mp4', '.mkv', '.webm'))]
                if downloaded_files:
                    latest_file = max(downloaded_files, key=os.path.getctime)
                    file_path = os.path.join(chat_dir, latest_file)
                    file_size = os.path.getsize(file_path)
                    
                    if file_size > MAX_FILE_SIZE:
                        os.remove(file_path)
                        return {'success': False, 'error': f'File too large ({file_size//(1024*1024)}MB > {MAX_FILE_SIZE//(1024*1024)}MB)'}
                    
                    return {'success': True, 'file_path': file_path, 'file_size': file_size}
                else:
                    return {'success': False, 'error': 'No video file found after download'}
            else:
                return {'success': False, 'error': result.stderr}
                
        except subprocess.TimeoutExpired:
            return {'success': False, 'error': 'Download timeout (1 hour)'}
        except Exception as e:
            return {'success': False, 'error': str(e)}
        finally:
            # Return to original directory
            os.chdir('/opt/telegram-twitter-bot')
    
    async def start_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Handle /start command"""
        user = update.effective_user
        welcome_text = f"""
🤖 *Welcome {user.first_name}!*

I can download videos from Twitter/X for you.

*How to use:*
1. Send me any Twitter/X link
2. Choose video quality
3. Wait for download

*Commands:*
/start - Show this message
/help - Show help
/formats <url> - Show available formats
/stats - Show bot statistics

*Examples:*
• Send: `https://twitter.com/username/status/1234567890`
• Send: `https://x.com/username/status/1234567890`

⚠️ *Note:* Maximum file size is 2GB
        """
        
        await update.message.reply_text(welcome_text, parse_mode='Markdown')
    
    async def help_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Handle /help command"""
        help_text = """
*Available Commands:*

/start - Start the bot
/help - Show this help
/formats <url> - Show available formats for a URL
/stats - Show bot statistics (admin only)

*How to download:*
1. Send a Twitter/X URL
2. Choose quality from buttons
3. Wait for download
4. Receive video file

*Supported URLs:*
• twitter.com/*
• x.com/*
• t.co/* (Twitter short links)

*Quality options:*
• Best Quality (auto select)
• 360p, 480p, 720p, 1080p, 1440p, 4K
        """
        
        await update.message.reply_text(help_text, parse_mode='Markdown')
    
    async def formats_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Handle /formats command"""
        if not context.args:
            await update.message.reply_text("Please provide a URL:\n`/formats https://twitter.com/...`", parse_mode='Markdown')
            return
        
        url = context.args[0]
        if not self.is_twitter_url(url):
            await update.message.reply_text("❌ Please provide a valid Twitter/X URL")
            return
        
        await update.message.reply_text("⏳ Getting available formats...")
        
        formats = self.get_available_formats(url)
        if formats:
            # Split long message
            max_length = 4000
            if len(formats) > max_length:
                for i in range(0, len(formats), max_length):
                    await update.message.reply_text(f"```\n{formats[i:i+max_length]}\n```", parse_mode='Markdown')
            else:
                await update.message.reply_text(f"```\n{formats}\n```", parse_mode='Markdown')
        else:
            await update.message.reply_text("❌ Could not get format information")
    
    async def stats_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Handle /stats command (admin only)"""
        user_id = update.effective_user.id
        
        if not self.is_admin(user_id):
            await update.message.reply_text("❌ This command is for admins only")
            return
        
        try:
            # Get download directory size
            total_size = 0
            file_count = 0
            
            for dirpath, dirnames, filenames in os.walk(DOWNLOAD_PATH):
                for f in filenames:
                    fp = os.path.join(dirpath, f)
                    total_size += os.path.getsize(fp)
                    file_count += 1
            
            stats_text = f"""
📊 *Bot Statistics*

*Storage:*
• Total files: {file_count}
• Total size: {total_size // (1024*1024)} MB
• Free space: {self.get_free_space()}

*Paths:*
• Bot: /opt/telegram-twitter-bot
• Downloads: {DOWNLOAD_PATH}
• Logs: /opt/telegram-twitter-bot/logs
            """
            
            await update.message.reply_text(stats_text, parse_mode='Markdown')
            
        except Exception as e:
            await update.message.reply_text(f"❌ Error getting stats: {str(e)}")
    
    def get_free_space(self):
        """Get free disk space"""
        try:
            stat = os.statvfs(DOWNLOAD_PATH)
            free = stat.f_bavail * stat.f_frsize
            return f"{free // (1024**3)} GB"
        except:
            return "Unknown"
    
    async def handle_message(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Handle incoming messages"""
        message = update.message
        user_id = message.from_user.id
        text = message.text
        
        # Check if message contains URL
        if not self.is_twitter_url(text):
            await message.reply_text("Please send a valid Twitter/X URL\nExample: https://twitter.com/username/status/1234567890")
            return
        
        # Store URL in user data
        context.user_data['url'] = text
        
        # Get video info
        await message.reply_text("🔍 Analyzing video...")
        info = self.get_video_info(text)
        
        if not info['success']:
            await message.reply_text(f"❌ Error: {info['error']}")
            return
        
        # Prepare quality selection keyboard
        keyboard = []
        row = []
        
        for quality_code, quality_name in self.quality_options.items():
            row.append(InlineKeyboardButton(quality_name, callback_data=f"quality_{quality_code}"))
            if len(row) == 2:
                keyboard.append(row)
                row = []
        
        if row:
            keyboard.append(row)
        
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        # Send video info with quality options
        info_text = f"""
📹 *Video Information*

*Title:* {info['title']}
*Duration:* {info['duration']}
*Size:* {self.format_size(info['filesize'])}

Please select video quality:
        """
        
        await message.reply_text(info_text, parse_mode='Markdown', reply_markup=reply_markup)
    
    async def handle_callback(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Handle callback queries (quality selection)"""
        query = update.callback_query
        await query.answer()
        
        user_id = query.from_user.id
        callback_data = query.data
        
        if callback_data.startswith('quality_'):
            quality = callback_data.split('_')[1]
            url = context.user_data.get('url')
            
            if not url:
                await query.edit_message_text("❌ URL not found. Please send the URL again.")
                return
            
            # Update message to show downloading
            await query.edit_message_text(f"⏬ Downloading {self.quality_options[quality]}...\nThis may take a few minutes.")
            
            # Download video
            result = self.download_video(url, quality, user_id)
            
            if result['success']:
                # Send video file
                with open(result['file_path'], 'rb') as video_file:
                    await context.bot.send_video(
                        chat_id=user_id,
                        video=video_file,
                        caption=f"✅ Downloaded successfully!\nQuality: {self.quality_options[quality]}\nSize: {self.format_size(result['file_size'])}",
                        supports_streaming=True
                    )
                
                # Clean up file
                try:
                    os.remove(result['file_path'])
                except:
                    pass
                    
                await query.edit_message_text("✅ Download complete! Video sent.")
            else:
                await query.edit_message_text(f"❌ Download failed:\n{result['error']}")
    
    def format_size(self, size_bytes):
        """Format file size"""
        if not size_bytes:
            return "Unknown"
        
        for unit in ['B', 'KB', 'MB', 'GB']:
            if size_bytes < 1024.0:
                return f"{size_bytes:.1f} {unit}"
            size_bytes /= 1024.0
        return f"{size_bytes:.1f} TB"
    
    async def error_handler(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Handle errors"""
        logger.error(f"Update {update} caused error {context.error}")
        
        if update and update.effective_message:
            await update.effective_message.reply_text(
                "❌ An error occurred. Please try again or contact admin."
            )

def main():
    """Main function to run the bot"""
    if not BOT_TOKEN:
        print("❌ Error: BOT_TOKEN not found in environment variables")
        print("Please create .env file with your bot token")
        exit(1)
    
    # Create bot instance
    bot = TwitterDownloaderBot()
    
    # Create application
    application = Application.builder().token(BOT_TOKEN).build()
    
    # Add handlers
    application.add_handler(CommandHandler("start", bot.start_command))
    application.add_handler(CommandHandler("help", bot.help_command))
    application.add_handler(CommandHandler("formats", bot.formats_command))
    application.add_handler(CommandHandler("stats", bot.stats_command))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, bot.handle_message))
    application.add_handler(CallbackQueryHandler(bot.handle_callback))
    
    # Add error handler
    application.add_error_handler(bot.error_handler)
    
    print("🤖 Bot is starting...")
    print(f"📁 Download path: {DOWNLOAD_PATH}")
    print(f"👑 Admin IDs: {ADMIN_IDS}")
    
    # Start bot
    application.run_polling(allowed_updates=Update.ALL_TYPES)

if __name__ == '__main__':
    main()
EOF
    
    chmod +x /opt/telegram-twitter-bot/bot.py
    
    print_success "Bot script created"
}

# Create .env file template
create_env_file() {
    print_info "Creating environment file template..."
    
    cat > /opt/telegram-twitter-bot/.env.example << 'EOF'
# Telegram Bot Token from @BotFather
BOT_TOKEN=your_bot_token_here

# Admin Telegram User IDs (comma separated)
ADMIN_IDS=123456789,987654321

# Maximum file size in bytes (default: 2GB)
MAX_FILE_SIZE=2147483648

# Download path (don't change unless you know what you're doing)
DOWNLOAD_PATH=/opt/telegram-twitter-bot/downloads
EOF
    
    print_info "Please create .env file with your bot token:"
    print_info "cd /opt/telegram-twitter-bot && cp .env.example .env"
    print_info "Then edit .env and add your BOT_TOKEN"
}

# Create systemd service
create_systemd_service() {
    print_info "Creating systemd service..."
    
    cat > /etc/systemd/system/telegram-twitter-bot.service << 'EOF'
[Unit]
Description=Telegram Twitter/X Video Downloader Bot
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/telegram-twitter-bot
ExecStart=/usr/bin/python3 /opt/telegram-twitter-bot/bot.py
Restart=always
RestartSec=10
StandardOutput=append:/opt/telegram-twitter-bot/logs/bot.log
StandardError=append:/opt/telegram-twitter-bot/logs/error.log
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    
    print_success "Systemd service created"
}

# Create management script
create_management_script() {
    print_info "Creating management script..."
    
    cat > /usr/local/bin/twitter-bot << 'EOF'
#!/bin/bash
# Telegram Twitter Bot Management Script

case "$1" in
    start)
        systemctl start telegram-twitter-bot
        echo "Bot started"
        ;;
    stop)
        systemctl stop telegram-twitter-bot
        echo "Bot stopped"
        ;;
    restart)
        systemctl restart telegram-twitter-bot
        echo "Bot restarted"
        ;;
    status)
        systemctl status telegram-twitter-bot
        ;;
    logs)
        tail -f /opt/telegram-twitter-bot/logs/bot.log
        ;;
    env)
        nano /opt/telegram-twitter-bot/.env
        ;;
    update)
        cd /opt/telegram-twitter-bot && git pull
        pip3 install -r requirements.txt 2>/dev/null || pip3 install python-telegram-bot yt-dlp
        systemctl restart telegram-twitter-bot
        echo "Bot updated"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|env|update}"
        echo ""
        echo "Commands:"
        echo "  start    - Start the bot"
        echo "  stop     - Stop the bot"
        echo "  restart  - Restart the bot"
        echo "  status   - Check bot status"
        echo "  logs     - View bot logs"
        echo "  env      - Edit environment file"
        echo "  update   - Update bot"
        ;;
esac
EOF
    
    chmod +x /usr/local/bin/twitter-bot
    
    print_success "Management script created"
}

# Create requirements file
create_requirements_file() {
    print_info "Creating requirements file..."
    
    cat > /opt/telegram-twitter-bot/requirements.txt << 'EOF'
python-telegram-bot>=20.7
yt-dlp>=2023.11.16
requests>=2.31.0
python-dotenv>=1.0.0
EOF
    
    print_success "Requirements file created"
}

# Show installation complete message
show_completion() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════╗"
    echo "║                                                  ║"
    echo "║           INSTALLATION COMPLETE! 🎉             ║"
    echo "║                                                  ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "\n${CYAN}📋 NEXT STEPS:${NC}"
    echo -e "${YELLOW}1. Get a Telegram Bot Token:${NC}"
    echo "   • Open Telegram"
    echo "   • Search for @BotFather"
    echo "   • Send /newbot command"
    echo "   • Follow instructions to create bot"
    echo "   • Copy the bot token"
    
    echo -e "\n${YELLOW}2. Configure the bot:${NC}"
    echo "   cd /opt/telegram-twitter-bot"
    echo "   cp .env.example .env"
    echo "   nano .env"
    echo "   • Add your BOT_TOKEN"
    echo "   • Add your Telegram ID to ADMIN_IDS"
    
    echo -e "\n${YELLOW}3. Find your Telegram ID:${NC}"
    echo "   • Open Telegram"
    echo "   • Search for @userinfobot"
    echo "   • Send /start"
    echo "   • Copy your ID"
    
    echo -e "\n${YELLOW}4. Start the bot:${NC}"
    echo "   twitter-bot start"
    
    echo -e "\n${YELLOW}5. Check bot status:${NC}"
    echo "   twitter-bot status"
    
    echo -e "\n${CYAN}🔧 Management Commands:${NC}"
    echo "   twitter-bot start      # Start bot"
    echo "   twitter-bot stop       # Stop bot"
    echo "   twitter-bot restart    # Restart bot"
    echo "   twitter-bot status     # Check status"
    echo "   twitter-bot logs       # View logs"
    echo "   twitter-bot env        # Edit config"
    echo "   twitter-bot update     # Update bot"
    
    echo -e "\n${CYAN}📁 Bot Location:${NC}"
    echo "   Directory: /opt/telegram-twitter-bot"
    echo "   Config: /opt/telegram-twitter-bot/.env"
    echo "   Logs: /opt/telegram-twitter-bot/logs/"
    echo "   Downloads: /opt/telegram-twitter-bot/downloads/"
    
    echo -e "\n${CYAN}🤖 How to use:${NC}"
    echo "   1. Start your bot on Telegram"
    echo "   2. Send a Twitter/X URL to the bot"
    echo "   3. Select video quality"
    echo "   4. Wait for download"
    echo "   5. Receive video file"
    
    echo -e "\n${YELLOW}⚠️  Important:${NC}"
    echo "   • Bot must run 24/7 to receive messages"
    echo "   • Use 'twitter-bot start' to launch"
    echo "   • Bot will auto-restart if crashes"
    echo "   • Check logs if having issues"
    
    echo -e "\n${GREEN}✅ Ready to configure!${NC}"
}

# Main installation
main() {
    show_logo
    check_root
    install_dependencies
    install_python_packages
    create_directory
    create_bot_script
    create_env_file
    create_requirements_file
    create_systemd_service
    create_management_script
    show_completion
}

# Run installation
main
