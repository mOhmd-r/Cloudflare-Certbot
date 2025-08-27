# Certbot + Cloudflare DNS Automation

Automate SSL certificate issuance with **Certbot** using **Cloudflare DNS-01 challenge** inside a Python virtual environment.  

---

## Requirements

- Ubuntu/Debian-based system  
- `python3`, `python3-pip`, `python3-venv`  
- Cloudflare API Token with **DNS edit permissions** for the domain  

---

## How It Works

1. Prompts for your **full domain** (e.g., `sub.example.com`) and **Cloudflare API token**.  
2. Extracts the **root domain** and **subdomain** automatically.  
3. Creates a **Cloudflare credentials file** at `~/.secrets/certbot/cloudflare.ini` with restricted permissions.  
4. Sets up a **Python virtual environment** at `~/certbot-venv`.  
5. Installs **Certbot** and the **Cloudflare DNS plugin** inside the virtual environment.  
6. Runs Certbot to request the SSL certificate using the DNS-01 challenge.  

---

## Usage

Make the script executable and run it:

```bash
chmod +x certbot-cloudflare.sh
./certbot-cloudflare.sh
