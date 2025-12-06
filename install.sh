#!/bin/bash

# Telegram Twitter/X Video Downloader Bot Installer
# Version with Caption Support

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
    echo "║   TWITTER/X VIDEO DOWNLOADER WITH CAPTION       ║"
    echo "║             COMPLETE VERSION 3.0                ║"
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
    pip3 install "python-telegram-bot==20.7" "yt-dlp>=2024.04.09" "requests>=2.31.0" "beautifulsoup4>=4.12.0" "lxml>=4.9.0"
    
    print_success "Python packages installed"
}

# Create bot directory
create_bot_dir() {
    print_info "Creating bot directory..."
    
    rm -rf /opt/twitter_caption_bot
    mkdir -p /opt/twitter_caption_bot
    mkdir -p /opt/twitter_caption_bot/downloads
    mkdir -p /opt/twitter_caption_bot/logs
    
    cd /opt/twitter_caption_bot
    
    print_success "Directory created: /opt/twitter_caption_bot"
}

# Create bot.py script with caption support
create_bot_script() {
    print_info "Creating bot script with caption support..."
    
    cat > /opt/twitter_caption_bot/bot.py << 'EOF'
#!/usr/bin/env python3
"""
Telegram Twitter/X Video Downloader Bot with Caption
Downloads video with tweet text/caption
"""

import os
import json
import re
import logging
import subprocess
import html
from datetime import datetime
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes, CallbackQueryHandler

# Setup logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO,
    filename='/opt/twitter_caption_bot/logs/bot.log'
)
logger = logging.getLogger(__name__)

# Bot token (will be set from environment)
BOT_TOKEN = os.getenv('BOT_TOKEN', '')

async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command"""
    user = update.effective_user
    text = f"""
👋 Welcome {user.first_name}!

📹 *Twitter/X Video Downloader Bot*

I can download videos from Twitter/X with full caption!

✨ *Features:*
• Download videos from Twitter/X
• Get tweet text/caption
• Multiple quality options
• Fast and reliable

📌 *How to use:*
1. Send me any Twitter/X link
2. Select video quality
3. Receive video with caption

🔗 *Examples:*
• `https://twitter.com/user/status/1234567890`
• `https://x.com/user/status/1234567890`

⚡ *Commands:*
/start - Show this message
/help - Help information
/info <url> - Get tweet info without download

📝 *Caption includes:*
✓ Tweet text
✓ Author username
✓ Date & time
✓ Likes & retweets count
    """
    await update.message.reply_text(text, parse_mode='Markdown')

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /help command"""
    text = """
🤖 *Bot Help Guide*

📌 *How to download:*
1. Find a Twitter/X video
2. Copy the link
3. Send to this bot
4. Select quality
5. Receive video with caption

🔧 *Available Commands:*
/start - Welcome message
/help - This help guide
/info <url> - Get tweet info

🎯 *Features:*
• Video download with caption
• Multiple quality options
• Fast download speed
• Support all Twitter links

⚠️ *Notes:*
• Max file size: 2GB
• Caption includes tweet text
• Private tweets cannot be downloaded
    """
    await update.message.reply_text(text, parse_mode='Markdown')

async def info_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Get tweet info without download"""
    if not context.args:
        await update.message.reply_text("Usage: /info <twitter-url>\nExample: /info https://twitter.com/username/status/1234567890")
        return
    
    url = context.args[0]
    
    if not is_twitter_url(url):
        await update.message.reply_text("❌ Please provide a valid Twitter/X URL")
        return
    
    msg = await update.message.reply_text("🔍 Getting tweet information...")
    
    try:
        # Get tweet info using yt-dlp
        info = get_tweet_info(url)
        
        if not info:
            await msg.edit_text("❌ Could not get tweet information")
            return
        
        # Format info message
        info_text = format_tweet_info(info)
        
        await msg.edit_text(info_text, parse_mode='Markdown')
        
    except Exception as e:
        logger.error(f"Info error: {e}")
        await msg.edit_text(f"❌ Error: {str(e)[:200]}")

def is_twitter_url(url):
    """Check if URL is from Twitter/X"""
    twitter_domains = ['twitter.com', 'x.com', 't.co']
    url_lower = url.lower()
    return any(domain in url_lower for domain in twitter_domains)

def get_tweet_info(url):
    """Extract tweet information including caption"""
    try:
        # Get detailed info using yt-dlp
        cmd = [
            'yt-dlp',
            '--skip-download',
            '--dump-json',
            '--no-warnings',
            '--extractor-args', 'twitter:include=all',
            url
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        
        if result.returncode != 0:
            # Try alternative method
            cmd = ['yt-dlp', '--skip-download', '--dump-json', '--no-warnings', url]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        
        if result.returncode == 0:
            info = json.loads(result.stdout)
            
            # Extract tweet information
            tweet_info = {
                'title': info.get('title', ''),
                'uploader': info.get('uploader', ''),
                'uploader_id': info.get('uploader_id', ''),
                'upload_date': info.get('upload_date', ''),
                'description': info.get('description', ''),
                'view_count': info.get('view_count', 0),
                'like_count': info.get('like_count', 0),
                'repost_count': info.get('repost_count', 0),
                'comment_count': info.get('comment_count', 0),
                'duration': info.get('duration_string', ''),
                'formats': info.get('formats', []),
                'thumbnail': info.get('thumbnail', ''),
                'webpage_url': info.get('webpage_url', url),
                'id': info.get('id', ''),
            }
            
            # Try to get clean caption from description
            description = info.get('description', '')
            if description:
                # Clean HTML entities
                description = html.unescape(description)
                # Remove URLs
                description = re.sub(r'https?://\S+', '', description)
                # Remove extra whitespace
                description = ' '.join(description.split())
                tweet_info['caption'] = description[:1000]  # Limit length
            
            return tweet_info
        
        return None
        
    except Exception as e:
        logger.error(f"Error getting tweet info: {e}")
        return None

def format_tweet_info(info):
    """Format tweet information for display"""
    # Format date
    upload_date = info.get('upload_date', '')
    if upload_date and len(upload_date) == 8:
        date_str = f"{upload_date[0:4]}-{upload_date[4:6]}-{upload_date[6:8]}"
    else:
        date_str = 'Unknown'
    
    # Get caption
    caption = info.get('caption', info.get('title', ''))
    
    # Format info text
    info_text = f"""
📝 *Tweet Information*

👤 *Author:* {info.get('uploader', 'Unknown')}
🆔 *Username:* @{info.get('uploader_id', 'Unknown')}
📅 *Date:* {date_str}
🔗 *URL:* {info.get('webpage_url', '')}

💬 *Tweet Text:*
{caption}

📊 *Statistics:*
👁️ Views: {info.get('view_count', 0):,}
❤️ Likes: {info.get('like_count', 0):,}
🔄 Retweets: {info.get('repost_count', 0):,}
💬 Replies: {info.get('comment_count', 0):,}

⏱️ *Duration:* {info.get('duration', 'Unknown')}

📥 *Available Qualities:* {len(info.get('formats', []))}
    """
    
    return info_text

def get_available_formats(info):
    """Get available video formats from tweet info"""
    formats = info.get('formats', [])
    
    # Filter video formats
    video_formats = []
    for fmt in formats:
        # Check if it's a video format
        if fmt.get('vcodec') != 'none':
            height = fmt.get('height', 0)
            if height > 0:
                # Get format details
                format_id = fmt.get('format_id', '')
                ext = fmt.get('ext', 'mp4')
                filesize = fmt.get('filesize', fmt.get('filesize_approx', 0))
                
                # Format size
                if filesize:
                    if filesize < 1024 * 1024:  # Less than 1MB
                        size_str = f"{filesize/1024:.1f}KB"
                    else:
                        size_str = f"{filesize/(1024*1024):.1f}MB"
                else:
                    size_str = "N/A"
                
                # Add format
                video_formats.append({
                    'quality': f"{height}p",
                    'format_id': format_id,
                    'height': height,
                    'size': size_str,
                    'ext': ext,
                    'note': fmt.get('format_note', '')
                })
    
    # Remove duplicates and sort by quality
    unique_formats = {}
    for fmt in video_formats:
        quality = fmt['quality']
        if quality not in unique_formats or fmt['height'] > unique_formats[quality]['height']:
            unique_formats[quality] = fmt
    
    # Sort by height descending
    sorted_formats = sorted(unique_formats.values(), key=lambda x: x['height'], reverse=True)
    
    # Add "best" option
    if sorted_formats:
        sorted_formats.insert(0, {
            'quality': '🎯 Best Quality',
            'format_id': 'best',
            'height': 9999,
            'size': 'Auto',
            'ext': 'mp4',
            'note': 'Automatic selection'
        })
    
    return sorted_formats

def create_caption(info, selected_quality):
    """Create caption for video"""
    # Get basic info
    author = info.get('uploader', 'Unknown')
    username = info.get('uploader_id', '')
    tweet_text = info.get('caption', info.get('title', ''))
    
    # Format date
    upload_date = info.get('upload_date', '')
    if upload_date and len(upload_date) == 8:
        date_str = f"{upload_date[0:4]}-{upload_date[4:6]}-{upload_date[6:8]}"
    else:
        date_str = datetime.now().strftime('%Y-%m-%d')
    
    # Get statistics
    likes = info.get('like_count', 0)
    retweets = info.get('repost_count', 0)
    
    # Create caption
    caption = f"""
📹 Twitter/X Video

👤 {author}
{'@' + username if username else ''}

💬 {tweet_text[:500]}{'...' if len(tweet_text) > 500 else ''}

📅 {date_str}
❤️ {likes:,} likes
🔄 {retweets:,} retweets

🎬 Quality: {selected_quality}

🔗 Downloaded via @{context.bot.username if 'context' in locals() else 'TwitterDownloaderBot'}
    """
    
    # Clean caption
    caption = '\n'.join(line.strip() for line in caption.split('\n') if line.strip())
    return caption.strip()

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle incoming messages"""
    message = update.message
    url = message.text.strip()
    
    if not is_twitter_url(url):
        await message.reply_text("❌ Please send a valid Twitter/X URL")
        return
    
    # Store URL in context
    context.user_data['url'] = url
    
    # Get tweet info
    msg = await message.reply_text("🔍 Analyzing tweet...")
    
    try:
        # Get tweet information
        info = get_tweet_info(url)
        
        if not info:
            await msg.edit_text("❌ Could not get tweet information. The tweet might be private or deleted.")
            return
        
        # Store info in context
        context.user_data['tweet_info'] = info
        
        # Get available formats
        formats = get_available_formats(info)
        
        if not formats:
            await msg.edit_text("❌ No video formats found for this tweet")
            return
        
        # Create keyboard with available formats
        keyboard = []
        for fmt in formats:
            button_text = f"{fmt['quality']}"
            if fmt['size'] != 'Auto':
                button_text += f" ({fmt['size']})"
            
            callback_data = f"quality:{fmt['format_id']}:{fmt['quality']}"
            keyboard.append([InlineKeyboardButton(button_text, callback_data=callback_data)])
        
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        # Get preview of tweet text
        tweet_text = info.get('caption', info.get('title', ''))[:100]
        if len(info.get('caption', info.get('title', ''))) > 100:
            tweet_text += "..."
        
        await msg.edit_text(
            f"📝 *Tweet Found!*\n\n"
            f"👤 *Author:* {info.get('uploader', 'Unknown')}\n"
            f"💬 *Text:* {tweet_text}\n\n"
            f"📊 *Select video quality:*",
            parse_mode='Markdown',
            reply_markup=reply_markup
        )
        
    except Exception as e:
        logger.error(f"Message handling error: {e}")
        await msg.edit_text(f"❌ Error: {str(e)[:200]}")

async def handle_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle callback queries (quality selection)"""
    query = update.callback_query
    await query.answer()
    
    user_id = query.from_user.id
    callback_data = query.data
    
    if callback_data.startswith('quality:'):
        _, format_id, quality_name = callback_data.split(':')
        url = context.user_data.get('url')
        info = context.user_data.get('tweet_info')
        
        if not url or not info:
            await query.edit_message_text("❌ Session expired. Please send the URL again.")
            return
        
        # Update message
        await query.edit_message_text(f"⏬ Downloading {quality_name}...\nThis may take a minute.")
        
        # Download video with caption
        success = await download_video_with_caption(url, format_id, quality_name, info, user_id, query.message, context)
        
        if success:
            await query.edit_message_text("✅ Download completed! Video sent with caption.")
        else:
            await query.edit_message_text("❌ Download failed. Try another quality or send the URL again.")

async def download_video_with_caption(url, format_id, quality_name, tweet_info, user_id, message, context):
    """Download video with caption"""
    try:
        # Create temp directory
        temp_dir = f"/tmp/twitter_dl_{user_id}"
        os.makedirs(temp_dir, exist_ok=True)
        os.chdir(temp_dir)
        
        # Clean previous files
        for f in os.listdir('.'):
            if f.endswith(('.mp4', '.mkv', '.webm', '.jpg', '.png')):
                try:
                    os.remove(f)
                except:
                    pass
        
        # Update status
        await message.edit_text(f"📥 Downloading video ({quality_name})...")
        
        # Download video using yt-dlp
        output_template = 'video_%(title)s_%(id)s.%(ext)s'
        cmd = [
            'yt-dlp',
            '-f', format_id,
            '-o', output_template,
            '--no-warnings',
            '--merge-output-format', 'mp4',
            '--add-metadata',
            '--embed-thumbnail',
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
        
        # Monitor progress
        for line in process.stdout:
            if '[download]' in line and '%' in line:
                # Extract progress
                import re
                match = re.search(r'(\d+\.?\d*)%', line)
                if match:
                    progress = match.group(1)
                    try:
                        await message.edit_text(f"📥 Downloading... {progress}%")
                    except:
                        pass
        
        process.wait()
        
        # If specific format failed, try best quality
        if process.returncode != 0 and format_id != 'best':
            await message.edit_text(f"⚠️ {quality_name} not available. Trying best quality...")
            cmd = [
                'yt-dlp',
                '-f', 'best',
                '-o', output_template,
                '--no-warnings',
                '--merge-output-format', 'mp4',
                '--add-metadata',
                url
            ]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
            if result.returncode != 0:
                return False
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
            return False
        
        # Create caption
        caption = create_caption(tweet_info, quality_name)
        
        # Update status
        await message.edit_text("📤 Sending video with caption...")
        
        # Send video with caption
        with open(video_file, 'rb') as f:
            await context.bot.send_video(
                chat_id=user_id,
                video=f,
                caption=caption,
                supports_streaming=True,
                read_timeout=120,
                write_timeout=120,
                connect_timeout=120
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
        await message.edit_text(f"❌ Error: {str(e)[:200]}")
        return False
    finally:
        os.chdir('/')
        # Clean temp directory
        try:
            import shutil
            shutil.rmtree(temp_dir, ignore_errors=True)
        except:
            pass

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
        print("Please add your bot token to /opt/twitter_caption_bot/.env")
        exit(1)
    
    # Create application
    app = Application.builder().token(BOT_TOKEN).build()
    
    # Add handlers
    app.add_handler(CommandHandler("start", start_command))
    app.add_handler(CommandHandler("help", help_command))
    app.add_handler(CommandHandler("info", info_command))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    app.add_handler(CallbackQueryHandler(handle_callback))
    app.add_error_handler(error_handler)
    
    print("🤖 Twitter Bot with Caption starting...")
    print("📝 Features: Video + Tweet text")
    print("📁 Logs: /opt/twitter_caption_bot/logs/bot.log")
    
    app.run_polling()

if __name__ == '__main__':
    main()
EOF
    
    chmod +x /opt/twitter_caption_bot/bot.py
    print_success "Bot script with caption support created"
}

# Create environment file
create_env_file() {
    print_info "Creating environment file..."
    
    cat > /opt/twitter_caption_bot/.env.example << EOF
# Telegram Bot Token from @BotFather
# Example: 1234567890:ABCdefGhIJKlmNoPQRsTUVwxyZ
BOT_TOKEN=your_bot_token_here

# Optional: Your Telegram User ID for admin features
# Get it from @userinfobot on Telegram
ADMIN_ID=123456789
EOF
    
    print_success "Environment file created"
}

# Create service file
create_service_file() {
    print_info "Creating systemd service..."
    
    cat > /etc/systemd/system/twitter-bot.service << EOF
[Unit]
Description=Twitter/X Video Downloader Bot with Caption
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/twitter_caption_bot
EnvironmentFile=/opt/twitter_caption_bot/.env
ExecStart=/usr/bin/python3 /opt/twitter_caption_bot/bot.py
Restart=always
RestartSec=10
StandardOutput=append:/opt/twitter_caption_bot/logs/bot.log
StandardError=append:/opt/twitter_caption_bot/logs/error.log

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
        if [ ! -f /opt/twitter_caption_bot/.env ]; then
            echo "❌ Please setup bot first: twitter-bot setup"
            exit 1
        fi
        
        systemctl start twitter-bot
        echo "✅ Bot started with caption support"
        echo "✨ Features: Video + Tweet text"
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
            tail -f /opt/twitter_caption_bot/logs/error.log
        else
            tail -f /opt/twitter_caption_bot/logs/bot.log
        fi
        ;;
    setup)
        echo "📝 Setting up bot with caption support..."
        
        if [ ! -f /opt/twitter_caption_bot/.env ]; then
            cp /opt/twitter_caption_bot/.env.example /opt/twitter_caption_bot/.env
            echo ""
            echo "📋 Created .env file"
            echo "Please edit it and add your BOT_TOKEN:"
            echo "   nano /opt/twitter_caption_bot/.env"
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
        nano /opt/twitter_caption_bot/.env
        ;;
    update)
        echo "🔄 Updating bot with caption support..."
        
        # Update packages
        pip3 install --upgrade yt-dlp python-telegram-bot requests beautifulsoup4 lxml
        
        # Update yt-dlp for better Twitter support
        yt-dlp -U
        
        systemctl restart twitter-bot
        echo "✅ Bot updated and restarted"
        echo "📝 Now includes tweet text in caption"
        ;;
    test)
        echo "🧪 Testing bot with caption support..."
        echo ""
        
        echo "1. Testing packages..."
        python3 -c "
try:
    import telegram, yt_dlp, requests, bs4, lxml
    print('✅ All packages installed')
except Exception as e:
    print(f'❌ Missing packages: {e}')
        "
        echo ""
        
        echo "2. Testing yt-dlp..."
        yt-dlp --version
        echo ""
        
        echo "3. Testing configuration..."
        if [ -f /opt/twitter_caption_bot/.env ]; then
            if grep -q "BOT_TOKEN=" /opt/twitter_caption_bot/.env && ! grep -q "BOT_TOKEN=your_bot_token_here" /opt/twitter_caption_bot/.env; then
                echo "✅ BOT_TOKEN configured"
            else
                echo "⚠️  BOT_TOKEN not configured"
            fi
        else
            echo "❌ .env file not found"
        fi
        ;;
    caption-test)
        echo "📝 Testing caption extraction..."
        echo ""
        
        # Test with a sample Twitter URL
        SAMPLE_URL="https://twitter.com/Twitter/status/1349129669258448897"
        echo "Testing URL: $SAMPLE_URL"
        echo ""
        
        cd /opt/twitter_caption_bot
        python3 -c "
import subprocess, json
try:
    cmd = ['yt-dlp', '--skip-download', '--dump-json', '--no-warnings', '$SAMPLE_URL']
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
    
    if result.returncode == 0:
        info = json.loads(result.stdout)
        title = info.get('title', 'No title')
        uploader = info.get('uploader', 'Unknown')
        description = info.get('description', '')[:200]
        
        print(f'✅ Success!')
        print(f'Title: {title}')
        print(f'Author: {uploader}')
        print(f'Text preview: {description}')
    else:
        print('❌ Failed to get tweet info')
except Exception as e:
    print(f'❌ Error: {e}')
        "
        ;;
    *)
        echo "🤖 Twitter/X Downloader Bot with Caption"
        echo ""
        echo "Usage: $0 {start|stop|restart|status|logs|setup|config|update|test|caption-test}"
        echo ""
        echo "Commands:"
        echo "  start        - Start bot with caption support"
        echo "  stop         - Stop bot"
        echo "  restart      - Restart bot"
        echo "  status       - Check status"
        echo "  logs         - View logs (add 'error' for error logs)"
        echo "  setup        - Initial setup"
        echo "  config       - Edit configuration"
        echo "  update       - Update bot & packages"
        echo "  test         - Test installation"
        echo "  caption-test - Test caption extraction"
        echo ""
        echo "✨ Features:"
        echo "• Downloads video with tweet text/caption"
        echo "• Shows author, date, likes, retweets"
        echo "• Multiple quality options"
        echo "• Fast and reliable"
        echo ""
        echo "Quick start:"
        echo "  1. twitter-bot setup"
        echo "  2. twitter-bot config  (add your token)"
        echo "  3. twitter-bot update  (for caption support)"
        echo "  4. twitter-bot start"
        echo "  5. twitter-bot logs"
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
    echo -e "${GREEN}   BOT WITH CAPTION SUPPORT INSTALLED!     ${NC}"
    echo -e "${GREEN}==============================================${NC}"
    echo ""
    echo -e "${YELLOW}🚀 NEW FEATURES:${NC}"
    echo "• 📝 Downloads video WITH tweet text/caption"
    echo "• 👤 Shows author username and name"
    echo "• 📅 Includes date and time"
    echo "• ❤️  Shows likes and retweets count"
    echo "• 💬 Full tweet text in caption"
    echo ""
    echo -e "${YELLOW}📋 SETUP STEPS:${NC}"
    echo "1. Setup bot:"
    echo "   twitter-bot setup"
    echo ""
    echo "2. Configure your bot token:"
    echo "   twitter-bot config"
    echo ""
    echo "3. Update for caption support:"
    echo "   twitter-bot update"
    echo ""
    echo "4. Test caption extraction:"
    echo "   twitter-bot caption-test"
    echo ""
    echo "5. Start bot:"
    echo "   twitter-bot start"
    echo ""
    echo "6. Test with a tweet:"
    echo "   Send any Twitter/X link to your bot"
    echo ""
    echo -e "${YELLOW}📝 EXAMPLE CAPTION:${NC}"
    echo "📹 Twitter/X Video"
    echo ""
    echo "👤 Elon Musk"
    echo "@elonmusk"
    echo ""
    echo "💬 Just launched something amazing..."
    echo ""
    echo "📅 2024-01-15"
    echo "❤️ 25,000 likes"
    echo "🔄 5,000 retweets"
    echo ""
    echo "🎬 Quality: 1080p"
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
