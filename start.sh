br=$(git branch --show-current)
git checkout run-trigger && git fetch -p && git rebase origin/main || exit 1

FILE="runs-counter"

num=$(cat "$FILE" | tr -d '[:space:]' || 0) && num=$((num + 1)) && echo "$num" > "$FILE" | exit 1

git add runs-counter || exit 1

if [ "$num" -eq 1 ]; then
    git commit -m "Add runs counter" && git push || exit 1
else
    git commit --amend --no-edit && git push -f || exit 1
fi

git checkout $br
