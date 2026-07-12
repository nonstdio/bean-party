class RateLimiter {
  constructor(windowMs, maxEvents) {
    this.windowMs = windowMs;
    this.maxEvents = maxEvents;
    this.buckets = new Map();
  }

  allow(key, now = Date.now()) {
    const bucket = this.buckets.get(key) || { count: 0, resetAt: now + this.windowMs };
    if (now >= bucket.resetAt) {
      bucket.count = 0;
      bucket.resetAt = now + this.windowMs;
    }
    bucket.count += 1;
    this.buckets.set(key, bucket);
    return bucket.count <= this.maxEvents;
  }

  reset() {
    this.buckets.clear();
  }
}

module.exports = {
  RateLimiter,
};
