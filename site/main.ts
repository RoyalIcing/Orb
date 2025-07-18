import { CSS, render } from "jsr:@deno/gfm@0.6";
import "npm:prismjs@1.29.0/components/prism-elixir.js";

import {
  fetchGitHubRepoRefs,
  findHEADInRefs,
  fetchGitHubRepoContent,
} from "jsr:@collected/github-fetch";

const ownerName = "RoyalIcing";
const repoName = "Orb";

const refs = await fetchGitHubRepoRefs(ownerName, repoName);
const headRef = findHEADInRefs(refs());
if (!headRef) throw Error("No Git HEAD to be found.");
const { sha } = headRef;

async function getContentMarkdown(path: string): Promise<string> {
  const res = await fetchGitHubRepoContent(ownerName, repoName, sha, "site/" + path + ".md")
  return await res.text();
}
async function getContentHTML(path: string): Promise<string> {
  const markdown = await getContentMarkdown(path);
  // https://deno.land/x/gfm@0.6.0/mod.ts?s=RenderOptions
  return render(markdown, {
    allowedAttributes: { details: ["data-path"] }
  });
}
async function getExampleWasm(path: string): Promise<string> {
  const res = await fetchGitHubRepoContent(ownerName, repoName, sha, "examples/" + path + ".wasm")
  const wasm = await res.arrayBuffer();
  return wasm;
  // return WebAssembly.compile(wasm);
}

const notFoundMd = getContentMarkdown("404");
const navHTML = getContentHTML("_nav");
const footerHTML = getContentHTML("_footer");
const cache = new Map<string, Promise<string>>();

function getContentPath(path: `/${string}`): undefined | string {
  if (!path.startsWith("/")) {
    return undefined;
  }

  const subpath = path.slice(1);

  switch (subpath) {
    case "": return "readme";
    case "install": return subpath;
    case "concepts/core-webassembly": return subpath;
    case "concepts/elixir-compiler": return subpath;
    case "concepts/strings": return subpath;
    case "concepts/composable-modules": return subpath;
    case "concepts/custom-types": return subpath;
    case "concepts/platform-agnostic": return subpath;
    case "run/elixir": return subpath;
    case "run/javascript": return subpath;
    case "silverorb": return "silverorb/silverorb";
    case "silverorb/parse": return subpath;
    case "silverorb/format": return subpath;
    default: return undefined;
  }
}

async function getMarkdownForRequest(req: Request): Promise<string> {
  const { pathname, searchParams } = new URL(req.url);

  if (pathname === "/search") {
    let query = searchParams.get("q") ?? ""
    query = query.trim().replace(/[\n\r\t]/g, ' ').replace(/[ ]+/g, ' ')
    const queryAttribute = query.replace(/"/g, '&quot;')
    let results: Array<string> = []
    if (query === "github") {
      results.push("https://github.com/RoyalIcing/Orb", "https://github.com/RoyalIcing/SilverOrb")
    }
    if (query === "spec" || query === "specs") {
      results.push("https://webassembly.org/specs/", "https://www.w3.org/TR/wasm-core-1/", "https://github.com/WebAssembly/WASI/blob/main/Proposals.md")
    }
    return `<form action=/search><input placeholder="Search" name=q value="${queryAttribute}" style="margin-bottom: 1rem"></form>` + "\n\n" + results.map(result => "- " + result).join("\n");
  }

  const cachedHTML = cache.get(pathname);
  if (cachedHTML) return cachedHTML;

  const contentPath = getContentPath(pathname);
  if (contentPath === undefined) return notFoundMd;

  const content = getContentMarkdown(contentPath);
  cache.set(contentPath, content);

  return await content;
}

Deno.serve(async (req: Request) => {
  const markdown = await getMarkdownForRequest(req);
  const body = render(markdown, {
    disableHtmlSanitization: true
  });

  const { pathname } = new URL(req.url);

  if (pathname === "/favicon.ico") {
    return new Response(`<svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
  <rect width="100" height="100" fill="#74d1f0" />
</svg>`, {
        headers: {
          "content-type": "image/svg+xml"
        }
      });
  }

  if (pathname.startsWith("/wasm/")) {
    const name = pathname.replace("/wasm/", "");
    const wasmBytes = await getExampleWasm(name);
    return new Response(wasmBytes, {
      headers: {
        "content-type": "application/wasm"
      }
    });
  }

  const html = `
<!DOCTYPE html>
<html lang=en data-path="${pathname.replace('"', '')}">
<meta charset=utf-8>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="mask-icon" href="/favicon.ico" color="#74d1f0">
<script src="https://cdn.usefathom.com/script.js" data-site="EFBQOFQL" defer></script>
<link rel=stylesheet href="https://rsms.me/inter/inter.css">
<title>Orb: Write WebAssembly with Elixir</title>
<style>
@view-transition { navigation: auto }
input[OFF] { view-transition-name: input }
</style>
<style>
:root {
  font-family: Inter,-apple-system,BlinkMacSystemFont,"Segoe UI","Noto Sans",Helvetica,Arial,sans-serif,"Apple Color Emoji","Segoe UI Emoji";
}

* {
  justify-content: var(--justify-content, initial);
}

a {
  display: var(--link-display, initial);
  padding: var(--link-padding);
  color: var(--color-accent-fg);
}
ul, ol {
  display: var(--list-display, block);
  margin: var(--list-margin, 0);
  padding: var(--list-padding, 0);
  flex-wrap: wrap;
}
li {
  list-style: var(--list-item-style);
}

body {
  min-height: 100vh;
  line-height: 1.5;
  max-width: 1232px;
  margin: auto;
  display: grid;
  grid-template-areas:
    "nav"
    "main"
    "footer";
  background-color: var(--color-canvas-default);
}

main {
  width: 100%;
  grid-area: main;
  max-width: 48rem;
  margin: 0 auto;
  padding: 3rem 1.5vw;
  line-height: 1.75;
  --list-padding: 0 0 0 1em;
}

nav {
  overflow: auto;
  position: sticky;
  top: 0;
  /*min-width: max-content;*/
  max-width: 100vw;
  display: flex;
  flex-direction: column;
  flex-wrap: wrap;
  text-align: center;
  gap: 1rem;
  padding-left: 1.5vw;
  padding-right: 1.5vw;
  padding-bottom: 2rem;
  background-color: var(--color-canvas-default);
  color: var(--color-fg-default);
  -webkit-user-select: none;
  user-select: none;

  --link-display: inline-block;
}
nav summary {
  padding-bottom: 0.25rem;
  cursor: pointer;
  user-select: none;
}
nav summary:hover {
}
nav ul {
  margin: 0;
  padding: 0;
}
nav li {
  list-style: none;
}
nav details {
  --link-padding: 0.125em 0;
}
nav a {
  text-decoration: none;
}
nav a:hover {
  text-decoration: underline;
}
nav a[href="/"] {
  font-size: 150%;
  text-decoration: none;
}

footer[role=contentinfo] {
  grid-area: footer;
  padding-top: 1rem;
  padding-bottom: 4rem;
  text-align: center;
  color: white;
  --list-display: flex;
  --justify-content: center;
  --list-item-style: none;
  --link-padding: 0 0.333em;
}

${CSS}

.markdown-body {
  font-size: 125%;
  line-height: 1.75;
  font-family: inherit;
}
.markdown-body h1 {
  font-size: 2.8em;
  font-weight: 800;
}
.markdown-body p, .markdown-body blockquote, .markdown-body ul, .markdown-body ol, .markdown-body dl, .markdown-body table, .markdown-body pre, .markdown-body details {
  margin-bottom: 1lh;
}
.markdown-body .highlight pre, .markdown-body pre {
  text-size-adjust: none;
  font-size: var(--pre-font-size, 0.75rem);
  white-space: pre-wrap;
  word-break: break-word;
  word-wrap: normal;
  overflow-x: auto;
}

/* Override theme */
[data-color-mode=light][data-light-theme=dark], [data-color-mode=dark][data-dark-theme=dark] {
  --color-canvas-default: #01142E;
  --color-accent-fg: #ffc900;
}
h1, h2, summary {
  color: #74d1f0;
}

form {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}
input { font-size: inherit; }

:root[data-path="/"] h1 {
  text-align: center;
  padding-bottom: 1em;
  font-size: 2em;
  font-style: italic;
  font-weight: 600;
  margin: 0;
  border-bottom: none;
}
:root[data-path="/"] h1 + ul {
  margin-bottom: 2rem;
  list-style: none;
  display: flex;
  justify-content: center;
  padding: 0;
  gap: 1rem;
}
:root[data-path="/"] h1 + ul li {
  margin-top: 0 !important;
}
:root[data-path="/"] h1 + ul a {
  border: solid 2px currentcolor;
  padding: 0.6rem 1rem;
  border-radius: 1000px;
}
:root[data-path="/"] h1 + ul a:hover {
  color: white;
  text-decoration: none;
  background: rgba(1.0 1.0 1.0 / 0.1)
}

@media (min-width: 900px) {
  :root {
    --pre-font-size: 1rem;
  }
  body {
    grid-template-areas:
      "nav main ."
      ". footer .";
  }
  nav {
    flex-direction: column;
    text-align: left;
    font-size: 125%;
  }
  nav details {
    --link-padding: 0.125em 0 0.125em 2rem;
  }
  :root[data-path="/"] h1 {
    padding-top: 1em;
    font-size: 3em;
  }
  :root[data-path="/"] h1 + ul {
    margin-bottom: 4rem;
    font-size: 125%;
  }
}

nav-primary details {
  opacity: 1;
  transition: opacity 0.2s ease-in-out;
}
nav-primary:defined details {
  opacity: 1;
}

</style>
<script type="module">
const breakpoints = { sm: "640px" };
const smMedia = window.matchMedia(\`(min-width: \${breakpoints.sm})\`);

const { path } = document.documentElement.dataset;

customElements.define("nav-primary", class NavPrimary extends HTMLElement {
  connectedCallback() {
    const isSm = smMedia.matches;
    this.querySelectorAll("details").forEach($details => {
      if (path !== "/" && typeof $details.dataset.path === "string" && path.startsWith($details.dataset.path)) {
        $details.open = true;
      }

      //$details.open = isSm;
    });
  }
});
</script>
<body data-color-mode="dark" data-light-theme="light" data-dark-theme="dark">

<nav-primary style="grid-area: nav">
<nav aria-label="Primary" style="min-width: 12em">
<a href="/">
  ${logoSVG}
</a>
${await navHTML}
</nav>
</nav-primary>

<main class="markdown-body">
${body}
</main>
<footer role=contentinfo>${await footerHTML}</footer>
`;
  return new Response(html, {
    headers: {
      "content-type": "text/html;charset=utf-8"
    }
  });
});

const logoSize = 174;
const logoSVG = `<svg height="${logoSize}" width="${logoSize}" viewBox="0 0 1080 1080" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"><title>Orb logo</title><filter id="a" color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse" height="1080" width="1080" x="0" y="0"><feGaussianBlur stdDeviation="0"></feGaussianBlur><feOffset dx="-21.650635" dy="12.5" result="offsetblur"></feOffset><feFlood flood-color="#ffcd39"></feFlood><feComposite in2="offsetblur" operator="in"></feComposite><feMerge><feMergeNode></feMergeNode><feMergeNode in="SourceGraphic"></feMergeNode></feMerge></filter><linearGradient id="b"><stop offset="0" stop-color="#ff8500"></stop><stop offset="1" stop-color="#ffc900"></stop></linearGradient><radialGradient id="c" cx="309.000021" cy="575.000012" gradientUnits="userSpaceOnUse" r="118.999979" xlink:href="#b"></radialGradient><radialGradient id="d" cx="234.499939" cy="600.499578" gradientTransform="matrix(.452138 -.891948 .891948 .452138 -407.140824 538.152997)" gradientUnits="userSpaceOnUse" r="60.888293" xlink:href="#b"></radialGradient><radialGradient id="e" cx="379.500172" cy="546.000623" gradientTransform="matrix(-.505209 .862997 -.862997 -.505209 1042.424008 494.337784)" gradientUnits="userSpaceOnUse" r="56.328758" xlink:href="#b"></radialGradient><radialGradient id="f" cx="332.499107" cy="648.49932" gradientTransform="matrix(-.535581 .844484 -.844484 -.535581 1058.226547 715.032818)" gradientUnits="userSpaceOnUse" r="32.782541" xlink:href="#b"></radialGradient><radialGradient id="g" cx="256.499112" cy="636.499283" gradientTransform="matrix(.995438 -.095414 .095414 .995438 -59.560455 27.377389)" gradientUnits="userSpaceOnUse" r="32.004128" xlink:href="#b"></radialGradient><radialGradient id="h" cx="228.000946" cy="562.999801" gradientTransform="matrix(-.557358 -.830272 .830272 -.557358 -112.364112 1066.095056)" gradientUnits="userSpaceOnUse" r="37.338804" xlink:href="#b"></radialGradient><radialGradient id="i" cx="274.001469" cy="496.500374" gradientTransform="matrix(-.430762 .902466 -.902466 -.430762 840.105363 463.096666)" gradientUnits="userSpaceOnUse" r="33.022791" xlink:href="#b"></radialGradient><radialGradient id="j" cx="357.500571" cy="509.000431" gradientTransform="matrix(.994031 -.109099 .109099 .994031 -53.397418 42.041183)" gradientUnits="userSpaceOnUse" r="39.966958" xlink:href="#b"></radialGradient><radialGradient id="k" cx="387.499342" cy="587.499976" gradientTransform="matrix(-.427359 -.904082 .904082 -.427359 21.952415 1188.904504)" gradientUnits="userSpaceOnUse" r="38.078508" xlink:href="#b"></radialGradient><radialGradient id="l" cx="314.499528" cy="500.500045" gradientTransform="matrix(.592448 .805608 -.805608 .592448 531.381828 -49.383866)" gradientUnits="userSpaceOnUse" r="52.731529" xlink:href="#b"></radialGradient><radialGradient id="m" cx="291.498387" cy="641.499598" gradientTransform="matrix(-.455561 -.890204 .890204 -.455561 -146.772023 1193.235125)" gradientUnits="userSpaceOnUse" r="55.676227" xlink:href="#b"></radialGradient><radialGradient id="n" cx="859.499899" cy="615.999941" gradientUnits="userSpaceOnUse" r="72.500101" xlink:href="#b"></radialGradient><radialGradient id="o" cx="863.000206" cy="618.000216" gradientTransform="matrix(.174513 -.984655 .984655 .174513 103.878183 1359.908146)" gradientUnits="userSpaceOnUse" r="77.964123" xlink:href="#b"></radialGradient><path d="m283.443359 746c-37.000152 0-68.749908-5.333252-95.25-16-26.500106-10.666748-46.749939-26.333252-60.75-47-14.000053-20.666748-21-46.166504-21-76.5 0-13.333374 1.083329-25.999939 3.25-38 2.16668-12.000061 5.416657-23.333252 9.75-34 9.333374-30.333496 23.749909-56.166565 43.25-77.5 19.500077-21.333435 43.41655-37.749939 71.75-49.25 28.333435-11.500061 60.333191-17.25 96-17.25 37.333496 0 69.249909 5.333252 95.75 16 26.500092 10.666748 46.833252 26.333252 61 47s21.25 46.166504 21.25 76.5c0 11.666748-.833343 22.916626-2.5 33.75-1.666687 10.833374-4.333313 21.249939-8 31.25-8.666717 31.666809-22.833282 58.749878-42.5 81.25-19.666748 22.500122-44.083221 39.749939-73.25 51.75-29.166778 12.000061-62.083191 18-98.75 18zm570.242188 0c-20.333435 0-38.249939-3.583252-53.75-10.75-15.500122-7.166748-27.25-18.416626-35.25-33.75h-4l-12 38.5h-53l63.5-362h65l-22.5 130.5h3c7.666687-8.333374 16.249939-15.333313 25.75-21 9.5-5.666687 19.833252-9.916626 31-12.75 11.166687-2.833374 22.916565-4.25 35.25-4.25 20.333435 0 37.999878 3.916626 53 11.75 15.000061 7.833374 26.583252 19.333252 34.75 34.5 8.166687 15.166748 12.25 33.916565 12.25 56.25 0 10.333374-.75 20.416626-2.25 30.25s-3.75 19.583252-6.75 29.25c-6.333374 25.666748-15.999939 46.916626-29 63.75s-28.416626 29.333252-46.25 37.5c-17.833435 8.166748-37.416565 12.25-58.75 12.25zm-347.871094-6 46.5-263.5h52.5l-1.5 44h3.5c4.666687-8.666687 10.416626-16.833313 17.25-24.5s14.916626-13.833313 24.25-18.5 19.999939-7 32-7c6.333374 0 12.25.5 17.75 1.5 5.500061 1 10.25 2.166687 14.25 3.5l-10 59h-27c-11.666687 0-22.166626 1.833313-31.5 5.5s-17.416626 8.916626-24.25 15.75-12.416626 14.833252-16.75 24c-4.333313 9.166748-7.333313 19.249939-9 30.25l-23 130zm334.371094-49.5c16.000061 0 29.749939-2.916626 41.25-8.75s20.916626-14.583252 28.25-26.25 12.666626-26.333313 16-44c1-5.333374 1.666626-9.916626 2-13.75.333313-3.833374.666626-7.166626 1-10 .333313-2.833374.5-5.416626.5-7.75 0-12.000061-2.166687-21.999939-6.5-30-4.333374-8.000061-10.916626-14-19.75-18s-19.916626-6-33.25-6c-11.000061 0-21.25 1.75-30.75 5.25-9.500061 3.5-17.916626 8.666626-25.25 15.5s-13.5 15.166626-18.5 25c-5.000061 9.833374-8.666687 21.249939-11 34.25-1 4.333374-1.666687 8.166626-2 11.5-.333374 3.333374-.583374 6.333313-.75 9-.166687 2.666687-.25 5.166626-.25 7.5 0 12.333374 2.249939 22.666626 6.75 31 4.5 8.333374 11.083252 14.666626 19.75 19 8.666687 4.333374 19.499939 6.5 32.5 6.5zm-555.242188-4c19.333405 0 37.166626-2.5 53.5-7.5s30.916596-12.249939 43.75-21.75c12.833405-9.500061 23.333283-21.333252 31.5-35.5 8.166718-14.166748 13.916657-30.416626 17.25-48.75.666657-5 1.333313-9.416626 2-13.25.666657-3.833374 1.083344-7.166626 1.25-10 .166657-2.833374.333344-5.416626.5-7.75.166657-2.333374.25-4.666626.25-7 0-18.333435-4.249969-33.833252-12.75-46.5-8.500061-12.666748-20.666626-22.249939-36.5-28.75s-34.749939-9.75-56.75-9.75c-19.333404 0-37.166626 2.416626-53.5 7.25s-30.833282 11.999939-43.5 21.5c-12.666717 9.500061-23.083313 21.249939-31.25 35.25-8.166702 14.000061-13.916656 30.333252-17.25 49-1.000015 5-1.75 9.416626-2.25 13.25s-.833343 7.166626-1 10c-.166671 2.833374-.333343 5.416626-.5 7.75-.166671 2.333374-.25 4.666626-.25 7 0 18.333374 4.24997 33.833252 12.75 46.5 8.500031 12.666748 20.666596 22.333313 36.5 29 15.83339 6.666687 34.583252 10 56.25 10z" fill="#19b2e4" fill-rule="evenodd" filter="url(#a)"></path><g fill="none" stroke-width="8"><path d="m190.000046 472.081116 237.999954 205.837829" stroke="url(#c)"></path><path d="m159.999939 630.999146 149-60.999146" stroke="url(#d)"></path><path d="m450.000397 522.001221-141.000458 47.998779" stroke="url(#e)"></path><path d="m374 636-83.001801 24.998657" stroke="url(#f)"></path><path d="m222.000015 611.999939 68.998184 48.998718" stroke="url(#g)"></path><path d="m222.000015 611.999939 12.001862-98.000305" stroke="url(#h)"></path><path d="m314.001068 479.001099-79.999191 34.998535" stroke="url(#i)"></path><path d="m314.001068 479.001099 86.999024 59.998657" stroke="url(#j)"></path><path d="m373.998596 636.000183 27.001496-97.000427" stroke="url(#k)"></path><path d="m319.999115 431.000061-10.999176 138.999939" stroke="url(#l)"></path><path d="m273.996826 712.999207 35.003113-142.999207" stroke="url(#m)"></path><path d="m786.999817 553.29718 145.000183 125.405579" stroke="url(#n)"></path><path d="m783.000671 683.000793 159.999024-130.001159" stroke="url(#o)"></path></g></svg>`