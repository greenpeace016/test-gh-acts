set -euo pipefail

ENV="${ENV:-.env}"
export $(grep -v '^#' "$ENV" | xargs)

REPO="${REPO:-$(git remote get-url origin)}"

br=$(git branch --show-current)

git stash && git stash apply || true

git branch -f sync && \
  git checkout sync && \
  (git commit -am sync-commit || true) && \
  (git push -f || git push -f --set-upstream origin sync)

git checkout $br && git stash pop || true

CMD="(cd $SSH_PROJECT_PATH || git clone $REPO $SSH_PROJECT_PATH || exit 1) && cd $SSH_PROJECT_PATH && git checkout ${GIT_BR:-main} && (git branch -D sync || true) && git fetch -p && git checkout sync" ./run-ssh.sh
