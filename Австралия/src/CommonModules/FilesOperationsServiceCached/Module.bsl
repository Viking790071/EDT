////////////////////////////////////////////////////////////////////////////////
// File functions subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Common and personal file operation settings.

// Returns a structure that contains CommonSettings and PersonalSettings.
Function FilesOperationSettings() Export
	
	CommonSettings        = New Structure;
	PersonalSettings = New Structure;
	
	FilesOperationsInternalServerCall.AddFilesOperationsSettings(CommonSettings, PersonalSettings);
	
	AddFilesOperationsSettings(CommonSettings, PersonalSettings);
	
	Settings = New Structure;
	Settings.Insert("CommonSettings",        CommonSettings);
	Settings.Insert("PersonalSettings", PersonalSettings);
	
	Return Settings;
	
EndFunction

// Sets common and personal file function settings.
Procedure AddFilesOperationsSettings(CommonSettings, PersonalSettings)
	
	SetPrivilegedMode(True);
	
	// Filling common settings
	
	// ExtractFilesTextsAtServer.
	CommonSettings.Insert(
		"ExtractTextFilesOnServer", FilesOperationsInternal.ExtractTextFilesOnServer());
	
	// MaxFileSize.
	CommonSettings.Insert("MaxFileSize", FilesOperations.MaxFileSize());
	
	// DenyImportFilesByExtension.
	DenyImportFilesByExtension = Constants.DenyUploadFilesByExtension.Get();
	If DenyImportFilesByExtension = Undefined Then
		DenyImportFilesByExtension = False;
		Constants.DenyUploadFilesByExtension.Set(DenyImportFilesByExtension);
	EndIf;
	CommonSettings.Insert("FilesImportByExtensionDenied", DenyImportFilesByExtension);
	
	// DeniedExtensionsList.
	CommonSettings.Insert("DeniedExtensionsList", DeniedExtensionsList());
	
	// OpenDocumentFilesExtensionsList.
	CommonSettings.Insert("FilesExtensionsListOpenDocument", FilesExtensionsListOpenDocument());
	
	// TestFilesExtensionsList.
	CommonSettings.Insert("TestFilesExtensionsList", TestFilesExtensionsList());
	
	// Filling personal settings.
	
	// LocalFileCacheMaxSize.
	LocalFileCacheMaxSize = Common.CommonSettingsStorageLoad(
		"LocalFileCache", "LocalFileCacheMaxSize");
	
	If LocalFileCacheMaxSize = Undefined Then
		LocalFileCacheMaxSize = 100*1024*1024; // 100 MB.
		
		Common.CommonSettingsStorageSave(
			"LocalFileCache",
			"LocalFileCacheMaxSize",
			LocalFileCacheMaxSize);
	EndIf;
	
	PersonalSettings.Insert(
		"LocalFileCacheMaxSize",
		LocalFileCacheMaxSize);
	
	// PathToLocalFileCache.
	PathToLocalFileCache = Common.CommonSettingsStorageLoad(
		"LocalFileCache", "PathToLocalFileCache");
	// Do not get this variable directly.
	// Use the UserWorkingDirectory function of the FilesOperationsInternalClient module.
	// 
	PersonalSettings.Insert("PathToLocalFileCache", PathToLocalFileCache);
	
	// DeleteFileFromLocalFileCacheOnCompleteEdit.
	DeleteFileFromLocalFileCacheOnCompleteEdit =
		Common.CommonSettingsStorageLoad(
			"LocalFileCache", "DeleteFileFromLocalFileCacheOnCompleteEdit");
	
	If DeleteFileFromLocalFileCacheOnCompleteEdit = Undefined Then
		DeleteFileFromLocalFileCacheOnCompleteEdit = False;
	EndIf;
	
	PersonalSettings.Insert(
		"DeleteFileFromLocalFileCacheOnCompleteEdit",
		DeleteFileFromLocalFileCacheOnCompleteEdit);
	
	// ConfirmOnDeleteFilesFromLocalCache.
	ConfirmOnDeleteFilesFromLocalCache =
		Common.CommonSettingsStorageLoad(
			"LocalFileCache", "ConfirmOnDeleteFilesFromLocalCache");
	
	If ConfirmOnDeleteFilesFromLocalCache = Undefined Then
		ConfirmOnDeleteFilesFromLocalCache = False;
	EndIf;
	
	PersonalSettings.Insert(
		"ConfirmOnDeleteFilesFromLocalCache",
		ConfirmOnDeleteFilesFromLocalCache);
	
	// ShowTooltipsOnEditFiles.
	ShowTooltipsOnEditFiles = Common.CommonSettingsStorageLoad(
		"ApplicationSettings", "ShowTooltipsOnEditFiles");
	
	If ShowTooltipsOnEditFiles = Undefined Then
		ShowTooltipsOnEditFiles = True;
		
		Common.CommonSettingsStorageSave(
			"ApplicationSettings",
			"ShowTooltipsOnEditFiles",
			ShowTooltipsOnEditFiles);
	EndIf;
	PersonalSettings.Insert(
		"ShowTooltipsOnEditFiles",
		ShowTooltipsOnEditFiles);
	
	// ShowFileNotModifiedFlag.
	ShowFileNotModifiedFlag = Common.CommonSettingsStorageLoad(
		"ApplicationSettings", "ShowFileNotModifiedFlag");
	
	If ShowFileNotModifiedFlag = Undefined Then
		ShowFileNotModifiedFlag = True;
		
		Common.CommonSettingsStorageSave(
			"ApplicationSettings",
			"ShowFileNotModifiedFlag",
			ShowFileNotModifiedFlag);
	EndIf;
	PersonalSettings.Insert(
		"ShowFileNotModifiedFlag",
		ShowFileNotModifiedFlag);
	
	// File opening settings.
	TextFilesExtension = Common.CommonSettingsStorageLoad(
		"OpenFileSettings\TextFiles",
		"Extension", "TXT XML INI");
	
	TextFilesOpeningMethod = Common.CommonSettingsStorageLoad(
		"OpenFileSettings\TextFiles", 
		"OpeningMethod",
		Enums.OpenFileForViewingMethods.UsingBuiltInEditor);
	
	GraphicalSchemasExtension = Common.CommonSettingsStorageLoad(
		"OpenFileSettings\GraphicalSchemas", "Extension", "GRS");
	
	GraphicalSchemasOpeningMethod = Common.CommonSettingsStorageLoad(
		"OpenFileSettings\GraphicalSchemas",
		"OpeningMethod",
		Enums.OpenFileForViewingMethods.UsingBuiltInEditor);
	
	PersonalSettings.Insert("TextFilesExtension",       TextFilesExtension);
	PersonalSettings.Insert("TextFilesOpeningMethod",   TextFilesOpeningMethod);
	PersonalSettings.Insert("GraphicalSchemasExtension",     GraphicalSchemasExtension);
	PersonalSettings.Insert("GraphicalSchemasOpeningMethod", GraphicalSchemasOpeningMethod);
	
EndProcedure

Function DeniedExtensionsList()
	
	SetPrivilegedMode(True);
	
	DeniedDataAreaExtensionsList =
		Constants.DeniedDataAreaExtensionsList.Get();
	
	If DeniedDataAreaExtensionsList = Undefined
	 OR DeniedDataAreaExtensionsList = "" Then
		
		DeniedDataAreaExtensionsList = "COM EXE BAT CMD VBS VBE JS JSE WSF WSH SCR";
		
		Constants.DeniedDataAreaExtensionsList.Set(
			DeniedDataAreaExtensionsList);
	EndIf;
	
	FinalExtensionList = "";
	
	If Common.DataSeparationEnabled()
	   AND Common.SeparatedDataUsageAvailable() Then
		
		DeniedExtensionsList = Constants.DeniedExtensionsList.Get();
		
		FinalExtensionList = 
			DeniedExtensionsList + " "  + DeniedDataAreaExtensionsList;
	Else
		FinalExtensionList = DeniedDataAreaExtensionsList;
	EndIf;
		
	Return FinalExtensionList;
	
EndFunction

Function FilesExtensionsListOpenDocument()
	
	SetPrivilegedMode(True);
	
	FilesExtensionsListDocumentDataAreas =
		Constants.FilesExtensionsListDocumentDataAreas.Get();
	
	If FilesExtensionsListDocumentDataAreas = Undefined
	 OR FilesExtensionsListDocumentDataAreas = "" Then
		
		FilesExtensionsListDocumentDataAreas =
			"ODT OTT ODP OTP ODS OTS ODC OTC ODF OTF ODM OTH SDW STW SXW STC SXC SDC SDD STI";
		
		Constants.FilesExtensionsListDocumentDataAreas.Set(
			FilesExtensionsListDocumentDataAreas);
	EndIf;
	
	FinalExtensionList = "";
	
	If Common.DataSeparationEnabled()
	   AND Common.SeparatedDataUsageAvailable() Then
		
		DeniedExtensionsList = Constants.FilesExtensionsListOpenDocument.Get();
		
		FinalExtensionList =
			DeniedExtensionsList + " "  + FilesExtensionsListDocumentDataAreas;
	Else
		FinalExtensionList = FilesExtensionsListDocumentDataAreas;
	EndIf;
	
	Return FinalExtensionList;
	
EndFunction

Function TestFilesExtensionsList()

	SetPrivilegedMode(True);
	
	TestFilesExtensionsList = Constants.TestFilesExtensionsList.Get();
	
	If IsBlankString(TestFilesExtensionsList) Then
		TestFilesExtensionsList = "TXT";
	EndIf;
	
	Return TestFilesExtensionsList;

EndFunction

// Returns the flag showing whether the node belongs to DIB exchange plan.
//
// Parameters:
//  FullExchangePlanName - String - an exchange plan string that requires receiving the function value.
// 
//  Returns:
//   True - the node belongs to DIB exchange plan. Otherwise, False.
//
Function IsDistributedInfobaseNode(FullExchangePlanName) Export

	Return Metadata.FindByFullName(FullExchangePlanName).DistributedInfoBase;
	
EndFunction

#EndRegion
