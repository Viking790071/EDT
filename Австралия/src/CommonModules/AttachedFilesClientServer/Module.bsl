////////////////////////////////////////////////////////////////////////////////
// Attached files subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Public

#Region ObsoleteProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Event subscription handlers.

// Obsolete.
// Use FilesOperations.DefiineAttachedFileForm.
// Handler of the subscription to FormGetProcessing event for overriding file form.
//
// Parameters:
//  Source                 - CatalogManager - the "*AttachedFiles" catalog manager.
//  FormKind                 - String - a standard form name.
//  Parameters                - Structure - structure parameters.
//  SelectedForm           - String - name or metadata object of opened form.
//  AdditionalInformation - Structure - an additional information of the form opening.
//  StandardProcessing     - Boolean - a flag of standard (system) event processing execution.
//
Procedure OverrideAttachedFileForm(Source,
                                                      FormType,
                                                      Parameters,
                                                      SelectedForm,
                                                      AdditionalInformation,
                                                      StandardProcessing) Export
	
	FilesOperationsInternalServerCall.DetermineAttachedFileForm(
		Source,
		FormType,
		Parameters,
		SelectedForm,
		AdditionalInformation,
		StandardProcessing);
		
EndProcedure

#EndRegion

#EndRegion
