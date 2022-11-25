#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var ThisIsGlobalDataProcessor;

#EndRegion

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	If IsFolder Then
		Return;
	EndIf;
	
	ItemCheck = True;
	If AdditionalProperties.Property("ListCheck") Then
		ItemCheck = False;
	EndIf;
	
	If NOT AdditionalReportsAndDataProcessors.CheckGlobalDataProcessor(Kind) Then
		If NOT UseForObjectForm AND NOT UseForListForm 
			AND Publication <> Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled Then
			CommonClientServer.MessageToUser(
				NStr("ru = 'Необходимо отключить публикацию или выбрать для использования как минимум одну из форм'; en = 'Make the report or data processor unavailable or select at least one of its forms'; pl = 'Wyłącz publikowanie lub wybierz przynajmniej jeden z używanych formularzy';es_ES = 'Desactivar el envío o seleccionar como mínimo uno de los formularios para utilizar';es_CO = 'Desactivar el envío o seleccionar como mínimo uno de los formularios para utilizar';tr = 'Yayımlamayı devre dışı bırak veya kullanılacak formlardan en az birini seç';it = 'Rendere il report o l''elaboratore dati non disponibile o selezionare almeno uno dei moduli';de = 'Deaktivieren Sie die Veröffentlichung oder wählen Sie mindestens eines der zu verwendenden Formulare aus'")
				,
				,
				,
				"Object.UseForObjectForm",
				Cancel);
		EndIf;
	EndIf;
	
	// If the report is published, a check for uniqueness of the object name used to register the 
	//     additional report in the application is performed.
	If Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used Then
		
		// Checking the name
		QueryText =
		"SELECT TOP 1
		|	1
		|FROM
		|	Catalog.AdditionalReportsAndDataProcessors AS AdditionalReports
		|WHERE
		|	AdditionalReports.ObjectName = &ObjectName
		|	AND &AdditReportCondition
		|	AND AdditionalReports.Publication = VALUE(Enum.AdditionalReportsAndDataProcessorsPublicationOptions.Used)
		|	AND AdditionalReports.DeletionMark = FALSE
		|	AND AdditionalReports.Ref <> &Ref";
		
		AddlReportsKinds = New Array;
		AddlReportsKinds.Add(Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport);
		AddlReportsKinds.Add(Enums.AdditionalReportsAndDataProcessorsKinds.Report);
		
		If AddlReportsKinds.Find(Kind) <> Undefined Then
			QueryText = StrReplace(QueryText, "&AdditReportCondition", "AdditionalReports.Kind IN (&AddlReportsKinds)");
		Else
			QueryText = StrReplace(QueryText, "&AdditReportCondition", "NOT AdditionalReports.Kind IN (&AddlReportsKinds)");
		EndIf;
		
		Query = New Query;
		Query.SetParameter("ObjectName",     ObjectName);
		Query.SetParameter("AddlReportsKinds", AddlReportsKinds);
		Query.SetParameter("Ref",         Ref);
		Query.Text = QueryText;
		
		SetPrivilegedMode(True);
		Conflicting = Query.Execute().Unload();
		SetPrivilegedMode(False);
		
		If Conflicting.Count() > 0 Then
			Cancel = True;
			If ItemCheck Then
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Имя ""%1"", используемое данным отчетом (обработкой), уже занято другим опубликованным дополнительным отчетом (обработкой). 
					|
					|Для продолжения необходимо изменить тип публикации с ""%2"" на ""%3"" или ""%4"".'; 
					|en = 'Name ""%1"" used by this report (data processor) is already in use by another published additional report (data processor). 
					|
					|To continue, change publishing type from ""%2"" to ""%3"" or ""%4"".'; 
					|pl = 'Nazwa ""%1"" używana przez to sprawozdanie (przetwarzanie danych) jest już używana przez inne opublikowane sprawozdanie dodatkowe (przetwarzanie danych)
					|
					|. Aby kontynuować, należy zmienić rodzaj publikacji z ""%2"" na ""%3"" lub ""%4"".';
					|es_ES = 'Nombre ""%1"" utilizado por este informe (procesador de datos) está ya utilizado por otro informe adicional enviado (procesador de datos).
					|
					|Para continuar es necesario cambiar el tipo de Envío de ""%2"" a ""%3"" o ""%4"".';
					|es_CO = 'Nombre ""%1"" utilizado por este informe (procesador de datos) está ya utilizado por otro informe adicional enviado (procesador de datos).
					|
					|Para continuar es necesario cambiar el tipo de Envío de ""%2"" a ""%3"" o ""%4"".';
					|tr = 'Bu raporda kullanılan ""%1"" adı (veri işlemcisi) yayınlanan başka bir ek rapor (veri işlemcisi) tarafından zaten kullanılıyor. 
					|
					|Devam etmek için Yayın türün ""%2"", ""%3"" veya ""%4""olarak değiştirmelidir.';
					|it = 'Nome ""%1"" utilizzato da questo report (elaboratore dati) già in uso da parte di un report aggiuntivo pubblicato (elaboratore dati). 
					|
					|Per continuare, modificare il tipo di pubblicazione da ""%2"" a ""%3"" o ""%4"".';
					|de = 'Der von diesem Bericht (Datenprozessor) verwendete Name ""%1"" wird bereits von einem anderen, zusätzlich veröffentlichten Bericht (Datenprozessor) verwendet.
					|
					|Um fortzufahren, ist es notwendig, die Publikationsart von ""%2"" in ""%3"" oder ""%4"" zu ändern.'"),
					ObjectName,
					String(Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used),
					String(Enums.AdditionalReportsAndDataProcessorsPublicationOptions.DebugMode),
					String(Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled));
			Else
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Имя ""%1"", используемое отчетом (обработкой) ""%2"", уже занято другим опубликованным дополнительным отчетом (обработкой).'; en = 'The report or data processor name ""%1"" is not unique. Report or data processor ""%2"" also has that name.'; pl = 'Nazwa ""%1"" używana dla raportu lub procesora danych nie jest unikalna. Raport lub procesor danych ""%2"" ma taką samą nazwę.';es_ES = 'Nombre ""%1"" utilizado por el informe (procesador de datos) ""%2"" está ya utilizado por otro informe adicional enviado (procesador de datos).';es_CO = 'Nombre ""%1"" utilizado por el informe (procesador de datos) ""%2"" está ya utilizado por otro informe adicional enviado (procesador de datos).';tr = '""%2"" raporda kullanılan ""%1"" adı (veri işlemcisi) yayınlanan başka bir ek rapor (veri işlemcisi) tarafından zaten kullanılıyor.';it = 'Il nome del report o dell''elaboratore dati ""%1"" non è univoco. Il report o elaboratore dati ""%2"" presenta lo stesso nome.';de = 'Der Name ""%1"", der vom Bericht verwendet wird (Datenprozessor) ""%2"" wird bereits von einem anderen veröffentlichten Zusatzbericht (Datenprozessor) verwendet.'"),
					ObjectName,
					Common.ObjectAttributeValue(Ref, "Description"));
			EndIf;
			CommonClientServer.MessageToUser(ErrorText, , "Object.Publication");
		EndIf;
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	If IsFolder Then
		Return;
	EndIf;
	
	// Called right before writing the object to the database.
	AdditionalReportsAndDataProcessors.BeforeWriteAdditionalDataProcessor(ThisObject, Cancel);
	
	If IsNew() AND NOT AdditionalReportsAndDataProcessors.InsertRight(ThisObject) Then
		Raise NStr("ru = 'Недостаточно прав для добавления дополнительных отчетов или обработок.'; en = 'Insufficient access rights for adding additional reports or data processors.'; pl = 'Niewystarczające uprawnienia do dodawania dodatkowych sprawozdań lub przetwarzania danych.';es_ES = 'Derechos insuficientes para añadir informes adicionales o procesadores de datos.';es_CO = 'Derechos insuficientes para añadir informes adicionales o procesadores de datos.';tr = 'Ek raporlar veya veri işlemcileri eklemek için yetersiz haklar.';it = 'Permessi di accesso non sufficienti per aggiungere report aggiuntivi o elaboratori dati.';de = 'Unzureichende Rechte zum Hinzufügen zusätzlicher Berichte oder Datenprozessoren.'");
	EndIf;
	
	// Preliminary checks
	If NOT IsNew() AND Kind <> Common.ObjectAttributeValue(Ref, "Kind") Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Невозможно сменить вид существующего дополнительного отчета или обработки.'; en = 'Cannot change the kind of existing additional report or data processor.'; pl = 'Nie można zmienić rodzaju istniejącego dodatkowego sprawozdania lub przetwarzania danych.';es_ES = 'No se puede cambiar el tipo del informe adicional existente o el procesador de datos.';es_CO = 'No se puede cambiar el tipo del informe adicional existente o el procesador de datos.';tr = 'Mevcut ek raporun veya veri işlemcisinin türü değiştirilemez.';it = 'Non è possibile cambiare il tipo di report supplementare esistente o di elaboratore dati.';de = 'Die Art des vorhandenen zusätzlichen Berichts oder Datenprozessors kann nicht geändert werden.'"),,,,
			Cancel);
		Return;
	EndIf;
	
	// Attribute connection with deletion mark.
	If DeletionMark Then
		Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled;
	EndIf;
	
	// Cache of standard checks
	AdditionalProperties.Insert("PublicationUsed", Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used);
	
	If ThisIsGlobalDataProcessor() Then
		If ScheduleSetupRight() Then
			BeforeWriteGlobalDataProcessors(Cancel);
		EndIf;
		Purpose.Clear();
	Else
		BeforeWriteAssignableDataProcessor(Cancel);
		Sections.Clear();
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	// Called right after writing the object to the database.
	If DataExchange.Load Then
		Return;
	EndIf;
	If IsFolder Then
		Return;
	EndIf;
	
	QuickAccess = CommonClientServer.StructureProperty(AdditionalProperties, "QuickAccess");
	If TypeOf(QuickAccess) = Type("ValueTable") Then
		MeasurementsValues = New Structure("AdditionalReportOrDataProcessor", Ref);
		ResourcesValues = New Structure("Available", True);
		InformationRegisters.DataProcessorAccessUserSettings.WriteSettingsPackage(QuickAccess, MeasurementsValues, ResourcesValues, True);
	EndIf;
	
	If ThisIsGlobalDataProcessor() Then
		If ScheduleSetupRight() Then
			OnWriteGlobalDataProcessor(Cancel);
		EndIf;
	Else
		OnWriteAssignableDataProcessors(Cancel);
	EndIf;
	
	If Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport
		Or Kind = Enums.AdditionalReportsAndDataProcessorsKinds.Report Then
		OnWriteReport(Cancel);
	EndIf;
	
EndProcedure

Procedure BeforeDelete(Cancel)
	// Called right before deleting the object from the database.
	AdditionalReportsAndDataProcessors.BeforeDeleteAdditionalDataProcessor(ThisObject, Cancel);
	
	If DataExchange.Load Then
		Return;
	EndIf;
	If IsFolder Then
		Return;
	EndIf;
	
	If AdditionalReportsAndDataProcessors.CheckGlobalDataProcessor(Kind) Then
		BeforeDeleteGlobalDataProcessor(Cancel);
	EndIf;
EndProcedure

#EndRegion

#Region Private

Function ThisIsGlobalDataProcessor()
	
	If ThisIsGlobalDataProcessor = Undefined Then
		ThisIsGlobalDataProcessor = AdditionalReportsAndDataProcessors.CheckGlobalDataProcessor(Kind);
	EndIf;
	
	Return ThisIsGlobalDataProcessor;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Global data processors

Procedure BeforeWriteGlobalDataProcessors(Cancel)
	If Cancel OR NOT AdditionalProperties.Property("RelevantCommands") Then
		Return;
	EndIf;
	
	CommandsTable = AdditionalProperties.RelevantCommands;
	
	JobsToUpdate = New Map;
	
	PublicationEnabled = (Publication <> Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled);
	
	// Scheduled jobs must be changed in the privileged mode.
	SetPrivilegedMode(True);
	
	// Clearing jobs whose commands are deleted from the table.
	If Not IsNew() Then
		For Each ObsoleteCommand In Ref.Commands Do
			If ValueIsFilled(ObsoleteCommand.GUIDScheduledJob)
				AND CommandsTable.Find(ObsoleteCommand.GUIDScheduledJob, "GUIDScheduledJob") = Undefined Then
				ScheduledJobsServer.DeleteJob(ObsoleteCommand.GUIDScheduledJob);
			EndIf;
		EndDo;
	EndIf;
	
	// Updating the set of scheduled jobs before writing their IDs to the tabular section.
	For Each ActualCommand In CommandsTable Do
		Command = Commands.Find(ActualCommand.ID, "ID");
		
		If PublicationEnabled AND ActualCommand.ScheduledJobSchedule.Count() > 0 Then
			Schedule    = ActualCommand.ScheduledJobSchedule[0].Value;
			Usage = ActualCommand.ScheduledJobUsage
				AND AdditionalReportsAndDataProcessorsClientServer.ScheduleSpecified(Schedule);
		Else
			Schedule = Undefined;
			Usage = False;
		EndIf;
		
		Job = ScheduledJobsServer.Job(ActualCommand.GUIDScheduledJob);
		If Job = Undefined Then // Not found
			If Usage Then
				// Creating and registering a scheduled job.
				JobParameters = New Structure;
				JobParameters.Insert("Metadata", Metadata.ScheduledJobs.StartingAdditionalDataProcessors);
				JobParameters.Insert("Use", False);
				Job = ScheduledJobsServer.AddJob(JobParameters);
				JobsToUpdate.Insert(ActualCommand, Job);
				Command.GUIDScheduledJob = ScheduledJobsServer.UUID(Job);
			Else
				// No action required
			EndIf;
		Else // Found
			If Usage Then
				// Registering the job.
				JobsToUpdate.Insert(ActualCommand, Job);
			Else
				// Delete the job.
				ScheduledJobsServer.DeleteJob(ActualCommand.GUIDScheduledJob);
				Command.GUIDScheduledJob = New UUID("00000000-0000-0000-0000-000000000000");
			EndIf;
		EndIf;
	EndDo;
	
	AdditionalProperties.Insert("JobsToUpdate", JobsToUpdate);
	
EndProcedure

Procedure OnWriteGlobalDataProcessor(Cancel)
	If Cancel Or Not AdditionalProperties.Property("RelevantCommands") Then
		Return;
	EndIf;
	
	PublicationEnabled = (Publication <> Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled);
	DeepIntegrationWithSubsystemInSaaS = AdditionalReportsAndDataProcessors.DeepIntegrationWithSubsystemInSaaSIsUsed();
	
	// Scheduled jobs must be changed in the privileged mode.
	SetPrivilegedMode(True);
	
	For Each KeyAndValue In AdditionalProperties.JobsToUpdate Do
		Command = KeyAndValue.Key;
		Job = KeyAndValue.Value;
		
		Changes = New Structure;
		Changes.Insert("Use", False);
		Changes.Insert("Schedule", Undefined);
		Changes.Insert("Description", Left(JobsPresentation(Command), 120));
		
		If PublicationEnabled AND Command.ScheduledJobSchedule.Count() > 0 Then
			Changes.Schedule    = Command.ScheduledJobSchedule[0].Value;
			Changes.Use = Command.ScheduledJobUsage
				AND AdditionalReportsAndDataProcessorsClientServer.ScheduleSpecified(Changes.Schedule);
		EndIf;
		
		ProcedureParameters = New Array;
		ProcedureParameters.Add(Ref);
		ProcedureParameters.Add(Command.ID);
		
		Changes.Insert("Parameters", ProcedureParameters);
		
		If DeepIntegrationWithSubsystemInSaaS Then
			SaaSIntegration.BeforeUpdateJob(ThisObject, Command, Job, Changes);
		EndIf;
		If Changes <> Undefined Then
			ScheduledJobsServer.ChangeJob(Job, Changes);
		EndIf;
	EndDo;
	
EndProcedure

Procedure BeforeDeleteGlobalDataProcessor(Cancel)
	// Scheduled jobs must be changed in the privileged mode.
	SetPrivilegedMode(True);
	
	// Deleting all jobs.
	For Each Command In Commands Do
		If ValueIsFilled(Command.GUIDScheduledJob) Then
			ScheduledJobsServer.DeleteJob(Command.GUIDScheduledJob);
		EndIf;
	EndDo;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Operations with scheduled jobs.

Function ScheduleSetupRight()
	// Checking whether a user has rights to schedule the execution of additional reports and data processors.
	Return AccessRight("Update", Metadata.Catalogs.AdditionalReportsAndDataProcessors);
EndFunction

Function JobsPresentation(Command)
	// '[ObjectKind]: [ObjectDescription] / Command: [CommandPresentation]'
	Return (
		TrimAll(Kind)
		+ ": "
		+ TrimAll(Description)
		+ " / "
		+ NStr("ru = 'Команда'; en = 'Command'; pl = 'Polecenie';es_ES = 'Comando';es_CO = 'Comando';tr = 'Komut';it = 'Comando';de = 'Befehl'")
		+ ": "
		+ TrimAll(Command.Presentation));
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Assignable data processors.

Procedure BeforeWriteAssignableDataProcessor(Cancel)
	PurposeTable = Purpose.Unload();
	PurposeTable.GroupBy("RelatedObject");
	Purpose.Load(PurposeTable);
	
	PurposeRegisterUpdate = New Structure("RefsArray");
	
	MetadataObjectReferences = PurposeTable.UnloadColumn("RelatedObject");
	
	If NOT IsNew() Then
		For Each TableRow In Ref.Purpose Do
			If MetadataObjectReferences.Find(TableRow.RelatedObject) = Undefined Then
				MetadataObjectReferences.Add(TableRow.RelatedObject);
			EndIf;
		EndDo;
	EndIf;
	
	AdditionalProperties.Insert("MetadataObjectsRefs", MetadataObjectReferences);
EndProcedure

Procedure OnWriteAssignableDataProcessors(Cancel)
	If Cancel OR NOT AdditionalProperties.Property("MetadataObjectsRefs") Then
		Return;
	EndIf;
	
	InformationRegisters.AdditionalDataProcessorsPurposes.UpdateDataByMetadataObjectReferences(AdditionalProperties.MetadataObjectsRefs);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Global reports

Procedure OnWriteReport(Cancel)
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		
		Try
			If IsNew() Then
				ExternalObject = ExternalReports.Create(ObjectName);
			Else
				ExternalObject = AdditionalReportsAndDataProcessors.ExternalDataProcessorObject(Ref);
			EndIf;
		Except
			ErrorText = NStr("ru = 'Ошибка подключения:'; en = 'Attachment error:'; pl = 'Błąd połączenia:';es_ES = 'Error de conexión:';es_CO = 'Error de conexión:';tr = 'Bağlantı hatası:';it = 'Errore allegato:';de = 'Verbindungsfehler'") + Chars.LF + DetailErrorDescription(ErrorInfo());
			AdditionalReportsAndDataProcessors.WriteError(Ref, ErrorText);
			AdditionalProperties.Insert("ConnectionError", ErrorText);
			ExternalObject = Undefined;
		EndTry;
		
		AdditionalProperties.Insert("Global", ThisIsGlobalDataProcessor());
		
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		ModuleReportsOptions.OnWriteAdditionalReport(ThisObject, Cancel, ExternalObject);
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
