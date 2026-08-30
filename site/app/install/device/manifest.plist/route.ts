const IPA_URL =
  "https://api.codemagic.io/artifacts/.eJwVwclygjAYAOB38c5MtLLk4EHWQiE0GNkuHbZC4FeQRZSn7_T7dvX5n_qAM49EM3SMJkJlXkmQFWNGpR5XxassN6v7oKmGe6zIwpzvlTpQQ_lSuiyIBsja9Urc5owBt0Y4eia5EtO1Awm6I4EJ3b9cgAKN7HbIeicVkgQZhG3tqjBr2PzAYRo-omk5PMDPZR_Bc71HoitTy97PdVd8Dk4mDItjino4Q0zS3tPs5sew-0TwPORj6-2l5rSsEnJa2nI1zDaWdww3vE6351QsaUJdm8bxAByPQRUFJAJ1Zlwfnu9fzaz0fXzVmW6NL4tdRFn51ri4ID55tzc9nXZ_5Mlh8Q.fMhxJJKrLdbQkhsmcLHZqfUPL-g";

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
        <string>10</string>
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
