#Region ListFormTableItemsEventHandlers

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentData = Items.List.CurrentData;
	
	CatalogData = New Structure;
	CatalogData.Insert("Catalog", CurrentData.Ref);
	
	NotifyChoice(CatalogData);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

// The procedure is called when clicking button "Select".
//
&AtClient
Procedure ChooseAccount(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then
		
		CatalogData = New Structure;
		CatalogData.Insert("Catalog", CurrentData.Ref);
		
		NotifyChoice(CatalogData);
		
	Else
		Close();
	EndIf;
	
EndProcedure

// The procedure is called when clicking button "Open catalog".
//
&AtClient
Procedure OpenAccount(Command)
	
	TableRow = Items.List.CurrentData;
	If TableRow <> Undefined Then
		ShowValue(Undefined,TableRow.Ref);
	EndIf;
	
EndProcedure

#EndRegion