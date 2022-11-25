///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	BusinessProcessesAndTasksServer.SetMyTasksListParameters(List);
	FilterParameters = New Map();
	FilterParameters.Insert("ShowExecuted", ShowExecuted);
	SetFilter(FilterParameters);
	
	FormFilterParameters = CommonClientServer.CopyStructure(Parameters.Filter);
	Parameters.Filter.Clear();
	
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	Items.DueDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	Items.StartDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	Items.Date.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	
EndProcedure

&AtServer
Procedure BeforeLoadDataFromSettingsAtServer(Settings)
	
	If FormFilterParameters <> Undefined Then
		// Replacing fixed filter items to unavailable user settings.
		For each FilterItem In FormFilterParameters Do
			CommonClientServer.SetDynamicListFilterItem(
				List, FilterItem.Key, FilterItem.Value);
		EndDo;
		
		FilterValue = Undefined;
		If FormFilterParameters.Property("Executed", FilterValue) Then
			Settings["ShowExecuted"] = FilterValue;
		EndIf;
		
		FormFilterParameters.Clear();
	EndIf;
	
	GroupByColumnOnServer(Settings["GroupingMode"]);
	SetFilter(Settings);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "Write_PerformerTask" Then
		RefreshTasksListOnServer();
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure GroupByImportance(Command)
	GroupByColumn("Importance");
EndProcedure

&AtClient
Procedure GroupByNoGroup(Command)
	GroupByColumn("");
EndProcedure

&AtClient
Procedure GroupByRoutePoint(Command)
	GroupByColumn("RoutePoint");
EndProcedure

&AtClient
Procedure GroupByAuthor(Command)
	GroupByColumn("Author");
EndProcedure

&AtClient
Procedure GroupBySubject(Command)
	GroupByColumn("SubjectString");
EndProcedure

&AtClient
Procedure GroupByDueDate(Command)
	GroupByColumn("GroupDueDate");
EndProcedure

&AtClient
Procedure ShowExecutedItemsOnChange(Item)
	
	SetFilterOnClient();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, Folder)
	BusinessProcessesAndTasksClient.TaskListBeforeAddRow(ThisObject, Item, Cancel, Clone, 
		Parent, Folder);
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	If Item.CurrentData <> Undefined
		AND Item.CurrentData.Property("AcceptedForExecution")
		AND NOT Item.CurrentData.AcceptedForExecution Then
			Items.AcceptForExecution.Enabled= True;
	Else
			Items.AcceptForExecution.Enabled= False;
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure AcceptForExecution(Command)
	
	BusinessProcessesAndTasksClient.AcceptTasksForExecution(Items.List.SelectedRows);
		
EndProcedure

&AtClient
Procedure CancelAcceptForExecution(Command)
	
	BusinessProcessesAndTasksClient.CancelAcceptTasksForExecution(Items.List.SelectedRows);
	
EndProcedure

&AtClient
Procedure RefreshTasksList(Command)
	
	RefreshTasksListOnServer();
	
EndProcedure

&AtClient
Procedure OpenBusinessProcess(Command)
	BusinessProcessesAndTasksClient.OpenBusinessProcess(Items.List);
EndProcedure

&AtClient
Procedure OpenTaskSubject(Command)
	BusinessProcessesAndTasksClient.OpenTaskSubject(Items.List);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	BusinessProcessesAndTasksServer.SetTaskAppearance(List);
	
EndProcedure

&AtClient
Procedure GroupByColumn(Val AttributeColumnName)
	GroupingMode = AttributeColumnName;
	If NOT IsBlankString(GroupingMode) Then
		ShowExecuted = False;
		SetFilterOnClient();
	EndIf;
	List.Group.Items.Clear();
	If NOT IsBlankString(AttributeColumnName) Then
		GroupField = List.Group.Items.Add(Type("DataCompositionGroupField"));
		GroupField.Field = New DataCompositionField(AttributeColumnName);
	EndIf;
EndProcedure

&AtServer
Procedure GroupByColumnOnServer(Val AttributeColumnName)
	GroupingMode = AttributeColumnName;
	If NOT IsBlankString(GroupingMode) Then
		ShowExecuted = False;
		FilterParameters = New Map();
		FilterParameters.Insert("ShowExecuted", ShowExecuted);	
		SetFilter(FilterParameters);	
	EndIf;
	List.Group.Items.Clear();
	If NOT IsBlankString(AttributeColumnName) Then
		GroupField = List.Group.Items.Add(Type("DataCompositionGroupField"));
		GroupField.Field = New DataCompositionField(AttributeColumnName);
	EndIf;
EndProcedure

&AtClient
Procedure SetFilterOnClient()
	
	FilterParameters = New Map();
	FilterParameters.Insert("ShowExecuted", ShowExecuted);	
	SetFilter(FilterParameters);	
	
EndProcedure

&AtServer
Procedure SetFilter(FilterParameters)
	
	If FilterParameters["ShowExecuted"] Then
		GroupByColumnOnServer("");
	EndIf;
	
	CommonClientServer.SetDynamicListFilterItem(
		List, "Executed", False, , , Not FilterParameters["ShowExecuted"]);
		
EndProcedure

&AtServer
Procedure RefreshTasksListOnServer()
	
	BusinessProcessesAndTasksServer.SetMyTasksListParameters(List);
	Items.List.Refresh();
	// The color of overdue tasks depends on the current date value. Refreshing conditional appearance.
	// 
	SetConditionalAppearance();
	
EndProcedure

#EndRegion