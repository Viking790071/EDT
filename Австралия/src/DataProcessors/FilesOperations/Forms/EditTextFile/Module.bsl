
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	File = Parameters.File;
	FileData = Parameters.FileData;
	FileNameToOpen = Parameters.FileNameToOpen;
	
	If FileData.CurrentUserEditsFile Then
		EditMode = True;
	EndIf;
	
	If FileData.Version <> FileData.CurrentVersion Then
		EditMode = False;
	EndIf;
	
	Items.Text.ReadOnly                = Not EditMode;
	Items.ShowDifferences.Visible           = CommonClientServer.IsWindowsClient();
	Items.ShowDifferences.Enabled         = EditMode;
	Items.Edit.Enabled           = Not EditMode;
	Items.EndEdit.Enabled = EditMode;
	Items.WriteAndClose.Enabled        = EditMode;
	Items.Write.Enabled                = EditMode;
	Items.FormSelectEncoding.Enabled   = EditMode;
	
	If FileData.Version <> FileData.CurrentVersion Then
		Items.Edit.Enabled = False;
	EndIf;
	
	TitleRow = CommonClientServer.GetNameWithExtension(
		FileData.FullVersionDescription, FileData.Extension);
	
	If Not EditMode Then
		TitleRow = TitleRow + " " + NStr("ru='(только просмотр)'; en = '(view only)'; pl = '(tylko podgląd)';es_ES = '(solo ver)';es_CO = '(solo ver)';tr = '(salt okunur)';it = '(solo visualizzazione)';de = '(nur Ansicht)'");
	EndIf;
	Title = TitleRow;
	
	If FileData.Property("Encoding") Then
		FileTextEncoding = FileData.Encoding;
	EndIf;
	
	If ValueIsFilled(FileTextEncoding) Then
		EncodingsList = FilesOperationsInternal.Encodings();
		ListItem = EncodingsList.FindByValue(FileTextEncoding);
		If ListItem = Undefined Then
			EncodingPresentation = FileTextEncoding;
		Else
			EncodingPresentation = ListItem.Presentation;
		EndIf;
	Else
		EncodingPresentation = NStr("ru='По умолчанию'; en = 'Default'; pl = 'Domyślnie';es_ES = 'Por defecto';es_CO = 'Por defecto';tr = 'Varsayılan';it = 'Predefinito';de = 'Standard'");
	EndIf;
	
	If UsersClientServer.IsExternalUserSession() Then
		
		Items.WriteAndClose.Enabled		= False;
		Items.Write.Enabled				= False;
		Items.Edit.Enabled				= False;
		Items.EndEdit.Enabled			= False;
		Items.OpenCard.Enabled			= False;
		Items.ShowDifferences.Enabled	= False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	Text.Read(FileNameToOpen, TextEncodingForRead());
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_File"
	   AND Parameter.Property("Event")
	   AND Parameter.Event = "FileWasEdited"
	   AND Source = File Then
		
		EditMode = True;
		SetCommandsAvailability();
	EndIf;
	
	If EventName = "Write_File"
	   AND Parameter.Property("Event")
	   AND Parameter.Event = "FileDataChanged"
	   AND Source = File Then
		
		FileData = FilesOperationsInternalServerCall.FileData(File);
		
		EditMode = False;
		
		If FileData.CurrentUserEditsFile Then
			EditMode = True;
		EndIf;
		
		If FileData.Version <> FileData.CurrentVersion Then
			EditMode = False;
		EndIf;
		
		SetCommandsAvailability();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Not Modified Then
		Return;
	EndIf;
	
	Cancel = True;
	
	NameAndExtension = CommonClientServer.GetNameWithExtension(
		FileData.FullVersionDescription,
		FileData.Extension);
	
	If Exit Then
		WarningText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru ='Изменения в файле ""%1"" будут потеряны.'; en = 'Changes in the ""%1"" file will be lost.'; pl = 'Zmiany w pliku ""%1"" zostaną utracone.';es_ES = 'Los cambios en el archivo ""%1"" serán perdidos.';es_CO = 'Los cambios en el archivo ""%1"" serán perdidos.';tr = '""%1"" dosyasındaki değişiklikler kaybedilecekler.';it = 'Le modifiche nel file ""%1"" andranno perse.';de = 'Änderungen an der Datei ""%1"" gehen verloren.'"), NameAndExtension);
		Return;
	EndIf;

	ResultHandler = New NotifyDescription("BeforeCloseAfterAnswerQuestionOnClosingTextEditor", ThisObject);
	ReminderText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru ='Файл ""%1"" был изменен.
			|Сохранить изменения?'; 
			|en = 'The ""%1"" file was changed.
			|Save the changes?'; 
			|pl = 'Plik ""%1"" został zmieniony.
			|Zapisać zmiany?';
			|es_ES = 'El archivo ""%1"" ha sido cambiado.
			|¿Guardar los cambios?';
			|es_CO = 'El archivo ""%1"" ha sido cambiado.
			|¿Guardar los cambios?';
			|tr = '""%1"" dosyası değiştirildi.
			|Değişiklikler kaydedilsin mi?';
			|it = 'Il file ""%1"" è stato modificato.
			|Salvare le modifiche?';
			|de = 'Die Datei ""%1"" wurde geändert.
			|Änderungen speichern?'"), 
		NameAndExtension);
	Buttons = New ValueList;
	Buttons.Add("Save", NStr("ru = 'Записать'; en = 'Save'; pl = 'Zapisz';es_ES = 'Guardar';es_CO = 'Guardar';tr = 'Sakla';it = 'Salva';de = 'Speichern'"));
	Buttons.Add("DoNotSave", NStr("ru = 'Не сохранять'; en = 'Do not save'; pl = 'Nie zapisuj';es_ES = 'No guardar';es_CO = 'No guardar';tr = 'Kaydetme';it = 'Non salvare';de = 'Nicht speichern'"));
	Buttons.Add("Cancel",  NStr("ru = 'Отмена'; en = 'Cancel'; pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = 'İptal et';it = 'Annulla';de = 'Abbrechen'"));
	ReminderParameters = New Structure;
	ReminderParameters.Insert("Picture", PictureLib.Information32);
	ReminderParameters.Insert("Title", NStr("ru = 'Внимание'; en = 'Warning'; pl = 'Ostrzeżenie';es_ES = 'Aviso';es_CO = 'Aviso';tr = 'Uyarı';it = 'Attenzione';de = 'Warnung'"));
	ReminderParameters.Insert("SuggestDontAskAgain", False);
	StandardSubsystemsClient.ShowQuestionToUser(
			ResultHandler, ReminderText, Buttons, ReminderParameters);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SaveAs(Command)
	
	// Selecting a full path to the file on the hard drive.
	SelectFile = New FileDialog(FileDialogMode.Save);
	SelectFile.Multiselect = False;
	
	NameWithExtension = CommonClientServer.GetNameWithExtension(
		FileData.FullVersionDescription, FileData.Extension);
	
	SelectFile.FullFileName = NameWithExtension;
	Filter = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Все файлы (*.%1)|*.%1'; en = 'All files  (*.%1)|*.%1'; pl = 'Wszystkie pliki (*.%1)|*.%1';es_ES = 'Todos archivos (*.%1)|*.%1';es_CO = 'Todos archivos (*.%1)|*.%1';tr = 'Tüm dosyalar (*.%1)|*.%1';it = 'Tutti i file (*.%1)|*.%1';de = 'Alle Dateien (*.%1)| *.%1'"), FileData.Extension);
	SelectFile.Filter = Filter;
	
	If SelectFile.Choose() Then
		
		SelectedFullFileName = SelectFile.FullFileName;
		WriteTextToFile(SelectedFullFileName);
		
		ShowUserNotification(NStr("ru = 'Файл успешно сохранен'; en = 'File saved'; pl = 'Zapis pliku zakończony pomyślnie';es_ES = 'Archivo se ha guardado con éxito';es_CO = 'Archivo se ha guardado con éxito';tr = 'Dosya başarıyla kaydedildi';it = 'File salvato';de = 'Die Datei wurde erfolgreich gespeichert'"), , SelectedFullFileName);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenCard(Command)
	
	ShowValue(, File);
	
EndProcedure

&AtClient
Procedure ExternalEditor(Command)
	
	WriteText();
	CommonClient.OpenFileInViewer(FileNameToOpen);
	Close();
	
EndProcedure

&AtClient
Procedure Edit(Command)
	
	FilesOperationsInternalClient.EditWithNotification(Undefined, File, UUID);
	
EndProcedure

&AtClient
Procedure Write(Command)
	
	WriteText();
	
	Handler = New NotifyDescription("EndEditingCompletion", ThisObject);
	FileUpdateParameters = FilesOperationsInternalClient.FileUpdateParameters(Handler, File, UUID);
	FileUpdateParameters.Encoding = FileTextEncoding;
	FilesOperationsInternalClient.SaveFileChangesWithNotification(Handler, File, UUID);
		
EndProcedure

&AtClient
Procedure EndEdit(Command)
	
	WriteText();
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("Scenario", "EndEdit");
	Handler = New NotifyDescription("EndEditingCompletion", ThisObject, HandlerParameters);
	
	FileUpdateParameters = FilesOperationsInternalClient.FileUpdateParameters(Handler, File, UUID);
	FileUpdateParameters.Encoding = FileTextEncoding;
	FilesOperationsInternalClient.EndEditAndNotify(FileUpdateParameters);
	
EndProcedure

&AtClient
Procedure ShowDifferences(Command)
	
#If WebClient Then
	ShowMessageBox(, NStr("ru = 'Сравнение версий файлов в веб-клиенте недоступно.'; en = 'Version comparison is not available in web client.'; pl = 'Porównanie wersji plików w kliencie Web jest niedostępne.';es_ES = 'No está disponible comparar las versiones de archivos en el cliente web.';es_CO = 'No está disponible comparar las versiones de archivos en el cliente web.';tr = 'Web istemcide dosya sürümleri karşılaştırılamaz.';it = 'Comparazione delle versioni non è disponibile nel web client.';de = 'Der Vergleich von Dateiversionen im Webclient ist nicht möglich.'"));
	Return;
#ElsIf MobileClient Then
	ShowMessageBox(, NStr("ru = 'Сравнение версий файлов в мобильном клиенте недоступно.'; en = 'File version comparison is unavailable in mobile client.'; pl = 'Porównanie wersji plików w mobilnej aplikacji jest niedostępne.';es_ES = 'No está disponible comparar las versiones de archivos en el cliente móvil.';es_CO = 'No está disponible comparar las versiones de archivos en el cliente móvil.';tr = 'Mobil istemciden dosya sürümleri karşılaştırılamaz.';it = 'Comparazione delle versioni di file non è disponibile nel client mobile.';de = 'Der Vergleich von Dateiversionen im mobilen Client ist nicht möglich.'"));
	Return;
#Else
	ExecutionParameters = New Structure;
	ExecutionParameters.Insert("CurrentStep", 1);
	ExecutionParameters.Insert("FileVersionsComparisonMethod", Undefined);
	ExecutionParameters.Insert("FullFileNameLeft", GetTempFileName(FileData.Extension));
	ExecuteCompareFiles(-1, ExecutionParameters);
#EndIf
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	WriteText();
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("Scenario", "WriteAndClose");
	Handler = New NotifyDescription("EndEditingCompletion", ThisObject, HandlerParameters);
	
	FileUpdateParameters = FilesOperationsInternalClient.FileUpdateParameters(Handler, File, UUID);
	FileUpdateParameters.Encoding = FileTextEncoding;
	FilesOperationsInternalClient.EndEditAndNotify(FileUpdateParameters);
	
EndProcedure

&AtClient
Procedure SelectEncoding(Command)
	FormParameters = New Structure;
	FormParameters.Insert("CurrentEncoding", FileTextEncoding);
	Handler = New NotifyDescription("SelectEncodingCompletion", ThisObject);
	OpenForm("DataProcessor.FilesOperations.Form.SelectEncoding", FormParameters, ThisObject, , , , Handler);
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure BeforeCloseAfterAnswerQuestionOnClosingTextEditor(Result, ExecutionParameters) Export
	
	If Result.Value = "Save" Then
		
		WriteText();
		HandlerParameters = New Structure;
		HandlerParameters.Insert("Scenario", "Close");
		Handler = New NotifyDescription("EndEditingCompletion", ThisObject, HandlerParameters);
		FileUpdateParameters = FilesOperationsInternalClient.FileUpdateParameters(Handler, File, UUID);
		FileUpdateParameters.Encoding = FileTextEncoding;
		FilesOperationsInternalClient.EndEditAndNotify(FileUpdateParameters);
		
	ElsIf Result.Value = "DoNotSave" Then
		
		Modified = False;
		Close();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectEncodingCompletion(Result, ExecutionParameters) Export
	
	If TypeOf(Result) <> Type("Structure") Then
		Return;
	EndIf;
	
	Modified     = True;
	FileTextEncoding   = Result.Value;
	EncodingPresentation = Result.Presentation;
	
	ReadText();
	
EndProcedure

&AtClient
Procedure EndEditingCompletion(Result, ExecutionParameters) Export
	If Result <> True Then
		Return;
	EndIf;
	
	If ExecutionParameters.Scenario = "EndEdit" Then
		EditMode = False;
		SetCommandsAvailability();
	ElsIf ExecutionParameters.Scenario = "WriteAndClose" Then
		EditMode = False;
		SetCommandsAvailability();
		Close();
	ElsIf ExecutionParameters.Scenario = "Close" Then
		Modified = False;
		Close();
	EndIf;
EndProcedure

&AtClient
Procedure WriteText()
	
	If Not Modified Then
		Return;
	EndIf;
	
	WriteTextToFile(FileNameToOpen);
	Modified = False;
	
EndProcedure

&AtClient
Procedure WriteTextToFile(FileName)
	
	If FileTextEncoding = "utf-8_WithoutBOM" Then
		
		BinaryData = GetBinaryDataFromString(Text.GetText(), "utf-8", False);
		BinaryData.Write(FileName);
		
	Else
		
		Text.Write(FileName,
			?(ValueIsFilled(FileTextEncoding), FileTextEncoding, Undefined));
		
	EndIf;
	
	FilesOperationsInternalServerCall.WriteFileVersionEncodingAndExtractedText(
		FileData.Version, FileTextEncoding, Text.GetText());
	
EndProcedure

&AtClient
Procedure SetCommandsAvailability()
	
	Items.Text.ReadOnly                = Not EditMode;
	Items.ShowDifferences.Enabled         = EditMode;
	Items.Edit.Enabled           = Not EditMode;
	Items.EndEdit.Enabled = EditMode;
	Items.WriteAndClose.Enabled        = EditMode;
	Items.Write.Enabled                = EditMode;
	Items.FormSelectEncoding.Enabled   = EditMode;
	
	TitleRow = CommonClientServer.GetNameWithExtension(
		FileData.FullVersionDescription, FileData.Extension);
	
	If Not EditMode Then
		TitleRow = TitleRow + " " + NStr("ru='(только просмотр)'; en = '(view only)'; pl = '(tylko podgląd)';es_ES = '(solo ver)';es_CO = '(solo ver)';tr = '(salt okunur)';it = '(solo visualizzazione)';de = '(nur Ansicht)'");
	EndIf;
	Title = TitleRow;
	
EndProcedure

&AtClient
Procedure ReadText()
	
	Text.Read(FileNameToOpen, TextEncodingForRead());
	
EndProcedure

&AtClient
Function TextEncodingForRead()
	
	TextEncodingForRead = ?(ValueIsFilled(FileTextEncoding), FileTextEncoding, Undefined);
	If TextEncodingForRead = "utf-8_WithoutBOM" Then
		TextEncodingForRead = "utf-8";
	EndIf;
	
	Return TextEncodingForRead;
	
EndFunction

&AtClient
Procedure ExecuteCompareFiles(Result, ExecutionParameters) Export
	If ExecutionParameters.CurrentStep = 1 Then
		PersonalSettings = FilesOperationsInternalClientServer.PersonalFilesOperationsSettings();
		ExecutionParameters.FileVersionsComparisonMethod = PersonalSettings.FileVersionsComparisonMethod;
		// First call means that setting has not been initialized yet.
		If ExecutionParameters.FileVersionsComparisonMethod = Undefined Then
			Handler = New NotifyDescription("ExecuteCompareFiles", ThisObject, ExecutionParameters);
			OpenForm("DataProcessor.FilesOperations.Form.SelectVersionCompareMethod", , ThisObject, , , , Handler);
			ExecutionParameters.CurrentStep = 1.1;
			Return;
		EndIf;
		ExecutionParameters.CurrentStep = 2;
	ElsIf ExecutionParameters.CurrentStep = 1.1 Then
		If Result <> DialogReturnCode.OK Then
			Return;
		EndIf;
		PersonalSettings = FilesOperationsInternalClientServer.PersonalFilesOperationsSettings();
		ExecutionParameters.FileVersionsComparisonMethod = PersonalSettings.FileVersionsComparisonMethod;
		If ExecutionParameters.FileVersionsComparisonMethod = Undefined Then
			Return;
		EndIf;
		ExecutionParameters.CurrentStep = 2;
	EndIf;
	
	If ExecutionParameters.CurrentStep = 2 Then
		// Saving file for the right part.
		WriteText(); // Full name is placed to the FileToOpenName attribute.
		
		// Saving file for the left part.
		If FileData.CurrentVersion = FileData.Version Then
			LeftFileData = FilesOperationsInternalServerCall.FileDataToSave(File, , UUID);
			LeftFileAddress = LeftFileData.CurrentVersionURL;
		Else
			LeftFileAddress = FilesOperationsInternalServerCall.GetURLToOpen(
				FileData.Version,
				UUID);
		EndIf;
		FilesToTransfer = New Array;
		FilesToTransfer.Add(New TransferableFileDescription(ExecutionParameters.FullFileNameLeft, LeftFileAddress));
		If Not GetFiles(FilesToTransfer,, ExecutionParameters.FullFileNameLeft, False) Then
			Return;
		EndIf;
		
		// Comparison.
		FilesOperationsInternalClient.ExecuteCompareFiles(
			ExecutionParameters.FullFileNameLeft,
			FileNameToOpen,
			ExecutionParameters.FileVersionsComparisonMethod);
	EndIf;
EndProcedure

#EndRegion
