
#Region Variables

&AtClient
Var PerformerChoiceFormOpened;
&AtClient
Var ChoiceContext;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Object.Ref.IsEmpty() Then
		InitializeForm();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	RefreshStopCommandsAvailability();
	
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
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	ChangeJobsBackdated = GetFunctionalOption("ChangeJobsBackdated");
	If InitialStartFlag And ChangeJobsBackdated Then
		SetPrivilegedMode(True);
		CurrentObject.ChangeUncompletedTasksAttributes();
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_ProjectJob", WriteParameters, Object.Ref);
	Notify("Write_PerformerTask", WriteParameters, Undefined);
	
	If WriteParameters.Property("Start") And WriteParameters.Start Then
		
		ParametersData = New Structure;
		ParametersData.Insert("Project", Object.Project);
		ParametersData.Insert("ProjectPhase", Object.ProjectPhase);
		
		Notify("BusinessProcessStarted", ParametersData);
		
		AttachIdleHandler("UpdateForm", 0.2, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateForm()
	
	SetFormItemsProperties(ThisObject);
	RefreshStopCommandsAvailability();
	
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
Procedure SubjectClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(, Object.Topic);
	
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
	
	If TypeOf(Object.Performer) = Type("CatalogRef.PerformerRoles") And ValueIsFilled(Object.Performer) Then
		
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
Procedure DueDateOnChange(Item)
	
	If Object.DueDate = BegOfDay(Object.DueDate) Then
		Object.DueDate = EndOfDay(Object.DueDate);
	EndIf;
	
EndProcedure

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

#EndRegion

#Region Private

&AtServer
Procedure InitializeForm()
	
	InitialStartFlag = Object.Started;
	
	UseDateAndTimeInTaskDeadlines	= GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	ChangeJobsBackdated				= GetFunctionalOption("ChangeJobsBackdated");
	
	SubjectString = Common.SubjectString(Object.Topic);
	
	SetFormItemsProperties(ThisObject);
	
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

&AtServerNoContext
Function UsedByAddressingObjects(ObjectToCheck)
	
	Return Common.ObjectAttributeValue(ObjectToCheck, "UsedByAddressingObjects");
	
EndFunction

&AtClientAtServerNoContext
Procedure SetFormItemsProperties(Form)
	
	If Form.ReadOnly Then
		
		Form.Items.FormStop.Visible = False;
		Form.Items.FormWriteAndClose.Visible = False;
		Form.Items.FormWrite.Visible = False;
		Form.Items.FormContinue.Visible = False;
		
	Else
		
		Form.Items.DueDateTime.Visible = Form.UseDateAndTimeInTaskDeadlines;
		Form.Items.Date.Format = ?(Form.UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
		Form.Items.Topic.Hyperlink = Form.Object.Topic <> Undefined And Not Form.Object.Topic.IsEmpty();
		Form.Items.FormStartAndClose.Visible = Not Form.Object.Started;
		Form.Items.FormStartAndClose.DefaultButton = Not Form.Object.Started;
		Form.Items.FormStart.Visible = Not Form.Object.Started;
		Form.Items.FormWriteAndClose.Visible = ?(Form.Object.Completed, False, Form.Object.Started);
		Form.Items.FormWrite.Visible = Not Form.Object.Completed;
		Form.Items.FormWriteAndClose.DefaultButton = Form.Object.Started;
		
	EndIf;
	
	SetsPropertiesForStateGroup(Form);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetsPropertiesForStateGroup(Form)
	
	DisplayGroup = Form.Object.Completed Or Form.Object.Started;
	Form.Items.StateGroup.Visible = DisplayGroup;
	
	If Not DisplayGroup Then
		Return;
	EndIf;
	
	RowsArray = New Array;
	Height = 1;
	
	If Form.Object.Completed Then
		
		EndDateAsString = ?(Form.UseDateAndTimeInTaskDeadlines,
			Format(Form.Object.CompletedOn, "DLF=DT"),
			Format(Form.Object.CompletedOn, "DLF=D"));
		TextString = ?(Form.Object.JobCompleted, 
			NStr("en = 'The project job is completed on %1.'; ru = 'Задание проекта выполнено %1.';pl = 'Zadanie projektu jest zakończone na %1.';es_ES = 'La tarea del proyecto se ha finalizado en %1.';es_CO = 'La tarea del proyecto se ha finalizado en %1.';tr = 'Proje işi tamamlanması: %1.';it = 'Il lavoro del progetto è completato il %1.';de = 'Die Projektaufgabe ist am %1 abgeschlossen.'"),
			NStr("en = 'The project job is canceled on %1.'; ru = 'Задание проекта отменено %1.';pl = 'Zadanie projektu jest anulowane na %1.';es_ES = 'La tarea del proyecto se ha cancelado en %1.';es_CO = 'La tarea del proyecto se ha cancelado en %1.';tr = 'Proje işi iptali: %1.';it = 'Il lavoro del progetto è cancellato il %1.';de = 'Die Projektaufgabe ist am %1 aufgehoben.'"));
		StateText = StringFunctionsClientServer.SubstituteParametersToString(TextString, EndDateAsString);
		RowsArray.Add(StateText);
		
		For Each Item In Form.Items Do
			If TypeOf(Item) <> Type("FormField") And TypeOf(Item) <> Type("FormGroup") Then
				Continue;
			EndIf;
			Item.ReadOnly = True;
		EndDo;
		
	ElsIf Form.Object.Started Then
		
		StateText = ?(Form.ChangeJobsBackdated,
			NStr("en = 'Changes to the importance, author and deadline will take effect immediately for the tasks assigned earlier.'; ru = 'Изменения важности, автора, а также перенос сроков исполнения вступят в силу немедленно для ранее выданной задачи.';pl = 'Zmiany priorytetu, autora i terminu zaczną obowiązywać natychmiast dla zadań przydzielonych wcześniej.';es_ES = 'Los cambios en la importancia, el autor y la fecha límite surtirán efecto inmediatamente para las tareas asignadas anteriormente.';es_CO = 'Los cambios en la importancia, el autor y la fecha límite surtirán efecto inmediatamente para las tareas asignadas anteriormente.';tr = 'Önem, oluşturan ve bitiş tarihindeki değişiklikler daha önce atanmış görevler için hemen geçerlilik kazanacak.';it = 'Le modifiche a importanza, autore e scadenza avranno effetto immediato per i compiti assegnati in precedenza.';de = 'Änderungen in der Bedeutung, im Autor und Fälligkeitstermin sind für die bisher zugeordneten Aufgaben unmittelbar gültig.'"), 
			NStr("en = 'Changes to the importance, author and deadline will not be shown in the task assigned earlier.'; ru = 'Изменения важности, автора, а также перенос сроков исполнения не будут отражены в ранее выданной задаче.';pl = 'Zmiany priorytetu, autora i terminu nie będą pokazywane w zadaniach przedzielonych wcześniej.';es_ES = 'Los cambios en la importancia, el autor y la fecha límite no se mostrarán en la tarea asignada anteriormente.';es_CO = 'Los cambios en la importancia, el autor y la fecha límite no se mostrarán en la tarea asignada anteriormente.';tr = 'Önem, oluşturan ve bitiş tarihindeki değişiklikler daha önce atanmış görevde gösterilmeyecek.';it = 'Le modifiche a importanza, autore e scadenza non saranno mostrate nel compito assegnato in precedenza.';de = 'Änderungen in der Bedeutung, im Autor, Fälligkeitstermin werden für die bisher zugeordneten Aufgaben nicht angezeigt.'"));
		RowsArray.Add(StateText);
		Height = 2;
		
	EndIf;
	
	Form.HelpTextTitle = New FormattedString(RowsArray);
	Form.Items.HelpTextTitle.MaxHeight = Height;
	
EndProcedure

#EndRegion
