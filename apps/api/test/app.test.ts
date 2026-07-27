import request from "supertest";
import { describe, expect, it } from "vitest";
import { createApp } from "../src/app.js";

const testConfig = {
  environment: "test",
  version: "1.2.3",
  commitSha: "abc1234",
  serviceName: "ecs-release-api",
  port: 3000
};

describe("release metadata API", () => {
  it("returns a health contract for load balancers and ECS", async () => {
    const response = await request(createApp(testConfig)).get("/api/health");

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      status: "healthy",
      service: "ecs-release-api"
    });
  });

  it("returns traceable deployment metadata", async () => {
    const response = await request(createApp(testConfig)).get("/api/platform");

    expect(response.status).toBe(200);
    expect(response.body).toMatchObject({
      service: "ecs-release-api",
      environment: "test",
      version: "1.2.3",
      commitSha: "abc1234"
    });
    expect(Number.isNaN(Date.parse(response.body.timestamp))).toBe(false);
  });

  it("does not disclose the framework and rejects unknown routes", async () => {
    const response = await request(createApp(testConfig)).get("/api/unknown");

    expect(response.status).toBe(404);
    expect(response.headers["x-powered-by"]).toBeUndefined();
    expect(response.body).toEqual({ error: "not_found" });
  });
});
