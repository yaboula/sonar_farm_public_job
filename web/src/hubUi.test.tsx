import { render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { beforeEach, describe, expect, it } from "vitest";
import { App } from "./App";
import { StatePanel } from "./components/StatePanel";
import { calculateSurfaceScale } from "./components/SurfaceStage";
import { HubProvider } from "./store/HubContext";
import type { ViewState } from "./types";

function renderHub(route: string) {
  return render(<MemoryRouter initialEntries={[route]}><HubProvider><App /></HubProvider></MemoryRouter>);
}

describe("public-job Hub visual contract", () => {
  beforeEach(() => window.history.replaceState({}, "", "/"));

  it("keeps the original fixed canvas scale inside common viewports", () => {
    expect(calculateSurfaceScale(1280, 720)).toBeCloseTo(0.709, 2);
    expect(calculateSurfaceScale(1920, 1080)).toBeGreaterThan(1);
    expect(calculateSurfaceScale(2560, 1080)).toBe(calculateSurfaceScale(1920, 1080));
  });

  it("shows only public routes and persistent progression", async () => {
    renderHub("/today");
    await screen.findByRole("heading", { name: "Today" });
    const navigation = screen.getByRole("navigation", { name: "Primary navigation" });
    expect(within(navigation).getAllByRole("link").map((link) => link.textContent)).toEqual(["Today", "Fields", "Market", "Sell"]);
    expect(screen.getByLabelText("Level 5, 4380 XP")).toBeVisible();
    expect(screen.queryByText("Company")).not.toBeInTheDocument();
    expect(screen.queryByText("Warehouse")).not.toBeInTheDocument();
  });

  it("renders all public view states in the dark shared state panel", () => {
    const states: Array<Exclude<ViewState, "ready">> = ["loading", "empty", "blocked", "error", "restricted", "unavailable"];
    for (const state of states) {
      const view = render(<StatePanel state={state} />);
      expect(view.container.querySelector(`.state-panel--${state}`)).toBeInTheDocument();
      view.unmount();
    }
  });

  it("filters Market products and opens an exact purchase confirmation", async () => {
    const user = userEvent.setup();
    const view = renderHub("/market");
    await screen.findByRole("heading", { name: "Market" });
    expect(view.container.querySelector(".supply-card img")).toHaveAttribute("src");
    await user.type(screen.getByPlaceholderText("Search products"), "potato");
    expect(screen.getByRole("heading", { name: "Potato Seeds" })).toBeVisible();
    expect(screen.queryByRole("heading", { name: "Carrot Seeds" })).not.toBeInTheDocument();
    await user.clear(screen.getByPlaceholderText("Search products"));
    await user.click(screen.getByRole("button", { name: "Add Carrot Seeds" }));
    await user.click(screen.getByRole("button", { name: "Review Purchase" }));
    const dialog = screen.getByRole("dialog", { name: "Confirm this purchase?" });
    expect(within(dialog).getByText("1× Carrot Seeds")).toBeVisible();
    expect(within(dialog).getByRole("button", { name: "Pay $24" })).toBeEnabled();
  });

  it("enforces the ten-line Market cart limit", async () => {
    const user = userEvent.setup();
    renderHub("/market");
    await screen.findByRole("heading", { name: "Market" });
    const products = ["Carrot Seeds", "Potato Seeds", "Lettuce Seeds", "Tomato Seedling", "Field Watering Can", "Reinforced Watering Can", "Field Hand Hoe", "Reinforced Hand Hoe", "Organic Fertilizer", "Balanced Fertilizer", "Organic Pest Treatment"];
    for (const product of products) await user.click(screen.getByRole("button", { name: `Add ${product}` }));
    const cart = screen.getByRole("complementary");
    expect(within(cart).getByRole("heading", { name: "10 lines" })).toBeVisible();
    expect(screen.getByRole("button", { name: "Remove Organic Pest Treatment" })).toBeDisabled();
  });

  it("keeps the tablet physical-only while enabling it at a Market terminal", async () => {
    window.history.replaceState({}, "", "/?surface=market");
    renderHub("/market");
    await screen.findByRole("heading", { name: "Market" });
    expect(screen.getByText("Market Terminal")).toBeVisible();
    expect(screen.getByRole("button", { name: "Add Farmer Tablet" })).toBeEnabled();
  });

  it("preserves Field privacy and opens authoritative topology plus extension review", async () => {
    const user = userEvent.setup();
    renderHub("/fields");
    await screen.findByRole("heading", { name: "Fields" });
    expect(screen.getByText("Holder identity remains private.")).toBeVisible();
    await user.click(screen.getByRole("button", { name: "Open Field Details" }));
    await screen.findByRole("heading", { name: "South Fields" });
    expect(screen.getByRole("region", { name: "South Fields topology" })).toBeVisible();
    await user.click(screen.getByRole("button", { name: /6 hours/ }));
    expect(screen.getByRole("dialog", { name: "Extend for 6 hours?" })).toBeVisible();
  });

  it("keeps remote Sell browse-only and enables confirmation at the physical buyer", async () => {
    const remote = renderHub("/sell");
    await screen.findByRole("heading", { name: "Sell" });
    expect(screen.getByRole("button", { name: "Route to Buyer" })).toBeVisible();
    expect(screen.queryByRole("button", { name: "Review Sale" })).not.toBeInTheDocument();
    remote.unmount();

    window.history.replaceState({}, "", "/?surface=sell");
    const user = userEvent.setup();
    renderHub("/sell");
    await screen.findByRole("heading", { name: "Sell" });
    await user.click(screen.getByRole("button", { name: "Select all eligible" }));
    await user.click(screen.getByRole("button", { name: "Review Sale" }));
    expect(screen.getByRole("dialog", { name: "Confirm this exact sale?" })).toBeVisible();
    expect(screen.getByRole("button", { name: "Sell for $553" })).toBeEnabled();
  });

  it("renders server-restricted state without plausible fixture content", async () => {
    window.history.replaceState({}, "", "/?state=restricted");
    renderHub("/market");
    await waitFor(() => expect(screen.getByRole("heading", { name: "Farmer access required" })).toBeVisible());
    expect(screen.queryByRole("heading", { name: "Carrot Seeds" })).not.toBeInTheDocument();
  });
});
