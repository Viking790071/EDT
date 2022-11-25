#Region Variables

&AtClient
Var AdministrationParameters, CurrentLockValue;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		SessionWithoutSeparators = ModuleSaaS.SessionWithoutSeparators();
	Else
		SessionWithoutSeparators = True;
	EndIf;
	
	IsFileInfobase = Common.FileInfobase();
	IsSystemAdministrator = Users.IsFullUser(, True);
	
	If IsFileInfobase Or Not IsSystemAdministrator Then
		Items.DisableScheduledJobsGroup.Visible = False;
	EndIf;
	
	If Common.DataSeparationEnabled() Or Not IsSystemAdministrator Then
		Items.UnlockCode.Visible = False;
	EndIf;
	
	SetInitialUserAuthorizationRestrictionStatus();
	RefreshSettingsPage();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ClientConnectedOverWebServer = CommonClient.ClientConnectedOverWebServer();
	If IBConnectionsClient.SessionTerminationInProgress() Then
		Items.ModeGroup.CurrentPage = Items.LockStatePage;
		RefreshStatePage(ThisObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	BlockingSessionsInformation = IBConnections.BlockingSessionsInformation(NStr("ru = 'Блокировка не установлена.'; en = 'The lock is not set.'; pl = 'Nie zablokowany.';es_ES = 'No bloqueado.';es_CO = 'No bloqueado.';tr = 'Kilitlenmedi.';it = 'Il blocco non è stato impostato.';de = 'Nicht verschlossen.'"));
	
	If BlockingSessionsInformation.HasBlockingSessions Then
		Raise BlockingSessionsInformation.MessageText;
	EndIf;
	
	SessionCount = BlockingSessionsInformation.SessionCount;
	
	// Checking if a lock can be set.
	If Object.LockEffectiveFrom > Object.LockEffectiveTo 
		AND ValueIsFilled(Object.LockEffectiveTo) Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Дата окончания блокировки не может быть меньше даты начала блокировки. Блокировка не установлена.'; en = 'Lock end date cannot be earlier than lock start date. Lock is not set.'; pl = 'Data zakończenia blokady nie może być wcześniejsza niż data rozpoczęcia blokady. Blokada nie jest ustawiona.';es_ES = 'Bloqueo de la fecha final no puede ser antes del bloqueo de la fecha inicial. Bloqueo no está establecido.';es_CO = 'Bloqueo de la fecha final no puede ser antes del bloqueo de la fecha inicial. Bloqueo no está establecido.';tr = 'Kilit bitiş tarihi, kilit başlangıç tarihinden önce olamaz. Kilit ayarlanmamış.';it = 'La data di fine del blocco non può essere inferiore alla data di inizio del blocco. Il blocco non è installato.';de = 'Das Enddatum der Sperre darf nicht vor dem Startdatum der Sperre liegen. Sperre ist nicht eingestellt.'"),,
			"Object.LockEffectiveTo",,Cancel);
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.LockEffectiveFrom) Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Не указана дата начала блокировки.'; en = 'Lock start date is not specified.'; pl = 'Data rozpoczęcia blokady nie została określona.';es_ES = 'Fecha inicial del bloqueo no está especificada.';es_CO = 'Fecha inicial del bloqueo no está especificada.';tr = 'Kilit başlangıç tarihi belirtilmemiş.';it = 'Blocco data di inizio non è specificato.';de = 'Startdatum der Sperre ist nicht angegeben.'"),, "Object.LockEffectiveFrom",,Cancel);
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "UserSessionsCompletion" Then
		SessionCount = Parameter.SessionCount;
		UpdateLockState(ThisObject);
		If Parameter.Status = "Finish" Then
			Close();
		ElsIf Parameter.Status = "Error" Then
			ShowMessageBox(,NStr("ru = 'Не удалось завершить работу всех активных пользователей.
				|Подробности см. в Журнале регистрации.'; 
				|en = 'Cannot close sessions of all active users.
				|For more information, see the Event log.'; 
				|pl = 'Nie udało się zamknąć wszystkich aktywnych użytkowników.
				|Szczegółowe informacje zawiera dziennik.';
				|es_ES = 'No se puede finalizar las sesiones de todos usuarios activos.
				|Buscar los detalles en el Registro de eventos.';
				|es_CO = 'No se puede finalizar las sesiones de todos usuarios activos.
				|Buscar los detalles en el Registro de eventos.';
				|tr = 'Tüm aktif kullanıcıların oturumları sonlandırılamıyor.
				|Ayrıntılar için bkz. Olay günlüğü.';
				|it = 'Impossibile la chiusura delle sessioni per tutti gli utenti attivi.
				|Per maggiori informazioni, guardare il registro eventi.';
				|de = 'Es war nicht möglich, alle aktiven Benutzer abzuschalten.
				|Details im Ereignisprotokoll.'"), 30);
			Close();
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ActiveUsers(Command)
	
	OpenForm("DataProcessor.ActiveUsers.Form",, ThisObject);
	
EndProcedure

&AtClient
Procedure Apply(Command)
	
	ClearMessages();
	
	Object.DisableUserAuthorisation = Not InitialUserAuthorizationRestrictionStatusValue;
	If Object.DisableUserAuthorisation Then
		
		SessionCount = 1;
		Try
			If Not CheckLockPreconditions() Then
				Return;
			EndIf;
		Except
			CommonClientServer.MessageToUser(BriefErrorDescription(ErrorInfo()));
			Return;
		EndTry;
		
		QuestionTitle = NStr("ru = 'Блокировка работы пользователей'; en = 'Application lock'; pl = 'Blokowanie operacji użytkownika';es_ES = 'Bloqueo de la operación del usuario';es_CO = 'Bloqueo de la operación del usuario';tr = 'Kullanıcı operasyon kilitleme';it = 'Blocco applicazione';de = 'Sperrung der Benutzerbedienung'");
		If SessionCount > 1 AND Object.LockEffectiveFrom < CommonClient.SessionDate() + 5 * 60 Then
			QuestionText = NStr("ru = 'Указано слишком близкое время начала действия блокировки, к которому пользователи могут не успеть сохранить все свои данные и завершить работу.
				|Рекомендуется установить время начала на 5 минут относительно текущего времени.'; 
				|en = 'Too close lock start time, by which users may not have time to save all their data and close their sessions. 
				|It is recommended that you set the start time 5 minutes later relative to the current time.'; 
				|pl = 'Ustawiono zbyt wczesny czas rozpoczęcia blokowania, użytkownicy mogą mieć za mało czasu, aby zapisać wszystkie swoje dane i zakończyć sesje.
				|Zaleca się ustawienie czasu rozpoczęcia na 5 minut później od bieżącego czasu.';
				|es_ES = 'La hora demasiado temprana de inicio está establecida, puede ser que los usuarios no tengan suficiente tiempo para guardar todos sus datos y finalizar sus sesiones.
				|Se recomienda establecer la hora de inicio 5 minutos después de la hora actual.';
				|es_CO = 'La hora demasiado temprana de inicio está establecida, puede ser que los usuarios no tengan suficiente tiempo para guardar todos sus datos y finalizar sus sesiones.
				|Se recomienda establecer la hora de inicio 5 minutos después de la hora actual.';
				|tr = 'Engellemenin çok erken başlama zamanı ayarlanmışsa, kullanıcılar tüm verilerini kaydetme ve oturumlarını sonlandırma için yeterli zamana sahip olmayabilir. 
				|Başlangıç saatinden 5 dakika sonra başlangıç zamanının ayarlanması önerilir.';
				|it = 'Tempo di blocco troppo ravvicinato, durante questo periodo gli utenti potrebbero non avere il tempo per salvare tutti i loro dati e chiudere le proprie sessioni.
				|Si raccomanda di impostare un tempo di inizio blocco 5 minuti dopo l''orario corrente.';
				|de = 'Zu frühe Startzeit der Blockierung ist festgelegt, Benutzer haben möglicherweise nicht genügend Zeit, alle ihre Daten zu speichern und ihre Sitzungen zu beenden.
				|Es wird empfohlen, die Startzeit 5 Minuten später als die aktuelle Uhrzeit einzustellen.'");
			Buttons = New ValueList;
			Buttons.Add(DialogReturnCode.Yes, NStr("ru = 'Заблокировать через 5 минут'; en = 'Lock in 5 minutes'; pl = 'Zablokować po upływie 5 minut';es_ES = 'Bloquear en 5 minutos';es_CO = 'Bloquear en 5 minutos';tr = '5 dakika içinde kilitleme';it = 'Blocca in 5 minuti';de = 'Blockieren in 5 Minuten'"));
			Buttons.Add(DialogReturnCode.No, NStr("ru = 'Заблокировать сейчас'; en = 'Lock now'; pl = 'Zablokować teraz';es_ES = 'Bloquear ahora';es_CO = 'Bloquear ahora';tr = 'Şimdi kilitle';it = 'Blocca ora';de = 'Jetzt sperren'"));
			Buttons.Add(DialogReturnCode.Cancel, NStr("ru = 'Отмена'; en = 'Cancel'; pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = 'İptal et';it = 'Annulla';de = 'Abbrechen'"));
			Notification = New NotifyDescription("ApplyCompletion", ThisObject, "LockTimeTooSoon");
			ShowQueryBox(Notification, QuestionText, Buttons,,, QuestionTitle);
		ElsIf Object.LockEffectiveFrom > CommonClient.SessionDate() + 60 * 60 Then
			QuestionText = NStr("ru = 'Указано слишком большое время начала действия блокировки (более, чем через час).
				|Запланировать блокировку на указанное время?'; 
				|en = 'Lock start time is too large (more than in one hour).
				|Schedule the lock for the specified time?'; 
				|pl = 'Czas rozpoczęcia blokowania jest zbyt późny (ponad godzina).
				|Czy chcesz zaplanować blokowanie na określony czas?';
				|es_ES = 'Fecha de inicio del bloqueo es demasiado tarde (más de en una hora).
				|¿Quiere programar el bloqueo para la hora especificada?';
				|es_CO = 'Fecha de inicio del bloqueo es demasiado tarde (más de en una hora).
				|¿Quiere programar el bloqueo para la hora especificada?';
				|tr = 'Engellemenin statü süresi çok geç (bir saatten fazla). 
				|Belirtilen süre için kilitlemeyi programlamak ister misiniz?';
				|it = 'Il tempo di blocco è troppo lontano (oltre un''ora).
				|Pianificare il blocco all''orario specificato.';
				|de = 'Die Blockierungszeit ist zu spät (mehr als in einer Stunde).
				|Möchten Sie die Sperrung für die angegebene Zeit planen?'");
			Buttons = New ValueList;
			Buttons.Add(DialogReturnCode.No, NStr("ru = 'Запланировать'; en = 'To plan'; pl = 'Zaplanuj';es_ES = 'Planear';es_CO = 'Planear';tr = 'Planla';it = 'Da pianificare';de = 'Planen'"));
			Buttons.Add(DialogReturnCode.Yes, NStr("ru = 'Заблокировать сейчас'; en = 'Lock now'; pl = 'Zablokować teraz';es_ES = 'Bloquear ahora';es_CO = 'Bloquear ahora';tr = 'Şimdi kilitle';it = 'Blocca ora';de = 'Jetzt sperren'"));
			Buttons.Add(DialogReturnCode.Cancel, NStr("ru = 'Отмена'; en = 'Cancel'; pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = 'İptal et';it = 'Annulla';de = 'Abbrechen'"));
			Notification = New NotifyDescription("ApplyCompletion", ThisObject, "LockTimeTooLate");
			ShowQueryBox(Notification, QuestionText, Buttons,,, QuestionTitle);
		Else
			If Object.LockEffectiveFrom - CommonClient.SessionDate() > 15*60 Then
				QuestionText = NStr("ru = 'Завершение работы всех активных пользователей будет произведено в период с %1 по %2.
					|Продолжить?'; 
					|en = 'All active user sessions will be closed from %1 to %2.
					|Continue?'; 
					|pl = 'Sesje wszystkich aktywnych użytkowników zostaną zakończone w okresie od %1do %2.
					|Kontynuować?';
					|es_ES = 'Sesiones de todos usuarios activos se finalizarán durante el período desde %1 hasta %2.
					|¿Continuar?';
					|es_CO = 'Sesiones de todos usuarios activos se finalizarán durante el período desde %1 hasta %2.
					|¿Continuar?';
					|tr = 'Tüm aktif kullanıcıların oturumları %1''den %2 kadar olan süre içinde sonlandırılacak. 
					|Devam et?';
					|it = 'Tutte le sessioni utenti saranno terminate da %1 a %2.
					|Continuare?';
					|de = 'Sitzungen aller aktiven Benutzer werden während des Zeitraums von %1 bis %2 beendet.
					|Fortsetzen?'");
			Else
				QuestionText = NStr("ru = 'Сеансы всех активных пользователей будут завершены к %2.
					|Продолжить?'; 
					|en = 'All active user sessions will be terminated by %2.
					|Continue?'; 
					|pl = 'Sesje wszystkich aktywnych użytkowników zostaną zakończone o %2.
					|Kontynuować?';
					|es_ES = 'Sesiones de todos usuarios activos se finalizarán antes de %2.
					|¿Continuar?';
					|es_CO = 'Sesiones de todos usuarios activos se finalizarán antes de %2.
					|¿Continuar?';
					|tr = 'Tüm aktif kullanıcı oturumları %2 tarafından sonlandırılacak.
					|Devam etmek istiyor musunuz?';
					|it = 'Tutte le sessioni utente attive saranno terminate entro %2.
					|Continuare?';
					|de = 'Sitzungen aller aktiven Benutzer werden durch %2 beendet.
					|Fortsetzen?'");
			EndIf;
			Notification = New NotifyDescription("ApplyCompletion", ThisObject, "ConfirmPassword");
			QuestionText = StringFunctionsClientServer.SubstituteParametersToString(QuestionText, Object.LockEffectiveFrom - 900, Object.LockEffectiveFrom);
			ShowQueryBox(Notification, QuestionText, QuestionDialogMode.OKCancel,,, QuestionTitle);
		EndIf;
		
	Else
		
		Notification = New NotifyDescription("ApplyCompletion", ThisObject, "ConfirmPassword");
		ExecuteNotifyProcessing(Notification, DialogReturnCode.OK);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ApplyCompletion(Response, Option) Export
	
	If Option = "LockTimeTooSoon" Then
		If Response = DialogReturnCode.Yes Then
			Object.LockEffectiveFrom = CommonClient.SessionDate() + 5 * 60;
		ElsIf Response <> DialogReturnCode.No Then
			Return;
		EndIf;
	ElsIf Option = "LockTimeTooLate" Then
		If Response = DialogReturnCode.Yes Then
			Object.LockEffectiveFrom = CommonClient.SessionDate() + 5 * 60;
		ElsIf Response <> DialogReturnCode.No Then
			Return;
		EndIf;
	ElsIf Option = "ConfirmPassword" Then
		If Response <> DialogReturnCode.OK Then
			Return;
		EndIf;
	EndIf;
	
	If CorrectAdministrationParametersEntered AND IsSystemAdministrator AND Not IsFileInfobase
		AND CurrentLockValue <> Object.DisableScheduledJobs Then
		
		Try
			
			If ClientConnectedOverWebServer Then
				SetScheduledJobLockAtServer(AdministrationParameters);
			Else
				ClusterAdministrationClientServer.SetInfobaseScheduledJobLock(
					AdministrationParameters, Undefined, Object.DisableScheduledJobs);
			EndIf;
			
		Except
			EventLogClient.AddMessageForEventLog(IBConnectionsClientServer.EventLogEvent(), "Error",
				DetailErrorDescription(ErrorInfo()),, True);
			Items.ErrorGroup.Visible = True;
			Items.ErrorText.Title = BriefErrorDescription(ErrorInfo());
			Return;
		EndTry;
		
	EndIf;
	
	If Not IsFileInfobase AND Not CorrectAdministrationParametersEntered AND SessionWithoutSeparators Then
		
		NotifyDescription = New NotifyDescription("AfterGetAdministrationParametersOnLock", ThisObject);
		FormHeader = NStr("ru = 'Управление блокировкой сеансов'; en = 'Session lock management'; pl = 'Zarządzanie blokowaniem sesji';es_ES = 'Gestión de bloqueo de sesiones';es_CO = 'Gestión de bloqueo de sesiones';tr = 'Oturum kilitleme yönetimi';it = 'Gestire il blocco delle sessioni';de = 'Sitzungssperrverwaltung'");
		NoteLabel = NStr("ru = 'Для управления блокировкой сеансов необходимо ввести
			|параметры администрирования кластера серверов и информационной базы'; 
			|en = 'To manage session locking, enter
			|administration parameters of server cluster and infobase'; 
			|pl = 'Aby zarządzać blokowaniem sesji, musisz wprowadzić
			| klaster serwera i parametry administracyjne bazy informacyjnej';
			|es_ES = 'Para la gestión de bloqueo de sesiones es necesario introducir
			|los parámetros de administración del clúster del servidor y las infobases';
			|es_CO = 'Para la gestión de bloqueo de sesiones es necesario introducir
			|los parámetros de administración del clúster del servidor y las infobases';
			|tr = 'Oturum kilidi yönetimi için sunucu kümesinin 
			|ve bilgi tabanlarının yönetim parametrelerini girmek gerekir';
			|it = 'Per gestire il blocco sessione, inserire
			|parametri di amministrazione del server cluster o infobase';
			|de = 'Um die Sitzungssperre zu verwalten, ist es notwendig,
			|die Parameter des Server-Clusters und der Datenbankverwaltung einzugeben'");
		IBConnectionsClient.ShowAdministrationParameters(NotifyDescription, True,
			True, AdministrationParameters, FormHeader, NoteLabel);
		
	Else
		
		AfterGetAdministrationParametersOnLock(True, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Stop(Command)
	
	If Not IsFileInfobase AND Not CorrectAdministrationParametersEntered AND SessionWithoutSeparators Then
		
		NotifyDescription = New NotifyDescription("AfterGetAdministrationParametersOnUnlock", ThisObject);
		FormHeader = NStr("ru = 'Управление блокировкой сеансов'; en = 'Session lock management'; pl = 'Zarządzanie blokowaniem sesji';es_ES = 'Gestión de bloqueo de sesiones';es_CO = 'Gestión de bloqueo de sesiones';tr = 'Oturum kilitleme yönetimi';it = 'Gestire il blocco delle sessioni';de = 'Sitzungssperrverwaltung'");
		NoteLabel = NStr("ru = 'Для управления блокировкой сеансов необходимо ввести
			|параметры администрирования кластера серверов и информационной базы'; 
			|en = 'To manage session locking, enter
			|administration parameters of server cluster and infobase'; 
			|pl = 'Aby zarządzać blokowaniem sesji, musisz wprowadzić
			| klaster serwera i parametry administracyjne bazy informacyjnej';
			|es_ES = 'Para la gestión de bloqueo de sesiones es necesario introducir
			|los parámetros de administración del clúster del servidor y las infobases';
			|es_CO = 'Para la gestión de bloqueo de sesiones es necesario introducir
			|los parámetros de administración del clúster del servidor y las infobases';
			|tr = 'Oturum kilidi yönetimi için sunucu kümesinin 
			|ve bilgi tabanlarının yönetim parametrelerini girmek gerekir';
			|it = 'Per gestire il blocco sessione, inserire
			|parametri di amministrazione del server cluster o infobase';
			|de = 'Um die Sitzungssperre zu verwalten, ist es notwendig,
			|die Parameter des Server-Clusters und der Datenbankverwaltung einzugeben'");
		IBConnectionsClient.ShowAdministrationParameters(NotifyDescription, True,
			True, AdministrationParameters, FormHeader, NoteLabel);
		
	Else
		
		AfterGetAdministrationParametersOnUnlock(True, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AdministrationParameters(Command)
	
	NotifyDescription = New NotifyDescription("AfterGetAdministrationParameters", ThisObject);
	FormHeader = NStr("ru = 'Управление блокировкой регламентных заданий'; en = 'Scheduled job lock management'; pl = 'Harmonogram zarządzania blokowaniem zadań';es_ES = 'Gestión de bloqueo de tareas programadas';es_CO = 'Gestión de bloqueo de tareas programadas';tr = 'Zamanlanmış iş kilidi yönetimi';it = 'Controllo del blocco delle attività pianificate';de = 'Geplante Auftragssperre'");
	NoteLabel = NStr("ru = 'Для управления блокировкой регламентных заданий необходимо
		|ввести параметры администрирования кластера серверов и информационной базы'; 
		|en = 'To manage locks of scheduled jobs,
		|enter administration parameters of server cluster and infobase'; 
		|pl = 'Aby kontrolować blokowanie zaplanowanych zadań, należy
		|wprowadzić klaster serwerów i parametry administracyjne bazy informacyjnej';
		|es_ES = 'Para gestión de bloqueo de tareas programadas es necesario
		|introducir los parámetros de administración del clúster del servidor y las infobases';
		|es_CO = 'Para gestión de bloqueo de tareas programadas es necesario
		|introducir los parámetros de administración del clúster del servidor y las infobases';
		|tr = 'Zamanlanmış işler yönetimi için sunucu kümesinin 
		|ve veritabanlarının yönetim parametrelerini girmek gerekir';
		|it = 'Per gestire il blocco di task programmati,
		|inserire i parametri dell''amministrazione del cluster dei server e dell''nfobase';
		|de = 'Um das Blockieren von Routineaufgaben zu verwalten, ist es notwendig,
		|die Parameter für die Verwaltung des Serverclusters und der Informationsbasis einzugeben'");
	IBConnectionsClient.ShowAdministrationParameters(NotifyDescription, True,
		True, AdministrationParameters, FormHeader, NoteLabel);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.InitialUserAuthorizationRestrictionStatus.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UsersAuthorizationRestrictionStatus");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = NStr("ru = 'Запрещено'; en = 'Denied'; pl = 'Zabronione';es_ES = 'Prohibido';es_CO = 'Prohibido';tr = 'Yasak';it = 'Vietato';de = 'Verboten'");

	Item.Appearance.SetParameterValue("TextColor", StyleColors.ErrorNoteText);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.InitialUserAuthorizationRestrictionStatus.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UsersAuthorizationRestrictionStatus");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = NStr("ru = 'Запланировано'; en = 'Scheduled'; pl = 'Planowany';es_ES = 'Planificado';es_CO = 'Planificado';tr = 'Planlanmış';it = 'In programma';de = 'Geplant'");

	Item.Appearance.SetParameterValue("TextColor", StyleColors.ErrorNoteText);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.InitialUserAuthorizationRestrictionStatus.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UsersAuthorizationRestrictionStatus");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = NStr("ru = 'Просроченные'; en = 'Expired'; pl = 'Przedawnione';es_ES = 'Caducado';es_CO = 'Caducado';tr = 'Süresi bitmiş';it = 'Scaduto';de = 'Abgelaufen'");

	Item.Appearance.SetParameterValue("TextColor", StyleColors.LockedAttributeColor);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.InitialUserAuthorizationRestrictionStatus.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UsersAuthorizationRestrictionStatus");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = NStr("ru = 'Разрешено'; en = 'Allowed'; pl = 'Dozwolone';es_ES = 'Permitido';es_CO = 'Permitido';tr = 'İzin verilen';it = 'Permesso';de = 'Erlauben'");

	Item.Appearance.SetParameterValue("TextColor", StyleColors.FormTextColor);

EndProcedure

&AtServer
Function CheckLockPreconditions()
	
	Return CheckFilling();

EndFunction

&AtServer
Function LockUnlock()
	
	Try
		FormAttributeToValue("Object").SetLock();
		Items.ErrorGroup.Visible = False;
	Except
		WriteLogEvent(IBConnectionsClientServer.EventLogEvent(),
			EventLogLevel.Error,,, 
			DetailErrorDescription(ErrorInfo()));
		If IsSystemAdministrator Then
			Items.ErrorGroup.Visible = True;
			Items.ErrorText.Title = BriefErrorDescription(ErrorInfo());
		EndIf;
		Return False;
	EndTry;
	
	SetInitialUserAuthorizationRestrictionStatus();
	SessionCount = IBConnections.InfobaseSessionCount();
	Return True;
	
EndFunction

&AtServer
Function CancelLock()
	
	Try
		FormAttributeToValue("Object").CancelLock();
	Except
		WriteLogEvent(IBConnectionsClientServer.EventLogEvent(),
			EventLogLevel.Error,,, 
			DetailErrorDescription(ErrorInfo()));
		If IsSystemAdministrator Then
			Items.ErrorGroup.Visible = True;
			Items.ErrorText.Title = BriefErrorDescription(ErrorInfo());
		EndIf;
		Return False;
	EndTry;
	
	SetInitialUserAuthorizationRestrictionStatus();
	Items.ModeGroup.CurrentPage = Items.SettingsPage;
	RefreshSettingsPage();
	Return True;
	
EndFunction

&AtServer
Procedure RefreshSettingsPage()
	
	Items.DisableScheduledJobsGroup.Enabled = True;
	Items.ApplyCommand.Visible = True;
	Items.ApplyCommand.DefaultButton = True;
	Items.StopCommand.Visible = False;
	Items.ApplyCommand.Title = ?(Object.DisableUserAuthorisation,
		NStr("ru='Снять блокировку'; en = 'Remove lock'; pl = 'Odblokuj';es_ES = 'Desbloquear';es_CO = 'Desbloquear';tr = 'Blokeyi kaldır';it = 'Rimuovi blocco';de = 'Freischalten'"), NStr("ru='Установить блокировку'; en = 'Set lock'; pl = 'Blokuj';es_ES = 'Bloquear';es_CO = 'Bloquear';tr = 'Kilitle';it = 'Imposta blocco';de = 'Sperren'"));
	Items.DisableScheduledJobs.Title = ?(Object.DisableScheduledJobs,
		NStr("ru='Оставить блокировку работы регламентных заданий'; en = 'Keep scheduled job lock'; pl = 'Zachowaj operacje zaplanowanych zadań';es_ES = 'Guardar las operaciones de bloqueo de las tareas programadas';es_CO = 'Guardar las operaciones de bloqueo de las tareas programadas';tr = 'Zamanlanmış işlerin kilitleme işlemlerini sürdürün';it = 'Mantieni il blocco processo pianificato';de = 'Halten Sie die Sperren geplanter Jobs fest'"), NStr("ru='Также запретить работу регламентных заданий'; en = 'Also disable scheduled jobs'; pl = 'Wyłącz również zaplanowane zadania';es_ES = 'También desactivar las tareas programadas';es_CO = 'También desactivar las tareas programadas';tr = 'Ayrıca planlanan işleri de devre dışı bırak';it = 'Anche disabilitare i lavori pianificati';de = 'Deaktivieren Sie auch geplante Aufträge'"));
	
EndProcedure

&AtClientAtServerNoContext
Procedure RefreshStatePage(Form)
	
	Form.Items.DisableScheduledJobsGroup.Enabled = False;
	Form.Items.StopCommand.Visible = True;
	Form.Items.ApplyCommand.Visible = False;
	Form.Items.CloseCommand.DefaultButton = True;
	UpdateLockState(Form);
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateLockState(Form)
	
	If Form.SessionCount = 0 Then
		
		StateText = NStr("ru='Ожидается установка блокировки...
			|Работа пользователей в программе будет запрещена в указанное время'; 
			|en = 'Waiting to set lock...
			|Users will not be able to use the application at a specified time'; 
			|pl = 'Blokada jest w toku...
			|Użytkownicy zostaną zablokowani w programie o określonej godzinie';
			|es_ES = 'Se está esperando la instalación del bloqueo...
			|El trabajo de usuarios en el programa será prohibido en el tiempo indicado';
			|es_CO = 'Se está esperando la instalación del bloqueo...
			|El trabajo de usuarios en el programa será prohibido en el tiempo indicado';
			|tr = 'Kilitleme bekleniyor...
			|Programdaki kullanıcıların çalışması belirtilen zamanda yasaklanacak';
			|it = 'In attesa di impostazione bloccco...
			|Utenti non saranno in grado di usare l''applicazione nel periodo specificato';
			|de = 'Sperre ausstehend...
			|Die Arbeit von Benutzern im Programm wird zu dem angegebenen Zeitpunkt verboten'");
		
	Else
		
		StateText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru='Пожалуйста, подождите...
			|Работа пользователей завершается. Осталось активных сеансов: %1'; 
			|en = 'Please wait...
			|Closing user sessions. Remaining active sessions: %1'; 
			|pl = 'Proszę czekać...
			|Użytkownicy się wyłączają. Pozostały aktywne sesje: %1';
			|es_ES = 'Por favor, espere...
			|El trabajo de usuarios se ha finalizado. Quedan las sesiones activas: %1';
			|es_CO = 'Por favor, espere...
			|El trabajo de usuarios se ha finalizado. Quedan las sesiones activas: %1';
			|tr = 'Lütfen bekleyin...
			|Kullanıcı oturumları kapatılıyor. Kalan aktif oturumlar: %1';
			|it = 'Si prega di attendere...
			|Chiusura sessioni utente. Sessioni attive rimanenti: %1';
			|de = 'Bitte warten Sie...
			|Die Arbeit der Benutzer ist beendet. Es sind noch aktive Sitzungen vorhanden: %1'"),
			Form.SessionCount);
			
	EndIf;
	
	Form.Items.State.Title = StateText;
	
EndProcedure

&AtServer
Procedure GetLockParameters()
	DataProcessor = FormAttributeToValue("Object");
	Try
		DataProcessor.GetLockParameters();
		Items.ErrorGroup.Visible = False;
	Except
		WriteLogEvent(IBConnectionsClientServer.EventLogEvent(),
			EventLogLevel.Error,,, 
			DetailErrorDescription(ErrorInfo()));
		If IsSystemAdministrator Then
			Items.ErrorGroup.Visible = True;
			Items.ErrorText.Title = BriefErrorDescription(ErrorInfo());
		EndIf;
	EndTry;
	
	ValueToFormAttribute(DataProcessor, "Object");
	
EndProcedure

&AtServer
Procedure SetInitialUserAuthorizationRestrictionStatus()
	
	GetLockParameters();
	
	InitialUserAuthorizationRestrictionStatusValue = Object.DisableUserAuthorisation;
	If Object.DisableUserAuthorisation Then
		If CurrentSessionDate() < Object.LockEffectiveFrom Then
			InitialUserAuthorizationRestrictionStatus = NStr("ru = 'Работа пользователей в программе будет запрещена в указанное время'; en = 'Users will be logged out of the application at the specified time'; pl = 'Operacje użytkownika w aplikacji zostaną zabronione w określonym czasie';es_ES = 'Operación de usuario en la aplicación estará prohibida en la hora especificada';es_CO = 'Operación de usuario en la aplicación estará prohibida en la hora especificada';tr = 'Uygulamada kullanıcı işlemi belirtilen zamanda yasaklanacaktır';it = 'Gli utenti saranno disconnessi dall''applicazione all''orario specificato';de = 'Die Benutzerbedienung in der Anwendung wird zur angegebenen Zeit verboten'");
			UsersAuthorizationRestrictionStatus = "Scheduled";
		ElsIf CurrentSessionDate() > Object.LockEffectiveTo AND Object.LockEffectiveTo <> '00010101' Then
			InitialUserAuthorizationRestrictionStatus = NStr("ru = 'Работа пользователей в программе разрешена (истек срок запрета)'; en = 'Users are allowed to sign in to the application (lock duration expired)'; pl = 'Operacje użytkownika w aplikacji są dozwolone (czas zakazu dobiegł końca)';es_ES = 'Operación de usuario en la aplicación está permitida (período de prohibición se ha acabado)';es_CO = 'Operación de usuario en la aplicación está permitida (período de prohibición se ha acabado)';tr = 'Uygulamada kullanıcı işlemine izin verilir (yasak süresi sona ermiştir)';it = 'Gli utenti possono accedere all''applicazione (durata del blocco scaduta)';de = 'Benutzerbedienung in der Anwendung ist erlaubt (Sperrfrist ist abgelaufen)'");;
			UsersAuthorizationRestrictionStatus = "Expired";
		Else
			InitialUserAuthorizationRestrictionStatus = NStr("ru = 'Работа пользователей в программе запрещена'; en = 'Users are logged out of the application'; pl = 'Operacje użytkownika w aplikacji są zabronione';es_ES = 'Operación de usuario en la aplicación está prohibida';es_CO = 'Operación de usuario en la aplicación está prohibida';tr = 'Uygulamada kullanıcı işlemi yasaktır';it = 'Gli utenti sono disconnessi dall''applicazione';de = 'Benutzerbedienung in der Anwendung ist untersagt'");
			UsersAuthorizationRestrictionStatus = "Denied";
		EndIf;
	Else
		InitialUserAuthorizationRestrictionStatus = NStr("ru = 'Работа пользователей в программе разрешена'; en = 'Users are allowed to sign in to the application'; pl = 'Użytkownicy mogą logować się do aplikacji';es_ES = 'Operación de usuario en la aplicación está permitida';es_CO = 'Operación de usuario en la aplicación está permitida';tr = 'Uygulamada kullanıcı işlemine izin verilir';it = 'Gli utenti possono accedere all''applicazione';de = 'Benutzerbedienung in der Anwendung ist erlaubt'");
		UsersAuthorizationRestrictionStatus = "Allowed";
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterGetAdministrationParameters(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		
		AdministrationParameters = Result;
		CorrectAdministrationParametersEntered = True;
		
		Try
			If ClientConnectedOverWebServer Then
				Object.DisableScheduledJobs = InfobaseScheduledJobLockAtServer(AdministrationParameters);
			Else
				Object.DisableScheduledJobs = ClusterAdministrationClientServer.InfobaseScheduledJobLock(AdministrationParameters);
			EndIf;
			CurrentLockValue = Object.DisableScheduledJobs;
		Except;
			CorrectAdministrationParametersEntered = False;
			Raise;
		EndTry;
		
		Items.DisableScheduledJobsGroup.CurrentPage = Items.ScheduledJobManagementGroup;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterGetAdministrationParametersOnLock(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	ElsIf TypeOf(Result) = Type("Structure") Then
		AdministrationParameters = Result;
		CorrectAdministrationParametersEntered = True;
		EnableScheduledJobLockManagement();
		IBConnectionsClient.SaveAdministrationParameters(AdministrationParameters);
	ElsIf TypeOf(Result) = Type("Boolean") AND CorrectAdministrationParametersEntered Then
		IBConnectionsClient.SaveAdministrationParameters(AdministrationParameters);
	EndIf;
	
	If Not LockUnlock() Then
		Return;
	EndIf;
	
	ShowUserNotification(NStr("ru = 'Блокировка работы пользователей'; en = 'Application lock'; pl = 'Blokowanie operacji użytkownika';es_ES = 'Bloqueo de la operación del usuario';es_CO = 'Bloqueo de la operación del usuario';tr = 'Kullanıcı operasyon kilitleme';it = 'Blocco applicazione';de = 'Sperrung der Benutzerbedienung'"),
		"e1cib/app/DataProcessor.ApplicationLock",
		?(Object.DisableUserAuthorisation, NStr("ru = 'Блокировка установлена.'; en = 'The lock is set.'; pl = 'Zablokowane.';es_ES = 'Bloqueado.';es_CO = 'Bloqueado.';tr = 'Kilitli.';it = 'Il blocco è impostato.';de = 'Gesperrt'"), NStr("ru = 'Блокировка снята.'; en = 'The lock is removed.'; pl = 'Odblokowane.';es_ES = 'Desbloqueado.';es_CO = 'Desbloqueado.';tr = 'Kilitsiz.';it = 'Il blocco è rimosso.';de = 'Freischalten.'")),
		PictureLib.Information32);
	IBConnectionsClient.SetSessionTerminationHandlers(Object.DisableUserAuthorisation);
	
	If Object.DisableUserAuthorisation Then
		Items.ModeGroup.CurrentPage = Items.LockStatePage;
		RefreshStatePage(ThisObject);
	Else
		Items.ModeGroup.CurrentPage = Items.SettingsPage;
		RefreshSettingsPage();
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterGetAdministrationParametersOnUnlock(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	ElsIf TypeOf(Result) = Type("Structure") Then
		AdministrationParameters = Result;
		CorrectAdministrationParametersEntered = True;
		EnableScheduledJobLockManagement();
		IBConnectionsClient.SaveAdministrationParameters(AdministrationParameters);
	ElsIf TypeOf(Result) = Type("Boolean") AND CorrectAdministrationParametersEntered Then
		IBConnectionsClient.SaveAdministrationParameters(AdministrationParameters);
	EndIf;
	
	If Not CancelLock() Then
		Return;
	EndIf;
	
	IBConnectionsClient.SetSessionTerminationHandlers(False);
	ShowMessageBox(,NStr("ru = 'Завершение работы активных пользователей отменено.'; en = 'Logging active users out of the application is canceled.'; pl = 'Zamknij pracę aktywnych użytkowników anulowanych.';es_ES = 'La terminación del trabajo de los usuarios activos está cancelada.';es_CO = 'La terminación del trabajo de los usuarios activos está cancelada.';tr = 'Aktif kullanıcıların uygulamadan çıkarılması iptal edildi.';it = 'La disconnessione degli utenti attivi dall''applicazione è stata annullata.';de = 'Aktive Benutzer herunterfahren abgebrochen.'"));
	
EndProcedure

&AtClient
Procedure EnableScheduledJobLockManagement()
	
	If ClientConnectedOverWebServer Then
		Object.DisableScheduledJobs = InfobaseScheduledJobLockAtServer(AdministrationParameters);
	Else
		Object.DisableScheduledJobs = ClusterAdministrationClientServer.InfobaseScheduledJobLock(AdministrationParameters);
	EndIf;
	CurrentLockValue = Object.DisableScheduledJobs;
	Items.DisableScheduledJobsGroup.CurrentPage = Items.ScheduledJobManagementGroup;
	
EndProcedure

&AtServer
Procedure SetScheduledJobLockAtServer(AdministrationParameters)
	
	ClusterAdministrationClientServer.SetInfobaseScheduledJobLock(
		AdministrationParameters, Undefined, Object.DisableScheduledJobs);
	
EndProcedure

&AtServer
Function InfobaseScheduledJobLockAtServer(AdministrationParameters)
	
	Return ClusterAdministrationClientServer.InfobaseScheduledJobLock(AdministrationParameters);
	
EndFunction

#EndRegion