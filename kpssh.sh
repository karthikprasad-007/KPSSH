#!/usr/bin/env bash
set -e

# ================================
# kpssh v1.0.1
# Safe Git SSH Identity Manager
# ================================

# ---------- UI helpers ----------
bold() { printf "\033[1m%s\033[0m\n" "$1"; }
ok() { printf "✔ %s\n" "$1"; }
warn() { printf "⚠ %s\n" "$1"; }
err() { printf "✖ %s\n" "$1"; exit 1; }

separator() {
  echo "--------------------------------------------------"
}

# ---------- Banner ----------
clear
bold "=================================================="
bold "                  kpssh"
bold "   Safe Git SSH Identity Manager (V1)"
bold "=================================================="
echo
echo "This tool will:"
echo " • Create SSH keys safely (no overwrite)"
echo " • Configure SSH for GitHub"
echo " • Optionally add the key automatically"
echo " • Never delete existing keys"
echo
separator

# ---------- Platform (V1 fixed) ----------
bold "Platform"
echo "GitHub (V1)"
separator

# ---------- User input ----------
read -rp "Enter account alias (work / personal / etc): " ALIAS
[[ -z "$ALIAS" ]] && err "Alias cannot be empty."

read -rp "Enter GitHub email: " EMAIL
[[ -z "$EMAIL" ]] && err "Email cannot be empty."

KEY_NAME="id_ed25519_${ALIAS}"
KEY_PATH="$HOME/.ssh/$KEY_NAME"
SSH_CONFIG="$HOME/.ssh/config"
HOST_ALIAS="github-${ALIAS}"

separator
bold "SSH Key Setup"

# ---------- SSH directory ----------
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
ok "SSH directory ready"

# ---------- Generate key safely ----------
if [[ -f "$KEY_PATH" ]]; then
  warn "SSH key already exists for alias '$ALIAS'"
else
  ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY_PATH" -N ""
  ok "SSH key generated: $KEY_NAME"
fi

# ---------- Start ssh-agent ----------
if ! pgrep -u "$USER" ssh-agent >/dev/null; then
  eval "$(ssh-agent -s)" >/dev/null
fi

ssh-add "$KEY_PATH" >/dev/null
ok "SSH key added to ssh-agent"

separator
bold "SSH Configuration"

# ---------- Update ~/.ssh/config safely ----------
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

if grep -q "Host $HOST_ALIAS" "$SSH_CONFIG"; then
  warn "SSH config entry already exists for $HOST_ALIAS"
else
  cat <<EOF >> "$SSH_CONFIG"

# kpssh - GitHub ($ALIAS)
Host $HOST_ALIAS
    HostName github.com
    User git
    IdentityFile $KEY_PATH
EOF
  ok "SSH config updated with host '$HOST_ALIAS'"
fi

separator
bold "Add SSH Key to GitHub"

echo "Do you want kpssh to automatically add the SSH key to GitHub?"
echo "  1) Yes (uses GitHub CLI)"
echo "  2) No (I will copy & paste manually)"
read -rp "Enter choice [1-2]: " ADD_MODE

# ---------- AUTO MODE ----------
if [[ "$ADD_MODE" == "1" ]]; then
  separator
  bold "Checking GitHub CLI"

  if ! command -v gh >/dev/null 2>&1; then
    warn "GitHub CLI (gh) not found."
    echo
    echo "To add keys automatically, GitHub CLI must be installed."
    echo "kpssh will NOT install anything without your permission."
    echo
    echo "  1) Install GitHub CLI now"
    echo "  2) Skip and use manual copy-paste"
    read -rp "Enter choice [1-2]: " INSTALL_CHOICE

    if [[ "$INSTALL_CHOICE" == "1" ]]; then
      separator
      bold "Installing GitHub CLI"

      if [[ "$OSTYPE" == "darwin"* ]]; then
        command -v brew >/dev/null || err "Homebrew not found. Install Homebrew first."
        echo "Running: brew install gh"
        brew install gh
      elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        err "Please install GitHub CLI manually for your Linux distribution."
      elif [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* || "$OSTYPE" == "win32"* ]]; then
        command -v winget >/dev/null || err "winget not found. Please install App Installer from Microsoft Store."
        echo "Running: winget install GitHub.cli --silent"
        winget install GitHub.cli --silent
      else
        err "Unsupported OS for auto-install."
      fi

      ok "GitHub CLI installed"
    else
      ADD_MODE="2"
    fi
  fi

  if [[ "$ADD_MODE" == "1" ]]; then
    separator
    bold "GitHub Authentication"

    if ! gh auth status >/dev/null 2>&1; then
      echo "You need to log in to GitHub."
      gh auth login
    fi

    separator
    bold "Uploading SSH Key"

    gh ssh-key add "${KEY_PATH}.pub" -t "${ALIAS}-kpssh"
    ok "SSH key successfully added to GitHub"
  fi
fi

# ---------- MANUAL MODE ----------
if [[ "$ADD_MODE" == "2" ]]; then
  separator
  bold "Manual Setup"

  echo
  echo "=========================================="
  echo "GitHub Account: $ALIAS"
  echo "=========================================="
  echo
  echo "👉 COPY THIS PUBLIC SSH KEY (THIS LINE ONLY):"
  echo
  cat "${KEY_PATH}.pub"
  echo
  echo "📌 Paste it here:"
  echo "GitHub → Settings → SSH and GPG keys → New SSH key"
  echo
  echo "🔗 Direct link:"
  echo "https://github.com/settings/ssh/new"
  echo
fi

separator
bold "Verification"

echo "After adding the key, test with:"
echo
echo "  ssh -T git@$HOST_ALIAS"
echo
echo "Expected output:"
echo "  Hi <your-username>! You've successfully authenticated."

separator
ok "Setup completed successfully"
echo
echo "Use this format to clone repositories:"
echo
echo "  git clone git@$HOST_ALIAS:org/repo.git"
echo
bold "Thank you for using kpssh ✨"
