const IPA_URL =
  "https://api.codemagic.io/artifacts/.eJwVwdtyQ0AAANB_yfvOuIfHZRd1abJUyr4YwlLEJe79-k7PuVTwnz61tuR1wzJRks3SC9r8LO3RLcDNGDg4LfWSZlXtYwyprooGrySFWB3PZLKvzw2w3Ix52VBjfxEClxXnYzWNsxbVZHr3rMC8Mza9atWfbcyxxw8SBl0nBvJgbbhgf5kJ952m81fDeSOwWHtsFGVhvcpyrt1UieTsxA5sXPE4Io4Hvv6-x-vuXSOyBaWa7PfOx9BHycyWgA1Es0KK6EdGogbJFsZKhuwdC5lCgWZE_eiFc7jLy1EsGBJw2r-zlNcm6PrLH6gMWGQ.TVoVv0xnNq7u43jx6kSZzCtC0vY";

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
        <string>7</string>
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
