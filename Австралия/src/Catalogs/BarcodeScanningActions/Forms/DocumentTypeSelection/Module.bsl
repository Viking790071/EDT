#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	MetadataObjectIDs.Ref AS Ref,
		|	MetadataObjectIDs.Name AS Name,
		|	MetadataObjectIDs.Synonym AS Synonym
		|FROM
		|	Catalog.MetadataObjectIDs AS MetadataObjectIDs
		|WHERE
		|	NOT MetadataObjectIDs.DeletionMark
		|	AND MetadataObjectIDs.Ref IN HIERARCHY(&DocumentsRef)
		|	AND MetadataObjectIDs.Ref <> &DocumentsRef";
	
	Query.SetParameter("DocumentsRef", Catalogs.MetadataObjectIDs.FindByDescription("Documents"));
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	RemovedObjectPrefix = "Obsolete";
	While SelectionDetailRecords.Next() Do
		If Lower(Left(SelectionDetailRecords.Name, StrLen(RemovedObjectPrefix))) <> Lower(RemovedObjectPrefix) Then
			AvailableObjectsForChange.Add(SelectionDetailRecords.Ref, SelectionDetailRecords.Synonym);
		EndIf;
	EndDo;
	
	AvailableObjectsForChange.SortByPresentation();
	
	If Not IsBlankString(Parameters.CurrentObject) Then
		SelectedItem = AvailableObjectsForChange.FindByValue(Parameters.CurrentObject);
		If SelectedItem <> Undefined Then
			Items.AvailableObjectsForChange.CurrentRow = SelectedItem.GetID();
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure AvailableObjectsForChangeSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	Close(Items.AvailableObjectsForChange.CurrentData.Value);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Select(Command)
	CurrentData = Items.AvailableObjectsForChange.CurrentData;
	If CurrentData <> Undefined Then
		Close(CurrentData.Value);
	EndIf;
EndProcedure

#EndRegion
