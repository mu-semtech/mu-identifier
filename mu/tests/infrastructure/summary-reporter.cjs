const Mocha = require('mocha');
const { writeFileSync } = require('fs');
const { basename } = require('path');

class SummaryReporter extends Mocha.reporters.Spec {
  constructor(runner, options) {
    super(runner, options);

    const passes = [];
    const failures = [];

    runner.on('pass', (test) => passes.push(test.fullTitle()));
    runner.on('fail', (test, err) => failures.push({ title: test.fullTitle(), error: err.message }));

    runner.once('end', () => {
      const specName = basename(process.env.TEST_SPEC || 'unknown', '.js');
      writeFileSync(`/results/${specName}.json`, JSON.stringify({ passes, failures }));
    });
  }
}

module.exports = SummaryReporter;
