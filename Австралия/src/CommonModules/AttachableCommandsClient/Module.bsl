#Region Public

// Form command handler.
//
// Parameters:
//   Form - ClientApplicationForm - a form, from which the command is executed.
//   Command - FormCommand - a running command.
//   Source - FormTable, FormDataStructure - an object or a form list with the Reference field.
//
Procedure StartCommandExecution(Form, Command, Source) Export
	CommandName = Command.Name;
	SettingsAddress = Form.AttachableCommandsParameters.CommandsTableAddress;
	CommandDetails = AttachableCommandsClientCached.CommandDetails(CommandName, SettingsAddress);
	
	Context = AttachableCommandsClientServer.CommandExecutionParametersTemplate();
	Context.CommandDetails = New Structure(CommandDetails);
	Context.Form           = Form;
	Context.Source        = Source;
	Context.IsObjectForm = TypeOf(Source) = Type("FormDataStructure");
	
	Context.Insert("WritingRequired", Context.IsObjectForm AND CommandDetails.WriteMode <> "DoNotWrite");
	Context.Insert("PostingRequired", CommandDetails.WriteMode = "Post");
	Context.Insert("FilesOperationsRequired", CommandDetails.FilesOperationsRequired);
	Context.Insert("CallServerThroughNotificationProcessing");
	
	ContinueCommandExecution(Context);
EndProcedure

// Form command handler.
//
// Parameters:
//   Form - ClientApplicationForm - a form, from which the command isexecuted.
//   Command - FormCommand - a running command.
//   Source - FormTable, FormDataStructure - an object or a form list with the Reference field.
//
Procedure ExecuteCommand(Form, Command, Source) Export
	CommandName = Command.Name;
	SettingsAddress = Form.AttachableCommandsParameters.CommandsTableAddress;
	CommandDetails = AttachableCommandsClientCached.CommandDetails(CommandName, SettingsAddress);
	
	Context = AttachableCommandsClientServer.CommandExecutionParametersTemplate();
	Context.CommandDetails = New Structure(CommandDetails);
	Context.Form           = Form;
	Context.Source        = Source;
	Context.IsObjectForm = TypeOf(Source) = Type("FormDataStructure");
	Context.Insert("RefGettingRequired", True);
	Context.Insert("WritingRequired", Context.IsObjectForm AND CommandDetails.WriteMode <> "DoNotWrite");
	Context.Insert("PostingRequired", CommandDetails.WriteMode = "Post");
	Context.Insert("FilesOperationsRequired", CommandDetails.FilesOperationsRequired);
	
	ContinueCommandExecution(Context);
EndProcedure

// Starts a deferred process of updating print commands on the form.
//
// Parameters:
//  Form - ClientApplicationForm - a form that requires update of print commands.
//
Procedure StartCommandUpdate(Form) Export
	Form.DetachIdleHandler("Attachable_UpdateCommands");
	Form.AttachIdleHandler("Attachable_UpdateCommands", 0.2, True);
EndProcedure

#EndRegion

#Region Private

// Executes the command attached to the form.
Procedure ContinueCommandExecution(Context)
	Source = Context.Source;
	CommandDetails = Context.CommandDetails;
	
	// Installing file system extension.
	If Context.FilesOperationsRequired Then
		Context.FilesOperationsRequired = False;
		Handler = New NotifyDescription("ContinueExecutionCommandAfterSetFileExtension", ThisObject, Context);
		MessageText = NStr("ru = 'Для продолжения необходимо установить расширение для веб-клиента 1С:Предприятие.'; en = 'Install the 1C:Enterprise web client file system extension to continue'; pl = 'Aby kontynuować pracę, należy zainstalować rozszerzenie dla klienta usługi 1C:Enterprise';es_ES = 'Para continuar es necesario instalar la extensión para el cliente web de 1C:Enterprise.';es_CO = 'Para continuar es necesario instalar la extensión para el cliente web de 1C:Enterprise.';tr = 'Devam etmek için 1C: İşletme web istemcisi için uzantı yükleyin.';it = 'Installa la estensione del file system webclient 1C:Enterprise per proseguire';de = 'Um fortzufahren, müssen Sie eine Erweiterung für den 1C:Enterprise-Webclient installieren.'");
		CommonClient.ShowFileSystemExtensionInstallationQuestion(Handler, MessageText, False);
		Return;
	EndIf;
	
	// Writing in the object form.
	If Context.WritingRequired Then
		Context.WritingRequired = False;
		If Source.Ref.IsEmpty()
			Or (CommandDetails.WriteMode <> "WriteNewOnly" AND Context.Form.Modified) Then
			QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Данные еще не записаны.
					|Выполнение действия ""%1"" возможно только после записи данных.
					|Данные будут записаны.'; 
					|en = 'Data is not written yet.
					|The ""%1"" action can be performed only after writing the data.
					|Data will be written.'; 
					|pl = 'Dane nie są jeszcze zapisane.
					|Wykonanie działania ""%1"" jest możliwe tylko po zapisie danych.
					|Dane zostaną zapisane.';
					|es_ES = 'Datos aún no se han grabado.
					|Ejecución de la acción ""%1"" es posible solo después de que los datos se hayan grabado.
					|Datos se grabarán.';
					|es_CO = 'Datos aún no se han grabado.
					|Ejecución de la acción ""%1"" es posible solo después de que los datos se hayan grabado.
					|Datos se grabarán.';
					|tr = 'Veri hala kaydedilmiyor. 
					|İşlemin yürütülmesi ""%1"" sadece veriler kaydedildikten sonra mümkündür. 
					|Veri yazılacak.';
					|it = 'I dati non sono ancora registrati.
					|L''operazione %1 può essere eseguita solo dopo aver registrato i dati.
					|I dati saranno registrati.';
					|de = 'Die Daten werden noch nicht aufgezeichnet.
					|Die Ausführung der Aktion ""%1"" ist erst möglich, nachdem Daten aufgezeichnet wurden.
					|Daten werden geschrieben.'"),
				CommandDetails.Presentation);
			Handler = New NotifyDescription("ProceedRunningCommandAfterRecordConfirmed", ThisObject, Context);
			ShowQueryBox(Handler, QuestionText, QuestionDialogMode.OKCancel);
			Return;
		EndIf;
	EndIf;
	
	// Determining object references.
	If Context.RefGettingRequired Then
		Context.RefGettingRequired = False;
		RefsArray = New Array;
		If Context.IsObjectForm Then
			AddRefToList(Source, RefsArray, CommandDetails.ParameterType);
		ElsIf Not CommandDetails.MultipleChoice Then
			AddRefToList(Source.CurrentData, RefsArray, CommandDetails.ParameterType);
		Else
			For Each ID In Source.SelectedRows Do
				AddRefToList(Source.RowData(ID), RefsArray, CommandDetails.ParameterType);
			EndDo;
		EndIf;
		If RefsArray.Count() = 0 AND CommandDetails.WriteMode <> "DoNotWrite" Then
			Raise NStr("ru = 'Команда не может быть выполнена для указанного объекта.'; en = 'Cannot execute the command for the specified object.'; pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Belirtilen nesne için komut çalıştırılamaz.';it = 'Non è possibile eseguire il comando per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
		EndIf;
		Context.Insert("RefsArray", RefsArray);
	EndIf;
	
	// Posting documents.
	If Context.PostingRequired Then
		Context.PostingRequired = False;
		DocumentsInfo = AttachableCommandsServerCall.DocumentsInfo(Context.RefsArray);
		If DocumentsInfo.Unposted.Count() > 0 Then
			If DocumentsInfo.HasRightToPost Then
				If DocumentsInfo.Unposted.Count() = 1 Then
					QuestionText = NStr("ru = 'Для выполнения команды необходимо предварительно провести документ. Выполнить проведение документа и продолжить?'; en = 'Post the document to execute the command. Post the document and continue?'; pl = 'W celu wykonania polecenia należy uprzednio zaksięgować dokument. Wykonać księgowanie dokumentu i kontynuować?';es_ES = 'Para realizar el comando es necesario validar anteriormente el documento. ¿Validar el documento y continuar?';es_CO = 'Para realizar el comando es necesario validar anteriormente el documento. ¿Validar el documento y continuar?';tr = 'Komutu yürütmek için belge önceden onaylanmalıdır. Belge onaylansın ve devam edilsin mi?';it = 'Pubblica il documento per eseguire il comando. Pubblicare il documento e proseguire?';de = 'Um den Befehl auszuführen, buchen Sie zuerst das Dokument. Das Dokument buchen und fortfahren?'");
				Else
					QuestionText = NStr("ru = 'Для выполнения команды необходимо предварительно провести документы. Выполнить проведение документов и продолжить?'; en = 'Post the documents to execute the command. Post the documents and continue?'; pl = 'W celu wykonania polecenia należy uprzednio zaksięgować dokumenty. Wykonać księgowanie dokumentów i kontynuować?';es_ES = 'Para realizar el comando es necesario validar anteriormente los documentos. ¿Validar los documentos y continuar?';es_CO = 'Para realizar el comando es necesario validar anteriormente los documentos. ¿Validar los documentos y continuar?';tr = 'Komutu yürütmek için belgeler önceden onaylanmalıdır. Belgeler onaylansın ve devam edilsin mi?';it = 'Pubblica i documenti per eseguire il comando. Pubblicare i documenti e proseguire?';de = 'Um den Befehl auszuführen, buchen Sie zuerst die Dokumente. Die Dokumente buchen und fortfahren?'");
				EndIf;
				Context.Insert("UnpostedDocuments", DocumentsInfo.Unposted);
				Handler = New NotifyDescription("ContinueCommandExecutionAfterConfirmPosting", ThisObject, Context);
				Buttons = New ValueList;
				Buttons.Add(DialogReturnCode.Yes, NStr("ru = 'Продолжить'; en = 'Continue'; pl = 'Kontynuuj';es_ES = 'Continuar';es_CO = 'Continuar';tr = 'Devam';it = 'Continua';de = 'Weiter'"));
				Buttons.Add(DialogReturnCode.Cancel);
				ShowQueryBox(Handler, QuestionText, Buttons);
			Else
				If DocumentsInfo.Unposted.Count() = 1 Then
					WarningText = NStr("ru = 'Для выполнения команды необходимо предварительно провести документ. Недостаточно прав для проведения документа.'; en = 'Post the document to execute the command. Insufficient rights to post the document.'; pl = 'W celu wykonania polecenia należy uprzednio zaksięgować dokument. Nie wystarczające uprawnienia do zaksięgowania dokumentu.';es_ES = 'Para realizar el comando es necesario validar anteriormente el documento. Insuficientes derechos para validar el documento.';es_CO = 'Para realizar el comando es necesario validar anteriormente el documento. Insuficientes derechos para validar el documento.';tr = 'Komutu yürütmek için belge önceden onaylanmalıdır. Belge onaylanması için yetersiz yetki.';it = 'Pubblica il documento per eseguire il comando. Permessi insufficienti per pubblicare il documento.';de = 'Um den Befehl auszuführen, buchen Sie zuerst das Dokument. Nicht ausreichende Rechte, um das Dokument zu buchen.'");
				Else
					WarningText = NStr("ru = 'Для выполнения команды необходимо предварительно провести документы. Недостаточно прав для проведения документов.'; en = 'Post the documents to execute the command. Insufficient rights to post the documents.'; pl = 'W celu wykonania polecenia należy uprzednio zaksięgować dokumenty. Nie wystarczające uprawnienia do zaksięgowania dokumentów.';es_ES = 'Para realizar el comando es necesario validar anteriormente los documentos. Insuficientes derechos para validar los documentos.';es_CO = 'Para realizar el comando es necesario validar anteriormente los documentos. Insuficientes derechos para validar los documentos.';tr = 'Komutu yürütmek için belgeler önceden onaylanmalıdır. Belgelerin onaylanması için yetersiz yetki.';it = 'Pubblica i documenti per eseguire il comando. Permessi insufficienti per pubblicare i documenti.';de = 'Um den Befehl auszuführen, buchen Sie die Dokumente zuerst. Nicht ausreichende Rechte, um die Dokumente zu buchen.'");
				EndIf;
				ShowMessageBox(, WarningText);
			EndIf;
			Return;
		EndIf;
	EndIf;
	
	// Executing the command.
	If CommandDetails.MultipleChoice Then
		CommandParameter = Context.RefsArray;
	ElsIf Context.RefsArray.Count() = 0 Then
		CommandParameter = Undefined;
	Else
		CommandParameter = Context.RefsArray[0];
	EndIf;
	If CommandDetails.Server Then
		ServerContext = New Structure;
		ServerContext.Insert("CommandParameter", CommandParameter);
		ServerContext.Insert("CommandNameInForm", CommandDetails.NameOnForm);
		Result = New Structure;
		If Context.Property("CallServerThroughNotificationProcessing") Then
			NotifyDescription = New NotifyDescription("Attachable_ContinueCommandExecutionAtServer", Context.Form);
			ExecuteNotifyProcessing(NotifyDescription, ServerContext);
			Result = ServerContext.Result;
		Else
			Context.Form.Attachable_ExecuteCommandAtServer(ServerContext, Result);
		EndIf;
		If ValueIsFilled(Result.Text) Then
			ShowMessageBox(, Result.Text);
		Else
			UpdateForm(Context);
		EndIf;
	Else
		If ValueIsFilled(CommandDetails.Handler) Then
			SubstringsArray = StrSplit(CommandDetails.Handler, ".");
			If SubstringsArray.Count() = 1 Then
				FormParameters = FormParameters(Context, CommandParameter);
				ModuleClient = GetForm(CommandDetails.FormName, FormParameters, Context.Form, True);
				ProcedureName = CommandDetails.Handler;
			Else
				ModuleClient = CommonClient.CommonModule(SubstringsArray[0]);
				ProcedureName = SubstringsArray[1];
			EndIf;
			Handler = New NotifyDescription(ProcedureName, ModuleClient, Context);
			ExecuteNotifyProcessing(Handler, CommandParameter);
		ElsIf ValueIsFilled(CommandDetails.FormName) Then
			FormParameters = FormParameters(Context, CommandParameter);
			OpenForm(CommandDetails.FormName, FormParameters, Context.Form, True);
		EndIf;
	EndIf;
EndProcedure

// The procedure branch that is going after the writing confirmation dialog.
Procedure ProceedRunningCommandAfterRecordConfirmed(Response, Context) Export
	If Response = DialogReturnCode.OK Then
		ClearMessages();
		Context.Form.Write();
		If Context.Source.Ref.IsEmpty() Or Context.Form.Modified Then
			Return; // Failed to write, the platform shows an error message.
		EndIf;
	ElsIf Response = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	ContinueCommandExecution(Context)
EndProcedure

// The procedure branch that is going after the posting confirmation dialog.
Procedure ContinueCommandExecutionAfterConfirmPosting(Response, Context) Export
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ClearMessages();
	UnpostedDocumentsData = CommonServerCall.PostDocuments(Context.UnpostedDocuments);
	MessageTemplate = NStr("ru = 'Документ %1 не проведен: %2'; en = 'Document %1 is not posted: %2'; pl = 'Dokument %1 nie został zatwierdzony: %2';es_ES = 'Documento %1 no está enviado: %2';es_CO = 'Documento %1 no está enviado: %2';tr = '%1 belgesi kaydedilmedi: %2';it = 'Il documento %1 non è pubblicato: %2';de = 'Dokument %1 ist nicht gebucht: %2'");
	UnpostedDocuments = New Array;
	For Each DocumentInformation In UnpostedDocumentsData Do
		CommonClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersToString(
				MessageTemplate,
				String(DocumentInformation.Ref),
				DocumentInformation.ErrorDescription),
				DocumentInformation.Ref);
		UnpostedDocuments.Add(DocumentInformation.Ref);
	EndDo;
	Context.Insert("UnpostedDocuments", UnpostedDocuments);
	
	Context.RefsArray = CommonClientServer.ArraysDifference(Context.RefsArray, UnpostedDocuments);
	
	// Notifying form opening that the documents were posted.
	PostedDocumentTypes = New Map;
	For Each PostedDocument In Context.RefsArray Do
		PostedDocumentTypes.Insert(TypeOf(PostedDocument));
	EndDo;
	For Each Type In PostedDocumentTypes Do
		NotifyChanged(Type.Key);
	EndDo;
	
	// If the command is called from a form, read the up-to-date (posted) copy from the infobase.
	If TypeOf(Context.Form) = Type("ClientApplicationForm") Then
		If Context.IsObjectForm Then
			Context.Form.Read();
		EndIf;
		Context.Form.RefreshDataRepresentation();
	EndIf;
	
	If UnpostedDocuments.Count() > 0 Then
		// Asking the user whether the procedure execution must be continued even if there are unposted documents.
		DialogText = NStr("ru = 'Не удалось провести один или несколько документов.'; en = 'Cannot post one or several documents.'; pl = 'Nie można dekretować jednego lub kilku dokumentów.';es_ES = 'No se puede enviar uno o varios documentos.';es_CO = 'No se puede enviar uno o varios documentos.';tr = 'Bir veya birkaç belge onaylanmaz.';it = 'Non è possibile inviare uno o più documenti.';de = 'Ein oder mehrere Dokumente können nicht gebucht werden.'");
		
		DialogButtons = New ValueList;
		If Context.RefsArray.Count() = 0 Then
			DialogButtons.Add(DialogReturnCode.Cancel, NStr("ru = 'ОК'; en = 'OK'; pl = 'OK';es_ES = 'OK';es_CO = 'Ok';tr = 'Tamam';it = 'OK';de = 'Ok'"));
		Else
			DialogText = DialogText + " " + NStr("ru = 'Продолжить?'; en = 'Continue?'; pl = 'Kontynuować?';es_ES = '¿Continuar?';es_CO = '¿Continuar?';tr = 'Devam et?';it = 'Continuare?';de = 'Fortsetzen?'");
			DialogButtons.Add(DialogReturnCode.Ignore, NStr("ru = 'Продолжить'; en = 'Continue'; pl = 'Kontynuuj';es_ES = 'Continuar';es_CO = 'Continuar';tr = 'Devam';it = 'Continua';de = 'Weiter'"));
			DialogButtons.Add(DialogReturnCode.Cancel);
		EndIf;
		
		Handler = New NotifyDescription("ContinueCommandExecutionAfterConfirmContinuation", ThisObject, Context);
		ShowQueryBox(Handler, DialogText, DialogButtons);
		Return;
	EndIf;
	
	ContinueCommandExecution(Context);
EndProcedure

// The procedure branch that is going after the continuation confirmation dialog when unposted documents exist.
Procedure ContinueCommandExecutionAfterConfirmContinuation(Response, Context) Export
	If Response <> DialogReturnCode.Ignore Then
		Return;
	EndIf;
	ContinueCommandExecution(Context);
EndProcedure

// The procedure branch that is going after the file system extension installation.
Procedure ContinueExecutionCommandAfterSetFileExtension(FileSystemExtensionAttached, Context) Export
	If Not FileSystemExtensionAttached Then
		Return;
	EndIf;
	ContinueCommandExecution(Context);
EndProcedure

// Gets a reference from the table row, checks whether the reference meets the type and adds it to the array.
Procedure AddRefToList(FormDataStructure, RefsArray, ParameterType)
	Ref = CommonClientServer.StructureProperty(FormDataStructure, "Ref");
	If ParameterType <> Undefined AND Not ParameterType.ContainsType(TypeOf(Ref)) Then
		Return;
	ElsIf Ref = Undefined Or TypeOf(Ref) = Type("DynamicListGroupRow") Then
		Return;
	EndIf;
	RefsArray.Add(Ref);
EndProcedure

// Generates form parameters of the attached object in the context of the command being executed.
Function FormParameters(Context, CommandParameter)
	Result = Context.CommandDetails.FormParameters;
	If TypeOf(Result) <> Type("Structure") Then
		Result = New Structure;
	EndIf;
	Context.CommandDetails.Delete("FormParameters");
	Result.Insert("CommandDetails", Context.CommandDetails);
	If IsBlankString(Context.CommandDetails.FormParameterName) Then
		Result.Insert("CommandParameter", CommandParameter);
	Else
		NamesArray = StrSplit(Context.CommandDetails.FormParameterName, ".", False);
		Node = Result;
		UBound = NamesArray.UBound();
		For Index = 0 To UBound-1 Do
			Name = TrimAll(NamesArray[Index]);
			If Not Node.Property(Name) Or TypeOf(Node[Name]) <> Type("Structure") Then
				Node.Insert(Name, New Structure);
			EndIf;
			Node = Node[Name];
		EndDo;
		Node.Insert(NamesArray[UBound], CommandParameter);
	EndIf;
	Return Result;
EndFunction

// Refreshes the destination object form when the command has been executed.
Procedure UpdateForm(Context)
	If Context.IsObjectForm AND Context.CommandDetails.WriteMode <> "DoNotWrite" AND Not Context.Form.Modified Then
		Try
			Context.Form.Read();
		Except
			// If the Read method is unavailable, printing was executed from a location other than the object form.
		EndTry;
	EndIf;
	If Context.CommandDetails.WriteMode <> "DoNotWrite" Then
		ModifiedObjectTypes = New Array;
		For Each Ref In Context.RefsArray Do
			Type = TypeOf(Ref);
			If ModifiedObjectTypes.Find(Ref) = Undefined Then
				ModifiedObjectTypes.Add(Ref);
			EndIf;
		EndDo;
		For Each Type In ModifiedObjectTypes Do
			NotifyChanged(Type);
		EndDo;
	EndIf;
	Context.Form.RefreshDataRepresentation();
EndProcedure

#EndRegion
