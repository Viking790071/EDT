#Region Public

// Defines the sections where the additional data processor calling command is available.
// Add the metadata of sections where the commands are available to the Sections array.
// 
// 
// Instead of Metadata for desktop, you must add
// AdditionalReportsAndDataProcessorsClientServer.DesktopID().
//
// Parameters:
//   Sections - Array - sections where commands calling additional data processors are available.
//       * MetadataObject: Subsystem - section (subsystem) metadata.
//       * String - for desktop.
//
Procedure GetSectionsWithAdditionalDataProcessors(Sections) Export
	
	 Sections.Add(Metadata.Subsystems.CRM);
	Sections.Add(Metadata.Subsystems.Sales);
	Sections.Add(Metadata.Subsystems.Purchases);
	Sections.Add(Metadata.Subsystems.Services);
	Sections.Add(Metadata.Subsystems.Warehouse);
	// begin Drive.FullVersion
	Sections.Add(Metadata.Subsystems.Production);
	// end Drive.FullVersion
	Sections.Add(Metadata.Subsystems.Finances);
	Sections.Add(Metadata.Subsystems.Payroll);
	Sections.Add(Metadata.Subsystems.Enterprise);
	Sections.Add(Metadata.Subsystems.Analysis);
	Sections.Add(Metadata.Subsystems.SetupAndAdministration);
	
EndProcedure

// Defines the sections where the command that opens an additional report is available.
// Add the metadata of sections where the commands are available to the Sections array.
// 
// 
// Instead of Metadata for desktop, you must add
// AdditionalReportsAndDataProcessorsClientServer.DesktopID().
//
// Parameters:
//   Sections - Array - sections where commands calling additional reports are available.
//       * MetadataObject: Subsystem - section (subsystem) metadata.
//       * String - for desktop.
//
Procedure GetSectionsWithAdditionalReports(Sections) Export
	
	Sections.Add(Metadata.Subsystems.CRM);
	Sections.Add(Metadata.Subsystems.Sales);
	Sections.Add(Metadata.Subsystems.Purchases);
	Sections.Add(Metadata.Subsystems.Services);
	Sections.Add(Metadata.Subsystems.Warehouse);
	// begin Drive.FullVersion
	Sections.Add(Metadata.Subsystems.Production);
	// end Drive.FullVersion
	Sections.Add(Metadata.Subsystems.Finances);
	Sections.Add(Metadata.Subsystems.Payroll);
	Sections.Add(Metadata.Subsystems.Enterprise);
	Sections.Add(Metadata.Subsystems.Analysis);
	Sections.Add(Metadata.Subsystems.SetupAndAdministration);
	
EndProcedure

#EndRegion
