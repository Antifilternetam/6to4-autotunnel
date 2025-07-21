## 🚀 One-line Installation

Copy and run this on each server (IRAN and KHAREJ):

```bash
bash <(curl -Ls https://raw.githubusercontent.com/Antifilternetam/6to4-autotunnel/main/6to4.sh)
```
⚙️ Features

Stateless IPv6 tunnel over public IPv4 using 6to4

Auto-generates persistent IPv6 addresses (2002:<IPv4>::1)

Systemd service for auto-start after reboot

Enables ICMPv6 (ping6) automatically

No password, no SSH connection required between servers



---

📦 Requirements

Debian/Ubuntu server

Public IPv4 (on both ends)

Port 41 must be open (check your VPS firewall or provider)



---
🧪 IPv6 

After setup, test from one server to the other using:

Iran server 
```
 ping 2002:2e1f:4f5d::1
```
Kharej server
```
Ping 2002:5eb6:958a::1

```

🇮🇷 راهنمای فارسی

این اسکریپت به شما اجازه می‌دهد بدون نیاز به IPv6 واقعی، یک تونل 6to4 بین دو سرور برقرار کنید که فقط IPv4 دارند.
---

⚡ نصب سریع:

کافیست دستور زیر را در هر دو سرور (ایران و خارج) اجرا کنید:
```bash
bash <(curl -Ls https://raw.githubusercontent.com/Antifilternetam/6to4-autotunnel/main/6to4.sh)
```

اسکریپت از شما نقش سرور (iran یا kharej) و آی‌پی عمومی هر دو را می‌پرسد، سپس:

تونل 6to4 را با آدرس مناسب IPv6 تنظیم می‌کند

پورت‌های مورد نیاز را باز می‌کند

اتصال دو سرور از طریق IPv6 برقرار می‌شود

و پس از ریبوت هم همه‌چیز خودکار اجرا می‌شود
---
❌ حذف تونل (Uninstall)

اگر خواستید همه تنظیمات را پاک کنید:

sudo systemctl stop 6to4.service
sudo systemctl disable 6to4.service
sudo rm /etc/systemd/system/6to4.service
sudo rm /usr/local/bin/setup-6to4.sh
sudo ip tunnel del sit0


---
