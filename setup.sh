#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Asahi Linux unattended setup script
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# DNF: Remove KDE PIM group
# ---------------------------------------------------------------------------
echo "==> Removing bloat groups..."
sudo dnf group remove -y kde-pim libreoffice kde-media admin-tools 2>/dev/null || true

# ---------------------------------------------------------------------------
# DNF: Remove setroubleshoot and abrt
# ---------------------------------------------------------------------------
echo "==> Removing setroubleshoot and abrt..."
sudo dnf remove -y \
  setroubleshoot \
  abrt \
  fedora-bookmarks \
  kdebugsettings \
  2>/dev/null || true

# ---------------------------------------------------------------------------
# DNF: Remove KDE games group and individual game packages
# ---------------------------------------------------------------------------
echo "==> Removing individual KDE game packages..."
sudo dnf remove -y \
  kapman \
  katomic \
  kblackbox \
  kblocks \
  kbounce \
  kbreakout \
  kdegames \
  kdiamond \
  kfourinline \
  kgoldrunner \
  kigo \
  killbots \
  kiriki \
  kjumpingcube \
  klickety \
  klines \
  kmahjongg \
  kmines \
  knavalbattle \
  knetwalk \
  knights \
  kollision \
  konquest \
  kpat \
  kreversi \
  kshisen \
  ksirk \
  ksnakeduel \
  ksquares \
  ksudoku \
  ktuberling \
  kubrick \
  lskat \
  palapeli \
  picmi \
  granateer \
  2>/dev/null || true

# ---------------------------------------------------------------------------
# DNF: Remove packages being replaced by flatpaks
# ---------------------------------------------------------------------------
echo "==> Removing packages being replaced by flatpaks..."
sudo dnf remove -y \
  firefox \
  openh264 \
  mozilla-openh264 \
  gwenview \
  okular \
  qrca \
  skanlite \
  kwalletmanager5 \
  2>/dev/null || true

# ---------------------------------------------------------------------------
# Flatpak: Replace Fedora remote with Flathub
# ---------------------------------------------------------------------------
echo "==> Collecting list of Fedora-sourced flatpaks..."
FEDORA_APPS=$(flatpak list --system --app --columns=application,origin 2>/dev/null \
  | awk '$2 == "fedora" {print $1}')

echo "==> Removing Fedora flatpak remotes..."
sudo flatpak remote-delete --force fedora 2>/dev/null || true
sudo flatpak remote-delete --force fedora-testing 2>/dev/null || true

echo "==> Uninstalling Fedora-sourced flatpaks..."
echo "$FEDORA_APPS" | xargs -r sudo flatpak uninstall --system --assumeyes 2>/dev/null || true

echo "==> Adding Flathub remote..."
sudo flatpak remote-add --system --if-not-exists flathub \
  https://dl.flathub.org/repo/flathub.flatpakrepo

echo "==> Reinstalling Fedora flatpaks from Flathub..."
echo "$FEDORA_APPS" | xargs -r sudo flatpak install --system --assumeyes --noninteractive flathub 2>/dev/null || true

# ---------------------------------------------------------------------------
# Flatpak: Install apps from Flathub (with local sideload repo)
# ---------------------------------------------------------------------------
echo "==> Installing flatpaks..."
sudo flatpak install --system --noninteractive --assumeyes \
  flathub \
  org.gtk.Gtk3theme.Breeze \
  org.kde.gwenview \
  org.kde.okular \
  org.kde.haruna \
  org.kde.qrca \
  org.kde.kcalc \
  org.kde.keepsecret \
  org.kde.skanpage \
  org.kde.merkuro \
  org.mozilla.firefox

# ---------------------------------------------------------------------------
# tmpfiles.d: Write zswap configuration
# ---------------------------------------------------------------------------
echo "==> Writing /etc/tmpfiles.d/zswap.conf..."
sudo tee /etc/tmpfiles.d/zswap.conf > /dev/null << 'EOF'
#Type Path                                            Mode UID  GID  Age  Content
w     /sys/module/zswap/parameters/max_pool_percent   -    -    -    -    75
w     /sys/module/zswap/parameters/zpool              -    -    -    -    zsmalloc
w     /sys/module/zswap/parameters/enabled            -    -    -    -    Y
w     /sys/module/zswap/parameters/compressor         -    -    -    -    zstd
w     /sys/module/zswap/parameters/shrinker_enabled   -    -    -    -    Y
w     /sys/module/zswap/parameters/exclusive_loads    -    -    -    -    Y
EOF

# ---------------------------------------------------------------------------
# tmpfiles.d: Remove old Asahi zswap config
# ---------------------------------------------------------------------------
echo "==> Removing /etc/tmpfiles.d/asahi-enable-zswap.conf..."
sudo rm -f /etc/tmpfiles.d/asahi-enable-zswap.conf

# Apply tmpfiles changes immediately without rebooting
sudo systemd-tmpfiles --create /etc/tmpfiles.d/zswap.conf

# ---------------------------------------------------------------------------
# Kernel cmdline: Set performance/latency parameters via grubby
# ---------------------------------------------------------------------------
echo "==> Applying kernel cmdline parameters..."
sudo grubby --update-kernel=ALL \
  --args="preempt=full threadirqs nohz=on nohz_full=all rcu_nocbs=all rcutree.enable_rcu_lazy=1"

echo ""
echo "==> Setup complete. Reboot for kernel parameter changes to take effect."
