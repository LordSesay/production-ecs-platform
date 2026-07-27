import type { PlatformMetadata } from "./types";

export async function fetchPlatformMetadata(signal?: AbortSignal): Promise<PlatformMetadata> {
  const response = await fetch("/api/platform", {
    headers: {
      Accept: "application/json"
    },
    signal
  });

  if (!response.ok) {
    throw new Error(`Platform API returned HTTP ${response.status}`);
  }

  return response.json() as Promise<PlatformMetadata>;
}
