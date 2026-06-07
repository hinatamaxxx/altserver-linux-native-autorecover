const fs = require("node:fs");
const path = require("node:path");

const root = process.argv[2] ? path.resolve(process.argv[2]) : process.cwd();

const patterns = [
  {
    name: "MAC address",
    regex: /([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}/,
  },
  {
    name: "Private IPv4",
    regex: /192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[0-1])\.[0-9]+\.[0-9]+/,
  },
  {
    name: "Secret keywords",
    regex: /password|passwd|apple.?id|mobiledevicepairing|BEGIN .*PRIVATE KEY/i,
  },
];

const allowedKeywordFiles = new Set([
  ".gitignore",
  "install.sh",
  "README.md",
  "PRIVACY_CHECKLIST.md",
  "docs/setup.md",
  "docs/publishing.md",
  "docs/license-notes.md",
  "docs/troubleshooting.md",
  "docs/known-issues.md",
  "docs/verification.md",
  "tools/privacy-scan.js",
]);

function walk(dir) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name === ".git") continue;
    const filePath = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(filePath));
    else out.push(filePath);
  }
  return out;
}

let findings = [];

for (const file of walk(root)) {
  const rel = path.relative(root, file).replaceAll(path.sep, "/");
  const text = fs.readFileSync(file, "utf8");
  const lines = text.split(/\r?\n/);
  for (const [index, line] of lines.entries()) {
    for (const pattern of patterns) {
      if (!pattern.regex.test(line)) continue;
      const isAllowedKeyword =
        pattern.name === "Secret keywords" && allowedKeywordFiles.has(rel);
      findings.push({
        file: rel,
        line: index + 1,
        type: pattern.name,
        allowed: isAllowedKeyword,
        text: line,
      });
    }
  }
}

const blocking = findings.filter((item) => !item.allowed);

console.log(`Scanned: ${root}`);
console.log(`Findings: ${findings.length}`);
console.log(`Blocking findings: ${blocking.length}`);

for (const item of findings) {
  const marker = item.allowed ? "allowed-doc" : "BLOCK";
  console.log(`${marker} ${item.type} ${item.file}:${item.line}: ${item.text}`);
}

if (blocking.length > 0) {
  process.exit(1);
}
