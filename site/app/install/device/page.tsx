import type { Metadata } from "next";
import { Footer, Mark, Nav } from "../../shared";

const installUrl =
  "itms-services://?action=download-manifest&url=https%3A%2F%2Fsvnly.sebastian-buergy.chatgpt.site%2Finstall%2Fdevice%2Fmanifest.plist";

export const metadata: Metadata = {
  title: "Direkter iPhone-Test",
  description: "SVNLY direkt auf einem registrierten iPhone installieren.",
  robots: { index: false, follow: false },
};

export default function DeviceInstallPage() {
  return (
    <main>
      <Nav />
      <section className="device-install">
        <div className="device-install__copy">
          <p className="eyebrow">PRIVATE AD HOC BUILD · REGISTERED DEVICES ONLY</p>
          <h1>SVNLY<br /><span>ON IPHONE.</span></h1>
          <p className="lede">
            Open this page in Safari on the registered iPhone, tap Install SVNLY,
            and confirm the system installation prompt.
          </p>
          <a className="cta" href={installUrl}>INSTALL SVNLY <b>↓</b></a>
          <div className="device-install__qr">
            <img
              src="/install/svnly-device-qr.png"
              alt="QR code for the SVNLY iPhone installation page"
              width="220"
              height="220"
            />
            <p>SCAN WITH THE REGISTERED IPHONE</p>
          </div>
          <div className="install-notes">
            <p><strong>Build:</strong> 1.0.0 · Codemagic build 7 · Ad Hoc · signed by Apple Distribution</p>
            <p><strong>Availability:</strong> The secured build link expires September 5, 2026.</p>
            <p><strong>Requirement:</strong> Installation works only on iPhones included in the provisioning profile.</p>
          </div>
        </div>
        <div className="device-install__mark" aria-label="SVNLY seven play mark"><Mark /></div>
      </section>
      <Footer />
    </main>
  );
}
