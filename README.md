# 6to4-autotunnel

🌍 Automatically enable IPv6 communication between two public IPv4-only servers using a 6to4 tunnel.

---

## 🚀 One-line installation

```bash
bash <(curl -Ls https://raw.githubusercontent.com/Antifilternetam/6to4-autotunnel/main/6to4.sh)
⚙️ Features

Stateless IPv6 via 6to4 tunnel (sit0)

Systemd-based persistent tunnel setup

Auto firewall configuration (ICMPv6 allow)

Easy setup on both IRAN / KHAREJ servers


📦 Requirements

Debian/Ubuntu-based server (with public IPv4)

Port 41 must be open (for IPv6-over-IPv4 tunneling)



---


🧪 After running:

Test from one server to another:

ping6 2002:<peer-ip-hex>::1


---
توضیحات فارسی

این اسکریپت یک تونل 6to4 بین دو سرور عمومی ایجاد می‌کند تا بدون نیاز به IPv6 واقعی، ارتباط ورژن ۶ بین دو سرور داشته باشید.

برای نصب، کافی‌ست فقط همین خط را بزنید:

bash <(curl -Ls https://raw.githubusercontent.com/Antifilternetam/6to4-autotunnel/main/6to4.sh)


---

💬 License

MIT — Free for all freedom fighters 😎
