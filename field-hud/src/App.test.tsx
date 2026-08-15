import { act, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { App } from "./App";
import { fieldHudFixture } from "./fixture";

describe("Field Operations HUD", () => {
  it("renders the expanded operational picture and full legend", () => {
    render(<App initial={fieldHudFixture()}/>);
    expect(screen.getByText("Grapeseed South")).toBeInTheDocument();
    expect(screen.getAllByText("11").length).toBeGreaterThan(0);
    expect(screen.getByLabelText("Field marker legend")).toHaveTextContent("Blocked");
    expect(screen.getByText("Maintain green")).toBeInTheDocument();
  });
  it("switches compact and expanded modes without hiding", () => {
    render(<App initial={{ ...fieldHudFixture(), expanded: false }}/>);
    expect(screen.queryByText("Working cycle")).not.toBeInTheDocument();
    act(() => window.dispatchEvent(new MessageEvent("message", { data: { type: "fieldHud:mode", payload: { expanded: true } } })));
    expect(screen.getByText("Working cycle")).toBeInTheDocument();
  });
  it("supports both configured positions", () => {
    const { container } = render(<App initial={{ ...fieldHudFixture(), position: "top-left" }}/>);
    expect(container.querySelector(".position-top-left")).toBeInTheDocument();
  });
  it("shows grace, restricted and stale states truthfully", () => {
    const fixture = fieldHudFixture();
    fixture.state.access.allowed = false; fixture.state.access.onDuty = false; fixture.state.access.reason = "duty_required";
    fixture.sync = "stale";
    render(<App initial={fixture}/>);
    expect(screen.getByText("Sync stale")).toBeInTheDocument();
    expect(screen.getByText("Interactions").parentElement).toHaveTextContent("Blocked");
  });
  it("explains grace and departing capabilities without over-blocking", () => {
    const fixture = fieldHudFixture();
    fixture.state.reservation.status = "grace";
    const { rerender } = render(<App initial={fixture}/>);
    expect(screen.getByText("Interactions").parentElement).toHaveTextContent("Care / harvest");
    const departing = fieldHudFixture();
    departing.state.reservation.memberStatus = "departing";
    rerender(<App key="departing" initial={departing}/>);
    expect(screen.getByText("Departing")).toBeInTheDocument();
    expect(screen.getByText("Interactions").parentElement).toHaveTextContent("Own crops only");
  });
  it("ticks the rental timer and hides only on authoritative hide", () => {
    vi.useFakeTimers();
    render(<App initial={{ ...fieldHudFixture(), remainingSeconds: 62 }}/>);
    expect(screen.getByText("00:01:02")).toBeInTheDocument();
    act(() => vi.advanceTimersByTime(2000));
    expect(screen.getByText("00:01:00")).toBeInTheDocument();
    act(() => window.dispatchEvent(new MessageEvent("message", { data: { type: "fieldHud:hide" } })));
    expect(screen.queryByText("Field operations")).not.toBeInTheDocument();
    vi.useRealTimers();
  });
  it("merges background refresh state without flashing zero counts or priority", () => {
    render(<App initial={fieldHudFixture()}/>);
    expect(screen.getAllByText("Harvest").length).toBeGreaterThan(0);
    expect(screen.getAllByText("11").length).toBeGreaterThan(0);
    act(() => window.dispatchEvent(new MessageEvent("message", {
      data: { type: "fieldHud:update", payload: { sync: "loading" } },
    })));
    expect(screen.getAllByText("Harvest").length).toBeGreaterThan(0);
    expect(screen.getAllByText("11").length).toBeGreaterThan(0);
    expect(screen.queryByText("Syncing Field")).not.toBeInTheDocument();
  });
});
