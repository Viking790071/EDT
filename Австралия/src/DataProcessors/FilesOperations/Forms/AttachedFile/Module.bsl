#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	OwnerType  = TypeOf(Parameters.FileOwner);
	
	If ValueIsFilled(Parameters.AttachedFile) Then
		AttachedFile = Parameters.AttachedFile;
	Else
		AttachedFile = Parameters.Key;
	EndIf;
	
	DigitalSignatureAvailable = FilesOperationsInternal.DigitalSignatureAvailable(TypeOf(AttachedFile));
	CurrentUser = Users.AuthorizedUser();
	
	Items.FileOwner0.Title = OwnerType;
	
	SendOptions = ?(ValueIsFilled(Parameters.SendOptions),
		Parameters.SendOptions, FilesOperationsInternal.PrepareSendingParametersStructure());
	
	FilesOperationsInternal.ItemFormOnCreateAtServer(
		ThisObject, Cancel, StandardProcessing, Parameters, ReadOnly, True);
		
	SetButtonsAvailability(ThisObject, Items);
	RestrictedExtensions = FilesOperationsInternal.DeniedExtensionsList();
	RefreshTitle();
	UpdateCloudServiceNote(AttachedFile);
	
	FilesOperationsOverridable.OnCreateFilesItemForm(ThisObject);
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		CommonClientServer.SetFormItemProperty(Items, "FormStandardWriteAndClose", "Representation", ButtonRepresentation.Picture);
		CommonClientServer.SetFormItemProperty(Items, "FormOpenFileForViewing", "Representation", ButtonRepresentation.Picture);
		CommonClientServer.SetFormItemProperty(Items, "Edit", "Representation", ButtonRepresentation.Picture);
		CommonClientServer.SetFormItemProperty(Items, "EndEdit", "Representation", ButtonRepresentation.Picture);
		CommonClientServer.SetFormItemProperty(Items, "FormSaveChanges", "Representation", ButtonRepresentation.Picture);
		CommonClientServer.SetFormItemProperty(Items, "SaveAs", "Representation", ButtonRepresentation.Picture);
		
		ItemNamesDetails = New Array(2);
		ItemNamesDetails[0] = "Details";
		ItemNamesDetails[1] = "Details0";
		
		For each ItemName In ItemNamesDetails Do
			
			If Items.Find(ItemName) = Undefined Then
				
				Continue;
				
			EndIf;
			
			CommonClientServer.SetFormItemProperty(Items, ItemName, "TitleLocation", FormItemTitleLocation.None);
			CommonClientServer.SetFormItemProperty(Items, ItemName, "InputHint", NStr("ru ='Краткое описание'; en = 'Brief details'; pl = 'Krótki opis';es_ES = 'Descricpión corta';es_CO = 'Descricpión corta';tr = 'Kısa açıklama';it = 'Dettagli brevi';de = 'Kurzbeschreibung'"));
			CommonClientServer.SetFormItemProperty(Items, ItemName, "MaxHeight", 2);
			CommonClientServer.SetFormItemProperty(Items, ItemName, "AutoMaxHeight", False);
			CommonClientServer.SetFormItemProperty(Items, ItemName, "VerticalStretch", False);
			
		EndDo;
		
		CommonClientServer.SetFormItemProperty(Items, "CommonInfoGroup", "Group", ChildFormItemsGroup.Vertical);
		CommonClientServer.SetFormItemProperty(Items, "CommandsGroup", "Group", ChildFormItemsGroup.AlwaysHorizontal);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	DescriptionBeforeWrite = ThisObject.Object.Description;
	
	ModificationDate = ToLocalTime(ThisObject.Object.UniversalModificationDate);
	
	SetAvaliabilityOfDSCommandsList();
	SetAvaliabilityOfEncryptionList();
	
	ReadSignaturesCertificates();
	DisplayAdditionalDataTabs();
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	UnlockObject(ThisObject.Object.Ref, UUID);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Write_ConstantsSet") AND (Upper(Source) = Upper("UseDigitalSignature")
		Or Upper(Source) = Upper("UseEncryption")) Then
		AttachIdleHandler("OnChangeSignatureOrEncryptionUsage", 0.3, True);
	EndIf;
	
	If EventName = "Write_File"
		AND Source = ThisObject.Object.Ref
		AND Parameter <> Undefined
		AND TypeOf(Parameter) = Type("Structure")
		AND Parameter.Property("Event")
		AND (Parameter.Event = "EditFinished"
		   Or Parameter.Event = "EditingCanceled") Then
		UpdateObject();
	EndIf;
	
	// StandardSubsystems.Properties
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DecorationSynchronizationDateURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	If FormattedStringURL = "OpenJournal" Then
		
		StandardProcessing = False;
		FilterParameters      = EventLogFilterData(Account);
		EventLogClient.OpenEventLog(FilterParameters, ThisObject);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region DigitalSignaturesFormTableItemsEventHandlers

&AtClient
Procedure DigitalSIgnaturesChoice(Item, RowSelected, Field, StandardProcessing)
	
	If Not CommonClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	ModuleDigitalSignatureClient = CommonClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.OpenSignature(Items.DigitalSignatures.CurrentData);
	
EndProcedure

&AtClient
Procedure InstructionClick(Item)
	
	If CommonClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureClient = CommonClient.CommonModule("DigitalSignatureClient");
		ModuleDigitalSignatureClient.OpenInstructionOnTypicalProblemsOnWorkWithApplications();
	EndIf;
	
EndProcedure

#EndRegion

#Region EncryptionCertificatesFormTableItemsEventHandlers

&AtClient
Procedure EncryptionCertificatesSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenEncryptionCertificate(Undefined);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

///////////////////////////////////////////////////////////////////////////////////
// File command handlers

&AtClient
Procedure ShowInList(Command)
	StandardSubsystemsClient.ShowInList(ThisObject["Object"].Ref, Undefined);
EndProcedure

&AtClient
Procedure UpdateFromFileOnHardDrive(Command)
	
	Var NewExtension;
	
	If IsNew()
		OR ThisObject.Object.Encrypted
		OR ThisObject.Object.SignedWithDS
		OR ValueIsFilled(ThisObject.Object.BeingEditedBy) Then
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileData(ThisObject.Object.Ref);
	Handler = New NotifyDescription("UpdateFromFileOnHardDriveCompletion", ThisObject);
	FilesOperationsInternalClient.UpdateFromFileOnHardDriveWithNotification(Handler, FileData, UUID);
	
EndProcedure

&AtClient
Procedure StandardWriteAndClose(Command)
	
	If HandleFileRecordCommand() Then
		
		Result = New Structure();
		Result.Insert("ErrorText", "");
		Result.Insert("FileAdded", True);
		Result.Insert("FileRef", ThisObject.Object.Ref);
		
		Close(Result);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure StandardWrite(Command)
	
	HandleFileRecordCommand();
	
EndProcedure

&AtClient
Procedure StandardSetDeletionMark(Command)
	
	If IsNew() Then
		Return;
	EndIf;
	
	If Modified Then
		If ThisObject.Object.DeletionMark Then
			QuestionText = NStr(
				"ru = 'Для выполнения действия требуется записать изменения файла.
				      |Записать изменения и снять пометку на удаление с файла ""%1""?'; 
				      |en = 'To clear the deletion mark from %1, you need to save the changes.
					  |Save the changes and clear the deletion mark?'; 
				      |pl = 'Aby usunąć zaznaczenie do usunięcia z %1, należy zapisać zmiany.
				      |Zapisać zmiany i usunąć zaznaczenie do usunięcia?';
				      |es_ES = 'Para borrar la marca de borrado de %1, debe guardar los cambios.
				      |¿Guardar los cambios y borrar la marca de borrado?';
				      |es_CO = 'Para borrar la marca de borrado de %1, debe guardar los cambios.
				      |¿Guardar los cambios y borrar la marca de borrado?';
				      |tr = '%1 öğesinden silme işaretini kaldırmak için değişiklikleri kaydetmelisiniz.
				      |Değişiklikler kaydedilip silme işareti kaldırılsın mı?';
				      |it = 'Per rimuovere il contrassegno di eliminazione da %1, è necessario salvare le modifiche.
				      |Salvare le modifiche e rimuovere il contrassegno di eliminazione?';
				      |de = 'Um die Löschmarkierung von %1 zu löschen, müssen Sie die Änderungen speichern.
				      |Änderungen speichern und Löschmarkierung löschen?'");
		Else
			QuestionText = NStr(
				"ru = 'Чтобы пометить %1 на удаление, необходимо сохранить изменения
				      |Сохранить изменения и пометить файл на удаление?'; 
				      |en = 'To mark %1 for deletion, you need to save the changes.
					  |Save the changes and mark the file for deletion?'; 
				      |pl = 'Aby zaznaczyć %1 do usunięcia, należy zapisać zamiany.
				      |Zapisać zmiany i zaznaczyć plik do usunięcia?';
				      |es_ES = 'Para marcar %1 para su borrado, necesita guardar los cambios.
				      |¿Guardar los cambios y marcar el archivo para su borrado?';
				      |es_CO = 'Para marcar %1 para su borrado, necesita guardar los cambios.
				      |¿Guardar los cambios y marcar el archivo para su borrado?';
				      |tr = '%1 öğesini silmek üzere işaretlemek için değişiklikleri kaydetmelisiniz.
				      |Değişiklikler kaydedilip dosya silinmek üzere işaretlensin mi?';
				      |it = 'Per contrassegnare %1 per l''eliminazione, è necessario salvare le modifiche.
				      |Salvare le modifiche e contrassegnare il file per l''eliminazione?';
				      |de = 'Um %1 zum Löschen zu markieren, müssen Sie die Änderungen speichern.
				      |Änderungen speichern und die Datei zum Löschen markieren?'");
		EndIf;
	Else
		If ThisObject.Object.DeletionMark Then
			QuestionText = NStr("ru = 'Снять пометку на удаление с файла
			                          |""%1""?'; 
			                          |en = 'Deletion mark will be cleared from %1.
			                          |Continue?'; 
			                          |pl = 'Zaznaczenie do usunięcia zostanie usunięte z %1.
			                          |Kontynuować?';
			                          |es_ES = 'Se eliminará la marca de borrado de %1.
			                          |¿Continuar?';
			                          |es_CO = 'Se eliminará la marca de borrado de %1.
			                          |¿Continuar?';
			                          |tr = '%1 öğesinden silme işareti kaldırılacak.
			                          |Devam edilsin mi?';
			                          |it = 'Il contrassegno di eliminazione verrà rimosso da %1.
			                          |Continuare?';
			                          |de = 'Löschmarkierung wird aus %1 gelöscht.
			                          |Fortfahren?'");
		Else
			QuestionText = NStr("ru = 'Пометить на удаление файл
			                          |""%1""?'; 
			                          |en = '%1 will be marked for deletion.
			                          |Continue?'; 
			                          |pl = '%1 zostaną zaznaczone do usunięcia.
			                          |Kontynuować?';
			                          |es_ES = '%1 será marcado para ser borrado.
			                          |¿Continuar?';
			                          |es_CO = '%1 será marcado para ser borrado.
			                          |¿Continuar?';
			                          |tr = '%1 silinmek üzere işaretlenecek.
			                          |Devam edilsin mi?';
			                          |it = '%1 sarà contrassegnato per l''eliminazione.
			                          |Continuare?';
			                          |de = '%1 wird zum Löschen markiert. 
			                          |Fortsetzen?'");
		EndIf;
	EndIf;
	
	QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
		QuestionText, ThisObject.Object.Ref);
		
	NotifyDescription = New NotifyDescription("StandardSetDeletionMarkAnswerReceived", ThisObject);
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
EndProcedure

&AtClient
Procedure StandardSetDeletionMarkAnswerReceived(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		ThisObject.Object.DeletionMark = NOT ThisObject.Object.DeletionMark;
		HandleFileRecordCommand();
	EndIf;
	
EndProcedure

&AtClient
Procedure StandardReread(Command)
	
	If IsNew() Then
		Return;
	EndIf;
	
	If NOT Modified Then
		RereadDataFromServer();
		Return;
	EndIf;
	
	QuestionText = NStr("ru = 'Данные изменены. Перечитать данные?'; en = 'Data is changed. Reread?'; pl = 'Dane są zmieniane. Odczytać ponownie?';es_ES = 'Datos se han cambiado. ¿Volver a leer?';es_CO = 'Datos se han cambiado. ¿Volver a leer?';tr = 'Veri değişti. Tekrar okunsun mu?';it = 'I dati sono stati modificati. Rileggere i dati?';de = 'Die Daten wurden geändert. Die Daten wieder lesen?'");
	
	NotifyDescription = New NotifyDescription("StandardRereadAnswerReceived", ThisObject);
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure StandardRereadAnswerReceived(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		RereadDataFromServer();
		Modified = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure StandardCopy(Command)
	
	If IsNew() Then
		Return;
	EndIf;
	
	FormParameters = New Structure("CopyingValue", ThisObject.Object.Ref);
	
	OpenForm("DataProcessor.FilesOperations.Form.AttachedFile", FormParameters);
	
EndProcedure

&AtClient
Procedure Print(Command)
	
	SystemInfo = New SystemInfo;
	If SystemInfo.PlatformType <> PlatformType.Windows_x86 
		AND SystemInfo.PlatformType <> PlatformType.Windows_x86_64 Then
			ShowMessageBox(, NStr("ru = 'Печать файлов возможна только в Windows.'; en = 'Printing files is available only in Windows.'; pl = 'Drukowanie plików jest możliwe tylko w Windows.';es_ES = 'Es posible imprimir los archivos solo en Windows.';es_CO = 'Es posible imprimir los archivos solo en Windows.';tr = 'Dosya yalnızca Windows''ta yazdırılabilir.';it = 'Il file di stampa sono disponibili solo in Windows.';de = 'Dateien können nur unter Windows gedruckt werden.'"));
			Return;
	EndIf;
	
	If ValueIsFilled(ThisObject.Object.Ref) Then
		FilePrint();
	Else
		ShowMessageBox(, NStr("ru = 'Для печати файла необходимо записать данные. Записать?';
			|en = 'You can print the file after the data is saved. Do you want to save the data?'; pl = 'Nie możesz drukować pliku po tym jak dane są zapisane. Czy chcesz zapisać dane?';es_ES = 'Puede imprimir el archivo después de guardar los datos. ¿Quiere guardar los datos?';es_CO = 'Puede imprimir el archivo después de guardar los datos. ¿Quiere guardar los datos?';tr = 'Veri kaydedildikten sonra dosyayı yazdırabilirsiniz. Veriyi kaydetmek istiyor musunuz?';it = 'Puoi stampare il file dopo aver salvato i dati. Vuoi salvare i dati?';de = 'Sie können die Datei erst als die Datei gespeichert ist ausdrücken. Möchten Sie die Datei speichern?'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure PrintWithStamp(Command)
	
	If ValueIsFilled(ThisObject.Object.Ref) Then
		DocumentWithStamp = FilesOperationsInternalServerCall.SpreadsheetDocumentWithStamp(ThisObject.Object.Ref, ThisObject.Object.Ref);
		FilesOperationsInternalClient.PrintFileWithStamp(DocumentWithStamp);
	EndIf;
	
EndProcedure

&AtClient
Procedure Send(Command)
	
	Files = CommonClientServer.ValueInArray(ThisObject.Object.Ref);
	FilesOperationsInternalClient.SendFilesViaEmail(Files, UUID, SendOptions);
	
EndProcedure

// StandardSubsystems.Properties

&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, URL = Undefined, StandardProcessing = Undefined)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
	EndIf;
	
EndProcedure

// End StandardSubsystems.Properties

///////////////////////////////////////////////////////////////////////////////////
// Digital signature and encryption command handlers.

&AtClient
Procedure Sign(Command)
	
	If IsNew()
		Or ValueIsFilled(ThisObject.Object.BeingEditedBy)
		Or ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	If Modified Then
		If Not WriteFile() Then
			Return;
		EndIf;
	EndIf;
	
	NotifyDescription      = New NotifyDescription("OnGetSignature", ThisObject);
	AdditionalParameters = New Structure("ResultProcessing", NotifyDescription);
	FilesOperationsClient.SignFile(ThisObject.Object.Ref, UUID, AdditionalParameters);
	
EndProcedure

&AtClient
Procedure AddDSFromFile(Command)
	
	If IsNew()
		Or ValueIsFilled(ThisObject.Object.BeingEditedBy)
		Or ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	AttachedFile = ThisObject.Object.Ref;
	FilesOperationsInternalClient.AddSignatureFromFile(
		AttachedFile,
		UUID,
		New NotifyDescription("OnGetSignatures", ThisObject));
	
EndProcedure

&AtClient
Procedure SaveWithDigitalSignature(Command)
	
	If IsNew()
		OR ValueIsFilled(ThisObject.Object.BeingEditedBy)
		OR ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	FilesOperationsClient.SaveWithDigitalSignature(
		ThisObject.Object.Ref,
		UUID);
	
EndProcedure

&AtClient
Procedure Encrypt(Command)
	
	If IsNew() Or ValueIsFilled(ThisObject.Object.BeingEditedBy) Or ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	If Modified Then
		If Not WriteFile() Then
			Return;
		EndIf;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.GetFileDataAndVersionsCount(ThisObject.Object.Ref);
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("FileData", FileData);
	Handler = New NotifyDescription("EncryptAfterEncryptAtClient", ThisObject, HandlerParameters);
	
	FilesOperationsInternalClient.Encrypt(
		Handler,
		FileData,
		UUID);
		
EndProcedure

&AtClient
Procedure EncryptAfterEncryptAtClient(Result, ExecutionParameters) Export
	If Not Result.Success Then
		Return;
	EndIf;
	
	WorkingDirectoryName = FilesOperationsInternalClient.UserWorkingDirectory();
	
	FilesArrayInWorkingDirectoryToDelete = New Array;
	
	EncryptServer(
		Result.DataArrayToStoreInDatabase,
		Result.ThumbprintsArray,
		FilesArrayInWorkingDirectoryToDelete,
		WorkingDirectoryName);
	
	FilesOperationsInternalClient.InformOfEncryption(
		FilesArrayInWorkingDirectoryToDelete,
		ExecutionParameters.FileData.Owner,
		ThisObject.Object.Ref);
		
	NotifyChanged(ThisObject.Object.Ref);
	Notify("Write_File", New Structure, ThisObject.Object.Ref);
	
	SetAvaliabilityOfEncryptionList();
	
EndProcedure

&AtClient
Procedure Decrypt(Command)
	
	If IsNew() Or Not ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.GetFileDataAndVersionsCount(ThisObject.Object.Ref);
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("FileData", FileData);
	Handler = New NotifyDescription("DecryptAfterDecryptAtClient", ThisObject, HandlerParameters);
	
	FilesOperationsInternalClient.Decrypt(
		Handler,
		FileData.Ref,
		UUID,
		FileData);
	
EndProcedure

&AtClient
Procedure DecryptAfterDecryptAtClient(Result, ExecutionParameters) Export
	
	If Not Result.Success Then
		Return;
	EndIf;
	WorkingDirectoryName = FilesOperationsInternalClient.UserWorkingDirectory();
	
	DecryptServer(Result.DataArrayToStoreInDatabase, WorkingDirectoryName);
	
	FilesOperationsInternalClient.InformOfDecryption(
		ExecutionParameters.FileData.Owner,
		ThisObject.Object.Ref);
	
	FillEncryptionListAtServer();
	SetAvaliabilityOfEncryptionList();
	
EndProcedure

&AtServer
Procedure FillEncryptionListAtServer()
	FilesOperationsInternal.FillEncryptionList(ThisObject);
EndProcedure

&AtClient
Procedure DigitalSignatureCommandListOpenSignature(Command)
	
	If Not CommonClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	ModuleDigitalSignatureClient = CommonClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.OpenSignature(Items.DigitalSignatures.CurrentData);
	
EndProcedure

&AtClient
Procedure VerifyDigitalSignature(Command)
	
	If Items.DigitalSignatures.SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	FileData = FileData(ThisObject.Object.Ref, UUID);
	
	FilesOperationsInternalClient.CheckSignatures(ThisObject,
		FileData.BinaryFileDataRef,
		Items.DigitalSignatures.SelectedRows);
	
EndProcedure

&AtClient
Procedure CheckAll(Command)
	
	FileData = FileData(ThisObject.Object.Ref, UUID);
	
	FilesOperationsInternalClient.CheckSignatures(ThisObject, FileData.BinaryFileDataRef);
	
EndProcedure

&AtClient
Procedure SaveSignature(Command)
	
	If Items.DigitalSignatures.CurrentData = Undefined Then
		Return;
	EndIf;
	
	CurrentData = Items.DigitalSignatures.CurrentData;
	
	If CurrentData.Object = Undefined Or CurrentData.Object.IsEmpty() Then
		Return;
	EndIf;
	
	If Not CommonClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	ModuleDigitalSignatureClient = CommonClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.SaveSignature(CurrentData.SignatureAddress);
	
EndProcedure

&AtClient
Procedure DeleteDS(Command)
	
	NotifyDescription = New NotifyDescription("DeleteDigitalSignatureAnswerReceived", ThisObject);
	ShowQueryBox(NotifyDescription, NStr("ru = 'Удалить выделенные подписи?'; en = 'Do you want to delete the selected signatures?'; pl = 'Usunąć zaznaczone podpisy?';es_ES = '¿Borrar las firmas seleccionadas?';es_CO = '¿Borrar las firmas seleccionadas?';tr = 'Seçilen imzalar silinsin mi?';it = 'Volete eliminare le firme selezionate?';de = 'Löschen Sie die ausgewählten Signaturen?'"), QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure DeleteDigitalSignatureAnswerReceived(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.No Then
		Return;
	EndIf;
	
	DeleteFromSignatureListAndWriteFile();
	NotifyChanged(ThisObject.Object.Ref);
	Notify("Write_File", New Structure, ThisObject.Object.Ref);
	SetAvaliabilityOfDSCommandsList();
	
EndProcedure

&AtClient
Procedure OpenEncryptionCertificate(Command)
	
	CurrentData = Items.EncryptionCertificates.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Not CommonClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	ModuleDigitalSignatureClient = CommonClient.CommonModule("DigitalSignatureClient");
	
	If IsBlankString(CurrentData.CertificateAddress) Then
		ModuleDigitalSignatureClient.OpenCertificate(CurrentData.Thumbprint);
	Else
		ModuleDigitalSignatureClient.OpenCertificate(CurrentData.CertificateAddress);
	EndIf;
	
EndProcedure

&AtClient
Procedure SetAvaliabilityOfDSCommandsList()
	
	FilesOperationsInternalClient.SetCommandsAvailabilityOfDigitalSignaturesList(ThisObject);
	
EndProcedure

&AtClient
Procedure SetAvaliabilityOfEncryptionList()
	
	FilesOperationsInternalClient.SetCommandsAvailabilityOfEncryptionCertificatesList(ThisObject);
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////////
// Command handlers to support collaboration in operations with files.

&AtClient
Procedure Lock(Command)
	
	If Modified AND Not HandleFileRecordCommand() Then
		Return;
	EndIf;
	
	Handler = New NotifyDescription("ReadAndSetFormItemsAvailability", ThisObject);
	FilesOperationsInternalClient.LockWithNotification(Handler, ThisObject.Object.Ref, UUID);
	
EndProcedure

&AtClient
Procedure Edit(Command)
	
	If IsNew()
		OR ThisObject.Object.SignedWithDS
		OR ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	If ValueIsFilled(ThisObject.Object.BeingEditedBy)
	   AND ThisObject.Object.BeingEditedBy <> CurrentUser Then
		Return;
	EndIf;
	
	If Modified AND Not HandleFileRecordCommand() Then
		Return
	EndIf;
	
	FileData = FileData(ThisObject.Object.Ref, UUID);
	
	If ValueIsFilled(ThisObject.Object.BeingEditedBy) Then
		FilesOperationsInternalClient.EditFile(Undefined,
			FileData, UUID);
	Else
		FilesOperationsInternalClient.EditFile(Undefined,
			FileData, UUID);
		
		UpdateObject();
		
		NotifyChanged(ThisObject.Object.Ref);
		Notify("Write_File", New Structure, ThisObject.Object.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure EndEdit(Command)
	
	If IsNew()
		Or Not ValueIsFilled(ThisObject.Object.BeingEditedBy)
		Or ThisObject.Object.BeingEditedBy <> CurrentUser Then
			Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileData(ThisObject.Object.Ref);
	
	NotifyDescription = New NotifyDescription("EndEditingPuttingCompleted", ThisObject);
	FileUpdateParameters = FilesOperationsInternalClient.FileUpdateParameters(NotifyDescription, FileData.Ref, UUID);
	FileUpdateParameters.StoreVersions = FileData.StoreVersions;
	If Not CanCreateFileVersions Then
		FileUpdateParameters.Insert("CreateNewVersion", False);
	EndIf;
	FileUpdateParameters.CurrentUserEditsFile = FileData.CurrentUserEditsFile;
	FileUpdateParameters.BeingEditedBy = FileData.BeingEditedBy;
	FilesOperationsInternalClient.EndEditAndNotify(FileUpdateParameters);
	UpdateObject();
	
EndProcedure

&AtClient
Procedure EndEditingPuttingCompleted(FileInfo, AdditionalParameters) Export
	
	NotifyChanged(ThisObject.Object.Ref);
	Notify("Write_File", New Structure, ThisObject.Object.Ref);
	SetButtonsAvailability(ThisObject, Items);
	
EndProcedure

&AtClient
Procedure Unlock(Command)
	
	If IsNew()
	 OR NOT ValueIsFilled(ThisObject.Object.BeingEditedBy)
	 OR ThisObject.Object.BeingEditedBy <> CurrentUser Then
		Return;
	EndIf;
	
	UnlockFile();
	NotifyChanged(ThisObject.Object.Ref);
	Notify("Write_File", New Structure("Event", "EditingCanceled"), ThisObject.Object.Ref);
	
EndProcedure

&AtClient
Procedure SaveChanges(Command)
	
	If Modified Then
		WriteFile();
	EndIf;
	
	Handler = New NotifyDescription("ReadAndSetFormItemsAvailability", ThisObject);
	
	FilesOperationsInternalClient.SaveFileChangesWithNotification(Handler,
		ThisObject.Object.Ref, UUID);
	
EndProcedure

&AtServer
Procedure PropertiesExecuteDeferredInitialization()
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.FillAdditionalAttributesInForm(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
	EndIf;
	
EndProcedure

// End StandardSubsystems.Properties

#EndRegion

#Region Private

&AtServer
Procedure RefreshTitle()
	
	If ValueIsFilled(ThisObject.Object.Ref) Then
		Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '%1 (Присоединенный файл)'; en = '%1 (Attached file)'; pl = '%1 (Załączony plik)';es_ES = '%1 (Archivo adjuntado)';es_CO = '%1 (Archivo adjuntado)';tr = '%1 (Ekli dosya)';it = '%1 (file allegato)';de = '%1 (Angehängte Datei)'"), String(ThisObject.Object.Ref));
	Else
		Title = NStr("ru = 'Присоединенный файл (Создание)'; en = 'Attached file (Create)'; pl = 'Załączony plik (Utworzenie)';es_ES = 'Archivo adjuntado (Creación)';es_CO = 'Archivo adjuntado (Creación)';tr = 'Ekli dosya (Oluşturma)';it = 'File allegato (Creare)';de = 'Angehängte Datei (Erstellen)'")
	EndIf;
	
EndProcedure

&AtClient
Procedure DisplayAdditionalDataTabs()
	
	If Items.AdditionalAttributesGroup.ChildItems.Count() > 0 Then
		BlankDecoration = Items.Find("Properties_EmptyDecoration");
		If BlankDecoration <> Undefined Then
			AdditionalAttributesVisibility = BlankDecoration.Visible;
		Else
			AdditionalAttributesVisibility = True;
		EndIf;
	Else
		AdditionalAttributesVisibility = False;
	EndIf;
	
	UseTabs = AdditionalAttributesVisibility Or Items.DigitalSignaturesGroup.Visible Or Items.EncryptionCertificatesGroup.Visible;
	Items.AdditionalPageDataGroup.PagesRepresentation =
	?(UseTabs , FormPagesRepresentation.TabsOnTop, FormPagesRepresentation.None);

EndProcedure

&AtServerNoContext
Function FileData(Val AttachedFile,
                            Val FormID = Undefined,
                            Val GetBinaryDataRef = True)
	
	Return FilesOperations.FileData(
		AttachedFile, FormID, GetBinaryDataRef);
	
EndFunction

&AtClient
Procedure OpenFileForViewing()
	
	If IsNew()
		OR ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	If RestrictedExtensions.FindByValue(ThisObject.Object.Extension) <> Undefined Then
		Notification = New NotifyDescription("OpenFileAfterConfirm", ThisObject);
		FormParameters = New Structure("Key", "BeforeOpenFile");
		OpenForm("CommonForm.SecurityWarning", FormParameters, , , , , Notification);
		Return;
	EndIf;
	
	FileBeingEdited = ValueIsFilled(ThisObject.Object.BeingEditedBy)
		AND ThisObject.Object.BeingEditedBy = CurrentUser;
	
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(ThisObject.Object.Ref, Undefined, UUID);
	
	FilesOperationsClient.OpenFile(FileData, FileBeingEdited);
	
EndProcedure

&AtClient
Procedure OpenFileAfterConfirm(Result, AdditionalParameters) Export
	
	If Result <> Undefined AND Result = "Continue" Then
		FileBeingEdited = ValueIsFilled(ThisObject.Object.BeingEditedBy)
			AND ThisObject.Object.BeingEditedBy = CurrentUser;
		
		FileData = FilesOperationsInternalServerCall.FileDataToOpen(ThisObject.Object.Ref, Undefined, UUID);
		
		FilesOperationsClient.OpenFile(FileData, FileBeingEdited);
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenFileDirectory()
	
	If IsNew()
		OR ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(ThisObject.Object.Ref, Undefined, UUID);
	FilesOperationsClient.OpenFileDirectory(FileData);
	
EndProcedure

&AtClient
Procedure SaveAs()
	
	If IsNew() Or ThisObject.Object.Encrypted Then
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataToSave(ThisObject.Object.Ref,, UUID);
	FilesOperationsInternalClient.SaveAs(Undefined, FileData, Undefined);
	
EndProcedure

&AtServer
Procedure DeleteFromSignatureListAndWriteFile()
	
	If Not Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
	
	RowIndexes = New Array;
	
	For Each SelectedRowNumber In Items.DigitalSignatures.SelectedRows Do
		RowToDelete = DigitalSignatures.FindByID(SelectedRowNumber);
		RowIndexes.Add(RowToDelete.SequenceNumber);
	EndDo;
	
	ObjectToWrite = FormAttributeToValue("Object");
	ModuleDigitalSignature.DeleteSignature(ObjectToWrite, RowIndexes);
	WriteFile(ObjectToWrite);
	ValueToFormAttribute(ObjectToWrite, "Object");
	
	FilesOperationsInternal.FillSignatureList(ThisObject);
	SetButtonsAvailability(ThisObject, Items);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetButtonsAvailability(Form, Items)
	
	AllCommandNames = AllFormCommandsNames();
	CommandsNames = AvailableFormCommands(Form);
		
	If Form.DigitalSignatures.Count() = 0 Then
		MakeCommandUnavailable(CommandsNames, "OpenSignature");
	EndIf;
	
	For Each FormItem In Items Do
		If TypeOf(FormItem) <> Type("FormButton") Then
			Continue;
		EndIf;
		If AllCommandNames.Find(FormItem.CommandName) <> Undefined Then
			FormItem.Enabled = False;
		EndIf;
	EndDo;
	
	For Each FormItem In Items Do
		If TypeOf(FormItem) <> Type("FormButton") Then
			Continue;
		EndIf;
		If CommandsNames.Find(FormItem.CommandName) <> Undefined Then
			FormItem.Enabled = True;
		EndIf;
	EndDo;
	
	PrintWithStampAvailable = Form["Object"].Extension = "mxl" AND Form["Object"].SignedWithDS;
	
	Items.PrintWithStamp.Visible = PrintWithStampAvailable;
	
	If Not PrintWithStampAvailable Then
		Items.PrintSubmenu.Type = FormGroupType.ButtonGroup;
		Items.Print.Title = NStr("ru='Печать'; en = 'Print'; pl = 'Drukuj';es_ES = 'Impresión';es_CO = 'Impresión';tr = 'Yazdır';it = 'Stampa';de = 'Drucken'");
	Else
		Items.PrintSubmenu.Type = FormGroupType.Popup;
		Items.Print.Title = NStr("ru='Сразу на принтер'; en = 'Directly to printer'; pl = 'Od razu do drukarki';es_ES = 'En seguida a la impresión';es_CO = 'En seguida a la impresión';tr = 'Doğrudan yazıcıya';it = 'Direttamente alla stampante';de = 'Direkt zum Drucker'");
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function AllFormCommandsNames()
	
	CommandsNames = FileChangeCommandsNames();
	CommonClientServer.SupplementArray(CommandsNames, OtherCommandsNames()); 
	Return CommandsNames;
	
EndFunction

&AtClientAtServerNoContext
Function OtherCommandsNames()
	
	CommandsNames = New Array;
	
	// Simple commands that are available to any user that reads the files
	CommandsNames.Add("SaveWithDigitalSignature");
	
	CommandsNames.Add("OpenCertificate");
	CommandsNames.Add("OpenSignature");
	CommandsNames.Add("VerifyDigitalSignature");
	CommandsNames.Add("CheckAll");
	CommandsNames.Add("SaveSignature");
	
	CommandsNames.Add("OpenFileDirectory");
	CommandsNames.Add("OpenFileForViewing");
	CommandsNames.Add("SaveAs");
	
	Return CommandsNames;
	
EndFunction

&AtClientAtServerNoContext
Function FileChangeCommandsNames()
	
	CommandsNames = New Array;
	
	CommandsNames.Add("Sign");
	CommandsNames.Add("AddDSFromFile");
	
	CommandsNames.Add("DeleteDigitalSignature");
	
	CommandsNames.Add("Edit");
	CommandsNames.Add("Lock");
	CommandsNames.Add("EndEdit");
	CommandsNames.Add("Unlock");
	CommandsNames.Add("SaveChanges");
	
	CommandsNames.Add("Encrypt");
	CommandsNames.Add("Decrypt");
	
	CommandsNames.Add("StandardCopy");
	CommandsNames.Add("UpdateFromFileOnHardDrive");
	
	CommandsNames.Add("StandardWrite");
	CommandsNames.Add("StandardWriteAndClose");
	CommandsNames.Add("StandardSetDeletionMark");
	
	Return CommandsNames;
	
EndFunction

&AtClientAtServerNoContext
Function AvailableFormCommands(Form)
	
	FormObject = Form["Object"];
	IsNewFile = FormObject.Ref.IsEmpty();
	
	If IsNewFile Then
		CommandsNames = New Array;
		CommandsNames.Add("StandardWrite");
		CommandsNames.Add("StandardWriteAndClose");
		Return CommandsNames;
	EndIf;
	
	CommandsNames = AllFormCommandsNames();
	
	FileToEditeInCloud = Form.FileToEditeInCloud;
	FileBeingEdited = ValueIsFilled(FormObject.BeingEditedBy) Or FileToEditeInCloud;
	CurrentUserEditsFile = FormObject.BeingEditedBy = Form.CurrentUser;
	FileSigned = FormObject.SignedWithDS;
	FileEncrypted = FormObject.Encrypted;
	
	If FileBeingEdited Then
		If CurrentUserEditsFile Then
			MakeCommandUnavailable(CommandsNames, "UpdateFromFileOnHardDrive");
		Else
			MakeCommandUnavailable(CommandsNames, "EndEdit");
			MakeCommandUnavailable(CommandsNames, "Unlock");
			MakeCommandUnavailable(CommandsNames, "Edit");
		EndIf;
		MakeCommandUnavailable(CommandsNames, "Lock");
		
		MakeDSCommandsUnavailable(CommandsNames);
		
		MakeCommandUnavailable(CommandsNames, "UpdateFromFileOnHardDrive");
		MakeCommandUnavailable(CommandsNames, "SaveAs");
		
		MakeCommandUnavailable(CommandsNames, "Encrypt");
		MakeCommandUnavailable(CommandsNames, "Decrypt");
	Else
		MakeCommandUnavailable(CommandsNames, "EndEdit");
		MakeCommandUnavailable(CommandsNames, "Unlock");
		MakeCommandUnavailable(CommandsNames, "SaveChanges");
	EndIf;
	
	If FileSigned Then
		MakeCommandUnavailable(CommandsNames, "EndEdit");
		MakeCommandUnavailable(CommandsNames, "Unlock");
		MakeCommandUnavailable(CommandsNames, "Edit");
		MakeCommandUnavailable(CommandsNames, "UpdateFromFileOnHardDrive");
	Else
		MakeCommandUnavailable(CommandsNames, "OpenCertificate");
		MakeCommandUnavailable(CommandsNames, "OpenSignature");
		MakeCommandUnavailable(CommandsNames, "VerifyDigitalSignature");
		MakeCommandUnavailable(CommandsNames, "CheckAll");
		MakeCommandUnavailable(CommandsNames, "SaveSignature");
		MakeCommandUnavailable(CommandsNames, "DeleteDigitalSignature");
		MakeCommandUnavailable(CommandsNames, "SaveWithDigitalSignature");
	EndIf;
	
	If FileEncrypted Then
		MakeDSCommandsUnavailable(CommandsNames);
		MakeCommandUnavailable(CommandsNames, "EndEdit");
		MakeCommandUnavailable(CommandsNames, "Unlock");
		MakeCommandUnavailable(CommandsNames, "Edit");
		
		MakeCommandUnavailable(CommandsNames, "UpdateFromFileOnHardDrive");
		
		MakeCommandUnavailable(CommandsNames, "Encrypt");
		
		MakeCommandUnavailable(CommandsNames, "OpenFileDirectory");
		MakeCommandUnavailable(CommandsNames, "OpenFileForViewing");
		MakeCommandUnavailable(CommandsNames, "SaveAs");
		
		MakeCommandUnavailable(CommandsNames, "Sign");
	Else
		MakeCommandUnavailable(CommandsNames, "Decrypt");
	EndIf;
	
	If FileToEditeInCloud Then
		MakeCommandUnavailable(CommandsNames, "StandardCopy");
		MakeCommandUnavailable(CommandsNames, "StandardSetDeletionMark");
		MakeCommandUnavailable(CommandsNames, "StandardWrite");
		MakeCommandUnavailable(CommandsNames, "StandardWriteAndClose");
		MakeCommandUnavailable(CommandsNames, "SaveChanges");
		
	EndIf;
	
	Return CommandsNames;
	
EndFunction

&AtClientAtServerNoContext
Procedure MakeDSCommandsUnavailable(Val CommandsNames)
	
	MakeCommandUnavailable(CommandsNames, "Sign");
	MakeCommandUnavailable(CommandsNames, "AddDSFromFile");
	MakeCommandUnavailable(CommandsNames, "SaveWithDigitalSignature");
	
EndProcedure

&AtClientAtServerNoContext
Procedure MakeCommandUnavailable(CommandsNames, CommandName)
	
	CommonClientServer.DeleteValueFromArray(CommandsNames, CommandName);
	
EndProcedure

&AtServer
Procedure EncryptServer(DataArrayToStoreInDatabase,
                            ThumbprintsArray,
                            FilesArrayInWorkingDirectoryToDelete,
                            WorkingDirectoryName)
	
	Encrypt = True;
	
	FilesOperationsInternal.WriteEncryptionInformation(
		ThisObject.Object.Ref,
		Encrypt,
		DataArrayToStoreInDatabase,
		UUID,
		WorkingDirectoryName,
		FilesArrayInWorkingDirectoryToDelete,
		ThumbprintsArray);
		
	UpdateInfoOfObjectCertificates();
	
EndProcedure

&AtServer
Procedure DecryptServer(DataArrayToStoreInDatabase, WorkingDirectoryName)
	
	Encrypt = False;
	ThumbprintsArray = New Array;
	FilesArrayInWorkingDirectoryToDelete = New Array;
	
	FilesOperationsInternal.WriteEncryptionInformation(
		ThisObject.Object.Ref,
		Encrypt,
		DataArrayToStoreInDatabase,
		UUID,
		WorkingDirectoryName,
		FilesArrayInWorkingDirectoryToDelete,
		ThumbprintsArray);
		
	UpdateInfoOfObjectCertificates();
	
EndProcedure

&AtServer
Procedure UpdateObject()
	
	ValueToFormAttribute(ThisObject.Object.Ref.GetObject(), "Object");
	SetButtonsAvailability(ThisObject, Items);
	
EndProcedure

&AtServer
Procedure UnlockFile()
	
	ObjectToWrite = FormAttributeToValue("Object");
	FilesOperationsInternal.UnlockFile(ObjectToWrite);
	ValueToFormAttribute(ObjectToWrite, "Object");
	
EndProcedure

&AtClient
Function HandleFileRecordCommand()
	
	If IsBlankString(ThisObject.Object.Description) Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Для продолжения укажите имя файла.'; en = 'To continue, specify the file name.'; pl = 'Aby kontynuować, podaj nazwę pliku.';es_ES = 'Para continuar, especificar el nombre del archivo.';es_CO = 'Para continuar, especificar el nombre del archivo.';tr = 'Devam etmek için dosya adını belirtin.';it = 'Per continuare, specificare il nome del file.';de = 'Um fortzufahren, geben Sie den Dateinamen an.'"), , "Description", "Object");
		Return False;
	EndIf;
	
	Try
		FilesOperationsInternalClient.CorrectFileName(ThisObject.Object.Description);
	Except
		CommonClientServer.MessageToUser(
			BriefErrorDescription(ErrorInfo()), ,"Description", "Object");
		Return False;
	EndTry;
	
	If NOT WriteFile() Then
		Return False;
	EndIf;
	
	Modified = False;
	RepresentDataChange(ThisObject.Object.Ref, DataChangeType.Update);
	NotifyChanged(ThisObject.Object.Ref);
	
	Notify("Write_File",
	           New Structure("IsNew, Event", FileCreated, "Write"),
	           ThisObject.Object.Ref);
	
	SetAvaliabilityOfDSCommandsList();
	SetAvaliabilityOfEncryptionList();
	
	If DescriptionBeforeWrite <> ThisObject.Object.Description Then
		// update file in cache
		FilesOperationsInternalClient.RefreshInformationInWorkingDirectory(
			ThisObject.Object.Ref, ThisObject.Object.Description);
		
		DescriptionBeforeWrite = ThisObject.Object.Description;
	EndIf;
	
	Return True;
	
EndFunction

&AtServer
Procedure RereadDataFromServer()
	
	FileObject = ThisObject.Object.Ref.GetObject();
	ValueToFormAttribute(FileObject, "Object");
	FilesOperationsInternal.FillSignatureList(ThisObject);
	FilesOperationsInternal.FillEncryptionList(ThisObject);
	
EndProcedure

&AtServer
Function WriteFile(Val ParameterObject = Undefined)
	
	If ParameterObject = Undefined Then
		ObjectToWrite = FormAttributeToValue("Object");
	Else
		ObjectToWrite = ParameterObject;
	EndIf;
	
	If ValueIsFilled(CopyingValue) Then
		BeginTransaction();
		Try
			BinaryData = FilesOperations.FileBinaryData(CopyingValue);
			
			If FilesOperationsInternal.FilesStorageTyoe() = Enums.FileStorageTypes.InInfobase Then
				NewRef = Catalogs[CatalogName].GetRef();
				ObjectToWrite.SetNewObjectRef(NewRef);
				FilesOperationsInternal.WriteFileToInfobase(NewRef, BinaryData);
				ObjectToWrite.FileStorageType = Enums.FileStorageTypes.InInfobase;
			Else
				FileInfo = FilesOperationsInternal.AddFileToVolume(BinaryData, ObjectToWrite.UniversalModificationDate,
				ObjectToWrite.Description, ObjectToWrite.Extension); 
				ObjectToWrite.Volume              = FileInfo.Volume;
				ObjectToWrite.PathToFile       = FileInfo.PathToFile;
				ObjectToWrite.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive;
			EndIf;
			
			If DigitalSignatureAvailable Then
				FilesOperationsInternal.MoveSignaturesCheckResults(DigitalSignatures, CopyingValue);
			EndIf;
			
			ObjectToWrite.Write();
			
			If DigitalSignatureAvailable AND Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
				ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
				
				SourceCertificates = ModuleDigitalSignature.EncryptionCertificates(CopyingValue);
				ModuleDigitalSignature.WriteEncryptionCertificates(ObjectToWrite, SourceCertificates);
				
				SetSignatures = ModuleDigitalSignature.SetSignatures(CopyingValue);
				ModuleDigitalSignature.AddSignature(ObjectToWrite, SetSignatures);
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	Else
		BeginTransaction();
		Try
			If DigitalSignatureAvailable Then
				FilesOperationsInternal.MoveSignaturesCheckResults(DigitalSignatures, ObjectToWrite.Ref);
			EndIf;
			ObjectToWrite.Write();
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndIf;
		
	If ParameterObject = Undefined Then
		ValueToFormAttribute(ObjectToWrite, "Object");
	EndIf;
	
	CopyingValue = Catalogs[CatalogName].EmptyRef();
	SetButtonsAvailability(ThisObject, Items);
	RefreshTitle();
	
	Return True;
	
EndFunction

&AtServerNoContext
Procedure UnlockObject(Val Ref, Val UUID)
	
	UnlockDataForEdit(Ref, UUID);
	
EndProcedure

// Print

&AtClient
Procedure FilePrint()
	
	Files = CommonClientServer.ValueInArray(ThisObject.Object.Ref);
	FilesOperationsClient.PrintFiles(Files, ThisObject.UUID);
	
EndProcedure

// Continue the SignDSFile procedure.
// It is called from the DigitalSignature subsystem after signing data for non-standard way of 
// adding a signature to the object.
//
&AtClient
Procedure OnGetSignature(ExecutionParameters, Context) Export
	
	UpdateInfoOfObjectSignature();
	SetAvaliabilityOfDSCommandsList();
	
EndProcedure

// Continue the SignDSFile procedure.
// It is called from the DigitalSignature subsystem after preparing signatures from files for 
// non-standard way of adding a signature to the object.
//
&AtClient
Procedure OnGetSignatures(ExecutionParameters, Context) Export
	
	UpdateInfoOfObjectSignature();
	SetAvaliabilityOfDSCommandsList();
	
EndProcedure

&AtServer
Procedure UpdateInfoOfObjectSignature()
	
	FileObject = ThisObject.Object.Ref.GetObject();
	ValueToFormAttribute(FileObject, "Object");
	FilesOperationsInternal.FillSignatureList(ThisObject);
	SetButtonsAvailability(ThisObject, Items);
	
EndProcedure

&AtServer
Procedure UpdateInfoOfObjectCertificates()
	
	FileObject = ThisObject.Object.Ref.GetObject();
	ValueToFormAttribute(FileObject, "Object");
	FilesOperationsInternal.FillEncryptionList(ThisObject);
	SetButtonsAvailability(ThisObject, Items);
	
EndProcedure

&AtClient
Procedure ReadAndSetFormItemsAvailability(Result, AdditionalParameters) Export
	
	ReadAndSetAvailabilityAtServer();
	
EndProcedure

&AtServer
Procedure ReadAndSetAvailabilityAtServer()
	
	FileObject = ThisObject.Object.Ref.GetObject();
	ValueToFormAttribute(FileObject, "Object");
	SetButtonsAvailability(ThisObject, Items);
	
EndProcedure

&AtClient
Procedure ReadSignaturesCertificates()
	
	If DigitalSignatures.Count() = 0 Then
		Return;
	EndIf;
	
	If Not CommonClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("ModuleDigitalSignatureClientServer", 
		CommonClient.CommonModule("DigitalSignatureClientServer"));
	
	CommonSettings = Context.ModuleDigitalSignatureClientServer.CommonSettings();
	
	If CommonSettings.VerifyDigitalSignaturesOnTheServer Then
		Return;
	EndIf;
	
	BeginAttachingCryptoExtension(New NotifyDescription(
		"ReadSignaturesCertificatesAfterAttachExtension", ThisObject, Context));
	
EndProcedure

// Continue the ReadSignaturesCertificates procedure.
&AtClient
Procedure ReadSignaturesCertificatesAfterAttachExtension(Attached, Context) Export
	
	If Not Attached Then
		Return;
	EndIf;
	
	ModuleDigitalSignatureClient = CommonClient.CommonModule("DigitalSignatureClient");
	
	ModuleDigitalSignatureClient.CreateCryptoManager(New NotifyDescription(
			"ReadSignaturesCertificatesAfterCreateCryptoManager", ThisObject, Context),
		"GetCertificates", False);
	
EndProcedure

// Continue the ReadSignaturesCertificates procedure.
&AtClient
Procedure ReadSignaturesCertificatesAfterCreateCryptoManager(Result, Context) Export
	
	If TypeOf(Result) <> Type("CryptoManager") Then
		Return;
	EndIf;
	
	Context.Insert("IndexOf", -1);
	Context.Insert("CryptoManager", Result);
	ReadSignaturesCertificatesLoopStart(Context);
	
EndProcedure

// Continue the ReadSignaturesCertificates procedure.
&AtClient
Procedure ReadSignaturesCertificatesLoopStart(Context)
	
	If DigitalSignatures.Count() <= Context.IndexOf + 1 Then
		Return;
	EndIf;
	Context.IndexOf = Context.IndexOf + 1;
	Context.Insert("TableRow", DigitalSignatures[Context.IndexOf]);
	
	If ValueIsFilled(Context.TableRow.Thumbprint) Then
		ReadSignaturesCertificatesLoopStart(Context);
		Return;
	EndIf;
	
	// The signature was not read when writing the object
	Signature = GetFromTempStorage(Context.TableRow.SignatureAddress);
	
	If Not ValueIsFilled(Signature) Then
		ReadSignaturesCertificatesLoopStart(Context);
		Return;
	EndIf;
	
	Context.CryptoManager.BeginGettingCertificatesFromSignature(New NotifyDescription(
			"ReadSignaturesCertificatesLoopAfterGetCertificatesFromSignature", ThisObject, Context,
			"ReadSignatureCertificatesLoopAfterGetCertificatesFromSignatureError", ThisObject),
		Signature);
	
EndProcedure

// Continue the ReadSignaturesCertificates procedure.
&AtClient
Procedure ReadSignatureCertificatesLoopAfterGetCertificatesFromSignatureError(ErrorInformation, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	ReadSignaturesCertificatesLoopStart(Context);
	
EndProcedure

// Continue the ReadSignaturesCertificates procedure.
&AtClient
Procedure ReadSignaturesCertificatesLoopAfterGetCertificatesFromSignature(Certificates, Context) Export
	
	If Certificates.Count() = 0 Then
		ReadSignaturesCertificatesLoopStart(Context);
		Return;
	EndIf;
	
	Context.Insert("Certificate", Certificates[0]);
	
	Context.Certificate.BeginUnloading(New NotifyDescription(
		"ReadSignaturesCertificatesLoopAfterExportCertificate", ThisObject, Context,
		"ReadSignatureCertificatesLoopAfterExportCertificateError", ThisObject));
	
EndProcedure

// Continue the ReadSignaturesCertificates procedure.
&AtClient
Procedure ReadSignatureCertificatesLoopAfterExportCertificateError(ErrorInformation, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	ReadSignaturesCertificatesLoopStart(Context);
	
EndProcedure

// Continue the ReadSignaturesCertificates procedure.
&AtClient
Procedure ReadSignaturesCertificatesLoopAfterExportCertificate(CertificateData, Context) Export
	
	TableRow = Context.TableRow;
	
	TableRow.Thumbprint = Base64String(Context.Certificate.Thumbprint);
	TableRow.CertificateAddress = PutToTempStorage(CertificateData, UUID);
	TableRow.CertificateOwner =
		Context.ModuleDigitalSignatureClientServer.SubjectPresentation(Context.Certificate);
	
	ReadSignaturesCertificatesLoopStart(Context);
	
EndProcedure

&AtClient
Function IsNew()
	
	Return ThisObject.Object.Ref.IsEmpty();
	
EndFunction

&AtClient
Procedure UpdateFromFileOnHardDriveCompletion(Result, ExecutionParameters) Export
	UpdateObjectDataAtServer();
	NotifyChanged(ThisObject.Object.Ref);
	Notify("Write_File", New Structure, ThisObject.Object.Ref);
EndProcedure

&AtServer
Procedure UpdateObjectDataAtServer()
	
	ValueToFormAttribute(ThisObject.Object.Ref.GetObject(), "Object");
	ModificationDate = ToLocalTime(ThisObject.Object.UniversalModificationDate);
	
EndProcedure

&AtClient
Procedure OnChangeSignatureOrEncryptionUsage()
	
	OnChangeUseSignOrEncryptionAtServer();
	DisplayAdditionalDataTabs();
	
EndProcedure

&AtServer
Procedure OnChangeUseSignOrEncryptionAtServer()
	
	FilesOperationsInternal.CryptographyOnCreateFormAtServer(ThisObject, False);
	
EndProcedure

&AtClient
Procedure GroupAdditionalPageDataOnChangePage(Item, CurrentPage)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties")
		AND CurrentPage.Name = "AdditionalAttributesGroup"
		AND Not ThisObject.PropertiesParameters.DeferredInitializationExecuted Then
		
		PropertiesExecuteDeferredInitialization();
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateCloudServiceNote(AttachedFile)
	
	NoteVisibility = False;
	
	If GetFunctionalOption("UseFileSync") Then
		
		SynchronizationInfo = FilesOperationsInternal.SynchronizationInfo(ThisObject.Object.FileOwner);
		
		If SynchronizationInfo.Count() > 0 Then
			
			Account = SynchronizationInfo.Account;
			FilesBeingEditedInCloudService = True;
			NoteVisibility = True;
			
			FolderAddressInCloudService = FilesOperationsInternalClientServer.AddressInCloudService(
				SynchronizationInfo.Service, SynchronizationInfo.Href);
				
			StringParts = New Array;
			StringParts.Add(NStr("ru = 'Файл доступен только для просмотра, работа с ним ведется в облачном сервисе'; en = 'This is a view-only file. File operations are carried out in cloud service'; pl = 'Plik jest dostępny tylko do wedługlądu, praca z nim jest prowadzona w serwisie w chmurze';es_ES = 'El archivo está disponible solo para ver, se usa en el servicio de nube';es_CO = 'El archivo está disponible solo para ver, se usa en el servicio de nube';tr = 'Dosya yalnızca salt okunur olarak kullanılabilir, bulut hizmeti ile çalışır.';it = 'Questo è un file di sola lettura. Le operazioni con file sono eseguite nel servizio in Cloud';de = 'Die Datei steht nur zur Ansicht zur Verfügung, die Bearbeitung erfolgt im Cloud-Service'"));
			StringParts.Add(" ");
			StringParts.Add(New FormattedString(SynchronizationInfo.AccountDescription,,,, FolderAddressInCloudService));
			StringParts.Add(".  ");
			Items.NoteDecoration.Title = New FormattedString(StringParts);
			
			Items.DecorationPictureSyncStatus.Visible = NOT SynchronizationInfo.Synchronized;
			Items.DecorationSyncDate.ToolTipRepresentation =?(SynchronizationInfo.Synchronized, ToolTipRepresentation.None, ToolTipRepresentation.Button);
			
			StringParts.Clear();
			StringParts.Add(NStr("ru = 'Синхронизирован'; en = 'Synchronized'; pl = 'Synchronizuje się';es_ES = 'Se está sincronizando';es_CO = 'Se está sincronizando';tr = 'Senkronize edildi';it = 'Sincronizzato';de = 'Synchronisiert'"));
			StringParts.Add(": ");
			StringParts.Add(New FormattedString(Format(SynchronizationInfo.SynchronizationDate, "DLF=DD"),,,, "OpenJournal"));
			Items.DecorationSyncDate.Title = New FormattedString(StringParts);
			
		EndIf;
		
	EndIf;
	
	Items.CloudServiceNoteGroup.Visible = NoteVisibility;
	
EndProcedure

&AtServerNoContext
Function EventLogFilterData(Account)
	Return FilesOperationsInternal.EventLogFilterData(Account);
EndFunction

#EndRegion
