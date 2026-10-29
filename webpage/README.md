# Asla Intervals – support site

Static support and privacy pages for the Asla Intervals iOS app, served by GitHub Pages from the `webpage` branch.

| File | Purpose |
|---|---|
| `index.html` | Support page: live workout-screen preview, topics, screenshots, FAQ, contact |
| `privacy.html` | Privacy Policy (use as the App Store Connect *Privacy Policy URL*) |
| `style.css` | Design tokens (app colors, light/dark), layout |
| `script.js` | Countdown preview, color swatches, appearance toggle, scroll reveal |
| `assets/` | App icon (SVG/PNG) and App Store screenshots (WebP) |
| `.nojekyll` | Serve files as-is, no Jekyll build |

## Preview locally

```sh
python3 -m http.server 8000
# open http://localhost:8000
```

## Publish

*Settings → Pages → Build and deployment → Deploy from a branch → `webpage` / `(root)`*.
The site is then at `https://<owner>.github.io/<repo>/`.

Contact: postmaster@asla.no
