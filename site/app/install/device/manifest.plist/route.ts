const IPA_URL =
  "https://svnly.sebastian-buergy.chatgpt.site/install/SVNLY-build-13.ipa";

const manifest = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>items</key>
  <array>
    <dict>
      <key>assets</key>
      <array>
        <dict>
          <key>kind</key>
          <string>software-package</string>
          <key>url</key>
          <string>${IPA_URL}</string>
        </dict>
        <dict>
          <key>kind</key>
          <string>display-image</string>
          <key>needs-shine</key>
          <false/>
          <key>url</key>
          <string>https://svnly.sebastian-buergy.chatgpt.site/icon.png</string>
        </dict>
        <dict>
          <key>kind</key>
          <string>full-size-image</string>
          <key>needs-shine</key>
          <false/>
          <key>url</key>
          <string>https://svnly.sebastian-buergy.chatgpt.site/icon.png</string>
        </dict>
      </array>
      <key>metadata</key>
      <dict>
        <key>bundle-identifier</key>
        <string>ch.sebastianbuergy.svnly</string>
        <key>bundle-version</key>
        <string>13</string>
        <key>kind</key>
        <string>software</string>
        <key>platform-identifier</key>
        <string>com.apple.platform.iphoneos</string>
        <key>title</key>
        <string>SVNLY</string>
      </dict>
    </dict>
  </array>
</dict>
</plist>`;

export async function GET() {
  return new Response(manifest, {
    headers: {
      "Cache-Control": "no-store",
      "Content-Type": "application/xml; charset=utf-8",
    },
  });
}
