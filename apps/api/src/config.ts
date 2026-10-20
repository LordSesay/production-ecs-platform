export type ApplicationConfig = {
  environment: string;
  version: string;
  commitSha: string;
  serviceName: string;
  port: number;
};

function env(name: string, fallback: string): string {
  return process.env[name]?.trim() || fallback;
}

export function loadConfig(): ApplicationConfig {
  const rawPort = env("PORT", "3000");
  const port = Number(rawPort);

  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error(`PORT must be 1-65535; received "${rawPort}"`);
  }

  return {
    environment: env("APP_ENVIRONMENT", "local"),
    version: env("APP_VERSION", "dev"),
    commitSha: env("COMMIT_SHA", "local"),
    serviceName: env("SERVICE_NAME", "ecs-release-api"),
    port,
  };
}
