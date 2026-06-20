# PushApp SDK — HTML documentation

Static documentation shell for the Flutter SDK (`mehery_sender`).

## Live URL (primary)

**https://docs.mehery.com/guide/pushapp/flutter-sdk/**

Hosted on the [MeherY documentation](https://docs.mehery.com/guide/pushapp/) site. Content is loaded from this repository via GitHub raw URLs — edit markdown in the repo root and refresh the site.

## Mirror (GitHub Pages)

This repo’s `/docs` folder can also be published as a GitHub Pages project site:

**https://mehery-soccom.github.io/PushApp-Flutter/**

Use the MeherY URL above for pub.dev, README links, and customer-facing docs.

## View locally

From the **repository root**:

```bash
python3 -m http.server 8080
```

Open [http://localhost:8080/docs/](http://localhost:8080/docs/) — markdown is fetched from GitHub raw (same as production).

## GitHub Pages setup (optional mirror)

- **Source:** Deploy from branch `main`, folder **`/docs`**
- **Custom domain:** leave empty (avoid conflicting with `docs.mehery.com`)
- Include **`.nojekyll`** so assets are not processed by Jekyll

## Structure

| Path | Purpose |
|------|---------|
| `index.html` | Shell, sidebar, CDN scripts |
| `css/docs.css` | PushApp theme |
| `js/docs.js` | Markdown fetch, routing, syntax highlight |
| `assets/pushapp-logo.png` | Brand logo |
| `.nojekyll` | Disable Jekyll on GitHub Pages |

## pub.dev

Set `documentation` in `pubspec.yaml` to:

`https://docs.mehery.com/guide/pushapp/flutter-sdk/`
