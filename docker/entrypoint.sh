#!/usr/bin/env bash
set -euo pipefail

STATE_DIR=${TAILSCALE_STATE_DIR:-/var/lib/tailscale}
SOCKET=${TAILSCALE_SOCKET:-/var/run/tailscale/tailscaled.sock}
HOSTNAME=${TS_HOSTNAME:-gh-test}
TS_EXTRA=${TS_EXTRA_ARGS:-}
SSH_PORT=${SSH_PORT:-22}
SSH_USER=${SSH_USER:-runner}
# TS_TUN: auto | tun | userspace (default: auto -> /dev/net/tun if present, else userspace)
TS_TUN=${TS_TUN:-auto}
# TAILSCALE_AUTHKEY preferred; TS_AUTHKEY2 (non-ephemeral testing key) as fallback
TAILSCALE_AUTHKEY=${TAILSCALE_AUTHKEY:-${TS_AUTHKEY2:-}}

: "${TAILSCALE_AUTHKEY:?TAILSCALE_AUTHKEY must be provided}"
mkdir -p "$STATE_DIR" /var/run/tailscale
rm -f "$SOCKET" "$STATE_DIR"/tailscaled.state "$STATE_DIR"/tailscaled.pid

ts() { tailscale --socket="$SOCKET" "$@"; }

# Phase 1 (GH runner) runs non-root: prefix privileged calls with sudo there;
# in the test container we are already root, so no wrapper is used.
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
fi

cleanup() {
  echo "[entrypoint] teardown: logout + stopping sshd/tailscaled" >&2
  pkill -x sshd 2>/dev/null || true
  ts logout 2>/dev/null || true
  pkill -x tailscaled 2>/dev/null || true
  rm -f "$SOCKET" "$STATE_DIR"/tailscaled.state "$STATE_DIR"/tailscaled.pid
  exit 0
}
trap cleanup INT TERM

setup_sshd() {
  echo "[sshd] configuring (user: $SSH_USER)" >&2
  USER_HOME=$(eval echo "~$SSH_USER")
  mkdir -p /run/sshd "$USER_HOME/.ssh"
  chmod 700 "$USER_HOME/.ssh"
  chown -R "$SSH_USER:$SSH_USER" "$USER_HOME/.ssh"
  if [ -n "${SSH_PASSWORD:-}" ]; then
    cat > /etc/ssh/sshd_config.d/99-gh-test.conf <<EOF
PermitRootLogin no
PasswordAuthentication yes
KbdInteractiveAuthentication no
EOF
    echo "$SSH_USER:${SSH_PASSWORD}" | chpasswd
  elif [ -n "${SSH_PUBLIC_KEY:-}" ]; then
    cat > /etc/ssh/sshd_config.d/99-gh-test.conf <<EOF
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
EOF
    echo "$SSH_PUBLIC_KEY" > "$USER_HOME/.ssh/authorized_keys"
    chmod 600 "$USER_HOME/.ssh/authorized_keys"
    chown "$SSH_USER:$SSH_USER" "$USER_HOME/.ssh/authorized_keys"
  else
    echo "[sshd] FATAL: provide SSH_PASSWORD or SSH_PUBLIC_KEY in env (.env)" >&2
    exit 1
  fi
  chmod 600 /etc/ssh/sshd_config.d/99-gh-test.conf
  ssh-keygen -A >/dev/null
  $SUDO /usr/sbin/sshd -p "$SSH_PORT"
  echo "[sshd] listening on :$SSH_PORT (login as $SSH_USER)" >&2
}

case "$TS_TUN" in
  tun)
    TUN_ARGS=(--tun tun)
    echo "[entrypoint] TUN mode: kernel tun (--tun tun)" >&2
    ;;
  userspace)
    TUN_ARGS=(--tun userspace-networking)
    ;;
  auto)
    if [ -e /dev/net/tun ]; then
      TUN_ARGS=(--tun tun)
      echo "[entrypoint] TUN mode: auto -> kernel tun (/dev/net/tun present)" >&2
    else
      TUN_ARGS=(--tun userspace-networking)
      echo "[entrypoint] TUN mode: auto -> userspace (/dev/net/tun absent)" >&2
    fi
    ;;
  *)
    echo "[entrypoint] Error: TS_TUN must be one of: auto|tun|userspace" >&2
    exit 1
    ;;
esac

echo "[entrypoint] starting tailscaled" >&2
$SUDO tailscaled "${TUN_ARGS[@]}" \
  --state="$STATE_DIR"/tailscaled.state \
  --socket="$SOCKET" &
TSD_PID=$!

echo "[entrypoint] waiting for tailscaled socket..." >&2
for i in $(seq 1 40); do
  [ -S "$SOCKET" ] && break
  if [ "$i" -eq 40 ]; then
    echo "[entrypoint] Error: tailscaled socket was not created in time" >&2
    exit 1
  fi
  sleep 0.5
done

setup_sshd

echo "[entrypoint] tailscale up (authkey, no tailscale-ssh: custom sshd on :$SSH_PORT)" >&2
ts up --authkey="$TAILSCALE_AUTHKEY" --hostname="$HOSTNAME" --reset $TS_EXTRA

TS_IP=$(ts ip -4)
echo "[entrypoint] logged in as node: $HOSTNAME"
echo "[entrypoint] tailscale ip -4: $TS_IP"
ts status || true

# --- foreground waiter: exit if tailscaled dies; signal -> cleanup ---
set +e
wait "$TSD_PID"
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  echo "[entrypoint] tailscaled exited unexpectedly (rc=$rc)" >&2
  cleanup
fi
