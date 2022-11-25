
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.Company.Visible = NOT Parameters.Filter.Property("Company");
	
	If Parameters.Property("Product") Then
		List.Parameters.SetParameterValue("Product", Parameters.Product);
	EndIf;
	
	If Parameters.Property("Characteristic") Then
		List.Parameters.SetParameterValue("Characteristic", Parameters.Characteristic);
	EndIf;
	
	If Parameters.Property("SerialNumber") Then
		List.Parameters.SetParameterValue("SerialNumber", Parameters.SerialNumber);
	EndIf;
	
EndProcedure

#EndRegion

#Region ListFormTableItemsEventHandlers

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentData = Items.List.CurrentData;
	
	DocumentData = New Structure;
	DocumentData.Insert("Document", CurrentData.Ref);
	
	NotifyChoice(DocumentData);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

// The procedure is called when clicking button "Select".
//
&AtClient
Procedure ChooseDocument(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then
		
		DocumentData = New Structure;
		DocumentData.Insert("Document", CurrentData.Ref);
		
		NotifyChoice(DocumentData);
		
	Else
		Close();
	EndIf;
	
EndProcedure

// The procedure is called when clicking button "Open document".
//
&AtClient
Procedure OpenDocument(Command)
	
	TableRow = Items.List.CurrentData;
	If TableRow <> Undefined Then
		ShowValue(Undefined,TableRow.Ref);
	EndIf;
	
EndProcedure

#EndRegion

