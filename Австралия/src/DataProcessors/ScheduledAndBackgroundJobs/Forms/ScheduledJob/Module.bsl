
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If NOT Users.IsFullUser(, True) Then
		Raise NStr("ru = 'Недостаточно прав доступа.
		                             |
		                             |Изменение свойств регламентного задания
		                             |выполняется только администраторами.'; 
		                             |en = 'Insufficient access rights.
		                             |
		                             |Changing scheduled job properties
		                             |is executed only by administrators.'; 
		                             |pl = 'Niewystarczające uprawnienia dostępu.
		                             |
		                             |Zmiana właściwości zaplanowanego zadania
		                             |jest wykonywana tylko przez administratorów.';
		                             |es_ES = 'Insuficientes derechos de acceso.
		                             |
		                             |Cambio de propiedades de la
		                             |tarea programada se ha ejecutado solo por administradores.';
		                             |es_CO = 'Insuficientes derechos de acceso.
		                             |
		                             |Cambio de propiedades de la
		                             |tarea programada se ha ejecutado solo por administradores.';
		                             |tr = 'Yetersiz erişim hakları.
		                             |
		                             | Zamanlanmış 
		                             |işin özellikleri yalnızca yöneticiler tarafından değiştirilir.';
		                             |it = 'Permessi di accesso insufficienti.
		                             |
		                             |La modifica delle proprietà del processo pianificato
		                             |è eseguita solo da amministratori.';
		                             |de = 'Unzureichende Zugriffsrechte.
		                             |
		                             |Ändern der Eigenschaften eines
		                             |geplanten Jobs wird nur von Administratoren ausgeführt.'");
	EndIf;
	
	Action = Parameters.Action;
	
	If StrFind(", Add, Copy, Change,", ", " + Action + ",") = 0 Then
		
		Raise NStr("ru = 'Неверные параметры открытия формы ""Регламентное задание"".'; en = 'Incorrect opening parameters of the Scheduled job form.'; pl = 'Niepoprawne parametry otwierania formularza ""Zaplanowane zadanie"".';es_ES = 'Parámetros incorrectos de la apertura del formulario ""Tarea programada"".';es_CO = 'Parámetros incorrectos de la apertura del formulario ""Tarea programada"".';tr = '""Zamanlanmış iş"" açılış formun yanlış parametreleri.';it = 'Parametri di apertura non corretti per il modulo del processo pianificato.';de = 'Falsche Parameter beim Öffnen des Formulars ""Geplanter Job"".'");
	EndIf;
	
	If Action = "Add" Then
		
		FilterParameters        = New Structure;
		ParameterizedJobs = New Array;
		JobDependencies     = ScheduledJobsInternal.ScheduledJobsDependentOnFunctionalOptions();
		
		FilterParameters.Insert("IsParameterized", True);
		SearchResult = JobDependencies.FindRows(FilterParameters);
		
		For Each TableRow In SearchResult Do
			ParameterizedJobs.Add(TableRow.ScheduledJob);
		EndDo;
		
		Schedule = New JobSchedule;
		
		For Each ScheduledJobMetadata In Metadata.ScheduledJobs Do
			If ParameterizedJobs.Find(ScheduledJobMetadata) <> Undefined Then
				Continue;
			EndIf;
			
			ScheduledJobMetadataDetails.Add(
				ScheduledJobMetadata.Name
					+ Chars.LF
					+ ScheduledJobMetadata.Synonym
					+ Chars.LF
					+ ScheduledJobMetadata.MethodName,
				?(IsBlankString(ScheduledJobMetadata.Synonym),
				  ScheduledJobMetadata.Name,
				  ScheduledJobMetadata.Synonym) );
		EndDo;
	Else
		Job = ScheduledJobsServer.GetScheduledJob(Parameters.ID);
		FillPropertyValues(
			ThisObject,
			Job,
			"Key,
			|Predefined,
			|Use,
			|Description,
			|UserName,
			|RestartIntervalOnFailure,
			|RestartCountOnFailure");
		
		ID = String(Job.UUID);
		If Job.Metadata = Undefined Then
			MetadataName        = NStr("ru = '<метаданные отсутствуют>'; en = '<no metadata>'; pl = '<nie ma metadanych>';es_ES = '<no hay metadatos>';es_CO = '<no metadata>';tr = '<meta veri yok>';it = '<no metadati>';de = 'Keine Metadaten'");
			MetadataSynonym    = NStr("ru = '<метаданные отсутствуют>'; en = '<no metadata>'; pl = '<nie ma metadanych>';es_ES = '<no hay metadatos>';es_CO = '<no metadata>';tr = '<meta veri yok>';it = '<no metadati>';de = 'Keine Metadaten'");
			MetadataMethodName  = NStr("ru = '<метаданные отсутствуют>'; en = '<no metadata>'; pl = '<nie ma metadanych>';es_ES = '<no hay metadatos>';es_CO = '<no metadata>';tr = '<meta veri yok>';it = '<no metadati>';de = 'Keine Metadaten'");
		Else
			MetadataName        = Job.Metadata.Name;
			MetadataSynonym    = Job.Metadata.Synonym;
			MetadataMethodName  = Job.Metadata.MethodName;
		EndIf;
		Schedule = Job.Schedule;
		
		UserMessagesAndErrorDescription = ScheduledJobsInternal
			.ScheduledJobMessagesAndErrorDescriptions(Job);
	EndIf;
	
	If Action <> "Change" Then
		ID = NStr("ru = '<будет создан при записи>'; en = '<will be created when writing>'; pl = '<będzie stworzony przy zapisie>';es_ES = '<se creará al grabar>';es_CO = '<se creará al grabar>';tr = '<yazarken oluşturulacak>';it = '<Verra creato durante la registrazione>';de = '<wird beim Schreiben erstellt>'");
		Use = False;
		
		Description = ?(
			Action = "Add",
			"",
			ScheduledJobsInternal.ScheduledJobPresentation(Job));
	EndIf;
	
	// Filling the user name selection list.
	UsersArray = InfoBaseUsers.GetUsers();
	
	For each User In UsersArray Do
		Items.UserName.ChoiceList.Add(User.Name);
	EndDo;
	
	StandardSubsystemsServer.SetGroupTitleRepresentation(ThisObject);
EndProcedure 

&AtClient
Procedure OnOpen(Cancel)
	
	If Action = "Add" Then
		AttachIdleHandler("SelectNewScheduledJobTemplate", 0.1, True);
	Else
		RefreshFormTitle();
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	Notification = New NotifyDescription("WriteAndCloseCompletion", ThisObject);
	CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DescriptionOnChange(Item)
	
	RefreshFormTitle();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Write(Command)
	
	WriteScheduledJob();
	
EndProcedure

&AtClient
Procedure WriteAndCloseComplete()
	
	WriteAndCloseCompletion();
	
EndProcedure

&AtClient
Procedure SetScheduleExecute()

	Dialog = New ScheduledJobDialog(Schedule);
	Dialog.Show(New NotifyDescription("OpenScheduleEnd", ThisObject));
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure WriteAndCloseCompletion(Result = Undefined, AdditionalParameters = Undefined) Export
	
	WriteScheduledJob();
	Modified = False;
	Close();
	
EndProcedure

&AtClient
Procedure SelectNewScheduledJobTemplate()
	
	// Scheduled job template selection (metadata).
	ScheduledJobMetadataDetails.ShowChooseItem(
		New NotifyDescription("SelectNewScheduledJobTemplateCompletion", ThisObject),
		NStr("ru = 'Выберите шаблон регламентного задания'; en = 'Select the scheduled job template'; pl = 'Wybierz szablon zaplanowanego zadania.';es_ES = 'Seleccinar un modelo de la tarea programada';es_CO = 'Seleccinar un modelo de la tarea programada';tr = 'Zamanlanmış bir iş şablonu seçin';it = 'Seleziona il template processo pianificato';de = 'Wählen Sie eine geplante Jobvorlage aus'"));
	
EndProcedure

&AtClient
Procedure SelectNewScheduledJobTemplateCompletion(ListItem, Context) Export
	
	If ListItem = Undefined Then
		Close();
		Return;
	EndIf;
	
	MetadataName       = StrGetLine(ListItem.Value, 1);
	MetadataSynonym   = StrGetLine(ListItem.Value, 2);
	MetadataMethodName = StrGetLine(ListItem.Value, 3);
	Description        = ListItem.Presentation;
	
	RefreshFormTitle();
	
EndProcedure

&AtClient
Procedure OpenScheduleEnd(NewSchedule, Context) Export

	If NewSchedule <> Undefined Then
		Schedule = NewSchedule;
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure WriteScheduledJob()
	
	If NOT ValueIsFilled(MetadataName) Then
		Return;
	EndIf;
	
	CurrentID = ?(Action = "Change", ID, Undefined);
	
	WriteScheduledJobAtServer();
	RefreshFormTitle();
	
	Notify("Write_ScheduledJobs", CurrentID);
	
EndProcedure

&AtServer
Procedure WriteScheduledJobAtServer()
	
	If Action = "Change" Then
		Job = ScheduledJobsServer.GetScheduledJob(ID);
	Else
		JobParameters = New Structure;
		JobParameters.Insert("Metadata", Metadata.ScheduledJobs[MetadataName]);
		
		Job = ScheduledJobsServer.AddJob(JobParameters);
		
		ID = String(Job.UUID);
		Action = "Change";
	EndIf;
	
	FillPropertyValues(
		Job,
		ThisObject,
		"Key, 
		|Description,
		|Use,
		|UserName,
		|RestartIntervalOnFailure,
		|RestartCountOnFailure");
	
	Job.Schedule = Schedule;
	Job.Write();
	
	Modified = False;
	
EndProcedure

&AtClient
Procedure RefreshFormTitle()
	
	If NOT IsBlankString(Description) Then
		Presentation = Description;
		
	ElsIf NOT IsBlankString(MetadataSynonym) Then
		Presentation = MetadataSynonym;
	Else
		Presentation = MetadataName;
	EndIf;
	
	If Action = "Change" Then
		Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 (Регламентное задание)'; en = '%1 (Scheduled job)'; pl = '%1(Zaplanowane zadanie)';es_ES = '%1 (Tarea programada)';es_CO = '%1 (Tarea programada)';tr = '%1 (Zamanlanmış iş)';it = '%1 (Attività pianificate)';de = '%1 (Geplanter Job)'"), Presentation);
	Else
		Title = NStr("ru = 'Регламентное задание (создание)'; en = 'Scheduled job (Create)'; pl = 'Zaplanowane zadanie (Tworzenie)';es_ES = 'Tarea programada (Crear)';es_CO = 'Tarea programada (Crear)';tr = 'Zamanlanmış iş (Oluştur)';it = 'Lavoro programmato (Creare)';de = 'Geplanter Job (Erstellen)'");
	EndIf;
	
EndProcedure

#EndRegion
