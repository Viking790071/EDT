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
	
	FormTitleText = "";
	If Parameters.Property("FormCaption", FormTitleText) 
		AND Not IsBlankString(FormTitleText) Then
		Title = FormTitleText;
		AutoTitle = False;
	EndIf;
	
	If Parameters.Property("BusinessProcess") Then
		BusinessProcessLine = Parameters.BusinessProcess;
		TaskLine = Parameters.Task;
		Items.TitleGroup.Visible = True;
	EndIf;
	
	If Parameters.Property("ShowTasks") Then
		ShowTasks = Parameters.ShowTasks;
	Else
		ShowTasks = 2;
	EndIf;
	
	If Parameters.Property("FiltersVisibility") Then
		Items.FilterGroup.Visible = Parameters.FiltersVisibility;
	Else
		ByAuthor = Users.AuthorizedUser();
	EndIf;
	SetFilter();
	
	If Parameters.Property("OwnerWindowLock") Then
		WindowOpeningMode = Parameters.OwnerWindowLock;
	EndIf;
		
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	Items.DueDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	Items.CompletionDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	
	If UsersClientServer.IsExternalUserSession() Then
		Items.ByAuthor.Visible = False;
		Items.ByPerformer.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_PerformerTask" Then
		RefreshTasksListOnServer();
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeLoadDataFromSettingsAtServer(Settings)

	SettingName = ?(Parameters.Property("BusinessProcess"), "BPListForm", "ListForm");
	FilterSettings = Common.SystemSettingsStorageLoad("Tasks.PerformerTask.Forms.ListForm", SettingName);
	If FilterSettings = Undefined Then 
		Settings.Clear();
		Return;
	EndIf;
	
	For Each Item In FilterSettings Do
		Settings.Insert(Item.Key, Item.Value);
	EndDo;
	SetListFilter(List, FilterSettings);
	
EndProcedure

&AtServer
Procedure OnSaveDataInSettingsAtServer(Settings)
	SettingsName = ?(Items.TitleGroup.Visible, "BPListForm", "ListForm");
	Common.SystemSettingsStorageSave("Tasks.PerformerTask.Forms.ListForm", SettingsName, Settings);
EndProcedure

&AtClient
Procedure NavigationProcessing(NavigationObject, StandardProcessing)
	
	If Not ValueIsFilled(NavigationObject) Or NavigationObject = Items.List.CurrentRow Then
		Return;
	EndIf;
	
	ByAuthor = Undefined;
	ByPerformer = Undefined;
	ShowTasks = 0;
	SetFilter();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ByPerformerOnChange(Item)
	SetFilter();
EndProcedure

&AtClient
Procedure ByAuthorOnChange(Item)
	SetFilter();
EndProcedure

&AtClient
Procedure ShowTasksOnChange(Item)
	SetFilter();
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
	If TypeOf(Items.List.CurrentRow) <> Type("TaskRef.PerformerTask") Then
		ShowMessageBox(,NStr("ru = 'Команда не может быть выполнена для указанного объекта.'; en = 'Cannot run the command for the specified object.'; pl = 'Polecenie nie może być uruchomione dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Belirtilen nesne için komut işletilemez.';it = 'Non è possibile eseguire il comando per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'"));
		Return;
	EndIf;
	If Items.List.CurrentData.BusinessProcess = Undefined Then
		ShowMessageBox(,NStr("ru = 'У выбранной задачи не указан бизнес-процесс.'; en = 'Business process of the selected task is not specified.'; pl = 'Proces biznesowy wybranego zadania nie jest określony.';es_ES = 'No se ha especificado el proceso de negocio de la tarea seleccionada.';es_CO = 'No se ha especificado el proceso de negocio de la tarea seleccionada.';tr = 'Seçilen görevin iş süreci belirtilmedi.';it = 'Nel processo selezionato non è indicato nessun processo aziendale.';de = 'Geschäftsprozess der ausgewählten Aufgabe nicht angegeben.'"));
		Return;
	EndIf;
	ShowValue(, Items.List.CurrentData.BusinessProcess);
EndProcedure

&AtClient
Procedure OpenTaskSubject(Command)
	If TypeOf(Items.List.CurrentRow) <> Type("TaskRef.PerformerTask") Then
		ShowMessageBox(,NStr("ru = 'Команда не может быть выполнена для указанного объекта.'; en = 'Cannot run the command for the specified object.'; pl = 'Polecenie nie może być uruchomione dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Belirtilen nesne için komut işletilemez.';it = 'Non è possibile eseguire il comando per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'"));
		Return;
	EndIf;
	If Items.List.CurrentData.Topic = Undefined Then
		ShowMessageBox(,NStr("ru = 'У выбранной задачи не указан предмет.'; en = 'Subject of the selected task is not specified.'; pl = 'Temat wybranego zadania nie jest określony.';es_ES = 'No se ha especificado el tema de la tarea seleccionada.';es_CO = 'No se ha especificado el tema de la tarea seleccionada.';tr = 'Seçilen görevin konusu belirtilmedi.';it = 'Nel processo selezionato non è indicato un oggetto.';de = 'Thema der ausgewählten Aufgabe nicht angegeben.'"));
		Return;
	EndIf;
	ShowValue(, Items.List.CurrentData.Topic);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetFilter()
	
	FilterParameters = New Map();
	FilterParameters.Insert("ByAuthor", ByAuthor);
	FilterParameters.Insert("ByPerformer", ByPerformer);
	FilterParameters.Insert("ShowTasks", ShowTasks);
	SetListFilter(List, FilterParameters);
	
EndProcedure	

&AtServerNoContext
Procedure SetListFilter(List, FilterParameters)
	
	CommonClientServer.SetDynamicListFilterItem(
		List, "Author", FilterParameters["ByAuthor"],,, FilterParameters["ByAuthor"] <> Undefined AND Not FilterParameters["ByAuthor"].IsEmpty());
	
	If FilterParameters["ByPerformer"] = Undefined Or FilterParameters["ByPerformer"].IsEmpty() Then
		List.Parameters.SetParameterValue("SelectedPerformer", NULL);
	Else	
		List.Parameters.SetParameterValue("SelectedPerformer", FilterParameters["ByPerformer"]);
	EndIf;
		
	If FilterParameters["ShowTasks"] = 0 Then 
		CommonClientServer.SetDynamicListFilterItem(
			List, "Executed", True,,,False);
	ElsIf FilterParameters["ShowTasks"] = 1 Then
		CommonClientServer.SetDynamicListFilterItem(
			List, "Executed", True,,,True);
	ElsIf FilterParameters["ShowTasks"] = 2 Then
		CommonClientServer.SetDynamicListFilterItem(
			List, "Executed", False,,,True);
	EndIf;	
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	BusinessProcessesAndTasksServer.SetTaskAppearance(List);
	
EndProcedure

&AtServer
Procedure RefreshTasksListOnServer()
	
	BusinessProcessesAndTasksServer.SetTaskAppearance(List);
	// The color of overdue tasks depends on the current date value. Refreshing conditional appearance.
	// 
	SetConditionalAppearance();
	Items.List.Refresh();
	
EndProcedure

#EndRegion
