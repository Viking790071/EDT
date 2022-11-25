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
	
	UseSubordinateBusinessProcesses = GetFunctionalOption("UseSubordinateBusinessProcesses");	
	
	If UseSubordinateBusinessProcesses Then
		Items.List.Visible = False;
		Items.CommonCommandBar.Visible = False;
		Items.ShowExecuted.Visible = False;
		Items.TasksTree.Visible = True;
	Else	
		Items.List.Visible = True;
		Items.CommonCommandBar.Visible = True;
		Items.ShowExecuted.Visible = True;
		Items.TasksTree.Visible = False;
	EndIf;	
	
	List.Parameters.Items[0].Value = Parameters.FilterValue;
	List.Parameters.Items[0].Use = True;
	Title = NStr("ru = 'Задачи по предмету'; en = 'Tasks by subject'; pl = 'Zadania według tematu';es_ES = 'Tareas por tema';es_CO = 'Tareas por tema';tr = 'Konuya göre görevler';it = 'Incarichi per soggetto';de = 'Aufgaben nach dem Thema'");
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	Items.DueDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	SetFilter(New Structure("ShowExecuted", ShowExecuted));
	
	If UseSubordinateBusinessProcesses Then 
		FillTaskTree();
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "Write_PerformerTask" Then
		RefreshTasksList();
	EndIf;
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	SetFilter(Settings);
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ShowExecutedItemsOnChange(Item)
	SetFilter(New Structure("ShowExecuted", ShowExecuted));
EndProcedure

#EndRegion

#Region TaskTreeFormTableItemEventHandlers

&AtClient
Procedure TaskTreeChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	OpenCurrentTaskTreeLine();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Update(Command)
	
	RefreshTasksList();
	For each Row In TasksTree.GetItems() Do
		Items.TasksTree.Expand(Row.GetID(), True);
	EndDo;
	
EndProcedure

&AtClient
Procedure Change(Command)
	
	OpenCurrentTaskTreeLine();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TasksTree.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("TasksTree.Overdue");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.OverdueDataColor);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TasksTree.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("TasksTree.Executed");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.CompletedBusinessProcess);

	BusinessProcessesAndTasksServer.SetTaskAppearance(List);
	
EndProcedure

&AtServer
Procedure SetFilter(FilterParameters)
	
	CommonClientServer.DeleteDynamicListFilterGroupItems(List, "Executed");
	If NOT FilterParameters["ShowExecuted"] Then
		CommonClientServer.SetDynamicListFilterItem(
			List, "Executed", False);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillTaskTree()
	
	Tree = FormAttributeToValue("TasksTree");
	Tree.Rows.Clear();
	
	AddTasksBySubject(Tree, Parameters.FilterValue);
	
	ValueToFormAttribute(Tree, "TasksTree");
	
EndProcedure	

&AtServer
Procedure RefreshTasksList()
	
	UseSubordinateBusinessProcesses = GetFunctionalOption("UseSubordinateBusinessProcesses");
	If UseSubordinateBusinessProcesses Then 
		FillTaskTree();
	Else
		Items.List.Refresh();
		// The color of overdue tasks depends on the current date value. Refreshing conditional appearance.
		// 
		BusinessProcessesAndTasksServer.SetTaskAppearance(List); 
	EndIf;
	
EndProcedure

&AtServer
Procedure AddTasksBySubject(Tree, Topic)
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	Tasks.Ref,
		|	Tasks.Description,
		|	Tasks.Performer,
		|	Tasks.PerformerRole,
		|	Tasks.DueDate,
		|	Tasks.Executed,
		|	CASE
		|		WHEN Tasks.Importance = VALUE(Enum.TaskImportanceOptions.Low)
		|			THEN 0
		|		WHEN Tasks.Importance = VALUE(Enum.TaskImportanceOptions.High)
		|			THEN 2
		|		ELSE 1
		|	END AS Importance,
		|	CASE
		|		WHEN Tasks.BusinessProcessState = VALUE(Enum.BusinessProcessStates.Stopped)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS Stopped
		|FROM
		|	Task.PerformerTask AS Tasks
		|WHERE
		|   Tasks.Topic = &Topic
		|   AND Tasks.DeletionMark = FALSE";
		
	Query.SetParameter("Topic", Topic);

	Result = Query.Execute();
	
	DetailedRecordsSelection = Result.Select();

	While DetailedRecordsSelection.Next() Do
		
		Branch = Tree.Rows.Find(DetailedRecordsSelection.Ref, "Ref", True);
		If Branch = Undefined Then
			Row = Tree.Rows.Add();
			
			Row.Description = DetailedRecordsSelection.Description;
			Row.Importance = DetailedRecordsSelection.Importance;
			Row.Type = 1;
			Row.Stopped = DetailedRecordsSelection.Stopped;
			Row.Ref = DetailedRecordsSelection.Ref;
			Row.DueDate = DetailedRecordsSelection.DueDate;
			Row.Executed = DetailedRecordsSelection.Executed;
			If DetailedRecordsSelection.DueDate <> "00010101"
				AND DetailedRecordsSelection.DueDate < CurrentSessionDate() Then
				Row.Overdue = True;
			EndIf;
			If ValueIsFilled(DetailedRecordsSelection.Performer) Then
				Row.Performer = DetailedRecordsSelection.Performer;
			Else
				Row.Performer = DetailedRecordsSelection.PerformerRole;
			EndIf;
			
			AddSubordinateBusinessProcesses(Tree, DetailedRecordsSelection.Ref);
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure AddSubordinateBusinessProcesses(Tree, TaskRef)
	
	For each BusinessProcessMetadata In Metadata.BusinessProcesses Do
		
		// Business processes are not required to have a main task.
		MainTaskAttribute = BusinessProcessMetadata.Attributes.Find("MainTask");
		If MainTaskAttribute = Undefined Then
			Continue;
		EndIf;	
		
		Query = New Query;
		Query.Text = 
			"SELECT ALLOWED
			|	BusinessProcesses.Ref,
			|	BusinessProcesses.Description,
			|	BusinessProcesses.Completed,
			|	CASE
			|		WHEN BusinessProcesses.Importance = VALUE(Enum.TaskImportanceOptions.Low)
			|			THEN 0
			|		WHEN BusinessProcesses.Importance = VALUE(Enum.TaskImportanceOptions.High)
			|			THEN 2
			|		ELSE 1
			|	END AS Importance,
			|	CASE
			|		WHEN BusinessProcesses.State = VALUE(Enum.BusinessProcessStates.Stopped)
			|			THEN TRUE
			|		ELSE FALSE
			|	END AS Stopped
			|FROM
			|	%1 AS BusinessProcesses
			|WHERE
			|   BusinessProcesses.MainTask = &MainTask
			|   AND BusinessProcesses.DeletionMark = FALSE";
			
		Query.Text = StringFunctionsClientServer.SubstituteParametersToString(Query.Text, BusinessProcessMetadata.FullName());
		Query.SetParameter("MainTask", TaskRef);

		Result = Query.Execute();
		
		DetailedRecordsSelection = Result.Select();

		While DetailedRecordsSelection.Next() Do
			
			AddSubordinateBusinessProcessTasks(Tree, DetailedRecordsSelection.Ref, TaskRef);
			
		EndDo;
		
	EndDo;	

EndProcedure

&AtServer
Procedure AddSubordinateBusinessProcessTasks(Tree, BusinessProcessRef, TaskRef)
	
	Branch = Tree.Rows.Find(TaskRef, "Ref", True);
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	Tasks.Ref,
		|	Tasks.Description,
		|	Tasks.Performer,
		|	Tasks.PerformerRole,
		|	Tasks.DueDate,
		|	Tasks.Executed,
		|	CASE
		|		WHEN Tasks.Importance = VALUE(Enum.TaskImportanceOptions.Low)
		|			THEN 0
		|		WHEN Tasks.Importance = VALUE(Enum.TaskImportanceOptions.High)
		|			THEN 2
		|		ELSE 1
		|	END AS Importance,
		|	CASE
		|		WHEN Tasks.BusinessProcessState = VALUE(Enum.BusinessProcessStates.Stopped)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS Stopped
		|FROM
		|	Task.PerformerTask AS Tasks
		|WHERE
		|   Tasks.BusinessProcess = &BusinessProcess
		|   AND Tasks.DeletionMark = FALSE";
		
	Query.SetParameter("BusinessProcess", BusinessProcessRef);

	Result = Query.Execute();
	
	DetailedRecordsSelection = Result.Select();

	While DetailedRecordsSelection.Next() Do
		
		FoundBranch = Tree.Rows.Find(DetailedRecordsSelection.Ref, "Ref", True);
		If FoundBranch <> Undefined Then
			Tree.Rows.Delete(FoundBranch);
		EndIf;	
			
		Row = Undefined;
		If Branch = Undefined Then
			Row = Tree.Rows.Add();
		Else	
			Row = Branch.Rows.Add();
		EndIf;
		
		Row.Description = DetailedRecordsSelection.Description;
		Row.Importance = DetailedRecordsSelection.Importance;
		Row.Type = 1;
		Row.Stopped = DetailedRecordsSelection.Stopped;
		Row.Ref = DetailedRecordsSelection.Ref;
		Row.DueDate = DetailedRecordsSelection.DueDate;
		Row.Executed = DetailedRecordsSelection.Executed;
		If DetailedRecordsSelection.DueDate <> '00010101000000' 
			AND DetailedRecordsSelection.DueDate < CurrentSessionDate() Then
			Row.Overdue = True;
		EndIf;
		If ValueIsFilled(DetailedRecordsSelection.Performer) Then
			Row.Performer = DetailedRecordsSelection.Performer;
		Else
			Row.Performer = DetailedRecordsSelection.PerformerRole;
		EndIf;
		
		AddSubordinateBusinessProcesses(Tree, DetailedRecordsSelection.Ref);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure OpenCurrentTaskTreeLine()
	
	If Items.TasksTree.CurrentData = Undefined Then
		Return;
	EndIf;
	
	ShowValue(,Items.TasksTree.CurrentData.Ref);
	
EndProcedure

#EndRegion
