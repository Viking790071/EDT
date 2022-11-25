#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Update handlers.

// Registers objects, for which it is necessary to update register records on the InfobaseUpdate 
// exchange plan.
//
Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	Ref = "";
	AllFilesOwnersProcessed = False;
	While Not AllFilesOwnersProcessed Do
		
		Query = New Query;
		Query.Text =
		"SELECT DISTINCT TOP 1000
		|	Files.Ref AS Ref
		|FROM
		|	Catalog.Files AS Files
		|		LEFT JOIN InformationRegister.FilesInfo AS FilesInfo
		|		ON Files.Ref = FilesInfo.File
		|WHERE
		|	Files.Ref > &Ref
		|	AND FilesInfo.File IS NULL
		|ORDER BY
		|	Files.Ref";
		
		Query.SetParameter("Ref", Ref);
		RefsArray = Query.Execute().Unload().UnloadColumn("Ref"); 
		
		InfobaseUpdate.MarkForProcessing(Parameters, RefsArray);
		
		RefsCount = RefsArray.Count();
		If RefsCount < 1000 Then
			AllFilesOwnersProcessed = True;
		EndIf;
		
		If RefsCount > 0 Then
			Ref = RefsArray[RefsCount-1];
		EndIf;
		
	EndDo;
	
EndProcedure

// Update register records.
Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	Selection = InfobaseUpdate.SelectRefsToProcess(Parameters.PositionInQueue, "Catalog.Files");
	ObjectsProcessed = 0;
	ObjectsWithIssuesCount = 0;
	
	While Selection.Next() Do
		BeginTransaction();
		Try
			Lock = New DataLock;
			LockItem = Lock.Add("Catalog.Files");
			LockItem.SetValue("Ref", Selection.Ref);
			LockItem.Mode = DataLockMode.Shared;
			Lock.Lock();
			
			RecordManager = CreateRecordManager();
			FillPropertyValues(RecordManager, Selection.Ref);
			RecordManager.File          = Selection.Ref;
			AttributesStructure          = Common.ObjectAttributesValues(Selection.Ref, "Author, FileOwner");
			RecordManager.Author         = AttributesStructure.Author;
			RecordManager.FileOwner = AttributesStructure.FileOwner;
			
			If Selection.Ref.SignedWithDS AND Selection.Ref.Encrypted Then
				RecordManager.SignedEncryptedPictureNumber = 2;
			ElsIf Selection.Ref.Encrypted Then
				RecordManager.SignedEncryptedPictureNumber = 1;
			ElsIf Selection.Ref.SignedWithDS Then
				RecordManager.SignedEncryptedPictureNumber = 0;
			Else
				RecordManager.SignedEncryptedPictureNumber = -1;
			EndIf;
			RecordManager.Write();
			
			InfobaseUpdate.MarkProcessingCompletion(Selection.Ref);
			ObjectsProcessed = ObjectsProcessed + 1;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			// If you fail to process a document, try again.
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не удалось обработать файл: %1 по причине:
				|%2'; 
				|en = 'Cannot process file: %1 due to:
				|%2'; 
				|pl = 'Nie udało się przetworzyć pliku: %1 z powodu:
				|%2';
				|es_ES = 'No se ha podido procesar el archivo: %1 a causa de: 
				|%2';
				|es_CO = 'No se ha podido procesar el archivo: %1 a causa de: 
				|%2';
				|tr = 'Dosya aşağıdaki nedenle işlenemedi: 
				|%2 %1';
				|it = 'Non è possibile elaborare il file: %1 a causa di:
				|%2';
				|de = 'Die Datei konnte nicht verarbeitet werden: %1 aus folgendem Grund:
				|%2'"), 
				Selection.Ref, DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Warning,
				Selection.Ref.Metadata(), Selection.Ref, MessageText);
		EndTry;
		
	EndDo;
	
	Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.PositionInQueue, "Catalog.Files");
	
	If ObjectsProcessed = 0 AND ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Процедуре InformationRegisters.FilesInfo.ProcessDataForMigrationToNewVersion не удалось обработать некоторые файлы файлов (пропущены): %1'; en = 'The InformationRegisters.FilesInfo.ProcessDataForMigrationToNewVersion procedure cannot process some file files (skipped): %1'; pl = 'Procedurze InformationRegisters.FilesInfo.ProcessDataForMigrationToNewVersion nie udało się przetworzyć niektóre pliki plików (pomijane): %1';es_ES = 'El procedimiento InformationRegisters.FilesInfo.ProcessDataForMigrationToNewVersion no ha podido procesar algunos archivos de archivos (saltados): %1';es_CO = 'El procedimiento InformationRegisters.FilesInfo.ProcessDataForMigrationToNewVersion no ha podido procesar algunos archivos de archivos (saltados): %1';tr = 'InformationRegisters.FilesInfo.ProcessDataForMigrationToNewVersion prosedürü bazı dosyaları işleyemedi (atlatıldı): %1';it = 'La procedura InformationRegisters.FilesInfo.ProcessDataForMigrationToNewVersion non è in grado di elaborare alcuni file (ignorati): %1';de = 'Die Prozedur InformationRegisters.FilesInfo.ProcessDataForMigrationToNewVersion kann einige Datei-Dateien nicht verarbeiten (übersprungen): %1'"), 
			ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
			Catalogs.Files,,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Процедура InformationRegisters.FilesInfo.ProcessDataForMigrationToNewVersion обработала очередную порцию файлов: %1'; en = 'The InformationRegisters.FilesInfo.ProcessDataForMigrationToNewVersion procedure has processed files: %1'; pl = 'Procedura InformationRegisters.FilesInfo.ProcessDataForMigrationToNewVersion opracowała kolejną porcję wersji plików: %1';es_ES = 'El procedimiento InformationRegisters.FilesInfo.ProcessDataForMigrationToNewVersion ha procesado los archivos: %1';es_CO = 'El procedimiento InformationRegisters.FilesInfo.ProcessDataForMigrationToNewVersion ha procesado los archivos: %1';tr = 'InformationRegisters.FilesInfo.ProcessDataForMigrationToNewVersion prosedürü dosyaları işledi: %1';it = 'La procedura RegistriInformazioni.ElaborazioneFilePerTransizioneVersoNuovaVersione ha elaborato un''ulteriore porzione di file: %1';de = 'Das Verfahren InformationRegisters.FilesInfo.ProcessDataForMigrationToNewVersion hat Dateien verarbeitet: %1'"),
				ObjectsProcessed));
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
