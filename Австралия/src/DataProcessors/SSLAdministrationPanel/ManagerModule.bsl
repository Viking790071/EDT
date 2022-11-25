#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonOverridable.OnAddMetadataObjectsRenaming. 
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	Library = "StandardSubsystems";
	
	Common.AddRenaming(Total,
		"2.2.1.12",
		"Subsystem.SettingsAndAdministration",
		"Subsystem.Administration",
		Library);
	
EndProcedure

// Defines the sections where the report panel is available.
//   For more see description of the SectionsToUse of the ReportsOptions common module procedure.
//   
//
Procedure OnDefineSectionsWithReportOptions(Sections) Export
	
	Return;
	
EndProcedure

// See AdditionalReportsAndDataProcessorsOverridable.GetSectionsWithAdditionalReports. 
Procedure OnDefineSectionsWithAdditionalReports(Sections) Export
	
	Return;
	
EndProcedure

// AdditionalReportsAndDataProcessorsOverridable.GetSectionsWithAdditionalDataProcessors. 
Procedure OnDefineSectionsWithAdditionalDataProcessors(Sections) Export
	
	Sections.Add(Metadata.Subsystems.SetupAndAdministration);
	
EndProcedure

#EndRegion

#EndIf
