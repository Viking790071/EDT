#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	ColumnsList = Parameters.ColumnsList;
	ColumnsList.SortByPresentation();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Choice(Command)
	Close(ColumnsList);
EndProcedure

#EndRegion

#Region SelectionTableItemsEventHandlers

&AtClient
Procedure ColumnsListSelection(Item, RowSelected, Field, StandardProcessing)
	ColumnsList.FindByID(RowSelected).Check = NOT ColumnsList.FindByID(RowSelected).Check;
EndProcedure

&AtClient
Procedure ColumnsListOnStartEdit(Item, NewRow, Clone)
	Row = ColumnsList.FindByID(Items.ColumnsList.CurrentRow);
	If StrStartsWith(Row.Value, "ContactInformation_") Then
		For Each ColumnInformation In ColumnsList Do
			If StrStartsWith(ColumnInformation.Value, "AdditionalAttribute_") Then
				ColumnInformation.Check = False;
			EndIf;
		EndDo;
	ElsIf StrStartsWith(Row.Value, "AdditionalAttribute_") Then
		For Each ColumnInformation In ColumnsList Do
			If StrStartsWith(ColumnInformation.Value, "ContactInformation_") Then
				ColumnInformation.Check = False;
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion