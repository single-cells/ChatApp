import assert from 'node:assert';

assert.strictEqual(typeof Date.prototype.toISOString, 'function');
console.log('health check script ok');
