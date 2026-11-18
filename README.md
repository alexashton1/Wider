# Wider — launch kit

Everything here is a static site. It costs nothing to host.

## 1. Put it online (GitHub Pages, ~5 minutes)
1. Create a new public GitHub repo (e.g. `wider`) and upload every file in this folder.
2. In the repo, go to **Settings → Pages**, set the source to the `main` branch with the `/ (root)` folder, and save.
3. It goes live at `https://<your-username>.github.io/wider/`.

## 2. Your own domain (recommended before you share it widely)
1. Buy a short domain (e.g. wider.games / playwider.com). Check the name isn't trademarked for games in the UK, the US and the EU first.
2. In **Settings → Pages → Custom domain**, enter the domain. GitHub creates a `CNAME` file for you.
3. At your registrar (GoDaddy works, as with tigerdle.com), add the DNS records GitHub shows you, then tick **Enforce HTTPS**.
4. **Find and replace `https://YOUR-DOMAIN` in `index.html`** with your real address (it appears 4 times). This is what makes WhatsApp, X, iMessage and Slack show the preview card (`og.png`) when someone pastes the link.
   - Test it: paste the link into https://www.opengraph.xyz, or into a WhatsApp chat with yourself.

## 3. Turn on "How everyone did" (Supabase free tier, ~5 minutes)
1. Create a new Supabase project.
2. Open **SQL Editor**, paste in `supabase.sql` and run it.
3. Go to **Project Settings → API** and copy the **Project URL** and the **anon public** key.
4. In `index.html`, find `const SUPABASE = {url: '', anonKey: ''};` and paste those two values in.

The anon key is safe to publish. The database only lets people add one result per player per day, and only the per-day totals can be read back. Individual rows can't be read. No personal data is stored: each result is just a puzzle number, a random ID and a zoom score.

## 4. When you update the game
- If you change `geo.js` or `data.js`, change `VERSION` in `sw.js` (e.g. `wider-v3`). Otherwise phones that have installed the game keep the old copy.
- The game puts out one country a day automatically. You never need to add puzzles by hand.

## Files
| File | What it is |
|---|---|
| index.html | The game |
| geo.js | Map maths (d3-geo + topojson, MIT/ISC licences) |
| data.js | Borders (Natural Earth 1:50m, public domain) + country facts (world-countries, ODbL — keep the credit in Settings → About) |
| og.png | 1200×630 preview card for social links |
| manifest.webmanifest, icon-*.png, apple-touch-icon.png, favicon.svg | Install-to-home-screen and app icons |
| sw.js | Offline support + fast repeat loads |
| supabase.sql | Database setup for the global results |
