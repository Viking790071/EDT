
#Region FormEventHandlers

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If CurrentObject.Enabled 
		And Not Cancel 
		And (CurrentObject.Mode = Enums.AccountingTransactionGenerationMode.AutomaticallyScheduled
				Or ValueIsFilled(CurrentObject.ScheduledJobUUID)) Then
				
		PostDocumentsByAccountingTemplatesJob = Metadata.ScheduledJobs.PostDocumentsByAccountingTemplates;
				
		JobParameters = New Structure;
		JobParameters.Insert("Metadata"		, PostDocumentsByAccountingTemplatesJob);
		JobParameters.Insert("MethodName"	, PostDocumentsByAccountingTemplatesJob.MethodName);
		
		MethodParameters = New Array;
		
		ParametersStructure = New Structure("Company, TypeOfAccounting, Mode");
		FillPropertyValues(ParametersStructure, CurrentObject);
		
		MethodParameters.Add(ParametersStructure);
		
		JobParameters.Insert("Parameters", MethodParameters);
		
		SetPrivilegedMode(True);
		
		JobsList = ScheduledJobsServer.FindJobs(JobParameters);
		
		ObjectPresentation	= StrTemplate(NStr("en = '(%1, %2)'; ru = '(%1, %2)';pl = '(%1, %2)';es_ES = '(%1, %2)';es_CO = '(%1, %2)';tr = '(%1, %2)';it = '(%1, %2)';de = '(%1, %2)'"), CurrentObject.Company, CurrentObject.TypeOfAccounting);
		JobDescription		= StrTemplate(NStr("en = 'Generation entries %1'; ru = 'Формирование проводок %1';pl = 'Wpisy generacji %1';es_ES = 'Generación de entradas de diario%1';es_CO = 'Generación de entradas de diario%1';tr = 'Giriş oluşturma %1';it = 'Creazione voci %1';de = 'Generierungsbuchungen %1'"), ObjectPresentation); 
		
		JobParameters.Insert("Description"	, JobDescription);
		JobParameters.Insert("Use"			, CurrentObject.Enabled);
		JobParameters.Insert("Schedule"		, Schedule);
		
		JobFound = False;
		For Each Job In JobsList Do
			
			If Job.UUID = CurrentObject.ScheduledJobUUID Then
				
				If CurrentObject.Mode = Enums.AccountingTransactionGenerationMode.AutomaticallyScheduled Then
					ScheduledJobsServer.ChangeJob(Job, JobParameters);
				Else
					ScheduledJobsServer.DeleteJob(Job);
				EndIf;
				
				JobFound = True;
			EndIf;
			
		EndDo;
		
		If Not JobFound 
			And CurrentObject.Mode = Enums.AccountingTransactionGenerationMode.AutomaticallyScheduled Then
			
			Job = ScheduledJobsServer.AddJob(JobParameters);
			CurrentObject.ScheduledJobUUID = Job.UUID;
			
		EndIf;
		
		SetPrivilegedMode(False);
		
	ElsIf Not Cancel
		And ValueIsFilled(CurrentObject.ScheduledJobUUID)
		And (Not CurrentObject.Enabled
			Or CurrentObject.Mode = Enums.AccountingTransactionGenerationMode.AutomaticallyScheduled) Then
		
		Job = ScheduledJobsServer.Job(CurrentObject.ScheduledJobUUID);
		
		If Job <> Undefined Then
			ScheduledJobsServer.DeleteJob(Job);
		EndIf;
		
		CurrentObject.ScheduledJobUUID = Undefined;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetScheduleButtonTitle();
	SetScheduleVisibility();
	
	Items.FormWriteAndClose.Enabled = Not ReadOnly;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	SetPrivilegedMode(True);
	
	Job = ScheduledJobsServer.Job(CurrentObject.ScheduledJobUUID);
	
	If Job = Undefined Then
		Schedule = Undefined;
	Else
		Schedule = Job.Schedule;
	EndIf;
	
	SetPrivilegedMode(False);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Not ValueIsFilled(Record.Company) Then
		CommonClientServer.MessageToUser(
			NStr("en = '""Company"" is a required field.'; ru = 'Заполните поле ""Организация"".';pl = 'Pole ""Firma"" jest wymagane.';es_ES = '""Empresa"" es un campo obligatorio.';es_CO = '""Empresa"" es un campo obligatorio.';tr = '""İş yeri"" zorunlu alandır.';it = '""Azienda"" è un campo richiesto.';de = '""Firma"" ist ein Pflichtfeld.'"),
			,
			"Record.Company",
			,
			Cancel);
	EndIf;
	
	If Not ValueIsFilled(Record.TypeOfAccounting) Then
		CommonClientServer.MessageToUser(
			NStr("en = '""Type of accounting"" is a required field.'; ru = 'Заполните поле ""Тип бухгалтерского учета"".';pl = 'Pole ""Typ rachunkowości"" jest wymagane.';es_ES = '""Tipo de contabilidad"" es un campo obligatorio.';es_CO = '""Tipo de contabilidad"" es un campo obligatorio.';tr = '""Muhasebe türü"" zorunlu alandır.';it = '""Tipo di contabilità"" è un campo richiesto.';de = '""Typ der Buchhaltung"" ist ein Pflichtfeld.'"),
			,
			"Record.TypeOfAccounting",
			,
			Cancel);
	EndIf;
	
	If Not ValueIsFilled(Record.Mode) Then
		CommonClientServer.MessageToUser(
			NStr("en = '""Mode"" is a required field.'; ru = 'Заполните поле ""Режим"".';pl = 'Pole ""Tryb"" jest wymagane.';es_ES = '""Modo"" es un campo obligatorio.';es_CO = '""Modo"" es un campo obligatorio.';tr = '""Mod"" zorunlu alandır.';it = '""Modalità"" è un campo richiesto.';de = '""Modus"" ist ein Pflichtfeld.'"),
			,
			"Record.Mode",
			,
			Cancel);
	EndIf;
	
	MessageStructure = CheckEnabledSettingsExist(Cancel);
	
	If Not Cancel 
		And Not WriteParameters.Property("DoNotCheckEnabledSettingsExist") 
		And Record.Enabled
		And MessageStructure.Text <> "" Then
		
		WriteParameters.Insert("CheckParameter", "EnabledSettingsExist");
		WriteParameters.Insert("KeyStructure", MessageStructure.KeyStructure);
		Mode = QuestionDialogMode.YesNo;
		Notification = New NotifyDescription("WriteObjectEnd", ThisObject, WriteParameters);
		QueryMessage = MessageStructure.Text;
		ShowQueryBox(Notification, QueryMessage, Mode, 0);
		
		Cancel = True;
		
	ElsIf Not Cancel 
		And Record.Mode = AutomaticallyScheduled
		And Record.Enabled
		And Schedule = Undefined Then
		
		QueryMessage = NStr("en = 'Fill schedule first'; ru = 'Сначала укажите график';pl = 'Najpierw wypełnij harmonogram';es_ES = 'Rellene primero el horario';es_CO = 'Rellene primero el horario';tr = 'Önce programı doldurun';it = 'Compilare prima il grafico';de = 'Plan zuerst auffüllen'");
		CommonClientServer.MessageToUser(QueryMessage, , "MessageJobSchedule", , Cancel);
				
	ElsIf Not Cancel Then
		
		WriteObjectEnd(Undefined, WriteParameters);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If ValueIsFilled(Parameters.CopyingValue) And ValueIsFilled(Record.ScheduledJobUUID) Then
		
		Job = ScheduledJobsServer.Job(Record.ScheduledJobUUID);
		
		If Job = Undefined Then
			Schedule = Undefined;
		Else
			Schedule = Job.Schedule;
		EndIf;
		
		Record.ScheduledJobUUID = Undefined;
		
	ElsIf Not ValueIsFilled(Parameters.Key) Then
		
		If Not ValueIsFilled(Record.Company) Then
			Record.Company = Catalogs.Companies.CompanyByDefault();
		EndIf;
		
		If Not ValueIsFilled(Record.Mode) Then
			Record.Mode = Enums.AccountingTransactionGenerationMode.AutomaticallyScheduled;
		EndIf;
		
	EndIf;
	
	Record.Author = Users.CurrentUser();
	
	AutomaticallyScheduled = Enums.AccountingTransactionGenerationMode.AutomaticallyScheduled;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	TypeofAccountingPeriod = Undefined;
	
	If Record.Enabled
		And FindTypeOfAccounting(Record.Company, Record.TypeOfAccounting, TypeofAccountingPeriod) Then
		
		MessageTmpl = NStr("en = 'On %1, for ""%2"", the accounting policy does not include ""%3"". The settings will be saved. To apply them, add ""%3"" to the accounting policy.'; ru = 'На %1 для ""%2"" учетная политика не содержит ""%3"". Настройки будут сохранены. Чтобы применить их, добавьте ""%3"" в учетную политику.';pl = 'Na %1, dla ""%2"", polityka rachunkowości nie włącza ""%3"". Ustawienia nie zostaną usunięte. Aby zastosować je, dodaj ""%3"" do politykia rachunkowości.';es_ES = 'En %1, para ""%2"", la política de contabilidad no incluye ""%3"". Los ajustes se guardarán. Para aplicarlos, añada ""%3"" a la política de contabilidad.';es_CO = 'En %1, para ""%2"", la política de contabilidad no incluye ""%3"". Los ajustes se guardarán. Para aplicarlos, añada ""%3"" a la política de contabilidad.';tr = '%1''de ""%2"" için muhasebe politikası ""%3"" içermiyor. Ayarlar kaydedilecek. Ayarları uygulamak için muhasebe politikasına ""%3"" ekleyin.';it = 'In %1, per ""%2"" la politica contabile non include ""%3"". Le impostazioni saranno salvate. Per applicarle, aggiungere ""%3"" alla politica contabile.';de = 'Auf %1, enthalten die Bilanzierungsrichtlinien für ""%2"" ""%3"" nicht. Die Einstellungen werden gespeichert. Um diese zu verwenden, fügen Sie ""%3"" zu den Bilanzierungsrichtlinien hinzu.'");
		MessageText = StrTemplate(MessageTmpl, Format(TypeofAccountingPeriod, "DLF=D"), Record.Company, Record.TypeOfAccounting);
		CommonClientServer.MessageToUser(MessageText);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ModeOnChange(Item)
	
	SetScheduleVisibility();
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject, "Record.Comment");
	
EndProcedure

&AtClient
Procedure EnabledOnChange(Item)
	
	If Not Record.Enabled
		And Schedule <> Undefined Then
		
		Mode = QuestionDialogMode.YesNo;
		Notification = New NotifyDescription("EnabledOnChangeEnd", ThisObject);
		QueryMessage = NStr("en = 'Schedule will be cleared. Continue?'; ru = 'График будет очищен. Продолжить?';pl = 'Harmonogram zostanie wyczyszczona. Kontynuować?';es_ES = 'El horario se eliminará. ¿Continuar?';es_CO = 'El horario se eliminará. ¿Continuar?';tr = 'Program temizlenecek. Devam edilsin mi?';it = 'Il grafico sarà cancellato, continuare?';de = 'Plan wird gelöscht. Fortsetzen?'");
		ShowQueryBox(Notification, QueryMessage, Mode, 0);
		
		Record.Enabled = True;
		
	Else
		
		EnabledOnChangeEnd(True, New Structure);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	Write(New Structure("WriteAndClose"));
	
EndProcedure

&AtClient
Procedure SetJobShedule(Command)
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("PrevSchedule", Schedule);
	
	If Schedule = Undefined Then
		Schedule = New JobSchedule;
	EndIf;
	
	SetNewShedule = New NotifyDescription("SetNewShedule", ThisObject, AdditionalParameters);
	SheduleDialog = New ScheduledJobDialog(Schedule);
	SheduleDialog.Show(SetNewShedule);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SetScheduleVisibility() 

	If Record.Mode = AutomaticallyScheduled Then
		
		Items.GroupSchedule.Visible	= True;
		Items.JobShedule.Enabled 	= Record.Enabled;
		Items.JobShedule.ToolTipRepresentation = ?(Record.Enabled, ToolTipRepresentation.None, ToolTipRepresentation.Button);
		
	Else
		
		Items.GroupSchedule.Visible	= False;
		
	EndIf;

EndProcedure

&AtClient
Procedure SetScheduleButtonTitle()
	
	If Schedule = Undefined Then
		Items.JobShedule.Title = NStr("en = 'Fill in schedule'; ru = 'Заполнить график';pl = 'Wypełnij w harmonogramie';es_ES = 'Rellene el horario';es_CO = 'Rellene el horario';tr = 'Programı doldur';it = 'Compilare grafico';de = 'Zeitplan ausfüllen'");
	Else
		Items.JobShedule.Title = Left(Schedule, 50);
	EndIf;
	
EndProcedure

&AtClient
Procedure SetNewShedule(NewSchedule, AdditionalParameters) Export
	
	If NewSchedule = Undefined Then
		
		Schedule = AdditionalParameters.PrevSchedule;
		Return;
		
	EndIf;
	
	Schedule = NewSchedule;
	Modified = True;
	SetScheduleButtonTitle();	
	
EndProcedure

&AtServer
Function FindTypeOfAccounting(Company, TypeOfAccounting, TypeofAccountingPeriod)

	TypeofAccountingPeriod = CurrentSessionDate();
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	CompaniesTypesOfAccounting.ChartOfAccounts AS ChartOfAccounts
	|FROM
	|	InformationRegister.CompaniesTypesOfAccounting.SliceLast(
	|			&Period,
	|			Company = &Company
	|				AND TypeOfAccounting = &TypeOfAccounting) AS CompaniesTypesOfAccounting
	|WHERE
	|	NOT CompaniesTypesOfAccounting.Inactive";

	Query.SetParameter("Company"			, Company);
	Query.SetParameter("TypeOfAccounting"	, TypeOfAccounting);
	Query.SetParameter("Period"				, TypeofAccountingPeriod);

	QueryResult = Query.Execute();
	
	Return QueryResult.IsEmpty();

EndFunction

&AtServer
Procedure DisableRecord(KeyStructure)

	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	AccountingTransactionGenerationSettings.Company AS Company,
	|	AccountingTransactionGenerationSettings.TypeOfAccounting AS TypeOfAccounting,
	|	AccountingTransactionGenerationSettings.Mode AS Mode,
	|	AccountingTransactionGenerationSettings.Enabled AS Enabled,
	|	AccountingTransactionGenerationSettings.Author AS Author,
	|	AccountingTransactionGenerationSettings.ScheduledJobUUID AS ScheduledJobUUID,
	|	AccountingTransactionGenerationSettings.Comment AS Comment
	|FROM
	|	InformationRegister.AccountingTransactionGenerationSettings AS AccountingTransactionGenerationSettings
	|WHERE
	|	AccountingTransactionGenerationSettings.Company = &Company
	|	AND AccountingTransactionGenerationSettings.TypeOfAccounting = &TypeOfAccounting
	|	AND AccountingTransactionGenerationSettings.Mode = &Mode
	|	AND AccountingTransactionGenerationSettings.Enabled";

	Query.SetParameter("Company"			, KeyStructure.Company);
	Query.SetParameter("TypeOfAccounting"	, KeyStructure.TypeOfAccounting);
	Query.SetParameter("Mode"				, KeyStructure.Mode);

	QueryResult	 = Query.Execute();
	
	Selection	 = QueryResult.Select();
	Selection.Next();
	
	EnabledRecord = InformationRegisters.AccountingTransactionGenerationSettings.CreateRecordManager();
	FillPropertyValues(EnabledRecord, Selection);
	EnabledRecord.Enabled = False;
	EnabledRecord.Write();

EndProcedure

&AtClient
Procedure WriteObjectEnd(Response, WriteParameters) Export

	If Response = DialogReturnCode.Yes Then
		
		If WriteParameters.CheckParameter = "TypeOfAccounting" Then
			WriteParameters.Insert("DoNotCheckTypeOfAccounting");
		ElsIf WriteParameters.CheckParameter = "EnabledSettingsExist" Then
			
			WriteParameters.Insert("DoNotCheckEnabledSettingsExist");
			DisableRecord(WriteParameters.KeyStructure);
			
		EndIf;
		
		Write(WriteParameters);
		
	ElsIf Response = DialogReturnCode.No Then
		
		If WriteParameters.CheckParameter = "TypeOfAccounting" Then
			
			WriteParameters.Insert("DoNotCheckTypeOfAccounting");
			Write(WriteParameters);
		
		EndIf;
		
	ElsIf Response = Undefined
		And WriteParameters.Property("WriteAndClose") Then
		
		Modified = False;
		Close();
		
	EndIf;
	
EndProcedure

&AtServer
Function CheckEnabledSettingsExist(Cancel)

	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	AccountingTransactionGenerationSettings.Company AS Company,
	|	AccountingTransactionGenerationSettings.TypeOfAccounting AS TypeOfAccounting,
	|	AccountingTransactionGenerationSettings.Mode AS Mode
	|FROM
	|	InformationRegister.AccountingTransactionGenerationSettings AS AccountingTransactionGenerationSettings
	|WHERE
	|	AccountingTransactionGenerationSettings.Company = &Company
	|	AND AccountingTransactionGenerationSettings.TypeOfAccounting = &TypeOfAccounting
	|	AND AccountingTransactionGenerationSettings.Enabled
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	1 AS Field1
	|FROM
	|	InformationRegister.AccountingTransactionGenerationSettings AS AccountingTransactionGenerationSettings
	|WHERE
	|	AccountingTransactionGenerationSettings.Company = &Company
	|	AND AccountingTransactionGenerationSettings.TypeOfAccounting = &TypeOfAccounting
	|	AND AccountingTransactionGenerationSettings.Mode = &Mode";

	Query.SetParameter("Mode"				, Record.Mode);
	Query.SetParameter("Company"			, Record.Company);
	Query.SetParameter("TypeOfAccounting"	, Record.TypeOfAccounting);
	
	QueryResult = Query.ExecuteBatch();
	
	If Record.Enabled
		And Not QueryResult[0].IsEmpty() Then
		
		Selection = QueryResult[0].Select();
		Selection.Next();
		
		KeyStructure = New Structure("Company, TypeOfAccounting, Mode");
		FillPropertyValues(KeyStructure, Selection);
		
		If Record.SourceRecordKey <> InformationRegisters.AccountingTransactionGenerationSettings.CreateRecordKey(KeyStructure) Then
			
			MessageTmpl = NStr("en = 'For ""%1"" and ""%2"", other settings are already enabled. The settings in this window will be disabled. Continue?'; ru = 'Для ""%1"" и ""%2"" прочие настройки уже включены. Настройки в этом окне будут отключены. Продолжить?';pl = 'Dla ""%1"" i ""%2"", już są włączone inne ustawienia. Ustawienia w tym oknie zostaną wyłączone. Kontynuować?';es_ES = 'Para ""%1"" y ""%2"", los demás ajustes ya están habilitados. Los ajustes de esta ventana estarán desactivados. ¿Continuar?';es_CO = 'Para ""%1"" y ""%2"", los demás ajustes ya están habilitados. Los ajustes de esta ventana estarán desactivados. ¿Continuar?';tr = '""%1"" ve ""%2"" için, başka ayarlar etkinleştirilmiş durumda. Bu penceredeki ayarlar devre dışı bırakılacak. Devam edilsin mi?';it = 'Per ""%1"" e ""%2"" sono già attivate altre impostazioni. Le impostazioni in questa finestra saranno disattivate, continuare?';de = 'Für ""%1"" und ""%2"", sind andere Einstellungen bereits aktiviert. Die Einstellungen in diesem Fenster werden deaktiviert. Weiter?'");
			MessageText = StrTemplate(MessageTmpl, Selection.Company, Selection.TypeOfAccounting);
			
			Return New Structure("Text, KeyStructure", MessageText, KeyStructure);
						
		EndIf;
		
	ElsIf Not ValueIsFilled(Record.SourceRecordKey)
		And Not QueryResult[1].IsEmpty() Then
		
		MessageText = NStr("en = 'Cannot save the changes. The same Accounting generation transaction settings already exist.'; ru = 'Не удалось сохранить изменения. Такие настройки формирования бухгалтерских операций уже существуют.';pl = 'Nie można zapisać zmian. Te same ustawienia Generacji rachunkowości już istnieją.';es_ES = 'No se pueden guardar los cambios. La misma configuración de generación de la transacción contable ya existe.';es_CO = 'No se pueden guardar los cambios. La misma configuración de generación de la transacción contable ya existe.';tr = 'Değişiklikler kaydedilemiyor. Aynı Muhasebe oluşturma işlem ayarları zaten mevcut.';it = 'Impossibile salvare le modifiche. Esistono già le medesime impostazioni di transazione di creazione contabilità.';de = 'Fehler beim Speichern von Änderungen. Dieselbe Einstellungen von Buchhaltungsgenerierungstransaktion bestehen bereits.'");
		CommonClientServer.MessageToUser(MessageText, , , , Cancel);
		
		Return New Structure("Text, KeyStructure", MessageText, Undefined);
		
	EndIf;
	
	Return New Structure("Text, KeyStructure", "", Undefined);
	
EndFunction

&AtClient
Procedure EnabledOnChangeEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		Record.Enabled	= False;
		Schedule		= Undefined;
		SetScheduleButtonTitle();	
		SetScheduleVisibility();
		
	ElsIf Result = True Then
		
		SetScheduleVisibility();
		
	EndIf;
	
EndProcedure

#EndRegion