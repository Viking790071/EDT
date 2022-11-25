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
	CommonClientServer.SetDynamicListFilterItem(
		List, "Executed", False);
			
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	Items.DueDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	Items.StartDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	Items.Date.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	
	// Setting dynamic list filter.
	CommonClientServer.SetDynamicListFilterItem(
		List, "DeletionMark", False, DataCompositionComparisonType.Equal, , ,
		DataCompositionSettingsItemViewMode.Normal);
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	GroupByColumnOnServer(Settings["GroupingMode"]);
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "Write_PerformerTask" Then
		RefreshTasksListOnServer();
	EndIf;
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
Procedure OpenBusinessProcess(Command)
	BusinessProcessesAndTasksClient.OpenBusinessProcess(Items.List);
EndProcedure

&AtClient
Procedure OpenTaskSubject(Command)
	BusinessProcessesAndTasksClient.OpenTaskSubject(Items.List);
EndProcedure

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

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	// Hide the second grouping line.
	TaskListColumns = New Array();
	SelectAllSubordinateItems(Items.Columns_Group, TaskListColumns);
	For each FormItem In TaskListColumns Do
		
		If FormItem = Items.Description Then
			Continue;
		EndIf;
		ItemField = Item.Fields.Items.Add();
		ItemField.Field = New DataCompositionField(FormItem.Name);
		
	EndDo;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("List.Ref");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;

	Item.Appearance.SetParameterValue("Visible", False);
	
	BusinessProcessesAndTasksServer.SetTaskAppearance(List);
	
EndProcedure

&AtServer
Procedure SelectAllSubordinateItems(Parent, Result)
	
	For each FormItem In Parent.ChildItems Do
		
		Result.Add(FormItem);
		If TypeOf(FormItem) = Type("FormGroup") Then
			SelectAllSubordinateItems(FormItem, Result); 
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure GroupByColumn(Val AttributeColumnName)
	GroupingMode = AttributeColumnName;
	List.Group.Items.Clear();
	If NOT IsBlankString(AttributeColumnName) Then
		GroupField = List.Group.Items.Add(Type("DataCompositionGroupField"));
		GroupField.Field = New DataCompositionField(AttributeColumnName);
	EndIf;
EndProcedure

&AtServer
Procedure GroupByColumnOnServer(Val AttributeColumnName)
	GroupingMode = AttributeColumnName;
	List.Group.Items.Clear();
	If NOT IsBlankString(AttributeColumnName) Then
		GroupField = List.Group.Items.Add(Type("DataCompositionGroupField"));
		GroupField.Field = New DataCompositionField(AttributeColumnName);
	EndIf;
EndProcedure

&AtServer
Procedure RefreshTasksListOnServer()
	
	BusinessProcessesAndTasksServer.SetMyTasksListParameters(List);
	// The color of overdue tasks depends on the current date value. Refreshing conditional appearance.
	// 
	SetConditionalAppearance();
	Items.List.Refresh();
	
EndProcedure

#EndRegion
