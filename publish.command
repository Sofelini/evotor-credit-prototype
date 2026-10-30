#!/bin/bash
# Публикует прототип на GitHub Pages.
# Запуск: откройте Терминал, напечатайте  bash  и пробел,
# перетащите этот файл в окно Терминала и нажмите Enter.

set -u
REPO="evotor-credit-prototype"
GH_VERSION="2.62.0"
cd "$(dirname "$0")" || exit 1

say()  { printf "\n\033[1m%s\033[0m\n" "$1"; }
fail() { printf "\n\033[31m%s\033[0m\n" "$1"; exit 1; }

say "1/5 · Проверяю инструменты"
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install >/dev/null 2>&1
  fail "macOS предложит установить «Инструменты командной строки». Нажмите «Установить», дождитесь окончания и запустите этот скрипт ещё раз."
fi

if ! command -v gh >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    brew install gh || fail "Не получилось установить GitHub CLI через Homebrew."
  else
    echo "Скачиваю GitHub CLI ${GH_VERSION}. Mac попросит пароль от компьютера — это нормально."
    PKG="/tmp/gh_${GH_VERSION}.pkg"
    curl -fL --progress-bar -o "$PKG" \
      "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_macOS_universal.pkg" \
      || fail "Не получилось скачать GitHub CLI. Проверьте интернет и запустите скрипт ещё раз."
    sudo installer -pkg "$PKG" -target / >/dev/null || fail "Установка GitHub CLI не завершилась."
    rm -f "$PKG"
    export PATH="/usr/local/bin:$PATH"
  fi
fi
command -v gh >/dev/null 2>&1 || fail "GitHub CLI не найден после установки. Закройте Терминал, откройте заново и повторите."

say "2/5 · Вход в GitHub"
if ! gh auth status >/dev/null 2>&1; then
  echo "Сейчас появится одноразовый код. Нажмите Enter — откроется браузер,"
  echo "вставьте код и подтвердите доступ. Если аккаунта нет, там же можно зарегистрироваться."
  gh auth login --hostname github.com --git-protocol https --web || fail "Вход в GitHub не завершён."
fi
gh auth setup-git >/dev/null 2>&1
OWNER="$(gh api user --jq .login)" || fail "Не получилось узнать ваш логин GitHub."
echo "Вы вошли как ${OWNER}."

say "3/5 · Готовлю файлы"
if [ ! -d .git ]; then
  git init -q -b main
fi
git config user.name  "$OWNER"
git config user.email "${OWNER}@users.noreply.github.com"
git add index.html README.md .nojekyll publish.command
git commit -q -m "Прототип: кредит для бизнеса в приложении Эвотор" 2>/dev/null || true

say "4/5 · Загружаю на GitHub"
if gh repo view "${OWNER}/${REPO}" >/dev/null 2>&1; then
  git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/${OWNER}/${REPO}.git"
  git push -q -u origin main --force || fail "Не получилось отправить файлы."
  echo "Репозиторий уже был — обновила файлы."
else
  gh repo create "${OWNER}/${REPO}" --public --source=. --remote=origin --push \
    --description "Кликабельный прототип: кредит для бизнеса в приложении Эвотор" \
    || fail "Не получилось создать репозиторий."
fi

say "5/5 · Включаю GitHub Pages"
if ! gh api "repos/${OWNER}/${REPO}/pages" >/dev/null 2>&1; then
  gh api -X POST "repos/${OWNER}/${REPO}/pages" \
    -f "source[branch]=main" -f "source[path]=/" >/dev/null \
    || fail "Не получилось включить Pages. Откройте Settings → Pages в репозитории и выберите ветку main."
fi

URL="https://${OWNER}.github.io/${REPO}/"
echo "Жду, пока GitHub соберёт страницу (обычно 1–2 минуты)…"
for _ in $(seq 1 36); do
  STATUS="$(gh api "repos/${OWNER}/${REPO}/pages" --jq .status 2>/dev/null)"
  [ "$STATUS" = "built" ] && break
  sleep 5
done

say "Готово. Ссылка для клиента:"
printf "\n    %s\n\n" "$URL"
[ "${STATUS:-}" = "built" ] || echo "Если страница пока показывает 404, подождите пару минут и обновите."
echo "$URL" | pbcopy 2>/dev/null && echo "Ссылка уже скопирована — можно вставить в письмо."
open "$URL" 2>/dev/null
