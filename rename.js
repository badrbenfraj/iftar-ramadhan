var fs = require("fs");
fs.rename(
  "/Users/badrbenfraj/projects/iftar-ramadhan/android/app/build/outputs/apk/debug/app-debug.apk",
  "/Users/badrbenfraj/projects/iftar-ramadhan/android/app/build/outputs/apk/debug/إفطار صائم.apk",
  function (err) {
    if (err) console.log("ERROR: " + err);
  }
);
