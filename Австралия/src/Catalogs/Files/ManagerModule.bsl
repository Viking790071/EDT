#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchObjectsModification

// Returns object attributes allowed to be edited using bench attribute change data processor.
// 
//
// Returns:
//  Array - a list of object attribute names.
Function AttributesToEditInBatchProcessing() Export
	
	Return FilesOperations.AttributesToEditInBatchProcessing();
	
EndFunction

// End StandardSubsystems.BatchObjectModification

// StandardSubsystems.AccessManagement

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowRead
	|WHERE
	|	ObjectReadingAllowed(FileOwner)
	|;
	|AllowUpdateIfReadingAllowed
	|WHERE
	|	ObjectUpdateAllowed(FileOwner)";
	
	Restriction.TextForExternalUsers =
	"AllowReadUpdate
	|WHERE
	|	ValueAllowed(CAST(Author AS Catalog.ExternalUsers))";
	Restriction.ByOwnerWithoutSavingAccessKeysForExternalUsers = False;
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#EndIf

#Region EventHandlers

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	If Parameters.Count() = 0 Then
		SelectedForm = "Files"; // Opening the file list because the specific file is not specified.
		StandardProcessing = False;
	EndIf;
	If FormType = "ListForm" Then
		CurrentRow = CommonClientServer.StructureProperty(Parameters, "CurrentRow");
		If TypeOf(CurrentRow) = Type("CatalogRef.Files") AND Not CurrentRow.IsEmpty() Then
			StandardProcessing = False;
			FileOwner = Common.ObjectAttributeValue(CurrentRow, "FileOwner");
			If TypeOf(FileOwner) = Type("CatalogRef.FileFolders") Then
				Parameters.Insert("Folder", FileOwner);
				SelectedForm = "DataProcessor.FilesOperations.Form.AttachedFiles";
			Else
				Parameters.Insert("FileOwner", FileOwner);
				SelectedForm = "DataProcessor.FilesOperations.Form.AttachedFiles";
			EndIf;
		EndIf;
	EndIf;
	
#EndIf

EndProcedure

#EndRegion

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// Registers the objects to be updated to the latest version in the InfobaseUpdate exchange plan.
// 
Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	AllFilesProcessed = False;
	Ref = "";
	
	While Not AllFilesProcessed Do
	
		Query = New Query;
		Query.Text = 
			"SELECT TOP 1000
			|	Files.Ref AS Ref
			|FROM
			|	Catalog.Files AS Files
			|WHERE
			|	((Files.UniversalModificationDate = DATETIME(1, 1, 1, 0, 0, 0)
			|	AND Files.CurrentVersion <> VALUE(Catalog.FilesVersions.EmptyRef))
			|	OR Files.FileStorageType = VALUE(Enum.FileStorageTypes.EmptyRef))
			|	AND Files.Ref > &Ref
			|
			|ORDER BY
			|	Ref";
		
		Query.SetParameter("Ref", Ref);
		RefsArray = Query.Execute().Unload().UnloadColumn("Ref");

		InfobaseUpdate.MarkForProcessing(Parameters, RefsArray);
		
		RefsCount = RefsArray.Count();
		If RefsCount < 1000 Then
			AllFilesProcessed = True;
		EndIf;
		
		If RefsCount > 0 Then
			Ref = RefsArray[RefsCount - 1];
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	ProcessingCompleted = True;
	
	Selection = InfobaseUpdate.SelectRefsToProcess(Parameters.PositionInQueue, "Catalog.Files");
	
	ObjectsProcessed = 0;
	ObjectsWithIssuesCount = 0;
	
	While Selection.Next() Do
		
		BeginTransaction();
		Try
			
			DataLock = New DataLock;
			DataLockItem = DataLock.Add("Catalog.Files");
			DataLockItem.SetValue("Ref", Selection.Ref);
			
			DataLockItem = DataLock.Add("Catalog.FilesVersions");
			DataLockItem.SetValue("Ref", Selection.Ref.CurrentVersion);
			DataLockItem.Mode = DataLockMode.Shared;
			
			DataLock.Lock();
			
			FileToUpdate = Selection.Ref.GetObject();
			FileToUpdate.UniversalModificationDate = FileToUpdate.CurrentVersion.UniversalModificationDate;
			FileToUpdate.FileStorageType             = FileToUpdate.CurrentVersion.FileStorageType;
			InfobaseUpdate.WriteObject(FileToUpdate);
			
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
	
	If Not InfobaseUpdate.DataProcessingCompleted(Parameters.PositionInQueue, "Catalog.Files") Then
		ProcessingCompleted = False;
	EndIf;
	
	If ObjectsProcessed = 0 AND ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Процедуре Catalogs.Files.ProcessDataForMigrationToNewVersion.ProcessDataForMigrationToNewVersion не удалось обработать программы электронной подписи (пропущены): %1'; en = 'The Catalogs.Files.ProcessDataForMigrationToNewVersion.ProcessDataForMigrationToNewVersion procedure cannot process digital signature applications (skipped): %1.'; pl = 'Procedurze Catalogs.Files.ProcessDataForMigrationToNewVersion.ProcessDataForMigrationToNewVersion nie udało się przetworzyć programów podpisu cyfrowego (pominięte): %1';es_ES = 'El procedimiento Catalogs.Files.ProcessDataForMigrationToNewVersion.ProcessDataForMigrationToNewVersion no ha podido procesar los programas de la firma electrónica (saltados): %1';es_CO = 'El procedimiento Catalogs.Files.ProcessDataForMigrationToNewVersion.ProcessDataForMigrationToNewVersion no ha podido procesar los programas de la firma electrónica (saltados): %1';tr = 'Catalogs.Files.ProcessDataForMigrationToNewVersion.ProcessDataForMigrationToNewVersion prosedürü, e-imza uygulamalarını işleyemedi (atladı) : %1';it = 'La procedura Catalogs.Files.ProcessDataForMigrationToNewVersion.ProcessDataForMigrationToNewVersion non può elaborare le applicazioni di firma elettronica (saltati): %1.';de = 'Das Verfahren Catalogs.Files.ProcessDataForMigrationToNewVersion.ProcessDataForMigrationToNewVersion kann digitale Unterschrift-Anwendungen nicht verarbeiten (übersprungen): %1.'"), 
		ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
		, ,
		StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Процедура Catalogs.Files.ProcessDataForMigrationToNewVersion обработала очередную порцию программ электронной подписи: %1'; en = 'The Catalogs.Files.ProcessDataForMigrationToNewVersion procedure has processed digital signature applications: %1.'; pl = 'Procedura Catalogs.Files.ProcessDataForMigrationToNewVersion przetworzyć kolejną partię programów do podpisu cyfrowego: %1';es_ES = 'El procedimiento Catalogs.Files.ProcessDataForMigrationToNewVersion no ha procesado una porción de programas de firma electrónica: %1';es_CO = 'El procedimiento Catalogs.Files.ProcessDataForMigrationToNewVersion no ha procesado una porción de programas de firma electrónica: %1';tr = 'Catalogs.Files.ProcessDataForMigrationToNewVersion prosedürü sıradaki e-imza uygulamaların kısmını işledi: %1';it = 'La procedura Catalogs.Files.ProcessDataForMigrationToNewVersion presenta applicazioni di firma elettronica elaborate: %1.';de = 'Das Verfahren Catalogs.Files.ProcessDataForMigrationToNewVersion hat Anwendungen für digitale Unterschriften verarbeitet: %1.'"),
		ObjectsProcessed));
	EndIf;
	
	Parameters.ProcessingCompleted = ProcessingCompleted;
	
EndProcedure

#EndRegion

#EndIf
