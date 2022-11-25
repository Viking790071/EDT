
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
		
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	ObjectValue = Parameters.Key.GetObject();
	ObjectValue.Fill(Undefined);

	CatalogName = ObjectValue.Metadata().Name;
	
	ErrorTitle = NStr("ru = 'Ошибка при настройке формы элемента присоединенных файлов.'; en = 'An error occurred when setting up an attached file item form.'; pl = 'Błąd podczas konfiguracji formularzu elementu dołączonych plików.';es_ES = 'Error al ajustar el formulario del elemento de los archivos adjuntos.';es_CO = 'Error al ajustar el formulario del elemento de los archivos adjuntos.';tr = 'Ekli dosyaların unsur biçimi yapılandırırken bir hata oluştu.';it = 'Si è verificato un errore durante l''impostazione di un modulo di elemento del file allegato.';de = 'Fehler beim Einrichten des Formulars der angehängten Artikelinformation.'");
	ErrorEnd = NStr("ru = 'В этом случае настройка формы элемента невозможна.'; en = 'In this case, you cannot set item forms.'; pl = 'W tym przypadku konfiguracja formularzu elementu nie jest możliwe.';es_ES = 'En este caso es imposible ajustar el formulario del elemento.';es_CO = 'En este caso es imposible ajustar el formulario del elemento.';tr = 'Bu durumda, unsur biçimi yapılandırılamaz.';it = 'In questo caso, non è possibile impostare moduli di elemento.';de = 'In diesem Fall ist die Einstellung der Elementform nicht möglich.'");
	
	FileVersionsStorageCatalogName = FilesOperationsInternal.FilesVersionsStorageCatalogName(
		TypeOf(ObjectValue.Owner.FileOwner), "", ErrorTitle, ErrorEnd);
	
	SetUpFormObject(ObjectValue);

	If TypeOf(ThisObject.Object.Owner) = Type("CatalogRef.Files") Then
		Items.FullDescr.ReadOnly = True;
	EndIf;
	
	If Users.IsFullUser() Then
		Items.Author0.ReadOnly = False;
		Items.CreationDate0.ReadOnly = False;
	Else
		Items.LocationGroup.Visible = False;
	EndIf;
	
	VolumeFullPath = FilesOperationsInternal.FullVolumePath(ThisObject.Object.Volume);
	
	CommonSettings = FilesOperationsInternalClientServer.CommonFilesOperationsSettings();
	
	FileExtensionInList = FilesOperationsInternalClientServer.FileExtensionInList(
		CommonSettings.TestFilesExtensionsList, ThisObject.Object.Extension);
	
	If FileExtensionInList Then
		If ValueIsFilled(ThisObject.Object.Ref) Then
			
			EncodingValue = FilesOperationsInternalServerCall.GetFileVersionEncoding(ThisObject.Object.Ref);
			
			EncodingsList = FilesOperationsInternal.Encodings();
			ListItem = EncodingsList.FindByValue(EncodingValue);
			If ListItem = Undefined Then
				Encoding = EncodingValue;
			Else	
				Encoding = ListItem.Presentation;
			EndIf;
			
		EndIf;
		
		If Not ValueIsFilled(Encoding) Then
			Encoding = NStr("ru='По умолчанию'; en = 'Default'; pl = 'Domyślnie';es_ES = 'Por defecto';es_CO = 'Por defecto';tr = 'Varsayılan';it = 'Predefinito';de = 'Standard'");
		EndIf;
	Else
		Items.Encoding.Visible = False;
	EndIf;
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		CommonClientServer.SetFormItemProperty(Items, "StandardWriteAndClose", "Representation", ButtonRepresentation.Picture);
		
		If Items.Find("Comment") <> Undefined Then
			
			CommonClientServer.SetFormItemProperty(Items, "Comment", "MaxHeight", 2);
			CommonClientServer.SetFormItemProperty(Items, "Comment", "AutoMaxHeight", False);
			CommonClientServer.SetFormItemProperty(Items, "Comment", "VerticalStretch", False);
			
		EndIf;
		
		If Items.Find("Comment0") <> Undefined Then
			
			CommonClientServer.SetFormItemProperty(Items, "Comment0", "MaxHeight", 2);
			CommonClientServer.SetFormItemProperty(Items, "Comment0", "AutoMaxHeight", False);
			CommonClientServer.SetFormItemProperty(Items, "Comment0", "VerticalStretch", False);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure OpenExecute()
	
	VersionRef = ThisObject.Object.Ref;
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(ThisObject.Object.Owner, VersionRef, UUID);
	FilesOperationsInternalClient.OpenFileVersion(Undefined, FileData, UUID);
	
EndProcedure

&AtClient
Procedure FullDescriptionOnChange(Item)
	ThisObject.Object.Description = ThisObject.Object.FullDescr;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SaveAs(Command)
	
	VersionRef = ThisObject.Object.Ref;
	FileData = FilesOperationsInternalServerCall.FileDataToSave(ThisObject.Object.Owner, VersionRef, UUID);
	FilesOperationsInternalClient.SaveAs(Undefined, FileData, UUID);
	
EndProcedure

&AtClient
Procedure StandardWrite(Command)
	ProcessWriteFileVersionCommand();
EndProcedure

&AtClient
Procedure StandardWriteAndClose(Command)
	
	If ProcessWriteFileVersionCommand() Then
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
			
			If Items.Find(ItemName) <> Undefined  Then
				Continue;
			EndIf;
			
			NewItem = Items.Insert(ItemName, TypeOf(Item), Item.Parent, Item);
			NewItem.DataPath = "Object." + Mid(Item.DataPath, StrLen("PrototypeObject[0].") + 1);
			
			If Item.Type = FormFieldType.CheckBoxField Or Item.Type = FormFieldType.PictureField Then
				PropertiesToExclude = "Name, DataPath";
			Else
				PropertiesToExclude = "Name, DataPath, SelectedText, TypeLink";
			EndIf;
			FillPropertyValues(NewItem, Item, , PropertiesToExclude);
			Item.Visible = False;
		EndIf;
	EndDo;
	
	If Not NewObject.IsNew() Then
		ThisObject.URL = GetURL(NewObject);
	EndIf;

EndProcedure

&AtClient
Function ProcessWriteFileVersionCommand()
	
	If IsBlankString(ThisObject.Object.FullDescr) Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Для продолжения укажите имя версии файла.'; en = 'Specify file version name to continue.'; pl = 'Aby kontynuować, wprowadź nazwę wersji pliku.';es_ES = 'Para continuar especifique el nombre de la versión del archivo.';es_CO = 'Para continuar especifique el nombre de la versión del archivo.';tr = 'Devam etmek için dosya sürümün adını belirtin.';it = 'Specificare il nome della versione di file per continuare.';de = 'Um fortzufahren, geben Sie den Namen der Dateiversion an.'"), , "Description", "Object");
		Return False;
	EndIf;
	
	Try
		FilesOperationsInternalClient.CorrectFileName(ThisObject.Object.FullDescr);
	Except
		CommonClientServer.MessageToUser(
			BriefErrorDescription(ErrorInfo()), ,"Description", "Object");
		Return False;
	EndTry;
	
	If NOT WriteFileVersion() Then
		Return False;
	EndIf;
	
	Modified = False;
	RepresentDataChange(ThisObject.Object.Ref, DataChangeType.Update);
	NotifyChanged(ThisObject.Object.Ref);
	Notify("Write_File", New Structure("Event", "VersionSaved"), ThisObject.Object.Owner);
	Notify("Write_FileVersion",
	           New Structure("IsNew", False),
	           ThisObject.Object.Ref);
	
	Return True;
	
EndFunction

&AtServer
Function WriteFileVersion(Val ParameterObject = Undefined)
	
	If ParameterObject = Undefined Then
		ObjectToWrite = FormAttributeToValue("Object");
	Else
		ObjectToWrite = ParameterObject;
	EndIf;
	
	BeginTransaction();
	Try
		
		ObjectToWrite.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("ru = 'Файлы.Ошибка записи версии присоединенного файла'; en = 'Files.An error occurred when writing attached file version'; pl = 'Plik.Błąd zapisu wersji załączonego pliku';es_ES = 'Archivos.Error de guardar la versión del archivo adjunto';es_CO = 'Archivos.Error de guardar la versión del archivo adjunto';tr = 'Dosyalar. Ekli dosya kaydedilirken bir hata oluştu.';it = 'File. Errore durante la scrittura della versione di file allegato';de = 'Dateien.Fehler beim Schreiben der Version der angehängten Datei'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
	If ParameterObject = Undefined Then
		ValueToFormAttribute(ObjectToWrite, "Object");
	EndIf;
	
	Return True;
	
EndFunction

&AtServer
Procedure RereadDataFromServer()
	
	FileObject = ThisObject.Object.Ref.GetObject();
	ValueToFormAttribute(FileObject, "Object");
	
EndProcedure

&AtClient
Procedure StandardRereadAnswerReceived(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		RereadDataFromServer();
		Modified = False;
	EndIf;
	
EndProcedure

&AtClient
Function IsNew()
	
	Return ThisObject.Object.Ref.IsEmpty();
	
EndFunction

#EndRegion