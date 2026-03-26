# Wordpresser — Local WordPress Dev Stack

Full local WordPress development environment running nginx, WordPress, PHP, MySQL,
phpMyAdmin, Mailpit, and automatic HTTPS via mkcert. Versions are controlled via `.env`.

---

## Table of contents

- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Configuration](#configuration)
- [URLs](#urls)
- [start.sh — version-checked startup](#startsh--version-checked-startup)
- [Trusting the certificate on Windows](#trusting-the-certificate-on-windows)
  - [Chrome and Edge on Windows](#chrome-and-edge-on-windows)
  - [Firefox on Windows](#firefox-on-windows)
- [Trusting the certificate on macOS](#trusting-the-certificate-on-macos)
  - [Safari and Chrome on macOS](#safari-and-chrome-on-macos)
  - [Firefox on macOS](#firefox-on-macos)
- [Changing the site URL](#changing-the-site-url)
- [Services](#services)
- [Project structure](#project-structure)
- [How it works](#how-it-works)
  - [SSL certificates](#ssl-certificates)
  - [WordPress & PHP](#wordpress--php)
  - [File uploads](#file-uploads)
  - [Mailpit — email catching](#mailpit--email-catching)
  - [phpMyAdmin](#phpmyadmin)
  - [Database](#database)
- [Regenerating certificates](#regenerating-certificates)
- [Re-running first-time setup](#re-running-first-time-setup)
- [Full reset](#full-reset)
- [Built with Claude Code](#built-with-claude-code)

---

## Requirements

Two pieces of software need to be installed on your machine before you can run this stack:

| Software | Purpose | Download |
|---|---|---|
| Docker Desktop | Runs all the containers | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/) |
| Git Bash | Runs `start.sh` on Windows | [git-scm.com/downloads](https://git-scm.com/downloads) |

Git Bash is bundled with Git for Windows — if you already have Git installed, you likely
have it already. Look for "Git Bash" in your Start menu.

Everything else (WP-CLI, mkcert, PHP, nginx, etc.) runs inside the containers — nothing
else needs to be installed on your machine.

---

## Quick start

### 1. Configure your `.env` file

Open `.env` and fill in these values before doing anything else:

```env
# The local domain you want to use
LOCAL_DOMAIN=myproject.local
SITE_URL=https://myproject.local

# Your WordPress admin account
WP_ADMIN_USER=yourusername
WP_ADMIN_PASSWORD=yourpassword
WP_ADMIN_EMAIL=your@email.com

# Your site name
BLOG_NAME=My Project
```

See the [Configuration](#configuration) section for a full reference of every available setting.

### 2. Add the domain to your hosts file

This tells your computer to point the domain to your local machine.
Open **PowerShell as Administrator** and run the command below, replacing `myproject.local`
with whatever you set as `LOCAL_DOMAIN` in the previous step:

```powershell
Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "127.0.0.1 myproject.local"
```

You only need to do this once per domain.

### 3. Start the stack

Open **Git Bash** in the project folder and run:

```bash
./start.sh --build
```

The script checks that all versions in `.env` exist on Docker Hub, asks for confirmation,
then builds and starts everything. On first run this will take a few minutes. When it's
done, WordPress will be fully installed and configured automatically — there is no setup wizard.

### 4. Trust the SSL certificate

On first run, mkcert generates a local SSL certificate. You need to tell your browser to
trust it once, otherwise you will get a security warning.

**Chrome / Edge (PowerShell as Administrator, from the project folder):**
```powershell
Import-Certificate -FilePath ".\nginx\certs\rootCA.pem" `
    -CertStoreLocation Cert:\LocalMachine\Root
```

Then **fully close and reopen** your browser.

For Firefox, or if you are on macOS, see the [detailed certificate trust instructions](#trusting-the-certificate-on-windows) below.

### 5. Open your site

Visit `https://myproject.local` (or whatever domain you set) — you should see your
WordPress site with a green padlock and no warnings.

- WordPress admin: `https://myproject.local/wp-admin`
- phpMyAdmin: `http://localhost:8888`
- Mailpit (caught emails): `http://localhost:8025`

---

## Configuration

All settings live in `.env`. Here is a full reference:

```env
# Ports
HTTP_PORT=80           # HTTP port (redirects to HTTPS)
HTTPS_PORT=443         # HTTPS port — see note below if you change this
PHPMYADMIN_PORT=8888   # phpMyAdmin UI
MAILPIT_PORT=8025      # Mailpit UI

# Domains
LOCAL_DOMAIN=myproject.local
SITE_URL=https://myproject.local   # Must match LOCAL_DOMAIN — see note below if you change HTTPS_PORT

# Versions — change these to use different versions
PHP_VERSION=8.4
NGINX_VERSION=1.26.1
MYSQL_VERSION=8.0.35
WP_VERSION=6.9.4

# Site
BLOG_NAME=My Project
WP_DEBUG=true

# WordPress admin account (created automatically on first run)
WP_ADMIN_USER=yourusername
WP_ADMIN_PASSWORD=yourpassword
WP_ADMIN_EMAIL=your@email.com

# Themes (1 = yes, 0 = no)
DOWNLOAD_CRETLACH_THEME=1
DELETE_DEFAULT_THEMES=1

# Plugins (1 = install and activate, 0 = skip)
INSTALL_FORMIDABLE=1
INSTALL_ICON_BLOCK=1
INSTALL_FILEBIRD=1

# Database
DB_NAME=wordpress
DB_USER=wordpress
DB_PASSWORD=wordpress
DB_ROOT_PASSWORD=secret
```

After changing any version number, run `./start.sh --build` to rebuild the affected images.
After changing anything else (domains, credentials, site name), run `./start.sh` to restart
with the new values.

> **Note — theme and plugin flags:** `DOWNLOAD_CRETLACH_THEME`, `DELETE_DEFAULT_THEMES`,
> and the `INSTALL_*` flags only take effect during first-time setup. If you change them
> after the stack has already been set up, you need to re-run first-time setup — see
> [Re-running first-time setup](#re-running-first-time-setup).

> **Important — if you change `HTTPS_PORT` away from 443:** port 443 is the standard HTTPS
> port, so browsers don't show it in the URL. If you use a different port (e.g. 8443), you
> must also update `SITE_URL` to include the port — for example
> `SITE_URL=https://myproject.local:8443` — otherwise WordPress will generate broken links.
> You also need to update the redirect in `nginx/nginx.conf`. See
> [Changing the site URL](#changing-the-site-url) for the full steps.

---

## URLs

Replace `myproject.local` in the table below with whatever you set as `LOCAL_DOMAIN` in `.env`.

| URL | What it does |
|-----|-------------|
| `http://myproject.local` | Redirects → `https://myproject.local` |
| `https://myproject.local` | WordPress site |
| `https://myproject.local/wp-admin` | WordPress admin |
| `http://localhost:8888` | phpMyAdmin |
| `http://localhost:8025` | Mailpit (caught emails) |

---

## start.sh — version-checked startup

You can start the stack with plain `docker compose up --build` if you prefer, but
`start.sh` adds one useful step first: it validates that every version specified in
`.env` actually exists on Docker Hub before attempting to build or pull anything,
then asks for confirmation before starting. This prevents a failed build caused by
a typo in a version number.

```bash
./start.sh             # normal start
./start.sh -d          # detached (background)
./start.sh --build     # force rebuild of images
./start.sh --build -d  # rebuild in background
```

**What it checks:**

| Variable | Image checked |
|---|---|
| `NGINX_VERSION` | `nginx:<version>` |
| `MYSQL_VERSION` | `mysql:<version>` |
| `WP_VERSION` + `PHP_VERSION` | `wordpress:<wp>-php<php>-fpm` |

If a version does not exist, the script exits immediately with an error and
prints a link to the image's Docker Hub tags page so you can find a valid version:

```
Checking image versions against Docker Hub...

  nginx:1.26.99                                 NOT FOUND
         ^ Check NGINX_VERSION in your .env file
         ^ Browse available tags: https://hub.docker.com/_/nginx/tags

Found 1 invalid version(s). Please fix your .env file and try again.
```

If all versions are valid, it asks for confirmation before proceeding:

```
All versions verified.

Start the services? [Y/n]
```

Press Enter (or `y`) to continue, `n` to abort.

> **Note:** Run `start.sh` from Git Bash or WSL on Windows — it will not work in PowerShell or CMD.

---

## Trusting the certificate on Windows

### Chrome and Edge on Windows

Both Chrome and Edge use the Windows system certificate store, so one import covers both.

> The stack must have been started at least once before the certificate file exists.
> If you followed Quick Start, it already has been.

1. Open **PowerShell as Administrator** and run from the project root:
   ```powershell
   Import-Certificate -FilePath ".\nginx\certs\rootCA.pem" `
       -CertStoreLocation Cert:\LocalMachine\Root
   ```

2. **Fully close and reopen** Chrome or Edge.

3. Visit `https://myproject.local` (your domain) — green padlock, no warnings.

> You only need to do this once. If you regenerate certificates, repeat this step.

### Firefox on Windows

Firefox manages its own certificate store independently of the Windows system store.

1. Open Firefox and go to **Settings → Privacy & Security**.
2. Scroll down to **Certificates** and click **View Certificates**.
3. Select the **Authorities** tab and click **Import**.
4. In the file dialog, navigate to the project folder, then open the `nginx\certs` subfolder
   and select `rootCA.pem`.
5. Check **Trust this CA to identify websites** and click **OK**.
6. Restart Firefox.

---

## Trusting the certificate on macOS

### Safari and Chrome on macOS

Both Safari and Chrome use the macOS system keychain, so one import covers both.

> The stack must have been started at least once before the certificate file exists.
> If you followed Quick Start, it already has been.

1. Run this command from the project root:
   ```bash
   sudo security add-trusted-cert -d -r trustRoot \
       -k /Library/Keychains/System.keychain nginx/certs/rootCA.pem
   ```

2. **Fully close and reopen** Safari or Chrome.

3. Visit `https://myproject.local` (your domain) — green padlock, no warnings.

Alternatively, you can import it manually via Keychain Access:
1. Open **Keychain Access** (search for it in Spotlight).
2. Drag `nginx/certs/rootCA.pem` into the **System** keychain.
3. Double-click the imported certificate, expand **Trust**, and set
   **When using this certificate** to **Always Trust**.
4. Close the dialog and enter your password to confirm.

### Firefox on macOS

Firefox manages its own certificate store independently of the system keychain.

1. Open Firefox and go to **Settings → Privacy & Security**.
2. Scroll down to **Certificates** and click **View Certificates**.
3. Select the **Authorities** tab and click **Import**.
4. In the file dialog, navigate to the project folder, then open the `nginx/certs` subfolder
   and select `rootCA.pem`.
5. Check **Trust this CA to identify websites** and click **OK**.
6. Restart Firefox.

---

## Changing the site URL

1. Update `.env`:
   ```env
   LOCAL_DOMAIN=yourchoice.local
   SITE_URL=https://yourchoice.local
   ```

2. Update the hardcoded fallback domain in `nginx/entrypoint.sh` (line 5). Open the file
   in any text editor and change the fallback value to match your new domain. This value
   is only used if Docker fails to pass the environment variable through — it should
   always match `LOCAL_DOMAIN`:
   ```sh
   DOMAIN="${LOCAL_DOMAIN:-yourchoice.local}"
   ```

3. Add the new domain to your Windows hosts file (PowerShell as Administrator):
   ```powershell
   Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "127.0.0.1 yourchoice.local"
   ```

4. Delete the old certificates so they are regenerated for the new domain.
   Run this in **Git Bash** from the project folder:
   ```bash
   rm nginx/certs/cert.pem nginx/certs/key.pem nginx/certs/rootCA.pem
   ```

5. Rebuild and restart in **Git Bash**:
   ```bash
   ./start.sh --build
   ```

6. Re-import the new `nginx/certs/rootCA.pem` into Windows (see [Chrome and Edge on Windows](#chrome-and-edge-on-windows) above).

---

**If you are also changing `HTTPS_PORT` away from 443**, three more things need updating
in addition to the steps above:

- **`SITE_URL` in `.env`** must include the port:
  ```env
  SITE_URL=https://yourchoice.local:8443
  ```
- **The HTTP→HTTPS redirect in `nginx/nginx.conf`** must include the port. Open the file
  in any text editor, find the line that reads `return 301 https://$host$request_uri;`
  and change it to:
  ```nginx
  return 301 https://$host:8443$request_uri;
  ```
- **Re-import the certificate** after rebuilding (step 6 above).

Skipping any of these three will result in either broken links or a browser that refuses
to open the site.



## Services

Versions are set in `.env` and validated by `start.sh` before each run.

| Service | Image | Purpose |
|---------|-------|---------|
| `mysql` | `mysql:<MYSQL_VERSION>` | Database |
| `wordpress` | `wordpress:<WP_VERSION>-php<PHP_VERSION>-fpm` | WordPress + PHP-FPM |
| `nginx` | `nginx:<NGINX_VERSION>` (custom build) | Web server, HTTPS, SSL termination |
| `phpmyadmin` | `phpmyadmin:latest` | Database management UI |
| `mailpit` | `axllent/mailpit:latest` | Catches all outgoing WordPress emails |

**Startup order** (via `depends_on`):
```
mysql → wordpress → nginx
mysql → phpmyadmin
mailpit (independent)
```

---

## Project structure

```
wordpresser/
├── .env                        # All configuration — ports, domains, versions, credentials
├── docker-compose.yml
├── start.sh                    # Version-checking startup script (optional, see start.sh section)
├── src/                        # WordPress files (populated automatically on first run)
├── php/
│   └── php.ini                 # Custom PHP configuration
├── nginx/
│   ├── Dockerfile              # Builds nginx with mkcert compiled in
│   ├── entrypoint.sh           # Generates SSL certs if missing, then starts nginx
│   ├── nginx.conf              # HTTP redirect + HTTPS + PHP-FPM proxy config
│   └── certs/                  # Generated at runtime — do not commit to git
└── wordpress/
    ├── Dockerfile              # WordPress + PHP-FPM image
    └── entrypoint.sh           # Installs WordPress, themes, plugins on first run
```

---

## How it works

### SSL certificates

The nginx image is built with [mkcert](https://github.com/FiloSottile/mkcert)
compiled in as a static binary. Before nginx starts, the entrypoint reads
`LOCAL_DOMAIN` from the environment and generates certificates for `localhost`
and that domain. nginx will never start without valid certificates — the missing
cert error cannot occur.

Generated files:

| File | Purpose |
|------|---------|
| `nginx/certs/cert.pem` | Server certificate |
| `nginx/certs/key.pem` | Server private key |
| `nginx/certs/rootCA.pem` | Root CA — import this once into your browser/OS |

### WordPress & PHP

nginx proxies all `.php` requests to the `wordpress` service (PHP-FPM on
port 9000) via FastCGI. Both `nginx` and `wordpress` share the `./src`
directory as a volume — nginx mounts it read-only for serving static assets,
WordPress mounts it read-write so it can manage its own files (themes, plugins,
uploads).

WordPress uses `SITE_URL` from `.env` for both `WP_HOME` and `WP_SITEURL` — these
are synced automatically on every container start, so you never need to update them
manually in the WordPress database. Note that changing your domain involves more than
just `.env`; see [Changing the site URL](#changing-the-site-url) for the full steps.

WordPress pretty permalinks are supported via `try_files $uri $uri/ /index.php?$args`.

### First-run setup

The WordPress container runs a setup script (`wordpress/entrypoint.sh`) every time
it starts, but most of the work only happens once. On first start it installs
WordPress, clones the theme, removes default themes and plugins, and installs any
plugins enabled in `.env`. When finished it writes a marker file at
`src/.setup_complete`. On every subsequent start the script sees that file and skips
straight to starting PHP-FPM — so plain restarts are fast and produce no noise in
the logs.

Two things still run on every start regardless: the uploads directory permissions
fix (harmless and instant) and the siteurl/blogname sync, so that changing
`SITE_URL` or `BLOG_NAME` in `.env` and running `docker compose up` is enough to
pick up the new values without a full rebuild.

### File uploads

`client_max_body_size 64M` is set in nginx and `upload_max_filesize = 64M` /
`post_max_size = 64M` in `php/php.ini` so large media uploads work out of the box.

### Mailpit — email catching

All outgoing WordPress emails are intercepted by Mailpit — nothing reaches a
real mail server. This is handled by a must-use plugin at
`src/wp-content/mu-plugins/mailpit.php` which hooks into WordPress's
`phpmailer_init` action and points PHPMailer at Mailpit's SMTP port (1025,
internal to the Docker network only).

View caught emails at `http://localhost:8025`.

### phpMyAdmin

phpMyAdmin provides a web UI for managing the MySQL database.

**URL:** `http://localhost:8888`

**Login credentials:**

| Field | Value |
|-------|-------|
| Server | `mysql` (auto-filled) |
| Username | value of `DB_USER` in `.env` |
| Password | value of `DB_PASSWORD` in `.env` |

You can also log in as `root` using `DB_ROOT_PASSWORD` from `.env` if you need
full administrative access (e.g. creating additional databases or users).

### Database

MySQL data is stored in a named Docker volume (`mysql_data`) so the database
persists across container restarts. Credentials are configured in `.env`.

---

## Regenerating certificates

If you need to regenerate certificates (e.g. after changing `LOCAL_DOMAIN`),
run these in **Git Bash** from the project folder:

```bash
rm nginx/certs/cert.pem nginx/certs/key.pem nginx/certs/rootCA.pem
docker compose restart nginx
```

Then re-import `rootCA.pem` into your browser — see the certificate trust instructions
above for your browser and OS.

---

## Re-running first-time setup

If you want to re-run the one-time setup (for example, you changed a plugin flag in
`.env` after the first run), delete the marker file and restart the container.
Run these in **Git Bash** from the project folder:

```bash
rm src/.setup_complete
docker compose up -d
```

The container will run through the full setup again on the next start. This is
lighter than a full reset — your database and uploaded files are left untouched.

---

## Full reset

> **Warning:** This deletes all WordPress content, database data, and uploaded files.
> There is no undo.

To completely tear down the stack and start fresh — removes all containers, images,
volumes, and WordPress files. Run these in **Git Bash** from the project folder:

```bash
docker compose down -v --rmi all
rm -rf src && mkdir src
```

Then run `./start.sh --build` to rebuild everything from scratch.

---

## Built with Claude Code

This project was developed with [Claude Code](https://claude.ai/claude-code),
the official CLI for Claude by Anthropic.

| | |
|-|-|
| **Model** | Claude Sonnet 4.6 (`claude-sonnet-4-6`) |
| **Developer** | [Anthropic](https://www.anthropic.com) |
