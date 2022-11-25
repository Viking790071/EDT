#Region Public

#Region ObsoleteProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working with scanner.

// Obsolete. Use FilesOperationsClient.OpenScannerSettingsForm.
// Opens the form of scanning settings.
Procedure OpenScanSettingForm() Export
	
	FilesOperationsClient.OpenScanSettingForm();
	
EndProcedure

#EndRegion

#EndRegion