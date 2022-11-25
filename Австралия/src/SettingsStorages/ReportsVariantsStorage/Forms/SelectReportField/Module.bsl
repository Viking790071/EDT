#Region Variables

&AtClient
Var NodesToExpand;
&AtClient
Var NumberOfNodesToExpand;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not Parameters.Property("SettingsComposer", SettingsComposer) Then
		Raise NStr("ru = 'The ""SettingsComposer"" service parameter is not passed.'; en = 'The ""SettingsComposer"" service parameter is not passed.'; pl = 'The ""SettingsComposer"" service parameter is not passed.';es_ES = 'The ""SettingsComposer"" service parameter is not passed.';es_CO = 'The ""SettingsComposer"" service parameter is not passed.';tr = 'The ""SettingsComposer"" service parameter is not passed.';it = 'The ""SettingsComposer"" service parameter is not passed.';de = 'The ""SettingsComposer"" service parameter is not passed.'");
	EndIf;
	If Not Parameters.Property("Mode", Mode) Then
		Raise NStr("ru = 'Service parameter ""Mode"" is not transferred.'; en = 'Service parameter ""Mode"" is not transferred.'; pl = 'Service parameter ""Mode"" is not transferred.';es_ES = 'Service parameter ""Mode"" is not transferred.';es_CO = 'Service parameter ""Mode"" is not transferred.';tr = 'Service parameter ""Mode"" is not transferred.';it = 'Service parameter ""Mode"" is not transferred.';de = 'Service parameter ""Mode"" is not transferred.'");
	EndIf;
	If Mode = "GroupComposition" Or Mode = "OptionStructure" Then
		TableName = "GroupFields";
	ElsIf Mode = "Filters" Or Mode = "SelectedFields" Or Mode = "Sort" Or Mode = "GroupFields" Then
		TableName = Mode;
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Incorrect value of parameter ""Mode"": ""%1"".'; en = 'Incorrect value of parameter ""Mode"": ""%1"".'; pl = 'Incorrect value of parameter ""Mode"": ""%1"".';es_ES = 'Incorrect value of parameter ""Mode"": ""%1"".';es_CO = 'Incorrect value of parameter ""Mode"": ""%1"".';tr = 'Incorrect value of parameter ""Mode"": ""%1"".';it = 'Incorrect value of parameter ""Mode"": ""%1"".';de = 'Incorrect value of parameter ""Mode"": ""%1"".'"), String(Mode));
	EndIf;
	If Not Parameters.Property("ReportSettings", ReportSettings) Then
		Raise NStr("ru = 'The ""ReportSettings"" service parameter is not passed.'; en = 'The ""ReportSettings"" service parameter is not passed.'; pl = 'The ""ReportSettings"" service parameter is not passed.';es_ES = 'The ""ReportSettings"" service parameter is not passed.';es_CO = 'The ""ReportSettings"" service parameter is not passed.';tr = 'The ""ReportSettings"" service parameter is not passed.';it = 'The ""ReportSettings"" service parameter is not passed.';de = 'The ""ReportSettings"" service parameter is not passed.'");
	EndIf;
	If Parameters.Property("CurrentDCNodeID", CurrentDCNodeID)
		AND CurrentDCNodeID <> Undefined Then
		DCCurrentNode = SettingsComposer.Settings.GetObjectByID(CurrentDCNodeID);
		If TypeOf(DCCurrentNode) = Type("DataCompositionTableStructureItemCollection")
			Or TypeOf(DCCurrentNode) = Type("DataCompositionChartStructureItemCollection")
			Or TypeOf(DCCurrentNode) = Type("DataCompositionTable")
			Or TypeOf(DCCurrentNode) = Type("DataCompositionChart") Then
			CurrentDCNodeID = Undefined;
		EndIf;
	EndIf;
	
	If TableName = "GroupFields" Then
		TreeItems = GroupFields.GetItems();
		GroupFieldsExpandRow(DCTable(ThisObject), TreeItems);
		If Mode = "OptionStructure" Then
			TreeRow = TreeItems.Add();
			TreeRow.Presentation  = NStr("ru = '<Detailed records>'; en = '<Detailed records>'; pl = '<Detailed records>';es_ES = '<Detailed records>';es_CO = '<Detailed records>';tr = '<Detailed records>';it = '<Detailed records>';de = '<Detailed records>'");
			TreeRow.PictureIndex = ReportsClientServer.PictureIndex("Item", "Predefined");
		EndIf;
	EndIf;
	
	DCField = Undefined;
	Parameters.Property("DCField", DCField);
	If DCField <> Undefined Then
		DCTable = DCTable(ThisObject);
		AvailableDCField = DCTable.FindField(DCField);
		If AvailableDCField <> Undefined Then
			Items[TableName + "Table"].CurrentRow = DCTable.GetIDByObject(AvailableDCField);
		EndIf;
	EndIf;
	
	Items.Pages.CurrentPage = Items[TableName + "Page"];
	
	Source = New DataCompositionAvailableSettingsSource(ReportSettings.SchemaURL);
	SettingsComposer.Initialize(Source);
	
	CloseOnChoice = False;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	NodesToExpand = New Array;
	NumberOfNodesToExpand = 0;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure Select(Command)
	SelectAndClose();
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersFiltersTable

&AtClient
Procedure FiltersTableChoice(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	SelectAndClose();
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersSelectedFieldsTable

&AtClient
Procedure SelectedFieldsTableChoice(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	SelectAndClose();
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersSortTable

&AtClient
Procedure SortTableChoice(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	SelectAndClose();
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersGroupFields

&AtClient
Procedure GroupFieldsTableBeforeExpand(Item, Row, Cancel)
	If NumberOfNodesToExpand > 10 Then
		Cancel = True;
		Return;
	EndIf;
	TreeRow = GroupFields.FindByID(Row);
	If TreeRow = Undefined Then
		Cancel = True;
		Return;
	EndIf;
	If TreeRow.ReadNestedItems Then // Not all nodes have to be expanded.
		NumberOfNodesToExpand = NumberOfNodesToExpand + 1;
		NodesToExpand.Add(Row);
		AttachIdleHandler("ExpandGroupFieldLines", 0.1, True); // Protection against hanging by Ctrl_Shift_+.
		TreeRow.GetItems().Clear(); // So that the user does not see intermediate effects.
	EndIf;
EndProcedure

&AtClient
Procedure GroupFieldsTableChoice(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	SelectAndClose();
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure SelectAndClose()
	TableItem = Items[TableName + "Table"];
	If TableName = "GroupFields" Then
		TreeRow = TableItem.CurrentData;
		If TreeRow = Undefined Then
			Return;
		EndIf;
		DCID = TreeRow.DCID;
	Else
		DCID = TableItem.CurrentRow;
	EndIf;
	If DCID = Undefined Then
		If TableName = "GroupFields" Then
			AvailableDCField = "<>";
		Else
			Return;
		EndIf;
	Else
		AvailableDCField = DCTable(ThisObject).GetObjectByID(DCID);
		If AvailableDCField = Undefined Then
			Return;
		EndIf;
	EndIf;
	If TypeOf(AvailableDCField) = Type("DataCompositionAvailableField")
		Or TypeOf(AvailableDCField) = Type("DataCompositionFilterAvailableField") Then
		If AvailableDCField.Folder Then
			ShowMessageBox(, NStr("ru = 'Select the item'; en = 'Select the item'; pl = 'Select the item';es_ES = 'Select the item';es_CO = 'Select the item';tr = 'Select the item';it = 'Select the item';de = 'Select the item'"));
			Return;
		EndIf;
	EndIf;
	NotifyChoice(AvailableDCField);
	Close(AvailableDCField);
EndProcedure

&AtClient
Procedure ExpandGroupFieldLines()
	ExpandServerCallGroupFieldsRows(NodesToExpand);
	NodesToExpand.Clear();
	NumberOfNodesToExpand = 0;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client, Server

&AtClientAtServerNoContext
Function DCTable(ThisObject)
	If ThisObject.TableName = "Filters" Then
		Return ThisObject.SettingsComposer.Settings.Filter.FilterAvailableFields;
	ElsIf ThisObject.TableName = "SelectedFields" Then
		Return ThisObject.SettingsComposer.Settings.Selection.SelectionAvailableFields;
	ElsIf ThisObject.TableName = "Sort" Then
		Return ThisObject.SettingsComposer.Settings.Order.OrderAvailableFields;
	ElsIf ThisObject.TableName = "GroupFields" Then
		If ThisObject.CurrentDCNodeID = Undefined Then
			DCCurrentNode = ThisObject.SettingsComposer.Settings;
		Else
			DCCurrentNode = ThisObject.SettingsComposer.Settings.GetObjectByID(ThisObject.CurrentDCNodeID);
		EndIf;
		If TypeOf(DCCurrentNode) = Type("DataCompositionSettings") Then
			Return DCCurrentNode.GroupAvailableFields;
		Else
			Return DCCurrentNode.GroupFields.GroupFieldsAvailableFields;
		EndIf;
	EndIf;
EndFunction

&AtClientAtServerNoContext
Procedure ExpandClientServerGroupFieldsRows(DCTable, GroupFields, NodesToExpand)
	Total = 0;
	For Each RowID In NodesToExpand Do
		TreeRow = GroupFields.FindByID(RowID);
		If TreeRow = Undefined Then
			Continue;
		EndIf;
		If Not TreeRow.ReadNestedItems Then
			Continue;
		EndIf;
		TreeRow.ReadNestedItems = False;
		AvailableDCField = DCTable.GetObjectByID(TreeRow.DCID);
		TreeRows = TreeRow.GetItems();
		TreeRows.Clear();
		GroupFieldsExpandRow(DCTable, TreeRows, AvailableDCField, Total);
	EndDo;
EndProcedure

&AtClientAtServerNoContext
Procedure GroupFieldsExpandRow(DCTable, TreeRows, AvailableDCFieldParent = Undefined, Total = 0)
	If AvailableDCFieldParent = Undefined Then
		AvailableDCFieldParent = DCTable;
		Prefix = "";
	Else
		Prefix = AvailableDCFieldParent.Title + ".";
	EndIf;
	
	Total = Total + AvailableDCFieldParent.Items.Count();
	CalculateNumber = (Total <= 100);
	For Each AvailableDCField In AvailableDCFieldParent.Items Do
		If TypeOf(AvailableDCField) = Type("DataCompositionAvailableField") Then
			TreeRow = TreeRows.Add();
			TreeRow.Presentation = StrReplace(AvailableDCField.Title, Prefix, "");
			TreeRow.DCID = DCTable.GetIDByObject(AvailableDCField);
			If AvailableDCField.Table Then
				Type = "Table";
			ElsIf AvailableDCField.Resource Then
				Type = "Resource";
			ElsIf AvailableDCField.Folder Then
				Type = "Folder";
			Else
				Type = "Item";
			EndIf;
			TreeRow.PictureIndex = ReportsClientServer.PictureIndex(Type);
			
			// Collecting the "AvailableDCField.Items" collection sometimes makes an implicit server call.
			If CalculateNumber Then
				TreeRow.ReadNestedItems = AvailableDCField.Items.Count() > 0;
			Else
				TreeRow.ReadNestedItems = True;
			EndIf;
			If TreeRow.ReadNestedItems Then
				TreeRow.GetItems().Add().Presentation = "...";
			EndIf;
		EndIf;
	EndDo;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server call, Server

&AtServer
Procedure ExpandServerCallGroupFieldsRows(NodesToExpand)
	ExpandClientServerGroupFieldsRows(DCTable(ThisObject), GroupFields, NodesToExpand);
EndProcedure

#EndRegion