import Link from "next/link";

export function Mark() {
  return <div className="mark"><i /><span /></div>;
}

export function Wordmark() {
  return <span className="wordmark" aria-label="SVNLY">S<strong>V</strong>NLY</span>;
}

export function Nav() {
  return <header className="nav"><Link href="/"><Wordmark /></Link><nav aria-label="Primary"><Link href="/#how">HOW IT WORKS</Link><Link href="/community">COMMUNITY</Link><Link href="/support">SUPPORT</Link></nav><span className="platform">iPHONE · 16+</span></header>;
}

export function Footer() {
  return <footer><Wordmark /><p>© 2026 SVNLY. Be real.</p><nav aria-label="Legal"><Link href="/privacy">Privacy</Link><Link href="/terms">Terms</Link><Link href="/community">Community</Link><Link href="/support">Support</Link><Link href="/account-deletion">Delete account</Link></nav></footer>;
}

export function LegalPage({ eyebrow, title, updated, children }: { eyebrow: string; title: string; updated: string; children: React.ReactNode }) {
  return <main><Nav /><article className="legal"><p className="eyebrow">{eyebrow}</p><h1>{title}</h1><p className="updated">Last updated · {updated} · English followed by Deutsch</p>{children}</article><Footer /></main>;
}
