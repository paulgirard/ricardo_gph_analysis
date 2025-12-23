import { MultiDirectedGraph } from "graphology";

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
  reportingByAggregateInto?: boolean;
  reportingBySplit?: boolean;
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
}

export type EntityResolutionLabelType = "AGGREGATE_INTO" | "SPLIT" | "SPLIT_OTHER";
export type TradeLabelType = "REPORTED_TRADE" | "GENERATED_TRADE" | "TO_IMPUTE";

export type EdgeLabelType = TradeLabelType | EntityResolutionLabelType;

export type FlowValueImputationMethod =
  | "aggregation"
  | "split_to_one"
  | "split_by_years_ratio"
  | "split_by_mirror_ratio";

type tradeEdgeStatus =
  | "toTreat"
  | "ok"
  | "ignore_internal"
  | "ignore_resolved"
  | "discard_collision"
  | "split_failed_no_ratio"
  | "split_failed_error"
  | "split_only_partial"
  | "to_impute";

export interface TradeEdgeAttributes {
  labels: Set<EdgeLabelType>;
  label?: string;
  // value can be undefinde for to impute trade flows
  value?: number;
  partial?: string;
  generatedFrom?: string;

  valueGeneratedBy?: FlowValueImputationMethod[];
  reportedBy: string;
  originalReporters?: Set<string>;

  status?: tradeEdgeStatus;
  notes?: string;
  mergedIn?: string[];
  valueToSplit?: number;
  //originalReportedTradeFlowId?: string;
  type: "trade";
}
export type GraphAttributes = { year: number };
export type GraphType = MultiDirectedGraph<
  EntityNodeAttributes,
  TradeEdgeAttributes | ResolutionEdgeAttributes,
  GraphAttributes
>;
export type GraphEntityPartiteType = MultiDirectedGraph<EntityNodeAttributes, TradeEdgeAttributes, GraphAttributes>;

export interface ResolutionEdgeAttributes {
  labels: Set<EntityResolutionLabelType>;
  type: "resolution";
}
export type GraphResolutionPartiteType = MultiDirectedGraph<
  EntityNodeAttributes,
  ResolutionEdgeAttributes,
  GraphAttributes
>;

export type TradeVizEdgeAttribute =
  | {
      labels: Set<EdgeLabelType | EntityResolutionLabelType>;
      status: Set<tradeEdgeStatus>;

      maxExpImp?: number;
      //TODO: add a combiend status ?

      importerValue?: number;
      importerPartial?: string;
      importerGeneratedFrom?: string;
      importerValueGeneratedBy?: FlowValueImputationMethod[];
      importerReportedBy: string;
      importerOriginalReporters?: Set<string>;

      importerStatus?: tradeEdgeStatus;
      importerNotes?: string;
      importerMergedIn?: string[];
      importerValueToSplit?: number;
      //importerOriginalReportedTradeFlowId?: string;
      exporterValue?: number;
      exporterPartial?: string;
      exporterGeneratedFrom?: string;
      exporterValueGeneratedBy?: FlowValueImputationMethod[];
      exporterReportedBy: string;
      exporterOriginalReporters?: Set<string>;

      exporterStatus?: tradeEdgeStatus;
      exporterNotes?: string;
      exporterMergedIn?: string[];
      exporterValueToSplit?: number;
      //exporterOriginalReportedTradeFlowId?: string;
      type: "trade" | "trade&resolution";
    }
  | {
      labels: Set<EdgeLabelType | EntityResolutionLabelType>;
      type: "resolution" | "trade&resolution";
    };
