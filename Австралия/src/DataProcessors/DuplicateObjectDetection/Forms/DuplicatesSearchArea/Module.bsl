// The following parameters are expected:
//
//     AreaToSearchForDuplicates - Row - full metadata table name of the area selected for search.
//
// Returns the selection result:
//
//     Undefined - to cancel editing.
//     Row - address of the temporary storage with new composer settings.
//

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Parameters.Property("DuplicatesSearchArea", DefaultArea);
	Parameters.Property("SettingsAddress", SettingsAddress);
	
	InitializeAreasToSearchForDuplicatesList();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AreasToSearchForDuplicatesSelection(Item, RowSelected, Field, StandardProcessing)
	
	MakeChoice(RowSelected);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)
	
	MakeChoice(Items.DuplicatesSearchAreas.CurrentRow);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure MakeChoice(Val RowID)
	
	Item = DuplicatesSearchAreas.FindByID(RowID);
	If Item = Undefined Then
		Return;
		
	ElsIf Item.Value = DefaultArea Then
		// Does not contain changes
		Close();
		Return;
		
	EndIf;
	
	NotifyChoice(Item.Value);
EndProcedure

&AtServer
Procedure InitializeAreasToSearchForDuplicatesList()
	If ValueIsFilled(SettingsAddress)
		AND IsTempStorageURL(SettingsAddress) Then
		SettingsTable = GetFromTempStorage(SettingsAddress);
	Else
		SettingsTable = DuplicateObjectDetection.MetadataObjectsSettings();
		SettingsAddress = PutToTempStorage(SettingsTable, UUID);
	EndIf;
	
	For Each TableRow In SettingsTable Do
		Item = DuplicatesSearchAreas.Add(TableRow.FullName, TableRow.ListPresentation, , PictureLib[TableRow.Kind]);
		If TableRow.FullName = DefaultArea Then
			Items.DuplicatesSearchAreas.CurrentRow = Item.GetID();
		EndIf;
	EndDo;
EndProcedure

#EndRegion