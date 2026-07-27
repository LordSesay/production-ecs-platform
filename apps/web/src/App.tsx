import { useEffect, useState } from "react";
import { fetchPlatformMetadata } from "./api";
import type { PlatformMetadata } from "./types";
import "./styles.css";

type ViewState =
  | { status: "loading" }
  | { status: "ready"; metadata: PlatformMetadata }
  | { status: "error"; message: string };

const workflow = ["GitHub", "Jenkins", "Amazon ECR", "ECS Fargate"];

export default function App() {
  const [viewState, setViewState] = useState<ViewState>({ status: "loading" });

  useEffect(() => {
    const controller = new AbortController();

    fetchPlatformMetadata(controller.signal)
      .then((metadata) => setViewState({ status: "ready", metadata }))
      .catch((error: unknown) => {
        if (error instanceof DOMException && error.name === "AbortError") {
          return;
        }

        setViewState({
          status: "error",
          message: error instanceof Error ? error.message : "Unknown platform API error"
        });
      });

    return () => controller.abort();
  }, []);

  return (
    <main>
      <section className="hero">
        <p className="eyebrow">Production-style delivery evidence</p>
        <h1>ECS Release Console</h1>
        <p className="lede">
          One traceable release path from source commit to a healthy Fargate workload.
        </p>
        <ol className="workflow" aria-label="Release workflow">
          {workflow.map((step, index) => (
            <li key={step}>
              <span>{String(index + 1).padStart(2, "0")}</span>
              {step}
            </li>
          ))}
        </ol>
      </section>

      <section className="release-card" aria-live="polite">
        <div className="card-heading">
          <div>
            <p className="eyebrow">Active deployment</p>
            <h2>Runtime identity</h2>
          </div>
          <span className={`status status-${viewState.status}`}>
            {viewState.status === "ready" ? "Healthy" : viewState.status}
          </span>
        </div>

        {viewState.status === "loading" && <p>Requesting metadata from the API…</p>}

        {viewState.status === "error" && (
          <div className="error-panel">
            <strong>Release verification failed</strong>
            <p>{viewState.message}</p>
          </div>
        )}

        {viewState.status === "ready" && (
          <dl className="metadata-grid">
            <div>
              <dt>Service</dt>
              <dd>{viewState.metadata.service}</dd>
            </div>
            <div>
              <dt>Environment</dt>
              <dd>{viewState.metadata.environment}</dd>
            </div>
            <div>
              <dt>Version</dt>
              <dd>{viewState.metadata.version}</dd>
            </div>
            <div>
              <dt>Commit</dt>
              <dd className="commit">{viewState.metadata.commitSha}</dd>
            </div>
            <div className="wide">
              <dt>API response</dt>
              <dd>{new Date(viewState.metadata.timestamp).toLocaleString()}</dd>
            </div>
          </dl>
        )}
      </section>

      <footer>
        <span>Terraform-managed platform</span>
        <span>Immutable container releases</span>
        <span>Health-verified deployments</span>
      </footer>
    </main>
  );
}
