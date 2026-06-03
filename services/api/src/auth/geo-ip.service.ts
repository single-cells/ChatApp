import { Injectable, Logger } from '@nestjs/common';

@Injectable()
export class GeoIpService {
  private readonly logger = new Logger(GeoIpService.name);

  isPrivateIp(ip: string): boolean {
    if (!ip || ip === '::1' || ip === '127.0.0.1') return true;
    if (ip.startsWith('10.') || ip.startsWith('192.168.') || ip.startsWith('172.')) {
      return true;
    }
    if (ip.startsWith('fe80:') || ip.startsWith('fc') || ip.startsWith('fd')) {
      return true;
    }
    return false;
  }

  async resolveLocation(ip: string): Promise<string | null> {
    if (this.isPrivateIp(ip)) return null;
    try {
      const res = await fetch(
        `http://ip-api.com/json/${encodeURIComponent(ip)}?fields=status,country,regionName,city&lang=zh-CN`,
        { signal: AbortSignal.timeout(4000) },
      );
      if (!res.ok) return null;
      const data = (await res.json()) as {
        status?: string;
        country?: string;
        regionName?: string;
        city?: string;
      };
      if (data.status !== 'success') return null;
      const parts = [data.country, data.regionName, data.city].filter(
        (p) => p && p.length > 0,
      );
      return parts.length > 0 ? parts.join(' ') : null;
    } catch (e) {
      this.logger.debug(`Geo lookup failed for ${ip}: ${e}`);
      return null;
    }
  }
}
