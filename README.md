# iftar-ramadhan
# Dev Build
ionic capacitor add android 
ionic capacitor copy android && cd android && ./gradlew assembleDebug && cd ..
Then your apk will be at:

android/app/build/outputs/apk/debug/app-debug.apk
If you want to run on device directly from command line:

ionic capacitor copy android && cd android && ./gradlew assembleDebug && ./gradlew installDebug && cd ..
Note: It doesn’t work without entering the android directory

# Prod Build
cd android && 
./gradlew assembleRelease && 
cd app/build/outputs/apk/release &&
jarsigner -keystore YOUR_KEYSTORE_PATH -storepass YOUR_KEYSTORE_PASS app-release-unsigned.apk YOUR_KEYSTORE_ALIAS &&
zipalign 4 app-release-unsigned.apk app-release.apk

إفطار صائم