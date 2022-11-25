#Region Public

#Region ObsoleteProceduresAndFunctions

// Obsolete. Use AttachableCommandsClientServer.UpdateCommands.
//
// Updates a list of print commands depending on the current context.
//
// Parameters:
//  Form - ClientApplicationForm - a form that requires an update of print commands.
//  Source - FormDataStructure - FormTable - a context to check conditions (Form.Object or Form.Items.List).
//
Procedure UpdateCommands(Form, Source) Export
	AttachableCommandsClientServer.UpdateCommands(Form, Source);
EndProcedure

#EndRegion

#EndRegion

#Region Private

Function SettingsForSaving() Export
	
	SettingsForSaving = New Structure;
	SettingsForSaving.Insert("SaveFormats", New Array);
	SettingsForSaving.Insert("PackToArchive", False);
	SettingsForSaving.Insert("TransliterateFilesNames", False);
	SettingsForSaving.Insert("SignatureAndSeal", False);
	
	Return SettingsForSaving;
	
EndFunction

#EndRegion