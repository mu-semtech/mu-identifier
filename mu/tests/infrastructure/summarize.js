import { readdirSync, readFileSync } from 'fs';

const GREEN = '\x1b[0;32m';
const RED = '\x1b[0;31m';
const BOLD = '\x1b[1m';
const NC = '\x1b[0m';

const files = readdirSync('/results').filter(f => f.endsWith('.json')).sort();

let totalPass = 0;
let totalFail = 0;
let filesPass = 0;
let filesFail = 0;

console.log(`\n${BOLD}Results${NC}\n`);

for (const file of files) {
  const { passes, failures } = JSON.parse(readFileSync(`/results/${file}`, 'utf8'));

  console.log(`  ${BOLD}${file.replace('.json', '.js')}${NC}`);
  for (const title of passes) {
    console.log(`    ${GREEN}pass${NC}  ${title}`);
  }
  for (const { title, error } of failures) {
    console.log(`    ${RED}fail${NC}  ${title}`);
    if (error) console.log(`          ${error.split('\n')[0]}`);
  }
  console.log();

  totalPass += passes.length;
  totalFail += failures.length;
  if (failures.length > 0) filesFail++; else filesPass++;
}

const filesSummary = [
  filesPass > 0 ? `${GREEN}${filesPass} ${filesPass === 1 ? 'suite' : 'suites'} passed${NC} (${totalPass} tests)` : null,
  filesFail > 0 ? `${RED}${filesFail} ${filesFail === 1 ? 'suite' : 'suites'} failed${NC} (${totalFail} failures)` : null,
].filter(Boolean).join(', ');

console.log(`  ${BOLD}${filesSummary}${NC}\n`);
