import { HealthController } from './health.controller';

describe('HealthController', () => {
  it('returns ok', () => {
    const c = new HealthController();
    const r = c.health();
    expect(r.ok).toBe(true);
  });
});
