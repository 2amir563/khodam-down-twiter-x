#!/bin/bash

# رنگ‌های ترمینال
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# تابع نمایش لوگو
show_logo() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════╗"
    echo "║                                        ║"
    echo "║        DOWN TWITTER/X BOT              ║"
    echo "║        Download Twitter Videos         ║"
    echo "║                                        ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
}

# تابع بررسی وجود دستورات لازم
check_dependencies() {
    echo -e "${YELLOW}[*] بررسی وابستگی‌های مورد نیاز...${NC}"
    
    local missing_deps=()
    
    # بررسی نصب بودن Python3
    if ! command -v python3 &> /dev/null; then
        missing_deps+=("python3")
    fi
    
    # بررسی نصب بودن pip3
    if ! command -v pip3 &> /dev/null; then
        missing_deps+=("pip3")
    fi
    
    # بررسی نصب بودن git
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi
    
    # بررسی نصب بودن ffmpeg
    if ! command -v ffmpeg &> /dev/null; then
        missing_deps+=("ffmpeg")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}[!] وابستگی‌های زیر یافت نشد:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo -e "  ${RED}- $dep${NC}"
        done
        
        echo -e "\n${YELLOW}[*] در حال نصب وابستگی‌های ضروری...${NC}"
        
        # تشخیص توزیع لینوکس
        if [ -f /etc/debian_version ]; then
            # دبیان/اوبونتو
            sudo apt-get update
            sudo apt-get install -y "${missing_deps[@]}" python3-pip
        elif [ -f /etc/redhat-release ]; then
            # ردهت/سنتروس/فدورا
            sudo yum install -y "${missing_deps[@]}" python3-pip
        elif [ -f /etc/arch-release ]; then
            # آرچ
            sudo pacman -Syu --noconfirm "${missing_deps[@]}" python-pip
        else
            echo -e "${RED}[!] توزیع لینوکس شناسایی نشد. لطفاً دستی نصب کنید.${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}[✓] تمام وابستگی‌ها نصب هستند.${NC}"
    fi
}

# تابع نصب پکیج‌های پایتون
install_python_packages() {
    echo -e "${YELLOW}[*] نصب پکیج‌های پایتون مورد نیاز...${NC}"
    
    # ایجاد محیط مجازی پایتون
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
    
    # فعال‌سازی محیط مجازی
    source venv/bin/activate
    
    # نصب پکیج‌ها
    pip3 install --upgrade pip
    
    # نصب پکیگ‌های اصلی
    pip3 install yt-dlp requests colorama
    
    # غیرفعال‌سازی محیط مجازی
    deactivate
    
    echo -e "${GREEN}[✓] پکیج‌های پایتون با موفقیت نصب شدند.${NC}"
}

# تابع ایجاد اسکریپت پایتون
create_python_script() {
    echo -e "${YELLOW}[*] ایجاد اسکریپت اصلی پایتون...${NC}"
    
    cat > twitter_downloader.py << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import subprocess
import re
import json
from colorama import init, Fore, Style

# راه‌اندازی colorama
init(autoreset=True)

class TwitterVideoDownloader:
    def __init__(self):
        self.quality_options = {
            '1': 'best (بهترین کیفیت)',
            '2': '1080p',
            '3': '720p', 
            '4': '480p',
            '5': '360p',
            '6': '240p',
            '7': '144p'
        }
        
    def clear_screen(self):
        """پاک کردن صفحه ترمینال"""
        os.system('cls' if os.name == 'nt' else 'clear')
    
    def show_banner(self):
        """نمایش بنر برنامه"""
        banner = f"""
{Fore.CYAN}
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║              {Fore.YELLOW}Twitter/X Video Downloader{Fore.CYAN}                ║
║                    {Fore.GREEN}نسخه 2.0{Fore.CYAN}                           ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
{Style.RESET_ALL}
        """
        print(banner)
    
    def validate_twitter_url(self, url):
        """اعتبارسنجی لینک توییتر"""
        twitter_patterns = [
            r'https?://(?:www\.)?(?:twitter\.com|x\.com)/[^/]+/status/\d+',
            r'https?://(?:mobile\.)?(?:twitter\.com|x\.com)/[^/]+/status/\d+',
            r'https?://t\.co/[a-zA-Z0-9]+',
            r'https?://vm\.tiktok\.com/[a-zA-Z0-9]+'  # برای لینک‌های کوتاه توییتر
        ]
        
        for pattern in twitter_patterns:
            if re.match(pattern, url):
                return True
        return False
    
    def get_video_info(self, url):
        """دریافت اطلاعات ویدیو"""
        print(f"\n{Fore.YELLOW}[*] در حال دریافت اطلاعات ویدیو...{Style.RESET_ALL}")
        
        try:
            # استفاده از yt-dlp برای دریافت اطلاعات
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
                print(f"{Fore.RED}[!] خطا در دریافت اطلاعات ویدیو{Style.RESET_ALL}")
                print(f"{Fore.RED}[!] خطا: {result.stderr}{Style.RESET_ALL}")
                return None
                
        except subprocess.TimeoutExpired:
            print(f"{Fore.RED}[!] زمان دریافت اطلاعات به پایان رسید{Style.RESET_ALL}")
            return None
        except json.JSONDecodeError:
            print(f"{Fore.RED}[!] خطا در پردازش اطلاعات دریافتی{Style.RESET_ALL}")
            return None
        except Exception as e:
            print(f"{Fore.RED}[!] خطای ناشناخته: {str(e)}{Style.RESET_ALL}")
            return None
    
    def format_file_size(self, bytes):
        """قالب‌بندی حجم فایل"""
        for unit in ['B', 'KB', 'MB', 'GB']:
            if bytes < 1024.0:
                return f"{bytes:.2f} {unit}"
            bytes /= 1024.0
        return f"{bytes:.2f} TB"
    
    def show_quality_options(self, formats):
        """نمایش گزینه‌های کیفیت"""
        print(f"\n{Fore.GREEN}[+] گزینه‌های کیفیت موجود:{Style.RESET_ALL}")
        print(f"{Fore.CYAN}{'='*60}{Style.RESET_ALL}")
        
        video_formats = []
        for f in formats:
            if f.get('vcodec') != 'none':  # فقط فرمت‌های ویدیویی
                video_formats.append(f)
        
        # مرتب‌سازی بر اساس کیفیت
        video_formats.sort(key=lambda x: x.get('height', 0), reverse=True)
        
        options = {}
        option_num = 1
        
        for fmt in video_formats:
            height = fmt.get('height', 0)
            width = fmt.get('width', 0)
            filesize = fmt.get('filesize', fmt.get('filesize_approx', 0))
            ext = fmt.get('ext', 'unknown')
            format_note = fmt.get('format_note', '')
            
            if height:
                quality_label = f"{height}p"
                if format_note:
                    quality_label += f" ({format_note})"
                
                size_str = self.format_file_size(filesize) if filesize else "نامشخص"
                
                print(f"{Fore.YELLOW}[{option_num}]{Style.RESET_ALL} {quality_label:<15} | {ext:<10} | {size_str:<15}")
                
                options[str(option_num)] = {
                    'format_id': fmt['format_id'],
                    'quality': quality_label,
                    'ext': ext,
                    'filesize': filesize
                }
                option_num += 1
        
        print(f"{Fore.CYAN}{'='*60}{Style.RESET_ALL}")
        return options
    
    def download_video(self, url, format_id, quality):
        """دانلود ویدیو"""
        print(f"\n{Fore.YELLOW}[*] در حال دانلود با کیفیت {quality}...{Style.RESET_ALL}")
        
        # نام فایل خروجی
        output_template = '%(title)s_%(height)sp.%(ext)s'
        
        try:
            cmd = [
                'yt-dlp',
                '-f', format_id,
                '-o', output_template,
                '--no-warnings',
                '--progress',
                url
            ]
            
            process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            
            for line in process.stdout:
                if 'ETA' in line or '%' in line:
                    print(f"\r{Fore.CYAN}{line.strip()}{Style.RESET_ALL}", end='', flush=True)
            
            process.wait()
            
            if process.returncode == 0:
                print(f"\n{Fore.GREEN}[✓] دانلود با موفقیت انجام شد!{Style.RESET_ALL}")
                return True
            else:
                print(f"\n{Fore.RED}[!] خطا در دانلود ویدیو{Style.RESET_ALL}")
                return False
                
        except Exception as e:
            print(f"\n{Fore.RED}[!] خطا: {str(e)}{Style.RESET_ALL}")
            return False
    
    def run(self):
        """اجرای اصلی برنامه"""
        self.clear_screen()
        self.show_banner()
        
        while True:
            try:
                print(f"\n{Fore.CYAN}[*] لطفاً لینک توییتر/X را وارد کنید (یا 'exit' برای خروج):{Style.RESET_ALL}")
                url = input(f"{Fore.GREEN}>>> {Style.RESET_ALL}").strip()
                
                if url.lower() == 'exit':
                    print(f"\n{Fore.YELLOW}[*] خروج از برنامه...{Style.RESET_ALL}")
                    break
                
                if not self.validate_twitter_url(url):
                    print(f"{Fore.RED}[!] لینک وارد شده معتبر نیست!{Style.RESET_ALL}")
                    print(f"{Fore.YELLOW}[*] لطفاً یک لینک معتبر توییتر/X وارد کنید.{Style.RESET_ALL}")
                    continue
                
                # دریافت اطلاعات ویدیو
                video_info = self.get_video_info(url)
                
                if not video_info:
                    print(f"{Fore.RED}[!] امکان دریافت اطلاعات ویدیو وجود ندارد.{Style.RESET_ALL}")
                    continue
                
                # نمایش اطلاعات ویدیو
                print(f"\n{Fore.GREEN}[+] اطلاعات ویدیو:{Style.RESET_ALL}")
                print(f"{Fore.CYAN}{'='*60}{Style.RESET_ALL}")
                print(f"{Fore.YELLOW}عنوان:{Style.RESET_ALL} {video_info.get('title', 'نامشخص')}")
                print(f"{Fore.YELLOW}مدت زمان:{Style.RESET_ALL} {video_info.get('duration_string', 'نامشخص')}")
                print(f"{Fore.YELLOW}تعداد بازدید:{Style.RESET_ALL} {video_info.get('view_count', 'نامشخص')}")
                print(f"{Fore.CYAN}{'='*60}{Style.RESET_ALL}")
                
                # نمایش گزینه‌های کیفیت
                formats = video_info.get('formats', [])
                if not formats:
                    print(f"{Fore.RED}[!] هیچ فرمت ویدیویی یافت نشد.{Style.RESET_ALL}")
                    continue
                
                quality_options = self.show_quality_options(formats)
                
                if not quality_options:
                    print(f"{Fore.RED}[!] گزینه کیفیتی یافت نشد.{Style.RESET_ALL}")
                    continue
                
                # انتخاب کیفیت توسط کاربر
                print(f"\n{Fore.CYAN}[*] لطفاً عدد کیفیت مورد نظر را انتخاب کنید:{Style.RESET_ALL}")
                choice = input(f"{Fore.GREEN}>>> {Style.RESET_ALL}").strip()
                
                if choice not in quality_options:
                    print(f"{Fore.RED}[!] انتخاب نامعتبر!{Style.RESET_ALL}")
                    continue
                
                selected = quality_options[choice]
                
                # تایید نهایی
                print(f"\n{Fore.YELLOW}[*] تایید نهایی:{Style.RESET_ALL}")
                print(f"{Fore.CYAN}لینک:{Style.RESET_ALL} {url}")
                print(f"{Fore.CYAN}کیفیت:{Style.RESET_ALL} {selected['quality']}")
                if selected['filesize']:
                    print(f"{Fore.CYAN}حجم تقریبی:{Style.RESET_ALL} {self.format_file_size(selected['filesize'])}")
                
                print(f"\n{Fore.CYAN}[*] آیا مایل به ادامه هستید؟ (y/n):{Style.RESET_ALL}")
                confirm = input(f"{Fore.GREEN}>>> {Style.RESET_ALL}").strip().lower()
                
                if confirm != 'y':
                    print(f"{Fore.YELLOW}[*] دانلود لغو شد.{Style.RESET_ALL}")
                    continue
                
                # شروع دانلود
                success = self.download_video(url, selected['format_id'], selected['quality'])
                
                if success:
                    print(f"\n{Fore.GREEN}[✓] عملیات با موفقیت به پایان رسید!{Style.RESET_ALL}")
                
                # پرسش برای ادامه
                print(f"\n{Fore.CYAN}[*] آیا می‌خواهید ویدیوی دیگری دانلود کنید؟ (y/n):{Style.RESET_ALL}")
                continue_choice = input(f"{Fore.GREEN}>>> {Style.RESET_ALL}").strip().lower()
                
                if continue_choice != 'y':
                    print(f"\n{Fore.YELLOW}[*] با تشکر از استفاده شما!{Style.RESET_ALL}")
                    break
                    
                self.clear_screen()
                self.show_banner()
                    
            except KeyboardInterrupt:
                print(f"\n\n{Fore.YELLOW}[*] برنامه توسط کاربر متوقف شد.{Style.RESET_ALL}")
                break
            except Exception as e:
                print(f"\n{Fore.RED}[!] خطای غیرمنتظره: {str(e)}{Style.RESET_ALL}")
                continue

def main():
    """تابع اصلی"""
    downloader = TwitterVideoDownloader()
    downloader.run()

if __name__ == "__main__":
    main()
EOF
    
    # دادن مجوز اجرا به فایل
    os.chmod('twitter_downloader.py', 0o755)
    
    echo -e "${GREEN}[✓] اسکریپت پایتون ایجاد شد.${NC}"
}

# تابع ایجاد اسکریپت اجرایی
create_launcher() {
    echo -e "${YELLOW}[*] ایجاد اسکریپت اجرایی...${NC}"
    
    cat > down-twitter-x.sh << 'EOF'
#!/bin/bash

# مسیر اسکریپت
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/twitter_downloader.py"

# بررسی وجود اسکریپت پایتون
if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo "خطا: اسکریپت پایتون یافت نشد!"
    echo "لطفاً ابتدا نصب را کامل کنید: ./install.sh"
    exit 1
fi

# فعال‌سازی محیط مجازی پایتون
if [ -d "$SCRIPT_DIR/venv" ]; then
    source "$SCRIPT_DIR/venv/bin/activate"
fi

# اجرای اسکریپت پایتون
python3 "$PYTHON_SCRIPT"

# غیرفعال‌سازی محیط مجازی
if [ -d "$SCRIPT_DIR/venv" ]; then
    deactivate
fi
EOF
    
    # دادن مجوز اجرا به فایل
    chmod +x down-twitter-x.sh
    
    echo -e "${GREEN}[✓] اسکریپت اجرایی ایجاد شد.${NC}"
}

# تابع نمایش راهنمای استفاده
show_usage() {
    echo -e "${GREEN}"
    cat << EOF

═══════════════════════════════════════════════════
                راهنمای استفاده
═══════════════════════════════════════════════════

پس از نصب کامل، می‌توانید از روش‌های زیر استفاده کنید:

1. روش مستقیم:
   ./down-twitter-x.sh

2. ایجاد لینک سمبلیک (اختیاری):
   sudo ln -s \$(pwd)/down-twitter-x.sh /usr/local/bin/twitter-dl
   سپس: twitter-dl

3. اجرای مستقیم اسکریپت پایتون:
   ./twitter_downloader.py

═══════════════════════════════════════════════════
   دستورات سریع:
═══════════════════════════════════════════════════
   نصب مجدد:        ./install.sh
   به‌روزرسانی:      git pull
   حذف برنامه:      rm -rf down-twitter-x/
═══════════════════════════════════════════════════

${NC}"
}

# تابع اصلی نصب
main_installation() {
    show_logo
    echo -e "${GREEN}[*] شروع فرآیند نصب Down Twitter/X Bot...${NC}"
    
    # بررسی وابستگی‌ها
    check_dependencies
    
    # نصب پکیج‌های پایتون
    install_python_packages
    
    # ایجاد اسکریپت پایتون
    create_python_script
    
    # ایجاد اسکریپت اجرایی
    create_launcher
    
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════╗"
    echo "║                                        ║"
    echo "║   نصب با موفقیت کامل شد! 🎉          ║"
    echo "║                                        ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # نمایش راهنمای استفاده
    show_usage
    
    echo -e "${YELLOW}[*] برای شروع، دستور زیر را اجرا کنید:${NC}"
    echo -e "${GREEN}    ./down-twitter-x.sh${NC}"
}

# اجرای تابع اصلی
main_installation
