#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Update handlers.

// Registers objects, for which it is necessary to update register records on the InfobaseUpdate 
// exchange plan.
//
Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	AllFilesOwnersProcessed = False;
	Ref = "";
	While Not AllFilesOwnersProcessed Do
		
		Query = New Query;
		Query.Text =
			"SELECT DISTINCT TOP 1000
			|	Files.Ref AS Ref
			|FROM
			|	Catalog.Files AS Files
			|		LEFT JOIN InformationRegister.FilesExist AS FilesExist
			|		ON Files.FileOwner = FilesExist.ObjectWithFiles
			|WHERE
			|	FilesExist.ObjectWithFiles IS NULL 
			|	AND Files.Ref > &Ref
			|
			|ORDER BY
			|	Ref";
			
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
	
	ProcessingCompleted = True;
	
	Selection = InfobaseUpdate.SelectRefsToProcess(Parameters.PositionInQueue, "Catalog.Files");
	
	ObjectsProcessed = 0;
	ObjectsWithIssuesCount = 0;
	
	While Selection.Next() Do
		
		FileOwner = Common.ObjectAttributeValue(Selection.Ref, "FileOwner");
		If NOT ValueIsFilled(FileOwner) Then
			InfobaseUpdate.MarkProcessingCompletion(Selection.Ref);
			Continue;
		EndIf;
		
		BeginTransaction();
		Try
			
			Lock = New DataLock;
			LockItem = Lock.Add("Catalog.Files");
			LockItem.SetValue("Ref", Selection.Ref);
			LockItem.Mode = DataLockMode.Shared;
			Lock.Lock();
			
			FilesExistWriteManager = CreateRecordManager();
			FilesExistWriteManager.ObjectWithFiles       = FileOwner;
			FilesExistWriteManager.HasFiles            = True;
			FilesExistWriteManager.ObjectID = FilesOperationsInternal.GetNextObjectID();
			FilesExistWriteManager.Write(True);
			
			InfobaseUpdate.MarkProcessingCompletion(Selection.Ref);
			ObjectsProcessed = ObjectsProcessed + 1;
			CommitTransaction();
		Except
			RollbackTransaction();
			// If you fail to process a document, try again.
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '???? ?????????????? ???????????????????? ???????????? ??????????: %1 ???? ??????????????:
				|%2'; 
				|en = 'Cannot process the file version: %1 due to: 
				|%2'; 
				|pl = 'Nie mo??na przetworzy?? wersji pliku: %1 z powodu:
				|%2';
				|es_ES = 'No se ha podido procesar la versi??n del archivo: %1 a causa de:
				|%2';
				|es_CO = 'No se ha podido procesar la versi??n del archivo: %1 a causa de:
				|%2';
				|tr = 'Dosya s??r??m?? ""%1"" a??a????daki nedenle i??lenemedi: 
				|%2';
				|it = 'Impossibile elaborare la versione di file: %1 a causa di: 
				|%2';
				|de = 'Die Version der Datei konnte nicht verarbeitet werden: %1 aus dem Grund:
				|%2'"), 
				Selection.Ref, DetailErrorDescription(ErrorInfo()));
				WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Warning,
				Selection.Ref.Metadata(), Selection.Ref, MessageText);
		EndTry;
		
	EndDo;
	
	If Not InfobaseUpdate.DataProcessingCompleted(Parameters.PositionInQueue, "Catalog.Files") Then
		ProcessingCompleted = False;
	EndIf;
	
	If ObjectsProcessed = 0 AND ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = '?????????????????? InformationRegisters.FilesExist.ProcessDataForMigrationToNewVersion.ProcessDataForMigrationToNewVersion ???? ?????????????? ???????????????????? ?????????????????? ?????????????????????? ?????????????? (??????????????????): %1'; en = 'The InformationRegisters.FilesExist.ProcessDataForMigrationToNewVersion.ProcessDataForMigrationToNewVersion procedure cannot process digital signature applications (skipped): %1'; pl = 'Procedurze InformationRegisters.FilesExist.ProcessDataForMigrationToNewVersion.ProcessDataForMigrationToNewVersion nie uda??o si?? przetworzy?? program??w podpisu cyfrowego (pomini??te): %1';es_ES = 'El procedimiento InformationRegisters.FilesExist.ProcessDataForMigrationToNewVersion.ProcessDataForMigrationToNewVersion no ha podido procesar los programas de firma electr??nica (saltados): %1';es_CO = 'El procedimiento InformationRegisters.FilesExist.ProcessDataForMigrationToNewVersion.ProcessDataForMigrationToNewVersion no ha podido procesar los programas de firma electr??nica (saltados): %1';tr = 'InformationRegisters.FilesExist.ProcessDataForMigrationToNewVersion.ProcessDataForMigrationToNewVersion prosed??r?? dijital imza uygulamalar??n?? i??leyemiyor (atland??): %1';it = 'La procedura InformationRegisters.FilesExist.ProcessDataForMigrationToNewVersion.ProcessDataForMigrationToNewVersion non ?? in grado di elaborare le applicazioni di firma elettronica (ignorate): %1';de = 'Das Verfahren InformationRegisters.FilesExist.ProcessDataForMigrationToNewVersion.ProcessDataForMigrationToNewVersion kann digitale Unterschrift-Anwendungen nicht verarbeiten (??bersprungen): %1'"), 
		ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
		, ,
		StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = '?????????????????? InformationRegisters.FilesExist.ProcessDataForMigrationToNewVersion ???????????????????? ?????????????????? ???????????? ???????????????? ?????????????????????? ??????????????: %1'; en = 'The InformationRegisters.FilesExist.ProcessDataForMigrationToNewVersion procedure has processed digital signature applications: %1'; pl = 'Procedura InformationRegisters.FilesExist.ProcessDataForMigrationToNewVersion przetworzy??a kolejn?? parti?? program??w podpisu cyfrowego: %1';es_ES = 'El procedimiento InformationRegisters.FilesExist.ProcessDataForMigrationToNewVersion no ha procesado una porci??n de programas de firma electr??nica: %1';es_CO = 'El procedimiento InformationRegisters.FilesExist.ProcessDataForMigrationToNewVersion no ha procesado una porci??n de programas de firma electr??nica: %1';tr = 'InformationRegisters.FilesExist.ProcessDataForMigrationToNewVersion prosed??r?? s??radaki e-imza uygulamalar??n k??sm??n?? i??ledi: %1';it = 'La procedura RegistriInformazioni.PresenzaFile.ElaborareDatiTransizioneVersoNuovaVersione ha elaborato un''ulteriore porzione di programmi di firma elettronica: %1';de = 'Das Verfahren InformationRegisters.FilesExist.ProcessDataForMigrationToNewVersion hat digitale Unterschrift-Anwendungen verarbeitet: %1'"),
		ObjectsProcessed));
	EndIf;
	
	Parameters.ProcessingCompleted = ProcessingCompleted;
	
EndProcedure

#EndRegion

#EndIf

