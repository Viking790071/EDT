#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	IsNew = Object.Ref.IsEmpty();
	
	Items.FormLoadFromFile.Enabled = Not Object.IsFilled;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If DataProcessorRegistration Then
		DataProcessorBinaryData = GetFromTempStorage(DataProcessorDataAddress);
		CurrentObject.TemplateStorage = New ValueStorage(DataProcessorBinaryData, New Deflation(9));
		CurrentObject.IsFilled = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If Not Object.IsFilled 
		And Not DataProcessorRegistration Then
		
		TextMessage = NStr("en = 'A report template file is required. Click ""Load from file"" and select the file.'; ru = 'Требуется файл шаблона отчета. Щелкните ""Загрузить из файла"" и выберите нужный файл.';pl = 'Wymagany jest plik szablonu raportu. Kliknij ""Pobierz z pliku"" i wybierz plik.';es_ES = 'Se requiere un archivo de modelo de informe. Hacer clic en ""Cargar del archivo"" y seleccione el archivo.';es_CO = 'Se requiere un archivo de modelo de informe. Hacer clic en ""Cargar del archivo"" y seleccione el archivo.';tr = 'Rapor şablonu dosyası gerekli. ''''Dosyadan yükle'''' butonuna tıklayın ve dosyayı seçin.';it = 'È richiesto un file modello di report. Cliccare su ""Caricamento da file"" e selezionare il file.';de = 'Eine Berichtsvorlagendatei ist erforderlich. Klicken Sie auf ""Aus der Datei herunterladen"" und wählen Sie die Datei aus.'");
		CommonClientServer.MessageToUser(TextMessage);
		Cancel = True;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure LoadFromFile(Command)
	
	If Not Object.Ref.IsEmpty() Then
		Return;
	EndIf;
		
	RegistrationParameters = New Structure;
	RegistrationParameters.Insert("Success", False);
	RegistrationParameters.Insert("DataProcessorDataAddress", DataProcessorDataAddress);
	Handler = New NotifyDescription("LoadFromFileAfterFileChoice", ThisObject, RegistrationParameters);
	
	DialogParameters = New Structure("Mode, Filter, FilterIndex, Title");
	DialogParameters.Mode  = FileDialogMode.Open;
	DialogParameters.Filter = SelectingAndSavingDialogFilter();
	DialogParameters.FilterIndex = 0;
	DialogParameters.Title = NStr("en = 'Select an external data processor file.'; ru = 'Выберите файл внешней обработки.';pl = 'Wybierz plik zewnętrznego przetwarzania danych.';es_ES = 'Seleccionar un archivo del procesador de datos externo.';es_CO = 'Seleccionar un archivo del procesador de datos externo.';tr = 'Harici veri işlemcisi dosyası seçin.';it = 'Selezioanre un file di elaborazionei dati esterno';de = 'Wählen Sie eine externe Datenprozessordatei aus.'");
	
	StandardSubsystemsClient.ShowPutFile(Handler, UUID, Object.FileName, DialogParameters);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Function SelectingAndSavingDialogFilter()
	
	Filter = NStr("en = 'External data processors (*.%1)|*.%1|External data processors (*.%1)|*.%1'; ru = 'Внешние обработки (*.%1)|*.%1|Внешние обработки (*.%1)|*.%1';pl = 'Procesory zewnętrznego przetwarzania danych (*.%1)|*.%1|Procesory zewnętrznego przetwarzania danych (*.%1)|*.%1';es_ES = 'Procesadores de datos externo (*.%1)|*.%1|Procesadores de datos externo (*.%1)|*.%1';es_CO = 'Procesadores de datos externo (*.%1)|*.%1|Procesadores de datos externo (*.%1)|*.%1';tr = 'Harici veri işlemcileri (*.%1)|*.%1|Harici veri işlemcileri (*.%1)|*.%1';it = 'Elaboratori dati esterni (*.%1)|*.%1|Elaboratori dati esterni (*.%1)|*.%1';de = 'Externe Datenprozessoren (*.%1)|*.%1|Externe Datenprozessoren (*.%1)|*.%1'");
	Filter = StringFunctionsClientServer.SubstituteParametersToString(Filter, "epf");
	Return Filter;
	
EndFunction

&AtClient
Procedure LoadFromFileAfterFileChoice(FilesThatWerePut, RegistrationParameters) Export
	
	If FilesThatWerePut = Undefined Or FilesThatWerePut.Count() = 0 Then
		Return;
	EndIf;
	
	FileDetails = FilesThatWerePut[0];
	
	RegistrationParameters.Insert("FileName");
	
	SubstringsArray = StrSplit(FileDetails.Name, "\", False);
	RegistrationParameters.FileName = SubstringsArray.Get(SubstringsArray.UBound());
	FileExtention = Upper(Right(RegistrationParameters.FileName, 3));
	
	If Not FileExtention = "EPF" Then
		
		WarningText = NStr("en = 'The file extension does not match external data processor extension (EPF).'; ru = 'Расширение файла не совпадает с расширением внешней обработки (EPF).';pl = 'Rozszerzenie pliku nie jest zgodne z rozszerzeniem procesora zewnętrznego przetwarzania danych (EPF).';es_ES = 'La extensión del archivo no coincide con la del procesador de datos externo (EPF).';es_CO = 'La extensión del archivo no coincide con la del procesador de datos externo (EPF).';tr = 'Dosya uzantısı ile harici veri işlemcisi uzantısı (EPF) uyumlu değil.';it = 'L''estensione del file non corrisponde all''estensione dell''elaboratore dati esterno (EPF).';de = 'Die Dateierweiterung stimmt mit der Erweiterung des externen Datenprozessors nicht überein (EPF).'");
		ShowMessageBox(, WarningText);
		Return;
		
	EndIf;
		
	RegistrationParameters.DataProcessorDataAddress = FileDetails.Location;
	
	LoadFromFileClientMechanics(RegistrationParameters);
	
EndProcedure

&AtClient
Procedure LoadFromFileClientMechanics(RegistrationParameters)
	
	// Server call.
	LoadFromFileServerMechanics(RegistrationParameters);
	
	// Processing server execution result.
	If RegistrationParameters.Success Then
		NotificationTitle = NStr("en = 'External data processor file is imported'; ru = 'Файл внешней обработки загружен';pl = 'Plik zewnętrznego procesora danych jest importowany';es_ES = 'Archivo del procesador de datos externo se ha importado';es_CO = 'Archivo del procesador de datos externo se ha importado';tr = 'Harici veri işlemcisi dosyası içe aktarıldı';it = 'Il file esterno dell''elaboratore dati è stato importato';de = 'Externe Datenprozessordatei wird importiert'");
		NotificationRef    = ?(IsNew, "", GetURL(Object.Ref));
		NotificationText     = RegistrationParameters.FileName;
		ShowUserNotification(NotificationTitle, NotificationRef, NotificationText);
		UpdateFromFileCompletion(Undefined, RegistrationParameters);
	EndIf;
	
EndProcedure

&AtServer
Procedure LoadFromFileServerMechanics(RegistrationParameters)
	
	CatalogObject = FormAttributeToValue("Object");
	
	Result = New Structure("ObjectName, ErrorText, BriefErrorPresentation");
	
	RegistrationResult = GetRegistrationData(Object, RegistrationParameters, Result);
	
	CatalogObject.FileName = RegistrationParameters.FileName;
	CatalogObject.ObjectName = Result.ObjectName;
	CatalogObject.Description = RegistrationResult.Description;
	
	ValueToFormAttribute(CatalogObject, "Object");
	
	CommonClientServer.SupplementStructure(RegistrationParameters, RegistrationResult, True);

EndProcedure

// For internal use.
&AtServer
Function GetRegistrationData(Val Object, Val RegistrationParameters, Val RegistrationResult)

	RegistrationData = New Structure;
	
	OnGetRegistrationData(Object, RegistrationData, RegistrationParameters, RegistrationResult);
	
	Return RegistrationData;
	
EndFunction

// For internal use.
&AtServer
Procedure OnGetRegistrationData(Object, RegistrationData, RegistrationParameters, RegistrationResult)
	
	// Attaching and getting the name to be used when attaching the object.
	Manager = ExternalDataProcessors;
	
	RegistrationData.Insert("Description");
	RegistrationData.Insert("Success");
	
	RegistrationData.Success = False;
	
	
	ErrorInformation = Undefined;
	Try
		If Common.HasUnsafeActionProtection() Then
			RegistrationResult.ObjectName =
			TrimAll(Manager.Connect(RegistrationParameters.DataProcessorDataAddress, , True,
			Common.ProtectionWithoutWarningsDetails()));
		Else
			RegistrationResult.ObjectName =
			TrimAll(Manager.Connect(RegistrationParameters.DataProcessorDataAddress, , True));
		EndIf;
		
		// Getting external data processor information.
		ExternalObject = Manager.Create(RegistrationResult.ObjectName);
		ExternalObjectMetadata = ExternalObject.Metadata();
		
	Except
		ErrorInformation = ErrorInfo();
	EndTry;
	
	If ErrorInformation <> Undefined Then
		ErrorText = NStr("en = 'Cannot attach an additional data processor from a file.
			|It might not be compatible with this application version.'; 
			|ru = 'Невозможно подключить дополнительную обработку из файла.
			|Возможно, она не подходит для этой версии программы.';
			|pl = 'Nie można włączyć dodatkowego przetwarzania danych z pliku.
			|Może ono nie odpowiadać tej wersji aplikacji.';
			|es_ES = 'No se puede activar el procesador adicional desde el archivo.
			|Puede ser no apto para esta versión de la aplicación.';
			|es_CO = 'No se puede activar el procesador adicional desde el archivo.
			|Puede ser no apto para esta versión de la aplicación.';
			|tr = 'Dosyadan ek işlemci etkinleştirilemiyor. 
			|Uygulama sürümü ile uyumlu olmayabilir.';
			|it = 'Impossibile allegare un elaboratore dati aggiuntivo da file. 
			|Potrebbe non essere compatibile con questa versione dell''applicazione.';
			|de = 'Der zusätzliche Prozessor kann nicht aus der Datei aktiviert werden.
			|Möglicherweise ist er für diese Version der Anwendung nicht geeignet.'");
		ErrorText = ErrorText + Chars.LF + Chars.LF + NStr("en = 'Technical information:'; ru = 'Техническая информация:';pl = 'Informacja techniczna:';es_ES = 'Información técnica:';es_CO = 'Información técnica:';tr = 'Teknik bilgi:';it = 'Informazione tecnica:';de = 'Technische Information:'") + Chars.LF;
		RegistrationResult.BriefErrorPresentation = BriefErrorDescription(ErrorInformation);
		RegistrationResult.ErrorText = ErrorText + RegistrationResult.BriefErrorPresentation;
		WriteLogEvent(
				NStr("en = 'TaxReportTemplates'; ru = 'TaxReportTemplates';pl = 'TaxReportTemplates';es_ES = 'TaxReportTemplates';es_CO = 'TaxReportTemplates';tr = 'TaxReportTemplates';it = 'TaxReportTemplates';de = 'TaxReportTemplates'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				Metadata.Catalogs.TaxReportTemplates,
				,
				ErrorText + DetailErrorDescription(ErrorInformation));
		Return;
	EndIf;
	
	RegistrationData.Description = ExternalObjectMetadata.Presentation();
	
	RegistrationData.Success = True;
	
EndProcedure

&AtClient
Procedure UpdateFromFileCompletion(EmptyResult, RegistrationParameters)
	
	If RegistrationParameters.Success = True Then
		Modified = True;
		DataProcessorRegistration = True;
		DataProcessorDataAddress = RegistrationParameters.DataProcessorDataAddress;
	EndIf;
	
EndProcedure

#EndRegion