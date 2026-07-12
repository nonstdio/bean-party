class RateLimiter {
  constructor(windowMs, maxEvents, maxKeys = 10000) {
    this.windowMs = windowMs;
    this.maxEvents = maxEvents;
    this.maxKeys = maxKeys;
    this.buckets = new Map();
  }

  allow(key, now = Date.now()) {
    this._prune(now);

    const bucket = this.buckets.get(key) || { count: 0, resetAt: now + this.windowMs };
    if (now >= bucket.resetAt) {
      bucket.count = 0;
      bucket.resetAt = now + this.windowMs;
    }
    bucket.count += 1;
    this.buckets.set(key, bucket);
    this._enforceMaxKeys();
    return bucket.count <= this.maxEvents;
  }

  _prune(now) {
    for (const [key, bucket] of this.buckets) {
      if (now >= bucket.resetAt) {
        this.buckets.delete(key);
      }
    }
  }

  _enforceMaxKeys() {
    while (this.buckets.size > this.maxKeys) {
      const oldestKey = this.buckets.keys().next().value;
      if (oldestKey === undefined) {
        break;
      }
      this.buckets.delete(oldestKey);
    }
  }

  reset() {
    this.buckets.clear();
  }
}

module.exports = {
  RateLimiter,
};
