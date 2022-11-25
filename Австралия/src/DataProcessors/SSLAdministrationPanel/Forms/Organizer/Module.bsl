#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		If Users.IsFullUser() Then
			HasEmail = Common.SubsystemExists("StandardSubsystems.EmailOperations");
			ScheduledJob = FindScheduledJob("TaskMonitoring");
			If HasEmail AND ScheduledJob <> Undefined Then
				TasksMonitoringUsage = ScheduledJob.Use;
				TaskMonitoringSchedule    = ScheduledJob.Schedule;
			Else
				Items.TasksMonitoringGroup.Visible = False;
			EndIf;
			ScheduledJob = FindScheduledJob("NewPerformerTaskNotifications");
			If HasEmail AND ScheduledJob <> Undefined Then
				NotifyPerformersAboutNewTasksUsage = ScheduledJob.Use;
				NewPerformerTaskNotificationsSchedule    = ScheduledJob.Schedule;
			Else
				Items.NotifyPerformersAboutNewTasksGroup.Visible = False;
			EndIf;
		Else
			Items.TasksMonitoringGroup.Visible = False;
			Items.NotifyPerformersAboutNewTasksGroup.Visible = False;
		EndIf;
		
		If Common.DataSeparationEnabled() Then
			Items.TasksMonitoringConfigureSchedule.Visible = False;
			Items.NotifyPerformersAboutNewTasksConfigureSchedule.Visible = False;
		EndIf;
	Else
		Items.BusinessProcessesAndTasksGroup.Visible = False;
	EndIf;
	
	// Update items states.
	SetAvailability();
	
	ApplicationSettingsOverridable.OrganizerOnCreateAtServer(ThisObject);
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	If Exit Then
		Return;
	EndIf;
	UpdateApplicationInterface();
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName <> "Write_ConstantsSet" Then
		Return;
	EndIf;
	
	If Source = "UseExternalUsers" Then
		
		ThisObject.Read();
		SetAvailability();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UseOtherInteractionsOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure SendEmailsInHTMLFormatOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure UseReviewedFlagOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure UseNotesOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure UseUserRemindersOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure UseMessagesTemplatesOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure UseBusinessProcessesAndTasksOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure UseSubordinateBusinessProcessesOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure UseEmailClientOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure UseQuestioningOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure ChangeJobsBackdatedOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure UseTaskStartDateOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure UseDateAndTimeInTaskDeadlinesOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure UseDocumentEventOnChange(Item)
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure RolesAndTaskPerformers(Command)
	
	If CommonClient.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksClient = CommonClient.CommonModule("BusinessProcessesAndTasksClient");
		ModuleBusinessProcessesAndTasksClient.OpenRolesAndTaskPerformersList();
	EndIf;
	
EndProcedure

&AtClient
Procedure TasksMonitoringConfigureSchedule(Command)
	Dialog = New ScheduledJobDialog(TaskMonitoringSchedule);
	Dialog.Show(New NotifyDescription("TaskMonitoringAfterScheduleChanged", ThisObject));
EndProcedure

&AtClient
Procedure NotifyPerformersAboutNewTasksConfigureSchedule(Command)
	Dialog = New ScheduledJobDialog(NewPerformerTaskNotificationsSchedule);
	Dialog.Show(New NotifyDescription("NewPerformerTaskNotificationsAfterChangeSchedule", ThisObject));
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure Attachable_OnChangeAttribute(Item, UpdateInterface = True)
	
	ConstantName = OnChangeAttributeServer(Item.Name);
	
	RefreshReusableValues();
	
	If UpdateInterface Then
		RefreshInterface = True;
		AttachIdleHandler("UpdateApplicationInterface", 2, True);
	EndIf;
	
	If ConstantName <> "" Then
		Notify("Write_ConstantsSet", New Structure, ConstantName);
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		CommonClient.RefreshApplicationInterface();
	EndIf;
	
EndProcedure

&AtClient
Procedure TaskMonitoringAfterScheduleChanged(Schedule, ExecutionParameters) Export
	If Schedule = Undefined Then
		Return;
	EndIf;
	
	TaskMonitoringSchedule = Schedule;
	TasksMonitoringUsage = True;
	WriteScheduledJob("TaskMonitoring", TasksMonitoringUsage, 
		TaskMonitoringSchedule, "TaskMonitoringSchedule");
EndProcedure

&AtClient
Procedure NewPerformerTaskNotificationsAfterChangeSchedule(Schedule, ExecutionParameters) Export
	If Schedule = Undefined Then
		Return;
	EndIf;
	
	NewPerformerTaskNotificationsSchedule = Schedule;
	NotifyPerformersAboutNewTasksUsage = True;
	WriteScheduledJob("NewPerformerTaskNotifications", NotifyPerformersAboutNewTasksUsage, 
		NewPerformerTaskNotificationsSchedule, "NewPerformerTaskNotificationsSchedule");
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Function OnChangeAttributeServer(ItemName)
	
	DataPathAttribute = Items[ItemName].DataPath;
	
	ValidateAbilityToChangeAttributeValue(DataPathAttribute);
	
	ConstantName = SaveAttributeValue(DataPathAttribute);
	
	SetAvailability(DataPathAttribute);
	
	RefreshReusableValues();
	
	Return ConstantName;
	
EndFunction

&AtServer
Function SaveAttributeValue(DataPathAttribute)
	
	// Save values of attributes not directly related to constants (in ratio one to one).
	If DataPathAttribute = "" Then
		Return "";
	EndIf;
	
	// Define the constant name.
	ConstantName = "";
	Position = StrFind(DataPathAttribute, "ConstantsSet.");
	If Position > 0 Then
		ConstantName = StrReplace(DataPathAttribute, "ConstantsSet.", "");
	Else
		// Define the name and record the attribute value in the constant from the ConstantsSet.
		// It is used for those form attributes that are directly related to constants (in ratio one to one).
	EndIf;
	
	// Save the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
		
		If (ConstantName = "UseEmailClient" OR ConstantName = "UseBusinessProcessesAndTasks") AND ConstantValue = False Then
			ThisObject.Read();
		EndIf;
	EndIf;
	
	Return ConstantName;
	
EndFunction

&AtServer
Procedure SetAvailability(DataPathAttribute = "")
	
	If (DataPathAttribute = "ConstantsSet.UseEmailClient" OR DataPathAttribute = "")
		AND Common.SubsystemExists("StandardSubsystems.Interactions") Then
		
		Items.UseOtherInteractions.Enabled             = ConstantsSet.UseEmailClient;
		Items.UseReviewedFlag.Enabled               = ConstantsSet.UseEmailClient;
		Items.SendEmailsInHTMLFormat.Enabled                 = ConstantsSet.UseEmailClient;
		
	EndIf;
	
	If (DataPathAttribute = "ConstantsSet.UseBusinessProcessesAndTasks" OR DataPathAttribute = "")
		AND Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		
		Items.OpenRolesAndPerformersForBusinessProcesses.Enabled = ConstantsSet.UseBusinessProcessesAndTasks;
		Items.UseSubordinateBusinessProcesses.Enabled  = ConstantsSet.UseBusinessProcessesAndTasks;
		Items.ChangeJobsBackdated.Enabled            = ConstantsSet.UseBusinessProcessesAndTasks;
		Items.UseTaskStartDate.Enabled            = ConstantsSet.UseBusinessProcessesAndTasks;
		Items.UseDateAndTimeInTaskDeadlines.Enabled     = ConstantsSet.UseBusinessProcessesAndTasks;
		Items.TasksMonitoringGroup.Enabled					= ConstantsSet.UseBusinessProcessesAndTasks;
		Items.NotifyPerformersAboutNewTasksGroup.Enabled = ConstantsSet.UseBusinessProcessesAndTasks;
		
	EndIf;
	
	If Items.TasksMonitoringGroup.Visible
		AND (DataPathAttribute = "TaskMonitoringSchedule" Or DataPathAttribute = "")
		AND Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		Items.TasksMonitoringConfigureSchedule.Enabled	= TasksMonitoringUsage;
		If TasksMonitoringUsage Then
			SchedulePresentation = String(TaskMonitoringSchedule);
			Presentation = Upper(Left(SchedulePresentation, 1)) + Mid(SchedulePresentation, 2);
		Else
			Presentation = "";
		EndIf;
		Items.TasksMonitoringNote.Title = Presentation;
	EndIf;
	
	If Items.NotifyPerformersAboutNewTasksGroup.Visible
		AND (DataPathAttribute = "NewPerformerTaskNotificationsSchedule" Or DataPathAttribute = "")
		AND Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		Items.NotifyPerformersAboutNewTasksConfigureSchedule.Enabled	= NotifyPerformersAboutNewTasksUsage;
		If NotifyPerformersAboutNewTasksUsage Then
			SchedulePresentation = String(NewPerformerTaskNotificationsSchedule);
			Presentation = Upper(Left(SchedulePresentation, 1)) + Mid(SchedulePresentation, 2);
		Else
			Presentation = "";
		EndIf;
		Items.NotifyPerformersAboutNewTasksNote.Title = Presentation;
	EndIf;
	
	If DataPathAttribute = "" Then
		
		Items.UseDocumentEvent.Visible = ConstantsSet.UseDocumentEvent;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure WriteScheduledJob(PredefinedItemName, Usage, Schedule, DataPathAttribute)
	ScheduledJob = FindScheduledJob(PredefinedItemName);
	
	JobParameters = New Structure;
	JobParameters.Insert("Use", Usage);
	JobParameters.Insert("Schedule", Schedule);
	
	ScheduledJobsServer.ChangeJob(ScheduledJob, JobParameters);
	
	If DataPathAttribute <> Undefined Then
		SetAvailability(DataPathAttribute);
	EndIf;
EndProcedure

&AtServer
Function FindScheduledJob(PredefinedItemName)
	Filter = New Structure;
	Filter.Insert("Metadata", PredefinedItemName);
	
	SearchResult = ScheduledJobsServer.FindJobs(Filter);
	Return ?(SearchResult.Count() = 0, Undefined, SearchResult[0]);
EndFunction

&AtClient
Procedure TasksMonitoringUseOnChange(Item)
	WriteScheduledJob("TaskMonitoring", TasksMonitoringUsage, 
		TaskMonitoringSchedule, "TaskMonitoringSchedule");
EndProcedure

&AtClient
Procedure NotifyAssigneesOfNewTasksUseOnChange(Item)
	WriteScheduledJob("NewPerformerTaskNotifications", NotifyPerformersAboutNewTasksUsage, 
		NewPerformerTaskNotificationsSchedule, "NewPerformerTaskNotificationsSchedule");
EndProcedure

&AtServer
Function ValidateAbilityToChangeAttributeValue(AttributePathToData)
	
	If AttributePathToData = "ConstantsSet.UseBusinessProcessesAndTasks" Then
		
		If Constants.UseBusinessProcessesAndTasks.Get() <> ConstantsSet.UseBusinessProcessesAndTasks
			And (Not ConstantsSet.UseBusinessProcessesAndTasks) Then
			
			ThereAreDocuments = Documents.PurchaseOrder.GetDocumentsWithAprrovalStatus();
			If ThereAreDocuments Then
				
				ConstantsSet.UseBusinessProcessesAndTasks = True;
				
				ErrorText = NStr("en = 'You cannot disable ""Business processes and tasks"", because ""Purchase order approval"" is in use.'; ru = 'Отключение опции ""Бизнес-процессы и задачи"" при использовании опции ""Утверждение заказа поставщику"" невозможно.';pl = 'Nie możesz wyłączyć ""Procesy biznesowe i zadania"", ponieważ jest używane ""Zatwierdzenie zamówienia zakupu"".';es_ES = 'No puede desactivar ""Procesos de negocio y tareas"", porque ""Aprobación de la orden de compra"" está en uso.';es_CO = 'No puede desactivar ""Procesos de negocio y tareas"", porque ""Aprobación de la orden de compra"" está en uso.';tr = '""Satın alma siparişi onayı"" kullanımda olduğundan ""İş süreçleri ve görevler"" devre dışı bırakılamıyor.';it = 'Impossibile disattivare ""Processi aziendali e incarichi"", poiché è in uso ""Approvazione ordini di acquisto"".';de = 'Sie können ""Geschäftsprozesse und Aufgaben"" nicht deaktivieren, denn ""Genehmigung der Bestellung an Lieferanten"" ist verwendet.'");
				CommonClientServer.MessageToUser(ErrorText, , AttributePathToData);
				
			EndIf;
		EndIf;
		
	EndIf;
		
EndFunction

#EndRegion
