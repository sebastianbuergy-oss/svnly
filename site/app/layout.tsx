import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "SVNLY — 7 seconds. One take. Be real.",
    template: "%s · SVNLY",
  },
  description: "One global challenge every day. Record seven seconds in one take before the feed unlocks.",
  icons: {
    icon: "/icon.png",
    apple: "/icon.png",
  },
  openGraph: {
    title: "SVNLY — 7 seconds. One take. Be real.",
    description: "One global challenge every day. No uploads. No edits. No voluntary retakes.",
    type: "website",
    images: [{ url: "/og.png", width: 1200, height: 630, alt: "SVNLY — 7 seconds. One take. Be real." }],
  },
  twitter: {
    card: "summary_large_image",
    title: "SVNLY — 7 seconds. One take. Be real.",
    description: "One global challenge every day. No uploads. No edits.",
    images: ["/og.png"],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
