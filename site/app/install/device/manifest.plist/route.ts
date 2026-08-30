const IPA_URL =
  "https://api.codemagic.io/artifacts/.eJwVwclygjAAANB_8c6MEEAuHqBEQwSDlCJw6bA0skTKmgBf3-l7h5f5zxqYhfW-d2MeAIdON_Bp7Mgx7bGC09qQQsXXLD9Z6eN1SSVU8PJYyjO3m1adnBbbJGK31ayybXgWvlKv9_xrldWQCM6TYBfy4uIIZt1cWP5OXaGAcQjh2_MGORcPd6HLzX0ZxlaQ3ED6kokYjf73gJhfV-LHuVM2tyYGUTxoVQc7p60T3-0kbY1SoQRXoJM4qFliIvO9iy1NIe0b2IeO0abEU7PCZzBBWs0_BO70EpNqMfLnJAdgvvDwuFK1g6G0t2UTS5RnMuvV-fQ8gl-SX9DjfD78Aa_eY_A.dFYDzSL3ajvqGLEP3dKDpbqO85w";

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
        <string>11</string>
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
