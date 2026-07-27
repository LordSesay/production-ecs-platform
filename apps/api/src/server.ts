import http from "node:http";
import { createApp } from "./app.js";
import { loadConfig } from "./config.js";

const config = loadConfig();
const server = http.createServer(createApp(config));

server.listen(config.port, "0.0.0.0", () => {
  console.info(
    JSON.stringify({
      event: "server_started",
      service: config.serviceName,
      environment: config.environment,
      version: config.version,
      commitSha: config.commitSha,
      port: config.port
    })
  );
});

let shuttingDown = false;

function shutdown(signal: NodeJS.Signals): void {
  if (shuttingDown) {
    return;
  }

  shuttingDown = true;
  console.info(JSON.stringify({ event: "shutdown_started", signal }));

  const forceExitTimer = setTimeout(() => {
    console.error(JSON.stringify({ event: "shutdown_forced" }));
    process.exit(1);
  }, 10_000);
  forceExitTimer.unref();

  server.close((error) => {
    clearTimeout(forceExitTimer);

    if (error) {
      console.error(JSON.stringify({ event: "shutdown_failed", message: error.message }));
      process.exit(1);
    }

    console.info(JSON.stringify({ event: "shutdown_complete" }));
    process.exit(0);
  });
}

process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);
