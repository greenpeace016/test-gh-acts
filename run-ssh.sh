ENV="${ENV:-.env}"
export $(grep -v '^#' "$ENV" | xargs)

sshpass -f $SSH_PASS_FILE \
  ssh -tt -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  $SSH_USER@$SSH_ADDR \
  tmux new-session -A -s opencode_session
