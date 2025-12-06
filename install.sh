#!/bin/bash

# Telegram Twitter/X Video Downloader Bot Installer - Fixed Version
# Now shows only available formats for each video

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
    echo "=============================================="
    echo "   TELEGRAM TWITTER/X DOWNLOADER BOT"
    echo "         SMART VERSION 2.0"
    echo "=============================================="
    echo -e "${NC}"
}

# Print functions
print_info() { echo -e "${CYAN}[*] $1${NC}"; }
print_success() { echo -e "${GREEN}[✓] $1${NC}"; }
print_warning() { echo -e "${YELLOW}[!] $1${NC}"; }
print_error() { echo -e "${RED}[✗] $1${NC}"; }

# Install dependencies
install_deps() {
    print_info "Installing system dependencies..."
    
    if command -v apt &> /dev/null; then
        apt update -y
        apt install -y python3 python3-pip git ffmpeg curl wget nano jq
    elif command -v yum &> /dev/null; then
        yum install -y python3 python3-pip git ffmpeg curl wget nano jq
    elif command -v dnf &> /dev/null; then
        dnf install -y python3 python3-pip git ffmpeg curl wget nano jq
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
    pip3 install "python-telegram-bot==20.7" "yt-dlp>=2023.11.16" requests
    
    print_success "Python packages installed"
}

# Create bot directory
create_bot_dir() {
    print_info "Creating bot directory..."
    
    rm -rf /opt/smart_twitter_bot
    mkdir -p /opt/smart_twitter_bot
    cd /opt/smart_twitter_bot
    
    print_success "Directory created: /opt/smart_twitter_bot"
}

# Create bot.py script (SMART VERSION)
create_bot_script() {
    print_info "Creating smart bot script..."
    
    cat > /opt/smart_twitter_bot/bot.py << 'EOF'
#!/usr/bin/env python3
"""
Smart Telegram Twitter/X Video Downloader Bot
Only shows available formats for each video
"""

import os
import json
import logging
import subprocess
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes, CallbackQueryHandler

# Setup logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO,
    filename='/opt/smart_twitter_bot/bot.log'
)
logger = logging.getLogger(__name__)

# Bot token (will be set from environment)
BOT_TOKEN = os.getenv('BOT_TOKEN', '')

async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command"""
    user = update.effective_user
    text = f"""
👋 Welcome {user.first_name}!

I can download videos from Twitter/X for you.

📌 How to use:
1. Send me any Twitter/X link
2. I'll show available qualities
3. Select quality
4. Receive video

🔗 Examples:
• https://twitter.com/user/status/1234567890
• https://x.com/user/status/1234567890

⚡ Commands:
/start - Show this message
/help - Help information
/direct <url> - Direct download (best quality)

🔧 Smart Features:
• Shows only available formats
• Auto-detects best quality
• Supports all Twitter/X links
    """
    await update.message.reply_text(text)

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /help command"""
    text = """
🤖 Bot Help

📌 How to download:
1. Copy Twitter/X video link
2. Send to this bot
3. Select available quality
4. Wait for download
5. Receive video

📌 Direct download:
/direct <url> - Download with best quality

📌 Note:
• Max file size: 2GB (Telegram limit)
• Shows only available formats
• Auto-retry on failure
    """
    await update.message.reply_text(text)

async def direct_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /direct command"""
    if not context.args:
        await update.message.reply_text("Usage: /direct <twitter-url>")
        return
    
    url = context.args[0]
    user_id = update.effective_user.id
    
    if not is_twitter_url(url):
        await update.message.reply_text("❌ Please provide a valid Twitter/X URL")
        return
    
    # Store URL
    context.user_data['url'] = url
    
    # Download with best quality
    msg = await update.message.reply_text("⏳ Downloading with best quality...")
    success = await download_video(url, "best", user_id, msg, context)
    
    if success:
        await msg.edit_text("✅ Download completed!")
    else:
        await msg.edit_text("❌ Download failed. Try selecting quality manually.")

def is_twitter_url(url):
    """Check if URL is from Twitter/X"""
    twitter_domains = ['twitter.com', 'x.com', 't.co']
    return any(domain in url.lower() for domain in twitter_domains)

def get_available_formats(url):
    """Get only available formats for this video"""
    try:
        # Get video info in JSON format
        cmd = ['yt-dlp', '--skip-download', '--dump-json', '--no-warnings', url]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        
        if result.returncode != 0:
            return None
        
        info = json.loads(result.stdout)
        formats = info.get('formats', [])
        
        # Filter video formats
        video_formats = []
        for fmt in formats:
            # Check if it's a video format
            if fmt.get('vcodec') != 'none' and fmt.get('acodec') != 'none':
                height = fmt.get('height', 0)
                if height > 0:
                    quality = f"{height}p"
                    format_id = fmt.get('format_id', '')
                    filesize = fmt.get('filesize', fmt.get('filesize_approx', 0))
                    
                    # Format size
                    if filesize:
                        size_mb = filesize / (1024 * 1024)
                        size_str = f"{size_mb:.1f}MB"
                    else:
                        size_str = "N/A"
                    
                    video_formats.append({
                        'quality': quality,
                        'format_id': format_id,
                        'height': height,
                        'size': size_str,
                        'ext': fmt.get('ext', 'mp4')
                    })
        
        # Remove duplicates and sort by quality
        unique_formats = {}
        for fmt in video_formats:
            if fmt['quality'] not in unique_formats:
                unique_formats[fmt['quality']] = fmt
            elif fmt['height'] > unique_formats[fmt['quality']]['height']:
                unique_formats[fmt['quality']] = fmt
        
        # Sort by height descending
        sorted_formats = sorted(unique_formats.values(), key=lambda x: x['height'], reverse=True)
        
        # Add "best" option
        sorted_formats.insert(0, {
            'quality': 'best',
            'format_id': 'best',
            'height': 9999,
            'size': 'Auto',
            'ext': 'mp4'
        })
        
        return sorted_formats
        
    except Exception as e:
        logger.error(f"Error getting formats: {e}")
        return None

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle incoming messages"""
    message = update.message
    url = message.text.strip()
    
    if not is_twitter_url(url):
        await message.reply_text("❌ Please send a valid Twitter/X URL")
        return
    
    # Store URL in user data
    context.user_data['url'] = url
    
    # Get video info
    msg = await message.reply_text("🔍 Analyzing video...")
    
    # Get available formats
    formats = get_available_formats(url)
    
    if not formats:
        await msg.edit_text("❌ Could not get video information. The video might be private or deleted.")
        return
    
    # Create keyboard with available formats
    keyboard = []
    row = []
    
    for i, fmt in enumerate(formats):
        if i > 0 and i % 2 == 0:
            keyboard.append(row)
            row = []
        
        button_text = f"{fmt['quality']} ({fmt['size']})"
        callback_data = f"quality:{fmt['format_id']}:{fmt['quality']}"
        row.append(InlineKeyboardButton(button_text, callback_data=callback_data))
    
    if row:
        keyboard.append(row)
    
    # Add "Best Quality" button separately
    keyboard.append([InlineKeyboardButton("🎯 Best Quality (Auto)", callback_data="quality:best:best")])
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await msg.edit_text(
        f"📹 Available qualities for this video:\n\n"
        f"🔗 URL: {url[:50]}...\n"
        f"📊 Select quality:",
        reply_markup=reply_markup
    )

async def handle_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle callback queries (quality selection)"""
    query = update.callback_query
    await query.answer()
    
    user_id = query.from_user.id
    callback_data = query.data
    
    if callback_data.startswith('quality:'):
        _, format_id, quality_name = callback_data.split(':')
        url = context.user_data.get('url')
        
        if not url:
            await query.edit_message_text("❌ URL not found. Please send the URL again.")
            return
        
        # Update message
        await query.edit_message_text(f"⏬ Downloading {quality_name} quality...\nThis may take a minute.")
        
        # Download video
        success = await download_video(url, format_id, user_id, query.message, context)
        
        if success:
            await query.edit_message_text("✅ Download completed! Video sent.")
        else:
            await query.edit_message_text("❌ Download failed. Try another quality or use /direct command.")

async def download_video(url, format_id, user_id, message, context):
    """Download video with specified format"""
    try:
        # Create temp directory
        os.makedirs('/tmp/twitter_dl', exist_ok=True)
        os.chdir('/tmp/twitter_dl')
        
        # Clean previous files
        for f in os.listdir('.'):
            if f.endswith(('.mp4', '.mkv', '.webm')):
                os.remove(f)
        
        # Download with yt-dlp
        output_template = 'video_%(title)s_%(id)s.%(ext)s'
        cmd = [
            'yt-dlp',
            '-f', format_id,
            '-o', output_template,
            '--no-warnings',
            '--merge-output-format', 'mp4',
            url
        ]
        
        # Run download
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            universal_newlines=True
        )
        
        # Show progress
        for line in process.stdout:
            if '[download]' in line and '%' in line:
                # Extract progress percentage
                import re
                match = re.search(r'(\d+\.?\d*)%', line)
                if match:
                    progress = match.group(1)
                    try:
                        await message.edit_text(f"⏬ Downloading... {progress}%")
                    except:
                        pass
        
        process.wait()
        
        if process.returncode != 0:
            # Try with best format if specific format failed
            if format_id != 'best':
                await message.edit_text(f"⚠️ Format {format_id} not available. Trying best quality...")
                cmd = [
                    'yt-dlp',
                    '-f', 'best',
                    '-o', output_template,
                    '--no-warnings',
                    '--merge-output-format', 'mp4',
                    url
                ]
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
                if result.returncode != 0:
                    return False
        
        # Find downloaded file
        files = [f for f in os.listdir('.') if f.endswith(('.mp4', '.mkv', '.webm'))]
        if not files:
            return False
        
        video_file = max(files, key=os.path.getctime)
        file_size = os.path.getsize(video_file)
        
        # Check file size (Telegram limit: 2GB for bots)
        if file_size > 1.9 * 1024 * 1024 * 1024:  # 1.9GB
            await message.edit_text("❌ File too large (>1.9GB). Try lower quality.")
            os.remove(video_file)
            return False
        
        # Send video
        await message.edit_text("📤 Sending video...")
        
        with open(video_file, 'rb') as f:
            await context.bot.send_video(
                chat_id=user_id,
                video=f,
                caption=f"✅ Downloaded successfully!\nQuality: {format_id}",
                supports_streaming=True,
                read_timeout=60,
                write_timeout=60,
                connect_timeout=60,
                pool_timeout=60
            )
        
        # Cleanup
        os.remove(video_file)
        return True
        
    except subprocess.TimeoutExpired:
        await message.edit_text("❌ Download timeout (5 minutes)")
        return False
    except Exception as e:
        logger.error(f"Download error: {e}")
        await message.edit_text(f"❌ Error: {str(e)[:200]}")
        return False
    finally:
        os.chdir('/')

async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle errors"""
    logger.error(f"Error: {context.error}")
    try:
        if update.callback_query:
            await update.callback_query.message.reply_text("⚠️ An error occurred. Please try again.")
        elif update.message:
            await update.message.reply_text("⚠️ An error occurred. Please try again.")
    except:
        pass

def main():
    """Main function"""
    if not BOT_TOKEN:
        print("❌ ERROR: BOT_TOKEN not set")
        print("Please add your bot token to /opt/smart_twitter_bot/.env")
        exit(1)
    
    # Create application
    app = Application.builder().token(BOT_TOKEN).build()
    
    # Add handlers
    app.add_handler(CommandHandler("start", start_command))
    app.add_handler(CommandHandler("help", help_command))
    app.add_handler(CommandHandler("direct", direct_command))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    app.add_handler(CallbackQueryHandler(handle_callback))
    app.add_error_handler(error_handler)
    
    print("🤖 Smart Twitter Bot starting...")
    print("📁 Logs: /opt/smart_twitter_bot/bot.log")
    print("⚡ Features: Shows only available formats")
    
    app.run_polling()

if __name__ == '__main__':
    main()
EOF
    
    chmod +x /opt/smart_twitter_bot/bot.py
    print_success "Smart bot script created"
}

# Create environment file
create_env_file() {
    print_info "Creating environment file..."
    
    cat > /opt/smart_twitter_bot/.env.example << EOF
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
Description=Smart Telegram Twitter/X Video Downloader Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/smart_twitter_bot
EnvironmentFile=/opt/smart_twitter_bot/.env
ExecStart=/usr/bin/python3 /opt/smart_twitter_bot/bot.py
Restart=always
RestartSec=10
StandardOutput=append:/opt/smart_twitter_bot/bot.log
StandardError=append:/opt/smart_twitter_bot/error.log

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
        if [ ! -f /opt/smart_twitter_bot/.env ]; then
            echo "❌ Please setup bot first: twitter-bot setup"
            exit 1
        fi
        
        systemctl start twitter-bot
        echo "✅ Smart bot started"
        echo "📊 Features: Shows only available formats"
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
        if [ "$2" = "error" ]; then
            tail -f /opt/smart_twitter_bot/error.log
        else
            tail -f /opt/smart_twitter_bot/bot.log
        fi
        ;;
    setup)
        echo "📝 Setting up smart bot..."
        
        if [ ! -f /opt/smart_twitter_bot/.env ]; then
            cp /opt/smart_twitter_bot/.env.example /opt/smart_twitter_bot/.env
            echo ""
            echo "📋 Created .env file"
            echo "Please edit it and add your BOT_TOKEN:"
            echo "   nano /opt/smart_twitter_bot/.env"
            echo ""
            echo "🔑 How to get BOT_TOKEN:"
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
        nano /opt/smart_twitter_bot/.env
        ;;
    update)
        echo "🔄 Updating smart bot..."
        
        # Update yt-dlp (important for Twitter)
        pip3 install --upgrade yt-dlp
        pip3 install --upgrade python-telegram-bot requests
        
        # Update yt-dlp cookies (helps with Twitter)
        yt-dlp --cookies-from-browser chrome 2>/dev/null || true
        
        systemctl restart twitter-bot
        echo "✅ Smart bot updated and restarted"
        echo "🔧 Now supports all Twitter formats"
        ;;
    test)
        echo "🧪 Testing smart bot..."
        echo ""
        
        # Test yt-dlp with Twitter
        echo "1. Testing yt-dlp Twitter support..."
        yt-dlp --version
        echo ""
        
        # Test Python packages
        echo "2. Testing Python packages..."
        python3 -c "
try:
    import telegram
    print('✅ python-telegram-bot installed')
except:
    print('❌ python-telegram-bot missing')
    
try:
    import yt_dlp
    print('✅ yt-dlp installed')
except:
    print('❌ yt-dlp missing')
        "
        echo ""
        
        # Test config
        echo "3. Testing configuration..."
        if [ -f /opt/smart_twitter_bot/.env ]; then
            if grep -q "BOT_TOKEN" /opt/smart_twitter_bot/.env; then
                echo "✅ .env file has BOT_TOKEN"
            else
                echo "⚠️  .env file exists but BOT_TOKEN not set"
            fi
        else
            echo "❌ .env file not found"
        fi
        ;;
    fix-twitter)
        echo "🔧 Fixing Twitter download issues..."
        
        # Update yt-dlp
        pip3 install --upgrade yt-dlp
        
        # Clear yt-dlp cache
        yt-dlp --rm-cache-dir 2>/dev/null || true
        
        # Restart bot
        systemctl restart twitter-bot
        
        echo "✅ Twitter fixes applied"
        echo "🔄 Bot restarted"
        ;;
    *)
        echo "🤖 SMART Twitter/X Downloader Bot"
        echo ""
        echo "Usage: $0 {start|stop|restart|status|logs|setup|config|update|test|fix-twitter}"
        echo ""
        echo "Commands:"
        echo "  start        - Start smart bot"
        echo "  stop         - Stop bot"
        echo "  restart      - Restart bot"
        echo "  status       - Check status"
        echo "  logs         - View logs (add 'error' for error logs)"
        echo "  setup        - Initial setup"
        echo "  config       - Edit config"
        echo "  update       - Update bot & fix Twitter"
        echo "  test         - Test installation"
        echo "  fix-twitter  - Fix Twitter download issues"
        echo ""
        echo "🎯 Smart Features:"
        echo "• Shows only available formats"
        echo "• Auto-retry with best quality"
        echo "• Supports all Twitter links"
        echo ""
        echo "Quick start:"
        echo "  1. twitter-bot setup"
        echo "  2. twitter-bot config"
        echo "  3. twitter-bot start"
        echo "  4. twitter-bot logs"
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
    echo -e "${GREEN}     SMART BOT INSTALLATION COMPLETE!       ${NC}"
    echo -e "${GREEN}==============================================${NC}"
    echo ""
    echo -e "${YELLOW}🚀 FEATURES:${NC}"
    echo "• Shows only available formats"
    echo "• Auto-detects best quality"
    echo "• Fixes Twitter download issues"
    echo "• Smart retry system"
    echo ""
    echo -e "${YELLOW}📋 SETUP STEPS:${NC}"
    echo "1. Setup bot:"
    echo "   twitter-bot setup"
    echo ""
    echo "2. Add your bot token:"
    echo "   twitter-bot config"
    echo ""
    echo "3. Update for Twitter fixes:"
    echo "   twitter-bot update"
    echo ""
    echo "4. Start bot:"
    echo "   twitter-bot start"
    echo ""
    echo "5. Test:"
    echo "   twitter-bot test"
    echo ""
    echo -e "${YELLOW}🔧 TROUBLESHOOTING:${NC}"
    echo "If Twitter downloads fail:"
    echo "   twitter-bot fix-twitter"
    echo ""
    echo -e "${GREEN}✅ Ready to use!${NC}"
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
