
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;

	// Appearance of items marked for deletion.
	ConditionalAppearanceItem = List.ConditionalAppearance.Items.Add();
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("TextColor");
	AppearanceColorItem.Value = Metadata.StyleItems.InaccessibleCellTextColor.Value;
	AppearanceColorItem.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("DeletionMark");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = True;
	DataFilterItem.Use  = True;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_File"
	   AND Parameter.Property("Event")
	   AND (    Parameter.Event = "EditFinished"
	      OR Parameter.Event = "VersionSaved") Then
		
		Items.List.Refresh();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ListChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(FileOwner(RowSelected), RowSelected, UUID);
	FilesOperationsInternalClient.OpenFileVersion(Undefined, FileData, UUID);
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure ListBeforeDelete(Item, Cancel)
	
	FileData = FilesOperationsInternalServerCall.FileData(Items.List.CurrentRow);
	If FileData.CurrentVersion = Items.List.CurrentRow Then
		ShowMessageBox(, NStr("ru = 'Активную версию нельзя удалить.'; en = 'Active version cannot be deleted.'; pl = 'Nie można usunąć aktywnej wersji.';es_ES = 'Versión del archivo no puede borrarse.';es_CO = 'Versión del archivo no puede borrarse.';tr = 'Aktif sürüm silinemez.';it = 'Versione attiva non può essere eliminata.';de = 'Aktive Version kann nicht gelöscht werden.'"));
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeChangeRow(Item, Cancel)
	Cancel = True;
	OpenFileCard();
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure OpenFileCard()
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then 
		
		Version = CurrentData.Ref;
		
		FormOpenParameters = New Structure("Key", Version);
		OpenForm("DataProcessor.FilesOperations.Form.AttachedFileVersion", FormOpenParameters);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function FileOwner(SelectedRow)
	Return SelectedRow.Owner;
EndFunction


#EndRegion