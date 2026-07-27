export type ApplicationConfig = {
  environment: string;
  version: string;
  commitSha: string;
  serviceName: string;
  port: number;
};

function readString(name: string, fallback: string): string {
  const value = process.env[name]?.trim();
  return value || fallback;
}

function readPort(): number {
  const rawPort = readString("PORT", "3000");
  const port = Number(rawPort);

  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error(`PORT must be an integer from 1 through 65535; received "${rawPort}"`);
  }

  return port;
}

export function loadConfig(): ApplicationConfig {
  return {
    environment: readString("APP_ENVIRONMENT", "local"),
    version: readString("APP_VERSION", "dev"),
    commitSha: readString("COMMIT_SHA", "local"),
    serviceName: readString("SERVICE_NAME", "ecs-release-api"),
    port: readPort()
  };
}
