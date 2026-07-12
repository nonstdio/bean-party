const { createApp } = require("./src/app");
const logger = require("./src/logger");

async function main() {
  const app = createApp();
  await app.start();

  const shutdown = async (signal) => {
    logger.info("shutdown_signal_received", { signal });
    try {
      await app.stop();
      process.exit(0);
    } catch (error) {
      logger.error("shutdown_failed", { message: error.message });
      process.exit(1);
    }
  };

  process.on("SIGINT", () => shutdown("SIGINT"));
  process.on("SIGTERM", () => shutdown("SIGTERM"));
}

if (require.main === module) {
  main().catch((error) => {
    logger.error("startup_failed", { message: error.message });
    process.exit(1);
  });
}

module.exports = {
  main,
};
