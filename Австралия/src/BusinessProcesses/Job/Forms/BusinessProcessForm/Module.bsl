///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Variables

&AtClient
Var PerformerChoiceFormOpened;  // Flag showing that the assignee is selected in a form (without using quick input).
&AtClient
Var SupervisorChoiceFormOpened; // Flag showing that the supervisor is selected in a form (without using quick input).
&AtClient
Var ChoiceContext;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	IsExternalUser = UsersClientServer.IsExternalUserSession();
	
	SetConditionalAppearance();
	
	// Executing form initialization script. For new objects it is executed in OnCreateAtServer.
	// For an existing object it is executed in OnReadAtServer.
	If Object.Ref.IsEmpty() Then
		
		If IsExternalUser Then
			
			Object.Performer = Constants.DefaultSupport.Get();
			
			If Not ValueIsFilled(Object.Topic) Then
				Object.Topic = SessionParameters.CurrentExternalUser;
			EndIf;
			
		EndIf;
		
		InitializeForm();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	RefreshStopCommandsAvailability();
	FormManagment();
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	InitializeForm();
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("CommonForm.SelectPerformerRole") Then
		
		If ChoiceContext = "PerformerOnChange" Then
			
			If TypeOf(SelectedValue) = Type("Structure") Then
				Object.Performer = SelectedValue.PerformerRole;
			EndIf;
			
			SetSupervisorAvailability(ThisObject);
			
		ElsIf ChoiceContext = "SupervisorOnChange" Then
			
			If TypeOf(SelectedValue) = Type("Structure") Then
				Object.Supervisor = SelectedValue.PerformerRole;
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "DeferredStartSettingsChanged" Then
		Deferred = (Parameter.Deferred AND Parameter.State = PredefinedValue("Enum.ProcessesStatesForStart.ReadyToStart"));
		DeferredStartDate = Parameter.DeferredStartDate;
		SetFormItemsProperties(ThisObject, IsExternalUser);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If UsersClientServer.IsExternalUserSession() 
		And Not WriteParameters.Property("Start")
		And Not ValueIsFilled(Object.Ref) Then
		WriteParameters.Insert("Start", True);
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	CheckDeferredProcessEndDate(CurrentObject, Cancel);
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	ChangeJobsBackdated = GetFunctionalOption("ChangeJobsBackdated");
	If InitialStartFlag AND ChangeJobsBackdated Then
		SetPrivilegedMode(True); 
		CurrentObject.ChangeUncompletedTasksAttributes();
	EndIf;

EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_Job", WriteParameters, Object.Ref);
	Notify("Write_PerformerTask", WriteParameters, Undefined);
	If WriteParameters.Property("Start") AND WriteParameters.Start Then
		AttachIdleHandler("UpdateForm", 0.2, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateForm()
	
	SetFormItemsProperties(ThisObject, IsExternalUser);
	RefreshStopCommandsAvailability();
	FormManagment();
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure OnValidationOnChange(Item)
	
	SetSupervisorAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure SubjectClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(,Object.Topic);
	
EndProcedure

&AtClient
Procedure MainTaskClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(,Object.MainTask);
	
EndProcedure

&AtClient
Procedure InfoLabelTitleURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	OpenDeferredStartSetup();
EndProcedure

&AtClient
Procedure StartPerformerChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	BusinessProcessesAndTasksClient.SelectPerformer(Item, Object.Performer);
	
EndProcedure

&AtClient
Procedure PerformerOnChange(Item)
	
	If PerformerChoiceFormOpened = True Then
		Return;
	EndIf;
	
	MainAddressingObject = Undefined;
	AdditionalAddressingObject = Undefined;
	
	If TypeOf(Object.Performer) = Type("CatalogRef.PerformerRoles") AND ValueIsFilled(Object.Performer) Then 
		
		If UsedByAddressingObjects(Object.Performer) Then 
			
			ChoiceContext = "PerformerOnChange";
			
			FormParameters = New Structure;
			FormParameters.Insert("PerformerRole", Object.Performer);
			FormParameters.Insert("MainAddressingObject", MainAddressingObject);
			FormParameters.Insert("AdditionalAddressingObject", AdditionalAddressingObject);
			
			OpenForm("CommonForm.SelectPerformerRole", FormParameters, ThisObject);
			
			Return;
			
		EndIf;
		
	EndIf;
	
	SetSupervisorAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure ProcessPerformerChoice(Item, ValueSelected, StandardProcessing)
	
	PerformerChoiceFormOpened = TypeOf(ValueSelected) = Type("Structure");
	If PerformerChoiceFormOpened Then
		StandardProcessing = False;
		Object.Performer = ValueSelected.PerformerRole;
		Object.MainAddressingObject = ValueSelected.MainAddressingObject;
		Object.AdditionalAddressingObject = ValueSelected.AdditionalAddressingObject;
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure AutoCompletePerformer(Item, Text, ChoiceData, Wait, StandardProcessing)
	
	If ValueIsFilled(Text) Then 
		StandardProcessing = False;
		ChoiceData = BusinessProcessesAndTasksServerCall.GeneratePerformerChoiceData(Text);
	EndIf;
	
EndProcedure

&AtClient
Procedure PerformerTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	If ValueIsFilled(Text) Then 
		StandardProcessing = False;
		ChoiceData = BusinessProcessesAndTasksServerCall.GeneratePerformerChoiceData(Text);
	EndIf;
	
EndProcedure

&AtClient
Procedure StartSupervisorChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	BusinessProcessesAndTasksClient.SelectPerformer(Item, Object.Supervisor);
	
EndProcedure

&AtClient
Procedure SupervisorOnChange(Item)
	
	If SupervisorChoiceFormOpened = True Then
		Return;
	EndIf;
	
	MainAddressingObject = Undefined;
	AdditionalAddressingObject = Undefined;
	
	If TypeOf(Object.Supervisor) = Type("CatalogRef.PerformerRoles") AND ValueIsFilled(Object.Supervisor) Then
		
		If UsedByAddressingObjects(Object.Supervisor) Then
			
			ChoiceContext = "SupervisorOnChange";
			
			FormParameters = New Structure;
			FormParameters.Insert("PerformerRole", Object.Supervisor);
			FormParameters.Insert("MainAddressingObject", MainAddressingObject);
			FormParameters.Insert("AdditionalAddressingObject", AdditionalAddressingObject);
			
			OpenForm("CommonForm.SelectPerformerRole", FormParameters, ThisObject);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessSupervisorChoice(Item, ValueSelected, StandardProcessing)
	
	SupervisorChoiceFormOpened = TypeOf(ValueSelected) = Type("Structure");
	If SupervisorChoiceFormOpened Then
		StandardProcessing = False;
		Object.Supervisor = ValueSelected.PerformerRole;
		Object.MainAddressingObjectSupervisor = ValueSelected.MainAddressingObject;
		Object.AdditionalAddressingObjectSupervisor = ValueSelected.AdditionalAddressingObject;
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure AutoCompleteSupervisor(Item, Text, ChoiceData, Wait, StandardProcessing)
	
	If ValueIsFilled(Text) Then 
		StandardProcessing = False;
		ChoiceData = BusinessProcessesAndTasksServerCall.GeneratePerformerChoiceData(Text);
	EndIf;
	
EndProcedure

&AtClient
Procedure SupervisorTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	If ValueIsFilled(Text) Then 
		StandardProcessing = False;
		ChoiceData = BusinessProcessesAndTasksServerCall.GeneratePerformerChoiceData(Text);
	EndIf;
	
EndProcedure

&AtClient
Procedure DueDateOnChange(Item)
	If Object.DueDate = BegOfDay(Object.DueDate) Then
		Object.DueDate = EndOfDay(Object.DueDate);
	EndIf;
EndProcedure

&AtClient
Procedure VerificationDueDateOnChange(Item)
	If Object.VerificationDueDate = BegOfDay(Object.VerificationDueDate) Then
		Object.VerificationDueDate = EndOfDay(Object.VerificationDueDate);
	EndIf;
EndProcedure

// StandardSubsystems.FilesOperations
&AtClient
Procedure Attachable_PreviewFieldClick(Item, StandardProcessing)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.PreviewFieldClick(ThisObject, Item, StandardProcessing);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_PreviewFieldDragCheck(Item, DragParameters, StandardProcessing)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.PreviewFieldCheckDragging(ThisObject, Item,
			DragParameters, StandardProcessing);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_PreviewFieldDrag(Item, DragParameters, StandardProcessing)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.PreviewFieldDrag(ThisObject, Item,
			DragParameters, StandardProcessing);
	EndIf;
	
EndProcedure
// End StandardSubsystems.FilesOperations

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	ClearMessages();
	If Not CheckFilling() Then
		Return;	
	EndIf;
	
	Write();
	Close();
	
EndProcedure

&AtClient
Procedure Stop(Command)
	
	BusinessProcessesAndTasksClient.StopBusinessProcessFromObjectForm(ThisObject);
	RefreshStopCommandsAvailability();
	
EndProcedure

&AtClient
Procedure ContinueBusinessProcess(Command)
	
	BusinessProcessesAndTasksClient.ContinueBusinessProcessFromObjectForm(ThisObject);
	RefreshStopCommandsAvailability();
	
EndProcedure

&AtClient
Procedure SetUpDeferredStart(Command)
	OpenDeferredStartSetup();
EndProcedure

// StandardSubsystems.FilesOperations
&AtClient
Procedure Attachable_AttachedFilesPanelCommand(Command)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.AttachmentsControlCommand(ThisObject, Command);
	EndIf;
	
EndProcedure
// End StandardSubsystems.FilesOperations

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Supervisor.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.OnValidation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.Supervisor");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("MarkIncomplete", True);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Supervisor.Name);

	FIlterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FIlterGroup1.GroupType = DataCompositionFilterItemsGroupType.OrGroup;

	ItemFilter = FIlterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.OnValidation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	ItemFilter = FIlterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.Supervisor");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Filled;
	Item.Appearance.SetParameterValue("MarkIncomplete", False);

EndProcedure

&AtServer
Procedure InitializeForm()
	
	InitialStartFlag = Object.Started;
	
	SetDeferredStartAttributes();
	
	UseDateAndTimeInTaskDeadlines    = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	ChangeJobsBackdated           = GetFunctionalOption("ChangeJobsBackdated");
	UseSubordinateBusinessProcesses = GetFunctionalOption("UseSubordinateBusinessProcesses");
	
	SubjectString = Common.SubjectString(Object.Topic);
	
	If Object.MainTask = Undefined Or Object.MainTask.IsEmpty() Then
		MainTaskString = NStr("ru = 'не указан'; en = 'not specified'; pl = 'nie określono';es_ES = 'no especificado';es_CO = 'no especificado';tr = 'belirtilmemiş';it = 'non specificato';de = 'keine angabe'");
	Else	
		MainTaskString = String(Object.MainTask);
	EndIf;
	
	SetFormItemsProperties(ThisObject, IsExternalUser);
	
EndProcedure

&AtClient
Procedure RefreshStopCommandsAvailability()
	
	If Object.Completed Then
		
		Items.FormStop.Visible = False;
		Items.FormContinue.Visible = False;
		Return;
		
	EndIf;
	
	If Object.State = PredefinedValue("Enum.BusinessProcessStates.Stopped") Then
		Items.FormStop.Visible = False;
		Items.FormContinue.Visible = True;
	Else
		Items.FormStop.Visible = Object.Started;
		Items.FormContinue.Visible = False;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetSupervisorAvailability(Form)
	
	FieldAvailability = Form.Object.OnValidation;
	Form.Items.SupervisorGroup.Enabled = FieldAvailability;
	
EndProcedure

&AtServerNoContext
Function UsedByAddressingObjects(ObjectToCheck)
	
	Return Common.ObjectAttributeValue(ObjectToCheck, "UsedByAddressingObjects");
	
EndFunction

&AtClientAtServerNoContext
Procedure SetFormItemsProperties(Form, IsExternalUser)
	
	If Form.ReadOnly Then
		Form.Items.FormStop.Visible               = False;
		Form.Items.FormWriteAndClose.Visible         = False;
		Form.Items.FormSetUpDeferredStart.Visible = False;
		Form.Items.FormWrite.Visible                 = False;
		Form.Items.FormContinue.Visible               = False;
	Else
		ObjectStarted = ObjectStarted(Form);
		
		Form.Items.DueDateTime.Visible             = Form.UseDateAndTimeInTaskDeadlines;
		Form.Items.DueDateVerificationTime.Visible               = Form.UseDateAndTimeInTaskDeadlines;
		Form.Items.Date.Format                               = ?(Form.UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
		Form.Items.Topic.Hyperlink                       = Form.Object.Topic <> Undefined AND NOT Form.Object.Topic.IsEmpty();
		Form.Items.FormStartAndClose.Visible              = Not ObjectStarted;
		Form.Items.FormStartAndClose.DefaultButton      = Not ObjectStarted;
		Form.Items.FormStart.Visible                      = Not ObjectStarted;
		Form.Items.FormSetUpDeferredStart.Visible   = Not ObjectStarted;
		Form.Items.FormWriteAndClose.Visible           = ?(Form.Object.Completed, False, ObjectStarted);
		Form.Items.FormWrite.Visible                   = NOT Form.Object.Completed;
		Form.Items.FormWriteAndClose.DefaultButton   = ObjectStarted;
		Form.Items.FormSetUpDeferredStart.Enabled = Not Form.Object.Started;
		
		If Form.Object.MainTask = Undefined Or Form.Object.MainTask.IsEmpty() Then
			Form.Items.MainTask.Hyperlink             = False;
		EndIf;
		
		If Not Form.UseSubordinateBusinessProcesses Then
			Form.Items.MainTask.Visible               = False;
		EndIf;
	EndIf;
	
	SetsPropertiesForStateGroup(Form);
	SetSupervisorAvailability(Form);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetsPropertiesForStateGroup(Form)

	DisplayGroup = Form.Object.Completed Or ObjectStarted(Form);
	Form.Items.StateGroup.Visible = DisplayGroup;
	
	If NOT DisplayGroup Then
		Return;
	EndIf;
	
	RowsArray = New Array;
	Height = 1;
	
	If Form.Object.Completed Then
		EndDateAsString = ?(Form.UseDateAndTimeInTaskDeadlines, 
			Format(Form.Object.CompletedOn, "DLF=DT"), Format(Form.Object.CompletedOn, "DLF=D"));
		TextString = ?(Form.Object.JobCompleted, 
			NStr("ru = 'Задание выполнено %1.'; en = 'Job is completed on %1.'; pl = 'Zadanie zakończono na %1.';es_ES = 'La tarea se ha completado en %1.';es_CO = 'La tarea se ha completado en%1.';tr = 'Görev %1''de tamamlanmıştır.';it = 'Compito completato su %1.';de = 'Die Arbeit ist am %1 abgeschlossen.'"), 
			NStr("ru = 'Задание отменено %1.'; en = 'Job is canceled on %1.'; pl = 'Zadanie jest anulowane na %1.';es_ES = 'La tarea se ha cancelado en %1.';es_CO = 'La tarea se ha cancelado en%1.';tr = 'Görev %1 tarihinde iptal edildi.';it = 'Compito annullato su %1.';de = 'Die Arbeit ist am %1 abgebrochen.'"));
		StateText = StringFunctionsClientServer.SubstituteParametersToString(TextString, EndDateAsString);
		RowsArray.Add(StateText);
		
		For each Item In Form.Items Do
			If TypeOf(Item) <> Type("FormField") AND TypeOf(Item) <> Type("FormGroup") Then
				Continue;
			EndIf;
			Item.ReadOnly = True;
		EndDo;	
		
	ElsIf Form.Object.Started Then
		StateText = ?(Form.ChangeJobsBackdated, 
			NStr("ru = 'Изменения формулировки, важности, автора, а также перенос сроков исполнения и проверки задания вступят в силу немедленно для ранее выданной задачи.'; en = 'Changes to the wording, importance, author, deadline, and verification of the job will take effect immediately for the tasks assigned earlier.'; pl = 'Zmiany w brzmieniu, ważności, autorze, terminie, i weryfikacji pracy wejdą w życie dla zadań przypisanych wcześniej.';es_ES = 'Los cambios en la redacción, la importancia, el autor, la fecha de entrega y la verificación de la tarea surtirán efecto inmediatamente para las tareas asignadas anteriormente.';es_CO = 'Los cambios en la redacción, la importancia, el autor, la fecha de entrega y la verificación de la tarea surtirán efecto inmediatamente para las tareas asignadas anteriormente.';tr = 'Görevin ifade biçimi, önemi, yazarı, bitiş tarihi ve kontrol süresi ile ilgili değişiklikler önceden atanan görevlerle ilgili olarak hemen devreye girecektir.';it = 'Le modifiche a contenuto, importanza, autore, deadline e verifica del compito avranno effetto immediato per gli incarichi assegnati precedentemente.';de = 'Änderungen in Wortlaut, Bedeutung, Autor, Fälligkeitstermin und Verifikation der Arbeit sind für die bisher zugeordneten Aufgaben unmittelbar gültig.'"), 
			NStr("ru = 'Изменения формулировки, важности, автора, а также перенос сроков исполнения и проверки задания не будут отражены в ранее выданной задаче.'; en = 'Changes to the wording, importance, author, deadline, and verification of the job will not be shown in the task assigned earlier.'; pl = 'Zmiany w brzmieniu, ważności, autorze, terminie, i weryfikacji pracy nie będą pokazywane w zadaniu przypisanym wcześniej.';es_ES = 'Los cambios en la redacción, la importancia, el autor, la fecha de entrega y la verificación de la tarea no se mostrarán en la tarea asignada anteriormente.';es_CO = 'Los cambios en la redacción, la importancia, el autor, la fecha de entrega y la verificación de la tarea no se mostrarán en la tarea asignada anteriormente.';tr = 'Görevin ifade biçimi, önemi, yazarı, bitiş tarihi ve kontrol süresi ile ilgili değişiklikler önceden atanan görevde yansımayacaktır.';it = 'Le modifiche a contenuto, importanza, autore, deadline e verifica del compito non saranno mostrate nell''incarico assegnato precedentemente.';de = 'Änderungen in Wortlaut, Bedeutung, Autor, Fälligkeitstermin und Verifikation der Arbeit sind für die bisher zugeordneten Aufgaben nicht angezeigt.'"));
		RowsArray.Add(StateText);
		Height = 2;
		
	ElsIf Form.Deferred Then
		DeferredStartDateAsString = ?(Form.UseDateAndTimeInTaskDeadlines, 
			Format(Form.DeferredStartDate, "DLF=DT"), Format(Form.DeferredStartDate, "DLF=D"));
		StateText = NStr("ru = 'Задание будет запущено'; en = 'Job will be started'; pl = 'Zadanie zostanie rozpoczęte';es_ES = 'La tarea se iniciará';es_CO = 'La tarea se iniciará';tr = 'Görev başlayacaktır';it = 'Il processo sarà riavviato';de = 'Die Arbeit beginnt'") + " ";
		RowsArray.Add(StateText);
		RowsArray.Add(New FormattedString(DeferredStartDateAsString,,,, "OpenDeferredStartSettings"));
	EndIf;
	
	Form.HelpTextTitle = New FormattedString(RowsArray);
	Form.Items.HelpTextTitle.MaxHeight = Height;
	
EndProcedure

&AtServer
Procedure CheckDeferredProcessEndDate(ObjectToCheck, Cancel)

	If Not ValueIsFilled(ObjectToCheck.DueDate) Then
		Return;
	EndIf;
	
	DeferredStartDate = BusinessProcessesAndTasksServer.ProcessDeferredStartDate(ObjectToCheck.Ref);
	
	If ObjectToCheck.DueDate < DeferredStartDate Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Срок исполнения задания не может быть раньше даты начала.'; en = 'Job due date cannot be less than the deferred start date.'; pl = 'Termin pracy nie może być mniejszy niż odroczony data rozpoczęcia.';es_ES = 'La fecha de vencimiento de la tarea no puede ser inferior a la fecha de inicio diferida.';es_CO = 'La fecha de vencimiento de la tarea no puede ser inferior a la fecha de inicio diferida.';tr = 'İşin bitiş tarihi başlangıç tarihinden önce olamaz.';it = 'La data di consegna del lavoro non può essere precedente alla data di inizio differita.';de = 'Das Arbeitsfälligkeitsdatum darf nicht vor dem verzögerten Startdatum liegen.'"),,
			"DueDate", "Object.DueDate");
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenDeferredStartSetup()

	If FormKeyAttributesAreFilledIn() Then
		BusinessProcessesAndTasksClient.SetUpDeferredStart(Object.Ref, Object.DueDate);
	EndIf;

EndProcedure

&AtClient
Function FormKeyAttributesAreFilledIn()

	If Object.Started Then
		Return True;
	EndIf;
	
	ClearMessages();
	
	FormAttributesAreFilledIn = True;
	If NOT ValueIsFilled(Object.Performer) Then
		CommonClientServer.MessageToUser(NStr("ru = 'Поле ""Исполнитель"" не заполнено.'; en = 'Assignee is required.'; pl = 'Wymagany jest wykonawca.';es_ES = 'Se requiere un ejecutor.';es_CO = 'Se requiere un ejecutor.';tr = 'Atanan gerekli.';it = 'Il campo ""Esecutore"" non è compilato.';de = 'Bevollmächtiger ist erforderlich.'"),,
			"Performer", "Object.Performer");
		FormAttributesAreFilledIn = False;
	EndIf;
	If NOT ValueIsFilled(Object.Description) Then
		CommonClientServer.MessageToUser(NStr("ru = 'Поле ""Задание"" не заполнено.'; en = 'Job is required.'; pl = 'Zadanie jest wymagane.';es_ES = 'Se requiere la tarea.';es_CO = 'Se requiere la tarea.';tr = 'Görev gerekli.';it = 'È richiesto il compito.';de = 'Arbeit ist erforderlich.'"),,
			"Performer", "Object.Description");
		FormAttributesAreFilledIn = False;
	EndIf;
	If NOT ValueIsFilled(Object.DueDate) Then
		CommonClientServer.MessageToUser(NStr("ru = 'Поле ""Срок"" исполнения не заполнено.'; en = 'Due date is required.'; pl = 'Wymagany jest termin.';es_ES = 'Se requiere la fecha de vencimiento.';es_CO = 'Se requiere la fecha de vencimiento.';tr = 'Bitiş tarihi gerekli.';it = 'Il campo ""Scadenza"" dell''esecuzione non è compilato.';de = 'Fälligkeitsdatum ist erforderlich.'"),,
			"DueDate", "Object.DueDate");
		FormAttributesAreFilledIn = False;
	EndIf;
	
	Return FormAttributesAreFilledIn;
	
EndFunction

&AtClientAtServerNoContext
Function ObjectStarted(Form)
	Return Form.Object.Started OR Form.Deferred;
EndFunction

&AtServer
Procedure SetDeferredStartAttributes()

	DeferredStartDate = BusinessProcessesAndTasksServer.ProcessDeferredStartDate(Object.Ref);
	Deferred = (DeferredStartDate <> '00010101');
	
EndProcedure

&AtClient
Procedure FormManagment()
	
	If IsExternalUser Then
		
		Items.StateGroup.Visible				= False;
		Items.Importance.Visible				= False;
		Items.Performer.Visible					= False;
		Items.StateGroup.Visible				= False;
		Items.Topic.Enabled						= False;
		Items.CheckingGroup.Visible				= False;
		Items.CommonInfoGroup.Visible			= False;
		Items.DataForExternalUserGroup.Visible	= True;
		Items.CompletedOn.Visible				= True;
		Items.FormSetUpDeferredStart.Visible	= False;
		Items.FormStart.Visible					= False;
		Items.FormStop.Visible					= False;
		Items.FormContinue.Visible				= False;
		
		If ValueIsFilled(Object.Ref) Then
			
			Items.JobsTitle.ReadOnly = True;
			Items.Content.ReadOnly	 = True;
			Items.DueDate.ReadOnly	 = True;
			
			Items.FormWriteAndClose.Enabled	 = False;
			Items.FormWrite.Enabled			 = False;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion
