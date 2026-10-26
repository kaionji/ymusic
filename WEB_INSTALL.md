# Веб-версия для iPhone (без подписи Apple, без 7 дней)

Схема: приложение собирается в облаке GitHub и публикуется на GitHub Pages
(`https://kaionji.github.io/ymusic/`). На iPhone его открывают в Safari и добавляют на экран "Домой".
Запросы к Яндексу идут через маленького посредника на Cloudflare Workers (`proxy/worker.js`),
потому что браузер не разрешает страницам обращаться к API Яндекса напрямую.

Что нужно: аккаунт GitHub (есть), бесплатный аккаунт Cloudflare, Node.js.

Команды (PowerShell, из папки проекта):

```
winget install OpenJS.NodeJS.LTS            # затем открыть новое окно PowerShell
cd C:\dev\ymusic_app\proxy
npx wrangler login                          # откроется браузер: войти в Cloudflare и разрешить доступ
npx wrangler deploy                         # выведет адрес вида https://ymusic-proxy.XXXX.workers.dev
cd ..
gh variable set API_BASE --body "https://ymusic-proxy.XXXX.workers.dev"   # без / на конце
gh api -X POST repos/kaionji/ymusic/pages -f build_type=workflow
git add .
git commit -m "Web version"
git push
gh workflow run web.yml
gh run watch
```

Потом на iPhone: Safari -> https://kaionji.github.io/ymusic/ -> кнопка "Поделиться" -> "На экран «Домой»".

Ограничения: громкость регулируется кнопками телефона (ползунок в Safari не работает); работа при заблокированном экране
зависит от iOS; веб-версия рассчитана на Safari на iPhone.
