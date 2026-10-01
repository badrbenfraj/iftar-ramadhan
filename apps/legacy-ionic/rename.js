const { rename } = require("fs").promises;
const { resolve } = require("path");

async function renameApk() {
  const outputDir = "android/app/build/outputs/apk/debug";
  const [currentPath, newPath] = ["app-debug.apk", "إفطار صائم.apk"].map(
    (file) => resolve(outputDir, file)
  );

  try {
    await rename(currentPath, newPath);
    console.log("APK renamed successfully.");
  } catch (err) {
    console.error("ERROR:", err);
  }
}

renameApk();
