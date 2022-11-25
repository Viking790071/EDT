
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If ValueIsFilled(Parameters.FileOwner) Then 
		List.Parameters.SetParameterValue(
			"Owner", Parameters.FileOwner);
	
		If TypeOf(Parameters.FileOwner) = Type("CatalogRef.FileFolders") Then
			Items.Folders.CurrentRow = Parameters.FileOwner;
			Items.Folders.SelectedRows.Clear();
			Items.Folders.SelectedRows.Add(Items.Folders.CurrentRow);
		Else
			Items.Folders.Visible = False;
		EndIf;
	Else
		If Parameters.SelectTemplate Then
			
			CommonClientServer.SetDynamicListFilterItem(
				Folders, "Ref", Catalogs.FileFolders.Templates,
				DataCompositionComparisonType.InHierarchy, , True);
			
			Items.Folders.CurrentRow = Catalogs.FileFolders.Templates;
			Items.Folders.SelectedRows.Clear();
			Items.Folders.SelectedRows.Add(Items.Folders.CurrentRow);
		EndIf;
		
		List.Parameters.SetParameterValue("Owner", Items.Folders.CurrentRow);
	EndIf;
	
EndProcedure

#EndRegion

#Region FolderFormTableItemsEventHandlers

&AtClient
Procedure FoldersOnActivateRow(Item)
	AttachIdleHandler("IdleHandler", 0.2, True);
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListValueChoice(Item, Value, StandardProcessing)
	
	FileRef = Items.List.CurrentRow;
	
	Parameter = New Structure;
	Parameter.Insert("FileRef", FileRef);
	
	NotifyChoice(Parameter);
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure IdleHandler()
	
	If Items.Folders.CurrentRow <> Undefined Then
		List.Parameters.SetParameterValue("Owner", Items.Folders.CurrentRow);
	EndIf;
	
EndProcedure

#EndRegion
