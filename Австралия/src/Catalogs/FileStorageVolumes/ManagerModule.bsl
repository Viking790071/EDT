#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchObjectsModification

// Returns object attributes allowed to be edited using bench attribute change data processor.
// 
//
// Returns:
//  Array - a list of object attribute names.
Function AttributesToEditInBatchProcessing() Export
	
	AttributesToEdit = New Array;
	AttributesToEdit.Add("Comment");
	
	Return AttributesToEdit;
	
EndFunction

// End StandardSubsystems.BatchObjectModification

#EndRegion

#EndRegion

#Region Private

// For internal use only.
Procedure AddRequestsToUseExternalResourcesForAllVolumes(Queries) Export
	
	If Common.DataSeparationEnabled() AND Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	FileStorageVolumes.Ref AS Ref,
	|	FileStorageVolumes.FullPathLinux,
	|	FileStorageVolumes.FullPathWindows,
	|	FileStorageVolumes.DeletionMark AS DeletionMark
	|FROM
	|	Catalog.FileStorageVolumes AS FileStorageVolumes
	|WHERE
	|	FileStorageVolumes.DeletionMark = FALSE";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		Queries.Add(RequestToUseExternalResourcesForVolume(
			Selection.Ref, Selection.FullPathWindows, Selection.FullPathLinux));
	EndDo;
	
EndProcedure

// For internal use only.
Procedure AddRequestsToStopUsingExternalResourcesForAllVolumes(Queries) Export
	
	If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
		Query = New Query;
		Query.Text =
		"SELECT
		|	FileStorageVolumes.Ref AS Ref,
		|	FileStorageVolumes.FullPathLinux,
		|	FileStorageVolumes.FullPathWindows,
		|	FileStorageVolumes.DeletionMark AS DeletionMark
		|FROM
		|	Catalog.FileStorageVolumes AS FileStorageVolumes";
		
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			Queries.Add(ModuleSafeModeManager.RequestToClearPermissionsToUseExternalResources(
				Selection.Ref));
		EndDo;
	EndIf;
	
EndProcedure

// For internal use only.
Function RequestToUseExternalResourcesForVolume(Volume, FullPathWindows, FullPathLinux) Export
	
	If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
		Permissions = New Array;
		
		If ValueIsFilled(FullPathWindows) Then
			Permissions.Add(ModuleSafeModeManager.PermissionToUseFileSystemDirectory(
				FullPathWindows, True, True));
		EndIf;
		
		If ValueIsFilled(FullPathLinux) Then
			Permissions.Add(ModuleSafeModeManager.PermissionToUseFileSystemDirectory(
				FullPathLinux, True, True));
		EndIf;
		
		Return ModuleSafeModeManager.RequestToUseExternalResources(Permissions, Volume);
	EndIf;
	
EndFunction

#EndRegion

#EndIf
