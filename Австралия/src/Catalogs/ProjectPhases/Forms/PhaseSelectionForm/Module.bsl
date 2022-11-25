
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Title") Then
		Title = Parameters.Title;
	EndIf;
	
	If Parameters.Property("Selected") Then
		For Each Row In Parameters.Selected Do
			NewRow = Selected.Add();
			NewRow.Ref = Row;
		EndDo;
	EndIf;
	
	ShowDeleted = False;
	SetFilter(List, ShowDeleted);
	
	SetConditionalAppearanceOnCreate();
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	ShowDeleted = Settings["ShowDeleted"];
	SetFilter(List, ShowDeleted);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListValueChoice(Item, Value, StandardProcessing)
	
	StandardProcessing = False;
	
	IncludeAtClient();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ShowDeleted(Command)
	
	ShowDeleted = Not ShowDeleted;
	SetFilter(List, ShowDeleted);
	
EndProcedure

&AtClient
Procedure Include(Command)
	
	IncludeAtClient();
	
EndProcedure

&AtClient
Procedure Exclude(Command)
	
	If Items.Selected.SelectedRows.Count() > 0 Then
		
		For Each Row In Items.Selected.SelectedRows Do
			RowByID = Selected.FindByID(Row);
			Selected.Delete(RowByID);
		EndDo;
		
	EndIf;
	
EndProcedure


&AtClient
Procedure Select(Command)
	
	If Selected.Count() = 0 Then
		IncludeAtClient();
	EndIf;
	
	Result = New Array;
	For Each Row In Selected Do
		Result.Add(Row.Ref);
	EndDo;
	
	NotifyChoice(Result);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure IncludeAtClient()
	
	For Each Row In Items.List.SelectedRows Do
		
		FilterParameters = New Structure("Ref", Row);
		If Selected.FindRows(FilterParameters).Count() = 0 Then
			NewRow = Selected.Add();
			NewRow.Ref = Row;
			Items.Selected.CurrentRow = NewRow.GetID();
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetFilter(List, ShowDeleted)
	
	If ShowDeleted Then
		CommonClientServer.DeleteDynamicListFilterGroupItems(List, "DeletionMark");
	Else
		CommonClientServer.SetDynamicListFilterItem(List, "DeletionMark", False);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearanceOnCreate()
	
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("List.DeletionMark");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Font", New Font("MS Shell Dlg", 8, False, False, False, True, 100));
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("List");
	FieldAppearance.Use = True;
	
EndProcedure

#EndRegion