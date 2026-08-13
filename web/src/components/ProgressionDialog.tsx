import { CheckCircle, LockKey, Star } from "@phosphor-icons/react";
import type { Progression } from "../types";
import { ConfirmDialog } from "./ConfirmDialog";

const MILESTONES = [
  { level: 1, label: "Public farming", detail: "Small Fields and Basic products" },
  { level: 4, label: "Plus equipment", detail: "Plus care products" },
  { level: 5, label: "Medium operator", detail: "Medium Fields · 5% rent discount · 3% Sell bonus" },
  { level: 8, label: "Pro equipment", detail: "Pro care products" },
  { level: 10, label: "Large operator", detail: "Large Fields · 12% rent discount · 7% Sell bonus" },
  { level: 15, label: "Advanced farmer", detail: "18% rent discount · 11% Sell bonus" },
  { level: 20, label: "Master farmer", detail: "25% rent discount · 15% Sell bonus" },
];

export function ProgressionDialog({ progression, onClose }: { progression: Progression; onClose: () => void }) {
  const levelSpan = Math.max(1, progression.nextLevelXp - progression.levelStartXp);
  const levelProgress = progression.level >= progression.maxLevel ? 100 : Math.round(((progression.xp - progression.levelStartXp) / levelSpan) * 100);
  return <ConfirmDialog eyebrow="Personal progression" title={`Farmer level ${progression.level}`} confirmLabel="Done" onClose={onClose} onConfirm={onClose}>
    <div className="progression-overview">
      <Star size={26} weight="thin" />
      <div><strong>{progression.xp.toLocaleString()} XP</strong><span>{progression.level >= progression.maxLevel ? "Maximum level reached" : `${progression.nextLevelXp - progression.xp} XP to level ${progression.level + 1}`}</span></div>
      <b>{levelProgress}%</b>
    </div>
    <div className="progression-dialog-track"><i style={{ width: `${Math.max(0, Math.min(100, levelProgress))}%` }} /></div>
    <div className="progression-milestones">
      {MILESTONES.map((milestone) => {
        const unlocked = progression.level >= milestone.level;
        return <div className={unlocked ? "is-unlocked" : ""} key={milestone.level}>
          {unlocked ? <CheckCircle size={20} /> : <LockKey size={20} />}
          <span>LVL {milestone.level}</span>
          <p><strong>{milestone.label}</strong><small>{milestone.detail}</small></p>
        </div>;
      })}
    </div>
  </ConfirmDialog>;
}
