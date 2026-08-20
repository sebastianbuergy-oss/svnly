import { Footer, Mark, Nav } from "./shared";

export default function Home() {
  return (
    <main>
      <Nav />
      <section className="hero">
        <div className="hero-copy">
          <p className="eyebrow">ONE CHALLENGE · EVERY DAY</p>
          <h1><span>7 seconds.</span><br />One take.<br />Be real.</h1>
          <p className="lede">Everyone gets the same prompt. Everyone gets seven seconds. Everyone gets one take.</p>
          <div className="rule-row"><span>7 SECONDS</span><span>1 TAKE</span><span>NO UPLOADS</span><span>NO EDITS</span></div>
          <a className="cta" href="#how">SEE HOW IT WORKS <b>↘</b></a>
        </div>
        <div className="hero-mark" aria-label="SVNLY seven play mark"><Mark /></div>
      </section>

      <section className="ticker" aria-hidden="true"><span>BE REAL · ONE TAKE · EVERY DAY · BE REAL · ONE TAKE · EVERY DAY ·</span></section>

      <section id="how" className="section steps">
        <p className="eyebrow">THE RULE IS THE PRODUCT</p>
        <h2>Same prompt.<br /><em>Same chance.</em></h2>
        <div className="step-grid">
          <article><b>01</b><h3>See today’s challenge</h3><p>One safe, global prompt runs from 00:00 to 23:59 UTC.</p></article>
          <article><b>02</b><h3>Take your seven seconds</h3><p>Choose a live look, then 3–2–1. Recording starts and stops automatically.</p></article>
          <article><b>03</b><h3>Unlock the world</h3><p>Your Friends, Country and World feeds open only after you participate.</p></article>
        </div>
      </section>

      <section className="section split">
        <div><p className="eyebrow">NO PERFORMANCE</p><h2>Made for<br /><em>actual moments.</em></h2></div>
        <div className="manifesto"><p>No gallery import.</p><p>No trimming.</p><p>No beauty filters.</p><p>No voluntary retakes.</p><small>A retry is offered only after a verified technical failure and never to improve a take.</small></div>
      </section>

      <section className="section safety">
        <p className="eyebrow">REAL ALSO MEANS SAFE</p>
        <div className="safety-grid">
          <h2>Built for people,<br />not engagement at any cost.</h2>
          <div><p>Private video storage and short-lived access links.</p><p>Report, block and account deletion inside the app.</p><p>Automated checks plus human moderation and appeals.</p><p>No GPS, contact uploads, ad tracking or biometric face data.</p></div>
        </div>
      </section>

      <section className="closing"><Mark /><h2>YOUR SEVEN SECONDS<br />ARE WAITING.</h2><p>SVNLY for iPhone · German and English</p></section>
      <Footer />
    </main>
  );
}
