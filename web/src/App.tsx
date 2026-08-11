import { Navigate, Route, Routes } from "react-router-dom";
import { SurfaceStage } from "./components/SurfaceStage";
import { FieldDetailView } from "./views/FieldDetailView";
import { FieldsView } from "./views/FieldsView";
import { MarketView } from "./views/MarketView";
import { SellView } from "./views/SellView";
import { TodayView } from "./views/TodayView";
export function App() {
  return <SurfaceStage><Routes>
    <Route path="/today" element={<TodayView />} />
    <Route path="/fields" element={<FieldsView />} />
    <Route path="/fields/:fieldId" element={<FieldDetailView />} />
    <Route path="/market" element={<MarketView />} />
    <Route path="/sell" element={<SellView />} />
    <Route path="*" element={<Navigate to="/today" replace />} />
  </Routes></SurfaceStage>;
}
