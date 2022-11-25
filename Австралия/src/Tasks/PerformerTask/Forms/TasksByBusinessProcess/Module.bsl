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
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	
	If UseSubordinateBusinessProcesses Then
		Items.List.Visible = False;
		Items.CommonCommandBar.Visible = False;
		Items.TasksTree.Visible = True;
	Else	
		Items.List.Visible = True;
		Items.CommonCommandBar.Visible = True;
		Items.TasksTree.Visible = False;
	EndIf;	
		
	Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Задачи бизнес-процесса %1'; en = 'Tasks of business process %1'; pl = 'Zadania procesu biznesowego %1';es_ES = 'Tareas del proceso de negocio%1';es_CO = 'Tareas del proceso de negocio%1';tr = 'İş sürecinin görevleri %1';it = 'Obiettivi del processo aziendale %1';de = 'Aufgaben des Geschäftprozesses %1'"), String(Parameters.FilterValue));
		
	If UseSubordinateBusinessProcesses Then 
		FillTaskTree();
		Items.DueDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	Else
		CommonClientServer.SetDynamicListFilterItem(
			List,"BusinessProcess", Parameters.FilterValue);
		CommonClientServer.SetDynamicListFilterItem(
			List, "Executed", False);
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
	
	ShowExecuted = Settings["ShowExecuted"];
	RefreshTasksList();

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ShowExecutedItemsOnChange(Item)
	
	RefreshTasksList();
	
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
	
	FillTaskTree();
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
Procedure RefreshTasksList()
	
	UseSubordinateBusinessProcesses = GetFunctionalOption("UseSubordinateBusinessProcesses");
	If UseSubordinateBusinessProcesses Then 
		FillTaskTree();
	Else
		CommonClientServer.DeleteDynamicListFilterGroupItems(List, "Executed");
		If NOT ShowExecuted Then
			CommonClientServer.SetDynamicListFilterItem(
				List, "Executed", False);
		EndIf;
		Items.List.Refresh();
	EndIf;
	// The color of overdue tasks depends on the current date value. Refreshing conditional appearance.
	// 
	BusinessProcessesAndTasksServer.SetTaskAppearance(List); 
	
EndProcedure

&AtClient
Procedure OpenCurrentTaskTreeLine()
	
	If Items.TasksTree.CurrentData = Undefined Then
		Return;
	EndIf;
	
	ShowValue(,Items.TasksTree.CurrentData.Ref);
	
EndProcedure

&AtServer
Procedure FillTaskTree()
	
	Tree = FormAttributeToValue("TasksTree");
	Tree.Rows.Clear();
	
	AddSubordinateBusinessProcessTasks(Tree, Parameters.FilterValue);
	
	ValueToFormAttribute(Tree, "TasksTree");
	
EndProcedure	

&AtServer
Procedure AddSubordinateBusinessProcesses(Tree, TaskRef)
	
	Branch = Tree.Rows.Find(TaskRef, "Ref", True);
	
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
			
			Row = Branch.Rows.Add();
			
			Row.Description = DetailedRecordsSelection.Description;
			Row.Importance = DetailedRecordsSelection.Importance;
			Row.Stopped = DetailedRecordsSelection.Stopped;
			Row.Ref = DetailedRecordsSelection.Ref;
			Row.Executed = DetailedRecordsSelection.Completed;
			Row.Type = 0;
			
			AddSubordinateBusinessProcessTasks(Tree, DetailedRecordsSelection.Ref);
			
		EndDo;
		
	EndDo;	

EndProcedure

&AtServer
Procedure AddSubordinateBusinessProcessTasks(Tree, BusinessProcessRef)
	
	Branch = Tree.Rows.Find(BusinessProcessRef, "Ref", True);
	
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
		|	Tasks.BusinessProcess = &BusinessProcess
		|	AND Tasks.DeletionMark = FALSE";
	If Not ShowExecuted Then	
		Query.Text = Query.Text + "
			|	AND Tasks.Executed = &Executed";
		Query.SetParameter("Executed", False);
	EndIf;	
	Query.SetParameter("BusinessProcess", BusinessProcessRef);

	Result = Query.Execute();
	
	DetailedRecordsSelection = Result.Select();

	While DetailedRecordsSelection.Next() Do
		
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

#EndRegion
