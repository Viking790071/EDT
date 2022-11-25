
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	IsNewGroup = Parameters.IsNewGroup;
	
	If IsNewGroup Then
		ObjectValue               = Catalogs[Parameters.FilesStorageCatalogName].CreateFolder();
		
		If Parameters.Property("Parent") AND Parameters.Parent <> Undefined AND TypeOf(Parameters.Parent) = TypeOf(ObjectValue.Ref) Then
			If Parameters.Parent.IsFolder Then
				ObjectValue.Parent      = Parameters.Parent;
			ElsIf Parameters.Parent.Parent <> Undefined AND TypeOf(Parameters.Parent.Parent) = TypeOf(ObjectValue.Ref) Then
				ObjectValue.Parent      = Parameters.Parent.Parent; // As the first parent, the reference to the item was passed.
			EndIf;
		Else
			ObjectValue.Parent      = Undefined;
		EndIf;
		
		ObjectValue.FileOwner = Parameters.FileOwner;
		ObjectValue.CreationDate  = CurrentUniversalDate();
		ObjectValue.Author         = Users.AuthorizedUser();
	ElsIf ValueIsFilled(Parameters.CopyingValue) Then
		ObjectToCopy    = Parameters.CopyingValue.GetObject();
		CopyingValue = Parameters.CopyingValue;
		
		ObjectValue          = Catalogs[ObjectToCopy.Metadata().Name].CreateFolder();
		ObjectValue.Parent = Parameters.Parent;
		FillPropertyValues(ObjectValue, ObjectToCopy,
			"FileOwner, CreationDate, Details, Description, UniversalModificationDate, Changed");
		ObjectValue.Author = Users.AuthorizedUser();
	Else
		If ValueIsFilled(Parameters.AttachedFile) Then
			ObjectValue = Parameters.AttachedFile.GetObject();
		Else
			ObjectValue = Parameters.Key.GetObject();
		EndIf;
	EndIf;
	ObjectValue.Fill(Undefined);
	
	CatalogName = ObjectValue.Metadata().Name;
	
	SetUpFormObject(ObjectValue);
	
	If ReadOnly
		OR NOT AccessRight("Update", ThisObject.Object.FileOwner.Metadata()) Then
		Items.FormStandardWrite.Enabled                  = False;
		Items.FormStandardWriteAndClose.Enabled          = False;
		Items.FormStandardMarkForDeletion.Enabled = False;
	EndIf;
	
	If NOT ReadOnly
		AND NOT ThisObject.Object.Ref.IsEmpty() Then
		LockDataForEdit(ThisObject.Object.Ref, , UUID);
	EndIf;
	
	RefreshTitle();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure StandardWrite(Command)
	HandleFileRecordCommand();
EndProcedure

&AtClient
Procedure StandardWriteAndClose(Command)
	
	If HandleFileRecordCommand() Then
		Close();
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
Procedure StandardCopy(Command)
	
	If IsNew() Then
		Return;
	EndIf;
	
	FormParameters = New Structure("CopyingValue", ThisObject.Object.Ref);
	
	OpenForm("DataProcessor.FilesOperations.Form.GroupOfFiles", FormParameters);

EndProcedure

&AtClient
Procedure StandardShowInList(Command)
	
	StandardSubsystemsClient.ShowInList(ThisObject["Object"].Ref, Undefined);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetUpFormObject(Val NewObject)
	
	NewObjectType = New Array;
	NewObjectType.Add(TypeOf(NewObject));
	
	NewAttribute = New FormAttribute("Object", New TypeDescription(NewObjectType));
	NewAttribute.StoredData = True;
	
	AttributesToAdd = New Array;
	AttributesToAdd.Add(NewAttribute);
	
	ChangeAttributes(AttributesToAdd);
	
	ValueToFormAttribute(NewObject, "Object");
	
	For each Item In Items Do
		If TypeOf(Item) = Type("FormField")
			AND StrStartsWith(Item.DataPath, "PrototypeObject[0].")
			AND StrEndsWith(Item.Name, "0") Then
			
			ItemName = Left(Item.Name, StrLen(Item.Name) -1);
			If Items.Find(ItemName) <> Undefined Then
				Continue;
			EndIf;
			
			NewItem = Items.Insert(ItemName, TypeOf(Item), Item.Parent, Item);
			NewItem.DataPath = "Object." + Mid(Item.DataPath, StrLen("PrototypeObject[0].") + 1);
			
			If Item.Type = FormFieldType.LabelField Then
				PropertiesToExclude = "Name, DataPath";
			Else
				PropertiesToExclude = "Name, DataPath, SelectedText, TypeLink";
			EndIf;
			FillPropertyValues(NewItem, Item, , PropertiesToExclude);
			
			Item.Visible = False;
		EndIf;
	EndDo;
	
	StringParts = New Array;
	StringParts.Add(New FormattedString(
		String(ThisObject["Object"].Author),
		,
		,
		,
		GetURL(ThisObject["Object"].Author)));
	
	CreatedStatus = New FormattedString(StringParts);
	
	RefreshInformationAboutChange();
	
	If Parameters.Property("Parent") Then
		NewObject.Parent = Parameters.Parent;
	EndIf;
	
	If Not NewObject.IsNew() Then
		URL = GetURL(NewObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshTitle()
	
	If ValueIsFilled(ThisObject.Object.Ref) Then
		Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '%1 (Группа файлов)'; en = '%1 (File group)'; pl = '%1 (Grupa plików)';es_ES = '%1 (Grupo de archivos)';es_CO = '%1 (Grupo de archivos)';tr = '%1 (Dosya grubu)';it = '%1 (Gruppo file)';de = '%1 (Datei-Gruppe)'"), String(ThisObject.Object.Ref));
	Else
		Title = NStr("ru = 'Группа файлов (создание)'; en = 'File group (Create)'; pl = 'Grupa plików (Tworzenie)';es_ES = 'Grupo de archivos (Crear)';es_CO = 'Grupo de archivos (Crear)';tr = 'Dosya grubu (Oluştur)';it = 'Gruppo gile (Creare)';de = 'Dateigruppe (Erstellung)'")
	EndIf;
	
EndProcedure

&AtClient
Function HandleFileRecordCommand()
	
	ClearMessages();
	
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
				New Structure("IsNew", FileCreated),
				ThisObject.Object.Ref);
	
	Return True;
	
EndFunction

&AtClient
Function IsNew()
	
	Return ThisObject.Object.Ref.IsEmpty();
	
EndFunction

&AtServer
Function WriteFile(Val ParameterObject = Undefined)
	
	If ParameterObject = Undefined Then
		ObjectToWrite = FormAttributeToValue("Object");
	Else
		ObjectToWrite = ParameterObject;
	EndIf;
	
	BeginTransaction();
	Try
		ObjectToWrite.Changed                      = Users.AuthorizedUser();
		ObjectToWrite.UniversalModificationDate = CurrentUniversalDate();
		ObjectToWrite.Write();
		
		CommitTransaction();
	Except
		
		RollbackTransaction();
		WriteLogEvent(NStr("ru = 'Файлы.Ошибка записи группы присоединенных файлов'; en = 'Files.Error writing attached files group'; pl = 'Pliki.Błąd zapisu grupy załączników';es_ES = 'Archivos.Error de guardar los grupos de los archivos adjuntos';es_CO = 'Archivos.Error de guardar los grupos de los archivos adjuntos';tr = 'Dosyalar. Ekli dosyalar grubunun kayıt hatası';it = 'File. Errore di scrittura del gruppo di file allegati';de = 'Dateien.Fehler beim Schreiben der Gruppe Dateianhang'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()) );
		Raise;
		
	EndTry;
	
	If ParameterObject = Undefined Then
		ValueToFormAttribute(ObjectToWrite, "Object");
	EndIf;
	
	CopyingValue = Catalogs[CatalogName].EmptyRef();
	
	RefreshTitle();
	RefreshInformationAboutChange();
	
	Return True;
	
EndFunction

&AtClient
Procedure StandardRereadAnswerReceived(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		RereadDataFromServer();
		Modified = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure RereadDataFromServer()
	
	FileObject = ThisObject.Object.Ref.GetObject();
	ValueToFormAttribute(FileObject, "Object");
	
	RefreshInformationAboutChange();

EndProcedure

&AtServer
Procedure RefreshInformationAboutChange()
	
	StringParts = New Array;
	StringParts.Add(New FormattedString(
		String(ThisObject["Object"].Changed),
		,
		,
		,
		GetURL(ThisObject["Object"].Changed)));
	
	ChangedStatus = New FormattedString(StringParts);
	
EndProcedure

#EndRegion