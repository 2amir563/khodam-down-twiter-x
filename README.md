
این ربات تلگرامی برای دانلود از توییتر هست
دستور نصب در سرور:
bash
# نصب
```
bash <(curl -s https://raw.githubusercontent.com/2amir563/khodam-down-twiter-x/main/install.sh)
```

مراحل اجرا:
مرحله ۱: تنظیم اولیه
bash
```
twitter-bot setup
```
مرحله ۲: ویرایش فایل config (اضافه کردن توکن ربات)
bash
twitter-bot config
در فایل ویرایشگر، توکن ربات خود را قرار دهید:

text
BOT_TOKEN=6123456789:AAEfghIJKlmNOPqRsTUVwxyZ-abcdefg
مرحله ۳: تست نصب
bash
twitter-bot test
مرحله ۴: اجرای ربات
bash
twitter-bot start
مرحله ۵: بررسی وضعیت
bash
twitter-bot status
twitter-bot logs
گرفتن توکن ربات تلگرام:
در تلگرام، @BotFather را جستجو کنید

روی آن کلیک کرده و Start بزنید

دستور /newbot را ارسال کنید

نام ربات را انتخاب کنید (مثلاً: Twitter Video DL)

یوزرنیم ربات را انتخاب کنید (مثلاً: MyTwitterVideoDLBot)

توکن را کپی کنید (یک رشته مثل: 6123456789:AAEfghIJKlmNOPqRsTUVwxyZ-abcdefg)
