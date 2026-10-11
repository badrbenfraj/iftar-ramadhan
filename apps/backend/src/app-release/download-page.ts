import { AppVersionOutput } from './app-version-output.dto';

const escapeHtml = (s: string): string =>
  s.replace(
    /[&<>"']/g,
    (c) =>
      ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[
        c
      ],
  );

/**
 * A single self-contained, mobile-friendly page (no framework, no external
 * assets), in the app's night-sky colours and its three languages.
 */
export function renderDownloadPage(info: AppVersionOutput): string {
  const version = info.latestVersion ? escapeHtml(info.latestVersion) : null;
  const body = version
    ? `
    <p class="version">Version ${version}</p>
    <a class="button" href="${escapeHtml(info.downloadUrl)}" download>
      Download Android app<br><span>تحميل التطبيق · Télécharger l'application</span>
    </a>
    <section class="note">
      <h2>Installation note</h2>
      <p>If Android asks for permission to install apps from this source, allow
      the browser (or file manager) to install apps, then open the downloaded
      file again.</p>
      <p dir="rtl" lang="ar">إذا طلب أندرويد الإذن بتثبيت تطبيقات من هذا المصدر، اسمح للمتصفّح (أو مدير الملفات) بالتثبيت ثم افتح الملف الذي تم تنزيله مرة أخرى.</p>
      <p lang="fr">Si Android demande l'autorisation d'installer des applications
      depuis cette source, autorisez le navigateur (ou le gestionnaire de
      fichiers), puis rouvrez le fichier téléchargé.</p>
    </section>
    ${info.sha256 ? `<p class="sha">SHA-256: ${escapeHtml(info.sha256)}</p>` : ''}`
    : `
    <p class="version">No version has been published yet.<br>
    <span dir="rtl" lang="ar">لم يُنشر أي إصدار بعد.</span><br>
    <span lang="fr">Aucune version publiée pour l'instant.</span></p>`;

  // No APK on iPhones: they use the web version, served by Caddy at /app/.
  const iphone = `
    <a class="button secondary" href="/app/">
      Open on iPhone<br><span>فتح على iPhone · Ouvrir sur iPhone</span>
    </a>
    <section class="note">
      <h2>iPhone</h2>
      <p>Open the link in Safari, then tap Share › Add to Home Screen.</p>
      <p dir="rtl" lang="ar">افتح الرابط في Safari، ثم اضغط مشاركة › إضافة إلى الشاشة الرئيسية.</p>
      <p lang="fr">Ouvrez le lien dans Safari, puis touchez Partager › Sur l'écran d'accueil.</p>
    </section>`;

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>إفطار صائم · Iftar Saim</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body {
    margin: 0; min-height: 100vh; padding: 32px 16px;
    font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
    background: linear-gradient(#0E1530, #121A3A 45%, #3A3566);
    color: #F3EBDD; text-align: center; line-height: 1.5;
  }
  main { max-width: 420px; margin: 0 auto; }
  h1 { color: #D6A645; font-size: 34px; margin: 8px 0 0; font-weight: 600; }
  .sub { color: #A8AEC8; margin: 0 0 28px; }
  .version { font-size: 18px; margin: 0 0 20px; }
  .button {
    display: block; padding: 16px; border-radius: 28px;
    background: #43CEBB; color: #121A3A; text-decoration: none;
    font-size: 18px; font-weight: 600;
  }
  .button span { font-size: 14px; font-weight: 500; }
  .button.secondary {
    margin-top: 28px; background: transparent; color: #43CEBB;
    border: 2px solid #43CEBB;
  }
  .note {
    margin-top: 28px; padding: 16px; border-radius: 16px; text-align: start;
    background: rgba(243, 235, 221, 0.08); font-size: 14px;
  }
  .note h2 { color: #D6A645; font-size: 15px; margin: 0 0 8px; }
  .note p { margin: 0 0 10px; }
  .sha { margin-top: 24px; color: #A8AEC8; font-size: 11px; word-break: break-all; }
</style>
</head>
<body>
<main>
  <h1>إفطار صائم</h1>
  <p class="sub">Iftar Saim · Ramadan volunteer app</p>
  ${body}
  ${iphone}
</main>
</body>
</html>
`;
}
