///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Public

// Generates reports and sends them according to the transport settings (Foder, FILE, EMAIL, FTP);
//
// Parameters:
//   Mailing - CatalogRef.ReportMailings - a report mailing to be executed.
//   LogParameters - Structure - parameters of the writing to the event log.
//       * EventName - String - an event name (or events group).
//       * Metadata - MetadataObject - metadata to link the event of the event log.
//       * Data - Arbitrary - data to link the event of the event log.
//   AdditionalSettings - Structure - settings that override standard mailing parameters, where:
//       * Recipients - Map - a set of recipients and their email addresses.
//           ** Key - CatalogRef - a recipient.
//           ** Value - String - a set of recipient e-mail addresses in the row with separators.
//
// Returns:
//   Boolean - a flag of successful mailing completion.
//
Function ExecuteReportsMailing(BulkEmail, LogParameters = Undefined, AdditionalSettings = Undefined) Export
	// Parameters of the writing to the event log.
	If LogParameters = Undefined Then
		LogParameters = New Structure;
	EndIf;
	
	If Not LogParameters.Property("EventName") Then
		LogParameters.Insert("EventName", NStr("ru = 'Рассылка отчетов. Запуск по требованию'; en = 'Report bulk email. Start on demand'; pl = 'Masowa wysyłka raportów przez e-mail. Zacznij na żądanie';es_ES = 'Informe del newsletter. Iniciar a petición';es_CO = 'Informe del newsletter. Iniciar a petición';tr = 'Rapor toplu e-postası. Talep üzerine başlat';it = 'Invio massivo di report. Inizio su richiesta';de = 'Bulk-Mail-Bericht. Nach Anfrage starten'", CommonClientServer.DefaultLanguageCode()));
	EndIf;
	
	If Not LogParameters.Property("Data") Then
		LogParameters.Insert("Data", BulkEmail);
	EndIf;
	
	If Not LogParameters.Property("Metadata") Then
		LogParameters.Insert("Metadata", LogParameters.Data.Metadata());
	EndIf;
	
	// Check rights settings
	If Not OutputRight(LogParameters) Then
		Return False;
	EndIf;
	
	// Check basic mailing attributes.
	If Not BulkEmail.Prepared
		Or BulkEmail.DeletionMark Then
		
		Reason = "";
		If Not BulkEmail.Prepared Then
			Reason = Reason + Chars.LF + NStr("ru = 'Рассылка не подготовлена'; en = 'Bulk email is not prepared'; pl = 'Masowa wysyłka e-mail nie jest przygotowana';es_ES = 'El newsletter no está listo';es_CO = 'El newsletter no está listo';tr = 'Toplu e-posta hazırlanmadı';it = 'L''email multipla non è preparata';de = 'Bulk Mail ist nicht bereitet'");
		EndIf;
		If BulkEmail.DeletionMark Then
			Reason = Reason + Chars.LF + NStr("ru = 'Рассылка помечена на удаление'; en = 'Bulk email is marked for deletion'; pl = 'Masowa wysyłka e-mail jest wybrana do usunięcia';es_ES = 'El newsletter está marcado para borrar';es_CO = 'El newsletter está marcado para borrar';tr = 'Toplu e-posta silinmek üzere işaretlendi';it = 'Invio massivo di email contrassegnato per l''eliminazione';de = 'Die Bulk-Mail ist zum Löschen markiert'");
		EndIf;
		
		LogRecord(LogParameters, EventLogLevel.Warning,
			NStr("ru = 'Завершение'; en = 'Completing'; pl = 'Zakończenie';es_ES = 'Terminación';es_CO = 'Terminación';tr = 'Tamamlama';it = 'Completamento';de = 'Fertigstellung'"), TrimAll(Reason));
		Return False;
		
	EndIf;
	
	StartCommitted = CommonClientServer.StructureProperty(AdditionalSettings, "StartCommitted");
	If StartCommitted <> True Then
		// Register startup (started but not completed).
		InformationRegisters.ReportMailingStates.FixMailingStart(BulkEmail);
	EndIf;
	
	// Value table
	ValueTable = New ValueTable;
	ValueTable.Columns.Add("Report", Metadata.Catalogs.ReportMailings.TabularSections.Reports.Attributes.Report.Type);
	ValueTable.Columns.Add("SendIfEmpty", New TypeDescription("Boolean"));
	
	SettingTypesArray = New Array;
	SettingTypesArray.Add(Type("Undefined"));
	SettingTypesArray.Add(Type("DataCompositionUserSettings"));
	SettingTypesArray.Add(Type("Structure"));
	
	ValueTable.Columns.Add("Settings", New TypeDescription(SettingTypesArray));
	ValueTable.Columns.Add("Formats", New TypeDescription("Array"));
	
	// Default formats
	DefaultFormats = New Array;
	FoundItems = BulkEmail.ReportFormats.FindRows(New Structure("Report", EmptyReportValue()));
	For Each StringFormat In FoundItems Do
		DefaultFormats.Add(StringFormat.Format);
	EndDo;
	If DefaultFormats.Count() = 0 Then
		FormatsList = FormatsList();
		For Each ListValue In FormatsList Do
			If ListValue.Check Then
				DefaultFormats.Add(ListValue.Value);
			EndIf;
		EndDo;
	EndIf;
	If DefaultFormats.Count() = 0 Then
		Raise NStr("ru = 'Не установлены форматы по умолчанию.'; en = 'Default formats are not set.'; pl = 'Nie ustawiono formatów domyślnych.';es_ES = 'No se han establecido los formatos por defecto.';es_CO = 'No se han establecido los formatos por defecto.';tr = 'Varsayılan biçimler ayarlanmadı';it = 'Non sono impostati i formati predefiniti.';de = 'Standardformate sind nicht eingestellt.'");
	EndIf;
	
	// Fill reports tables
	For Each RowReport In BulkEmail.Reports Do
		Page = ValueTable.Add();
		Page.Report = RowReport.Report;
		Page.SendIfEmpty = RowReport.SendIfEmpty;
		
		// Settings
		Settings = RowReport.Settings.Get();
		If TypeOf(Settings) = Type("ValueTable") Then
			Page.Settings = New Structure;
			FoundItems = Settings.FindRows(New Structure("Use", True));
			For Each SettingRow In FoundItems Do
				Page.Settings.Insert(SettingRow.Attribute, SettingRow.Value);
			EndDo;
		Else
			Page.Settings = Settings;
		EndIf;
		
		// Formats
		FoundItems = BulkEmail.ReportFormats.FindRows(New Structure("Report", RowReport.Report));
		If FoundItems.Count() = 0 Then
			Page.Formats = DefaultFormats;
		Else
			For Each StringFormat In FoundItems Do
				Page.Formats.Add(StringFormat.Format);
			EndDo;
		EndIf;
	EndDo;
	
	// Prepare delivery parameters.
	DeliveryParameters = New Structure;
	DeliveryParameters.Insert("StartCommitted",           True);
	DeliveryParameters.Insert("Author",                        Users.CurrentUser());
	DeliveryParameters.Insert("UseDirectory",            BulkEmail.UseDirectory);
	DeliveryParameters.Insert("UseNetworkDirectory",   BulkEmail.UseNetworkDirectory);
	DeliveryParameters.Insert("UseFTPResource",        BulkEmail.UseFTPResource);
	DeliveryParameters.Insert("UseEmail", BulkEmail.UseEmail);
	DeliveryParameters.Insert("TransliterateFileNames", BulkEmail.TransliterateFileNames);
	
	// Marked delivery method checks.
	If Not DeliveryParameters.UseDirectory
		AND Not DeliveryParameters.UseNetworkDirectory
		AND Not DeliveryParameters.UseFTPResource
		AND Not DeliveryParameters.UseEmail Then
		LogRecord(LogParameters, EventLogLevel.Warning, NStr("ru = 'Не выбран способ доставки.'; en = 'Delivery method is not selected.'; pl = 'Nie wybrano metody dostawy.';es_ES = 'No se ha seleccionado el método de entrega.';es_CO = 'No se ha seleccionado el método de entrega.';tr = 'Teslimat yöntemi seçilmedi.';it = 'Non è stato selezionato il metodo di consegna.';de = 'Die Zustellungsmethode ist nicht gewählt.'"));
		Return False;
	EndIf;
	
	DeliveryParameters.Insert("Personalized", BulkEmail.Personalized);
	DeliveryParameters.Insert("AddToArchive",      BulkEmail.AddToArchive);
	DeliveryParameters.Insert("ArchiveName",         BulkEmail.ArchiveName);
	SetPrivilegedMode(True);
	DeliveryParameters.Insert("ArchivePassword", Common.ReadDataFromSecureStorage(BulkEmail, "ArchivePassword"));
	SetPrivilegedMode(False);
	
	// Prepare parameters of delivery to the folder.
	If DeliveryParameters.UseDirectory Then
		DeliveryParameters.Insert("Folder", BulkEmail.Folder);
	EndIf;
	
	// Prepare parameters of delivery to the network directory.
	If DeliveryParameters.UseNetworkDirectory Then
		DeliveryParameters.Insert("NetworkDirectoryWindows", BulkEmail.NetworkDirectoryWindows);
		DeliveryParameters.Insert("NetworkDirectoryLinux",   BulkEmail.NetworkDirectoryLinux);
	EndIf;
	
	// Prepare parameters of delivery to the FTP resource.
	If DeliveryParameters.UseFTPResource Then
		DeliveryParameters.Insert("Server",              BulkEmail.FTPServer);
		DeliveryParameters.Insert("Port",                BulkEmail.FTPPort);
		DeliveryParameters.Insert("Username",               BulkEmail.FTPUsername);
		SetPrivilegedMode(True);
		DeliveryParameters.Insert("Password", Common.ReadDataFromSecureStorage(BulkEmail, "FTPPassword"));
		SetPrivilegedMode(False);
		DeliveryParameters.Insert("Directory",             BulkEmail.FTPDirectory);
		DeliveryParameters.Insert("PassiveConnection", BulkEmail.FTPPassiveConnection);
	EndIf;
	
	// Prepare parameters of delivery by email.
	If DeliveryParameters.UseEmail Then
		DeliveryParameters.Insert("Account",   BulkEmail.Account);
		DeliveryParameters.Insert("NotifyOnly", BulkEmail.NotifyOnly);
		DeliveryParameters.Insert("BCC",    BulkEmail.BCC);
		DeliveryParameters.Insert("SubjectTemplate",      BulkEmail.EmailSubject);
		DeliveryParameters.Insert("TextTemplate",  ?(BulkEmail.HTMLFormatEmail, BulkEmail.EmailTextInHTMLFormat, BulkEmail.EmailText));
		
		// Recipients
		If AdditionalSettings <> Undefined AND AdditionalSettings.Property("Recipients") Then
			DeliveryParameters.Insert("Recipients", AdditionalSettings.Recipients);
		Else
			Recipients = GenerateMailingRecipientsList(BulkEmail, LogParameters);
			If Recipients.Count() = 0 Then
				DeliveryParameters.UseEmail = False;
				If Not DeliveryParameters.UseDirectory
					AND Not DeliveryParameters.UseNetworkDirectory
					AND Not DeliveryParameters.UseFTPResource Then
					Return False;
				EndIf;
			EndIf;
			DeliveryParameters.Insert("Recipients", Recipients);
		EndIf;
		
		TextType = ?(BulkEmail.HTMLFormatEmail, "HTML", "PlainText");
		Pictures = New Structure;
		
		EmailParameters = New Structure;
		EmailParameters.Insert("TextType", TextType);
		EmailParameters.Insert("Pictures", Pictures);
		
		If BulkEmail.HTMLFormatEmail Then
			EmailParameters.Pictures = BulkEmail.EmailPicturesInHTMLFormat.Get();
		EndIf;
		
		If ValueIsFilled(BulkEmail.ReplyToAddress) Then
			EmailParameters.Insert("ReplyToAddress", BulkEmail.ReplyToAddress);
		EndIf;
		
		DeliveryParameters.Insert("EmailParameters", EmailParameters);
		
	EndIf;
	
	If Not DeliveryParameters.Property("StartCommitted") Or Not DeliveryParameters.StartCommitted Then
		InformationRegisters.ReportMailingStates.FixMailingStart(BulkEmail);
	EndIf;
	
	Result = ExecuteBulkEmail(ValueTable, DeliveryParameters, BulkEmail, LogParameters);
	InformationRegisters.ReportMailingStates.FixMailingExecutionResult(BulkEmail, DeliveryParameters);
	Return Result;
	
EndFunction

// Executes report mailing without the ReportMailing catalog item.
//
////////////////////////////////////////////////////////////////////////////////
// Parameters:
//
//   Reports - ValueTable - a set of reports to be exported. Columns:
//       * Report - CatalogRef.ReportOptions, CatalogRef.AdditionalReportsAndDataProcessors - 
//           Report to be generated.
//       * SendIfEmpty - Boolean - a flag of sending report even if it is empty.
//       * Settings - settings to generate a report.
//           It is used additionally to determine whether the report belongs to the DCS.
//           - DataCompositionUserSettings - a spreadsheet document will be generated by the DSC mechanisms.
//           - Structure - a spreadsheet document will be generated by the Generate() method.
//               *** Key     - String       - a report object attribute name.
//               *** Value - Arbitrary - a report object attribute value.
//           - Undefined - default settings. To determine whether it belongs to the DCS, the  
//               CompositionDataSchema object attribute will be used.
//       * Formats - Array from EnumRef.ReportSaveFormats -
//            Formats in which the report must be saved and sent.
//
//   DeliveryParameters - Structure - report transport settings (delivery method).
//     Attributes set can be different for different delivery methods:
//
//     Required attributes:
//       * Author - CatalogRef.Users - a mailing author.
//       * UseDirectory            - Boolean - deliver reports to the "Stored files" subsystem folder.
//       * UseNetworkDirectory   - Boolean - deliver reports to the file system folder.
//       * UseFTPResource        - Boolean - deliver reports to the FTP.
//       * UseEmail - Boolean - deliver reports by email.
//
//     Required attributes when { UseFolder = True }:
//       * Folder (CatalogRef.FilesDirectories) - the "Stored files" subsystem folder.
//
//     Required attributes when { UseNetworkDirectory = True }:
//       * NetworkDirectoryWindows - String - a file system directory (local at server or network).
//       * NetworkDirectoryLinux   - String - a file system directory (local at server or network).
//
//     Required attributes when { UseFTPResource = True }:
//       * Server              - String - an FTP server name.
//       * Port                - Number - an FTP server port.
//       * Username               - String - an FTP server user name.
//       * Password              - String - an FTP server user password.
//       * Directory             - String - a path to the directory at the FTP server.
//       * PassiveConnection - Boolean - use passive connection.
//
//     Required attributes when { UseEmail = True }:
//       * Account - CatalogRef.EmailAccounts - 
//           Account to send an email message.
//       * Recipients - Map - a set of recipients and their email addresses.
//           ** Key - CatalogRef - a recipient.
//           ** Value - String - a set of recipient e-mail addresses in the row with separators.
//
//     Optional attributes:
//       * Archive - Boolean - archive all generated reports into one archive.
//                                 Archiving can be required, for example, when mailing schedules in html format.
//       * ArchiveName    - String - an archive name.
//       * ArchivePassword - String - an archive password.
//       * TransliterateFileNames - Boolean - a flag that shows whether it is necessary to transliterate mailing report files name.
//
//     Optional attributes when { UseEmail = True }:
//       * Personalized - Boolean - a mailing personalized by recipients.
//           Default value is False.
//           If True value is set, each recipient will receive a report with a filter by it.
//           To do this, in reports, set the "[Получатель]" filter by the attribute that match the recipient type.
//           Applies only to delivery by mail, so when setting to the True, other delivery methods 
//           are disabled:
//           { UseFolder = False }
//            { UseNetworkDirectory = False }
//           { UseFTPResource = False }
//           And related notification features:
//           { NotifyOnly = False}
//       * NotifyOnly - Boolean, False - send notifications only (do not attach generated reports).
//       * BCC    - Boolean, False - if True, when sending fill BCC instead of To.
//       * SubjectTemplate      - String -       an email subject.
//       * TextTemplate    - String -       an email body.
//       * EmailParameters - Structure -    message parameters that will be passed directly to the 
//           EmailOperations subsystem.
//           Their processing can be seen in the EmailOperations module, the SendMessage procedure.
//           The ReportsMailing subsystem can use:
//           ** TextType - InternetMailTextType,String,EnumRef.EmailTextsTypes - 
//               Email text type.
//           ** Attachments - Map - email pictures.
//               *** Key - String - a description.
//               *** Value - picture data.
//                   - String - an address in the temporary storage where the picture is located.
//                   - BinaryData - binary data of a picture.
//                   - Picture - picture data.
//           ** ResponseAddress - String - an email address of the response.
//
//   MailingDescription - String - displayed in the subject and message as well as to display errors.
//
//   LogParameters - Structure - parameters of the writing to the event log.
//       * EventName - String           - an event name (or events group).
//       * Metadata - MetadataObject - metadata to link the event of the event log.
//       * Data     - Arbitrary     - data to link the event of the event log.
//
// Returns:
//   Boolean - a flag of successful mailing completion.
//
Function ExecuteBulkEmail(Reports, DeliveryParameters, MailingDescription = "", LogParameters = Undefined) Export
	MailingExecuted = False;
	
	// Add a tree of generated reports  - spreadsheet document and reports saved in formats (of files).
	ReportsTree = CreateReportsTree();
	
	// Fill with default parameters and check whether key delivery parameters are filled.
	If Not CheckAndFillExecutionParameters(Reports, DeliveryParameters, MailingDescription, LogParameters) Then
		Return False;
	EndIf;
	
	// Row of the general (not personalized by recipients) reports tree.
	DeliveryParameters.Insert("GeneralReportsRow", DefineTreeRowForRecipient(ReportsTree, Undefined, DeliveryParameters));
	
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Инициализирована рассылка ""%1"", автор: ""%2""'; en = 'The ""%1"" bulk e-mail sending is initialized; from ""%2""'; pl = '""%1"" wysyłanie subskrypcji e-mail jest zainicjowane; z ""%2""';es_ES = 'El envío de newsletter de ""%1"" está iniciado; desde ""%2"".';es_CO = 'El envío de newsletter de ""%1"" está iniciado; desde ""%2"".';tr = '""%1"" toplu e-posta gönderimi başlatıldı; ""%2""dan';it = 'L''invio massivo di e-mail ""%1"" è inizializzato; da ""%2""';de = 'Das ""%1"" Massen-E-Mail-Senden ist initialisiert; von ""%2""'"),
		MailingDescription, DeliveryParameters.Author);
	
	LogRecord(LogParameters,, MessageText);
	
	// Generate and save reports.
	ReportsNumber = 1;
	For Each RowReport In Reports Do
		LogText = NStr("ru = 'Отчет ""%1"" формируется'; en = 'Generating the ""%1"" report'; pl = 'Generowanie ""%1"" sprawozdania';es_ES = 'Generando el informe ""%1""';es_CO = 'Generando el informe ""%1""';tr = '""%1"" raporu oluşturma';it = 'Generazione del report ""%1"" in corso';de = 'Den Bericht ""%1"" erstellen'");
		If RowReport.Settings = Undefined Then
			LogText = LogText + Chars.LF + NStr("ru = '(пользовательские настройки не заданы)'; en = '(user settings are not set)'; pl = '(ustawienia użytkownika nie są ustawione)';es_ES = '(la configuración del usuario no está establecida)';es_CO = '(la configuración del usuario no está establecida)';tr = '(kullanıcı ayarları ayarlanmadı)';it = '(impostazioni utente non configurate)';de = '(Benutzereinstellungen sind nicht eingestellt)'");
		EndIf;
		
		ReportPresentation = String(RowReport.Report);
		
		LogRecord(LogParameters,
			EventLogLevel.Note,
			StringFunctionsClientServer.SubstituteParametersToString(LogText, ReportPresentation));
		
		// Initialize report.
		ReportParameters = New Structure("Report, Settings, Formats, SendIfEmpty");
		FillPropertyValues(ReportParameters, RowReport);
		If Not InitializeReport(LogParameters, ReportParameters, DeliveryParameters.Personalized) Then
			Continue;
		EndIf;
		
		If DeliveryParameters.Personalized AND NOT ReportParameters.Personalized Then
			ReportParameters.Errors = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Отчет ""%1"" не может сформирован, так как в его настройках не указан отбор по получателю рассылки.'; en = 'Cannot generate the ""%1"" report as the filter by by a recipient of a bulk e-mail sending is not specified in settings.'; pl = 'Nie wygenerowano ""%1"" raportu jako filtru według wysyłania odbiorcy subskrypcji e-mail nie jest określony w ustawieniach.';es_ES = 'No se puede generar el informe ""%1"", ya que el filtro de un destinatario del envío del newsletter no se especifica en las configuraciones.';es_CO = 'No se puede generar el informe ""%1"", ya que el filtro de un destinatario del envío del newsletter no se especifica en las configuraciones.';tr = '''''%1'''' raporu düzenlenemedi çünkü alıcıya göre toplu e-posta gönderimi filtresi ayarlarda belirtilmedi.';it = 'Impossibile generare report ""%1"" perché il filtro per destinatario dell''invio di e-mail massive non è specificato nelle impostazioni.';de = 'Der ""%1"" Bericht kann nicht generiert werden, denn der Filter vom Empfänger der Massen-E-Mails ist in den Einstellungen nicht angegeben.'"),
				ReportPresentation);
			
			LogRecord(LogParameters, EventLogLevel.Error, ReportParameters.Errors);
			Continue;
		EndIf;
	
		// Generate spreadsheet documents and save in formats.
		Try
			If ReportParameters.Personalized Then
				// Broken down by recipients
				For Each KeyAndValue In DeliveryParameters.Recipients Do
					GenerateAndSaveReport(
						LogParameters,
						ReportParameters,
						ReportsTree,
						DeliveryParameters,
						KeyAndValue.Key);
				EndDo;
			Else
				// Without personalization
				GenerateAndSaveReport(
					LogParameters,
					ReportParameters,
					ReportsTree,
					DeliveryParameters,
					Undefined);
			EndIf;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Отчет ""%1"" успешно сформирован'; en = 'The ""%1"" report is successfully generated'; pl = '""%1"" raport został wygenerowany pomyślnie';es_ES = 'El informe ""%1"" se ha generado con éxito';es_CO = 'El informe ""%1"" se ha generado con éxito';tr = '""%1"" raporu başarıyla düzenlendi';it = 'Il report ""%1"" è stato generato con successo';de = 'Der ""%1"" Bericht ist erfolgreich generiert'"), ReportPresentation);
			
			LogRecord(LogParameters, EventLogLevel.Note, MessageText);

			ReportsNumber = ReportsNumber + 1;
		Except
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Отчет ""%1"" не сформирован:'; en = 'The ""%1"" report is not generated:'; pl = 'Nie wygenerowano raportu ""%1"":';es_ES = 'El informe ""%1"" no se ha generado:';es_CO = 'El informe ""%1"" no se ha generado:';tr = '""%1"" raporu oluşturulmadı:';it = 'Il report ""%1"" non è stato generato:';de = 'Der ""%1"" Bericht ist nicht generiert:'"), ReportPresentation);
			
			LogRecord(LogParameters,, MessageText, DetailErrorDescription(ErrorInfo()));
		EndTry;
	EndDo;
	
	// Check the number of the saved reports.
	If ReportsTree.Rows.Find(3, "Level", True) = Undefined Then
		LogRecord(LogParameters,
			EventLogLevel.Warning,
			NStr("ru = 'Рассылка отчетов не выполнена, так как отчеты пустые или не сформированы из-за ошибок.'; en = 'Reports are not mailed as they are empty or were not generated due to errors.'; pl = 'Raporty nie są wysyłane pocztą, ponieważ są puste lub nie zostały wygenerowane z powodu błędów.';es_ES = 'Los informes no se han enviado por correo ya que están vacíos o no se han generado debido a errores.';es_CO = 'Los informes no se han enviado por correo ya que están vacíos o no se han generado debido a errores.';tr = 'Raporlar boş oldukları için gönderilmedi ya da hatalara bağlı olarak düzenlenmedi.';it = 'I report non sono stati inviati perché risultano vuoti o non generati a causa di qualche errore.';de = 'Die Berichte sind nicht gesendet denn sie sind leere oder wegen Fehler nicht generiert.'"));
			
		Common.DeleteTemporaryDirectory(DeliveryParameters.TempFilesDirectory);
		Return False;
	EndIf;
	
	// General reports.
	SharedAttachments = DeliveryParameters.GeneralReportsRow.Rows.FindRows(New Structure("Level", 3), True);
	
	// Send personal reports (personalized).
	For Each RecipientRow In ReportsTree.Rows Do
		If RecipientRow = DeliveryParameters.GeneralReportsRow Then
			Continue; // Ignore the general reports tree row.
		EndIf;
		
		// Personal attachments.
		PersonalAttachments = RecipientRow.Rows.FindRows(New Structure("Level", 3), True);
		
		// Check the number of saved personal reports.
		If PersonalAttachments.Count() = 0 Then
			Continue;
		EndIf;
		
		// Merge common and personal attachments.
		RecipientsAttachments = CombineArrays(SharedAttachments, PersonalAttachments);
		
		// Generate reports presentation.
		GenerateReportPresentationsForRecipient(DeliveryParameters, RecipientRow);
		
		// Archive attachments.
		ArchiveAttachments(RecipientsAttachments, DeliveryParameters, RecipientRow.Value);
		
		RecipientPresentation = String(RecipientRow.Key);
		
		// Transport.
		Try
			SendReportsToRecipient(RecipientsAttachments, DeliveryParameters, RecipientRow);
			MailingExecuted = True;
			DeliveryParameters.ExecutedByEmail = True;
		Except
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не удалось отправить отчеты получателю ""%1"":'; en = 'Cannot send reports to the recipient ""%1"":'; pl = 'Nie można wysłać raportów do odbiorców ""%1"":';es_ES = 'No se pueden enviar informes al destinatario ""%1"":';es_CO = 'No se pueden enviar informes al destinatario ""%1"":';tr = '""%1"" alıcısına raporlar gönderilemiyor:';it = 'Impossibile inviare i report al destinatario ""%1"":';de = 'Die Berichte können an die Empfänger ""%1"" nicht gesendet werden:'"), RecipientPresentation);
			
			LogRecord(LogParameters,, MessageText, DetailErrorDescription(ErrorInfo()));
		EndTry;
		
		If MailingExecuted Then
			DeliveryParameters.Recipients.Delete(RecipientRow.Key);
		EndIf;
	EndDo;
	
	// Send general reports.
	If SharedAttachments.Count() > 0 Then
		// Reports presentation.
		GenerateReportPresentationsForRecipient(DeliveryParameters, RecipientRow);
		
		// Archive attachments.
		ArchiveAttachments(SharedAttachments, DeliveryParameters, DeliveryParameters.TempFilesDirectory);
		
		// Transport.
		If ExecuteDelivery(LogParameters, DeliveryParameters, SharedAttachments) Then
			MailingExecuted = True;
		EndIf;
	EndIf;

	If MailingExecuted Then
		LogRecord(LogParameters, , NStr("ru = 'Рассылка выполнена'; en = 'Bulk email is completed'; pl = 'Masowa wysyłka e-mail została zakończona';es_ES = 'El newsletter se ha completado';es_CO = 'El newsletter se ha completado';tr = 'Toplu e-posta tamamlandı';it = 'L''invio massivo di email completato';de = 'Bulk-Mail ist abgeschlossen'"));
	Else
		LogRecord(LogParameters, , NStr("ru = 'Рассылка не выполнена'; en = 'Bulk email failed'; pl = 'Masowa wysyłka e-mail nie powiodła się';es_ES = 'Error en el newsletter';es_CO = 'Error en el newsletter';tr = 'Toplu e-posta gönderimi başarısız oldu';it = 'L''invio massivo di email non riuscito';de = 'Bulk Mail fehlgeschlagen'"));
	EndIf;
	
	Common.DeleteTemporaryDirectory(DeliveryParameters.TempFilesDirectory);
	
	// Result.
	If LogParameters.Property("HadErrors") Then
		DeliveryParameters.HadErrors = LogParameters.HadErrors;
	EndIf;
	
	If LogParameters.Property("HasWarnings") Then
		DeliveryParameters.HasWarnings = LogParameters.HasWarnings;
	EndIf;
	
	Return MailingExecuted;
EndFunction

// To call from the modules ReportsMailingOverridable or ReportsMailingCached.
//   Adds format (if absent) and sets its parameters (if passed).
//
// Parameters:
//   FormatsList - ListOfValues - a list of formats.
//   FormatRef   - String, EnumRef.ReportStorageFormats - a reference or name of the format.
//   Picture                - Picture - optional. Formats picture.
//   UseByDefault - Boolean   - optional. Flag showing that the format is used by default.
//
Procedure SetFormatsParameters(FormatsList, FormatRef, Picture = Undefined, UseByDefault = Undefined) Export
	If TypeOf(FormatRef) = Type("String") Then
		FormatRef = Enums.ReportSaveFormats[FormatRef];
	EndIf;
	ListItem = FormatsList.FindByValue(FormatRef);
	If ListItem = Undefined Then
		ListItem = FormatsList.Add(FormatRef, String(FormatRef), False, PictureLib.BlankFormat);
	EndIf;
	If Picture <> Undefined Then
		ListItem.Picture = Picture;
	EndIf;
	If UseByDefault <> Undefined Then
		ListItem.Check = UseByDefault;
	EndIf;
EndProcedure

// To call from the modules ReportsMailingOverridable or ReportsMailingCached.
//   Adds recipients type description to the table.
//
// Parameters:
//   TypesTable - ValueTable - passed from procedure parameters as is. Contains types information.
//   AvailableTypes - Array          - passed from procedure parameters as is. Unused types array.
//   Settings     - Structure       - predefined settings to register the main type.
//     Mandatory parameters:
//       * MainType - Type - a main type for the described recipients.
//     Optional parameters:
//       * Presentation - String - a presentation of this type of recipients in the interface.
//       * CIKind - CatalogRef.ContactInformationKinds - a main type or group of contact information 
//           for email addresses of this type of recipients.
//       * ChoiceFormPath - String - a path to the choice form.
//       * AdditionalType - Type - an additional type that can be selected along with the main one from the choice form.
//
Procedure AddItemToRecipientsTypesTable(TypesTable, AvailableTypes, Settings) Export
	SetPrivilegedMode(True);
	
	MainTypesMetadata = Metadata.FindByType(Settings.MainType);
	
	// Register the main type usage.
	TypeIndex = AvailableTypes.Find(Settings.MainType);
	If TypeIndex <> Undefined Then
		AvailableTypes.Delete(TypeIndex);
	EndIf;
	
	// Metadata objects IDs.
	MetadataObjectID = Common.MetadataObjectID(Settings.MainType);
	TableRow = TypesTable.Find(MetadataObjectID, "MetadataObjectID");
	If TableRow = Undefined Then
		TableRow = TypesTable.Add();
		TableRow.MetadataObjectID = MetadataObjectID;
	EndIf;
	
	// Recipients type
	TypesArray = New Array;
	TypesArray.Add(Settings.MainType);
	
	// Recipients type: Main
	TableRow.MainType = New TypeDescription(TypesArray);
	
	// Recipients type: Additional.
	If Settings.Property("AdditionalType") Then
		TypesArray.Add(Settings.AdditionalType);
		
		// Register the additional type.
		TypeIndex = AvailableTypes.Find(Settings.AdditionalType);
		If TypeIndex <> Undefined Then
			AvailableTypes.Delete(TypeIndex);
		EndIf;
	EndIf;
	TableRow.RecipientsType = New TypeDescription(TypesArray);
	
	// Presentation
	If Settings.Property("Presentation") Then
		TableRow.Presentation = Settings.Presentation;
	Else
		TableRow.Presentation = MainTypesMetadata.Synonym;
	EndIf;
	
	// Main type of contact information email for the object.
	If Settings.Property("CIKind") AND Not Settings.CIKind.IsFolder Then
		TableRow.MainCIKind = Settings.CIKind;
		TableRow.CIGroup = Settings.CIKind.Parent;
	Else
		If Settings.Property("CIKind") Then
			TableRow.CIGroup = Settings.CIKind;
		Else
			
			If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
				
				ModuleContactsManager = Common.CommonModule("ContactsManager");
				CIGroupName = StrReplace(MainTypesMetadata.FullName(), ".", "");
				TableRow.CIGroup = ModuleContactsManager.ContactInformationKindByName(CIGroupName);
				
			EndIf;
			
		EndIf;
		Query = New Query;
		Query.Text = "SELECT TOP 1 Ref FROM Catalog.ContactInformationKinds WHERE Parent = &Parent AND Type = &Type";
		Query.SetParameter("Parent", TableRow.CIGroup);
		Query.Parameters.Insert("Type", Enums.ContactInformationTypes.EmailAddress);
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			TableRow.MainCIKind = Selection.Ref;
		EndIf;
	EndIf;
	
	// Full path to the choice form of this object.
	If Settings.Property("ChoiceFormPath") Then
		TableRow.ChoiceFormPath = Settings.ChoiceFormPath;
	Else
		TableRow.ChoiceFormPath = MainTypesMetadata.FullName() +".ChoiceForm";
	EndIf;
EndProcedure

// Executes an array of mailings and places the result at the ResultAddress address. In the file 
//   mode called directly, in the client/server mode called through a background job.
//
// Parameters:
//   ExecutionParameters - Structure - mailings to be executed and their parameters.
//       * RefArray - Array from CatalogRef.ReportMailings - mailings to be executed.
//       * PreliminarySettings - Structure - parameters, see ReportsMailing.ExecuteReportsMailing. 
//   ResultAddress - String - an address in the temporary storage where the result will be placed.
//
Procedure SendBulkEmailsInBackgroundJob(ExecutionParameters, ResultAddress) Export
	MailingArray           = ExecutionParameters.MailingArray;
	PreliminarySettings = ExecutionParameters.PreliminarySettings;
	
	// Selecting all mailings including nested excluding groups.
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED DISTINCT
	|	ReportMailings.Ref AS BulkEmail,
	|	ReportMailings.Presentation AS Presentation,
	|	CASE
	|		WHEN ReportMailings.Prepared = TRUE
	|				AND ReportMailings.DeletionMark = FALSE
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS Prepared,
	|	FALSE AS Executed,
	|	FALSE AS WithErrors
	|FROM
	|	Catalog.ReportMailings AS ReportMailings
	|WHERE
	|	ReportMailings.Ref IN HIERARCHY(&MailingArray)
	|	AND ReportMailings.IsFolder = FALSE";
	
	Query.SetParameter("MailingArray", MailingArray);
	MailingsTable = Query.Execute().Unload();
	PreparedReportDistributionDetails = MailingsTable.FindRows(New Structure("Prepared", True));
	Completed = 0;
	WithErrors = 0;
	
	MessagesArray = New Array;
	For Each TableRow In PreparedReportDistributionDetails Do
		LogParameters = New Structure("ErrorArray", New Array);
		
		TableRow.Executed = ExecuteReportsMailing(
			TableRow.BulkEmail,
			LogParameters,
			PreliminarySettings);
		TableRow.WithErrors = (LogParameters.ErrorArray.Count() > 0);
		
		If TableRow.WithErrors Then
			MessagesArray.Add("---" + Chars.LF + Chars.LF + TableRow.Presentation + ":"); // Title
			For Each Message In LogParameters.ErrorArray Do
				MessagesArray.Add(Message);
			EndDo;
		EndIf;
		
		If TableRow.Executed Then
			Completed = Completed + 1;
			If TableRow.WithErrors Then
				WithErrors = WithErrors + 1;
			EndIf;
		EndIf;
	EndDo;
	
	Total        = MailingsTable.Count();
	Prepared = PreparedReportDistributionDetails.Count();
	NotCompleted  = Prepared - Completed;
	
	If Total = 0 Then
		MessageText = NStr("ru = 'Выбранные группы не содержат рассылок отчетов.'; en = 'The selected groups do not have report mailing.'; pl = 'Wybrane grupy nie mają mailingu raportów.';es_ES = 'Los grupos seleccionados no disponen de envío de informe.';es_CO = 'Los grupos seleccionados no disponen de envío de informe.';tr = 'Seçilen grupların rapor gönderimi yok.';it = 'I gruppi selezionati non dispongono dell''invio di report.';de = 'Die gewählten Gruppen haben kein Bericht-Mailing.'");
	ElsIf Total <= 5 Then
		MessageText = "";
		For Each TableRow In MailingsTable Do
			If Not TableRow.Prepared Then
				MessageTemplate = NStr("ru = 'Рассылка ""%1"" не подготовлена.'; en = 'Bulk email ""%1"" is not prepared.'; pl = 'Masowa wysyłka e-mail ""%1"" nie jest przygotowana.';es_ES = 'El newsletter ""%1"" no está listo.';es_CO = 'El newsletter ""%1"" no está listo.';tr = '""%1"" toplu e-postası hazırlanmadı.';it = 'L''email multipla ""%1"" non è preparata.';de = 'Bulk Mail ""%1"" ist nicht vorbereitet.'");
			ElsIf Not TableRow.Executed Then
				MessageTemplate = NStr("ru = 'Рассылка ""%1"" не выполнена.'; en = 'Bulk email ""%1"" was not completed.'; pl = 'Masowa wysyłka e-mail ""%1"" nie została zakończona.';es_ES = 'El newsletter ""%1"" no ha sido completado.';es_CO = 'El newsletter ""%1"" no ha sido completado.';tr = '""%1"" toplu e-postası tamamlanmadı.';it = 'L''invio massivo di email ""%1"" non è stato completato.';de = 'Massen-E-Mail ""%1"" ist nicht abgeschlossen.'");
			ElsIf TableRow.WithErrors Then
				MessageTemplate = NStr("ru = 'Рассылка ""%1"" выполнена с ошибками.'; en = 'Bulk email ""%1"" has completed with errors.'; pl = 'Masowa wysyłka e-mail ""%1"" zakończyła się z błędami.';es_ES = 'El newsletter ""%1"" se ha completado con errores.';es_CO = 'El newsletter ""%1"" se ha completado con errores.';tr = '""%1"" toplu e-postası hatalarla tamamlandı.';it = 'L''invio massivo di email ""%1"" è stato completato con errori.';de = 'Bulk Mail ""%1"" abgeschlossen mit Fehlern'");
			Else
				MessageTemplate = NStr("ru = 'Рассылка ""%1"" выполнена.'; en = 'Bulk email ""%1"" is completed.'; pl = 'Masowa wysyłka e-mail ""%1"" zakończyła się.';es_ES = 'El newsletter ""%1"" se ha completado.';es_CO = 'El newsletter ""%1"" se ha completado.';tr = '""%1"" toplu e-postası tamamlandı.';it = 'L''invio massivo di email ""%1"" è completato.';de = 'Massen-E-Mail ""%1"" ist abgeschlossen.'");
			EndIf;
			MessageTemplate = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, TableRow.Presentation);
			
			If MessageText = "" Then
				MessageText = MessageTemplate;
			Else
				MessageText = MessageText + Chars.LF + Chars.LF + MessageTemplate;
			EndIf;
		EndDo;
	Else
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Подготовлено рассылок: %1 из %2
			|Выполнено: %3
			|С ошибками: %4
			|Не выполнено: %5'; 
			|en = 'Prepared mailings: %1 of %2
			|Completed: %3
			|With errors: %4
			|Not completed: %5'; 
			|pl = 'Przygotowane mailingi: %1 %2
			|Zakończone: %3
			|Z błędami: %4
			|Nie zakończone: %5';
			|es_ES = 'Envíos preparados: %1de %2
			|Completado: %3
			|Con errores: %4
			|No completado: %5';
			|es_CO = 'Envíos preparados: %1de %2
			|Completado: %3
			|Con errores: %4
			|No completado: %5';
			|tr = 'Hazırlanan gönderimler:%2
			|''dan %1Tamamlanan:%3
			|Hatalı: %4
			|Tamamlanmayan:%5';
			|it = 'Invii preparati: %1 di%2
			|Completati: %3
			|Con errori: %4
			|Non completati: %5';
			|de = 'Vorbereitete Mailings: %1 von %2
			|Abgeschlossen: %3
			|Mit Fehlern: %4
			|Nicht abgeschlossen: %5'"),
			Format(Prepared, "NZ=0; NG=0"), Format(Total, "NZ=0; NG=0"),
			Format(Completed,    "NZ=0; NG=0"),
			Format(WithErrors,    "NZ=0; NG=0"),
			Format(NotCompleted,  "NZ=0; NG=0"));
	EndIf;
	
	Result = New Structure;
	Result.Insert("BulkEmails", MailingsTable.UnloadColumn("BulkEmail"));
	Result.Insert("Text", MessageText);
	Result.Insert("More", MessagesToUserString(MessagesArray));
	PutToTempStorage(Result, ResultAddress);
EndProcedure

#Region ObsoleteProceduresAndFunctions

// Obsolete. Use ExecuteReportsMailing.
// Generates reports and sends them according to the transport settings (Foder, FILE, EMAIL, FTP);
//
// Parameters:
//   Mailing - CatalogRef.ReportMailings - a report mailing to be executed.
//   LogParameters - Structure - parameters of the writing to the event log.
//       * EventName - String - an event name (or events group).
//       * Metadata - MetadataObject - metadata to link the event of the event log.
//       * Data - Arbitrary - data to link the event of the event log.
//   AdditionalSettings - Structure - settings that redefine the standard mailing parameters.
//       * Recipients - Map - a set of recipients and their email addresses.
//           ** Key - CatalogRef - a recipient.
//           ** Value - String - a set of recipient e-mail addresses in the row with separators.
//
// Returns:
//   Boolean - a flag of successful mailing completion.
//
Function PrepareParametersAndExecuteMailing(BulkEmail, LogParameters = Undefined, AdditionalSettings = Undefined) Export
	
	Return ExecuteReportsMailing(BulkEmail, LogParameters, AdditionalSettings);
	
EndFunction

#EndRegion

#EndRegion

#Region Internal

// Adds commands for creating mailings to the report form.
//
// Parameters:
//   Form - ClientApplicationForm - ReportFormExtension -
//   Cancel - Boolean -
//   StandardProcessing - Boolean -
//
Procedure ReportFormAddCommands(Form, Cancel, StandardProcessing) Export
	
	// Mailings can be added only if there is an option link (it is internal or additional).
	If Form.ReportSettings.External Then
		Return;
	EndIf;
	If Not InsertRight() Then
		Return;
	EndIf;
	
	// Add commands and buttons
	Commands = New Array;
	
	CreateCommand = Form.Commands.Add("ReportMailingCreateNew");
	CreateCommand.Action  = "ReportMailingClient.CreateNewBulkEmailFromReport";
	CreateCommand.Picture  = PictureLib.ReportMailing;
	CreateCommand.Title = NStr("ru = 'Создать рассылку отчетов...'; en = 'Create report bulk email...'; pl = 'Utwórz masową wysyłkę raportów przez e-mail...';es_ES = 'Generar informe de newsletter...';es_CO = 'Generar informe de newsletter...';tr = 'Rapor toplu e-postası oluştur...';it = 'Creare invio massivo di report...';de = 'Bulk-Mail-Bericht erstellen...'");
	CreateCommand.ToolTip = NStr("ru = 'Создать новую рассылку отчетов и добавить в нее отчет с текущими настройками.'; en = 'Create new report bulk email and add a report with current settings to it.'; pl = 'Utwórz nową masową wysyłkę raportów przez e-mail i dodaj do niej raport z bieżącymi ustawieniami.';es_ES = 'Generar un nuevo informe de newsletter y añadir un informe con la configuración actual.';es_CO = 'Generar un nuevo informe de newsletter y añadir un informe con la configuración actual.';tr = 'Yeni bir rapor toplu e-postası yarat ve ona mevcut ayarlarla bir rapor ekle.';it = 'Creare un nuovo invio massivo di email di report e aggiungervi il report con le impostazioni correnti.';de = 'Neuen Bulk-Mail-Bericht erstellen und dem den Bericht mit laufenden Einstellungen hinzufügen.'");
	Commands.Add(CreateCommand);
	
	AttachCommand = Form.Commands.Add("ReportMailingAddToExisting");
	AttachCommand.Action  = "ReportMailingClient.AttachReportToExistingBulkEmail";
	AttachCommand.Title = NStr("ru = 'Включить в существующую рассылку отчетов...'; en = 'Include in the existing report bulk email...'; pl = 'Włącz do istniejącej wysyłki masowej raportów przez e-mail...';es_ES = 'Incluir en el informe existente el newsletter...';es_CO = 'Incluir en el informe existente el newsletter...';tr = 'Var olan rapor toplu e-postasına dahil et...';it = 'Includere nell''invio massivo di email di report esistente...';de = 'In den vorhandenen Bulk-Mail-Bericht einschließen...'");
	AttachCommand.ToolTip = NStr("ru = 'Присоединить отчет с текущими настройками к существующей рассылке отчетов.'; en = 'Attach the report with current settings to the existing report bulk email.'; pl = 'Załącz raport z bieżącymi ustawieniami do istniejącej masowej wysyłki raportów przez e-mail.';es_ES = 'Adjuntar el informe con la configuración actual al informe existente del newsletter.';es_CO = 'Adjuntar el informe con la configuración actual al informe existente del newsletter.';tr = 'Mevcut ayarlı raporu var olan rapor toplu e-postasına ekle.';it = 'Allegare il report con le impostazioni correnti all''invio massivo di report esistente.';de = 'Den Bericht mit aktuellen Einstellungen dem vorhandenen Bulk-Mail-Bericht hinzufügen.'");
	Commands.Add(AttachCommand);
	
	MailingsWithReportsNumber = MailingsWithReportsNumber(Form.ReportSettings.OptionRef);
	If MailingsWithReportsNumber > 0 Then
		MailingsCommand = Form.Commands.Add("ReportMailingOpenMailingsWithReport");
		MailingsCommand.Action  = "ReportMailingClient.OpenBulkEmailsWithReport";
		MailingsCommand.Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Рассылки отчета (%1)'; en = 'Report bulk emails (%1)'; pl = 'Masowe wysyłki raportów przez e-mail (%1)';es_ES = 'Informe de los newsletter (%1)';es_CO = 'Informe de los newsletter (%1)';tr = 'Rapor toplu e-postaları (%1)';it = 'Invio massivo di report (%1)';de = 'Massen-E-Mail-Bericht: (%1)'"), 
			MailingsWithReportsNumber);
		MailingsCommand.ToolTip = NStr("ru = 'Открыть список рассылок, в которые включен отчет.'; en = 'Open list of mailings containing the report.'; pl = 'Otwórz listę mailingów zawierających raport.';es_ES = 'Abrir la lista de correos que contienen el informe.';es_CO = 'Abrir la lista de correos que contienen el informe.';tr = 'Raporun olduğu gönderimlerin listesini aç.';it = 'Aprire l''elenco di invii contenenti il report.';de = 'Die Mailing-Liste mit dem Bericht öffnen.'");
		Commands.Add(MailingsCommand);
	EndIf;
	
	ReportsServer.OutputCommand(Form, Commands, "SubmenuSend", False, False, "ReportMailing");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Administration panels.

// Returns True if the user has the right to save report mailings.
Function InsertRight() Export
	Return CheckAddRightErrorText() = "";
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonOverridable.OnAddReferenceSearchExceptions 
//
// Parameters:
//   RefSearchExceptions - Array -
//
Procedure OnAddReferenceSearchExceptions(RefSearchExceptions) Export
	
	RefSearchExceptions.Add(Metadata.Catalogs.ReportMailings.Attributes.MailingRecipientType);
	
EndProcedure

// See SafeModeManagerOverridable.OnFillPermissionsToAccessExternalResources. 
//
// Parameters:
//   PermissionRequests - Array -
//
Procedure OnFillPermissionsToAccessExternalResources(PermissionRequests) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	QueryText = 
	"SELECT
	|	ReportMailings.Ref,
	|	ReportMailings.UseFTPResource,
	|	ReportMailings.FTPServer,
	|	ReportMailings.FTPDirectory,
	|	ReportMailings.FTPPort,
	|	ReportMailings.UseNetworkDirectory,
	|	ReportMailings.NetworkDirectoryWindows,
	|	ReportMailings.NetworkDirectoryLinux
	|FROM
	|	Catalog.ReportMailings AS ReportMailings
	|WHERE
	|	ReportMailings.DeletionMark = FALSE
	|	AND (ReportMailings.UseNetworkDirectory = TRUE
	|		OR ReportMailings.UseFTPResource = TRUE)";
	
	Query = New Query;
	Query.Text = QueryText;
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	BulkEmail = Query.Execute().Select();
	While BulkEmail.Next() Do
		
		PermissionRequests.Add(
			ModuleSafeModeManager.RequestToUseExternalResources(
				PermissionsToUseServerResources(BulkEmail), BulkEmail.Ref));
		
	EndDo;
	
EndProcedure

// See ToDoListOverridable.OnDetermineToDoListHandlers 
//
// Parameters:
//  ToDoList - Array -
//
Procedure OnFillToDoList(ToDoList) Export
	If Not InsertRight() Then
		Return;
	EndIf;
	
	ToDoName = "ReportMailingIssues";
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	If ModuleToDoListServer.UserTaskDisabled(ToDoName) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
		"SELECT ALLOWED
		|	COUNT(ReportMailings.Ref) AS Count
		|FROM
		|	InformationRegister.ReportMailingStates AS ReportMailingStates
		|		INNER JOIN Catalog.ReportMailings AS ReportMailings
		|		ON ReportMailingStates.BulkEmail = ReportMailings.Ref
		|WHERE
		|	ReportMailings.Prepared = TRUE
		|	AND ReportMailingStates.WithErrors = TRUE
		|	AND ReportMailings.Author = &Author";
	Filters = New Structure;
	Filters.Insert("DeletionMark", False);
	Filters.Insert("Prepared", True);
	Filters.Insert("WithErrors", True);
	Filters.Insert("IsFolder", False);
	If Users.IsFullUser() Then
		Query.Text = StrReplace(Query.Text, "AND ReportMailings.Author = &Author", "");
	Else
		Filters.Insert("Author", Users.CurrentUser());
		Query.SetParameter("Author", Filters.Author);
	EndIf;
	IssuesCount = Query.Execute().Unload()[0].Count;
	
	FormParameters = New Structure;
	FormParameters.Insert("Filter", Filters);
	FormParameters.Insert("Representation", "List");
	
	Sections = ModuleToDoListServer.SectionsForObject(Metadata.Catalogs.ReportMailings.FullName());
	For Each Section In Sections Do
		ToDoItem = ToDoList.Add();
		ToDoItem.ID  = ToDoName + StrReplace(Section.FullName(), ".", "");
		ToDoItem.HasUserTasks       = IssuesCount > 0;
		ToDoItem.Presentation  = NStr("ru = 'Проблемы с рассылками отчетов'; en = 'Report bulk email issues'; pl = 'Problemy z masową wysyłką raportów przez e-meil';es_ES = 'Informar los temas del newsletter';es_CO = 'Informar los temas del newsletter';tr = 'Rapor toplu e-posta çıkışları';it = 'Problemi con invio massivo di report';de = 'Bulk-Mail-Probleme'");
		ToDoItem.Count     = IssuesCount;
		ToDoItem.Form          = "Catalog.ReportMailings.ListForm";
		ToDoItem.FormParameters = FormParameters;
		ToDoItem.Important         = True;
		ToDoItem.Owner       = Section;
	EndDo;
EndProcedure

// See BatchObjectModificationOverridable.OnDetermineObjectsWithEditableAttributes. 
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.ReportMailings.FullName(), "AttributesToSkipInBatchProcessing");
EndProcedure

// See ScheduledJobsOverridable.OnDefineScheduledJobsSettings. 
//
// Parameters:
//   Dependencies - ValueTable -
//
Procedure OnDefineScheduledJobSettings(Dependencies) Export
	Dependence = Dependencies.Add();
	Dependence.ScheduledJob = Metadata.ScheduledJobs.ReportMailing;
	Dependence.UseExternalResources = True;
	Dependence.IsParameterized = True;
EndProcedure

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillListsWithAccessRestriction(Lists) Export
	
	Lists.Insert(Metadata.Catalogs.ReportMailings, True);
	
EndProcedure

// See InfobaseUpdateOverridable.OnDefineSettings 
//
// Parameters:
//   Objects - Array -
//
Procedure OnDefineObjectsWithInitialFilling(Objects) Export
	
	Objects.Add(Metadata.Catalogs.ReportMailings);
	
EndProcedure

Procedure OnAddUpdateHandlers(Handlers) Export
		
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Scheduled job execution.

// Starts mailing and controls result.
//
// Parameters:
//   Mailing - CatalogRef.ReportMailings - a report mailing to be executed.
//
Procedure ExecuteScheduledMailing(BulkEmail) Export
	
	// Checks.
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.ReportMailing);
	
	// Register startup (started but not completed).
	InformationRegisters.ReportMailingStates.FixMailingStart(BulkEmail);
	
	If Not AccessRight("Read", Metadata.Catalogs.ReportMailings) Then
		Raise
			NStr("ru = 'У текущего пользователя недостаточно прав для чтения рассылок отчетов.
				|Рекомендуется отключить все рассылки этого пользователя или сменить автора его рассылок (на вкладке ""Расписание"").'; 
				|en = 'The current user has insufficient rights to view report bulk mails. 
				|It is recommended that you unsubscribe this user from all bulk mails or change the author of their mailings (on the Schedule tab).'; 
				|pl = 'Aktualny użytkownik ma niewystarczające uprawnienia do obejrzenia masowych wiadomości e-mail. 
				|Zaleca się wypisanie tego użytkownika ze wszystkich masowych wiadomości e-mail lub zmianę autora ich mailingu (w zakładce Harmonogram).';
				|es_ES = 'El usuario actual no tiene suficientes derechos para ver el informe de los newsletter. 
				|Se recomienda cancelar la suscripción de este usuario de todos los correos masivos o cambiar el autor de sus correos (en la pestaña Horario).';
				|es_CO = 'El usuario actual no tiene suficientes derechos para ver el informe de los newsletter. 
				|Se recomienda cancelar la suscripción de este usuario de todos los correos masivos o cambiar el autor de sus correos (en la pestaña Horario).';
				|tr = 'Bu kullanıcının rapor toplu e-postalarını görüntülemek için hakları yetersiz. 
				| Bu kullanıcının tüm toplu e-postalara olan aboneliğini kaldırılmanız veya gönderimlerin yazarını değiştirmeniz (Zaman çizelgesi sekmesinde) tavsiye edilir.';
				|it = 'L''utente corrente non dispone di autorizzazioni sufficienti per visualizzare l''email massive di report. 
				|Si consiglia di consiglia di disabilitare questo utente in tutte le email massive o modificare l''autore delle email massive (nella scheda Pianificazione).';
				|de = 'Der aktuelle Benutzer hat unzureichende Rechte um den Massen-E-Mail-Bericht anzusehen.
				|Es ist empfehlenswert dass Sie diesen Benutzer aus allen Massen-E-Mails ausschreiben oder den Autor der Mailings ändern (Zeitplan Tab).'");
	EndIf;
	Query = New Query("SELECT ALLOWED ExecuteOnSchedule FROM Catalog.ReportMailings WHERE Ref = &Ref");
	Query.SetParameter("Ref", BulkEmail);
	Selection = Query.Execute().Select();
	If Not Selection.Next() Then
		Raise
			NStr("ru = 'У текущего пользователя недостаточно прав для чтения этой рассылки.
				|Рекомендуется сменить автора рассылки (на вкладке ""Расписание"").'; 
				|en = 'The current user has insufficient rights to read this bulk email. 
				|It is recommended that you change the bulk email author (on the Schedule tab).'; 
				|pl = 'Aktualny użytkownik ma wystarczające uprawnienia do odczytania tej masowej wysyłki e-mail. 
				|Zaleca się zmianę autora masowej wysyłki e-mail (w zakładce Harmonogram).';
				|es_ES = 'El usuario actual no tiene suficientes derechos para leer este newsletter. 
				|Se recomienda cambiar el autor del newsletter (en la pestaña Horario).';
				|es_CO = 'El usuario actual no tiene suficientes derechos para leer este newsletter. 
				|Se recomienda cambiar el autor del newsletter (en la pestaña Horario).';
				|tr = 'Bu kullanıcının bu toplu e-postayı okumak için hakları yetersiz. 
				| Toplu e-posta yazarını değiştirmeniz (Zaman çizelgesi sekmesinde) tavsiye edilir.';
				|it = 'L''utente corrente non dispone di autorizzazioni sufficienti per leggere queste email massive. 
				|Si consiglia di modificare l''autore di email massive (nella scheda Pianificazione).';
				|de = 'Der aktuelle Benutzer hat unzureichende Rechte um den Bulk-Mail-Bericht anzusehen.
				|Es ist empfehlenswert dass Sie den Autor der Bulk Mail ändern (Zeitplan Tab).'");
	EndIf;
	If Not Selection.ExecuteOnSchedule Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'У рассылки отчетов ""%1"" отключен флажок ""Выполнять по расписанию""
				|Рекомендуется отключить соответствующее регламентное задание или перезаписать эту рассылку.'; 
				|en = 'The ""Run on schedule"" check box is cleared for bulk email of reports ""%1"". 
				|It is recommended that you disable the corresponding scheduled job or rewrite the bulk email.'; 
				|pl = 'Pole wyboru „Uruchom zgodnie z harmonogramem” jest wyczyszczone dla masowych wiadomości e-mail z raportami ""%1"". 
				|Zaleca się wyłączenie odpowiedniego zaplanowanego zadania lub przepisanie masowej wiadomości e-mail.';
				|es_ES = 'La casilla de verificación ""Lanzamiento por horario"" está desactivada para el newsletter de informes ""%1"". 
				|Se recomienda desactivar la tarea programada correspondiente o reescribir el newsletter.';
				|es_CO = 'La casilla de verificación ""Lanzamiento por horario"" está desactivada para el newsletter de informes ""%1"". 
				|Se recomienda desactivar la tarea programada correspondiente o reescribir el newsletter.';
				|tr = '''''Planlanmış başlatma'''' işaret kutucuğu ''''%1'''' rapor toplu e-postaları için temizlendi. 
				| İlgili zamanlanmış işi devre dışı bırakmanız veya toplu e-postayı tekrar yazmanız tavsiye edilir.';
				|it = 'La funzione ""Avvio programmato"" dell''invio massivo di report ""%1"" è disabilitata. 
				|Si consiglia di disabilitare il task programmato corrispondente o riscrivere l''invio massivo.';
				|de = 'Das ""Start nach Zeitplan"" Kontrollkästchen ist für die Bulk Mails von Berichten ""%1"" gelöscht.
				|Es ist empfehlenswert dass Sie den jeweiligen geplanten Auftrag deaktivieren oder die Bulk Mail neu schreiben.'"),
			String(BulkEmail));
	EndIf;
	
	// Parameters of the writing to the event log.
	LogParameters = New Structure("EventName, Metadata, Data");
	LogParameters.EventName = NStr("ru = 'Рассылка отчетов. Запуск по расписанию'; en = 'Report bulk email. Run on schedule'; pl = 'Masowa wysyłka raportów przez e-mail. Uruchom zgodnie z harmonogramem';es_ES = 'Informe del newsletter. Lanzamiento por horario';es_CO = 'Informe del newsletter. Lanzamiento por horario';tr = 'Rapor toplu e-postası. Planlanmış başlatma';it = 'Invio massivo di report. Avvio programmato';de = 'Bulk-Mail-Bericht. Start nach Zeitplan'", CommonClientServer.DefaultLanguageCode());
	LogParameters.Metadata = BulkEmail.Metadata();
	LogParameters.Data     = BulkEmail;
	
	// BulkEmail
	ExecuteReportsMailing(BulkEmail, LogParameters, New Structure("StartCommitted", True));
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal export procedures and functions.

// Generate a recipients list from the Recipients tabular section of mailing.
//
// Parameters:
//   Mailing - CatalogRef.ReportMailings, Structure - a catalog item for which recipients list 
//              generating is required.
//
// Returns:
//   Structure - a result of the mailing recipients list receiving.
//       * Recipients - Map - Recipients. See ReportMailing.ExecuteMailing, details of the  DeliveryParameters.Recipients.
//       * Errors- String - errors that occurred in the process.
//
Function GenerateMailingRecipientsList(BulkEmail, LogParameters = Undefined) Export
	
	RecipientsEmailAddressKind = BulkEmail.RecipientEmailAddressKind;
	
	If BulkEmail.Personal Then
		
		RecipientsType = TypeOf(BulkEmail.Author);
		RecipientsMetadata = Metadata.FindByType(RecipientsType);
		
		RecipientsTable = New ValueTable;
		For Each Attribute In Metadata.Catalogs.ReportMailings.TabularSections.Recipients.Attributes Do
			RecipientsTable.Columns.Add(Attribute.Name, Attribute.Type);
		EndDo;
		RecipientsTable.Add().Recipient = BulkEmail.Author;
		
	Else
		RecipientsMetadata = Common.MetadataObjectByID(BulkEmail.MailingRecipientType, False);
		RecipientsType = BulkEmail.MailingRecipientType.MetadataObjectKey.Get();
		RecipientsTable = BulkEmail.Recipients.Unload();
	EndIf;
	
	RecipientsList = New Map;
	
	Query = New Query;
	If RecipientsType = Type("CatalogRef.Users") Then
	
		QueryText =
		"SELECT
		|	RecipientsTable.Recipient,
		|	RecipientsTable.Excluded
		|INTO ttRecipientTable
		|FROM
		|	&RecipientsTable AS RecipientsTable
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT
		|	MAX(ReportMailingRecipients.Excluded) AS Excluded,
		|	UserGroupCompositions.User
		|INTO ttRecipients
		|FROM
		|	ttRecipientTable AS ReportMailingRecipients
		|		INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
		|		ON ReportMailingRecipients.Recipient = UserGroupCompositions.UsersGroup
		|			AND (UserGroupCompositions.UsersGroup.DeletionMark = FALSE)
		|WHERE
		|	UserGroupCompositions.User REFS Catalog.Users
		|	AND UserGroupCompositions.User.DeletionMark = FALSE
		|	AND UserGroupCompositions.User.Invalid = FALSE
		|	AND UserGroupCompositions.User.Internal = FALSE
		|
		|GROUP BY
		|	UserGroupCompositions.User
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT
		|	ttRecipients.User AS Recipient,
		|	UserContactInformation.Presentation AS EMail
		|FROM
		|	ttRecipients AS ttRecipients
		|		LEFT JOIN Catalog.Users.ContactInformation AS UserContactInformation
		|		ON ttRecipients.User = UserContactInformation.Ref
		|WHERE
		|	ttRecipients.Excluded = FALSE
		|	AND UserContactInformation.Kind = &RecipientEmailAddressKind";
		
	Else
		
		QueryText =
		"SELECT
		|	RecipientsTable.Recipient,
		|	RecipientsTable.Excluded
		|INTO ttRecipientTable
		|FROM
		|	&RecipientsTable AS RecipientsTable
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT
		|	BulkEmailRecipients.Ref AS Recipient,
		|	RecipientContactInformation.Presentation AS EMail
		|FROM
		|	Catalog.Users AS BulkEmailRecipients
		|		LEFT JOIN Catalog.Users.ContactInformation AS RecipientContactInformation
		|		ON (RecipientContactInformation.Ref = BulkEmailRecipients.Ref)
		|			AND (RecipientContactInformation.Kind = &RecipientEmailAddressKind)
		|WHERE
		|	BulkEmailRecipients.Ref IN HIERARCHY
		|			(SELECT
		|				Recipients.Recipient
		|			FROM
		|				ttRecipientTable AS Recipients
		|			WHERE
		|				Recipients.Excluded = FALSE)
		|	AND (NOT BulkEmailRecipients.Ref IN HIERARCHY
		|				(SELECT
		|					RecipientExclusions.Recipient
		|				FROM
		|					ttRecipientTable AS RecipientExclusions
		|				WHERE
		|					RecipientExclusions.Excluded = TRUE))
		|	AND BulkEmailRecipients.DeletionMark = FALSE
		|	AND &ThisIsNotGroup";
		
		If Not RecipientsMetadata.Hierarchical Then
			// Not hierarchical
			QueryText = StrReplace(QueryText, "IN HIERARCHY", "IN");
			QueryText = StrReplace(QueryText, "AND &ThisIsNotGroup", "");
		ElsIf RecipientsMetadata.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyOfItems Then
			// Item hierarchy
			QueryText = StrReplace(QueryText, "AND &ThisIsNotGroup", "");
		Else
			// Group hierarchy
			QueryText = StrReplace(QueryText, "AND &ThisIsNotGroup", "AND BulkEmailRecipients.IsFolder = FALSE");
		EndIf;
		
		QueryText = StrReplace(QueryText, "Catalog.Users", RecipientsMetadata.FullName());
		
	EndIf;
	
	Query.SetParameter("RecipientsTable", RecipientsTable);
	If ValueIsFilled(RecipientsEmailAddressKind) Then
		Query.SetParameter("RecipientEmailAddressKind", RecipientsEmailAddressKind);
	Else
		QueryText = StrReplace(QueryText, ".Kind = &RecipientEmailAddressKind", ".Type = &MailAddressType");
		Query.SetParameter("MailAddressType", Enums.ContactInformationTypes.EmailAddress);
	EndIf;
	Query.Text = QueryText;
	
	ErrorMessageTextForEventLog = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Не удалось сформировать список получателей ""%1"" по причине:'; en = 'Cannot form the recipient list ""%1"" due to:'; pl = 'Nie można utworzyć listy odbiorców ""%1"" z powodu:';es_ES = 'No se puede formar la lista de destinatarios ""%1"" a causa de:';es_CO = 'No se puede formar la lista de destinatarios ""%1"" a causa de:';tr = '''''%1'''' alıcı listesi bundan dolayı oluşturulamıyor:';it = 'Impossibile creare l''elenco dei destinatari ""%1"" a causa di:';de = 'Die ""%1"" Empfängerliste kann nicht erstellt werden wegen:'"), String(RecipientsType));
	
	//  Extension mechanism
	Try
		StandardProcessing = True;
		ReportMailingOverridable.BeforeGenerateMailingRecipientsList(BulkEmail, Query, StandardProcessing, RecipientsList);
		If StandardProcessing <> True Then
			Return RecipientsList;
		EndIf;
	Except
		LogRecord(LogParameters,, ErrorMessageTextForEventLog, ErrorInfo());
		Return RecipientsList;
	EndTry;
	
	// Standard processing
	Try
		BulkEmailRecipients = Query.Execute().Unload();
	Except
		LogRecord(LogParameters,, ErrorMessageTextForEventLog, ErrorInfo());
		Return RecipientsList;
	EndTry;
	
	For Each BulkEmailRecipient In BulkEmailRecipients Do
		If Not ValueIsFilled(BulkEmailRecipient.EMail) Then
			Continue;
		EndIf;
		
		CurrentAddress = RecipientsList.Get(BulkEmailRecipient.Recipient);
		CurrentAddress = ?(CurrentAddress = Undefined, "", CurrentAddress + "; ");
		RecipientsList[BulkEmailRecipient.Recipient] = CurrentAddress + BulkEmailRecipient.EMail;
	EndDo;
	
	If RecipientsList.Count() = 0 Then
		ErrorsText = NStr("ru = 'Не удалось сформировать список получателей ""%1"" по одной из возможных причин:
		| - У получателей не заполнен адрес электронной почты ""%2"";
		| - Не заполнен список получателей или получатели помечены на удаление;
		| - Выбраны пустые группы получателей;
		| - Исключены все получатели (исключение имеет наивысший приоритет; участники исключенных групп также исключаются из списка);
		| - Недостаточно прав доступа к справочнику ""%1"".'; 
		|en = 'Cannot form the recipient list ""%1"" due to one of the following possible reasons:
		| - The recepients'' e-mail address ""%2"" is not specified;
		| - The list of recepients is not given or recepients are marked for deletion;
		| - The selected groups of recepients are empty;
		| - All recepients are excluded (exclusion has the highest priority; participants of excluded groups are also excluded from the list);
		| - You do not possess enough rights to access the catalog ""%1"".'; 
		|pl = 'Nie można otworzyć listy odbiorców ""%1"" z jednego z następujących możliwych powodów:
		| - Odbiorca adresu e-mail ""%2"" nie jest określony;
		| - lista odbiorców nie jest podana lub odbiorcy są wybrani do usunięcia;
		| - Wybrane grupy odbiorców są puste;
		| - Wszyscy odbiorcy są wykluczeni (wykluczenie ma najwyższy priorytet; uczestnicy wykluczonych grup są również wykluczeni z listy);
		| - Nie masz wystarczających uprawnień, aby uzyskać dostęp do katalogu ""%1"".';
		|es_ES = 'No se puede formar la lista de destinatarios ""%1"" a causa de una de las siguientes razones posibles: 
		|- No se especifica la dirección de correo electrónico ""%2""de los destinatarios;
		| - No se indica la lista de destinatarios o se marca a los destinatarios para su eliminación; 
		|- Los grupos de destinatarios seleccionados están vacíos; 
		|- Se excluyen todos los destinatarios (la exclusión tiene la máxima prioridad; los participantes de los grupos excluidos también se excluyen de la lista); 
		|- No se poseen suficientes derechos para acceder al catálogo ""%1"".';
		|es_CO = 'No se puede formar la lista de destinatarios ""%1"" a causa de una de las siguientes razones posibles: 
		|- No se especifica la dirección de correo electrónico ""%2""de los destinatarios;
		| - No se indica la lista de destinatarios o se marca a los destinatarios para su eliminación; 
		|- Los grupos de destinatarios seleccionados están vacíos; 
		|- Se excluyen todos los destinatarios (la exclusión tiene la máxima prioridad; los participantes de los grupos excluidos también se excluyen de la lista); 
		|- No se poseen suficientes derechos para acceder al catálogo ""%1"".';
		|tr = '''''%1'''' alıcı listesi bu olası sebeplerden birinden dolayı oluşturulamıyor: 
		| - Alıcıların e-posta adresi ''''%2'''' belirtilmemiş; 
		| - Alıcı listesi verilmemiş veya alıcılar silinmek üzere işaretlenmiş; 
		| - Seçilen alıcılar grupları boş; 
		| - Tüm alıcılar hariç tutulmuş (hariç tutulma en yüksek önceliğe sahip; hariç tutulan grupların katılımcıları da listeden hariç tutulur); 
		| - ''''%1'''' kataloğuna erişmek için yeterli haklara sahip değilsiniz.';
		|it = 'Impossibile creare l''elenco di destinatari ""%1"" per uno di questi possibili motivi:
		| - L''indirizzo email del destinatario ""%2"" non è indicato;
		| - Manca l''elenco dei destinatari o ci sono destinatari contrassegnati per l''eliminazione;
		| - Il gruppo selezionato di destinatari è vuoto;
		| - Tutti i destinatari sono esclusi (l''esclusione ha la massima priorità; anche i partecipanti dei gruppi esclusi vengono esclusi dall''elenco);
		| - Non possiedi autorizzazioni necessarie per accedere alla directory ""%1"".';
		|de = 'Die ""%1"" Empfängerliste kann aus einem der folgenden möglichen Gründen nicht erstellt werden:
		| - Die ""%2"" Empfänger-E-Mail-Adresse ist nicht angegeben;
		| - Die Empfängerliste ist nicht angegeben oder die Empfänger sind zum Löschen markiert;
		| - Die gewählten Empfängergruppen sind leer;
		| - Alle Empfänger sind ausgeschlossen (Ausschließung mit Höchstpriorität; die Teilnehmer der ausgeschlossenen Gruppen sind auch aus der Liste ausgeschlossen);
		| - Sie haben unzureichende Rechte um den Katalog zuzugreifen""%1"".'");
		
		LogRecord(LogParameters, EventLogLevel.Error,
			StringFunctionsClientServer.SubstituteParametersToString(ErrorsText, String(RecipientsType),
			String(RecipientsEmailAddressKind)), "");
	EndIf;
	
	Return RecipientsList;
EndFunction

// Connects, checks and initializes the report by reference and used before generating or editing 
// parameters.
//
// Parameters:
//   ReportParameters - Structure - a settings report and the result of its initialization.
//       * Report - CatalogRef.ReportOptions - a report reference.
//       * Settings - Undefined, DataCompositionUserSettings,ValueTable - 
//           Report settings to use, for details see the WriteReportsRowSettings procedure of the 
//           Catalog.ReportsMailing.ObjectForm module.
//   PersonalizationAvailable - Boolean - True if a report can be personalized.
//   UUIDOfForm - UUID - optional. DCS location address.
//
// Parameters to be changed during the method operation:
//   ReportParameters - Structure - 
//     Initialization result:
//       * Initialized - Boolean - True if was successful.
//       * Errors - String - an error text.
//     Properties of all reports:
//       * Name - String - a report name.
//       * IsOption - Boolean - True if vendor is the ReportOptions catalog.
//       * DCS - Boolean - True if a report is based on DCS.
//       * Metadata - MetadataObject: Report - report metadata.
//       * Object - ReportObject.<report name>, ExternalReport - a report object.
//     Properties of reports based on DCS:
//       * DCSSchema - DataCompositionSchema
//       * DCSettingsComposer - DataCompositionSettingsComposer
//       * DCSettings - DataCompositionSettings - 
//       * SchemaURL - String - an address of data composition schema in the temporary storage.
//     Properties of arbitrary reports:
//       * AvailableAttributes - Structure - a name and parameters of the attribute.
//           ** <Attribute name> - Structure - attribute parameters.
//               *** Presentation - String - attribute presentation.
//               *** Type - TypeDescription - attribute type.
//
// Returns:
//   Boolean - True if initialization was successful (matches the ReportParameters.Initialized).
//
Function InitializeReport(LogParameters, ReportParameters, PersonalizationAvailable, UUIDOfForm = Undefined) Export
	
	// Check reinitialization.
	If ReportParameters.Property("Initialized") Then
		Return ReportParameters.Initialized;
	EndIf;
	
	ReportParameters.Insert("Initialized", False);
	ReportParameters.Insert("Errors", "");
	ReportParameters.Insert("Personalized", False);
	ReportParameters.Insert("PersonalFilters", New Map);
	ReportParameters.Insert("IsOption", TypeOf(ReportParameters.Report) = Type("CatalogRef.ReportsOptions"));
	ReportParameters.Insert("DCS", False);
	ReportParameters.Insert("AvailableAttributes", Undefined);
	ReportParameters.Insert("DCSettingsComposer", Undefined);
	
	AttachmentParameters = New Structure;
	AttachmentParameters.Insert("OptionRef",              ReportParameters.Report);
	AttachmentParameters.Insert("FormID",          UUIDOfForm);
	AttachmentParameters.Insert("DCUserSettings", ReportParameters.Settings);
	If TypeOf(AttachmentParameters.DCUserSettings) <> Type("DataCompositionUserSettings") Then
		AttachmentParameters.DCUserSettings = New DataCompositionUserSettings;
	EndIf;
	Try
		Attachment = ReportsOptions.AttachReportAndImportSettings(AttachmentParameters);
		CommonClientServer.SupplementStructure(ReportParameters, Attachment, True);
	Except
		ReportParameters.Errors = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось подключить и загрузить настройки отчета ""%1"".'; en = 'Cannot attach report ""%1"" and load its settings.'; pl = 'Nie można dołączyć raportu ""%1"" i załadować jego ustawień.';es_ES = 'No se puede adjuntar el informe ""%1"" y descargar su configuración.';es_CO = 'No se puede adjuntar el informe ""%1"" y descargar su configuración.';tr = '""%1"" raporu eklenemiyor ve ayarları yüklenemiyor.';it = 'Impossibile allegare report ""%1"" e caricare le sue impostazioni.';de = 'Der Bericht ""%1"" kann nicht beigelegt werden; seine Einstellungen können nicht heruntergeladen werden.'"),
			String(ReportParameters.Report));
		LogRecord(
			LogParameters,
			EventLogLevel.Error,
			ReportParameters.Errors,
			ErrorInfo());
		Return ReportParameters.Initialized;
	EndTry;
	
	// In existing mailings, we generate only reports that are ready for mailing.
	If ReportMailingCached.ReportsToExclude().Find(Attachment.ReportRef) <> Undefined Then
		ReportParameters.Errors = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Отчет ""%1"" не предназначен для рассылки.
			|Подробнее см. в процедуре ОпределитьИсключаемыеОтчеты модуля РассылкаОтчетовПереопределяемый.'; 
			|en = 'Report ""%1"" is not intended for bulk mail.
			|For more information, see procedure DetermineReportsToExclude of module ReportMailingOverridable.'; 
			|pl = 'Raport ""%1"" nie jest przeznaczony do masowych e-maili.
			|O więcej informacji, zobacz procedurę DetermineReportsToExclude modułu ReportMailingOverridable.';
			|es_ES = 'El informe ""%1"" no está destinado al correo masivo.
			|Para más información, véase el procedimiento DetermineReportsToExclude el procedimiento ReportMailingOverridable.';
			|es_CO = 'El informe ""%1"" no está destinado al correo masivo.
			|Para más información, véase el procedimiento DetermineReportsToExclude el procedimiento ReportMailingOverridable.';
			|tr = 'Rapor ''''%1'''' toplu e-posta için uygun değil. 
			| Daha fazla bilgi için prosedüre göz atınız DetermineReportsToExclude of module ReportMailingOverridable.';
			|it = 'Il report ""%1"" non è destinato all''invio massivo.
			|Per ulteriori informazioni vedere la procedura DetermineReportsToExclude del modulo ReportMailingOverridable.';
			|de = 'Der Bericht ""%1"" ist für die Massen-E-Mail nicht ausgelegt.
			|Für weitere Informationen siehe die Prozedur ZuAusschließendeBerichte von Modus MailingBerichtOverridable.'"),
			String(Attachment.ReportRef));
		LogRecord(LogParameters, EventLogLevel.Error, ReportParameters.Errors);
		Return False;
	EndIf;
	If Not Attachment.Success Then
		LogRecord(LogParameters, EventLogLevel.Error, Attachment.ErrorText);
		Return False;
	EndIf;
	ReportParameters.DCSettingsComposer = Attachment.Object.SettingsComposer;
	
	// Determine whether the report belongs to the Data Composition System.
	If TypeOf(ReportParameters.Settings) = Type("DataCompositionUserSettings") Then
		ReportParameters.DCS = True;
	ElsIf TypeOf(ReportParameters.Settings) = Type("ValueTable") Then
		ReportParameters.DCS = False;
	ElsIf TypeOf(ReportParameters.Settings) = Type("Structure") Then
		ReportParameters.DCS = False;
	Else
		ReportParameters.DCS = (ReportParameters.Object.DataCompositionSchema <> Undefined);
	EndIf;
	
	// Initialize a report and fill its parameters.
	If ReportParameters.DCS Then
		
		// Set personal filters.
		If PersonalizationAvailable Then
			DCUserSettings = ReportParameters.DCSettingsComposer.UserSettings;
			Filter = New Structure("Use, Value", True, "[Recipient]");
			FoundItems = ReportsClientServer.SettingsItemsFiltered(DCUserSettings, Filter);
			For Each DCUserSetting In FoundItems Do
				DCID = DCUserSettings.GetIDByObject(DCUserSetting);
				If DCID <> Undefined Then
					ReportParameters.PersonalFilters.Insert(DCID);
				EndIf;
			EndDo;
		EndIf;
		
	Else // Not DCS Report.
		
		// Available report attributes
		ReportParameters.AvailableAttributes = New Structure;
		For Each Attribute In ReportParameters.Metadata.Attributes Do
			ReportParameters.AvailableAttributes.Insert(Attribute.Name, 
				New Structure("Presentation, Type", Attribute.Presentation(), Attribute.Type));
		EndDo;
		
		If ValueIsFilled(ReportParameters.Settings) Then
			
			// Check whether attributes are available.
			// Prepare personal filters mappings.
			// Set static values of attributes.
			For Each SettingDetails In ReportParameters.Settings Do
				If TypeOf(SettingDetails) = Type("ValueTableRow") Then
					AttributeName = SettingDetails.Attribute;
				Else
					AttributeName = SettingDetails.Key;
				EndIf;
				SettingValue = SettingDetails.Value;
				
				// Attribute availability
				If Not ReportParameters.AvailableAttributes.Property(AttributeName) Then
					Continue;
				EndIf;
				
				// Belonging to the mechanism of personalization.
				If PersonalizationAvailable AND SettingValue = "[Recipient]" Then
					// Register a personal filter field.
					ReportParameters.PersonalFilters.Insert(AttributeName);
				Else
					// Set value of report object attribute.
					ReportParameters.Object[AttributeName] = SettingValue;
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
	ReportParameters.Personalized = (ReportParameters.PersonalFilters.Count() > 0);
	ReportParameters.Initialized = True;
	
	Return True;
EndFunction

// Generates a report and checks that the result is empty.
//
// Parameters:
//   LogParameters - Structure - parameters of the writing to the event log. See LogRecord(). 
//   ReportParameters - Structure - See InitializeReport(), return value. 
//   Recipient - CatalogRef - a recipient reference.
//
// Returns:
//   Structure - report generation result.
//       * Spreadsheet - SpreadsheetDocument - a spreadsheet document.
//       * IsEmpty - Boolean - True if the report did not contain any parameters values.
//
Function GenerateReport(LogParameters, ReportParameters, Recipient = Undefined)
	Result = New Structure("SpreadsheetDoc, Generated, IsEmpty", New SpreadsheetDocument, False, True);
	
	If Not ReportParameters.Property("Initialized") Then
		LogRecord(LogParameters, ,
			StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Отчет ""%1"" не инициализирован'; en = 'Report ''%1'' is not initialized'; pl = 'Raport ''%1'' nie inicjalizuje się';es_ES = 'El informe ''%1'' no está iniciado';es_CO = 'El informe ''%1'' no está iniciado';tr = '''%1'' raporu başlatılmadı';it = 'Report ""%1"" non inizializzato';de = 'Der Bericht ''%1'' ist nicht initialisiert'"), String(ReportParameters.Report)));
		Return Result;
	EndIf;
	
	// Report connection settings.
	GenerationParameters = New Structure;
	
	// Fill personalized recipients data.
	If Recipient <> Undefined AND ReportParameters.Property("PersonalFilters") Then
		If ReportParameters.DCS Then
			DCUserSettings = ReportParameters.DCSettingsComposer.UserSettings;
			For Each KeyAndValue In ReportParameters.PersonalFilters Do
				Setting = DCUserSettings.GetObjectByID(KeyAndValue.Key);
				If TypeOf(Setting) = Type("DataCompositionFilterItem") Then
					Setting.RightValue = Recipient;
				ElsIf TypeOf(Setting) = Type("DataCompositionSettingsParameterValue") Then
					Setting.Value = Recipient;
				EndIf;
			EndDo;
			GenerationParameters.Insert("DCUserSettings", DCUserSettings);
		Else
			For Each KeyAndValue In ReportParameters.PersonalFilters Do
				ReportParameters.Object[KeyAndValue.Key] = Recipient;
			EndDo;
		EndIf;
	EndIf;
	
	GenerationParameters.Insert("Connection", ReportParameters);
	Generation = ReportsOptions.GenerateReport(GenerationParameters, True, Not ReportParameters.SendIfEmpty);
	
	If Not Generation.Success Then
		LogRecord(LogParameters, EventLogLevel.Error,
			StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Отчет ""%1"":'; en = 'Report ""%1"":'; pl = 'Raport ""%1"":';es_ES = 'Informe ""%1"":';es_CO = 'Informe ""%1"":';tr = 'Rapor ""%1"":';it = 'Report ""%1"":';de = 'Bericht ""%1"":'"),
			String(ReportParameters.Report)), Generation.ErrorText);
		Result.SpreadsheetDoc = Undefined;
		Return Result;
	EndIf;
	
	Result.Generated = True;
	Result.SpreadsheetDoc = Generation.SpreadsheetDocument;
	If ReportParameters.SendIfEmpty Then
		Result.IsEmpty = False;
	Else
		Result.IsEmpty = Generation.IsEmpty;
	EndIf;
	
	Return Result;
EndFunction

// Transports attachments for all delivery methods.
//
// Parameters:
//   Author - CatalogRef - a mailing author.
//   DeliveryParameters - Structure - see ExecuteMailing(). 
//   Attachments - Map - see AddReportsToAttachments(). 
//
// Returns:
//   Structure - a delivery result.
//       * Delivery - String - a delivery method presentation.
//       * Executed - Boolean - True if the delivery is executed at least by one of the methods.
//
Function ExecuteDelivery(LogParameters, DeliveryParameters, Attachments) Export
	Result = False;
	ErrorMessageTemplate = NStr("ru = 'Ошибка доставки отчетов'; en = 'Report delivery error'; pl = 'Błąd dostawy raportu';es_ES = 'Error en la entrega del informe';es_CO = 'Error en la entrega del informe';tr = 'Rapor teslimat hatası';it = 'Errore di invio report';de = 'Berichtzustellungsfehler'");
	TestMode = CommonClientServer.StructureProperty(DeliveryParameters, "TestMode", False);
	
	////////////////////////////////////////////////////////////////////////////
	// To network directory.
	
	If DeliveryParameters.UseNetworkDirectory Then
		
		ServerNetworkDdirectory = DeliveryParameters.NetworkDirectoryWindows;
		SystemInfo = New SystemInfo;
		ServerPlatformType = SystemInfo.PlatformType;		
		
		If ServerPlatformType = PlatformType.Linux_x86
			Or ServerPlatformType = PlatformType.Linux_x86_64 Then
			ServerNetworkDdirectory = DeliveryParameters.NetworkDirectoryLinux;
		EndIf;
		
		Try
			For Each Attachment In Attachments Do
				FileCopy(Attachment.Value, ServerNetworkDdirectory + Attachment.Key);
				If DeliveryParameters.AddReferences <> "" Then
					DeliveryParameters.RecipientReportsPresentation = StrReplace(
						DeliveryParameters.RecipientReportsPresentation,
						Attachment.Value,
						DeliveryParameters.NetworkDirectoryWindows + Attachment.Key);
				EndIf;
			EndDo;
			Result = True;
			DeliveryParameters.ExecutedToNetworkDirectory = True;
			
			If TestMode Then // Delete all created.
				For Each Attachment In Attachments Do
					DeleteFiles(ServerNetworkDdirectory + Attachment.Key);
				EndDo;
			EndIf;
		Except
			LogRecord(LogParameters, ,
				ErrorMessageTemplate, ErrorInfo());
		EndTry;
		
	EndIf;
	
	////////////////////////////////////////////////////////////////////////////
	// To FTP resource.
	
	If DeliveryParameters.UseFTPResource Then
		
		Destination = "ftp://"+ DeliveryParameters.Server +":"+ Format(DeliveryParameters.Port, "NZ=0; NG=0") + DeliveryParameters.Directory;
		
		Try
			If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
				ModuleNetworkDownload = Common.CommonModule("GetFilesFromInternet");
				Proxy = ModuleNetworkDownload.GetProxy("ftp");
			Else
				Proxy = Undefined;
			EndIf;
			If DeliveryParameters.Property("Password") Then
				Password = DeliveryParameters.Password;
			Else
				SetPrivilegedMode(True);
				DataFromStorage = Common.ReadDataFromSecureStorage(DeliveryParameters.Owner, "FTPPassword");
				SetPrivilegedMode(False);
				Password = ?(ValueIsFilled(DataFromStorage), DataFromStorage, "");
			EndIf;
			Connection = New FTPConnection(
				DeliveryParameters.Server,
				DeliveryParameters.Port,
				DeliveryParameters.Username,
				Password,
				Proxy,
				DeliveryParameters.PassiveConnection,
				15);
			Connection.SetCurrentDirectory(DeliveryParameters.Directory);
			For Each Attachment In Attachments Do
				Connection.Put(Attachment.Value, DeliveryParameters.Directory + Attachment.Key);
				If DeliveryParameters.AddReferences <> "" Then
					DeliveryParameters.RecipientReportsPresentation = StrReplace(
						DeliveryParameters.RecipientReportsPresentation,
						Attachment.Value,
						Destination + Attachment.Key);
				EndIf;
			EndDo;
			
			Result = True;
			DeliveryParameters.ExecutedAtFTP = True;
			
			If TestMode Then // Delete all created.
				For Each Attachment In Attachments Do
					Connection.Delete(DeliveryParameters.Directory + Attachment.Key);
				EndDo;
			EndIf;
		Except
			LogRecord(LogParameters, ,
				ErrorMessageTemplate, ErrorInfo());
		EndTry;
		
	EndIf;
	
	////////////////////////////////////////////////////////////////////////////
	// To folder.
	
	If DeliveryParameters.UseDirectory Then
		
		If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
			ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
			Try
				ModuleFilesOperationsInternal.OnExecuteDeliveryToFolder(DeliveryParameters, Attachments);
				Result = True;
				DeliveryParameters.ExecutedToFolder = True;
			Except
				LogRecord(LogParameters, ,
					ErrorMessageTemplate, ErrorInfo());
			EndTry;
		EndIf;
		
	EndIf;
	
	////////////////////////////////////////////////////////////////////////////
	// By email.
	
	If DeliveryParameters.UseEmail Then
		
		If DeliveryParameters.NotifyOnly Then
			ErrorMessageTemplate = NStr("ru = 'Невозможно отправить уведомление о рассылке по электронной почте:'; en = 'Cannot send bulk email notification by email:'; pl = 'Nie można wysłać masowej wysyłki e-mail:';es_ES = 'No se puede enviar la notificación de newsletter por correo electrónico:';es_CO = 'No se puede enviar la notificación de newsletter por correo electrónico:';tr = 'Toplu e-posta bildirimi e-posta ile gönderilemedi:';it = 'Impossibile inviare la notifica di invio massivo via email:';de = 'Kann keine Bulk-Mail-Warnung per E-Mail senden:'");
			EmailAttachments = New Map;
		Else
			ErrorMessageTemplate = NStr("ru = 'Невозможно отправить отчет по электронной почте:'; en = 'Cannot send report by email:'; pl = 'Nie można wysłać raportu przez e-mail:';es_ES = 'No puedo enviar el informe por correo electrónico:';es_CO = 'No puedo enviar el informe por correo electrónico:';tr = 'E-posta ile gönderilemedi:';it = 'Impossibile inviare il report per posta elettronica:';de = 'Kann keinen Bericht per E-Mail senden:'");
			EmailAttachments = Attachments;
		EndIf;
		
		Try
			SendReportsToRecipient(EmailAttachments, DeliveryParameters);
			If Not DeliveryParameters.NotifyOnly Then
				Result = True;
			EndIf;
			If Result = True Then
				DeliveryParameters.ExecutedByEmail = True;
			EndIf;
		Except
			LogRecord(LogParameters, ,
				ErrorMessageTemplate, ErrorInfo());
		EndTry;
		
	EndIf;
	
	Return Result;
EndFunction

// Gets a username by the Users catalog reference.
//
// Parameters:
//   User - CatalogRef.Users - a user reference.
//
// Returns:
//   String - a username.
//
Function IBUserName(User) Export
	If Not ValueIsFilled(User) Then
		Return Undefined;
	EndIf;
	
	SetPrivilegedMode(True);
	
	InfobaseUser = InfoBaseUsers.FindByUUID(
		Common.ObjectAttributeValue(User, "IBUserID"));
	If InfobaseUser = Undefined Then
		Return Undefined;
	EndIf;
	
	Return InfobaseUser.Name;
EndFunction

// Creates a record in the event log and in messages to a user.
//   Supports error information passing.
//
// Parameters:
//   LogParameters - Structure - parameters of the writing to the event log.
//       * EventName - String - an event name (or events group).
//       * Metadata - MetadataObject - metadata to link the event of the event log.
//       * Data - Arbitrary - data to link the event of the event log.
//       * ErrorsArray - user messages.
//   LogLevel - EventLogLevel - message importance for the administrator.
//       Determined automatically based on the ProblemDetails parameter type.
//       When type = ErrorInformation, then Error, when type = String, then Warning, otherwise 
//       Information.
//       
//   Text - String - brief details of the issue.
//   ProblemDetails - ErrorInformation, String - a problem description that is added after the text.
//       Errors brief presentation is output to the user, and an error detailed presentation is written in the log.
//
Procedure LogRecord(LogParameters, Val LogLevel = Undefined, Val Text = "", Val IssueDetails = Undefined) Export
	
	If LogParameters = Undefined Then
		Return;
	EndIf;
	
	// Determine the event log level based on the type of the passed error message.
	If TypeOf(LogLevel) <> Type("EventLogLevel") Then
		If TypeOf(IssueDetails) = Type("ErrorInfo") Then
			LogLevel = EventLogLevel.Error;
		ElsIf TypeOf(IssueDetails) = Type("String") Then
			LogLevel = EventLogLevel.Warning;
		Else
			LogLevel = EventLogLevel.Information;
		EndIf;
	EndIf;
	
	If LogLevel = EventLogLevel.Error Then
		LogParameters.Insert("HadErrors", True);
	ElsIf LogLevel = EventLogLevel.Warning Then
		LogParameters.Insert("HasWarnings", True);
	EndIf;
	
	WriteToLog = ValueIsFilled(LogParameters.Data);
	
	TextForLog      = Text;
	TextForUser = Text;
	If TypeOf(IssueDetails) = Type("ErrorInfo") Then
		If WriteToLog Then
			TextForLog = TextForLog + Chars.LF + DetailErrorDescription(IssueDetails);
		EndIf;	
		TextForUser = TextForUser + Chars.LF + BriefErrorDescription(IssueDetails);
	ElsIf TypeOf(IssueDetails) = Type("String") Then
		If WriteToLog Then
			TextForLog = TextForLog + Chars.LF + IssueDetails;
		EndIf;	
		TextForUser = TextForUser + Chars.LF + IssueDetails;
	EndIf;
	
	// The event log.
	If WriteToLog Then
		WriteLogEvent(LogParameters.EventName, LogLevel, LogParameters.Metadata, 
			LogParameters.Data, TrimAll(TextForLog));
	EndIf;
	
	// Message to a user.
	TextForUser = TrimAll(TextForUser);
	If (LogLevel = EventLogLevel.Error) Or (LogLevel = EventLogLevel.Warning) Then
		Message = New UserMessage;
		Message.Text = TextForUser;
		Message.SetData(LogParameters.Data);
		If LogParameters.Property("ErrorArray") Then
			LogParameters.ErrorArray.Add(Message);
		Else
			Message.Message();
		EndIf;
	EndIf;
	
EndProcedure

// Generates PermissionsArray according to report mailing data.
Function PermissionsToUseServerResources(BulkEmail) Export
	Permissions = New Array;
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	If BulkEmail.UseNetworkDirectory Then
		If ValueIsFilled(BulkEmail.NetworkDirectoryWindows) Then
			Item = ModuleSafeModeManager.PermissionToUseFileSystemDirectory(
				BulkEmail.NetworkDirectoryWindows,
				True,
				True,
				NStr("ru = 'Сетевой каталог для публикации отчетов с сервера Windows.'; en = 'Network directory for report publication from Windows server.'; pl = 'Katalog sieciowy do publikacji raportu z serwera Windows.';es_ES = 'Catálogo de la red para publicar informes desde el servidor de Windows.';es_CO = 'Catálogo de la red para publicar informes desde el servidor de Windows.';tr = 'Windows sunucusundan rapor yayımı için ağ dizini.';it = 'Directory di rete per la pubblicazione di report dal server Windows.';de = 'Netzwerkverzeichnis für Berichtveröffentlichung aus Windows-Server.'"));
			Permissions.Add(Item);
		EndIf;
		If ValueIsFilled(BulkEmail.NetworkDirectoryLinux) Then
			Item = ModuleSafeModeManager.PermissionToUseFileSystemDirectory(
				BulkEmail.NetworkDirectoryLinux,
				True,
				True,
				NStr("ru = 'Сетевой каталог для публикации отчетов с сервера Linux.'; en = 'Network directory for report publication from Linux server.'; pl = 'Katalog sieciowy do publikacji raportu z serwera Linux.';es_ES = 'Catálogo de la red para publicar informes desde el servidor de Linux.';es_CO = 'Catálogo de la red para publicar informes desde el servidor de Linux.';tr = 'Linux sunucusundan rapor yayımı için ağ dizini.';it = 'Directory di rete per la pubblicazione di report dal server Linux.';de = 'Netzwerkverzeichnis für Berichtveröffentlichung aus Linux-Server.'"));
			Permissions.Add(Item);
		EndIf;
	EndIf;
	If BulkEmail.UseFTPResource Then
		If ValueIsFilled(BulkEmail.FTPServer) Then
			Item = ModuleSafeModeManager.PermissionToUseInternetResource(
				"FTP",
				BulkEmail.FTPServer + BulkEmail.FTPDirectory,
				BulkEmail.FTPPort,
				NStr("ru = 'FTP ресурс для публикации отчетов.'; en = 'FTP resource for publishing reports.'; pl = 'Serwer FTP do publikowania raportów.';es_ES = 'Recurso FTP para publicar informes.';es_CO = 'Recurso FTP para publicar informes.';tr = 'Rapor yayımı için FTP kaynağı.';it = 'Risorsa FTP per la pubblicazione di report.';de = 'FTP-Ressource für Berichtsveröffentlichung.'"));
			Permissions.Add(Item);
		EndIf;
	EndIf;
	Return Permissions;
EndFunction

Function EventLogParameters(BulkEmail) Export
	Query = New Query;
	Query.Text =
	"SELECT
	|	States.LastRunStart,
	|	States.LastRunCompletion,
	|	States.SessionNumber
	|FROM
	|	InformationRegister.ReportMailingStates AS States
	|WHERE
	|	States.BulkEmail = &BulkEmail";
	Query.SetParameter("BulkEmail", BulkEmail);
	
	SetPrivilegedMode(True);
	Selection = Query.Execute().Select();
	If Not Selection.Next() Then
		Return Undefined;
	EndIf;
	Result = New Structure;
	Result.Insert("StartDate", Selection.LastRunStart);
	Result.Insert("EndDate", Selection.LastRunCompletion);
	// Interval is not more than 30 minutes because sessions numbers can be reused.
	If Not ValueIsFilled(Result.EndDate) Or Result.EndDate < Result.StartDate Then
		Result.EndDate = Result.StartDate + 30 * 60; 
	EndIf;
	If Not ValueIsFilled(Selection.SessionNumber) Then
		Result.Insert("Data", BulkEmail);
	Else
		Sessions = New ValueList;
		Sessions.Add(Selection.SessionNumber);
		Result.Insert("Session", Sessions);
	EndIf;
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

// In addition to generating reports, executes personalization on the list of recipients and 
//   generates reports broken down by recipients (if necessary).
//
// Parameters:
//   LogParameters - Structure - parameters of the writing to the event log.
//       * Prefix - String - prefix for the name of the event of the event log.
//       * Metadata - MetadataObject - metadata to write to the event log.
//       * Data - Arbitrary - metadata to write to the event log.
//   ReportParameters - Structure - see ExecuteMailing(), the ReportsTable parameter. 
//   ReportsTree - ValueTree - reports and result of formation.
//   DeliveryParameters - Structure - see ExecuteMailing(), the DeliveryParameters parameter. 
//   Recipient - CatalogRef - a recipient reference.
//
// Execution result is written in the ReportsTree.
// Errors are written to the log and messages of the user session.
//
Procedure GenerateAndSaveReport(LogParameters, ReportParameters, ReportsTree, DeliveryParameters, RecipientRef)
	
	// Determine the tree root string mapping to the recipient.
	// 1 - Recipients
	//   Key - a reference
	//   Value - a recipients directory.
	//   Settings - a generated reports presentation.
	RecipientRow = DefineTreeRowForRecipient(ReportsTree, RecipientRef, DeliveryParameters);
	RecipientsDirectory = RecipientRow.Value;
	
	// Generate a report for the recipient.
	Result = GenerateReport(LogParameters, ReportParameters, RecipientRef);
	
	// Check the result
	If Not Result.Generated Or (Result.IsEmpty AND Not ReportParameters.SendIfEmpty) Then
		Return;
	EndIf;
	
	// Register the intermediate result.
	// 2 - user spreadsheet documents.
	//   Key - a report name
	//   Value - a spreadsheet document.
	//   Settings - ............. all report parameters .............
	RowReport = RecipientRow.Rows.Add();
	RowReport.Level   = 2;
	RowReport.Key      = String(ReportParameters.Report);
	RowReport.Value  = Result.SpreadsheetDoc;
	RowReport.Settings = ReportParameters;
	
	ReportPresentation = TrimAll(RowReport.Key);// + "([ПредставлениеФорматов])";
	
	// Save a spreadsheet document in formats.
	FormatsPresentation = "";
	For Each Format In ReportParameters.Formats Do
		
		FormatParameters = DeliveryParameters.FormatsParameters.Get(Format);
		
		If FormatParameters = Undefined Then
			Continue;
		EndIf;
		
		FullFileName = RecipientsDirectory + FileName(
			RowReport.Key + " (" + FormatParameters.Name + ")"
			+ ?(FormatParameters.Extension = Undefined, "", FormatParameters.Extension), DeliveryParameters.TransliterateFileNames);
		
		FindFreeFileName(FullFileName);
		
		StandardProcessing = True;
		
		//  Extension mechanism
		ReportMailingOverridable.BeforeSaveSpreadsheetDocumentToFormat(
			StandardProcessing,
			RowReport.Value,
			Format,
			FullFileName);
		
		// Save a report by the built-in subsystem tools.
		If StandardProcessing = True Then
			ErrorTitle = NStr("ru = 'Ошибка записи отчета ""%1"" в формат ""%2"":'; en = 'An error occurred when writing the report ""%1"" to the ""%2"" format:'; pl = 'Wystąpił błąd podczas zapisywania raportu ""%1"" do ""%2"" formatu:';es_ES = 'Ha ocurrido un error al escribir el informe ""%1"" en el formato ""%2"":';es_CO = 'Ha ocurrido un error al escribir el informe ""%1"" en el formato ""%2"":';tr = '''''%1'''' raporunu ''''%2'''' biçimine yazarken bir hata oluştu.';it = 'Si è verificato un errore durante la trascrizione del report ""%1"" nel formato ""%2"":';de = 'Ein Fehler trat beim Schreiben des Berichts ""%1"" ins Format ""%2"" auf:'");
			
			If FormatParameters.FileType = Undefined Then
				LogRecord(LogParameters, EventLogLevel.Error,
					StringFunctionsClientServer.SubstituteParametersToString(ErrorTitle, RowReport.Key, FormatParameters.Name),
					NStr("ru = 'Формат не поддерживается'; en = 'Format is not supported'; pl = 'Format nie jest obsługiwany';es_ES = 'No se admite el formato';es_CO = 'No se admite el formato';tr = 'Biçim desteklenmiyor';it = 'Il formato non è supportato';de = 'Format ist nicht unterstützt'"));
				Continue;
			EndIf;
			
			DocumentResult = RowReport.Value; // SpreadsheetDocument
			
			Try
				DocumentResult.Write(FullFileName, FormatParameters.FileType);
			Except
				LogRecord(LogParameters, EventLogLevel.Error,
					StringFunctionsClientServer.SubstituteParametersToString(ErrorTitle, RowReport.Key, FormatParameters.Name),
					ErrorInfo());
				Continue;
			EndTry;
		EndIf;
		
		// Checks and result registration.
		TempFile = New File(FullFileName);
		If Not TempFile.Exist() Then
			LogRecord(LogParameters, EventLogLevel.Error,
				StringFunctionsClientServer.SubstituteParametersToString(ErrorTitle + Chars.LF + NStr("ru = 'Файл ""%3"" не существует.'; en = 'The file ""%3"" does not exist.'; pl = 'Plik ""%3"" nie istnieje.';es_ES = 'El archivo ""%3"" no existe.';es_CO = 'El archivo ""%3"" no existe.';tr = '""%3"" dosyası mevcut değil.';it = 'Il file ""%3"" non esiste.';de = 'Die Datei ""%3"" existiert nicht.'"),
				RowReport.Key, FormatParameters.Name, TempFile.FullName));
			Continue;
		EndIf;
		
		// Register the final result - the saved report in a temporary directory.
		// 3 - Recipients files
		//   Key - a file name
		//   Value - full path to the file.
		//   Settings - file settings.
		FileRow = RowReport.Rows.Add();
		FileRow.Level = 3;
		FileRow.Key      = TempFile.Name;
		FileRow.Value  = TempFile.FullName;
		
		FileRow.Settings = New Structure("FileWithDirectory, FileName, FullFileName, DirectoryName, FullDirectoryName, 
			|Format, Name, Extension, FileType, Ref");
		
		FileRow.Settings.Format = Format;
		FillPropertyValues(FileRow.Settings, FormatParameters, "Name, Extension, FileType");
		
		FileRow.Settings.FileName          = TempFile.Name;
		FileRow.Settings.FullFileName    = TempFile.FullName;
		FileRow.Settings.DirectoryName       = TempFile.BaseName + "_files";
		FileRow.Settings.FullDirectoryName = TempFile.Path + FileRow.Settings.DirectoryName + "\";
		
		FileDirectory = New File(FileRow.Settings.FullDirectoryName);
		
		FileRow.Settings.FileWithDirectory = (FileDirectory.Exist() AND FileDirectory.IsDirectory());
		
		If FileRow.Settings.FileWithDirectory AND Not DeliveryParameters.AddToArchive Then
			// Directory and the file are archived and an archive is sent instead of the file.
			ArchiveName       = TempFile.BaseName + ".zip";
			FullArchiveName = RecipientsDirectory + ArchiveName;
			
			SaveMode = ZIPStorePathMode.StoreRelativePath;
			ProcessingMode  = ZIPSubDirProcessingMode.ProcessRecursively;
			
			ZipFileWriter = New ZipFileWriter(FullArchiveName);
			ZipFileWriter.Add(FileRow.Settings.FullFileName,    SaveMode, ProcessingMode);
			ZipFileWriter.Add(FileRow.Settings.FullDirectoryName, SaveMode, ProcessingMode);
			ZipFileWriter.Write();
			
			FileRow.Key     = ArchiveName;
			FileRow.Value = FullArchiveName;
		EndIf;
		
		FileDirectory = Undefined;
		TempFile = Undefined;
		
		FormatsPresentation = FormatsPresentation 
			+ ?(FormatsPresentation = "", "", ", ") 
			// An opening tag for links (full paths to the files will be replaced with the links to files in the final storage).
			+ ?(DeliveryParameters.AddReferences = "ToFormats", "<a href = '"+ FileRow.Value +"'>", "")
			// format name
			+ FormatParameters.Name
			// end tag for links
			+ ?(DeliveryParameters.AddReferences = "ToFormats", "</a>", "");
			
		//
		If DeliveryParameters.AddReferences = "AfterReports" Then
			ReportPresentation = ReportPresentation + Chars.LF + "<" + FileRow.Value + ">";
		EndIf;
		
	EndDo;
	
	// Presentation of a specific report.
	ReportPresentation = StrReplace(ReportPresentation, "[FormatsPresentation]", FormatsPresentation);
	RowReport.Settings.Insert("PresentationInEmail", ReportPresentation);
	
EndProcedure

// Auxiliary procedure of the ExecuteMailing function fills default values for parameters that were 
//   not passed explicitly.
//   Also prepares and fills parameters required for mailing.
//
// Parameters and return value:
//   See ExecuteMailing(). 
//
Function CheckAndFillExecutionParameters(ValueTable, DeliveryParameters, MailingDescription, LogParameters)
	// Parameters of the writing to the event log.
	If TypeOf(LogParameters) <> Type("Structure") Then
		LogParameters = New Structure;
	EndIf;
	If Not LogParameters.Property("EventName") Then
		LogParameters.Insert("EventName", NStr("ru = 'Рассылка отчетов. Запуск по требованию'; en = 'Report bulk email. Start on demand'; pl = 'Masowa wysyłka raportów przez e-mail. Zacznij na żądanie';es_ES = 'Informe del newsletter. Iniciar a petición';es_CO = 'Informe del newsletter. Iniciar a petición';tr = 'Rapor toplu e-postası. Talep üzerine başlat';it = 'Invio massivo di report. Inizio su richiesta';de = 'Bulk-Mail-Bericht. Nach Anfrage starten'", CommonClientServer.DefaultLanguageCode()));
	EndIf;
	If Not LogParameters.Property("Data") Then
		LogParameters.Insert("Data", MailingDescription);
	EndIf;
	If Not LogParameters.Property("Metadata") Then
		LogParameters.Insert("Metadata", Undefined);
		DataType = TypeOf(LogParameters.Data);
		If DataType <> Type("Structure") AND Common.IsReference(DataType) Then
			LogParameters.Metadata = LogParameters.Data.Metadata();
		EndIf;
	EndIf;
	
	// Check access rights.
	If Not OutputRight(LogParameters) Then
		Return False;
	EndIf;
	
	ReportsAvailability = ReportsOptions.ReportsAvailability(ValueTable.UnloadColumn("Report"));
	Unavailable = ReportsAvailability.Copy(New Structure("Available", False));
	If Unavailable.Count() > 0 Then
		LogRecord(LogParameters, EventLogLevel.Error,
			StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'В рассылке есть недоступные отчеты (%1):%2'; en = 'There are unavailable reports in bulk email(%1):%2'; pl = 'Brak dostępnych raportów w masowej wysyłce e-mail(%1):%2';es_ES = 'No hay informes disponibles en el newsletter (%1): %2';es_CO = 'No hay informes disponibles en el newsletter (%1): %2';tr = 'Toplu e-postada kullanılamaz raporlar mevcut(%1):%2';it = 'Ci sono report non disponibili nell''invio massivo(%1):%2';de = 'Es gibt unerreichbare Berichte in Bulk Mail (%1): %2'"),
			Unavailable.Count(),
			Chars.LF + Chars.Tab + StrConcat(Unavailable.UnloadColumn("Presentation"), Chars.LF + Chars.Tab)));
		Return False;
	EndIf;
	
	DeliveryParameters.Insert("BulkEmail", TrimAll(String(MailingDescription)));
	DeliveryParameters.Insert("ExecutionDate", CurrentSessionDate());
	DeliveryParameters.Insert("HadErrors",                   False);
	DeliveryParameters.Insert("HasWarnings",           False);
	DeliveryParameters.Insert("ExecutedToFolder",              False);
	DeliveryParameters.Insert("ExecutedToNetworkDirectory",     False);
	DeliveryParameters.Insert("ExecutedAtFTP",               False);
	DeliveryParameters.Insert("ExecutedByEmail",  False);
	DeliveryParameters.Insert("ExecutedPublicationMethods", "");
	
	If DeliveryParameters.UseDirectory Then
		If Not ValueIsFilled(DeliveryParameters.Folder) Then
			DeliveryParameters.UseDirectory = False;
			LogRecord(LogParameters, EventLogLevel.Warning,
				NStr("ru = 'Папка не заполнена, доставка в папку отключена'; en = 'The folder is not filled in. Delivery to the folder is disabled'; pl = 'Folder nie jest wypełniony. Dostarczanie do folderu jest wyłączone';es_ES = 'La carpeta no está rellenada. La entrega a la carpeta está desactivada';es_CO = 'La carpeta no está rellenada. La entrega a la carpeta está desactivada';tr = 'Klasör doldurulmadı. Klasöre teslim devre dışı bırakıldı';it = 'La cartella non piena. Invio alla cartella è disattivato';de = 'Der Ordner ist nicht ausgefüllt. Zustellung in den Ordner ist deaktiviert'"));
		Else
			If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
				ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
				AccessRight = ModuleFilesOperationsInternal.RightToAddFilesToFolder(DeliveryParameters.Folder);
			Else
				AccessRight = True;
			EndIf;
			If Not AccessRight Then
				SetPrivilegedMode(True);
				FoldersPresentation = String(DeliveryParameters.Folder);
				SetPrivilegedMode(False);
				LogRecord(LogParameters, EventLogLevel.Error,
					StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Недостаточно прав для создания файлов в папке ""%1"".'; en = 'You are not authorized to create files in the ""%1"" folder.'; pl = 'Nie jesteś uprawniony do tworzenia plików ""%1"" w folderze.';es_ES = 'No está autorizado a crear archivos en la carpeta ""%1"".';es_CO = 'No está autorizado a crear archivos en la carpeta ""%1"".';tr = '''''%1'''' klasöründe dosya oluşturmak için yetkiniz yok.';it = 'Non hai autorizzazioni necessarie per creare file nella cartella ""%1"".';de = 'Sie sind zum Erstellen der Dateien im Ordner ""%1"" nicht autorisiert.'"),
					FoldersPresentation));
				Return False;
			EndIf;
		EndIf;
	EndIf;
	
	If DeliveryParameters.UseNetworkDirectory Then
		If Not ValueIsFilled(DeliveryParameters.NetworkDirectoryWindows) 
			Or Not ValueIsFilled(DeliveryParameters.NetworkDirectoryLinux) Then
			
			If ValueIsFilled(DeliveryParameters.NetworkDirectoryWindows) Then
				SubstitutionValue = NStr("ru = 'Linux'; en = 'Linux'; pl = 'Linux';es_ES = 'Linux';es_CO = 'Linux';tr = 'Linux';it = 'Linux';de = 'Linux'");
			ElsIf ValueIsFilled(DeliveryParameters.NetworkDirectoryLinux) Then
				SubstitutionValue = NStr("ru = 'Windows'; en = 'Windows'; pl = 'Windows';es_ES = 'Windows';es_CO = 'Windows';tr = 'Windows';it = 'Windows';de = 'Windows'");
			Else
				SubstitutionValue = NStr("ru = 'Windows и Linux'; en = 'Windows and Linux'; pl = 'Windows i Linux';es_ES = 'Windows y Linux';es_CO = 'Windows y Linux';tr = 'Windows ve Linux';it = 'Windows and Linux';de = 'Windows und Linux'");
			EndIf;
			
			DeliveryParameters.UseNetworkDirectory = False;
			LogRecord(LogParameters, EventLogLevel.Error,
				StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Сетевой каталог %1 не выбран, доставка в сетевой каталог отключена'; en = 'Network directory %1 is not selected, delivery into network directory is disabled'; pl = 'Katalog sieci %1 nie jest wybrany, dostawa do katalogu sieciowego jest wyłączona';es_ES = 'La carpeta de red %1no está seleccionada, la entrega en la carpeta de red está desactivada';es_CO = 'La carpeta de red %1no está seleccionada, la entrega en la carpeta de red está desactivada';tr = 'Ağ dizini %1 seçilmedi, ağ dizinine teslim devre dışı bırakıldı';it = 'Directory di rete %1non selezionata, consegna nelle directory di rete disattivata';de = 'Netzwerkverzeichnis %1 nicht ausgewählt, deaktivierte Zustellung in Netzwerkverzeichnis'"),
				SubstitutionValue));
			
		Else
			
			DeliveryParameters.NetworkDirectoryWindows = CommonClientServer.AddLastPathSeparator(
				DeliveryParameters.NetworkDirectoryWindows);
			DeliveryParameters.NetworkDirectoryLinux = CommonClientServer.AddLastPathSeparator(
				DeliveryParameters.NetworkDirectoryLinux);
			
		EndIf;
	EndIf;
	
	If DeliveryParameters.UseFTPResource AND Not ValueIsFilled(DeliveryParameters.Server) Then
		DeliveryParameters.UseFTPResource = False;
		LogRecord(LogParameters, EventLogLevel.Error,
			NStr("ru = 'FTP-сервер не заполнен, доставка в папку на FTP-ресурс отключена'; en = 'FTP server is not filled in, delivery to folder on FTP resource is disabled'; pl = 'Serwer FTP nie jest wypełniony, dostarczanie do folderu na zasobie FTP jest wyłączone';es_ES = 'El servidor FTP no está rellenado, la entrega a la carpeta en el recurso FTP está desactivada';es_CO = 'El servidor FTP no está rellenado, la entrega a la carpeta en el recurso FTP está desactivada';tr = 'FTP sunucusu girilmedi, FTP kaynağındaki klasöre teslim devre dışı bırakıldı';it = 'Il server FTP non è pieno, l''invio alla cartella sulla risorsa FTP è disattivato';de = 'Der FTP-Server ist nicht ausgefüllt. Zustellung in den Ordner der FTP-Ressource ist deaktiviert'"));
	EndIf;
	
	If DeliveryParameters.UseEmail AND Not ValueIsFilled(DeliveryParameters.Account) Then
		DeliveryParameters.UseEmail = False;
		LogRecord(LogParameters, EventLogLevel.Error,
			NStr("ru = 'Учетная запись не выбрана, доставка по электронной почте отключена'; en = 'No account is selected, email delivery is disabled'; pl = 'Nie wybrano konta, dostarczanie poczty e-mail jest wyłączone';es_ES = 'No se ha seleccionado ninguna cuenta, el envío de correo electrónico está desactivado';es_CO = 'No se ha seleccionado ninguna cuenta, el envío de correo electrónico está desactivado';tr = 'Hiçbir hesap seçilmedi, e-posta teslimi devre dışı bırakıldı';it = 'Nessun account selezionato, invio via email è disattivato';de = 'Kein Account ist gewählt, E-Mail-Zusendung ist deaktiviert'"));
	EndIf;
	
	If Not DeliveryParameters.Property("Personalized") Then
		DeliveryParameters.Insert("Personalized", False);
	EndIf;
	
	If DeliveryParameters.Personalized Then
		If Not DeliveryParameters.UseEmail Then
			LogRecord(LogParameters, EventLogLevel.Error,
				NStr("ru = 'Персонализированная рассылка может быть отправлена только по электронной почте'; en = 'Personalized bulk email can be sent only by email'; pl = 'Spersonalizowaną masową wysyłkę e-mail można wysłać tylko przez pocztę elektroniczną';es_ES = 'El newsletter personalizado sólo puede ser enviado por correo electrónico';es_CO = 'El newsletter personalizado sólo puede ser enviado por correo electrónico';tr = 'Kişiselleştirilmiş toplu e-posta yalnızca e-posta ile gönderilebilir';it = 'Invio massivo personalizzato può essere eseguito solo via email';de = 'Personalisierte Bulk Mail kann nur per E-Mail gesendet werden'"));
			Return False;
		EndIf;
		
		DeliveryParameters.UseDirectory          = False;
		DeliveryParameters.UseNetworkDirectory = False;
		DeliveryParameters.UseFTPResource      = False;
		DeliveryParameters.Insert("NotifyOnly", False);
	EndIf;
	
	If DeliveryParameters.UseEmail Then
		// Connection to a mail server rises the longest.
		If Not DeliveryParameters.Property("Connection") Then
			DeliveryParameters.Insert("Connection", Undefined);
		EndIf;
		
		//  Email delivery notification.
		If Not DeliveryParameters.Property("NotifyOnly") Then
			DeliveryParameters.Insert("NotifyOnly", False);
		EndIf;
		
		If DeliveryParameters.NotifyOnly
			AND Not DeliveryParameters.UseDirectory
			AND Not DeliveryParameters.UseNetworkDirectory
			AND Not DeliveryParameters.UseFTPResource Then
			LogRecord(LogParameters, EventLogLevel.Warning,
				NStr("ru = 'Использование уведомлений по электронной почте возможно только совместно с другими способами доставки'; en = 'Use of email notifications is available only with other delivery methods'; pl = 'Korzystanie z powiadomień e-mail jest możliwe tylko w przypadku innych metod dostawy';es_ES = 'El uso de notificaciones por correo electrónico sólo está disponible con otros métodos de entrega';es_CO = 'El uso de notificaciones por correo electrónico sólo está disponible con otros métodos de entrega';tr = 'E-posta bildirim kullanımı yalnızca diğer teslimat yöntemleri için kullanılabilir';it = 'Uso di notifiche via email è disponibile solo in combinazione con altri metodi di invio';de = 'Anwendung von E-Mail-Warnungen ist nur mit der anderen Zustellungsmethode möglich'"));
			Return False;
		EndIf;
		
		// Email parameters.
		If Not DeliveryParameters.Property("BCC") Then
			DeliveryParameters.Insert("BCC", False);
		EndIf;
		If Not DeliveryParameters.Property("EmailParameters") Then
			DeliveryParameters.Insert("EmailParameters", New Structure);
		EndIf;
		
		EmailParameters = DeliveryParameters.EmailParameters;
		
		EmailParameters.Insert("ProcessTexts", False);
		
		// Internet mail text type.
		If Not EmailParameters.Property("TextType") Or Not ValueIsFilled(EmailParameters.TextType) Then
			EmailParameters.Insert("TextType", InternetMailTextType.PlainText);
		EndIf;
		
		DeliveryParameters.Insert("HTMLFormatEmail", EmailParameters.TextType = "HTML" Or EmailParameters.TextType = InternetMailTextType.HTML);
		
		// For backward compatibility.
		If EmailParameters.Property("Attachments") Then
			EmailParameters.Insert("Pictures", EmailParameters.Attachments);
		EndIf;
		
		// Subjects template
		If Not DeliveryParameters.Property("SubjectTemplate") Or Not ValueIsFilled(DeliveryParameters.SubjectTemplate) Then
			DeliveryParameters.Insert("SubjectTemplate", SubjectTemplate());
		EndIf;
		
		// Message template
		If Not DeliveryParameters.Property("TextTemplate") Or Not ValueIsFilled(DeliveryParameters.TextTemplate) Then
			DeliveryParameters.Insert("TextTemplate", TextTemplate());
			If DeliveryParameters.HTMLFormatEmail Then
				Document = New FormattedDocument;
				Document.Add(DeliveryParameters.TextTemplate, FormattedDocumentItemType.Text);
				Document.GetHTML(DeliveryParameters.TextTemplate, New Structure);
			EndIf;
		EndIf;
		
		// Delete unnecessary style elements.
		If DeliveryParameters.HTMLFormatEmail Then
			StyleLeft = StrFind(DeliveryParameters.TextTemplate, "<style");
			StyleRight = StrFind(DeliveryParameters.TextTemplate, "</style>");
			If StyleLeft > 0 AND StyleRight > StyleLeft Then
				DeliveryParameters.TextTemplate = Left(DeliveryParameters.TextTemplate, StyleLeft - 1) + Mid(DeliveryParameters.TextTemplate, StyleRight + 8);
			EndIf;
		EndIf;
		
		// Value content for the substitution.
		TemplateFillingStructure = New Structure("BulkEmailDescription, Author, SystemTitle, ExecutionDate");
		TemplateFillingStructure.BulkEmailDescription = DeliveryParameters.BulkEmail;
		TemplateFillingStructure.Author                = DeliveryParameters.Author;
		TemplateFillingStructure.SystemTitle     = ThisInfobaseName();
		TemplateFillingStructure.ExecutionDate       = DeliveryParameters.ExecutionDate;
		If Not DeliveryParameters.Personalized Then
			TemplateFillingStructure.Insert("Recipient", "");
		EndIf;
		
		// Subjects template
		DeliveryParameters.SubjectTemplate = ReportsDistributionClientServer.FillTemplate(
			DeliveryParameters.SubjectTemplate, 
			TemplateFillingStructure);
		
		// Message template
		DeliveryParameters.TextTemplate = ReportsDistributionClientServer.FillTemplate(
			DeliveryParameters.TextTemplate,
			TemplateFillingStructure);
		
		// Flags that show whether it is necessary to fill in the templates (checks cache).
		DeliveryParameters.Insert(
			"FillRecipientInSubjectTemplate",
			StrFind(DeliveryParameters.SubjectTemplate, "[Recipient]") <> 0);
		DeliveryParameters.Insert(
			"ЗаполнитьПолучателяВШаблонеСообщения",
			StrFind(DeliveryParameters.TextTemplate, "[Recipient]") <> 0);
		DeliveryParameters.Insert(
			"FillGeneratedReportsInMessageTemplate",
			StrFind(DeliveryParameters.TextTemplate, "[GeneratedReports]") <> 0);
		DeliveryParameters.Insert(
			"FillDeliveryMethodInMessageTemplate",
			StrFind(DeliveryParameters.TextTemplate, "[DeliveryMethod]") <> 0);
		
		// Reports presentation.
		DeliveryParameters.Insert("RecipientReportsPresentation", "");
	EndIf;
	
	// Temporary file directory.
	DeliveryParameters.Insert("TempFilesDirectory", Common.CreateTemporaryDirectory("RP"));
	
	// Recipients temporary files directory mapping.
	DeliveryParameters.Insert("RecipientsSettings", New Map);
	
	// Archive settings: checkbox and password.
	If Not DeliveryParameters.Property("AddToArchive") Then
		DeliveryParameters.Insert("AddToArchive", False);
		DeliveryParameters.Insert("ArchivePassword", "");
	ElsIf Not DeliveryParameters.Property("ArchivePassword") Then
		DeliveryParameters.Insert("ArchivePassword", "");
	EndIf;
	
	// Archive name (delete forbidden characters, fill a template) and extension.
	If DeliveryParameters.AddToArchive Then
		If Not DeliveryParameters.Property("ArchiveName") Or Not ValueIsFilled(DeliveryParameters.ArchiveName) Then
			DeliveryParameters.Insert("ArchiveName", ArchivePatternName());
		EndIf;
		Structure = New Structure("BulkEmailDescription, ExecutionDate", DeliveryParameters.BulkEmail, CurrentSessionDate());
		ArchiveName = ReportsDistributionClientServer.FillTemplate(DeliveryParameters.ArchiveName, Structure);
		DeliveryParameters.ArchiveName = FileName(ArchiveName, DeliveryParameters.TransliterateFileNames);
		If Lower(Right(DeliveryParameters.ArchiveName, 4)) <> ".zip" Then
			DeliveryParameters.ArchiveName = DeliveryParameters.ArchiveName +".zip";
		EndIf;
	EndIf;
	
	// Formats parameters.
	DeliveryParameters.Insert("FormatsParameters", New Map);
	For Each MetadataFormat In Metadata.Enums.ReportSaveFormats.EnumValues Do
		Format = Enums.ReportSaveFormats[MetadataFormat.Name];
		FormatParameters = WriteSpreadsheetDocumentToFormatParameters(Format);
		FormatParameters.Insert("Name", MetadataFormat.Name);
		DeliveryParameters.FormatsParameters.Insert(Format, FormatParameters);
	EndDo;
	
	// File name transliteration parameters.
	If Not DeliveryParameters.Property("TransliterateFileNames") Then
		DeliveryParameters.Insert("TransliterateFileNames", False);
	EndIf;
	
	// Parameters for adding links to the final files to the message.
	DeliveryParameters.Insert("AddReferences", "");
	If DeliveryParameters.UseEmail 
		AND (DeliveryParameters.UseDirectory
			Or DeliveryParameters.UseNetworkDirectory
			Or DeliveryParameters.UseFTPResource)
		AND DeliveryParameters.FillGeneratedReportsInMessageTemplate Then
		
		If DeliveryParameters.AddToArchive Then
			DeliveryParameters.AddReferences = "ToArchive";
		ElsIf DeliveryParameters.HTMLFormatEmail Then
			DeliveryParameters.AddReferences = "ToFormats";
		Else
			DeliveryParameters.AddReferences = "AfterReports";
		EndIf;
	EndIf;
	
	Return True;
EndFunction

// Returns the default subject template for delivery by email.
Function SubjectTemplate() Export
	Return NStr("ru = '[BulkEmailDescription] от [ExecutionDate(DLF=''D'')]'; en = '[BulkEmailDescription] from [ExecutionDate(DLF=''D'')]'; pl = '[BulkEmailDescription] z [ExecutionDate(DLF=''D'')]';es_ES = '[BulkEmailDescription] desde [ExecutionDate(DLF=''D'')]';es_CO = '[BulkEmailDescription] desde [ExecutionDate(DLF=''D'')]';tr = '[ExecutionDate(DLF=''D'')] ''dan [BulkEmailDescription]';it = '[BulkEmailDescription] from [ExecutionDate(DLF=''D'')]';de = '[BulkEmailDescription] aus [ExecutionDate(DLF=''D'')]'");
EndFunction

// Returns the default body template for delivery by email.
Function TextTemplate() Export
	Return NStr(
		"ru = 'Сформированы отчеты:
		|
		|[GeneratedReports]
		|
		|[DeliveryMethod]
		|
		|[SystemTitle]
		|[ExecutionDate(DLF=''DD'')]'; 
		|en = 'The following reports were generated:
		|
		|[GeneratedReports]
		|
		|[DeliveryMethod]
		|
		|[SystemTitle]
		|[ExecutionDate(DLF=''DD'')]'; 
		|pl = 'Zostały wygenerowane następujące raporty:
		|
		|[GeneratedReports]
		|
		|[DeliveryMethod]
		|
		|[SystemTitle]
		|[ExecutionDate(DLF=''DD'')]';
		|es_ES = 'Se han generado los siguientes informes:
		|
		|[GeneratedReports]
		|
		|[DeliveryMethod]
		|
		|[SystemTitle]
		|[ExecutionDate(DLF=''DD'')]';
		|es_CO = 'Se han generado los siguientes informes:
		|
		|[GeneratedReports]
		|
		|[DeliveryMethod]
		|
		|[SystemTitle]
		|[ExecutionDate(DLF=''DD'')]';
		|tr = 'Bu raporlar düzenlendi: 
		|
		|[GeneratedReports]
		|
		|[DeliveryMethod]
		|
		|[SystemTitle]
		|[ExecutionDate(DLF=''DD'')]';
		|it = 'Sono stati generati i seguenti report:
		|
		|[GeneratedReports]
		|
		|[DeliveryMethod]
		|
		|[SystemTitle]
		|[ExecutionDate(DLF=''DD'')]';
		|de = 'Die folgenden Berichte sind generiert:
		|
		|[GeneratedReports]
		|
		|[DeliveryMethod]
		|
		|[SystemTitle]
		|[ExecutionDate(DLF=''DD'')]'");
EndFunction

// Returns the default archive description template.
Function ArchivePatternName() Export
	// For date format localization is not required.
	Return NStr("ru = '[BulkEmailDescription]_[ExecutionDate(DF=''dd.MM.yyyy'')]'; en = '[BulkEmailDescription]_[ExecutionDate(DF=''MM/dd/yyyy'')]'; pl = '[BulkEmailDescription]_[ExecutionDate(DF=''yyyy-MM-dd'')]';es_ES = '[BulkEmailDescription]_[ExecutionDate(DF=''dd/MM/yyyy'')]';es_CO = '[BulkEmailDescription]_[ExecutionDate(DF=''dd/MM/yyyy'')]';tr = '[BulkEmailDescription]_[ExecutionDate(DF=''dd.MM.yyyy'')]';it = '[BulkEmailDescription]_[ExecutionDate(DF=''MM/dd/yyyy'')]';de = '[BulkEmailDescription]_[ExecutionDate(DF=''dd.MM.yyyy'')]'");
EndFunction

// Generates the mailing list from the recipients list, prepares all email parameters and passes 
//   control to the EmailOperations subsystem.
//   To monitor the fulfillment, it is recommended to call in construction the Attempt... Exception.
//
// Parameters:
//   Attachments - Map - see SaveReportsToFormats(), the Result parameter. 
//   DeliveryParameters - Structure - see ExecuteMailing(), the DeliveryParameters parameter. 
//   RowRecipient - recipient settings:
//       - Undefined - whole recipients list from the DeliveryParameters.Recipients is used.
//       - ValueTreeRow - the Recipient row property is used.
//
Procedure SendReportsToRecipient(Attachments, DeliveryParameters, RecipientRow = Undefined)
	Recipient = ?(RecipientRow = Undefined, Undefined, RecipientRow.Key);
	EmailParameters = DeliveryParameters.EmailParameters;
	
	// Attachments - reports
	EmailParameters.Insert("Attachments", ConvertToMap(Attachments, "Key", "Value"));
	
	// Subject and body templates
	SubjectTemplate = DeliveryParameters.SubjectTemplate;
	TextTemplate = DeliveryParameters.TextTemplate;
	
	// Insert generated reports into the message template.
	If DeliveryParameters.FillGeneratedReportsInMessageTemplate Then
		If DeliveryParameters.HTMLFormatEmail Then
			DeliveryParameters.RecipientReportsPresentation = StrReplace(
				DeliveryParameters.RecipientReportsPresentation,
				Chars.LF,
				Chars.LF + "<br>");
		EndIf;
		TextTemplate = StrReplace(TextTemplate, "[GeneratedReports]", DeliveryParameters.RecipientReportsPresentation);
	EndIf;
	
	// Delivery method is filled earlier (outside this procedure).
	If DeliveryParameters.FillDeliveryMethodInMessageTemplate Then
		TextTemplate = StrReplace(TextTemplate, "[DeliveryMethod]", ReportsDistributionClientServer.DeliveryMethodsPresentation(DeliveryParameters));
	EndIf;
	
	// Subject and body of the message
	EmailParameters.Insert("Subject", SubjectTemplate);
	EmailParameters.Insert("Body", TextTemplate);
	
	// Subject and body of the message
	DeliveryAddressKey = ?(DeliveryParameters.BCC, "BCC", "SendTo");
	
	If Recipient = Undefined Then
		If DeliveryParameters.Recipients.Count() = 0 Then
			Return;
		EndIf;
		
		// Deliver to all recipients
		If DeliveryParameters.FillRecipientInSubjectTemplate Or DeliveryParameters.ЗаполнитьПолучателяВШаблонеСообщения Then
			// Templates are personalized - delivery to each recipient.
			Emails = New Array;
			For Each KeyAndValue In DeliveryParameters.Recipients Do
				// Subject and body of the message
				If DeliveryParameters.FillRecipientInSubjectTemplate Then
					EmailParameters.Subject = StrReplace(SubjectTemplate, "[Recipient]", String(KeyAndValue.Key));
				EndIf;
				If DeliveryParameters.ЗаполнитьПолучателяВШаблонеСообщения Then
					EmailParameters.Body = StrReplace(TextTemplate, "[Recipient]", String(KeyAndValue.Key));
				EndIf;
				
				// Recipient
				EmailParameters.Insert(DeliveryAddressKey, KeyAndValue.Value);
				
				// Sending email
				Emails.Add(PrepareEmail(DeliveryParameters, EmailParameters));
			EndDo;
			EmailOperations.SendEmails(DeliveryParameters.Account, Emails);
		Else
			// Templates are not personalized - glue recipients email addresses and joint delivery.
			SendTo = "";
			For Each KeyAndValue In DeliveryParameters.Recipients Do
				SendTo = SendTo + ?(SendTo = "", "", ", ") + KeyAndValue.Value;
			EndDo;
			
			EmailParameters.Insert(DeliveryAddressKey, SendTo);
			
			// Sending email
			SendEmailMessage(DeliveryParameters, EmailParameters);
		EndIf;
	Else
		// Deliver to a specific recipient.
		
		// Subject and body of the message
		If DeliveryParameters.FillRecipientInSubjectTemplate Then
			EmailParameters.Subject = StrReplace(SubjectTemplate, "[Recipient]", String(Recipient));
		EndIf;
		If DeliveryParameters.ЗаполнитьПолучателяВШаблонеСообщения Then
			EmailParameters.Body = StrReplace(TextTemplate, "[Recipient]", String(Recipient));
		EndIf;
		
		// Recipient
		EmailParameters.Insert(DeliveryAddressKey, DeliveryParameters.Recipients[Recipient]);
		
		// Sending email
		SendEmailMessage(DeliveryParameters, EmailParameters);
	EndIf;
	
EndProcedure

Procedure SendEmailMessage(DeliveryParameters, EmailParameters)
	
	Email = PrepareEmail(DeliveryParameters, EmailParameters);
	EmailOperations.SendEmail(DeliveryParameters.Account, Email);
	
EndProcedure
	
Function PrepareEmail(DeliveryParameters, EmailParameters)
	
	If EmailParameters.Property("Pictures")
		AND EmailParameters.Pictures <> Undefined
		AND EmailParameters.Pictures.Count() > 0 Then
		FormattedDocument = New FormattedDocument;
		FormattedDocument.SetHTML(EmailParameters.Body, EmailParameters.Pictures);
		EmailParameters.Body = FormattedDocument;
	EndIf;
	
	Return EmailOperations.PrepareEmail(DeliveryParameters.Account, EmailParameters);
	
EndFunction

// Converts the collection to mapping.
Function ConvertToMap(Collection, KeyName, ValueName)
	If TypeOf(Collection) = Type("Map") Then
		Return New Map(New FixedMap(Collection));
	EndIf;
	Result = New Map;
	For Each Item In Collection Do
		Result.Insert(Item[KeyName], Item[ValueName]);
	EndDo;
	Return Result;
EndFunction

// Combines arrays and returns the result of the union.
Function CombineArrays(Array1, Array2)
	Array = New Array;
	For Each ArrayElement In Array1 Do
		Array.Add(ArrayElement);
	EndDo;
	For Each ArrayElement In Array2 Do
		Array.Add(ArrayElement);
	EndDo;
	Return Array;
EndFunction

// Executes archiving of attachments in accordance with the delivery parameters.
//
// Parameters:
//   Attachments - Map, ValueTreeRow - see CreateReportsTree(), return value, level 3. 
//   DeliveryParameters - Structure - see ExecuteMailing(), the DeliveryParameters parameter. 
//   TempFilesDir - String - a directory for archiving.
//
Procedure ArchiveAttachments(Attachments, DeliveryParameters, TempFilesDirectory)
	If Not DeliveryParameters.AddToArchive Then
		Return;
	EndIf;
	
	// Directory and file are archived and the file name is changed to the archive name.
	FullFileName = TempFilesDirectory + DeliveryParameters.ArchiveName;
	
	SaveMode = ZIPStorePathMode.StoreRelativePath;
	ProcessingMode  = ZIPSubDirProcessingMode.ProcessRecursively;
	
	ZipFileWriter = New ZipFileWriter(FullFileName, DeliveryParameters.ArchivePassword);
	
	For Each Attachment In Attachments Do
		ZipFileWriter.Add(Attachment.Value, SaveMode, ProcessingMode);
		If Attachment.Settings.FileWithDirectory = True Then
			ZipFileWriter.Add(Attachment.Settings.FullDirectoryName, SaveMode, ProcessingMode);
		EndIf;
	EndDo;
	
	ZipFileWriter.Write();
	
	Attachments = New Map;
	Attachments.Insert(DeliveryParameters.ArchiveName, FullFileName);
	
	If DeliveryParameters.UseEmail Then
		If DeliveryParameters.FillGeneratedReportsInMessageTemplate Then
			DeliveryParameters.RecipientReportsPresentation = 
				DeliveryParameters.RecipientReportsPresentation 
				+ Chars.LF 
				+ Chars.LF
				+ NStr("ru = 'Файлы отчетов запакованы в архив'; en = 'Report files are archived'; pl = 'Pliki raportów zostały archiwizowane';es_ES = 'Los archivos del informe se han archivado';es_CO = 'Los archivos del informe se han archivado';tr = 'Rapor dosyaları arşivlendi';it = 'File dei report archiviati';de = 'Berichtsdateien sind archiviert'")
				+ " ";
		EndIf;
		
		If DeliveryParameters.AddReferences = "ToArchive" Then
			// Delivery method involves links adding.
			If DeliveryParameters.HTMLFormatEmail Then
				DeliveryParameters.RecipientReportsPresentation = TrimAll(
					DeliveryParameters.RecipientReportsPresentation
					+"<a href = '"+ FullFileName +"'>"+ DeliveryParameters.ArchiveName +"</a>");
			Else
				DeliveryParameters.RecipientReportsPresentation = TrimAll(
					DeliveryParameters.RecipientReportsPresentation
					+""""+ DeliveryParameters.ArchiveName +""":"+ Chars.LF +"<"+ FullFileName +">");
			EndIf;
		ElsIf DeliveryParameters.FillGeneratedReportsInMessageTemplate Then
			// Delivery by mail only
			DeliveryParameters.RecipientReportsPresentation = TrimAll(
				DeliveryParameters.RecipientReportsPresentation
				+""""+ DeliveryParameters.ArchiveName +"""");
		EndIf;
		
	EndIf;
	
EndProcedure

// Parameters for saving a spreadsheet document in format.
//
// Parameters:
//   Format - EnumRef.ReportSaveFormats - a format for which you need to get the parameters.
//
// Returns:
//   Structure - Result - Structure - Parameters for writing. 
//       * Extension - String - extension with which you can save the file.
//       * FileType - SpreadsheetDocumentFileType - a spreadsheet document save format.
//           This procedure is used to define the SpreadsheetFileType parameter of the SpreadsheetDocument.Write method.
//
Function WriteSpreadsheetDocumentToFormatParameters(Format)
	Result = New Structure("Extension, FileType");
	If Format = Enums.ReportSaveFormats.XLSX Then
		Result.Extension = ".xlsx";
		Result.FileType = SpreadsheetDocumentFileType.XLSX;
		
	ElsIf Format = Enums.ReportSaveFormats.XLS Then
		Result.Extension = ".xls";
		Result.FileType = SpreadsheetDocumentFileType.XLS;
		
	ElsIf Format = Enums.ReportSaveFormats.ODS Then
		Result.Extension = ".ods";
		Result.FileType = SpreadsheetDocumentFileType.ODS;
		
	ElsIf Format = Enums.ReportSaveFormats.MXL Then
		Result.Extension = ".mxl";
		Result.FileType = SpreadsheetDocumentFileType.MXL;
		
	ElsIf Format = Enums.ReportSaveFormats.PDF Then
		Result.Extension = ".pdf";
		Result.FileType = SpreadsheetDocumentFileType.PDF;
		
	ElsIf Format = Enums.ReportSaveFormats.HTML Then
		Result.Extension = ".html";
		Result.FileType = SpreadsheetDocumentFileType.HTML;
		
	ElsIf Format = Enums.ReportSaveFormats.HTML4 Then
		Result.Extension = ".html";
		Result.FileType = SpreadsheetDocumentFileType.HTML4;
		
	ElsIf Format = Enums.ReportSaveFormats.DOCX Then
		Result.Extension = ".docx";
		Result.FileType = SpreadsheetDocumentFileType.DOCX;
		
	ElsIf Format = Enums.ReportSaveFormats.TXT Then
		Result.Extension = ".txt";
		Result.FileType = SpreadsheetDocumentFileType.TXT;
	
	ElsIf Format = Enums.ReportSaveFormats.ANSITXT Then
		Result.Extension = ".txt";
		Result.FileType = SpreadsheetDocumentFileType.ANSITXT;
		
	Else 
		// Pattern for all formats added during the deployment the saving handler of which has to be in the 
		// overridable module.
		Result.Extension = Undefined;
		Result.FileType = Undefined;
		
	EndIf;
	
	Return Result;
EndFunction

// Converts invalid file characters to similar valid characters.
//   Operates only with the file name, the path is not supported.
//
// Parameters:
//   InitialFileName - String - a file name from which you have to remove invalid characters.
//
// Returns:
//   String - Result - String - Conversion result.
//
Function FileName(InitialFileName, TranslitFilesNames)
	
	Result = Left(TrimAll(InitialFileName), 255);
	
	ReplacementsMap = New Map;
	
	// Standard unsupported characters.
	ReplacementsMap.Insert("""", "'");
	ReplacementsMap.Insert("/", "_");
	ReplacementsMap.Insert("\", "_");
	ReplacementsMap.Insert(":", "_");
	ReplacementsMap.Insert(";", "_");
	ReplacementsMap.Insert("|", "_");
	ReplacementsMap.Insert("=", "_");
	ReplacementsMap.Insert("?", "_");
	ReplacementsMap.Insert("*", "_");
	ReplacementsMap.Insert("<", "_");
	ReplacementsMap.Insert(">", "_");
	
	// Characters not supported by the obsolete OS.
	ReplacementsMap.Insert("[", "");
	ReplacementsMap.Insert("]", "");
	ReplacementsMap.Insert(",", "");
	ReplacementsMap.Insert("{", "");
	ReplacementsMap.Insert("}", "");
	
	For Each KeyAndValue In ReplacementsMap Do
		Result = StrReplace(Result, KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	
	If TranslitFilesNames Then
		Result = StringFunctionsClientServer.LatinString(Result);
	EndIf;
	
	Return Result;
EndFunction

// Value tree required for generating and delivering reports.
Function CreateReportsTree()
	// Tree structure by nesting levels:
	//
	// 1 - Recipients:
	//   Key - a reference.
	//   Value - a recipients directory.
	//
	// 2 - Recipients spreadsheet documents:
	//   Key - a report name.
	//   Value - a spreadsheet document.
	//   Settings - all report parameters...
	//
	// 3 - Recipients files:
	//   Key - a file name.
	//   Value - full path to the file.
	//   Settings - FileWithDirectory, FileName, FullFileName, DirectoryName, FullDirectoryName, Format, Name, Extension, FileType.
	
	ReportsTree = New ValueTree;
	ReportsTree.Columns.Add("Level", New TypeDescription("Number"));
	ReportsTree.Columns.Add("Key");
	ReportsTree.Columns.Add("Value");
	ReportsTree.Columns.Add("Settings", New TypeDescription("Structure"));
	
	Return ReportsTree;
EndFunction

// Checks the current users right to output information. If there are no rights - an event log record is created.
//
// Parameters:
//   LogParameters - Structure -
// 
// Returns:
//   Boolean:
//
Function OutputRight(LogParameters)
	OutputRight = AccessRight("Output", Metadata);
	If Not OutputRight Then
		LogRecord(LogParameters, EventLogLevel.Error,
			StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'У пользователя ""%1"" недостаточно прав на вывод информации'; en = 'The user ""%1"" does not possess enough rights to display information'; pl = 'Użytkownik ""%1"" nie ma wystarczających uprawnień do wyświetlania informacji';es_ES = 'El usuario ""%1"" no dispone de suficientes derechos para mostrar la información';es_CO = 'El usuario ""%1"" no dispone de suficientes derechos para mostrar la información';tr = '''''%1'''' kullanıcısı bilgi görüntülemek için yeterli haklara sahip değil';it = 'L''utente ""%1"" non dispone di autorizzazioni necessarie per visualizzare le informazioni';de = 'Der Benutzer ""%1"" hat unzureichende Rechte auf Anzeigen der Informationen'"),
			Users.CurrentUser()));
	EndIf;
	Return OutputRight;
EndFunction

// Converts an array of messages to a user in one string.
Function MessagesToUserString(Errors = Undefined, SeeEventLog = True) Export
	If Errors = Undefined Then
		Errors = GetUserMessages(True);
	EndIf;
	
	Indent = Chars.LF + Chars.LF;
	
	AllErrors = "";
	For Each Error In Errors Do
		AllErrors = TrimAll(AllErrors + Indent + ?(TypeOf(Error) = Type("String"), Error, Error.Text));
	EndDo;
	If AllErrors <> "" AND SeeEventLog Then
		AllErrors = AllErrors + Indent + "---" + Indent + NStr("ru = 'Подробности см. в журнале регистрации.'; en = 'See the event log for details.'; pl = 'Szczegóły w Dzienniku wydarzeń';es_ES = 'Ver detalles en el registro.';es_CO = 'Ver detalles en el registro.';tr = 'Ayrıntılar için olay günlüğüne bakın.';it = 'Guarda il registro eventi per dettagli.';de = 'Siehe Details im Protokoll.'");
	EndIf;
	
	Return AllErrors;
EndFunction

// If the file exists - adds a suffix to the file name.
//
// Parameters:
//   FullFileName - String - a file name to start a search.
//
Procedure FindFreeFileName(FullFileName)
	File = New File(FullFileName);
	
	If Not File.Exist() Then
		Return;
	EndIf;
	
	// Set a file names template to substitute various suffixes.
	NameTemplate = "";
	NameLength = StrLen(FullFileName);
	SlashCode = CharCode("/");
	BackSlashCode = CharCode("\");
	PointCode = CharCode(".");
	For ReverseIndex = 1 To NameLength Do
		Index = NameLength - ReverseIndex + 1;
		Code = CharCode(FullFileName, Index);
		If Code = PointCode Then
			NameTemplate = Left(FullFileName, Index - 1) + "<template>" + Mid(FullFileName, Index);
			Break;
		ElsIf Code = SlashCode Or Code = BackSlashCode Then
			Break;
		EndIf;
	EndDo;
	If NameTemplate = "" Then
		NameTemplate = FullFileName + "<template>";
	EndIf;
	
	Index = 0;
	While File.Exist() Do
		Index = Index + 1;
		FullFileName = StrReplace(NameTemplate, "<template>", " ("+ Format(Index, "NG=") +")");
		File = New File(FullFileName);
	EndDo;
EndProcedure

// Creates the tree root row for the recipient (if it is absent) and fills it with default parameters.
//
// Parameters:
//   ReportsTree - ValueTree - see CreateReportsTree(), return value, level 1. 
//   RecipientRef - CatalogRef, Undefined - a recipient reference.
//   DeliveryParameters - Structure - see ExecuteMailing(), the DeliveryParameters parameter. 
//
// Returns:
//   ValueTreeRow - see CreateReportsTree(), return value, level 1. 
//
Function DefineTreeRowForRecipient(ReportsTree, RecipientRef, DeliveryParameters)
	
	RecipientRow = ReportsTree.Rows.Find(RecipientRef, "Key", False);
	If RecipientRow = Undefined Then
		
		RecipientsDirectory = DeliveryParameters.TempFilesDirectory;
		If RecipientRef <> Undefined Then
			RecipientsDirectory = RecipientsDirectory 
				+ FileName(String(RecipientRef), DeliveryParameters.TransliterateFileNames)
				+ " (" + String(RecipientRef.UUID()) + ")\";
			CreateDirectory(RecipientsDirectory);
		EndIf;
		
		RecipientRow = ReportsTree.Rows.Add();
		RecipientRow.Level  = 1;
		RecipientRow.Key     = RecipientRef;
		RecipientRow.Value = RecipientsDirectory;
		
	EndIf;
	
	Return RecipientRow;
	
EndFunction

// Generates reports presentation for recipients.
Procedure GenerateReportPresentationsForRecipient(DeliveryParameters, RecipientRow)
	
	GeneratedReports = "";
	
	If DeliveryParameters.UseEmail AND DeliveryParameters.FillGeneratedReportsInMessageTemplate Then
		
		Separator = Chars.LF;
		If DeliveryParameters.AddReferences = "AfterReports" Then
			Separator = Separator + Chars.LF;
		EndIf;
		
		Index = 0;
		
		For Each RowReport In DeliveryParameters.GeneralReportsRow.Rows Do
			Index = Index + 1;
			GeneratedReports = GeneratedReports 
			+ Separator 
			+ Format(Index, "NG=") 
			+ ". " 
			+ RowReport.Settings.PresentationInEmail;
		EndDo;
		
		If RecipientRow <> Undefined AND RecipientRow <> DeliveryParameters.GeneralReportsRow Then
			For Each RowReport In RecipientRow.Rows Do
				Index = Index + 1;
				GeneratedReports = GeneratedReports 
				+ Separator 
				+ Format(Index, "NG=") 
				+ ". " 
				+ RowReport.Settings.PresentationInEmail;
			EndDo;
		EndIf;
		
	EndIf;
	
	DeliveryParameters.Insert("RecipientReportsPresentation", TrimAll(GeneratedReports));
	
EndProcedure

// Checks if there are external data sets.
//
// Parameters:
//   DataSets - DataCompositionTemplateDataSets - a collection of data sets to be checked.
//
// Returns:
//   Boolean - True if there are external data sets.
//
Function ThereIsExternalDataSet(DataSets)
	
	For Each DataSet In DataSets Do
		
		If TypeOf(DataSet) = Type("DataCompositionTemplateDataSetObject") Then
			
			Return True;
			
		ElsIf TypeOf(DataSet) = Type("DataCompositionTemplateDataSetUnion") Then
			
			If ThereIsExternalDataSet(DataSet.Items) Then
				
				Return True;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

Function MailingsWithReportsNumber(ReportOption)
	
	If Not ValueIsFilled(ReportOption) Or TypeOf(ReportOption) <> Type("CatalogRef.ReportsOptions") 
		Or ReportOption.IsEmpty() Then
		Return 0;
	EndIf;
	
	Query = New Query(
		"SELECT ALLOWED
		|	COUNT(DISTINCT Reports.Ref) AS Count
		|FROM
		|	Catalog.ReportMailings.Reports AS Reports
		|WHERE
		|	Reports.Report = &ReportOption");
		
	Query.SetParameter("ReportOption", ReportOption);
	Return Query.Execute().Unload()[0].Count;
	
EndFunction	

// Checks rights and generates error text.
Function CheckAddRightErrorText() Export
	If Not AccessRight("Output", Metadata) Then
		Return NStr("ru = 'Нет прав на вывод информации.'; en = 'You have no rights to display information.'; pl = 'Nie masz uprawnień do wyświetlania informacji.';es_ES = 'No tiene ningún derecho para mostrar información.';es_CO = 'No tiene ningún derecho para mostrar información.';tr = 'Bilgi görüntüleme yetkisine sahip değilsiniz.';it = 'Non hai autorizzazioni necessarie per visualizzare le informazioni.';de = 'Sie haben keine Rechte auf Anzeigen der Informationen.'");
	EndIf;
	If Not AccessRight("Update", Metadata.Catalogs.ReportMailings) Then
		Return NStr("ru = 'Нет прав на рассылки отчетов.'; en = 'You have no rights to mail reports.'; pl = 'Nie masz uprawnień do raportów e-mail.';es_ES = 'No tiene ningún derecho para enviar informes por correo.';es_CO = 'No tiene ningún derecho para enviar informes por correo.';tr = 'Rapor gönderme yetkisine sahip değilsiniz.';it = 'Non hai autorizzazioni necessarie per inviare i report.';de = 'Sie haben keine Rechte auf Senden der Berichte.'");
	EndIf;
	If Not EmailOperations.CanSendEmails() Then
		Return NStr("ru = 'Нет прав на отправку писем или нет доступных учетных записей.'; en = 'You have no rights to send emails or there are no available accounts.'; pl = 'Nie masz uprawnień do wysyłania wiadomości e-mail lub nie ma dostępnych kont.';es_ES = 'No tiene ningún derecho para enviar correos electrónicos o no tiene cuentas disponibles.';es_CO = 'No tiene ningún derecho para enviar correos electrónicos o no tiene cuentas disponibles.';tr = 'E-posta gönderme yetkisine sahip değilsiniz veya kullanılabilir hesap mevcut değil.';it = 'Non hai autorizzazioni necessarie per inviare email o non ci sono account disponibili.';de = 'Sie haben keine Rechte auf Senden der Berichte oder es gibt keine erreichbaren Accounts.'");
	EndIf;
	Return "";
EndFunction

// Returns a value list of the ReportSaveFormats enumeration.
//
// Returns:
//   FormatsList - ValueList - a list of formats with marks on the system default formats where:
//       * Value - EnumRef.ReportSaveFormats - a reference to the described format.
//       * Presentation - String - user presentation of the described format.
//       * CheckMark - Boolean - a flag of usage as a default format.
//       * Picture      - Picture - a picture of the format.
//
Function FormatsList() Export
	FormatsList = New ValueList;
	
	SetFormatsParameters(FormatsList, "HTML4", PictureLib.HTMLFormat, True);
	SetFormatsParameters(FormatsList, "PDF"  , PictureLib.PDFFormat);
	SetFormatsParameters(FormatsList, "XLSX" , PictureLib.Excel2007Format);
	SetFormatsParameters(FormatsList, "XLS"  , PictureLib.ExcelFormat);
	SetFormatsParameters(FormatsList, "ODS"  , PictureLib.OpenOfficeCalcFormat);
	SetFormatsParameters(FormatsList, "MXL"  , PictureLib.MXLFormat);
	SetFormatsParameters(FormatsList, "DOCX" , PictureLib.Word2007Format);
	SetFormatsParameters(FormatsList, "TXT"    , PictureLib.TXTFormat);
	SetFormatsParameters(FormatsList, "ANSITXT", PictureLib.TXTFormat);
	
	ReportMailingOverridable.OverrideFormatsParameters(FormatsList);
	
	// Remaining formats
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Formats.Ref
	|FROM
	|	Enum.ReportSaveFormats AS Formats
	|WHERE
	|	(NOT Formats.Ref IN (&FormatArray))";
	Query.SetParameter("FormatArray", FormatsList.UnloadValues());
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		SetFormatsParameters(FormatsList, Selection.Ref);
	EndDo;
	
	Return FormatsList;
EndFunction

// Gets an empty value for the search in the Reports or ReportFormats table of the ReportsMailing catalog.
//
// Returns:
//   - CatalogRef.AdditionalReportsAndDataProcessors -
//   - CatalogRef.ReportsOptions -
//
Function EmptyReportValue() Export
	SetPrivilegedMode(True);
	Return Metadata.Catalogs.ReportMailings.TabularSections.ReportFormats.Attributes.Report.Type.AdjustValue();
EndFunction

// Gets the application header, and if it is not specified, a synonym for configuration metadata.
Function ThisInfobaseName() Export
	
	SetPrivilegedMode(True);
	Result = Constants.SystemTitle.Get();
	Return ?(IsBlankString(Result), Metadata.Synonym, Result);
	
EndFunction

Procedure DisableBulkEmailBeforeBulkEmailRecipientsTypeDeletion(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ReportMailings.Ref AS Ref
		|FROM
		|	Catalog.ReportMailings AS ReportMailings
		|WHERE
		|	ReportMailings.MailingRecipientType = &MailingRecipientType";
	Query.SetParameter("MailingRecipientType", Source.Ref);
	Records = Query.Execute().Select();
	While Records.Next() Do
		BulkEmailObject = Records.Ref.GetObject();
		If BulkEmailObject = Undefined Then
			Continue;
		EndIf;
		BulkEmailObject.MailingRecipientType = Catalogs.MetadataObjectIDs.EmptyRef();
		BulkEmailObject.Prepared = False;
		InfobaseUpdate.WriteData(BulkEmailObject);
	EndDo;

EndProcedure

#EndRegion
