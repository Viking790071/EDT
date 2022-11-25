
#Region Variables

&AtClient
Var HandlerParameters;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	LoadFormSettings();
	FillTheList();
	
	EmailAccount = DriveReUse.GetValueOfSetting("DefaultEmailAccount");
	If EmailAccount.IsEmpty() Then 
		EmailAccount = Catalogs.EmailAccounts.SystemEmailAccount;
	EndIf;
	
	TemplateName = "PF_MXL_ConfirmationOfArrival";
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetListRowFilter("StatusNumber", GetFilterStatusNumber(FilterStatus), ValueIsFilled(FilterStatus));
	
	ApplyFilters();
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;

	SettingsStructure = New Structure;
	
	SettingsStructure.Insert("Status", FilterStatus);
	SettingsStructure.Insert("Counterparty", FilterCounterparty);
	SettingsStructure.Insert("VATTaxation", FilterVATTaxation);
	SettingsStructure.Insert("Company", FilterCompany);
	
	SettingsStructure.Insert("StartDate", StartDate);
	SettingsStructure.Insert("EndDate", EndDate);
	
	SaveFormSettings(SettingsStructure);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_File" Then
		
		If Not (Parameter.Property("IsNew") And Parameter.IsNew) Then
			Return;
		EndIf;
		
		DocumentsRows = List.FindRows(New Structure("DocumentRef", Parameter.FileOwner));
		For Each DocumentRow In DocumentsRows Do
			
			DocumentRow.StatusNumber = GetReceivedStatusNumber();
			DocumentRow.AttachedFiles = GetOpenFilesLabel();
			
			WriteEmailLog(GetReceivedStatusNumber(), New Structure("DocumentRef", DocumentRow.DocumentRef));
			
			CommonClientServer.MessageToUser(
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'For the %1, the confirmation of arrival status is changed to Received'; ru = 'Для %1 изменено подтверждение статуса прибытия на Получено';pl = 'Dla %1, potwierdzenie statusu przybycia zmienia się na Odebrane';es_ES = 'Para el %1, la confirmación del estado de llegada se ha cambiado a Recibido';es_CO = 'Para el %1, la confirmación del estado de llegada se ha cambiado a Recibido';tr = '%1 için varış onayı durumu Teslim alındı olarak değiştirildi';it = 'Per %1, la conferma dello stato di arrivo è cambiata in Ricevuto';de = 'Für %1wird die Bestätigung des Ankunftsstatus auf Empfangene geändert'"),
					Lower(DocumentRow.DocumentRef)));
			
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterStatusOnChange(Item)
	
	MarkRows();
	
	FilterStatusNumber = GetFilterStatusNumber(FilterStatus);
	SetListRowFilter("StatusNumber", FilterStatusNumber, ValueIsFilled(FilterStatus));
	
EndProcedure

&AtClient
Procedure FilterCounterpartyOnChange(Item)
	SetListRowFilter("Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
EndProcedure

&AtClient
Procedure FilterVATTaxationOnChange(Item)
	SetListRowFilter("VATTaxation", FilterVATTaxation, ValueIsFilled(FilterVATTaxation));
EndProcedure

&AtClient
Procedure FilterCompanyOnChange(Item)
	SetListRowFilter("Company", FilterCompany, ValueIsFilled(FilterCompany));
EndProcedure

&AtClient
Procedure StartDateOnChange(Item)
	
	FillTheList();
	
	ApplyFilters();
	
EndProcedure

&AtClient
Procedure EndDateOnChange(Item)
	
	FillTheList();
	
	ApplyFilters();
	
EndProcedure

&AtClient
Procedure SetInterval(Command)
	
	Dialog = New StandardPeriodEditDialog();
	Dialog.Period.StartDate	= StartDate;
	Dialog.Period.EndDate	= EndDate;
	
	NotifyDescription = New NotifyDescription("SetIntervalCompleted", ThisObject);
	Dialog.Show(NotifyDescription);
	
EndProcedure

&AtClient
Procedure SetIntervalCompleted(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		
		StartDate	= Result.StartDate;
		EndDate		= Result.EndDate;
		
		FillTheList();
		
		ApplyFilters();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlers

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentData = Items.List.CurrentData;
	
	If Field.Name = "ListRecipients" Then
		
		OpenSettingsForm(CurrentData);
		
	ElsIf Field.Name = "ListAttachedFiles" Then
		
		FilesInfo = New Structure(
			"Document, NumberOfFiles", CurrentData.DocumentRef, GetNumberOfAttachedFiles(CurrentData.DocumentRef));
		
		FormParameters = New Structure(
			"FileOwner, FormCaption", 
			CurrentData.DocumentRef,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Confirmation of arrival for %1'; ru = 'Подтверждение прибытия для %1';pl = 'Potwierdzenie przybycia dla %1';es_ES = 'Confirmación de llegada para %1';es_CO = 'Confirmación de llegada para %1';tr = '%1 için varış onayı';it = 'Conferma di arrivo per %1';de = 'Ankunftsbestätigung für %1'"), Lower(CurrentData.DocumentRef)));
		
		OpenForm("DataProcessor.FilesOperations.Form.AttachedFiles", FormParameters);
		
	Else
		
		OpenForm(
			"Document.SalesInvoice.ObjectForm",
			New Structure("Key", CurrentData.DocumentRef),
			ThisObject,
			,
			,
			,
			New NotifyDescription("SalesInvoiceObjectFormAfterClose", ThisObject, CurrentData.DocumentRef));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SalesInvoiceObjectFormAfterClose(Result, Parameter) Export
	
	DocumentsRows = List.FindRows(New Structure("DocumentRef", Parameter));
	For Each DocumentRow In DocumentsRows Do
		DocumentRow.DocumentStatus = GetCurrentDocumentStatus(DocumentRow.DocumentRef);
	EndDo;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Send(Command)
	
	If Not CheckMarkedRows(True, True) Or Not CheckFilling() Then
		Return;
	EndIf;
	
	ExecutionResult = SendEmailsInBackground();
	
	If ExecutionResult.Status = "Completed" Then
		
		AfterEmailSending();
		MarkRows();
		
		SetListRowFilter("StatusNumber", GetFilterStatusNumber(FilterStatus), True);
		ApplyFilters();
		
		Items.List.CurrentRow = Undefined;
		
		MessageText = NStr("en = 'Emails have been sent successfully.'; ru = 'Письма успешно отправлены.';pl = 'Wiadomości e-mail zostały wysłane pomyślnie.';es_ES = 'Se han enviado con éxito los correos electrónicos.';es_CO = 'Se han enviado con éxito los correos electrónicos.';tr = 'E-postalar başarıyla gönderildi.';it = 'Le email sono state inviate con successo.';de = 'E-Mails wurden erfolgreich gesendet.'");
		CommonClientServer.MessageToUser(MessageText);
		
	Else
		
		StartBackgroungJobWaiting(ExecutionResult);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	FillTheList();
	
	ApplyFilters();
	
EndProcedure

&AtClient
Procedure SelectAll(Command)
	MarkRows(True);
EndProcedure

&AtClient
Procedure ClearAll(Command)
	MarkRows(False);
EndProcedure

&AtClient
Procedure SpecifyRecipients(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenSettingsForm(CurrentData);
	
EndProcedure

&AtClient
Procedure Print(Command)
	
	If Not CheckMarkedRows(True) Then
		Return;
	EndIf;
	
	PrintForms = New Array;
	ObjectsArray = New Array;
	
	For Each Row In List.FindRows(New Structure("ToProcess", True)) Do
		ObjectsArray.Add(Row.DocumentRef);
	EndDo;
	
	PrintParameters = New Structure("ID, AddExternalPrintFormsToSet, Result, FormTitle, PrintInfo, PrintObjects");
	
	PrintParameters.ID = "PF_MXL_ConfirmationOfArrival";
	PrintParameters.AddExternalPrintFormsToSet = False;
	PrintParameters.Result = PrintManagementServerCallDrive.ProgramPrintingPrintOptionsStructure(True);
	
	PrintParameters.FormTitle = NStr("en = 'Confirmation of arrival'; ru = 'Подтверждение прибытия';pl = 'Potwierdzenie przybycia';es_ES = 'Confirmación de llegada';es_CO = 'Confirmación de llegada';tr = 'Varış onayı';it = 'Conferma arrivo';de = 'Ankunftsbestätigung'");
	PrintParameters.PrintInfo = ObjectsArray;
	PrintParameters.PrintObjects = ObjectsArray;
	
	PrintManagementClient.ExecutePrintCommand("DataProcessor.ConfirmationOfArrival",
		TemplateName, ObjectsArray, ThisObject, PrintParameters);
	
EndProcedure

&AtClient
Procedure SetStatusNotSent(Command)
	
	If Not CheckMarkedRows() Then
		Return;
	EndIf;
	
	SetNewStatus(GetNotSentStatusNumber());
	MarkRows();
	
EndProcedure

&AtClient
Procedure SetStatusSent(Command)
	
	If Not CheckMarkedRows(True) Then
		Return;
	EndIf;
	
	SetNewStatus(GetSentStatusNumber());
	MarkRows();
	
EndProcedure

&AtClient
Procedure SetStatusReceived(Command)
	
	If Not CheckMarkedRows(True) Then
		Return;
	EndIf;
	
	SetNewStatus(GetReceivedStatusNumber());
	MarkRows();
	
EndProcedure

&AtClient
Procedure SentEmails(Command)
	
	Filter = New Structure;
	
	Filter.Insert("Period", EndDate);
	Filter.Insert("StartDate", StartDate);
	Filter.Insert("EndDate", EndDate);
	
	Filter.Insert("StatusNotSent", NStr("en = 'Not sent'; ru = 'Не отправлено';pl = 'Nie wysłano';es_ES = 'No se ha enviado';es_CO = 'No se ha enviado';tr = 'Gönderilmedi';it = 'Non inviato';de = 'Nicht gesendet'"));
	Filter.Insert("StatusSent", NStr("en = 'Sent'; ru = 'Отправлено';pl = 'Wysłano';es_ES = 'Enviar';es_CO = 'Enviar';tr = 'Gönderildi';it = 'Inviato';de = 'Gesendet'"));
	Filter.Insert("StatusReceived", NStr("en = 'Received'; ru = 'Получено';pl = 'Otrzymano';es_ES = 'Recibido';es_CO = 'Recibido';tr = 'Alındı';it = 'Ricevuto';de = 'Erhalten'"));
	
	If ValueIsFilled(FilterCounterparty) Then
		Filter.Insert("Counterparty", FilterCounterparty);
	EndIf;
	
	If ValueIsFilled(FilterVATTaxation) Then
		Filter.Insert("VATTaxation", FilterVATTaxation);
	EndIf;
	
	If ValueIsFilled(FilterCompany) Then
		Filter.Insert("Company", FilterCompany);
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("GenerateOnOpen", True);
	FormParameters.Insert("Filter", Filter);
	
	OpenForm("Report.SentEmails.ObjectForm", FormParameters, ThisObject, True);
	
EndProcedure

#EndRegion

#Region Private

#Region TextAndNumberValues

&AtClientAtServerNoContext
Function GetReceivedStatusNumber()
	Return 0;
EndFunction

&AtClientAtServerNoContext
Function GetSentStatusNumber()
	Return 1;
EndFunction

&AtClientAtServerNoContext
Function GetNotSentStatusNumber()
	Return 2;
EndFunction

&AtClientAtServerNoContext
Function GetAddFilesLabel()
	Return NStr("en = 'Add files'; ru = 'Добавить файлы';pl = 'Dodaj pliki';es_ES = 'Añadir archivos';es_CO = 'Añadir archivos';tr = 'Dosya ekle';it = 'Aggiungere i file';de = 'Dateien hinzufügen'"); 
EndFunction

&AtClientAtServerNoContext
Function GetOpenFilesLabel()
	Return NStr("en = 'Open files'; ru = 'Открыть файлы';pl = 'Otwórz pliki';es_ES = 'Abrir los archivos';es_CO = 'Abrir los archivos';tr = 'Dosyaları aç';it = 'Aprire file';de = 'Dateien öffnen'"); 
EndFunction

#EndRegion 

#Region BackgroundJobs

&AtServer
Function SendEmailsInBackground()
	
	SendEmailsJobID = Undefined;
	
	ProcedureName = "DriveServer.SendEmailsInBackground";
	StartSettings = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	StartSettings.BackgroundJobDescription = NStr("en = 'Emails sending'; ru = 'Отправка писем';pl = 'Wysłanie wiadomości e-mail';es_ES = 'Envío de correos electrónicos';es_CO = 'Envío de correos electrónicos';tr = 'E-postalar gönderiliyor';it = 'Invio email';de = 'E-Mails senden'");
	
	EmailsTree = GetEmailsToProcess(CurrentSessionDate());
	EmailsTreeAddress = PutToTempStorage(EmailsTree, ThisObject.UUID);
	
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("EmailAccount", EmailAccount);
	ProcedureParameters.Insert("EmailsTree", EmailsTree);
	ProcedureParameters.Insert("TemplateID", "PF_MXL_ConfirmationOfArrival");
	
	ExecutionResult = TimeConsumingOperations.ExecuteInBackground(ProcedureName, ProcedureParameters, StartSettings);
	
	StorageAddress = ExecutionResult.ResultAddress;
	SendEmailsJobID = ExecutionResult.JobID;
	
	Return ExecutionResult;

EndFunction

&AtClient
Procedure Attachable_CheckBackgroundJob()
	
	Try
		If JobCompleted(SendEmailsJobID) Then
			
			AfterEmailSending();
			MarkRows();
			
			SetListRowFilter("StatusNumber", GetFilterStatusNumber(FilterStatus), True);
			ApplyFilters();
	
			Items.List.CurrentRow = Undefined;
			
			MessageText = NStr("en = 'Emails have been sent successfully.'; ru = 'Письма успешно отправлены.';pl = 'Wiadomości e-mail zostały wysłane pomyślnie.';es_ES = 'Se han enviado con éxito los correos electrónicos.';es_CO = 'Se han enviado con éxito los correos electrónicos.';tr = 'E-postalar başarıyla gönderildi.';it = 'Le email sono state inviate con successo.';de = 'E-Mails wurden erfolgreich gesendet.'");
			CommonClientServer.MessageToUser(MessageText);
			
		Else
			TimeConsumingOperationsClient.UpdateIdleHandlerParameters(HandlerParameters);
			AttachIdleHandler(
				"Attachable_CheckBackgroundJob",
				HandlerParameters.CurrentInterval,
				True);
		EndIf;
	Except
		Raise DetailErrorDescription(ErrorInfo());
	EndTry;
	
EndProcedure

&AtServerNoContext
Function JobCompleted(SendEmailsJobID)
	
	Return TimeConsumingOperations.JobCompleted(SendEmailsJobID);
	
EndFunction

&AtClient
Procedure StartBackgroungJobWaiting(TimeConsumingOperation)
	
	TimeConsumingOperationsClient.InitIdleHandlerParameters(HandlerParameters);
	AttachIdleHandler("Attachable_CheckBackgroundJob", 3, True);
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(Undefined);
	IdleParameters.MessageText = NStr("en = 'Sending email(s)...'; ru = 'Отправка письма (писем)...';pl = 'Wysyłanie wiadomości e-mail...';es_ES = 'Envío de correo electrónico(s)...';es_CO = 'Envío de correo electrónico(s)...';tr = 'E-posta(lar) gönderiliyor...';it = 'Invio email...';de = 'E-Mail(s) werden gesendet...'") ;
	IdleParameters.OutputIdleWindow = True;
	
	TimeConsumingOperationsClient.WaitForCompletion(TimeConsumingOperation, , IdleParameters);
	
EndProcedure

#EndRegion

&AtServer
Procedure AfterEmailSending()
	
	EmailsTree = GetFromTempStorage(EmailsTreeAddress);;
	
	WriteEmailLog(GetSentStatusNumber(), EmailsTree);
	
	FillTheList();
	
EndProcedure

&AtClient
Procedure ApplyFilters()
	
	FilterStatusNumber = GetFilterStatusNumber(FilterStatus);
	
	SetListRowFilter("StatusNumber", FilterStatusNumber, ValueIsFilled(FilterStatus));
	SetListRowFilter("Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	SetListRowFilter("VATTaxation", FilterVATTaxation, ValueIsFilled(FilterVATTaxation));
	SetListRowFilter("Company", FilterCompany, ValueIsFilled(FilterCompany));
	
EndProcedure

&AtServerNoContext 
Function GetFilterStatusNumber(FilterStatus)
	
	If FilterStatus = Enums.MailStatus.Received Then
		Return GetReceivedStatusNumber();
	ElsIf FilterStatus = Enums.MailStatus.Sent Then
		Return GetSentStatusNumber();
	Else
		Return GetNotSentStatusNumber();
	EndIf;
	
EndFunction

&AtServer
Procedure FillTheList()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Documents.DocumentRef AS DocumentRef,
	|	Documents.Recipients AS Recipients
	|INTO TT_CurrentDocuments
	|FROM
	|	&Documents AS Documents
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Emails.DocumentRef AS DocumentRef,
	|	Emails.ContactPerson AS ContactPerson,
	|	Emails.Email AS Email
	|INTO TT_CurrentEmails
	|FROM
	|	&Emails AS Emails
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesInvoice.Date AS Date,
	|	SalesInvoice.Number AS Number,
	|	CASE
	|		WHEN SalesInvoice.DeletionMark
	|			THEN CASE
	|					WHEN SalesInvoice.Posted
	|						THEN 4
	|					ELSE 3
	|				END
	|		ELSE CASE
	|				WHEN SalesInvoice.Posted
	|					THEN 1
	|				ELSE 0
	|			END
	|	END AS DocumentStatus,
	|	Counterparties.Ref AS Counterparty,
	|	Counterparties.ContactPerson AS ContactPerson,
	|	ISNULL(ContactPersonsContactInformation.EMAddress, """") AS Email,
	|	CASE
	|		WHEN ContactPersonsContactInformation.EMAddress IS NULL
	|			THEN """"
	|		ELSE Counterparties.ContactPerson.Description + "" <"" + ContactPersonsContactInformation.EMAddress + "">""
	|	END AS Recipients,
	|	SalesInvoice.Ref AS DocumentRef,
	|	SalesInvoice.VATTaxation AS VATTaxation,
	|	SalesInvoice.DocumentAmount AS DocumentAmount,
	|	SalesInvoice.DocumentCurrency AS DocumentCurrency,
	|	MAX(CASE
	|			WHEN ISNULL(FilesExist.HasFiles, FALSE)
	|				THEN &OpenFiles
	|			ELSE &AddFiles
	|		END) AS AttachedFiles,
	|	SalesInvoice.Company AS Company
	|INTO TT_Documents
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|		INNER JOIN Catalog.Counterparties AS Counterparties
	|			LEFT JOIN Catalog.ContactPersons.ContactInformation AS ContactPersonsContactInformation
	|			ON Counterparties.ContactPerson = ContactPersonsContactInformation.Ref
	|				AND (ContactPersonsContactInformation.Type = VALUE(Enum.ContactInformationTypes.EmailAddress))
	|				AND (ContactPersonsContactInformation.Kind = VALUE(Catalog.ContactInformationKinds.ContactPersonEmail))
	|		ON SalesInvoice.Counterparty = Counterparties.Ref
	|		LEFT JOIN InformationRegister.FilesExist AS FilesExist
	|		ON SalesInvoice.Ref = FilesExist.ObjectWithFiles
	|WHERE
	|	SalesInvoice.Date BETWEEN &StartDate AND &EndDate
	|
	|GROUP BY
	|	SalesInvoice.Date,
	|	SalesInvoice.Number,
	|	CASE
	|		WHEN SalesInvoice.DeletionMark
	|			THEN CASE
	|					WHEN SalesInvoice.Posted
	|						THEN 4
	|					ELSE 3
	|				END
	|		ELSE CASE
	|				WHEN SalesInvoice.Posted
	|					THEN 1
	|				ELSE 0
	|			END
	|	END,
	|	Counterparties.Ref,
	|	Counterparties.ContactPerson,
	|	ISNULL(ContactPersonsContactInformation.EMAddress, """"),
	|	CASE
	|		WHEN ContactPersonsContactInformation.EMAddress IS NULL
	|			THEN """"
	|		ELSE Counterparties.ContactPerson.Description + "" <"" + ContactPersonsContactInformation.EMAddress + "">""
	|	END,
	|	SalesInvoice.Ref,
	|	SalesInvoice.VATTaxation,
	|	SalesInvoice.DocumentAmount,
	|	SalesInvoice.DocumentCurrency,
	|	SalesInvoice.Company
	|
	|INDEX BY
	|	DocumentRef,
	|	Company,
	|	Counterparty
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TT_Documents.DocumentRef AS DocumentRef,
	|	MAX(EmailLog.Period) AS Period
	|INTO TT_LatestSendingsByDocuments
	|FROM
	|	TT_Documents AS TT_Documents
	|		INNER JOIN InformationRegister.EmailLog AS EmailLog
	|		ON TT_Documents.DocumentRef = EmailLog.Document
	|
	|GROUP BY
	|	TT_Documents.DocumentRef
	|
	|INDEX BY
	|	DocumentRef
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TT_Documents.DocumentRef AS DocumentRef,
	|	TT_Documents.Company AS Company,
	|	TT_Documents.Counterparty AS Counterparty,
	|	MAX(EmailLog.Period) AS Period
	|INTO TT_LatestSendingsByCompaniesCounterparties
	|FROM
	|	TT_Documents AS TT_Documents
	|		INNER JOIN InformationRegister.EmailLog AS EmailLog
	|		ON TT_Documents.DocumentRef <> EmailLog.Document
	|			AND TT_Documents.Company = EmailLog.Company
	|			AND TT_Documents.Counterparty = EmailLog.Counterparty
	|
	|GROUP BY
	|	TT_Documents.DocumentRef,
	|	TT_Documents.Company,
	|	TT_Documents.Counterparty
	|
	|INDEX BY
	|	Company,
	|	Counterparty
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TT_LatestSendingsByDocuments.DocumentRef AS DocumentRef,
	|	TT_LatestSendingsByDocuments.Period AS DateOfEmail,
	|	EmailLog.ContactPerson AS ContactPerson,
	|	EmailLog.Email AS Email,
	|	EmailLog.Company AS Company,
	|	EmailLog.Counterparty AS Counterparty,
	|	EmailLog.MailStatus AS EmailStatus,
	|	CASE
	|		WHEN EmailLog.MailStatus = VALUE(Enum.MailStatus.Received)
	|			THEN &Received
	|		WHEN EmailLog.MailStatus = VALUE(Enum.MailStatus.Sent)
	|			THEN &Sent
	|		ELSE &NotSent
	|	END AS StatusNumber,
	|	EmailLog.Recipients AS Recipients
	|INTO TT_EmailLogByDocuments
	|FROM
	|	TT_LatestSendingsByDocuments AS TT_LatestSendingsByDocuments
	|		INNER JOIN InformationRegister.EmailLog AS EmailLog
	|		ON TT_LatestSendingsByDocuments.DocumentRef = EmailLog.Document
	|			AND TT_LatestSendingsByDocuments.Period = EmailLog.Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	TT_LatestSendingsByCompaniesCounterparties.DocumentRef AS DocumentRef,
	|	DATETIME(1, 1, 1) AS DateOfEmail,
	|	EmailLog.ContactPerson AS ContactPerson,
	|	EmailLog.Email AS Email,
	|	EmailLog.Company AS Company,
	|	EmailLog.Counterparty AS Counterparty,
	|	VALUE(Enum.MailStatus.Draft) AS EmailStatus,
	|	&NotSent AS StatusNumber,
	|	EmailLog.Recipients AS Recipients
	|INTO TT_EmailLogByCompaniesCounterparties
	|FROM
	|	TT_LatestSendingsByCompaniesCounterparties AS TT_LatestSendingsByCompaniesCounterparties
	|		INNER JOIN InformationRegister.EmailLog AS EmailLog
	|		ON TT_LatestSendingsByCompaniesCounterparties.Company = EmailLog.Company
	|			AND TT_LatestSendingsByCompaniesCounterparties.Counterparty = EmailLog.Counterparty
	|			AND TT_LatestSendingsByCompaniesCounterparties.Period = EmailLog.Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TT_Documents.Date AS Date,
	|	TT_Documents.Number AS Number,
	|	TT_Documents.DocumentStatus AS DocumentStatus,
	|	TT_Documents.Counterparty AS Counterparty,
	|	TT_Documents.DocumentRef AS DocumentRef,
	|	TT_Documents.VATTaxation AS VATTaxation,
	|	TT_Documents.DocumentAmount AS DocumentAmount,
	|	TT_Documents.DocumentCurrency AS DocumentCurrency,
	|	TT_Documents.AttachedFiles AS AttachedFiles,
	|	TT_Documents.Company AS Company,
	|	ISNULL(TT_EmailLogByDocuments.ContactPerson, ISNULL(TT_EmailLogByCompaniesCounterparties.ContactPerson, TT_Documents.ContactPerson)) AS ContactPerson,
	|	ISNULL(TT_EmailLogByDocuments.Email, ISNULL(TT_EmailLogByCompaniesCounterparties.Email, TT_Documents.Email)) AS Email,
	|	ISNULL(TT_EmailLogByDocuments.StatusNumber, ISNULL(TT_EmailLogByCompaniesCounterparties.StatusNumber, &NotSent)) AS StatusNumber,
	|	ISNULL(TT_EmailLogByDocuments.EmailStatus, ISNULL(TT_EmailLogByCompaniesCounterparties.EmailStatus, VALUE(Enum.MailStatus.Draft))) AS EmailStatus,
	|	ISNULL(TT_EmailLogByDocuments.DateOfEmail, ISNULL(TT_EmailLogByCompaniesCounterparties.DateOfEmail, DATETIME(1, 1, 1))) AS DateOfEmail,
	|	ISNULL(TT_EmailLogByDocuments.Recipients, ISNULL(TT_EmailLogByCompaniesCounterparties.Recipients, TT_Documents.Recipients)) AS Recipients
	|INTO TT_DocumentsAndEmails
	|FROM
	|	TT_Documents AS TT_Documents
	|		LEFT JOIN TT_EmailLogByDocuments AS TT_EmailLogByDocuments
	|		ON TT_Documents.DocumentRef = TT_EmailLogByDocuments.DocumentRef
	|		LEFT JOIN TT_EmailLogByCompaniesCounterparties AS TT_EmailLogByCompaniesCounterparties
	|		ON TT_Documents.DocumentRef = TT_EmailLogByCompaniesCounterparties.DocumentRef
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TT_DocumentsAndEmails.Date AS Date,
	|	TT_DocumentsAndEmails.StatusNumber AS StatusNumber,
	|	TT_DocumentsAndEmails.EmailStatus AS EmailStatus,
	|	TT_DocumentsAndEmails.DateOfEmail AS DateOfEmail,
	|	TT_CurrentDocuments.Recipients AS Recipients,
	|	TT_DocumentsAndEmails.DocumentStatus AS DocumentStatus,
	|	TT_DocumentsAndEmails.DocumentRef AS DocumentRef,
	|	TT_DocumentsAndEmails.Company AS Company,
	|	TT_DocumentsAndEmails.Counterparty AS Counterparty,
	|	TT_DocumentsAndEmails.DocumentAmount AS DocumentAmount,
	|	TT_DocumentsAndEmails.DocumentCurrency AS DocumentCurrency,
	|	TT_DocumentsAndEmails.AttachedFiles AS AttachedFiles,
	|	TT_DocumentsAndEmails.VATTaxation AS VATTaxation
	|FROM
	|	TT_DocumentsAndEmails AS TT_DocumentsAndEmails
	|		INNER JOIN TT_CurrentDocuments AS TT_CurrentDocuments
	|		ON TT_DocumentsAndEmails.DocumentRef = TT_CurrentDocuments.DocumentRef
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	TT_DocumentsAndEmails.Date,
	|	TT_DocumentsAndEmails.StatusNumber,
	|	TT_DocumentsAndEmails.EmailStatus,
	|	TT_DocumentsAndEmails.DateOfEmail,
	|	TT_DocumentsAndEmails.Recipients,
	|	TT_DocumentsAndEmails.DocumentStatus,
	|	TT_DocumentsAndEmails.DocumentRef,
	|	TT_DocumentsAndEmails.Company,
	|	TT_DocumentsAndEmails.Counterparty,
	|	TT_DocumentsAndEmails.DocumentAmount,
	|	TT_DocumentsAndEmails.DocumentCurrency,
	|	TT_DocumentsAndEmails.AttachedFiles,
	|	TT_DocumentsAndEmails.VATTaxation
	|FROM
	|	TT_DocumentsAndEmails AS TT_DocumentsAndEmails
	|		LEFT JOIN TT_CurrentDocuments AS TT_CurrentDocuments
	|		ON TT_DocumentsAndEmails.DocumentRef = TT_CurrentDocuments.DocumentRef
	|WHERE
	|	TT_CurrentDocuments.DocumentRef IS NULL
	|
	|ORDER BY
	|	TT_DocumentsAndEmails.Date
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TT_DocumentsAndEmails.DocumentRef AS DocumentRef,
	|	TT_CurrentEmails.ContactPerson AS ContactPerson,
	|	TT_CurrentEmails.Email AS Email,
	|	TT_DocumentsAndEmails.Counterparty AS Counterparty,
	|	TT_DocumentsAndEmails.Company AS Company,
	|	TT_DocumentsAndEmails.StatusNumber AS StatusNumber
	|FROM
	|	TT_DocumentsAndEmails AS TT_DocumentsAndEmails
	|		INNER JOIN TT_CurrentEmails AS TT_CurrentEmails
	|		ON TT_DocumentsAndEmails.DocumentRef = TT_CurrentEmails.DocumentRef
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	TT_DocumentsAndEmails.DocumentRef,
	|	TT_DocumentsAndEmails.ContactPerson,
	|	TT_DocumentsAndEmails.Email,
	|	TT_DocumentsAndEmails.Counterparty,
	|	TT_DocumentsAndEmails.Company,
	|	TT_DocumentsAndEmails.StatusNumber
	|FROM
	|	TT_DocumentsAndEmails AS TT_DocumentsAndEmails
	|		LEFT JOIN TT_CurrentEmails AS TT_CurrentEmails
	|		ON TT_DocumentsAndEmails.DocumentRef = TT_CurrentEmails.DocumentRef
	|WHERE
	|	TT_CurrentEmails.DocumentRef IS NULL";
	
	Query.SetParameter("NotSent", GetNotSentStatusNumber());
	Query.SetParameter("Sent", GetSentStatusNumber());
	Query.SetParameter("Received", GetReceivedStatusNumber());
	
	Query.SetParameter("StartDate", StartDate);
	Query.SetParameter("EndDate", ?(EndDate = Date(1,1,1), Date(3999, 12, 31), EndOfDay(EndDate)));
	
	Query.SetParameter("AddFiles", GetAddFilesLabel());
	Query.SetParameter("OpenFiles", GetOpenFilesLabel());
	
	Query.SetParameter("Documents", List.Unload());
	Query.SetParameter("Emails", Emails.Unload());
	
	QueryResult = Query.ExecuteBatch();
	
	List.Load(QueryResult[8].Unload());
	Emails.Load(QueryResult[9].Unload());
	
EndProcedure

&AtClient
Function FillEmailsArray(Document)
	
	EmailsArray = New Array;
	
	CurrentDocumentEmails = Emails.FindRows(New Structure("DocumentRef", Document));
	
	For Each EmailRow In CurrentDocumentEmails Do
		EmailsArray.Add(New Structure("ContactPerson, Email", EmailRow.ContactPerson, EmailRow.Email));
	EndDo;
	
	Return EmailsArray;
	
EndFunction

&AtClient
Procedure SetListRowFilter(FieldName, Value, Use)
	
	RowFilter = Items.List.RowFilter;
	
	If RowFilter = Undefined Then
		
		NewFilter = New Structure;
		
		If Use Then
			NewFilter.Insert(FieldName, Value);
		EndIf;
		
	Else
		
		NewFilter = New Structure(RowFilter);
		
		If Use Then
			NewFilter.Insert(FieldName, Value);
		ElsIf NewFilter.Property(FieldName) Then
			NewFilter.Delete(FieldName);
		EndIf;
		
	EndIf;
	
	Items.List.RowFilter = New FixedStructure(NewFilter);
	
EndProcedure

&AtClient
Procedure MarkRows(MarkForActiveRows = Undefined)
	
	For Each Row In List Do
		
		If MarkForActiveRows <> Undefined Then
			Row.ToProcess = MarkForActiveRows;
		EndIf;
		
		If Items.List.RowFilter <> Undefined Then
			
			For Each Filter In Items.List.RowFilter Do
				
				If Row[Filter.Key] <> Filter.Value Then
					Row.ToProcess = False;
					Break;
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure UpdateEmails(NewEmails, Parameters, ForAll)
	
	FilterEmails = New Structure;
	FilterEmails.Insert("StatusNumber", GetNotSentStatusNumber());
	
	If ForAll Then
		FilterEmails.Insert("Company", Parameters.Company);
		FilterEmails.Insert("Counterparty", Parameters.Counterparty);
	Else
		FilterEmails.Insert("DocumentRef", Parameters.Document);
	EndIf;
	
	OldEmailsArray = Emails.FindRows(FilterEmails);
	
	For Index = -OldEmailsArray.UBound() To 0 Do
		Emails.Delete(Emails.IndexOf(OldEmailsArray[-Index]));
	EndDo;
	
	Recipients = ContactPersonsEmailsPresentation(NewEmails);
	
	For Each ListRow In List.FindRows(FilterEmails) Do
		
		ListRows = List.FindRows(New Structure("DocumentRef", ListRow.DocumentRef));
		For Each ListRow In ListRows Do
			ListRow.ToProcess = True;
			ListRow.Recipients = Recipients;
		EndDo;
		
		For Each NewEmail In NewEmails Do
			
			EmailRow = Emails.Add();
			
			FillPropertyValues(EmailRow, Parameters);
			
			EmailRow.DocumentRef = ListRow.DocumentRef;
			EmailRow.Email = NewEmail.Email;
			EmailRow.ContactPerson = NewEmail.ContactPerson;
			EmailRow.StatusNumber = GetNotSentStatusNumber();
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtServer
Function GetEmailsToProcess(Period)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CAST(List.DocumentRef AS Document.SalesInvoice) AS DocumentRef,
	|	CAST(List.Company AS Catalog.Companies) AS Company,
	|	CAST(List.Counterparty AS Catalog.Counterparties) AS Counterparty
	|INTO TT_List
	|FROM
	|	&List AS List
	|
	|INDEX BY
	|	DocumentRef
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CAST(Emails.DocumentRef AS Document.SalesInvoice) AS DocumentRef,
	|	CAST(Emails.ContactPerson AS Catalog.ContactPersons) AS ContactPerson,
	|	Emails.Email AS Email
	|INTO TT_Emails
	|FROM
	|	&Emails AS Emails
	|
	|INDEX BY
	|	DocumentRef
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	&Period AS Period,
	|	TT_List.Company AS Company,
	|	TT_List.Counterparty AS Counterparty,
	|	TT_Emails.ContactPerson AS ContactPerson,
	|	TT_Emails.Email AS Email,
	|	TT_Emails.DocumentRef AS Document,
	|	VALUE(Enum.MailStatus.Sent) AS MailStatus
	|FROM
	|	TT_List AS TT_List
	|		INNER JOIN TT_Emails AS TT_Emails
	|		ON TT_List.DocumentRef = TT_Emails.DocumentRef
	|
	|ORDER BY
	|	Email
	|TOTALS
	|	MAX(Period),
	|	MAX(Company),
	|	MAX(Counterparty),
	|	MAX(MailStatus)
	|BY
	|	Document";
	
	Query.SetParameter("Period", Period);
	Query.SetParameter("List", List.Unload(New Structure("ToProcess", True)));
	Query.SetParameter("Emails", Emails.Unload());
	
	Return Query.Execute().Unload(QueryResultIteration.ByGroups);
	
EndFunction

&AtServer
Procedure WriteEmailLog(NewStatusNumber, Source, Date = Undefined)
	
	If Date = Undefined Then
		Date = CurrentSessionDate();
	EndIf;
	
	RecordSet = InformationRegisters.EmailLog.CreateRecordSet();
	RecordSet.Filter.Period.Set(Date);
	
	If TypeOf(Source) = Type("ValueTree") Then
		
		For Each DocumentRow In Source.Rows Do
			AddEmailLogRecords(NewStatusNumber, RecordSet, DocumentRow.Rows, Date);
		EndDo;
		
	ElsIf TypeOf(Source) = Type("Structure") Then
		
		AddEmailLogRecords(NewStatusNumber, RecordSet, Emails.FindRows(Source), Date);
		
	Else
		Return;
	EndIf;
	
	RecordSet.Write();
	
EndProcedure

&AtServer
Procedure AddEmailLogRecords(NewStatusNumber, RecordSet, RecipientRows, Period)
	
	Recipients = ContactPersonsEmailsPresentation(RecipientRows);
	
	For Each RecipientRow In RecipientRows Do
		
		Record = RecordSet.Add();
		
		FillPropertyValues(Record, RecipientRow);
		
		Record.Recipients = TrimAll(Recipients);
		Record.Period = Period;
		
		If NewStatusNumber = 0 Then
			Record.MailStatus = Enums.MailStatus.Received;
		ElsIf NewStatusNumber = 1 Then
			Record.MailStatus = Enums.MailStatus.Sent;
		Else
			Record.MailStatus = Enums.MailStatus.EmptyRef();
		EndIf;
		
		If TypeOf(RecipientRow) = Type("FormDataCollectionItem") And RecipientRow.Property("DocumentRef") Then
			Record.Document = RecipientRow.DocumentRef;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Function ContactPersonsEmailsPresentation(Recipients)
	
	Presentation = "";
	For Each RecipientRow In Recipients Do
		Presentation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 %2 <%3>; '; ru = '%1 %2 <%3>; ';pl = '%1 %2 <%3>; ';es_ES = '%1 %2 <%3>; ';es_CO = '%1 %2 <%3>; ';tr = '%1 %2 <%3>; ';it = '%1 %2 <%3>; ';de = '%1 %2 <%3>; '"), 
			Presentation,
			String(RecipientRow.ContactPerson),
			RecipientRow.Email);
	EndDo;
	
	StringFunctionsClientServer.DeleteLastCharInString(Presentation, 2);
	
	Return Presentation;
	
EndFunction

&AtClient
Procedure OpenSettingsForm(CurrentData)
	
	If CurrentData.StatusNumber <> GetNotSentStatusNumber() Then
		CommonClientServer.MessageToUser(NStr("en = 'Cannot specify recepients. The email was already sent.'; ru = 'Невозможно указать получателей. Письмо уже было отправлено.';pl = 'Nie można określić odbiorców. Wiadomość e-mail została już wysłana.';es_ES = 'No se pueden especificar los destinatarios. El correo electrónico ya fue enviado.';es_CO = 'No se pueden especificar los destinatarios. El correo electrónico ya fue enviado.';tr = 'Alıcı belirtilemez. Bu e-posta zaten gönderildi.';it = 'Impossibile specificare i destinatari. Le email erano già state inviate.';de = 'Empfänger können nicht angegeben werden. Die E-Mail wurde bereits versendet.'"));
		Return;
	EndIf;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Document", CurrentData.DocumentRef);
	ParametersStructure.Insert("Company", CurrentData.Company);
	ParametersStructure.Insert("Counterparty", CurrentData.Counterparty);
	ParametersStructure.Insert("Emails", FillEmailsArray(CurrentData.DocumentRef));
	
	OpenForm(
		"DataProcessor.ConfirmationOfArrival.Form.Settings",
		ParametersStructure, 
		ThisObject, 
		CurrentData.DocumentRef,
		,
		,
		New NotifyDescription("OnCloseSettingsForm", ThisObject, ParametersStructure));
	
EndProcedure

&AtClient
Procedure OnCloseSettingsForm(Result, Parameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	SimilarRows = List.FindRows(New Structure(
		"StatusNumber, Company, Counterparty",
		GetNotSentStatusNumber(),
		Parameters.Company,
		Parameters.Counterparty));
		
	If SimilarRows.Count() > 1 Then
		
		ShowQueryBox(
			New NotifyDescription(
				"QuestionBeforeUpdatingEmails", 
				ThisObject, 
				New Structure("NewEmails, Filters", Result.NewEmails, Parameters)),
			NStr("en = 'The sales invoice list contains other sales invoices for the same company and customer.
				|Do you want to specify the same recipients for these sales invoices?'; 
				|ru = 'Список инвойсов покупателям содержит другие инвойсы той же организации и покупателя.
				|Указать тех же получателей для данных инвойсов?';
				|pl = 'Lista faktur sprzedaży zawiera inne faktury sprzedaży dla tej samej firmy i nabywcy.
				|Czy chcesz wybrać tych samych odbiorców dla tych faktur sprzedaży?';
				|es_ES = 'La lista de facturas de venta contiene otras facturas de venta para la misma empresa y el mismo cliente. 
				|¿Quiere especificar los mismos destinatarios de estas facturas de venta?';
				|es_CO = 'La lista de facturas de venta contiene otras facturas de venta para la misma empresa y el mismo cliente. 
				|¿Quiere especificar los mismos destinatarios de estas facturas de venta?';
				|tr = 'Satış faturası listesi aynı iş yerinin ve müşterinin satış faturalarını içeriyor.
				|Bu satış faturaları için aynı alıcıları belirtmek istiyor musunuz?';
				|it = 'L''elenco delle fatture di vendita contiene altre fatture di vendita per la stessa azienda e cliente. 
				|Specificare gli stessi destinatari per queste fatture di vendita?';
				|de = 'Die Verkaufsrechnungsliste enthält weitere Verkaufsrechnungen für dieselbe Firma und Kunden.
				|Möchten Sie dieselbe Empfänger für diese Verkaufsrechnungen festlegen?'"),
			QuestionDialogMode.YesNoCancel, 10, DialogReturnCode.Cancel);
			
	Else
		UpdateEmails(Result.NewEmails, Parameters, False);
	EndIf;
	
EndProcedure

&AtClient
Procedure QuestionBeforeUpdatingEmails(Result, Parameters) Export
	UpdateEmails(Parameters.NewEmails, Parameters.Filters, Result = DialogReturnCode.Yes);
EndProcedure

&AtServerNoContext
Procedure SaveFormSettings(SettingsStructure)
	
	FormDataSettingsStorage.Save("ConfirmationOfArrivalForm", "SettingsStructure", SettingsStructure);
	
EndProcedure

&AtServer
Function LoadFormSettings()
	
	SettingsStructure = FormDataSettingsStorage.Load("ConfirmationOfArrivalForm", "SettingsStructure");
	
	If TypeOf(SettingsStructure) = Type("Structure") Then
		
		If SettingsStructure.Property("Status") Then
			FilterStatus = SettingsStructure.Status;
		EndIf;
		
		If SettingsStructure.Property("Counterparty") Then
			FilterCounterparty = SettingsStructure.Counterparty;
		EndIf;
		
		If SettingsStructure.Property("VATTaxation") Then
			FilterVATTaxation = SettingsStructure.VATTaxation;
		EndIf;
		
		If SettingsStructure.Property("Company") Then
			FilterCompany = SettingsStructure.Company;
		EndIf;
		
		If SettingsStructure.Property("StartDate") Then
			StartDate = SettingsStructure.StartDate;
		EndIf;
		
		If SettingsStructure.Property("EndDate") Then
			EndDate = SettingsStructure.EndDate;
		EndIf;
		
	EndIf;
	
	CurrentDate = CurrentSessionDate();
	
	If StartDate = Date(1,1,1) Then
		StartDate = BegOfMonth(CurrentDate);
	EndIf;
	
	If EndDate = Date(1,1,1) Then
		EndDate = EndOfMonth(CurrentDate);
	EndIf;
	
EndFunction

&AtServer
Procedure SetNewStatus(NewStatusNumber)
	
	SelectedRows = List.FindRows(New Structure("ToProcess", True));
	
	For Each DocumentRow In SelectedRows Do
		
		If DocumentRow.StatusNumber = GetReceivedStatusNumber() And NewStatusNumber <> GetReceivedStatusNumber() Then
			DocumentRow.AttachedFiles = GetAddFilesLabel();
		EndIf;
		
		DocumentRow.StatusNumber = NewStatusNumber;
		
	EndDo;
	
	CurrentDate = CurrentSessionDate();
	WriteEmailLog(NewStatusNumber, GetEmailsToProcess(CurrentDate), CurrentDate);
	
EndProcedure

&AtClient
Function CheckMarkedRows(CheckPosting = False, CheckEmails = False)
	
	MarkedRows = List.FindRows(New Structure("ToProcess", True));
	
	If MarkedRows.Count() = 0 Then
		CommonClientServer.MessageToUser(NStr("en = 'Cannot perform this action. First, select sales invoices.'; ru = 'Не удается выполнить действие. Сначала выберите инвойсы покупателям.';pl = 'Nie można wykonać działania. Najpierw, wybierz faktury sprzedaży.';es_ES = 'No se puede realizar esta acción. Primero, seleccione las facturas de venta.';es_CO = 'No se puede realizar esta acción. Primero, seleccione las facturas de venta.';tr = 'Bu işlem gerçekleştirilemiyor. Önce satış faturalarını seçin.';it = 'Impossibile eseguire questa aziende. Innanzitutto, selezionare le fatture di vendita.';de = 'Diese Aktion kann nicht ausgeführt werden. Wählen Sie zuerst die Verkaufsrechnungen aus.'"));
		Return False;
	EndIf;
	
	If CheckEmails Then
		
		MarkedDocuments = New Array;
		For Each Row In MarkedRows Do
			MarkedDocuments.Add(Row.DocumentRef);
		EndDo;
		
		If EmailsNotSpecified(MarkedDocuments) Then
			CommonClientServer.MessageToUser(
				NStr("en = 'Cannot send confirmations of arrival for the selected sales invoices. First, specify the recipients.'; ru = 'Не удается отправить подтверждения прибытия для выбранных расходных накладных. Сначала укажите получателей.';pl = 'Nie można wysłać potwierdzeń przybycia dla wybranych faktur sprzedaży. Najpierw, wybierz odbiorców.';es_ES = 'No se pueden enviar confirmaciones de llegada para las facturas de venta seleccionadas. Primero, especifique los destinatarios.';es_CO = 'No se pueden enviar confirmaciones de llegada para las facturas de venta seleccionadas. Primero, especifique los destinatarios.';tr = 'Seçilen satış faturaları için varış onayları gönderilemiyor. Önce alıcıları belirtin.';it = 'Impossibile inviare le conferme di arrivo per le fatture di vendita selezionate. Innanzitutto, specificare i destinatari.';de = 'Ankunftsbestätigungen für die ausgewählten Verkaufsrechnungen können nicht gesendet werden. Geben Sie zuerst die Empfänger an.'"));
			Return False;
		EndIf;
		
	EndIf;
	
	If CheckPosting Then
		
		AllDocumentsArePosted = True;
		
		For Each Row In MarkedRows Do
			
			If Row.DocumentStatus <> 1 Then
				AllDocumentsArePosted = False;
				Break;
			EndIf;
			
		EndDo;
		
		If Not AllDocumentsArePosted Then
			CommonClientServer.MessageToUser(
				NStr("en = 'Cannot perform this action. Select only the posted sales invoices.'; ru = 'Не удается выполнить действие. Выберите только проведенные инвойсы покупателей.';pl = 'Nie można wykonać działania. Wybierz tylko zatwierdzone faktury sprzedaży.';es_ES = 'No se puede realizar esta acción. Seleccione sólo las facturas de venta contabilizadas.';es_CO = 'No se puede realizar esta acción. Seleccione sólo las facturas de venta contabilizadas.';tr = 'Bu eylem gerçekleştirilemiyor. Sadece kaydedilen satış faturalarını seçin.';it = 'Impossibile eseguire questa azione. Selezionare solo le fatture di vendita pubblicate.';de = 'Diese Aktion kann nicht ausgeführt werden. Wählen Sie nur die gebuchten Verkaufsrechnungen aus.'"));
			Return False;
		EndIf;
		
	EndIf;
	
	Return True;
	
EndFunction

&AtServer
Function EmailsNotSpecified(Documents)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	List.DocumentRef AS DocumentRef
	|INTO TT_List
	|FROM
	|	&List AS List
	|WHERE
	|	List.DocumentRef IN(&Documents)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Emails.DocumentRef AS DocumentRef,
	|	Emails.Email AS Email
	|INTO TT_Emails
	|FROM
	|	&Emails AS Emails
	|WHERE
	|	Emails.DocumentRef IN(&Documents)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_List.DocumentRef AS DocumentRef
	|FROM
	|	TT_List AS TT_List
	|		LEFT JOIN TT_Emails AS TT_Emails
	|		ON TT_List.DocumentRef = TT_Emails.DocumentRef
	|			AND (TT_Emails.Email <> """")
	|WHERE
	|	TT_Emails.DocumentRef IS NULL";
	
	Query.SetParameter("Documents", Documents);
	Query.SetParameter("List", List.Unload(New Structure("ToProcess", True)));
	Query.SetParameter("Emails", Emails.Unload());
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

&AtServerNoContext
Function GetNumberOfAttachedFiles(Document)
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	ISNULL(SUM(1), 0) AS NumberOfFiles
	|FROM
	|	Catalog.SalesInvoiceAttachedFiles AS SalesInvoiceAttachedFiles
	|WHERE
	|	SalesInvoiceAttachedFiles.FileOwner = &Document";
	
	Query.SetParameter("Document", Document);
	QueryResult = Query.Execute();
	
	Return QueryResult.Unload()[0].NumberOfFiles;
	
EndFunction

&AtServerNoContext
Function GetCurrentDocumentStatus(Document)
	
	DocumentStatus = 0;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CASE
	|		WHEN SalesInvoice.DeletionMark
	|			THEN CASE
	|					WHEN SalesInvoice.Posted
	|						THEN 4
	|					ELSE 3
	|				END
	|		ELSE CASE
	|				WHEN SalesInvoice.Posted
	|					THEN 1
	|				ELSE 0
	|			END
	|	END AS DocumentStatus
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.Ref = &Ref";
	
	Query.SetParameter("Ref", Document);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		DocumentStatus = Selection.DocumentStatus;
	EndIf;
	
	Return DocumentStatus;
	
EndFunction

#EndRegion
