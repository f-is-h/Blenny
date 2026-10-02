// Download links: the HTML points at the GitHub Releases page, which always
// works. Once the latest release is known, the links become that release's disk
// image, which GitHub serves as an attachment: the download starts and the
// visitor stays on the page. The answer is kept for the session.

const API = 'https://api.github.com/repos/f-is-h/Blenny/releases/latest';
const KEY = 'blenny-latest-dmg';

export const latestDownload = { url: null };

export async function resolveDownloads() {
  let url = null;
  try { url = sessionStorage.getItem(KEY); } catch { /* storage unavailable */ }
  if (!url) {
    try {
      const res = await fetch(API, { headers: { Accept: 'application/vnd.github+json' } });
      if (!res.ok) return;
      const release = await res.json();
      url = release.assets?.find((a) => a.name.endsWith('.dmg'))?.browser_download_url ?? null;
    } catch { return; }
    if (!url) return;
    try { sessionStorage.setItem(KEY, url); } catch { /* storage unavailable */ }
  }
  latestDownload.url = url;
  document.querySelectorAll('[data-download]').forEach((a) => { a.href = url; });
}
