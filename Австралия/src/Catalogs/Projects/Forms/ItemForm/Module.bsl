#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	UseProjectManagement = GetFunctionalOption("UseProjectManagement");
	
	If UseProjectManagement Then
		
		FillFinancialDocuments();
		
		CurrentDate = CurrentSessionDate();
		
		StatusBeforeChange = Object.Status;
		
		If Object.Ref.IsEmpty() Then
			
			If Not ValueIsFilled(Parameters.CopyingValue) Then
				
				If Object.UseWorkSchedule Then
					Object.StartDate = WorkSchedulesDrive.GetFirstWorkingTimeOfDay(
						Object.WorkSchedule,
						CurrentDate - Second(CurrentDate));
				Else
					Object.StartDate = BegOfDay(CurrentDate);
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
	
	Items.GroupSettings.Visible = UseProjectManagement;
	Items.GroupPlanDates.Visible = UseProjectManagement;
	Items.GroupActualDates.Visible = UseProjectManagement;
	
	If Not UseProjectManagement Then
		Items.GroupPages.PagesRepresentation = FormPagesRepresentation.None;
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	SaveFinancialDocumentsSettings(CurrentObject);
	
	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetEnabled();
	SetWorkScheduleVisible();
	SetContractVisible();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If (EventName = "ProjectPhaseCreated"
		Or EventName = "ProjectPhaseChanged"
		Or EventName = "Change_Project")
		And Parameter.Project = Object.Ref Then
		
		Read();
		SetWorkScheduleVisible();
		
	ElsIf EventName = "Write_Counterparty"
		And ValueIsFilled(Parameter)
		And Object.Counterparty = Parameter Then
		
		ReadCounterpartyAttributes(CounterpartyAttributes, Parameter);
		SetContractVisible();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If UseProjectManagement Then
		
		If Not WriteParameters.Property("ContinueWriteAfterAnswerQuestion")
			And StatusBeforeChange <> Object.Status
			And Object.Status = PredefinedValue("Enum.ProjectStatuses.Completed")
			And ValueIsFilled(Object.Ref)
			And ProjectManagement.ExistNotCompetedProjectPhases(Object.Ref) Then
			
			QuestionText = NStr("en = 'The project has phases pending completion.
								|Are you sure that you want to set the project status to Completed?'; 
								|ru = 'В проекте есть этапы, ожидающие завершения.
								|Вы уверены, что хотите установить для проекта статус ""Завершен""?';
								|pl = 'Projekt ma etapy które są w toku wykonania.
								|Czy na pewno chcesz ustawić status projektu na Zakończono?';
								|es_ES = 'El proyecto tiene fases pendientes de finalización.
								|¿Está seguro de que desea establecer el estado del proyecto en Finalizado?';
								|es_CO = 'El proyecto tiene fases pendientes de finalización.
								|¿Está seguro de que desea establecer el estado del proyecto en Finalizado?';
								|tr = 'Projenin tamamlanmamış evreleri var.
								|Projenin durumunu Tamamlandı olarak ayarlamak istediğinize emin misiniz?';
								|it = 'Nel progetto ci sono fasi in attesa di completamento.
								|Confermi di voler impostare lo stato del progetto su Completato?';
								|de = 'Der Projekt hat Phasen mit anstehendem Abschluss.
								|Möchten Sie wirklich den Projektstatus als Abgeschlossen setzen?'");
			
			NotifyDescription = New NotifyDescription("BeforeWriteEnd", ThisObject, WriteParameters);
			
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.No);
			
			Cancel = True;
			
			Return;
			
		EndIf;
		
		If Object.UseWorkSchedule And ValueIsFilled(Object.WorkSchedule) Then
			
			If NotExistWorkSchedulePeriodSettings(Object.WorkSchedule) Then
				
				MessageText = NStr("en = 'Working hours in day, working hours in week, working days in month are required.'; ru = 'Укажите рабочее время в день, рабочее время в неделю, рабочее время в месяц.';pl = 'Godziny pracy w dniu, godziny pracy w tygodniu, godziny pracy w miesiącu są wymagane.';es_ES = 'Se requieren horas de trabajo en el día, horas de trabajo en la semana, días de trabajo en el mes.';es_CO = 'Se requieren horas de trabajo en el día, horas de trabajo en la semana, días de trabajo en el mes.';tr = 'Gün içindeki çalışma saatleri, hafta içindeki çalışma saatleri, ay içindeki çalışma günleri gerekli.';it = 'Sono richiesti ore lavorative al giorno, ore lavorative alla settimana, giorni lavorativi al mese.';de = 'Arbeitsstunden täglich, Arbeitsstunden wöchentlich, Arbeitstage monatlich sind erforderlich.'");
				CommonClientServer.MessageToUser(MessageText, , , , Cancel);
				
				FormParameters = New Structure("FillingValues", New Structure("WorkSchedule", Object.WorkSchedule));
				OpenForm("InformationRegister.WorkSchedulePeriodSettings.RecordForm",
					FormParameters,
					ThisObject,,,,,
					FormWindowOpeningMode.LockOwnerWindow);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CounterpartyOnChange(Item)
	
	DataStructure = GetDataCounterpartyOnChange(Object.Counterparty, Object.Company);
	Object.Contract = DataStructure.Contract;
	
	SetContractVisible();
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	If UseProjectManagement Then
		
		WorkSchedule = GetCompanyWorkSchedule(Object.Company);
		
		If ValueIsFilled(WorkSchedule) Then
			Object.WorkSchedule = WorkSchedule;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure StartDateOnChange(Item)
	
	GetWorkingDate(Object.StartDate, True);
	
EndProcedure

&AtClient
Procedure EndDateOnChange(Item)
	
	GetWorkingDate(Object.EndDate, False);
	
EndProcedure

&AtClient
Procedure StatusOnChange(Item)
	
	If UseProjectManagement Then
		
		CheckResult = ProjectManagement.CheckProjectNewStatus(Object.Status, Object.Ref);
		
		If CheckResult.Checked Then
			
			SetEnabled();
			
		Else
			
			If CheckResult.IsQuery Then
				NotifyDescription = New NotifyDescription("CheckProjectNewStatusEnd",
					ThisObject,
					New Structure("PrevStatus", CheckResult.PrevStatus));
				ShowQueryBox(NotifyDescription, CheckResult.MessageText, QuestionDialogMode.YesNo);
				Return;
			Else
				
				CommonClientServer.MessageToUser(CheckResult.MessageText);
				
			EndIf;
			
			Object.Status = CheckResult.PrevStatus;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UseWorkScheduleOnChange(Item)
	
	SetWorkScheduleVisible();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlers

&AtClient
Procedure FinancialDocumentsSettingCheckOnChange(Item)
	
	Modified = True;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OpenProjectWorkplace(Command)
	
	If Object.Ref.IsEmpty() Then
		
		If Not Write() Then
			Return;
		EndIf;
		
	EndIf;
	
	OpenForm("Catalog.ProjectPhases.Form.ProjectPlanForm",
		New Structure("Project", Object.Ref),
		ThisObject);
	
EndProcedure

&AtClient
Procedure LoadFromTemplate(Command)
	
	If Modified Or Object.Ref.IsEmpty() Then
		If Not Write() Then
			Return;
		EndIf;
	EndIf;
	
	ProjectManagementClient.LoadProjectFromTemplate(Object.Ref);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function GetDataCounterpartyOnChange(Counterparty, Company)
	
	ReadCounterpartyAttributes(CounterpartyAttributes, Counterparty);
	
	Return New Structure("Contract", GetContractByDefault(Counterparty, Company));
	
EndFunction

&AtServerNoContext
Procedure ReadCounterpartyAttributes(StructureAttributes, Val CatalogCounterparty)
	
	Attributes = "DoOperationsByContracts";
	
	DriveServer.ReadCounterpartyAttributes(StructureAttributes, CatalogCounterparty, Attributes);
	
EndProcedure

&AtServerNoContext
Function GetContractByDefault(Counterparty, Company)
	
	Return DriveServer.GetContractByDefault(Catalogs.Projects.EmptyRef(), Counterparty, Company);
	
EndFunction

&AtServer
Procedure FillFinancialDocuments()
	
	If Not UseProjectManagement Then
		Return;
	EndIf;
	
	TypesArray					= Metadata.DefinedTypes.ProjectDocuments.Type.Types();
	AllDocuments				= Documents.AllRefsType();
	ProjectFinancialDocuments	= Object.FinancialDocumentsSetting.Unload();
	
	For Each Type In TypesArray Do
		
		If AllDocuments.ContainsType(Type) Then
			
			MetadataObjectID = Common.MetadataObjectID(Type);
			CheckMark = ProjectFinancialDocuments.Find(MetadataObjectID, "DocumentType") <> Undefined;
			
			FinancialDocuments.Add(MetadataObjectID, MetadataObjectID.Synonym, CheckMark);
			
		EndIf;
		
	EndDo;
	
	If FinancialDocuments.Count() > 0 Then
		FinancialDocuments.SortByPresentation();
	EndIf;
	
EndProcedure

&AtServer
Procedure SaveFinancialDocumentsSettings(CurrentObject)
	
	If Not UseProjectManagement Then
		Return;
	EndIf;
	
	WasModified = False;
	
	ProjectFinancialDocuments = CurrentObject.FinancialDocumentsSetting.Unload();
	
	For Each ListItem In FinancialDocuments Do
		
		FinancialDocumentsRow = ProjectFinancialDocuments.Find(ListItem.Value);
		
		If ListItem.Check And FinancialDocumentsRow = Undefined Then
			
			NewRow = ProjectFinancialDocuments.Add();
			NewRow.DocumentType = ListItem.Value;
			
			WasModified = True;
			
		ElsIf Not ListItem.Check And FinancialDocumentsRow <> Undefined Then
			
			ProjectFinancialDocuments.Delete(FinancialDocumentsRow);
			
			WasModified = True;
			
		EndIf;
		
	EndDo;
	
	If WasModified Then
		CurrentObject.FinancialDocumentsSetting.Load(ProjectFinancialDocuments);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetCompanyWorkSchedule(Company)
	
	CompanyAttributes = DriveServer.GetRefAttributes(Company, "BusinessCalendar");
	
	Return CompanyAttributes.BusinessCalendar;
	
EndFunction

&AtServer
Procedure GetWorkingDate(Date, IsStart)
	
	If ValueIsFilled(Date) And Date = BegOfDay(Date) Then
		
		If Object.UseWorkSchedule Then 
			
			If ValueIsFilled(Object.WorkSchedule) Then
				WorkSchedule = Object.WorkSchedule;
			Else
				WorkSchedule = GetCompanyWorkSchedule(Object.Company);
			EndIf;
			
			If WorkSchedulesDrive.IsWorkingDay(Date, WorkSchedule) Then
				If IsStart Then
					Date = WorkSchedulesDrive.GetFirstWorkingTimeOfDay(WorkSchedule, Date);
				Else
					Date = WorkSchedulesDrive.GetLastWorkingTimeOfDay(WorkSchedule, Date);
				EndIf;
			EndIf;
			
		Else
			
			If IsStart Then
				Date = BegOfDay(Date);
			Else
				Date = EndOfDay(Date);
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWriteEnd(Result, WriteParameters) Export
	
	If Result = DialogReturnCode.No Then
		Return;
	Else
		WriteParameters.Insert("ContinueWriteAfterAnswerQuestion", True);
		Write(WriteParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckProjectNewStatusEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		ClearMessages();
		ProjectManagement.CompleteProjectPhaseTasks(Object.Ref);
	Else
		Object.Status = AdditionalParameters.PrevStatus;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetEnabled()
	
	Items.FormLoadFromTemplate.Enabled = (Object.Status = PredefinedValue("Enum.ProjectStatuses.Open"));
	
EndProcedure

&AtClient
Procedure SetContractVisible()
	
	Items.Contract.Visible = CounterpartyAttributes.DoOperationsByContracts;
	
EndProcedure

&AtClient
Procedure SetWorkScheduleVisible()
	
	Items.WorkSchedule.Visible = Object.UseWorkSchedule;
	
EndProcedure

&AtServerNoContext
Function NotExistWorkSchedulePeriodSettings(WorkSchedule)
	
	PeriodSettings = InformationRegisters.WorkSchedulePeriodSettings.GetWorkSchedulePeriodSettings(WorkSchedule);
	
	Return (PeriodSettings = Undefined);
	
EndFunction

#Region LibrariesHandlers

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Object);
EndProcedure

&AtServer
Procedure Attachable_ExecuteCommandAtServer(Context, Result)
	AttachableCommands.ExecuteCommand(ThisObject, Context, Object, Result);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
EndProcedure
// End StandardSubsystems.AttachableCommands

// StandardSubsystems.ObjectAttributesLock

&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	ObjectAttributesLockClient.AllowObjectAttributeEdit(ThisObject);
EndProcedure

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#EndRegion