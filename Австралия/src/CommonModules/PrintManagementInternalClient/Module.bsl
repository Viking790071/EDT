#Region Internal

// The attached command handler.
//
// Parameters
//   RefsArrray - Array - an array of selected object references, for which the command is running.
//   ExecutionParameters - Structure - a command context.
//       * CommandDetails - Structure - information about the running command.
//          ** ID - String - a command ID.
//          ** Presentation - String - a command presentation on a form.
//          ** Name - String - a command name on a form.
//       * Form - ClientApplicationForm - a form the command is called from.
//       * Source - FormDataStructure, FormTable - an object or a form list with the Reference field.
//
Procedure CommandHandler(Val RefsArray, Val ExecutionParameters) Export
	ExecutionParameters.Insert("PrintObjects", RefsArray);
	CommonClientServer.SupplementStructure(ExecutionParameters.CommandDetails, ExecutionParameters.CommandDetails.AdditionalParameters, True);
	RunAttachablePrintCommandCompletion(True, ExecutionParameters);
EndProcedure

// Generates a spreadsheet document in the Print subsystem form.
Procedure ExecutePrintFormOpening(DataSource, CommandID, RelatedObjects, Form, StandardProcessing) Export
	
	Parameters = New Structure;
	Parameters.Insert("Form",                Form);
	Parameters.Insert("DataSource",       DataSource);
	Parameters.Insert("CommandID", CommandID);
	If StandardProcessing Then
		NotifyDescription = New NotifyDescription("ExecutePrintFormOpeningCompletion", ThisObject, Parameters);
		PrintManagementClient.CheckDocumentsPosting(NotifyDescription, RelatedObjects, Form);
	Else
		ExecutePrintFormOpeningCompletion(RelatedObjects, Parameters);
	EndIf;
	
EndProcedure

// Opens a form for command visibility setting in the Print submenu.
Procedure OpenPrintSubmenuSettingsForm(Filter) Export
	OpeningParameters = New Structure;
	OpeningParameters.Insert("Filter", Filter);
	OpenForm("CommonForm.PrintCommandsSetup", OpeningParameters, , , , , , FormWindowOpeningMode.LockOwnerWindow);
EndProcedure

// Opening a form to select attachment format options
//
// Parameters:
//  FormatSettings - Structure - settings description
//       * PackToArchive   - Boolean - shows whether it is necessary to archive attachments.
//       * SaveFormats - Array - a list of selected save formats.
//  Notification - NotifyDescription - a notification called after closing the form for processing 
//                                          the selection result.
//
Procedure OpenAttachmentsFormatSelectionForm(FormatSettings, Notification) Export
	FormParameters = New Structure("FormatSettings", FormatSettings);
	OpenForm("CommonForm.SelectAttachmentFormat", FormParameters,,,,, Notification, FormWindowOpeningMode.LockOwnerWindow);
EndProcedure

#EndRegion

#Region Private

// Continues the PrintManagerClient.RunAttachablePrintCommand procedure.
Procedure RunAttachablePrintCommandCompletion(FileSystemExtensionAttached, AdditionalParameters)
	
	If Not FileSystemExtensionAttached Then
		Return;
	EndIf;
	
	CommandDetails = AdditionalParameters.CommandDetails;
	Form = AdditionalParameters.Form;
	PrintObjects = AdditionalParameters.PrintObjects;
	
	CommandDetails = CommonClientServer.CopyStructure(CommandDetails);
	CommandDetails.Insert("PrintObjects", PrintObjects);
	
	If CommonClient.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitorClient = CommonClient.CommonModule("PerformanceMonitorClient");
		
		IndicatorName = NStr("ru = 'Печать'; en = 'Print'; pl = 'Drukuj';es_ES = 'Impresión';es_CO = 'Impresión';tr = 'Yazdır';it = 'Stampa';de = 'Drucken'") + StringFunctionsClientServer.SubstituteParametersToString("/%1/%2/%3/%4/%5/%6/%7",
			CommandDetails.ID,
			CommandDetails.PrintManager,
			CommandDetails.Handler,
			Format(CommandDetails.PrintObjects.Count(), "NG=0"),
			?(CommandDetails.SkipPreview, "Printer", ""),
			CommandDetails.SaveFormat,
			?(CommandDetails.FixedSet, "Fixed", ""));
		
		ModulePerformanceMonitorClient.StartTechologicalTimeMeasurement(True, Lower(IndicatorName));
	EndIf;
	
	If CommandDetails.PrintManager = "StandardSubsystems.AdditionalReportsAndDataProcessors" 
		AND CommonClient.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
			ModuleAdditionalReportsAndDataProcessorsClient = CommonClient.CommonModule("AdditionalReportsAndDataProcessorsClient");
			ModuleAdditionalReportsAndDataProcessorsClient.ExecuteAssignedPrintCommand(CommandDetails, Form);
			Return;
	EndIf;
	
	If Not IsBlankString(CommandDetails.Handler) Then
		CommandDetails.Insert("Form", Form);
		HandlerName = CommandDetails.Handler;
		If StrOccurrenceCount(HandlerName, ".") = 0 AND IsReportOrDataProcessor(CommandDetails.PrintManager) Then
			DefaultForm = GetForm(CommandDetails.PrintManager + ".Form", , Form, True);
			HandlerName = "DefaultForm." + HandlerName;
		EndIf;
		Handler = HandlerName + "(CommandDetails)";
		Result = Eval(Handler);
		Return;
	EndIf;
	
	If CommandDetails.SkipPreview Then
		PrintManagementClient.ExecutePrintToPrinterCommand(CommandDetails.PrintManager, CommandDetails.ID,
			PrintObjects, CommandDetails.AdditionalParameters);
	Else
		PrintManagementClient.ExecutePrintCommand(CommandDetails.PrintManager, CommandDetails.ID,
			PrintObjects, Form, CommandDetails);
	EndIf;
	
EndProcedure

// Continues execution of the PrintManagerClient.CheckDocumentsPosted procedure.
Procedure CheckDocumentsPostedPostingDialog(Parameters) Export
	
	If PrintManagementServerCall.HasRightToPost(Parameters.UnpostedDocuments) Then
		If Parameters.UnpostedDocuments.Count() = 1 Then
			QuestionText = NStr("ru = 'Для того чтобы распечатать документ, его необходимо предварительно провести. Выполнить проведение документа и продолжить?'; en = 'To print the document, post it first. Post the document and continue?'; pl = 'Aby wydrukować dokument, najpierw go zaksięguj. Zaksięgować dokument i kontynuować?';es_ES = 'Para imprimir el documento, enviarlo primero. ¿Enviar el documento y continuar?';es_CO = 'Para imprimir el documento, enviarlo primero. ¿Enviar el documento y continuar?';tr = 'Belgeyi yazdırmak için önce onaylayın. Belgeyi onayla ve devam et?';it = 'Per stampare il documento, è necessario prima eseguirlo. Vuoi continuare con il documento?';de = 'Um das Dokument zu drucken, buchen Sie es zuerst. Das Dokument buchen und fortfahren?'");
		Else
			QuestionText = NStr("ru = 'Для того чтобы распечатать документы, их необходимо предварительно провести. Выполнить проведение документов и продолжить?'; en = 'To print documents, post them first. Post the documents and continue?'; pl = 'Aby wydrukować dokumenty, należy je najpierw zaksięgować. Zaksięgować dokumenty i kontynuować?';es_ES = 'Para imprimir los documentos, se requiere enviarlos primero. ¿Enviar los documentos y continuar?';es_CO = 'Para imprimir los documentos, se requiere enviarlos primero. ¿Enviar los documentos y continuar?';tr = 'Belgeyi yazdırmak için onu önce onaylamak gerekir. Belgeyi onayla ve devam et?';it = 'Per stampare i documenti, prima pubblicateli. Volete pubblicarli e continuare?';de = 'Um Dokumente zu drucken, buchen Sie diese zuerst. Dokumente buchen und fortfahren?'");
		EndIf;
	Else
		If Parameters.UnpostedDocuments.Count() = 1 Then
			WarningText = NStr("ru = 'Для того чтобы распечатать документ, его необходимо предварительно провести. Недостаточно прав для проведения документа, печать невозможна.'; en = 'To print the document, post it first. Insufficient rights to post the document, cannot print.'; pl = 'Aby wydrukować dokument, najpierw go zaksięguj. Niewystarczające uprawnienia do księgowania dokumentu, drukowanie nie jest możliwe.';es_ES = 'Para imprimir el documento, enviarlo primero. Insuficientes derechos para enviar el documento, no se puede imprimir.';es_CO = 'Para imprimir el documento, enviarlo primero. Insuficientes derechos para enviar el documento, no se puede imprimir.';tr = 'Belgeyi yazdırmak için onu önce onaylayın. Belgeyi göndermek için yetersiz haklar, yazdırılamıyor.';it = 'Per stampare il documento, è necessario prima eseguirlo. Diritti insufficienti per l''esecuzione del documento, la stampa non è possibile.';de = 'Um das Dokument zu drucken, buchen Sie es zuerst. Unzureichende Rechte zum Buchen des Dokuments, Fehler beim Drucken.'");
		Else
			WarningText = NStr("ru = 'Для того чтобы распечатать документы, их необходимо предварительно провести. Недостаточно прав для проведения документов, печать невозможна.'; en = 'To print the documents, post them first. Insufficient rights to post the documents, cannot print.'; pl = 'Aby wydrukować dokumenty, najpierw je zaksięguj. Niewystarczające uprawnienia do księgowania dokumentów, drukowanie nie jest możliwe.';es_ES = 'Para imprimir los documentos, enviarlo primero. Insuficientes derechos para enviar los documentos, no se puede imprimir.';es_CO = 'Para imprimir los documentos, enviarlo primero. Insuficientes derechos para enviar los documentos, no se puede imprimir.';tr = 'Belgeleri yazdırmak için onları önce onaylayın. Belgeleri göndermek için yetersiz haklar, yazdırılamıyor.';it = 'Per stampare i documenti, devono prima essere eseguiti. Diritti insufficienti per l''esecuzione di documenti, la stampa non è possibile.';de = 'Um die Dokumente zu drucken, buchen Sie sie zuerst. Unzureichende Rechte zum Buchen der Dokumente, Fehler beim Drucken.'");
		EndIf;
		ShowMessageBox(, WarningText);
		Return;
	EndIf;
	NotifyDescription = New NotifyDescription("CheckDocumentsPostedDocumentsPosting", ThisObject, Parameters);
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
	
EndProcedure

// Continues execution of the PrintManagerClient.CheckDocumentsPosted procedure.
Procedure CheckDocumentsPostedDocumentsPosting(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ClearMessages();
	UnpostedDocumentsData = CommonServerCall.PostDocuments(AdditionalParameters.UnpostedDocuments);
	
	MessageTemplate = NStr("ru = 'Документ %1 не проведен: %2'; en = 'Document %1 is not posted: %2'; pl = 'Dokument %1 nie został zaksięgowany: %2';es_ES = 'Documento %1 no está enviado: %2';es_CO = 'Documento %1 no está enviado: %2';tr = '%1 belgesi kaydedilmedi: %2';it = 'Il documento %1 non è pubblicato: %2';de = 'Dokument %1 ist nicht gebucht: %2'");
	UnpostedDocuments = New Array;
	For Each DocumentInformation In UnpostedDocumentsData Do
		CommonClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, String(DocumentInformation.Ref), DocumentInformation.ErrorDescription),
			DocumentInformation.Ref);
		UnpostedDocuments.Add(DocumentInformation.Ref);
	EndDo;
	PostedDocuments = CommonClientServer.ArraysDifference(AdditionalParameters.DocumentsList, UnpostedDocuments);
	ModifiedDocuments = CommonClientServer.ArraysDifference(AdditionalParameters.UnpostedDocuments, UnpostedDocuments);
	
	AdditionalParameters.Insert("UnpostedDocuments", UnpostedDocuments);
	AdditionalParameters.Insert("PostedDocuments", PostedDocuments);
	
	CommonClient.NotifyObjectsChanged(ModifiedDocuments);
	
	// If the command is called from a form, read the up-to-date (posted) copy from the infobase.
	If TypeOf(AdditionalParameters.Form) = Type("ClientApplicationForm") Then
		Try
			AdditionalParameters.Form.Read();
		Except
			// If the Read method is unavailable, printing was executed from a location other than the object form.
		EndTry;
	EndIf;
		
	If UnpostedDocuments.Count() > 0 Then
		// Asking a user whether they want to continue printing if there are unposted documents.
		DialogText = NStr("ru = 'Не удалось провести один или несколько документов.'; en = 'Cannot post one or several documents.'; pl = 'Nie można dekretować jednego lub kilku dokumentów.';es_ES = 'No se puede enviar uno o varios documentos.';es_CO = 'No se puede enviar uno o varios documentos.';tr = 'Bir veya birkaç belge onaylanmaz.';it = 'Non è possibile inviare uno o più documenti.';de = 'Ein oder mehrere Dokumente können nicht gebucht werden.'");
		
		DialogButtons = New ValueList;
		If PostedDocuments.Count() > 0 Then
			DialogText = DialogText + " " + NStr("ru = 'Продолжить?'; en = 'Continue?'; pl = 'Kontynuować?';es_ES = '¿Continuar?';es_CO = '¿Continuar?';tr = 'Devam et?';it = 'Continuare?';de = 'Fortsetzen?'");
			DialogButtons.Add(DialogReturnCode.Ignore, NStr("ru = 'Продолжить'; en = 'Continue'; pl = 'Kontynuuj';es_ES = 'Continuar';es_CO = 'Continuar';tr = 'Devam';it = 'Continua';de = 'Weiter'"));
			DialogButtons.Add(DialogReturnCode.Cancel);
		Else
			DialogButtons.Add(DialogReturnCode.OK);
		EndIf;
		
		NotifyDescription = New NotifyDescription("CheckDocumentsPostedCompletion", ThisObject, AdditionalParameters);
		ShowQueryBox(NotifyDescription, DialogText, DialogButtons);
		Return;
	EndIf;
	
	CheckDocumentsPostedCompletion(Undefined, AdditionalParameters);
	
EndProcedure

// Continues execution of the PrintManagerClient.CheckDocumentsPosted procedure.
Procedure CheckDocumentsPostedCompletion(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult <> Undefined AND QuestionResult <> DialogReturnCode.Ignore Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(AdditionalParameters.CompletionProcedureDetails, AdditionalParameters.PostedDocuments);
	
EndProcedure

// Checks if a print manager is a report or a data processor.
Function IsReportOrDataProcessor(PrintManager)
	If Not ValueIsFilled(PrintManager) Then
		Return False;
	EndIf;
	SubstringsArray = StrSplit(PrintManager, ".");
	If SubstringsArray.Count() = 0 Then
		Return False;
	EndIf;
	Kind = Upper(TrimAll(SubstringsArray[0]));
	Return Kind = "REPORT" Or Kind = "DATAPROCESSOR";
EndFunction

// Continues execution of the ExecutePrintFormOpening procedure.
Procedure ExecutePrintFormOpeningCompletion(RelatedObjects, AdditionalParameters) Export
	
	Form = AdditionalParameters.Form;
	
	SourceParameters = New Structure;
	SourceParameters.Insert("CommandID", AdditionalParameters.CommandID);
	SourceParameters.Insert("RelatedObjects",    RelatedObjects);
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("DataSource",     AdditionalParameters.DataSource);
	OpeningParameters.Insert("SourceParameters", SourceParameters);
	OpeningParameters.Insert("CommandParameter", RelatedObjects);
	
	OpenForm("CommonForm.PrintDocuments", OpeningParameters, Form);
	
EndProcedure

// Synchronous analog of CommonClient.CreateTempDirectory for backward compatibility.
//
Function CreateTemporaryDirectory(Val Extension = "") Export 
	
	DirectoryName = TempFilesDir() + "v8_" + String(New UUID);
	If Not IsBlankString(Extension) Then 
		DirectoryName = DirectoryName + "." + Extension;
	EndIf;
	CreateDirectory(DirectoryName);
	Return DirectoryName;
	
EndFunction

#EndRegion
