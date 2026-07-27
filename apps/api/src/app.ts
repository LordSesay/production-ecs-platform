import express, { type Request, type Response } from "express";
import type { ApplicationConfig } from "./config.js";

type PlatformResponse = {
  service: string;
  environment: string;
  version: string;
  commitSha: string;
  timestamp: string;
};

export function createApp(config: ApplicationConfig) {
  const app = express();

  app.disable("x-powered-by");

  app.use((request, response, next) => {
    response.setHeader("X-Content-Type-Options", "nosniff");
    response.setHeader("X-Frame-Options", "DENY");
    response.setHeader("Referrer-Policy", "no-referrer");
    response.setHeader("Cache-Control", "no-store");

    const startedAt = performance.now();
    response.on("finish", () => {
      const logEntry = {
        timestamp: new Date().toISOString(),
        method: request.method,
        path: request.path,
        status: response.statusCode,
        durationMs: Number((performance.now() - startedAt).toFixed(2))
      };
      console.info(JSON.stringify(logEntry));
    });

    next();
  });

  app.get("/api/health", (_request: Request, response: Response) => {
    response.status(200).json({
      status: "healthy",
      service: config.serviceName
    });
  });

  app.get("/api/platform", (_request: Request, response: Response<PlatformResponse>) => {
    response.status(200).json({
      service: config.serviceName,
      environment: config.environment,
      version: config.version,
      commitSha: config.commitSha,
      timestamp: new Date().toISOString()
    });
  });

  app.use((_request: Request, response: Response) => {
    response.status(404).json({
      error: "not_found"
    });
  });

  return app;
}
