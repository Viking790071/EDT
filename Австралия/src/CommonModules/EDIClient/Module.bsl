#Region Public

Procedure EDIExecuteCommand(Val Command, Val Form, Val Source) Export
	
	CommandDescription = Command;
	If TypeOf(Command) = Type("FormCommand") Then
		EDICommandsAddressInTempStorage = Form.Commands.Find("EDICommandsAddressInTempStorage").Action;
		CommandDescription = EDICommandDescription(Command.Name, EDICommandsAddressInTempStorage);
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("CommandDescription", CommandDescription);
	AdditionalParameters.Insert("Form", Form);
	AdditionalParameters.Insert("Source", Source);
	
	If TypeOf(Source) = Type("FormDataStructure")
		And (Source.Ref.IsEmpty() Or Form.Modified) Then
		
		QueryText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Data is not written yet.
				|You can access ""%1"" after writing the data only.'; 
				|ru = 'Данные еще не записаны. 
				|Переход к ""%1"" возможен только после записи данных.';
				|pl = 'Dane nie są jeszcze zapisane. 
				|Przejście do ""%1"" możliwy jest tylko po zapisaniu danych.';
				|es_ES = 'Los datos todavía no se han guardado.
				|Puedes acceder a ""%1"" solo después de guardar los datos.';
				|es_CO = 'Los datos todavía no se han guardado.
				|Puedes acceder a ""%1"" solo después de guardar los datos.';
				|tr = 'Veriler henüz kaydedilmedi.
				|''''%1'''' öğesine sadece veri kaydından sonra erişilebilir.';
				|it = 'Le modifiche non sono salvate.
				| Per proseguire a ""%1"", salvare le modifiche.';
				|de = 'Die Daten wurden noch nicht erfasst. 
				|Der Zugriff auf ""%1"" ist erst nach dem Schreiben der Daten möglich.'"),
			CommandDescription.Presentation);
			
		NotifyHandler = New NotifyDescription("EDIExecuteCommandWriteConfirmation", ThisObject, AdditionalParameters);
		ShowQueryBox(NotifyHandler, QueryText, QuestionDialogMode.OKCancel);
		Return;
		
	EndIf;
	
	EDIExecuteCommandWriteConfirmation(Undefined, AdditionalParameters);
	
EndProcedure

Procedure EDIStateDecorationClick(Val Form, Val Item) Export
	
	EDI_StatusDescription = "EDI_StatusDescription";
	
	ValueToShow = Item.Title;
	If ValueIsFilled(Form[EDI_StatusDescription]) Then
		ValueToShow = Form[EDI_StatusDescription];
	EndIf;
	
	ShowValue(, ValueToShow);
	
EndProcedure

Procedure EDIExecuteCommandWriteConfirmation(Result, AdditionalParameters) Export
	
	CommandDescription = AdditionalParameters.CommandDescription;
	Form = AdditionalParameters.Form;
	Source = AdditionalParameters.Source;
	
	If Result = DialogReturnCode.OK Then
		
		Form.Write();
		If Source.Ref.IsEmpty() Or Form.Modified Then
			Return;
		EndIf;
		
		AccountingDocuments = New Array;
		AccountingDocuments.Add(Source.Ref);
		
		NotifyParameters = New Structure;
		NotifyParameters.Insert("AccountingDocuments", AccountingDocuments);
		
		Notify("RefreshEDIState", NotifyParameters);
		
	ElsIf Result = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	BaseObjects = Source;
	If TypeOf(BaseObjects) <> Type("Array") Then
		BaseObjects = BaseObjects(BaseObjects);
	EndIf;
	
	AdditionalParameters.Insert("BaseObjects", BaseObjects);
	
	If Not IsBlankString(CommandDescription.Handler) Then
		
		TimeConsumingOperation = EDIServerCall.EDIExecuteCommandTimeConsumingOperation(BaseObjects, CommandDescription.Handler);
		
		ExecuteParameters = New Structure;
		ExecuteParameters.Insert("TimeConsumingOperation", TimeConsumingOperation);
		ExecuteParameters.Insert("BaseObjects", BaseObjects);
		
		IdleParameters = TimeConsumingOperationsClient.IdleParameters(Undefined);
		IdleParameters.MessageText = NStr("en = 'EDI exchange'; ru = 'Электронный документооборот';pl = 'Wymiana dokumentów elektronicznych';es_ES = 'Intercambio EDI';es_CO = 'Intercambio EDI';tr = 'EDI değişimi';it = 'Scambio di documenti elettronici';de = 'EDI-Austausch'");
		
		CompletionNotification = New NotifyDescription("EDIExecuteCommandCompletion", ThisObject, ExecuteParameters);
		TimeConsumingOperationsClient.WaitForCompletion(TimeConsumingOperation, CompletionNotification, IdleParameters);
		
	EndIf;
	
EndProcedure

Procedure EDIExecuteCommandCompletion(Result, ExecuteParameters) Export
	
	If Result = Undefined Or Result.Status = "Canceled" Then
		
		Return;
		
	ElsIf Result.Status = "Error" Then
		
		CommonClientServer.MessageToUser(Result.BriefErrorPresentation);
		
	ElsIf Result.Status = "Completed" Then
		
		ResultStructure = GetFromTempStorage(Result.ResultAddress);
		If ResultStructure.ErrorsInEventLog Then
			ShowEDIExchangeErrorMessage();
		ElsIf ResultStructure.ErrorsToShow Then
			For Each ErrorText In ResultStructure.ListOfErrorsToShow Do
				
				CommonClientServer.MessageToUser(ErrorText);
				
			EndDo;
		Else
			ShowUserNotification(NStr("en = 'Completed successfully'; ru = 'Успешно завершено';pl = 'Zakończono sukcesem';es_ES = 'Finalizado con éxito';es_CO = 'Finalizado con éxito';tr = 'Başarıyla tamamlandı';it = 'Completato con successo';de = 'Erfolgreich beendet'"));
			Notify("RefreshEDIState", ExecuteParameters.BaseObjects);
		EndIf;
		
	EndIf;
	
EndProcedure

Function ParametersNotificationProcessing() Export
	
	ParametersNotificationProcessing = New Structure("
		|Form,
		|Ref,
		|StateDecoration,
		|StateGroup,
		|SpotForCommands");
	
	Return ParametersNotificationProcessing;
	
EndFunction

Procedure NotificationProcessing_DocumentForm(EventName, Parameter, Source, NotificationParameters) Export
	
	If EventName = "RefreshEDIState" Then
		
		Ref = NotificationParameters.Ref;
		
		If TypeOf(Parameter) = Type("Structure")
			And Parameter.Property("AccountingDocuments")
			And TypeOf(Parameter.AccountingDocuments) = Type("Array")
			And Parameter.AccountingDocuments.Find(Ref) = Undefined Then
			
			Return;
			
		EndIf;
		
		EDIState = EDIServerCall.GetEDIState(Ref);
		
		EDI_StatusDescription = "EDI_StatusDescription";
		Form = NotificationParameters.Form;
		StateDecoration = NotificationParameters.StateDecoration;
		
		StateDecoration.Title = EDIState.Status;
		Form[EDI_StatusDescription] = EDIState.StatusDescription;
		
	EndIf;
	
EndProcedure

Procedure CheckConnection(EDIProfile) Export
	
	ClearMessages();
	HasErrors = False;
	
	EDIServerCall.CheckConnection(EDIProfile, HasErrors);
	
	If HasErrors Then
		ShowCheckConnectionErrorMessage();
	Else
		ShowMessageBox(
			,
			NStr("en = 'Profile parameters check is completed successfully'; ru = 'Проверка параметров профиля успешно завершена';pl = 'Sprawdzenie parametrów profilu zostało zakończone pomyślnie';es_ES = 'La comprobación de los parámetros del perfil se ha finalizado con éxito';es_CO = 'La comprobación de los parámetros del perfil se ha finalizado con éxito';tr = 'Profil parametresi kontrolü başarıyla tamamlandı';it = 'Il controllo dei parametri di profilo sono stati completati con successo';de = 'Die Überprüfung der Profil-Parameter wurde erfolgreich abgeschlossen'"),
			,
			NStr("en = 'EDI exchange'; ru = 'Электронный документооборот';pl = 'Wymiana dokumentów elektronicznej';es_ES = 'Intercambio de EDI';es_CO = 'Intercambio de EDI';tr = 'EDI değişimi';it = 'Scambio di documenti elettronici';de = 'EDI-Austausch'"));
	EndIf;
	
EndProcedure

Procedure DocumentWasChanged(DocumentRef) Export
	
	If EDIServerCall.DocumentWasSent(DocumentRef)
		And Not EDIServerCall.ProhibitEDocumentsChanging() Then
		
		ShowMessageBox(
			,
			NStr("en = 'Document has already been sent to EDI system.
				|When you change main document attributes, you need to change it in EDI system manually.'; 
				|ru = 'Документ уже был отправлен в систему электронного документооборота.
				|При изменении основных реквизитов документа вам потребуется изменить их в системе электронного документооборота вручную.';
				|pl = 'Dokument został już wysłany do systemu elektronicznej wymiany dokumentów.
				|Gdy zmieniasz atrybuty dokumentu głównego, musisz zmienić go w systemie elektronicznej wymiany dokumentów ręcznie.';
				|es_ES = 'El documento ya ha sido enviado al sistema EDI.
				|Al modificar los atributos principales del documento, es necesario modificarlos manualmente en el sistema EDI.';
				|es_CO = 'El documento ya ha sido enviado al sistema EDI.
				|Al modificar los atributos principales del documento, es necesario modificarlos manualmente en el sistema EDI.';
				|tr = 'Belge EDI sistemine gönderildi.
				| Ana belge öznitelikleri EDI sisteminde manuel olarak değiştirilmelidir.';
				|it = 'Il documento è già stato inviato al sistema EDI. 
				|Quando si modificano gli attributi del documento principale è necessario modificarli manualmente nel sistema EDI.';
				|de = 'Das Dokument wurde bereits an das EDI-System gesendet.
				|Wenn Sie die Hauptdokument-Attribute ändern, müssen Sie es im EDI-System manuell ändern.'"),
			,
			NStr("en = 'Key attributes were changed'; ru = 'Ключевые реквизиты изменены';pl = 'Atrybuty klucza zostały zmienione';es_ES = 'Se han cambiado los atributos clave';es_CO = 'Se han cambiado los atributos clave';tr = 'Anahtar öznitelikler değiştirildi';it = 'Attributi chiave modificati';de = 'Schlüsselattribute wurden geändert'"));
		
	EndIf;
	
EndProcedure

Procedure CheckCounterpartyIsReadyForExchange(Counterparty, HasErrors = False) Export
	
	CounterpartyInfo = EDIServerCall.CounterpartyInfoToCheck(Counterparty);
	
	If Not ValueIsFilled(CounterpartyInfo.CounterpartyTIN) Then
		
		MessageToUserText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'To exchange documents with %1, please fill the TIN in their profile.'; ru = 'Для обмена документами с %1, пожалуйста, заполните ИНН в их профиле.';pl = 'Do wymiany dokumentów z %1, wypełnij NIP w ich profilu.';es_ES = 'Para intercambiar documentos con %1, por favor, rellene el NIF en su perfil.';es_CO = 'Para intercambiar documentos con %1, por favor, rellene el NIF en su perfil.';tr = '%1 ile belge değişimi için lütfen profillerinde VKN''yi doldurun.';it = 'Per poter scambiare i documenti con %1, compilare il cod.fiscale nel loro profilo.';de = 'Um Dokumente mit %1 auszutauschen, füllen Sie bitte die Steuernummer in deren Profil aus.'"),
			Counterparty);
		CommonClientServer.MessageToUser(MessageToUserText);
		HasErrors = True;
		
	EndIf;
	
	If Not ValueIsFilled(CounterpartyInfo.CounterpartyEmail) Then
		
		MessageToUserText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'To exchange documents with %1, please fill the email in their profile.'; ru = 'Для обмена документами с %1, пожалуйста, заполните адрес электронной почты в их профиле.';pl = 'Do wymiany dokumentów z %1, wypełnij adres e-mail w ich profilu.';es_ES = 'Para intercambiar documentos con %1, por favor, rellene el correo electrónico en su perfil.';es_CO = 'Para intercambiar documentos con %1, por favor, rellene el correo electrónico en su perfil.';tr = '%1 ile belge değişimi için lütfen profillerinde e-postayı doldurun.';it = 'Per poter scambiare i documenti con %1, compilare l''email nel loro profilo.';de = 'Um Dokumente mit %1 auszutauschen, füllen Sie bitte die E-Mail in deren Profil aus.'"),
			Counterparty);
		CommonClientServer.MessageToUser(MessageToUserText);
		HasErrors = True;
		
	EndIf;
	
	If Not ValueIsFilled(CounterpartyInfo.CounterpartyPostalAddress) Then
		
		MessageToUserText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'To exchange documents with %1, please fill the legal address in their profile.'; ru = 'Для обмена документами с %1, пожалуйста, заполните юридический адрес в их профиле.';pl = 'Do wymiany dokumentów z %1, wypełnij adres prawny w ich profilu.';es_ES = 'Para intercambiar documentos con %1, por favor, rellene el domicilio legal en su perfil.';es_CO = 'Para intercambiar documentos con %1, por favor, rellene el domicilio legal en su perfil.';tr = '%1 ile belge değişimi için lütfen profillerinde yasal adresi doldurun.';it = 'Per poter scambiare i documenti con %1, compilare l''indirizzo legale nel loro profilo.';de = 'Um Dokumente mit %1 auszutauschen, füllen Sie bitte die gültige Geschäftsadresse in deren Profil aus.'"),
			Counterparty);
		CommonClientServer.MessageToUser(MessageToUserText);
		HasErrors = True;
		
	EndIf;
	
	
	
	If CounterpartyInfo.IsIndividual Then
		
		If CounterpartyInfo.NameParts.Count() < 2 Then
			MessageToUserText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'To exchange documents with %1, the counterparty must have at least a two-part name.'; ru = 'Для обмена документами с %1 имя контрагента должно состоять как минимум из двух частей.';pl = 'Do zmiany dokumentów z %1, kontrahent powinien mieć nazwę co najmniej dwuczęściową.';es_ES = 'Para intercambiar documentos con %1, el nombre de la contrapartida debe tener al menos dos partes.';es_CO = 'Para intercambiar documentos con %1, el nombre de la contrapartida debe tener al menos dos partes.';tr = '%1 ile belge değişimi için cari hesabın en az iki kısımlı ismi olmalıdır.';it = 'Per poter scambiare i documenti con %1, la controparte deve avere almeno un nome in due parti.';de = 'Um Dokumente mit %1 auszutauschen, muss der Geschäftspartner mindestens einen zweiteiligen Namen haben.'"),
				Counterparty);
			CommonClientServer.MessageToUser(MessageToUserText);
			HasErrors = True;
		EndIf;
		
		If StrLen(CounterpartyInfo.CounterpartyTIN) <> 11 Then
			MessageToUserText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'To exchange documents with %1, the counterparty of ''Individual'' type must have 11 digits TIN.'; ru = 'Для обмена документами с %1, контрагент типа ""Физическое лицо"" должен иметь ИНН из 11 цифр.';pl = 'Do wymiany dokumentów z %1, kontrahent o typie ''Osoba fizyczna'' powinien mieć 11 cyfr NIP.';es_ES = 'Para intercambiar documentos con %1, la contrapartida del tipo ''Individual'' debe tener un NIF de 11 dígitos.';es_CO = 'Para intercambiar documentos con %1, la contrapartida del tipo ''Individual'' debe tener un NIF de 11 dígitos.';tr = '%1 ile belge değişimi için ''Kişi'' türünde cari hesabın 11 haneli VKN''si olmalıdır.';it = 'Per poter modificare i documenti con %1, la controparte di tipo ""Individuale"" deve avere un cod.fiscale di 11 cifre.';de = 'Um Dokumente mit %1 auszutauschen, muss der Geschäftspartner des Typs ''Natürliche Person'' 11 Ziffern der Steuernummer haben.'"),
				Counterparty);
			CommonClientServer.MessageToUser(MessageToUserText);
			HasErrors = True;
		EndIf;
		
	Else
		
		If StrLen(CounterpartyInfo.CounterpartyTIN) <> 10 Then
			MessageToUserText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'To exchange documents with %1, the counterparty of ''Legal entity'' type must have 10 digits TIN.'; ru = 'Для обмена документами с %1, контрагент типа ""Юридическое лицо"" должен иметь ИНН из 10 цифр.';pl = 'Do wymiany dokumentów z %1, kontrahent o typie ''Osoba prawna'' powinien mieć 10 cyfr NIP.';es_ES = 'Para intercambiar documentos con %1, la contrapartida del tipo ''Entidad empresarial'' debe tener un NIF de 10 dígitos.';es_CO = 'Para intercambiar documentos con %1, la contrapartida del tipo ''Entidad empresarial'' debe tener un NIF de 10 dígitos.';tr = '%1 ile belge değişimi için ''Tüzel kişi'' türünde cari hesabın 10 haneli VKN''si olmalıdır.';it = 'Per poter scambiare i documenti con %1, la controparte del tipo ""Persona giuridica"" deve avere un cod.fiscale di 10 cifre.';de = 'Um Dokumente mit %1 auszutauschen, muss der Geschäftspartner des Typs ''Juristische Person'' 10 Ziffern der Steuernummer haben.'"),
				Counterparty);
			CommonClientServer.MessageToUser(MessageToUserText);
			HasErrors = True;
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure ShowCheckConnectionErrorMessage()
	
	ErrorText = NStr("en = 'Profile parameters check is completed with errors. Technical info was written to the event log.
	|Proceed to the event log?'; 
	|ru = 'Проверка параметров профиля завершена с ошибками. Техническая информация была записана в журнал регистрации.
	|Перейти к журналу регистрации?';
	|pl = 'Sprawdzenie parametrów profilu zostało zakończone z błędami. Informacje techniczne zostały zapisane do dziennika wydarzeń.
	|Przejść do dziennika wydarzeń?';
	|es_ES = 'La comprobación de los parámetros del perfil se ha completado con errores. La información técnica ha sido grabada en el registro de eventos.
	|¿Proceder al registro de eventos?';
	|es_CO = 'La comprobación de los parámetros del perfil se ha completado con errores. La información técnica ha sido grabada en el registro de eventos.
	|¿Proceder al registro de eventos?';
	|tr = 'Profil parametreleri kontrolü hatalarla tamamlandı. Teknik bilgiler olay günlüğüne yazıldı.
	|Olay günlüğüne gitmek istiyor musunuz?';
	|it = 'Validazione dei parametri di profilo fallita. I dettagli sono salvati nel registro degli eventi. 
	|Aprire il registro degli eventi?';
	|de = 'Die Profil-Parameterüberprüfung ist mit Fehlern abgeschlossen. Technische Informationen wurden in das Ereignisprotokoll geschrieben.
	|Zum Ereignisprotokoll fortsetzen?'");
	Notification = New NotifyDescription("ShowEventLogWhenErrorOccurred", ThisObject);
	ShowQueryBox(Notification, ErrorText, QuestionDialogMode.YesNo, ,DialogReturnCode.No, NStr("en = 'EDI exchange'; ru = 'Электронный документооборот';pl = 'Elektroniczna wymiana dokumentów';es_ES = 'Intercambio EDI';es_CO = 'Intercambio EDI';tr = 'EDI değişimi';it = 'Scambio di documenti elettronici';de = 'EDI-Austausch'"));
	
EndProcedure

Procedure ShowEDIExchangeErrorMessage()
	
	ErrorText = NStr("en = 'Something went wrong on EDI system side. Technical info was written to the event log.
	|Proceed to the event log?'; 
	|ru = 'На стороне системы электронного документооборота произошла неизвестная ошибка. Техническая информация была записана в журнал регистрации.
	|Перейти к журналу регистрации?';
	|pl = 'Coś poszło nie tak na stronie systemu elektronicznej wymiany dokumentów. Informacje techniczne zostały zapisane do dziennika zmian.
	|Przejść do dziennika wydarzeń?';
	|es_ES = 'Ocurrió un error en el sistema EDI. La información técnica fue grabada en el registro de eventos.
	| ¿Proceder al registro de eventos?';
	|es_CO = 'Ocurrió un error en el sistema EDI. La información técnica fue grabada en el registro de eventos.
	| ¿Proceder al registro de eventos?';
	|tr = 'EDI sistemi tarafında hata oluştu. Teknik bilgiler olay günlüğüne yazıldı.
	|Olay günlüğüne gitmek istiyor musunuz?';
	|it = 'EDI non riuscito. I dettagli sono salvati nel registro degli eventi. 
	|Aprire il registro degli eventi?';
	|de = 'Auf der EDI-Systemseite ist etwas schief gelaufen. Technische Informationen wurden in das Ereignisprotokoll geschrieben.
	|Zum Ereignisprotokoll fortsetzen?'");
	Notification = New NotifyDescription("ShowEventLogWhenErrorOccurred", ThisObject);
	ShowQueryBox(Notification, ErrorText, QuestionDialogMode.YesNo, ,DialogReturnCode.No, NStr("en = 'EDI exchange'; ru = 'Электронный документооборот';pl = 'Elektroniczna wymiana dokumentów';es_ES = 'Intercambio EDI';es_CO = 'Intercambio EDI';tr = 'EDI değişimi';it = 'Scambio di documenti elettronici';de = 'EDI-Austausch'"));
	
EndProcedure

Procedure ShowEventLogWhenErrorOccurred(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		
		Filter = New Structure;
		Filter.Insert("EventLogEvent", NStr("en = 'EDI exchange'; ru = 'Электронный документооборот';pl = 'Elektroniczna wymiana dokumentów';es_ES = 'Intercambio EDI';es_CO = 'Intercambio EDI';tr = 'EDI değişimi';it = 'Scambio di documenti elettronici';de = 'EDI-Austausch'", CommonClientServer.DefaultLanguageCode()));
		OpenForm("DataProcessor.EventLog.Form", Filter);
		
	EndIf;
	
EndProcedure

Function EDICommandDescription(CommandName, CommandsAddressInTempStorage)
	
	Return EDIServerCall.EDICommandDescription(CommandName, CommandsAddressInTempStorage);
	
EndFunction

Function BaseObjects(Source)
	
	Result = New Array;
	Result.Add(Source.Ref);
	
	Return Result;
	
EndFunction

#EndRegion