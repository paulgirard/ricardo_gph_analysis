import { DirectedGraph } from "graphology";

import { GPHStatusType } from "./GPH";

export type RICType = "GPH_entity" | "group" | "locality" | "geographical_area" | "colonial_area";

export interface RICentity {
  RICname: string;
  type: RICType;
  parent_entity?: string;
  GPH_code?: string;
}

export type EntityType = "RIC" | "GPH" | "GPH-AUTONOMOUS" | "GPH-AUTONOMOUS-CITED" | "ROTW";

export interface EntityNodeAttributes {
  label: string;
  reporting: boolean;
  ricType: RICType;
  entityType: EntityType;
  cited?: boolean;
  gphStatus?: GPHStatusType;
  ricParent?: string;
  totalBilateralTrade?: number;
  type: "entity";
}
export interface ResolutionNodeAttributes {
  label: string;
  type: "resolution";
  value?: number;
}

export type EntityResolutionLabelType = "AGGREGATE_INTO" | "SPLIT" | "SPLIT_OTHER";
export type TradeLabelType = "REPORTED_TRADE" | "GENERATED_TRADE" | "RESOLVE";

export type EdgeLabelType = TradeLabelType | EntityResolutionLabelType;

export type FlowValueImputationMethod =
  | "aggregation"
  | "split_to_one"
  | "split_by_years_ratio"
  | "split_by_mirror_ratio";
export interface EdgeAttributes {
  labels: Set<EdgeLabelType>;
  label?: string;
  Exp?: number;
  Imp?: number;
  valueGeneratedBy?: FlowValueImputationMethod;
  ExpReportedBy?: string;
  ImpReportedBy?: string;
  status?: "toTreat" | "ok" | "ignore_internal" | "ignore_resolved" | "discard_collision";
  value?: number;
  notes?: string;
  aggregatedIn?: string;
}
export type GraphAttributes = { year: number };
export type GraphType = DirectedGraph<EntityNodeAttributes | ResolutionNodeAttributes, EdgeAttributes, GraphAttributes>;
export type GraphEntityPartiteType = DirectedGraph<EntityNodeAttributes, EdgeAttributes, GraphAttributes>;
export type GraphResolutionPartiteType = DirectedGraph<ResolutionNodeAttributes, EdgeAttributes, GraphAttributes>;
