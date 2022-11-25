///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Private

// Opens an email attachment.
//
// Parameters:
//  Ref - CatalogRef.IncomingEmailAttachedFiles,
//            CatalogRef.IncomingEmailAttachedFiles - a reference to file that is to be opened.
//                                                                            
//
Procedure OpenAttachment(Ref, Form, ForEditing = False) Export

	FileData = FilesOperationsClient.FileData(Ref, Form.UUID);
	
	If Form.RestrictedExtensions.FindByValue(FileData.Extension) <> Undefined Then
		
		AdditionalParameters = New Structure("FileData", FileData);
		AdditionalParameters.Insert("ForEditing", ForEditing);
		
		Notification = New NotifyDescription("OpenFileAfterConfirm", ThisObject, AdditionalParameters);
		FormParameters = New Structure;
		FormParameters.Insert("Key", "BeforeOpenFile");
		FormParameters.Insert("FileName", FileData.FileName);
		OpenForm("CommonForm.SecurityWarning", FormParameters, , , , , Notification);
		Return;
		
	EndIf;
	
	FilesOperationsClient.OpenFile(FileData, ForEditing);
	
EndProcedure

Procedure OpenFileAfterConfirm(Result, AdditionalParameters) Export
	
	If Result <> Undefined AND Result = "Continue" Then
		FilesOperationsClient.OpenFile(AdditionalParameters.FileData, AdditionalParameters.ForEditing);
	EndIf;
	
EndProcedure

// Returns an array that contains structures with information about interaction contacts or 
// interaction subject participants.
// Parameters:
//  ContactsTable - Document.TabularSection - contains descriptions and references to interaction 
//                                               contacts or interaction subject participants.
//
Function ContactsTableToArray(ContactsTable) Export
	
	Result = New Array;
	For Each TableRow In ContactsTable Do
		Contact = ?(TypeOf(TableRow.Contact) = Type("String"), Undefined, TableRow.Contact);
		Record = New Structure(
		"Address, Presentation, Contact", TableRow.Address, TableRow.Presentation, Contact);
		Result.Add(Record);
	EndDo;
	
	Return Result;
	
EndFunction

// Get email by all available accounts.
// Parameters:
//  ItemList    - FormTable - a form item that has to be updated after getting emails.
//
Procedure SendReceiveUserEmail(UUID, Form, ItemList = Undefined) Export

	TimeConsumingOperation =  InteractionsServerCall.SendReceiveUserEmailInBackground(UUID);
	If TimeConsumingOperation = Undefined Then
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemList", ItemList);
	AdditionalParameters.Insert("URL", Form.Window.GetURL());
	
	If TimeConsumingOperation.Status = "Completed" Then
		SendImportUserEmailCompletion(TimeConsumingOperation, AdditionalParameters);
	ElsIf TimeConsumingOperation.Status = "Running" Then
		IdleParameters = TimeConsumingOperationsClient.IdleParameters(Form);
		CompletionNotification = New NotifyDescription("SendImportUserEmailCompletion", ThisObject, AdditionalParameters);
		TimeConsumingOperationsClient.WaitForCompletion(TimeConsumingOperation, CompletionNotification, IdleParameters);
	EndIf;
	
EndProcedure

Procedure SendImportUserEmailCompletion(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Error" Then
		Raise Result.BriefErrorPresentation;
	EndIf;
	
	If Result.Status = "Completed" Then
		
		If AdditionalParameters.ItemList <> Undefined Then
			AdditionalParameters.ItemList.Refresh();
		EndIf;
		
		Title = NStr("ru = 'Отправка и получение почты'; en = 'Sending and receiving emails'; pl = 'Wysyłanie i odbieranie wiadomości e-mail';es_ES = 'Enviar y recibir correos electrónicos';es_CO = 'Enviar y recibir correos electrónicos';tr = 'E-posta gönder ve al';it = 'Invio e ricezione email';de = 'Senden und Empfangen von E-Mails'");
		ExecutionResult = GetFromTempStorage(Result.ResultAddress);
		If ExecutionResult.HasErrors Then
			ShowUserNotification(Title, AdditionalParameters.URL, 
				NStr("ru = 'Не удалось выполнить все действия. Технические подробности для администратора в журнале регистрации.'; en = 'Cannot perform all actions. If you are an administrator, please go to registration log for details.'; pl = 'Nie można wykonać wszystkich działań. Jeśli jesteś administratorem, przejdź do dziennika rejestracji aby zobaczyć szczegóły.';es_ES = 'No se han podido realizar todas las acciones. Si usted es un administrador, por favor, vaya al registro para obtener más detalles.';es_CO = 'No se han podido realizar todas las acciones. Si usted es un administrador, por favor, vaya al registro para obtener más detalles.';tr = 'Tüm işlemler gerçekleştirilemiyor. Yöneticiyseniz, lütfen ayrıntılar için kayıt günlüğüne bakın.';it = 'Impossibile eseguire tutte le azioni. Se sei un amministratore, vai al log di registrazione per ulteriori informazioni.';de = 'Kann nicht alle Aktionen ausführen. Wenn Sie ein Administrator sind, bitten gehen Sie zu Anmeldeprotokoll für weitere Informationen.'"), 
				PictureLib.Error32, UserNotificationStatus.Important);
		Else	
			ShowUserNotification(Title, AdditionalParameters.URL,
				EmailsSendingReceivingResult(ExecutionResult));
		EndIf;
		
		Notify("SendAndReceiveEmailDone");
	EndIf;
	
EndProcedure

Function EmailsSendingReceivingResult(ExecutionResult)
	
	If ExecutionResult.EmailsReceived > 0 AND ExecutionResult.SentEmails > 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Получено: %1, отправлено: %2'; en = 'Received: %1, sent: %2'; pl = 'Otrzymano: %1, wysłano: %2';es_ES = 'Recibido: %1, enviado: %2';es_CO = 'Recibido: %1, enviado: %2';tr = 'Alındı: %1, gönderildi: %2';it = 'Ricevute: %1, inviate: %2';de = 'Empfangen: %1, gesendet: %2'"), 
			ExecutionResult.EmailsReceived, ExecutionResult.SentEmails);
	ElsIf ExecutionResult.EmailsReceived > 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Получено: %1'; en = 'Received: %1'; pl = 'Otrzymano: %1';es_ES = 'Recibido:%1';es_CO = 'Recibido:%1';tr = 'Alındı: %1';it = 'Ricevute: %1';de = 'Erhalten: %1'"), 
			ExecutionResult.EmailsReceived);
	ElsIf ExecutionResult.EmailsReceived > 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Отправлено: %1'; en = 'Sent: %1'; pl = 'Wysłano: %1';es_ES = 'Enviado: %1';es_CO = 'Enviado: %1';tr = 'Gönderildi: %1';it = 'Inviate: %1';de = 'Gesendet: %1'"), 
			ExecutionResult.SentEmails);
	Else
		MessageText = NStr("ru = 'Нет новых писем'; en = 'No new emails'; pl = 'Brak nowych wiadomości e-mail';es_ES = 'No hay nuevos correos electrónicos';es_CO = 'No hay nuevos correos electrónicos';tr = 'Yeni e-posta yok';it = 'Nessuna nuova email';de = 'Keine neuen Mails'");
	EndIf;	
	If ExecutionResult.UserAccountsAvailable > 1 Then
		MessageText = MessageText + Chars.LF  
			+ StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '(учетных записей: %1)'; en = '(accounts: %1)'; pl = '(Kont: %1)';es_ES = '(Cuentas de correo electrónico: %1)';es_CO = '(Cuentas de correo electrónico: %1)';tr = '(hesaplar: %1)';it = '(account: %1)';de = '(Konten: %1)'"),
				ExecutionResult.UserAccountsAvailable);
	EndIf;
	
	Return MessageText;
	
EndFunction

#EndRegion
