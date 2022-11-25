#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	Var Cache;
	
	Filling = False;
	If Parameters.Property("Filling") Then
		Filling = Parameters.Filling;
	EndIf;
	
	ItemsTree = GetFromTempStorage(Parameters.ReportItemsAddress);
	TreeRow = FinancialReportingClientServer.ChildItem(ItemsTree, "ItemStructureAddress", Parameters.ItemAddressInTempStorage);
	AvailableItemsList = FinancialReportingServer.ItemValuesSources(Cache, TreeRow, Filling);
	
	PreviousSourcesTable = Parameters.ValuesSources.Unload(New Structure("AddedDocumentValues", False));
	SourcesTree = FormAttributeToValue("ValuesSources");
	
	NewRow = Undefined;
	For Each AvailableItemsRow In AvailableItemsList Do
		Item = AvailableItemsRow.Item;
		If ValueIsFilled(AvailableItemsRow.Parent) Then
			AddingPlace = SourcesTree.Rows.Find(AvailableItemsRow.Parent, "Source", True);
		Else
			AddingPlace = SourcesTree;
		EndIf;
		NewRow = AddingPlace.Rows.Add();
		NewRow.Source = Item;
		If TypeOf(Item) = Type("String") Then
			ObjectAttributes = GetFromTempStorage(Item);
		Else
			ObjectAttributes = New Structure("Ref", Item);
		EndIf;
		NewRow.ItemType = AvailableItemsRow.ItemType;
		NewRow.Presentation = AvailableItemsRow.Description;
		NewRow.NonstandardPicture = FinancialReportingCached.NonstandardPicture(NewRow.ItemType);
		For Each ItemRow In PreviousSourcesTable Do
			If ItemRow.Source = ObjectAttributes.Ref Or ItemRow.Source = Item Then
				NewRow.Use = True;
				Break;
			EndIf;
		EndDo;
	EndDo;
	
	FillFlagsByChildItems(FinancialReportingClientServer.ChildItems(SourcesTree));
	
	ValueToFormAttribute(SourcesTree, "ValuesSources");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ChildRows = FinancialReportingClientServer.ChildItems(ValuesSources);
	For Each ChildRow In ChildRows Do
		Items.ValuesSources.Expand(ChildRow.GetID(), True);
	EndDo;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersValuesSources

&AtClient
Procedure ValuesSourcesUseOnChange(Item)
	
	CurrentData = Items.ValuesSources.CurrentData;
	If CurrentData.Use = 2 Then
		CurrentData.Use = 0;
	EndIf;
	
	FillChildItemsFlags(FinancialReportingClientServer.ChildItems(CurrentData), CurrentData.Use);
	
	Parent = FinancialReportingClientServer.ParentItem(CurrentData);
	While Parent <> Undefined Do
		ChildRows = FinancialReportingClientServer.ChildItems(Parent);
		Parent.Use = FillFlagsByChildItems(ChildRows, False);
		Parent = FinancialReportingClientServer.ParentItem(Parent);
	EndDo;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Select(Command)
	
	Close(GetSelectionResult());
	
EndProcedure

&AtClient
Procedure CheckAll(Command)
	
	FillChildItemsFlags(FinancialReportingClientServer.ChildItems(ValuesSources), 1);
	
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	FillChildItemsFlags(FinancialReportingClientServer.ChildItems(ValuesSources), 0);
	
EndProcedure

&AtClient
Procedure ExpandAll(Command)

	ChildRows = FinancialReportingClientServer.ChildItems(ValuesSources);
	For Each ChildRow In ChildRows Do
		Items.ValuesSources.Expand(ChildRow.GetID(), True);
	EndDo;
	
EndProcedure

&AtClient
Procedure CollapseAll(Command)

	ChildRows = FinancialReportingClientServer.ChildItems(ValuesSources);
	CollapseRow(ChildRows);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure FillChildItemsFlags(Rows, Flag)
	
	For Each Row In Rows Do
		Row.Use = Flag;
		ChildRows = FinancialReportingClientServer.ChildItems(Row);
		FillChildItemsFlags(ChildRows, Flag);
	EndDo;
	
EndProcedure

&AtServer
Function GetSelectionResult()
	
	Result = New Array;
	FoundRows = FormAttributeToValue("ValuesSources").Rows.FindRows(New Structure("Use", 1), True);
	AvailableTypesArray = New Array;
	AvailableTypesArray.Add(Enums.FinancialReportItemsTypes.BudgetItem);
	AvailableTypesArray.Add(Enums.FinancialReportItemsTypes.BudgetIndicator);
	AvailableTypesArray.Add(Enums.FinancialReportItemsTypes.NonfinancialIndicator);
	
	For Each FoundRow In FoundRows Do
		If FoundRow.Rows.Count() Then
			Continue;
		EndIf;
		If AvailableTypesArray.Find(FoundRow.ItemType) = Undefined Then
			Continue;
		EndIf;
		Result.Add(FoundRow.Source);
	EndDo;
	
	Return Result;
	
EndFunction

&AtClientAtServerNoContext
Function FillFlagsByChildItems(TreeRows, IncludeChildItems = True)
	
	CurrentLevelFlagsArray = New Array;
	For Each Row In TreeRows Do
		
		If IncludeChildItems Then
			ChildRows = FinancialReportingClientServer.ChildItems(Row);
		EndIf;
		If IncludeChildItems And ChildRows.Count() Then
			Row.Use = FillFlagsByChildItems(ChildRows);
		EndIf;
		CurrentLevelFlagsArray.Add(Row.Use);
		
	EndDo;
	
	Result = CommonClientServer.CollapseArray(CurrentLevelFlagsArray);
	If Result.Count() = 2 Then
		Return 2;
	ElsIf Result.Count() Then
		Return Result[0];
	EndIf;
	
EndFunction

&AtClient
Procedure CollapseRow(TreeRows)
	
	For Each Row In TreeRows Do
		ChildRows = FinancialReportingClientServer.ChildItems(Row);
		CollapseRow(ChildRows);
		Items.ValuesSources.Collapse(Row.GetID());
	EndDo;
	
EndProcedure

#EndRegion
