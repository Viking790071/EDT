#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	ComponentInformation = Catalogs.IntegrationComponents.GetComponentInformation(Object);
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If ValueIsFilled(DataProcessorDataAddress) Then
		DataProcessorBinaryData = GetFromTempStorage(DataProcessorDataAddress);
		CurrentObject.DataProcessorStorage = New ValueStorage(DataProcessorBinaryData, New Deflation(9));
		CurrentObject.IsFilled = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure AddDataProcessor(Command)
	
	RegistrationParameters = New Structure;
	RegistrationParameters.Insert("Success", False);
	RegistrationParameters.Insert("DataProcessorDataAddress", DataProcessorDataAddress);
	Handler = New NotifyDescription("LoadFromFileAfterFileChoice", ThisObject, RegistrationParameters);
	
	DialogParameters = New Structure("Mode, Filter, FilterIndex, Title");
	DialogParameters.Mode  = FileDialogMode.Open;
	DialogParameters.Filter = SelectingAndSavingDialogFilter();
	DialogParameters.FilterIndex = 0;
	DialogParameters.Title = NStr("en = 'Select external data processor file'; ru = 'Выберите файл внешней обработки';pl = 'Wybierz plik zewnętrznego procesora danych';es_ES = 'Seleccionar archivo de procesador de datos externo';es_CO = 'Seleccionar archivo de procesador de datos externo';tr = 'Harici veri işlemcisi dosyası seçin';it = 'Seleziona file di elaboratore dati esterno';de = 'Wählen Sie eine externe Datenprozessordatei aus'");
	
	StandardSubsystemsClient.ShowPutFile(Handler, UUID, "", DialogParameters);
		
EndProcedure

#EndRegion

#Region Private

&AtClient
Function SelectingAndSavingDialogFilter()
	
	Filter = NStr("en = 'External data processors (*.%1)|*.%1|External data processors (*.%1)|*.%1'; ru = 'Внешние обработки (*.%1)|*.%1|Внешние обработки (*.%1)|*.%1';pl = 'Zewnętrzne procesory danych (*.%1)|*.%1|Zewnętrzne procesory danych (*.%1)|*.%1';es_ES = 'Procesadores de datos externos (*.%1)|*.%1| Procesadores de datos externos (*.%1)| *.%1';es_CO = 'Procesadores de datos externos (*.%1)|*.%1| Procesadores de datos externos (*.%1)| *.%1';tr = 'Harici veri işlemcileri (*.%1)|*.%1|Harici veri işlemcileri (*.%1)|*.%1';it = 'Elaboratori dati esterni (*.%1)|*.%1|Elaboratori dati esterni (*.%1)|*.%1';de = 'Externe Datenprozessoren (*.%1)|*.%1|Externe Datenprozessoren (*.%1)|*.%1'");
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
		
		WarningText = NStr("en = 'The selected file is inapplicable as an external data processor. Select an .EPF file.'; ru = 'Выбранный файл не может использоваться в качестве внешней обработки. Выберите файл с расширением .EPF.';pl = 'Wybrany plik nie ma zastosowania jako zewnętrzny procesor danych. Wybierz plik .EPF.';es_ES = 'El archivo seleccionado no se puede aplicar como procesador de datos externo. Seleccione un archivo .EPF.';es_CO = 'El archivo seleccionado no se puede aplicar como procesador de datos externo. Seleccione un archivo .EPF.';tr = 'Seçilen dosya harici veri işlemcisi olarak geçersiz. "".EPF"" dosyası seçin.';it = 'Il file selezionato non è utilizzabile come elaboratore dati esterno. Selezionare un file .EPF.';de = 'Die ausgewählte Datei ist für einen externen Datenprozessor nicht anwendbar. Wählen Sie eine .EPF Datei aus.'");
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
		NotificationTitle = NStr("en = 'The external data processor file is imported.'; ru = 'Файл внешней обработки загружен.';pl = 'Plik zewnętrznego procesora danych jest importowany.';es_ES = 'Se importa el archivo del procesador de datos externo.';es_CO = 'Se importa el archivo del procesador de datos externo.';tr = 'Harici veri işlemcisi dosyası içe aktarıldı.';it = 'Il file dell''elaboratore dati esterno è stato importato.';de = 'Die Datei des externen Datenprozessors wird importiert.'");
		NotificationRef    = ?(IsNew, "", GetURL(Object.Ref));
		NotificationText     = RegistrationParameters.FileName;
		ShowUserNotification(NotificationTitle, NotificationRef, NotificationText);
		UpdateFromFileCompletion(Undefined, RegistrationParameters);
	EndIf;
	
EndProcedure

&AtServer
Procedure LoadFromFileServerMechanics(RegistrationParameters)
	
	ComponentInformation = "";
	CatalogObject = FormAttributeToValue("Object");
	
	Result = New Structure("ObjectName, ErrorText, BriefErrorPresentation");
		
	RegistrationResult = GetRegistrationData(Object, RegistrationParameters, Result);
	Catalogs.IntegrationComponents.UpdateSettingsFromDataProcessor(RegistrationParameters, CatalogObject, ComponentInformation);
	CatalogObject.Description = RegistrationResult.Description;
	
	ValueToFormAttribute(CatalogObject, "Object");
	
	CommonClientServer.SupplementStructure(RegistrationParameters, RegistrationResult, True);

EndProcedure

&AtServer
Function GetRegistrationData(Val Object, Val RegistrationParameters, Val RegistrationResult)

	RegistrationData = New Structure;
	
	OnGetRegistrationData(Object, RegistrationData, RegistrationParameters, RegistrationResult);
	
	Return RegistrationData;
	
EndFunction

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
			TrimAll(Manager.Connect(RegistrationParameters.DataProcessorDataAddress, , False,
				Common.ProtectionWithoutWarningsDetails()));
		Else
			RegistrationResult.ObjectName =
			TrimAll(Manager.Connect(RegistrationParameters.DataProcessorDataAddress, , False));
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
			|pl = 'Nie można załączyć dodatkowego procesora danych z pliku.
			|Może nie odpowiadać tej wersji aplikacji.';
			|es_ES = 'No se puede adjuntar un procesador de datos adicional desde un archivo.
			|Puede que no sea compatible con esta versión de la aplicación.';
			|es_CO = 'No se puede adjuntar un procesador de datos adicional desde un archivo.
			|Puede que no sea compatible con esta versión de la aplicación.';
			|tr = 'Dosyadan ek veri işlemcisi eklenemiyor.
			|Uygulamanın bu sürümüyle uyumlu olmayabilir.';
			|it = 'Impossibile allegare un elaboratore dati aggiuntivo da file. 
			|Potrebbe non essere compatibile con questa versione dell''applicazione.';
			|de = 'Fehler beim Beifügen eines zusätzlichen Datenprozessors aus einer Datei.
			|Möglicherweise ist er für diese Version der App nicht geeignet.'");
		ErrorText = ErrorText + Chars.LF + Chars.LF + NStr("en = 'Details:'; ru = 'Подробнее:';pl = 'Szczegóły:';es_ES = 'Detalles:';es_CO = 'Detalles:';tr = 'Ayrıntılar:';it = 'Dettagli:';de = 'Details:'") + Chars.LF;
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
		DataProcessorDataAddress = RegistrationParameters.DataProcessorDataAddress;
	EndIf;
	
EndProcedure

#EndRegion