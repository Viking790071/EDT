////////////////////////////////////////////////////////////////////////////////
// Subsystem "Configuration update".
//  
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Procedure of the configuration on schedule update checking.
Procedure ProcessUpdateCheckOnSchedule() Export
	ConfigurationUpdateClientDrive.CheckUpdateOnSchedule();
EndProcedure

#EndRegion
