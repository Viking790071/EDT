#Region Public

////////////////////////////////////////////////////////////////////////////////
// Common procedures and functions to manage infobase data.

// See Common.ReferencesToObjectFound. 
Function RefsToObjectFound(Val RefOrRefArray, Val SearchInInternalObjects = False) Export
	
	Return Common.RefsToObjectFound(RefOrRefArray, SearchInInternalObjects);
	
EndFunction

// See Common.CheckDocumentsPosted. 
Function CheckDocumentsPosting(Val Documents) Export
	
	Return Common.CheckDocumentsPosting(Documents);
	
EndFunction

// See Common.PostDocuments. 
Function PostDocuments(Documents) Export
	
	Return Common.PostDocuments(Documents);
	
EndFunction 

////////////////////////////////////////////////////////////////////////////////
// Saving, reading, and deleting settings from storages.

// See Common.CommonSettingsStorageSave. 
Procedure CommonSettingsStorageSave(ObjectKey, SettingsKey, Settings,
			SettingsDetails = Undefined,
			Username = Undefined,
			UpdateCachedValues = False) Export
	
	Common.CommonSettingsStorageSave(
		ObjectKey,
		SettingsKey,
		Settings,
		SettingsDetails,
		Username);
		
EndProcedure

// See Common.CommonSettingsStorageLoad. 
Function CommonSettingsStorageLoad(ObjectKey, SettingsKey, DefaultValue = Undefined,
			SettingsDetails = Undefined,
			Username = Undefined) Export
	
	Return Common.CommonSettingsStorageLoad(
		ObjectKey,
		SettingsKey,
		DefaultValue,
		SettingsDetails,
		Username);
		
EndFunction

// See Common.CommonSettingsStorageDelete. 
Procedure CommonSettingsStorageDelete(ObjectKey, SettingsKey, Username) Export
	
	Common.CommonSettingsStorageDelete(ObjectKey, SettingsKey, Username);
	
EndProcedure

// See Common.CommonSettingsStorageSaveArray. 
Procedure CommonSettingsStorageSaveArray(StructuresArray, UpdateCachedValues = False) Export
	
	Common.CommonSettingsStorageSaveArray(StructuresArray, UpdateCachedValues);
	
EndProcedure

// See Common.SystemSettingsStorageSave. 
Procedure SystemSettingsStorageSave(ObjectKey, SettingsKey, Settings,
			SettingsDetails = Undefined,
			Username = Undefined,
			UpdateCachedValues = False) Export
	
	Common.SystemSettingsStorageSave(
		ObjectKey,
		SettingsKey,
		Settings,
		SettingsDetails,
		Username,
		UpdateCachedValues);
	
EndProcedure

// See Common.SystemSettingsStorageLoad. 
Function SystemSettingsStorageLoad(ObjectKey, SettingsKey, DefaultValue = Undefined, 
			SettingsDetails = Undefined,
			Username = Undefined) Export
	
	Return Common.SystemSettingsStorageLoad(
		ObjectKey,
		SettingsKey,
		DefaultValue,
		SettingsDetails,
		Username);
	
EndFunction

// See Common.SystemSettingsStorageDelete. 
Procedure SystemSettingsStorageDelete(ObjectKey, SettingsKey, Username) Export
	
	Common.SystemSettingsStorageDelete(ObjectKey, SettingsKey, Username);
	
EndProcedure

// See Common.FormDataSettingsStorageSave. 
Procedure FormDataSettingsStorageSave(ObjectKey, SettingsKey, Settings,
			SettingsDetails = Undefined,
			Username = Undefined,
			UpdateCachedValues = False) Export
	
	Common.FormDataSettingsStorageSave(
		ObjectKey,
		SettingsKey,
		Settings,
		SettingsDetails,
		Username,
		UpdateCachedValues);
	
EndProcedure

// See Common.FormDataSettingsStorageLoad. 
Function FormDataSettingsStorageLoad(ObjectKey, SettingsKey, DefaultValue = Undefined,
			SettingsDetails = Undefined,
			Username = Undefined) Export
	
	Return Common.FormDataSettingsStorageLoad(
		ObjectKey,
		SettingsKey,
		DefaultValue,
		SettingsDetails,
		Username);
	
EndFunction

// See Common.FormDataSettingsStorageDelete. 
Procedure FormDataSettingsStorageDelete(ObjectKey, SettingsKey, Username) Export
	
	Common.FormDataSettingsStorageDelete(ObjectKey, SettingsKey, Username);
	
EndProcedure

#Region ObsoleteProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Data separation mode common procedures and functions.

// Obsolete. Please use SaaS.SetSessionSeparation.
Procedure SetSessionSeparation(Val Usage, Val DataArea = Undefined) Export
	
	If Common.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		ModuleSaaS.SetSessionSeparation(Usage, DataArea);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Saving, reading, and deleting settings from storages.

// Obsolete. Use the CommonSettingsStorageSave function instead.
Procedure CommonSettingsStorageSaveArrayAndUpdateCachedValues(StructuresArray) Export
	
	Common.CommonSettingsStorageSaveArray(StructuresArray, True);
	
EndProcedure

// Obsolete. Use the CommonSettingsStorageSave function instead.
Procedure CommonSettingsStorageSaveAndUpdateCachedValues(ObjectKey,
			SettingsKey, Settings) Export
	
	Common.CommonSettingsStorageSave(ObjectKey, SettingsKey, Settings,,, True);
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Functions to manage style colors in the client code.

// The function gets the style color by a style item name.
//
// Parameters:
// StyleColorName - String - Style item name.
//
// Returns:
// Color.
//
Function StyleColor(StyleColorName) Export
	
	Return StyleColors[StyleColorName];
	
EndFunction

// The function gets the style font by a style item name.
//
// Parameters:
// StyleFontName - String -  the style font name.
//
// Returns:
// Font.
//
Function StyleFont(StyleFontName) Export
	
	Return StyleFonts[StyleFontName];
	
EndFunction

#EndRegion
