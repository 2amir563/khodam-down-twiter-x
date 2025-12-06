#!/bin/bash

# Telegram Twitter/X Video Downloader Bot Installer
# Smart Version with Caption Support
# Based on previous working version

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
    echo "     SMART VERSION WITH CAPTION 3.0"
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
    pip3 install "python-telegram-bot==20.7" "yt-dlp>=2024.04.09" requests
    
    print_success "Python packages installed"
}

# Create bot directory
create_bot_dir() {
    print_info "Creating bot directory..."
    
    rm -rf /opt/twitter_smart_bot
    mkdir -p /opt/twitter_smart_bot
    cd /opt/twitter_smart_bot
    
    print_success "Directory created: /opt/twitter_smart_bot"
}

# Create bot.py script (SMART VERSION with CAPTION)
create_bot_script() {
    print_info "Creating smart bot script with caption..."
    
    cat > /opt/twitter_smart_bot/bot.py << 'EOF'
#!/usr/bin/env python3
"""
Smart Telegram Twitter/X Video Downloader Bot with Caption
Shows only available formats + includes tweet text
"""

import os
import json
import re
import html
import logging
import subprocess
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes, CallbackQueryHandler

# Setup logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO,
    filename='/opt/twitter_smart_bot/bot.log'
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
4. Receive video with tweet text

🔗 Examples:
• https://twitter.com/user/status/1234567890
• https://x.com/user/status/1234567890

⚡ Commands:
/start - Show this message
/help - Help information
/direct <url> - Direct download (best quality)

🔧 Smart Features:
• Shows only available formats
• Includes tweet text in caption
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
5. Receive video with tweet text

📌 Direct download:
/direct <url> - Download with best quality

📌 Note:
• Max file size: 2GB (Telegram limit)
• Shows only available formats
• Includes tweet text in caption
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
    
    # Get tweet info for caption
    tweet_info = get_tweet_info(url)
    success = await download_video(url, "best", user_id, msg, context, tweet_info)
    
    if success:
        await msg.edit_text("✅ Download completed!")
    else:
        await msg.edit_text("❌ Download failed. Try selecting quality manually.")

def is_twitter_url(url):
    """Check if URL is from Twitter/X"""
    twitter_domains = ['twitter.com', 'x.com', 't.co']
    return any(domain in url.lower() for domain in twitter_domains)

def get_tweet_info(url):
    """Get tweet information including text/caption"""
    try:
        cmd = ['yt-dlp', '--skip-download', '--dump-json', '--no-warnings', url]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        
        if result.returncode == 0:
            info = json.loads(result.stdout)
            
            # Extract tweet information
            tweet_info = {
                'title': info.get('title', ''),
                'uploader': info.get('uploader', ''),
                'uploader_id': info.get('uploader_id', ''),
                'description': info.get('description', ''),
                'like_count': info.get('like_count', 0),
                'repost_count': info.get('repost_count', 0),
                'formats': info.get('formats', []),
            }
            
            # Clean description for caption
            description = info.get('description', '')
            if description:
                # Decode HTML entities
                description = html.unescape(description)
                # Remove URLs
                description = re.sub(r'https?://\S+', '', description)
                # Remove extra whitespace
                description = ' '.join(description.split())
                tweet_info['clean_description'] = description[:500]  # Limit length
            
            return tweet_info
        
        return None
        
    except Exception as e:
        logger.error(f"Error getting tweet info: {e}")
        return None

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
            # Check if it's a video format with audio
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
        if sorted_formats:
            sorted_formats.insert(0, {
                'quality': '🎯 Best Quality',
                'format_id': 'best',
                'height': 9999,
                'size': 'Auto',
                'ext': 'mp4'
            })
        
        return sorted_formats
        
    except Exception as e:
        logger.error(f"Error getting formats: {e}")
        return None

def create_caption(tweet_info, quality):
    """Create caption from tweet info"""
    if not tweet_info:
        return f"✅ Downloaded\nQuality: {quality}"
    
    caption_parts = []
    
    # Add tweet text if available
    tweet_text = tweet_info.get('clean_description', tweet_info.get('title', ''))
    if tweet_text:
        # Clean and limit text
        tweet_text = tweet_text.replace('\n', ' ').strip()
        if len(tweet_text) > 300:
            tweet_text = tweet_text[:297] + "..."
        caption_parts.append(f"💬 {tweet_text}")
    
    # Add author if available
    author = tweet_info.get('uploader', '')
    if author:
        caption_parts.append(f"👤 {author}")
    
    # Add quality
    caption_parts.append(f"🎬 Quality: {quality}")
    
    # Add likes/retweets if available
    likes = tweet_info.get('like_count', 0)
    retweets = tweet_info.get('repost_count', 0)
    if likes > 0 or retweets > 0:
        stats = []
        if likes > 0:
            stats.append(f"❤️ {likes:,}")
        if retweets > 0:
            stats.append(f"🔄 {retweets:,}")
        if stats:
            caption_parts.append(" ".join(stats))
    
    # Join all parts
    caption = "\n\n".join(caption_parts)
    
    # Add footer
    caption += "\n\n📥 Downloaded via bot"
    
    return caption

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
    
    # Get tweet info for caption
    tweet_info = get_tweet_info(url)
    
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
        
        button_text = f"{fmt['quality']}"
        if fmt['size'] != 'Auto':
            button_text += f" ({fmt['size']})"
        
        callback_data = f"quality:{fmt['format_id']}:{fmt['quality']}"
        row.append(InlineKeyboardButton(button_text, callback_data=callback_data))
    
    if row:
        keyboard.append(row)
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    # Show tweet preview if available
    tweet_preview = ""
    if tweet_info:
        tweet_text = tweet_info.get('clean_description', tweet_info.get('title', ''))[:100]
        if tweet_text:
            tweet_preview = f"\n💬 {tweet_text}..."
    
    await msg.edit_text(
        f"📹 Available qualities for this video:{tweet_preview}\n\n"
        f"🔗 URL: {url[:50]}...\n"
        f"📊 Select quality:",
        reply_markup=reply_markup
    )
    
    # Store tweet info in context for later use
    if tweet_info:
        context.user_data['tweet_info'] = tweet_info

async def handle_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle callback queries (quality selection)"""
    query = update.callback_query
    await query.answer()
    
    user_id = query.from_user.id
    callback_data = query.data
    
    if callback_data.startswith('quality:'):
        _, format_id, quality_name = callback_data.split(':')
        url = context.user_data.get('url')
        tweet_info = context.user_data.get('tweet_info')
        
        if not url:
            await query.edit_message_text("❌ URL not found. Please send the URL again.")
            return
        
        # Update message
        await query.edit_message_text(f"⏬ Downloading {quality_name}...\nThis may take a minute.")
        
        # Download video with caption
        success = await download_video(url, format_id, user_id, query.message, context, tweet_info)
        
        if success:
            await query.edit_message_text("✅ Download completed! Video sent with caption.")
        else:
            await query.edit_message_text("❌ Download failed. Try another quality or use /direct command.")

async def download_video(url, format_id, user_id, message, context, tweet_info=None):
    """Download video with specified format and caption"""
    try:
        # Create temp directory
        os.makedirs('/tmp/twitter_dl', exist_ok=True)
        os.chdir('/tmp/twitter_dl')
        
        # Clean previous files
        for f in os.listdir('.'):
            if f.endswith(('.mp4', '.mkv', '.webm')):
                try:
                    os.remove(f)
                except:
                    pass
        
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
                await message.edit_text(f"⚠️ Format not available. Trying best quality...")
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
                format_id = 'best'
                quality_name = 'Best Quality'
        
        # Find downloaded file
        files = [f for f in os.listdir('.') if f.endswith(('.mp4', '.mkv', '.webm'))]
        if not files:
            return False
        
        video_file = max(files, key=os.path.getctime)
        file_size = os.path.getsize(video_file)
        
        # Check file size (Telegram limit: 2GB for bots)
        if file_size > 1.9 * 1024 * 1024 * 1024:  # 1.9GB
            await message.edit_text("❌ File too large (>1.9GB). Try lower quality.")
            try:
                os.remove(video_file)
            except:
                pass
            return False
        
        # Create caption
        quality_display = format_id if format_id == 'best' else format_id + 'p'
        caption = create_caption(tweet_info, quality_display)
        
        # Send video
        await message.edit_text("📤 Sending video...")
        
        with open(video_file, 'rb') as f:
            # Send without parse_mode to avoid entity errors
            await context.bot.send_video(
                chat_id=user_id,
                video=f,
                caption=caption,
                supports_streaming=True,
                read_timeout=60,
                write_timeout=60,
                connect_timeout=60
            )
        
        # Cleanup
        try:
            os.remove(video_file)
        except:
            pass
        
        return True
        
    except subprocess.TimeoutExpired:
        await message.edit_text("❌ Download timeout (5 minutes)")
        return False
    except Exception as e:
        logger.error(f"Download error: {e}")
        # Clean error message for display
        error_msg = str(e)
        if "Can't parse entities" in error_msg:
            error_msg = "Error sending caption. Video downloaded but caption had formatting issues."
        await message.edit_text(f"❌ Error: {error_msg[:200]}")
        return False
    finally:
        os.chdir('/')

async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle errors"""
    logger.error(f"Error: {context.error}")
    
    # Fix for "Can't parse entities" error
    error_msg = str(context.error)
    if "Can't parse entities" in error_msg:
        # This is a caption formatting error, not critical
        logger.warning(f"Caption formatting error: {error_msg}")
        return
    
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
        print("Please add your bot token to /opt/twitter_smart_bot/.env")
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
    
    print("🤖 Smart Twitter Bot with Caption starting...")
    print("📁 Logs: /opt/twitter_smart_bot/bot.log")
    print("✨ Features: Shows available formats + Tweet text")
    
    app.run_polling()

if __name__ == '__main__':
    main()
EOF
    
    chmod +x /opt/twitter_smart_bot/bot.py
    print_success "Smart bot script with caption created"
}

# Create environment file
create_env_file() {
    print_info "Creating environment file..."
    
    cat > /opt/twitter_smart_bot/.env.example << EOF
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
Description=Smart Twitter/X Video Downloader Bot with Caption
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/twitter_smart_bot
EnvironmentFile=/opt/twitter_smart_bot/.env
ExecStart=/usr/bin/python3 /opt/twitter_smart_bot/bot.py
Restart=always
RestartSec=10
StandardOutput=append:/opt/twitter_smart_bot/bot.log
StandardError=append:/opt/twitter_smart_bot/error.log

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
        if [ ! -f /opt/twitter_smart_bot/.env ]; then
            echo "❌ Please setup bot first: twitter-bot setup"
            exit 1
        fi
        
        systemctl start twitter-bot
        echo "✅ Smart bot started"
        echo "✨ Features: Available formats + Tweet text"
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
            tail -f /opt/twitter_smart_bot/error.log
        else
            tail -f /opt/twitter_smart_bot/bot.log
        fi
        ;;
    setup)
        echo "📝 Setting up smart bot with caption..."
        
        if [ ! -f /opt/twitter_smart_bot/.env ]; then
            cp /opt/twitter_smart_bot/.env.example /opt/twitter_smart_bot/.env
            echo ""
            echo "📋 Created .env file"
            echo "Please edit it and add your BOT_TOKEN:"
            echo "   nano /opt/twitter_smart_bot/.env"
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
        nano /opt/twitter_smart_bot/.env
        ;;
    update)
        echo "🔄 Updating smart bot..."
        
        # Update packages
        pip3 install --upgrade yt-dlp python-telegram-bot requests
        
        systemctl restart twitter-bot
        echo "✅ Bot updated and restarted"
        echo "📝 Now includes tweet text in caption"
        ;;
    test)
        echo "🧪 Testing smart bot with caption..."
        echo ""
        
        echo "1. Testing packages..."
        python3 -c "
try:
    import telegram, yt_dlp, requests
    print('✅ All packages installed')
except Exception as e:
    print(f'❌ Missing packages: {e}')
        "
        echo ""
        
        echo "2. Testing yt-dlp..."
        yt-dlp --version
        echo ""
        
        echo "3. Testing configuration..."
        if [ -f /opt/twitter_smart_bot/.env ]; then
            if grep -q "BOT_TOKEN=" /opt/twitter_smart_bot/.env && ! grep -q "BOT_TOKEN=your_bot_token_here" /opt/twitter_smart_bot/.env; then
                echo "✅ BOT_TOKEN configured"
            else
                echo "⚠️  BOT_TOKEN not configured"
            fi
        else
            echo "❌ .env file not found"
        fi
        
        echo ""
        echo "4. Testing caption extraction..."
        echo "Run a test with: curl -s 'https://twitter.com/Twitter/status/1349129669258448897'"
        ;;
    fix)
        echo "🔧 Fixing common issues..."
        
        # Update yt-dlp
        pip3 install --upgrade yt-dlp
        
        # Clear cache
        yt-dlp --rm-cache-dir 2>/dev/null || true
        
        # Restart bot
        systemctl restart twitter-bot
        
        echo "✅ Fixes applied and bot restarted"
        ;;
    *)
        echo "🤖 SMART Twitter/X Downloader Bot with Caption"
        echo ""
        echo "Usage: $0 {start|stop|restart|status|logs|setup|config|update|test|fix}"
        echo ""
        echo "Commands:"
        echo "  start    - Start smart bot"
        echo "  stop     - Stop bot"
        echo "  restart  - Restart bot"
        echo "  status   - Check status"
        echo "  logs     - View logs (add 'error' for error logs)"
        echo "  setup    - Initial setup"
        echo "  config   - Edit configuration"
        echo "  update   - Update bot & packages"
        echo "  test     - Test installation"
        echo "  fix      - Fix common issues"
        echo ""
        echo "✨ Features:"
        echo "• Shows only available formats"
        echo "• Includes tweet text in caption"
        echo "• Auto-retry with best quality"
        echo "• Clean and reliable"
        echo ""
        echo "📝 Caption includes:"
        echo "• Tweet text"
        echo "• Author name"
        echo "• Video quality"
        echo "• Likes/retweets"
        echo ""
        echo "Quick start:"
        echo "  1. twitter-bot setup"
        echo "  2. twitter-bot config  (add your token)"
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
    echo -e "${GREEN}   SMART BOT WITH CAPTION INSTALLED!        ${NC}"
    echo -e "${GREEN}==============================================${NC}"
    echo ""
    echo -e "${YELLOW}🚀 KEY FEATURES:${NC}"
    echo "• ✅ Shows only available formats (like before)"
    echo "• ✅ Includes tweet text in caption (NEW!)"
    echo "• ✅ Auto-detects best quality"
    echo "• ✅ Clean interface, no errors"
    echo ""
    echo -e "${YELLOW}📋 SETUP STEPS:${NC}"
    echo "1. Setup bot:"
    echo "   twitter-bot setup"
    echo ""
    echo "2. Add your bot token:"
    echo "   twitter-bot config"
    echo ""
    echo "3. Start bot:"
    echo "   twitter-bot start"
    echo ""
    echo "4. Check logs:"
    echo "   twitter-bot logs"
    echo ""
    echo -e "${YELLOW}📝 EXAMPLE CAPTION:${NC}"
    echo "💬 Just launched something amazing for the future..."
    echo ""
    echo "👤 Elon Musk"
    echo "🎬 Quality: 1080p"
    echo "❤️ 25,000 🔄 5,000"
    echo ""
    echo "📥 Downloaded via bot"
    echo ""
    echo -e "${GREEN}✅ Ready to use! Send tweets to your bot.${NC}"
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
