#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonOverridable.OnAddMetadataObjectsRenaming. 
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	Library = "StandardSubsystems";
	
	Common.AddRenaming(Total,
		"2.1.0.1",
		"Subsystem.StandardSubsystems.Subsystem.EventLogMonitor",
		"Subsystem.StandardSubsystems.Subsystem.EventLogAnalysis",
		Library);
	
EndProcedure

// See ReportsOptionsOverridable.CustomizeReportOptions. 
Procedure OnSetUpReportsOptions(Settings) Export
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	ModuleReportsOptions.CustomizeReportInManagerModule(Settings, Metadata.Reports.EventLogAnalysis);
EndProcedure

#EndRegion

