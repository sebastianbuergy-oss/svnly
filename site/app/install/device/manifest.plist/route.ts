const IPA_URL =
  "https://api.codemagic.io/artifacts/.eJwVwduSQzAAANB_6bsZKy7NYxW7bq1LEF4M3bq0ikpI4-t39pxDe_qnv_skarqEyFXREjM49zUq1N6-UiudBwEOcR57Y-lc2Yhz12iINslofn5fdlMmSpb5CcrWGCaovjnC6BTbPh-VNvOEmSzrVLrATXHKLL3ExvjTaABWziXkskV_3aGUufGmz2ATP1rtWF4ZLsGI2ReSZi5ENmiw0bNpi0wiVTNURKz7gKNj73OQnGJmdIoXQcQzKhoI7qfPhxUNzbu7z1XwCBEltZRuA1fx7pYgep_PlGg9FO4vexWZ7Tykl7bdApwGy-EPHuVbNw.T0QhTXshiAvxcMcMmSuYUz5w3c8";

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
        <string>1.0.0</string>
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
