#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	SettingsComposer = Parameters.SettingsComposer;
	ReportSettings = Parameters.ReportSettings;
	
	QuickOnly = CommonClientServer.StructureProperty(Parameters, "QuickOnly", False);
	
	Source = New DataCompositionAvailableSettingsSource(ReportSettings.SchemaURL);
	SettingsComposer.Initialize(Source);
	
	ReportObjectOrFullName = ReportSettings.FullName; // Copying so that the report object does not move to the client structure.
	
	OutputConditions = New Structure;
	OutputConditions.Insert("UserSettingsOnly", True);
	OutputConditions.Insert("QuickOnly",          QuickOnly);
	OutputConditions.Insert("CurrentDCNodeID", Undefined);
	Information = ReportsServer.AdvancedInformationOnSettings(SettingsComposer, ReportSettings, ReportObjectOrFullName, OutputConditions);
	
	SettingsToOutput = Information.UserSettings.Copy(New Structure("OutputAllowed", True));
	SettingsToOutput.Sort("IndexInCollection Asc");
	
	ReportsServer.ClearAdvancedInformationOnSettings(Information);
	
	RowsSet = Filters.GetItems();
	SettingsTypesToOutput = New Array;
	SettingsTypesToOutput.Add("FilterItem");
	For Each SettingProperties In SettingsToOutput Do
		If SettingsTypesToOutput.Find(SettingProperties.Type) = Undefined Then
			Continue;
		EndIf;
		TableRow = RowsSet.Add();
		FillPropertyValues(TableRow, SettingProperties, "DefaultPresentation, ComparisonType, DCID");
		TableRow.ValueType = SettingProperties.TypeDescription;
		TableRow.InitialComparisonType = TableRow.ComparisonType;
	EndDo;
	
	CloseOnChoice = False;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersFiltersTable

&AtClient
Procedure FiltersChoice(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	
	TableRow = Items.Filters.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	ColumnName = Field.Name;
	If ColumnName = "FiltersCondition" Then
		Context = New Structure;
		Context.Insert("TableRow", TableRow);
		Handler = New NotifyDescription("AfterComparisonTypeChoice", ThisObject, Context);
		
		List = ReportsClientServer.ComparisonTypesSelectionList(TableRow.ValueType);
		
		ListItem = List.FindByValue(TableRow.ComparisonType);
		If ListItem <> Undefined Then
			ListItem.Picture = PictureLib.Check;
		EndIf;
		
		ShowChooseFromMenu(Handler, List);
	EndIf;
EndProcedure

&AtClient
Procedure AfterComparisonTypeChoice(ListItem, Context) Export
	If ListItem = Undefined Then
		Return;
	EndIf;
	Context.TableRow.ComparisonType = ListItem.Value;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)
	SelectAndClose();
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SelectAndClose()
	Result = New Map;
	For Each TableRow In Filters.GetItems() Do
		If TableRow.InitialComparisonType <> TableRow.ComparisonType Then
			Result.Insert(TableRow.DCID, TableRow.ComparisonType);
		EndIf;
	EndDo;
	NotifyChoice(Result);
	Close(Result);
EndProcedure

#EndRegion
