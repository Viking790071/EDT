#Region Public

// Attaches an external report or data processor.
//   For more information, see AdditionalReportsAndDataProcessors.AttachExternalDataProcessor(). 
//
// Parameters:
//   Reference - CatalogRef.AdditionalReportsAndDataProcessors - a data processor to attach.
//
// Returns:
//   String       - a name of the attached report or data processor.
//   Undefined - if an invalid reference is passed.
//
Function AttachExternalDataProcessor(Ref) Export
	
	Return AdditionalReportsAndDataProcessors.AttachExternalDataProcessor(Ref);
	
EndFunction

// Function creates and returns an instance of the external data processor (report).
//   For more information, see AdditionalReportsAndDataProcessors.ExternalDataProcessorObject(). 
//
// Parameters:
//   Reference - CatalogRef.AdditionalReportsAndDataProcessors - a report data processor to attach.
//
// Returns:
//   ExternalDataProcessorObject - attached data processor object.
//   ExternalReportObject     - attached report object.
//   Undefined           - if an invalid reference is passed.
//
Function ExternalDataProcessorObject(Ref) Export
	
	Return AdditionalReportsAndDataProcessors.ExternalDataProcessorObject(Ref);
	
EndFunction

#Region ObsoleteProceduresAndFunctions

// Obsolete. Use AdditionalReportsAndDataProcessors.ExternalDataProcessorObject().
//
// Parameters:
//   Reference - CatalogRef.AdditionalReportsAndDataProcessors - a report data processor to attach.
//
// Returns:
//   ExternalDataProcessorObject - attached data processor object.
//   ExternalReportObject     - attached report object.
//   Undefined           - if an invalid reference is passed.
//
Function GetExternalDataProcessorsObject(Ref) Export
	
	Return AdditionalReportsAndDataProcessors.ExternalDataProcessorObject(Ref);
	
EndFunction

#EndRegion

#EndRegion

#Region Private

// Executes a data processor command and puts the result to a temporary storage.
//   For more information, see AdditionalReportsAndDataProcessors.ExecuteCommand(). 
//
Function ExecuteCommand(CommandParameters, ResultAddress = Undefined) Export
	
	Return AdditionalReportsAndDataProcessors.ExecuteCommand(CommandParameters, ResultAddress);
	
EndFunction

// Puts binary data of an additional report or data processor to a temporary storage.
Function PutInStorage(Ref, FormID) Export
	If TypeOf(Ref) <> Type("CatalogRef.AdditionalReportsAndDataProcessors") 
		Or Ref = Catalogs.AdditionalReportsAndDataProcessors.EmptyRef() Then
		Return Undefined;
	EndIf;
	If NOT AdditionalReportsAndDataProcessors.CanExportDataProcessorToFile(Ref) Then
		Raise NStr("ru = 'Недостаточно прав для выгрузки файлов дополнительных отчетов и обработок'; en = 'Insufficient rights to export additional report or data processor files'; pl = 'Niewystarczające uprawnienia do eksportowania plików dodatkowych sprawozdań i procedur przetwarzania danych';es_ES = 'Insuficientes derechos para exportar los archivos de informes adicionales y procesadores de datos';es_CO = 'Insuficientes derechos para exportar los archivos de informes adicionales y procesadores de datos';tr = 'Ek raporların ve veri işlemcilerinin dosyalarını dışa aktarmak için yetersiz haklar';it = 'Permessi insufficienti per l''importazione dei file dei report e delle elaborazioni aggiuntive';de = 'Unzureichende Rechte zum Exportieren von Dateien zusätzlicher Berichte und Datenprozessoren'");
	EndIf;
	
	DataProcessorStorage = Common.ObjectAttributeValue(Ref, "DataProcessorStorage");
	
	Return PutToTempStorage(DataProcessorStorage.Get(), FormID);
EndFunction

// Starts a time-consuming operation.
Function StartTimeConsumingOperation(Val UUID, Val CommandParameters) Export
	MethodName = "AdditionalReportsAndDataProcessors.ExecuteCommand";
	
	StartSettings = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	StartSettings.WaitForCompletion = 0;
	StartSettings.BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Выполнение дополнительного отчета или обработки ""%1"", имя команды ""%2""'; en = 'Execution of additional report or data processor: %1, command name: %2'; pl = 'Uruchamianie dodatkowego sprawozdania lub przetwarzania danych ""%1"", nazwa polecenia ""%2""';es_ES = 'Lanzando el informe adicional o el procesador de datos ""%1"", nombre del comando ""%2""';es_CO = 'Lanzando el informe adicional o el procesador de datos ""%1"", nombre del comando ""%2""';tr = 'Ek rapor veya veri işlemcisi çalıştırılıyor ""%1"", komut adı ""%2""';it = 'Esecuzione del report o dell''elaborazione aggiuntiva ""%1"", nome del comando ""%2""';de = 'Ausführen eines zusätzlichen Berichts oder Datenprozessors ""%1"", Befehlsname ""%2""'"),
		String(CommandParameters.AdditionalDataProcessorRef),
		CommandParameters.CommandID);
	
	Return TimeConsumingOperations.ExecuteInBackground(MethodName, CommandParameters, StartSettings);
EndFunction

#EndRegion
