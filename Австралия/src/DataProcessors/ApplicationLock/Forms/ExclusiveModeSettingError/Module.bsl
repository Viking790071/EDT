
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	MarkedObjectsDeletion = Parameters.MarkedObjectsDeletion;
	If MarkedObjectsDeletion Then
		Title = NStr("ru = 'Не удалось выполнить удаление помеченных объектов'; en = 'Cannot delete the marked objects'; pl = 'Nie można usunąć zaznaczonych obiektów';es_ES = 'No se puede borrar los objetos marcados';es_CO = 'No se puede borrar los objetos marcados';tr = 'İşaretli nesneler silinemiyor';it = 'Impossibile eliminare elementi speciali';de = 'Die markierten Objekte können nicht gelöscht werden'");
		Items.ErrorMessageText.Title = NStr("ru = 'Невозможно выполнить удаление помеченных объектов, т.к. в программе работают другие пользователи:'; en = 'Cannot delete selected objects as other users are using the application:'; pl = 'Nie można usunąć wybranych obiektów, ponieważ inni użytkownicy korzystają z aplikacji:';es_ES = 'No se puede borrar los objetos seleccionados porque otros usuarios están utilizando la aplicación:';es_CO = 'No se puede borrar los objetos seleccionados porque otros usuarios están utilizando la aplicación:';tr = 'Seçilen kullanıcılar, uygulamayı kullanan diğer kullanıcılar tarafından silinemiyor:';it = 'Impossibile eliminare gli elementi contrassegnati, perché altri utenti lavorano nel programma:';de = 'Ausgewählte Objekte können nicht gelöscht werden, wenn andere Benutzer die Anwendung verwenden:'");
	EndIf;
	
	ActiveUsersTemplate = NStr("ru = 'Активные пользователи (%1)'; en = 'Active users (%1)'; pl = 'Aktywni użytkownicy (%1)';es_ES = 'Usuarios activos (%1)';es_CO = 'Usuarios activos (%1)';tr = 'Aktif kullanıcılar (%1)';it = 'Utenti attivi (%1)';de = 'Aktive Benutzer (%1)'");
	
	ActiveSessionCount = NumberOfActiveSessionsOnServer();
	Items.ActiveUsers.Title = StringFunctionsClientServer.SubstituteParametersToString(ActiveUsersTemplate, ActiveSessionCount);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ActiveSessionCount = 0 Then
		Cancel = True;
		ExecuteNotifyProcessing(OnCloseNotifyDescription, False);
	Else
		If Parameters.MarkedObjectsDeletion Then
			IBConnectionsClient.SetTerminateAllSessionsExceptCurrentFlag(True);
		EndIf;
		AttachIdleHandler("UpdateActiveSessionCount", 30);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	If Parameters.MarkedObjectsDeletion Then
		IBConnectionsClient.SetTerminateAllSessionsExceptCurrentFlag(False);
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ActiveUsersClick(Item)
	
	NotifyDescription = New NotifyDescription("OpenActiveUserListCompletion", ThisObject);
	OpenForm("DataProcessor.ActiveUsers.Form.ActiveUsers", , , , , ,
		NotifyDescription,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ActiveUsers2Click(Item)
	
	NotifyDescription = New NotifyDescription("OpenActiveUserListCompletion", ThisObject);
	OpenForm("DataProcessor.ActiveUsers.Form.ActiveUsers" , , , , , ,
		NotifyDescription,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure TerminateSessionsAndRestartApplication(Command)
	
	Items.PagesGroup.CurrentPage = Items.Page2;
	CurrentWizardPage = "Page2";
	Items.RetryApplicationStartForm.Visible = False;
	Items.TerminateSessionsAndRestartApplicationForm.Visible = False;
	
	// Setting the infobase lock parameters.
	UpdateActiveSessionCount();
	LockFileInfobase();
	IBConnectionsClient.SetSessionTerminationHandlers(True);
	AttachIdleHandler("UserSessionTimeout", 60);
	
EndProcedure

&AtClient
Procedure AbortApplicationStart(Command)
	
	CancelFileInfobaseLock();
	
	Close(True);
	
EndProcedure

&AtClient
Procedure RetryApplicationStart(Command)
	
	Close(False);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure OpenActiveUserListCompletion(Result, AdditionalParameters) Export
	UpdateActiveSessionCount();
EndProcedure

&AtClient
Procedure UpdateActiveSessionCount()
	
	If CurrentWizardPage = "Page2" Then
		ActiveUsers = "ActiveUsers2";
	Else
		ActiveUsers = "ActiveUsers";
	EndIf;
	
	Result = NumberOfActiveSessionsOnServer();
	If Result = 0 Then
		Close(False);
	Else
		Items[ActiveUsers].Title = StringFunctionsClientServer.SubstituteParametersToString(ActiveUsersTemplate, Result);
	EndIf;
	
EndProcedure

&AtServer
Function NumberOfActiveSessionsOnServer()
	
	InfobaseSessions = GetInfoBaseSessions();
	
	CurrentUserSessionNumber = InfoBaseSessionNumber();
	NumberOfSessionsPreventingContinuation = 0;
	For Each IBSession In InfobaseSessions Do
		
		If IBSession.ApplicationName = "Designer"
			Or IBSession.SessionNumber = CurrentUserSessionNumber Then
			Continue;
		EndIf;
		
		NumberOfSessionsPreventingContinuation = NumberOfSessionsPreventingContinuation + 1;
	EndDo;
	
	Return NumberOfSessionsPreventingContinuation;
	
EndFunction

&AtClient
Procedure UserSessionTimeout()
	
	UserSessionsTerminationDuration = UserSessionsTerminationDuration + 1;
	
	If UserSessionsTerminationDuration >= 3 Then
		CancelFileInfobaseLock();
		Items.PagesGroup.CurrentPage = Items.Page1;
		CurrentWizardPage = "Page1";
		Items.ErrorMessageText.Title = NStr("ru = 'Невозможно выполнить обновление версии программы, т.к. не удалось завершить работу пользователей:'; en = 'Cannot update the application version as the following user sessions failed to terminate:'; pl = 'Nie można zaktualizować wersji aplikacji, ponieważ niektóre sesje użytkowników nadal są aktywne:';es_ES = 'No se puede actualizar la versión de la aplicación porque algunas sesiones del usuario aún están activas:';es_CO = 'No se puede actualizar la versión de la aplicación porque algunas sesiones del usuario aún están activas:';tr = 'Şu kullanıcı oturumları hala etkin olduğundan uygulama sürümü güncellenemiyor:';it = 'Impossibile aggiornare la versione dell''applicazione dato che le sessione utente seguenti non sono state terminate:';de = 'Die Anwendungsversion kann nicht aktualisiert werden, da einige Benutzersitzungen noch aktiv sind:'");
		Items.RetryApplicationStartForm.Visible = True;
		Items.TerminateSessionsAndRestartApplicationForm.Visible = True;
		DetachIdleHandler("UserSessionTimeout");
		UserSessionsTerminationDuration = 0;
	EndIf;
	
EndProcedure

&AtServer
Procedure LockFileInfobase()
	
	Object.DisableUserAuthorisation = True;
	If MarkedObjectsDeletion Then
		Object.LockEffectiveFrom = CurrentSessionDate() + 2*60;
		Object.LockEffectiveTo = Object.LockEffectiveFrom + 60;
		Object.MessageForUsers = NStr("ru = 'Программа заблокирована для удаления помеченных объектов.'; en = 'The application is locked for deleting selected objects.'; pl = 'Aplikacja jest zablokowana do usuwania wybranych obiektów.';es_ES = 'La aplicación está bloqueda para borrar los objetos seleccionados.';es_CO = 'La aplicación está bloqueda para borrar los objetos seleccionados.';tr = 'Seçilen nesneleri silmek için uygulama kilitlendi.';it = 'L''applicazione è bloccata per l''eliminazione di oggetti selezionati.';de = 'Die Anwendung ist zum Löschen ausgewählter Objekte gesperrt.'");
	Else
		Object.LockEffectiveFrom = CurrentSessionDate() + 2*60;
		Object.LockEffectiveTo = Object.LockEffectiveFrom + 5*60;
		Object.MessageForUsers = NStr("ru = 'Программа заблокирована для выполнения обновления.'; en = 'The application is locked for update purposes.'; pl = 'Aplikacja jest zablokowana w celu przeprowadzenia aktualizacji.';es_ES = 'La aplicación está bloqueada para actualizar.';es_CO = 'La aplicación está bloqueada para actualizar.';tr = 'Uygulama güncellemek için kilitlendi.';it = 'L''applicazione è bloccata per motivi di aggiornamento.';de = 'Die Anwendung ist für die Aktualisierung gesperrt.'");
	EndIf;
	
	Try
		FormAttributeToValue("Object").SetLock();
	Except
		WriteLogEvent(IBConnectionsClientServer.EventLogEvent(),
			EventLogLevel.Error,,, 
			DetailErrorDescription(ErrorInfo()));
		CommonClientServer.MessageToUser(BriefErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

&AtServer
Procedure CancelFileInfobaseLock()
	
	FormAttributeToValue("Object").CancelLock();
	
EndProcedure

#EndRegion
