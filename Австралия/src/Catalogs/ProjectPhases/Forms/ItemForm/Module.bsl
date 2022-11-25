
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Object.Ref.IsEmpty() Then
		
		If ValueIsFilled(Parameters.Project) Then
			Object.Owner = Parameters.Project;
		EndIf;
		
		If ValueIsFilled(Parameters.Parent) Then
			Object.Parent = Parameters.Parent;
		EndIf;
		
		If ValueIsFilled(Object.Owner) Then
			
			ProjectAttributes = Common.ObjectAttributesValues(Object.Owner, 
				"UseWorkSchedule, WorkSchedule, Status, DurationUnit, StartDate, EndDate, Company");
			
			DurationUnit = ProjectAttributes.DurationUnit;
			ActualDurationUnit = ProjectAttributes.DurationUnit;
			StartDate = ProjectAttributes.StartDate;
			
		EndIf;
		
		If ValueIsFilled(Object.Parent) Then
			Result = ProjectManagement.GetProjectPhaseTimelines(Object.Parent);
			StartDate = Result.StartDate;
		EndIf;
		
		If ValueIsFilled(Parameters.PreviousPhase) Then
			PreviousPhase = Parameters.PreviousPhase;
			Result = ProjectManagement.GetProjectPhaseTimelines(PreviousPhase);
			StartDate = Result.EndDate;
		EndIf;
		
		If Not ValueIsFilled(Duration) Then
			Duration = 1;
		EndIf;
		
		If ValueIsFilled(StartDate) And ValueIsFilled(Duration) Then
			
			EndDate = ProjectManagement.CalculatePeriodEnd(Object,
				StartDate,
				Duration,
				DurationUnit);
			
		EndIf;
		
	Else
		
		ReadProjectPhaseTimelines();
		
	EndIf;
	
	If Object.SummaryPhase Then
		Items.GroupPlan.ReadOnly = True;
		Items.GroupActual.ReadOnly = True;
		Items.Status.ReadOnly = True;
	EndIf;
	
	If ValueIsFilled(Object.Owner) Then
		Items.Owner.ReadOnly = True;
	EndIf;
	
	ParentOfRef = Object.Ref.Parent;
	ProjectOfRef = Object.Ref.Owner;
	
	PreviousPhaseState = OutputPreviousPhaseState(Object.PreviousPhase);
	
	IsAvailableForModification = True;
	If Not AccessRight("Update", Metadata.Catalogs.ProjectPhases) Then
		ThisObject.ReadOnly = True;
		IsAvailableForModification = False;
	EndIf;
	
	If ProjectAttributes = Undefined Then
		ProjectAttributes = Common.ObjectAttributesValues(Object.Owner,
				"UseWorkSchedule, WorkSchedule, Status, DurationUnit, StartDate, EndDate, Company");
	EndIf;
	
	If ValueIsFilled(Object.Owner) Then
		
		ProjectCompleted = (ProjectAttributes.Status = Enums.ProjectStatuses.Completed);
		
		If ProjectCompleted Then
			ThisObject.ReadOnly = True;
			Items.EditingIsProhibitedLabel.Visible = True;
			Items.EditingIsProhibitedLabel.Title = ProjectManagementClientServer.ProhibitedEditForCompletedMessageText();
		ElsIf Not IsAvailableForModification Then
			Items.EditingIsProhibitedLabel.Visible = True;
			Items.EditingIsProhibitedLabel.Title = ProjectManagementClientServer.NoRightsEditMessageText();
		EndIf;
		
	EndIf;
	
	ChoiceOrderParameters = New Array;
	ChoiceOrderParameters.Add(New ChoiceParameter("Filter.Company", ProjectAttributes.Company));
	Items.ProductionOrder.ChoiceParameters = New FixedArray(ChoiceOrderParameters);
	
	SetConditionalAppearanceOnCreate();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If (EventName = "BusinessProcessStarted"
		And Parameter.Property("ProjectPhase")
		And Parameter.ProjectPhase = Object.Ref) Then
		Read();
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ReadProjectPhaseTimelines();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	WriteParameters.Insert("IsNew", Object.Ref.IsEmpty());
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	IsNewObject = Not ValueIsFilled(CurrentObject.Ref);
	WriteParameters.Insert("IsNewObject", IsNewObject);
	
	If IsNewObject Or NeedRecalculateCodeWBS Then
		CodeData = ProjectManagement.GetCodeWBSAndPhaseNumberInLevel(CurrentObject.Owner, CurrentObject.Parent);
		CurrentObject.CodeWBS = CodeData.CodeWBS;
		CurrentObject.PhaseNumberInLevel = CodeData.PhaseNumberInLevel;
	EndIf;
	
	CurrentParent = Common.ObjectAttributeValue(CurrentObject.Ref, "Parent");
	WriteParameters.Insert("CurrentParent", CurrentParent);
	
	CurrentObject.AdditionalProperties.Insert("UUID", UUID);
	CurrentObject.AdditionalProperties.Insert("CheckPrevious", True);
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	DataStructure = New Structure;
	DataStructure.Insert("StartDate", StartDate);
	DataStructure.Insert("EndDate", EndDate);
	DataStructure.Insert("Duration", Duration);
	DataStructure.Insert("DurationUnit", DurationUnit);
	
	DataStructure.Insert("ActualStartDate", ActualStartDate);
	DataStructure.Insert("ActualEndDate", ActualEndDate);
	DataStructure.Insert("ActualDuration", ActualDuration);
	DataStructure.Insert("ActualDurationUnit", ActualDurationUnit);
	
	ProjectManagement.WriteProjectPhaseTimelines(CurrentObject.Ref, DataStructure);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	ModifiedPhasesArray = New Array;
	ModifiedPhasesArray.Add(CurrentObject.Ref);
	
	If ValueIsFilled(WriteParameters.CurrentParent) And WriteParameters.CurrentParent <> CurrentObject.Parent Then
		ProjectManagement.CalculateProjectPlan(WriteParameters.CurrentParent, ModifiedPhasesArray);
		ProjectManagement.UpdateParentsStatus(WriteParameters.CurrentParent, ModifiedPhasesArray);
	EndIf;
	
	ProjectManagement.CalculateProjectPlan(CurrentObject.Ref, ModifiedPhasesArray);
	ProjectManagement.UpdateParentsStatus(CurrentObject.Ref, ModifiedPhasesArray);
	
	WriteParameters.Insert("ModifiedPhasesArray", ModifiedPhasesArray);
	
	ReadProjectPhaseTimelines();
	
	ParentOfRef = Object.Ref.Parent;
	ProjectOfRef = Object.Ref.Owner;
	
	If WriteParameters.Property("IsNewObject") And WriteParameters.IsNewObject = True Or NeedRecalculateCodeWBS Then
		ProjectManagement.FillInProjectPhasesOrder(ProjectOfRef);
	EndIf;
	
	NeedRecalculateCodeWBS = False;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	NotifyParameter = New Structure;
	NotifyParameter.Insert("Project", Object.Owner);
	NotifyParameter.Insert("Parent", Object.Parent);
	NotifyParameter.Insert("ProjectPhase", Object.Ref);
	NotifyParameter.Insert("ModifiedPhasesArray", WriteParameters.ModifiedPhasesArray);
	
	If WriteParameters.IsNew Then
		Notify("ProjectPhaseCreated", NotifyParameter, ThisObject);
	Else
		Notify("ProjectPhaseChanged", NotifyParameter, ThisObject);
	EndIf;
	
	SetEnableByStatus();
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If ValueIsFilled(Object.Parent)
		And Not Object.DeletionMark 
		And Common.ObjectAttributeValue(Object.Parent, "DeletionMark") Then
		CommonClientServer.MessageToUser(
			NStr("en = 'Cannot save the phase. Parent is set to a phase marked for deletion. Select another parent.'; ru = 'Не удалось сохранить этап. Родитель задан для этапа, помеченного на удаление. Выберите другого родителя.';pl = 'Nie można zapisać etapu. Rodzic jest ustawiony na etap zaznaczony do usunięcia. Wybierz innego rodzica.';es_ES = 'No se ha podido guardar la fase. El padre se ha establecido en una fase marcada para ser borrada. Seleccione otro padre.';es_CO = 'No se ha podido guardar la fase. El padre se ha establecido en una fase marcada para ser borrada. Seleccione otro padre.';tr = 'Evre kaydedilemiyor. Üst öğe, silinmek üzere işaretlenmiş bir evreye ayarlı. Başka bir üst öğe seçin.';it = 'Impossibile salvare la fase. Il genitore è impostato su una fase contrassegnata per l''eliminazione. Selezionare un altro genitore.';de = 'Phase kann nicht gespeichert werden. Elternklasse ist zum Löschen markiert. Wählen Sie eine andere Elternklasse aus.'"),,
			"Object.Parent",,
			Cancel);
	EndIf;
	
	If ValueIsFilled(StartDate) Then 
		CheckedAttributes.Add("EndDate");
	EndIf;
	
	If ValueIsFilled(EndDate) Then 
		CheckedAttributes.Add("StartDate");
	EndIf;
	
	If ValueIsFilled(ActualEndDate) Then 
		CheckedAttributes.Add("ActualStartDate");
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetVisibleProduction();
	SetEnableActualAttributes();
	SetEnableByStatus();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure StartDateOnChange(Item)
	
	If ValueIsFilled(StartDate)
		And StartDate = BegOfDay(StartDate)
		And ProjectAttributes.UseWorkSchedule Then
		
		StartDate = WorkSchedulesDrive.GetFirstWorkingTimeOfDay(ProjectAttributes.WorkSchedule, StartDate);
		
	EndIf;
	
	If Not ValueIsFilled(StartDate) Then
		
		Duration = 0;
		
	ElsIf ValueIsFilled(Duration) Then
		
		EndDate = ProjectManagement.CalculatePeriodEnd(Object,
			StartDate,
			Duration,
			DurationUnit);
		
	ElsIf ValueIsFilled(EndDate) Then 
		
		Duration = ProjectManagement.CalculatePeriodDuration(Object, 
			StartDate,
			EndDate,
			DurationUnit);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EndDateOnChange(Item)
	
	If ValueIsFilled(EndDate) 
		And EndDate = BegOfDay(EndDate)
		And ProjectAttributes.UseWorkSchedule Then
		
		EndDate = WorkSchedulesDrive.GetLastWorkingTimeOfDay(ProjectAttributes.WorkSchedule, EndDate);
		
	EndIf;
	
	If Not ValueIsFilled(EndDate) Then
		
		Duration = 0;
		
	ElsIf ValueIsFilled(StartDate) Then
		
		Duration = ProjectManagement.CalculatePeriodDuration(Object,
			StartDate,
			EndDate,
			DurationUnit);
		
	ElsIf ValueIsFilled(Duration) Then
		
		StartDate = ProjectManagement.CalculatePeriodStart(Object,
			EndDate,
			Duration,
			DurationUnit);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DurationOnChange(Item)
	
	If ValueIsFilled(StartDate) Then
		
		EndDate = ProjectManagement.CalculatePeriodEnd(Object,
			StartDate,
			Duration,
			DurationUnit);
		
	ElsIf ValueIsFilled(EndDate) Then
		
		StartDate = ProjectManagement.CalculatePeriodStart(Object,
			EndDate,
			Duration,
			DurationUnit);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DurationUnitOnChange(Item)
	
	If ValueIsFilled(StartDate) Then
		
		EndDate = ProjectManagement.CalculatePeriodEnd(Object,
			StartDate,
			Duration,
			DurationUnit);
		
	ElsIf ValueIsFilled(EndDate) Then
		
		StartDate = ProjectManagement.CalculatePeriodStart(Object,
			EndDate,
			Duration,
			DurationUnit);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ActualStartDateOnChange(Item)
	
	ProcessActualStartDateChange();
	
EndProcedure

&AtClient
Procedure ActualEndDateOnChange(Item)
	
	ProcessActualEndDateChange();
	
EndProcedure

&AtClient
Procedure ActualDurationOnChange(Item)
	
	If ValueIsFilled(ActualStartDate) Then
		ActualEndDate = ProjectManagement.CalculatePeriodEnd(Object,
			ActualStartDate,
			ActualDuration,
			ActualDurationUnit);
	ElsIf ValueIsFilled(ActualEndDate) Then
		ActualStartDate = ProjectManagement.CalculatePeriodStart(Object,
			ActualEndDate,
			ActualDuration,
			ActualDurationUnit);
	EndIf;
	
EndProcedure

&AtClient
Procedure ActualDurationUnitOnChange(Item)
	
	If ValueIsFilled(ActualStartDate) Then
		ActualEndDate = ProjectManagement.CalculatePeriodEnd(Object,
			ActualStartDate,
			ActualDuration,
			ActualDurationUnit);
	ElsIf ValueIsFilled(ActualEndDate) Then
		ActualStartDate = ProjectManagement.CalculatePeriodStart(Object,
			ActualEndDate,
			ActualDuration,
			ActualDurationUnit);
	EndIf;
	
EndProcedure

&AtClient
Procedure OwnerOnChange(Item)
	
	NeedRecalculateCodeWBS = ProjectOfRef <> Object.Owner;
	
EndProcedure

&AtClient
Procedure ParentOnChange(Item)
	
	NeedRecalculateCodeWBS = ParentOfRef <> Object.Parent;
	
EndProcedure

&AtClient
Procedure ParentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("Filter", New Structure("Owner", Object.Owner));
	
	OpenForm("Catalog.ProjectPhases.ChoiceForm", FormParameters, Item);
	
EndProcedure

&AtClient
Procedure ParentChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	Object.Parent = ValueSelected;
	
	NeedRecalculateCodeWBS = (ParentOfRef <> Object.Parent);
	
EndProcedure

&AtClient
Procedure ParentAutoComplete(Item, Text, ChoiceData, DataGetParameters, Wait, StandardProcessing)
	
	If ValueIsFilled(Text) Then
		StandardProcessing = False;
		ChoiceData = ProjectManagement.GenerateProjectPhaseChoiceData(Text, Object.Owner);
	EndIf;
	
EndProcedure

&AtClient
Procedure ParentTextEditEnd(Item, Text, ChoiceData, DataGetParameters, StandardProcessing)
	
	If ValueIsFilled(Text) Then
		StandardProcessing = False;
		ChoiceData = ProjectManagement.GenerateProjectPhaseChoiceData(Text, Object.Owner);
	EndIf;
	
EndProcedure

&AtClient
Procedure PreviousPhaseOnChange(Item)
	
	PreviousPhaseState = OutputPreviousPhaseState(Object.PreviousPhase);
	
EndProcedure

&AtClient
Procedure IsProductionOnChange(Item)
	
	SetVisibleProduction();
	
EndProcedure

&AtClient
Procedure StatusOnChange(Item)
	
	CheckResult = ProjectManagement.CheckProjectPhaseNewStatus(Object.Status, Object.Ref);
	
	If CheckResult.Checked Then
		
		If CheckResult.PrevStatus <> Object.Status Then
			
			If Object.Status = PredefinedValue("Enum.ProjectPhaseStatuses.InProgress") Then
				
				ActualStartDate = DriveReUse.GetSessionCurrentDate();
				ProcessActualStartDateChange();
				
				If CheckResult.PrevStatus = PredefinedValue("Enum.ProjectPhaseStatuses.Completed") Then
					ActualEndDate = Date(1, 1, 1);
					ActualDuration = 0;
				EndIf;
				
			ElsIf Object.Status = PredefinedValue("Enum.ProjectPhaseStatuses.Completed") Then
				
				ActualEndDate = DriveReUse.GetSessionCurrentDate();
				ProcessActualEndDateChange();
				
			ElsIf Object.Status = PredefinedValue("Enum.ProjectPhaseStatuses.Open") Then
				
				If CheckResult.PrevStatus = PredefinedValue("Enum.ProjectPhaseStatuses.InProgress") Then
					ActualStartDate = Date(1, 1, 1);
					ActualEndDate = Date(1, 1, 1);
					ActualDuration = 0;
				EndIf;
				
			EndIf;
			
		EndIf;
		
		SetEnableActualAttributes();
		SetEnableByStatus();
		
	Else
		
		If CheckResult.IsQuery Then
			NotifyDescription = New NotifyDescription("CheckProjectPhaseNewStatusEnd",
				ThisObject,
				New Structure("PrevStatus", CheckResult.PrevStatus));
			ShowQueryBox(NotifyDescription, CheckResult.MessageText, QuestionDialogMode.YesNo);
			Return;
		Else
			
			CommonClientServer.MessageToUser(CheckResult.MessageText);
			
		EndIf;
		
		Object.Status = CheckResult.PrevStatus;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CommandWrite(Command)
	
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	WriteParameters = New Structure;
	WriteParameters.Insert("CloseAfterWrite", False);
	Write(WriteParameters);
	
EndProcedure

&AtClient
Procedure CreateTask(Command)
	
	If Not Object.Ref.IsEmpty() And Not Modified Then
		
		OpenForm("BusinessProcess.ProjectJob.ObjectForm", New Structure("Basis", Object.Ref));
		
	Else
		
		NotifyDescription = New NotifyDescription("CreateTaskEnd", ThisObject);
		
		QueryText = NStr("en = 'To create a task, save the phase first by clicking OK.
						|Or, to go back to the phase details, click Cancel.'; 
						|ru = 'Чтобы создать задачу, сначала сохраните этап, нажав ОК.
						| Чтобы вернуться к описанию этапа, нажмите Отмена.';
						|pl = 'Aby utworzyć zadanie, zapisz etap zanim naciśniesz OK.
						|Lub przejdź wstecz do szczegółów etapu i kliknij Anuluj.';
						|es_ES = 'Para crear una tarea, guarde primero la fase haciendo clic en OK.
						|O, para volver a los detalles de la fase, haga clic en Cancelar.';
						|es_CO = 'Para crear una tarea, guarde primero la fase haciendo clic en OK.
						|O, para volver a los detalles de la fase, haga clic en Cancelar.';
						|tr = 'Görev oluşturmak için önce Tamam''a tıklayarak evreyi kaydedin
						|veya evre ayrıntılarına dönüp İptal''e tıklayın.';
						|it = 'Per generare il compito, salva prima la fase cliccando OK.
						|Oppure clicca Annulla per ritornare ai dettagli della fase.';
						|de = 'Um eine Aufgabe zu erstellen, speichern Sie zuerst die Phase durch klicken auf OK.
						| Um zurück auf die Phasendetails zu gelangen, klicken Sie auf ""Abbrechen"".'");
		
		ShowQueryBox(NotifyDescription, QueryText, QuestionDialogMode.OKCancel);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure ReadProjectPhaseTimelines()
	
	Result = ProjectManagement.GetProjectPhaseTimelines(Object.Ref);
	
	StartDate = Result.StartDate;
	EndDate = Result.EndDate;
	Duration = Result.Duration;
	DurationUnit = Result.DurationUnit;
	
	ActualStartDate = Result.ActualStartDate;
	ActualEndDate = Result.ActualEndDate;
	ActualDuration = Result.ActualDuration;
	ActualDurationUnit = Result.ActualDurationUnit;
	
EndProcedure

&AtServerNoContext
Function OutputPreviousPhaseState(Val PreviousPhase)
	
	SetPrivilegedMode(True);
	
	If Not ValueIsFilled(PreviousPhase) Then
		
		PreviousPhaseState = "";
		
	Else
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	ProjectPhasesTimelines.ProjectPhase AS ProjectPhase,
		|	CASE
		|		WHEN ProjectPhasesTimelines.ActualStartDate = DATETIME(1, 1, 1)
		|			THEN FALSE
		|		ELSE TRUE
		|	END AS Started,
		|	CASE
		|		WHEN ProjectPhasesTimelines.ActualEndDate = DATETIME(1, 1, 1)
		|			THEN FALSE
		|		ELSE TRUE
		|	END AS Completed
		|FROM
		|	InformationRegister.ProjectPhasesTimelines AS ProjectPhasesTimelines
		|WHERE
		|	ProjectPhasesTimelines.ProjectPhase = &PreviousPhase";
		
		Query.SetParameter("PreviousPhase", PreviousPhase);
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			
			If Selection.Completed Then
				PreviousPhaseState = NStr("en = 'The previous phase is completed.'; ru = 'Предыдущий этап завершен.';pl = 'Poprzedni etap został zakończony.';es_ES = 'Se ha finalizado la fase anterior.';es_CO = 'Se ha finalizado la fase anterior.';tr = 'Önceki evre tamamlandı.';it = 'La fase precedente è completata.';de = 'Die Vorphase wurde abgeschlossen.'");
			ElsIf Selection.Started Then
				PreviousPhaseState = NStr("en = 'The previous phase is started.'; ru = 'Предыдущий этап начат.';pl = 'Poprzedni etap jest rozpoczęty.';es_ES = 'Se inicia la fase anterior.';es_CO = 'Se inicia la fase anterior.';tr = 'Önceki evre başladı.';it = 'La fase precedente è avviata.';de = 'Die Vorphase ist gestartet.'");
			Else
				PreviousPhaseState = NStr("en = 'The previous phase is not started.'; ru = 'Предыдущий этап не начат.';pl = 'Poprzedni etap nie jest rozpoczęty.';es_ES = 'No se ha iniciado la fase anterior.';es_CO = 'No se ha iniciado la fase anterior.';tr = 'Önceki evre başlamadı.';it = 'La fase precedente non è avviata.';de = 'Die Vorphase ist nicht gestartet.'");
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return PreviousPhaseState;
	
EndFunction

&AtClient
Procedure SetVisibleProduction()
	
	Items.ProductionOrder.Visible = Object.IsProduction;
	
EndProcedure

&AtClient
Procedure CheckProjectPhaseNewStatusEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		ClearMessages();
		ProjectManagement.CompleteProjectPhaseTasks(Object.Ref);
	Else
		Object.Status = AdditionalParameters.PrevStatus;
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessActualEndDateChange()
	
	If ValueIsFilled(ActualEndDate)
		And ActualEndDate = BegOfDay(ActualEndDate)
		And ProjectAttributes.UseWorkSchedule Then
		ActualEndDate = WorkSchedulesDrive.GetLastWorkingTimeOfDay(ProjectAttributes.WorkSchedule, ActualEndDate);
	EndIf;
	
	If ValueIsFilled(ActualEndDate) And ValueIsFilled(ActualStartDate) Then
		ActualDuration = ProjectManagement.CalculatePeriodDuration(Object,
			ActualStartDate,
			ActualEndDate,
			ActualDurationUnit);
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessActualStartDateChange()
	
	If ValueIsFilled(ActualStartDate)
		And ActualStartDate = BegOfDay(ActualStartDate)
		And ProjectAttributes.UseWorkSchedule Then
		ActualStartDate = WorkSchedulesDrive.GetFirstWorkingTimeOfDay(ProjectAttributes.WorkSchedule, ActualStartDate);
	EndIf;
	
	If ValueIsFilled(ActualStartDate) And ValueIsFilled(ActualEndDate) Then
		ActualDuration = ProjectManagement.CalculatePeriodDuration(Object,
			ActualStartDate,
			ActualEndDate,
			ActualDurationUnit);
	EndIf;
	
EndProcedure

&AtClient
Procedure SetEnableActualAttributes()
	
	SummaryPhaseOrInProgress = Object.SummaryPhase
		Or Object.Status <> PredefinedValue("Enum.ProjectPhaseStatuses.InProgress");
	
	SummaryPhaseOrCompleted = Object.SummaryPhase
		Or Object.Status <> PredefinedValue("Enum.ProjectPhaseStatuses.Completed");
	
	Items.ActualStartDate.ReadOnly = SummaryPhaseOrInProgress;
	Items.ActualEndDate.ReadOnly = SummaryPhaseOrCompleted;
	Items.ActualDuration.ReadOnly = SummaryPhaseOrCompleted;
	
EndProcedure

&AtClient
Procedure CreateTaskEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		If Not CheckFilling() Then
			Return;
		EndIf;
		
		WriteParameters = New Structure("CloseAfterWrite", False);
		If Write(WriteParameters) Then
			OpenForm("BusinessProcess.ProjectJob.ObjectForm", New Structure("Basis", Object.Ref));
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetEnableByStatus()
	
	CreateTaskEnabled = (Object.Status = PredefinedValue("Enum.ProjectPhaseStatuses.InProgress")
		And Not Object.DeletionMark
		And Not ThisObject.ReadOnly);
	
	Items.FormCreateTask.Enabled = CreateTaskEnabled;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearanceOnCreate()
	
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("NeedRecalculateCodeWBS");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Font", New Font("MS Shell Dlg", 10, False, False, False, True, 100));
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("CodeWBS");
	FieldAppearance.Use = True;
	
EndProcedure

#EndRegion