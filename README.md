# نصب trafx-socks روی میکروتیک

> **این مخزن منتقل شد:** نصب و راهنمای جدید (رایگان، بدون لایسنس، با HTTP/HTTPS پراکسی) در
> **[TrafXCloud/trafx-access-server](https://github.com/TrafXCloud/trafx-access-server)** است. روترهایی که با
> این مخزن نصب شده‌اند با `update.rsc` همین‌جا هم به آخرین نسخه می‌روند؛ نصب‌های جدید را از مخزن جدید انجام دهید.
> ساخت [TrafX Cloud](https://trafx.cloud) · [t.me/trafxcloud](https://t.me/trafxcloud)


سرور SOCKS5 (TCP و UDP) که ورود، ثبت مصرف و قطع کاربر را از پنل TrafX Radius می‌گیرد،
به صورت کانتینر روی RouterOS 7.

## پیش‌نیاز

- RouterOS 7 با پکیج `container` و `device-mode` فعال برای container
- معماری x86_64 (CHR)، arm64 یا arm (ARMv7)
- در پنل: یک NAS با IP عمومی این روتر، نوع `other` و یک secret بلند
- لایسنس (`TXS1....`) برای IP همین روتر

## نصب

در ترمینال میکروتیک (مقدارها را عوض کنید):

```
:global tsPanel "PANEL_IP"
:global tsSecret "NAS_SECRET"
:global tsLicense "TXS1...."
:global tsTunnel "to-uk"
/tool fetch url="https://raw.githubusercontent.com/alirezamshk/trafx-socks-install/main/install.rsc" dst-path=trafx-socks-install.rsc
/import trafx-socks-install.rsc
```

- `tsTunnel` اختیاری است: نام routing table تونلی که ترافیک کاربرها از آن بیرون برود. اگر نگذارید، مستقیم بیرون می‌رود.
- اختیاری: `tsPublicIP` (اگر تشخیص خودکار IP عمومی درست نبود)، `tsDisk`، `tsPort` (پیش‌فرض 1080).
- بعد از نصب، این متغیرها از حافظه‌ی روتر پاک می‌شوند.

اسکریپت یک bridge جدا (`br-trafx-socks`، شبکه‌ی `172.31.250.0/24`) می‌سازد و با شبکه‌های دیگر روتر تداخل ندارد.
همه‌ی چیزهایی که می‌سازد توضیح `trafx-socks` دارند.

## OpenConnect / AnyConnect (ocserv) در همان کانتینر

همان NAS، همان secret و همان لایسنس؛ قبل از `/tool fetch` این‌ها را هم اضافه کنید:

```
:global tsOcserv "yes"
:global tsOcHost "oc.example.com"
:global tsOcEmail "you@example.com"
:global tsOcLocations "to-uk=UK;to-de=Germany"
:global tsOcDefaultName "Iran"
```

- پورت پیش‌فرض 443 (`tsOcPort` برای عوض کردن). اگر سرویسی از خود روتر (مثل `www-ssl`، `reverse-proxy`،
  SSTP) یا قانون NAT دیگری این پورت را گرفته باشد، اسکریپت قبل از هر تغییری متوقف می‌شود و می‌گوید چه کنید.
- `tsOcHost` و `tsOcEmail`: گواهی Let's Encrypt که خودکار تمدید می‌شود. رکورد A دامنه باید به IP روتر اشاره کند
  (در Cloudflare پراکسی خاموش) و پورت 80 روتر آزاد باشد (مثلاً `/ip service set www port=8080`). بدون این دو،
  گواهی self-signed است.
- `tsOcLocations` (اختیاری): لوکیشن‌ها روی همان دامنه، به شکل `خروجی=اسم`؛ هر روتر هرکدام را که دارد
  (حداکثر ۱۰). خروجی یک **جدول مسیریابی** است (هر اسمی) یا یک **اینترفیس تونل نقطه‌به‌نقطه** (WireGuard، GRE،
  IPIP، ...) که اسکریپت برایش جدول و route می‌سازد. ترتیب منو همان ترتیب لیست است و اولی پیش‌فرض.
  برای ویرایش یا حذف، اسکریپت را با لیست کامل جدید دوباره اجرا کنید. کاربر در AnyConnect از منوی Group (و بعد از اتصال اول، از لیست اتصال‌های اپ) انتخاب می‌کند؛
  پرچم کشور خودکار اضافه می‌شود. `tsOcProfile "no"`: فقط منوی Group، بدون اضافه شدن به لیست اپ.
- `tsOcDefaultName`: اسم ورودی بدون لوکیشن (خروج از `tsTunnel` یا مستقیم)؛ `"none"` = این ورودی نباشد و
  فقط لوکیشن‌ها نمایش داده شوند.
- در پنل نیازی به تغییر نیست؛ NAS همان نوع `other` می‌ماند.

نصب دوباره (مثلاً برای عوض کردن لوکیشن‌ها) فقط متغیرهای جدید را لازم دارد؛ پنل، secret، لایسنس، تونل، دامنه
و لوکیشن‌های قبلی از تنظیمات روتر برداشته می‌شوند. گواهی در پوشه‌ی `trafx-socks-data` روی دیسک می‌ماند.

## HTTP و HTTPS پراکسی (همان پورت 1080)

با همان حساب‌های پنل، روی همان پورت SOCKS؛ قبل از `/tool fetch`:

```
:global tsHttp "yes"
:global tsHttps "yes"
```

- `tsHttp`: HTTP پراکسی (`http://USER:PASS@IP:1080`).
- `tsHttps`: HTTPS پراکسی (TLS، رمز کاربر رمزنگاری می‌شود)؛ از گواهی Let's Encrypt ocserv استفاده می‌کند، پس
  `tsOcserv`، `tsOcHost` و `tsOcEmail` لازم است. کلاینت با دامنه وصل می‌شود: `https://USER:PASS@oc.example.com:1080`.
- UDP ندارند (تماس تلگرام فقط با SOCKS). در پنل پروتکل نشست `1415053315` (HTTP) یا `1415053316` (HTTPS)
  نشان داده می‌شود. یک کاربر از یک IP با SOCKS و HTTP یک نشست دارد.
- Chrome / Edge پراکسی HTTPS را فقط با فایل PAC قبول می‌کنند؛ Firefox و curl مستقیم.
- روی روتری که از قبل نصب است: فقط این دو متغیر و دوباره `install.rsc` (بقیه‌ی تنظیمات از روتر برداشته می‌شود).

تست:

```
curl -x http://USER:PASS@ROUTER_IP:1080 https://ifconfig.me
```

## آپدیت

```
/tool fetch url="https://raw.githubusercontent.com/alirezamshk/trafx-socks-install/main/update.rsc" dst-path=trafx-socks-update.rsc
/import trafx-socks-update.rsc
```

## حذف

```
/tool fetch url="https://raw.githubusercontent.com/alirezamshk/trafx-socks-install/main/uninstall.rsc" dst-path=trafx-socks-uninstall.rsc
/import trafx-socks-uninstall.rsc
```

## بررسی

```
/log print where message~"trafx"
```

باید `accounting-on acknowledged by panel` و `trafx-socks started` دیده شود؛ با ocserv همچنین `ocserv started` و
(با دامنه) `certificate ok`:

```
/log print where message~"certificate"
```

## سرور لینوکس (Docker)

راهنمای نصب روی لینوکس (docker-compose، `.env`، خروجی هر لوکیشن از یک اینترفیس تونل، مثل
`fi:Finland:10.21.0.0/16:l2tp-fi@172.31.98.2` برای تونل لایه‌ی ۲) در README ریپوی اصلی است؛ image همان
`ghcr.io/alirezamshk/trafx-socks:ocserv` (از 0.3.2: خروجی با gateway و بازسازی خودکار route هر ۱۵ ثانیه).
