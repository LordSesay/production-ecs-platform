import { render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import App from "./App";

afterEach(() => {
  vi.restoreAllMocks();
});

describe("ECS Release Console", () => {
  it("renders deployment metadata returned by the API", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(
        JSON.stringify({
          service: "ecs-release-api",
          environment: "staging",
          version: "2.0.0",
          commitSha: "7c91abc",
          timestamp: "2026-07-27T06:00:00.000Z"
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      )
    );

    render(<App />);

    expect(await screen.findByText("Healthy")).toBeInTheDocument();
    expect(screen.getByText("staging")).toBeInTheDocument();
    expect(screen.getByText("7c91abc")).toBeInTheDocument();
  });

  it("makes a failed release visible", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response(null, { status: 503 }));

    render(<App />);

    expect(await screen.findByText("Release verification failed")).toBeInTheDocument();
    expect(screen.getByText("Platform API returned HTTP 503")).toBeInTheDocument();
  });
});
