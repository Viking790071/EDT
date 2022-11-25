
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	FileVersionsInInfobaseCount = FileVersionsInInfobaseCount();
	VolumeStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive;
	
	VersionsSizeInBaseInBytes = FileVersionsSizeInInfobase();
	FileVersionsSizeInInfobase = VersionsSizeInBaseInBytes / 1048576;
	
	AdditionalParameters = New Structure;
	
	AdditionalParameters.Insert(
		"OnOpenStoreFilesInVolumesOnHardDrive",
		FilesOperationsInternal.StoreFilesInVolumesOnHardDrive());
	
	AdditionalParameters.Insert(
		"OnOpenHasFilesStorageVolumes",
		FilesOperations.HasFileStorageVolumes());
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If NOT AdditionalParameters.OnOpenStoreFilesInVolumesOnHardDrive Then
		ShowMessageBox(, NStr("ru = 'Не установлен тип хранения файлов ""В томах на диске""'; en = 'File storage type ""In volumes on the hard disk"" is not set'; pl = 'Typ przechowywania plików ""W woluminach na dysku twardym"" nie jest ustawiony';es_ES = 'Tipo de almacenamiento de archivos ""En volúmenes en el disco duro"" no está establecido';es_CO = 'Tipo de almacenamiento de archivos ""En volúmenes en el disco duro"" no está establecido';tr = '""Sabit diskteki birimlerde"" dosya depolama türü ayarlanmadı';it = 'Il tipo di archiviazione di file ""In volumi su disco rigido"" non è impostato';de = 'Der Dateispeichertyp ""In Volumen auf der Festplatte"" ist nicht festgelegt'"));
		Cancel = True;
		Return;
	EndIf;
	
	If NOT AdditionalParameters.OnOpenHasFilesStorageVolumes Then 
		ShowMessageBox(, NStr("ru = 'Нет ни одного тома для размещения файлов'; en = 'There are no volumes to place files in'; pl = 'Brak woluminów do umieszczania plików w';es_ES = 'No hay volúmenes para colocar archivos en ellos';es_CO = 'No hay volúmenes para colocar archivos en ellos';tr = 'Dosyaların yerleştirileceği birimler yok';it = 'Non ci sono volumi per ospitare file';de = 'Es gibt keine Volumen zum Einreihen von Dateien'"));
		Cancel = True;
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ExecuteMoveFilesToVolumes(Command)
	
	FilesStorageProperties = FilesStorageProperties();
	
	If FilesStorageProperties.FilesStorageTyoe <> VolumeStorageType Then
		ShowMessageBox(, NStr("ru = 'Не установлен тип хранения файлов ""В томах на диске""'; en = 'File storage type ""In volumes on the hard disk"" is not set'; pl = 'Typ przechowywania plików ""W woluminach na dysku twardym"" nie jest ustawiony';es_ES = 'Tipo de almacenamiento de archivos ""En volúmenes en el disco duro"" no está establecido';es_CO = 'Tipo de almacenamiento de archivos ""En volúmenes en el disco duro"" no está establecido';tr = '""Sabit diskteki birimlerde"" dosya depolama türü ayarlanmadı';it = 'Il tipo di archiviazione di file ""In volumi su disco rigido"" non è impostato';de = 'Der Dateispeichertyp ""In Volumen auf der Festplatte"" ist nicht festgelegt'"));
		Return;
	EndIf;
	
	If NOT FilesStorageProperties.HasFileStorageVolumes Then
		ShowMessageBox(, NStr("ru = 'Нет ни одного тома для размещения файлов'; en = 'There are no volumes to place files in'; pl = 'Brak woluminów do umieszczania plików w';es_ES = 'No hay volúmenes para colocar archivos en ellos';es_CO = 'No hay volúmenes para colocar archivos en ellos';tr = 'Dosyaların yerleştirileceği birimler yok';it = 'Non ci sono volumi per ospitare file';de = 'Es gibt keine Volumen zum Einreihen von Dateien'"));
		Return;
	EndIf;
	
	If FileVersionsInInfobaseCount = 0 Then
		ShowMessageBox(, NStr("ru = 'Нет ни одного файла в информационной базе'; en = 'There are no files in the infobase'; pl = 'Brak plików w bazie informacyjnej';es_ES = 'No hay archivos en la infobase';es_CO = 'No hay archivos en la infobase';tr = 'Infobase''de dosya yok';it = 'Non ci sono file nella infobase';de = 'In der Infobase befinden sich keine Dateien'"));
		Return;
	EndIf;
	
	QuestionText = NStr("ru = 'Выполнить перенос файлов в информационной базе в тома хранения файлов?
		|
		|Эта операция может занять продолжительное время.'; 
		|en = 'Transfer files from the infobase to the file storage volumes?
		|
		|This operation may take a long time to complete.'; 
		|pl = 'Wykonać transfer plików w bazie informacyjnej do woluminów przechowywania plików?
		|
		|Ta operacja może potrwać dłuższy czas.';
		|es_ES = '¿Quiere realizar el traslado de archivos en la infobase a los volúmenes de guarda de archivos?
		|
		|Esta operación puede llevar mucho tiempo.';
		|es_CO = '¿Quiere realizar el traslado de archivos en la infobase a los volúmenes de guarda de archivos?
		|
		|Esta operación puede llevar mucho tiempo.';
		|tr = 'Veritabanı dosyalarında depolama birimlerine dosya aktarımı yapmak ister misiniz? 
		|
		|Bu işlem uzun zaman alabilir.';
		|it = 'Trasferire file dall''infobase ai volumi di archiviazione file?
		|
		|Questa operazione può richiedere molto tempo.';
		|de = 'Dateiübertragung aus der Infobase auf Dateispeicher-Volumes durchführen?
		|
		|Diese Operation kann lange dauern.'");
	Handler = New NotifyDescription("MoveFilesToVolumesCompletion", ThisObject);
	ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure MoveFilesToVolumesCompletion(Response, ExecutionParameters) Export
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	VersionsArray = VersionsInBase();
	LoopNumber = 1;
	MovedFilesCount = 0;
	
	VersionsInPackageCount = 10;
	VersionsPackage = New Array;
	
	FilesArrayWithErrors = New Array;
	ProcessingAborted = False;
	
	For Each VersionStructure In VersionsArray Do
		
		Progress = 0;
		If FileVersionsInInfobaseCount <> 0 Then
			Progress = Round(LoopNumber * 100 / FileVersionsInInfobaseCount, 2);
		EndIf;
		
		VersionsPackage.Add(VersionStructure);
		
		If VersionsPackage.Count() >= VersionsInPackageCount Then
			MovedItemsInPackageCount = MoveVersionsArrayToVolume(VersionsPackage, FilesArrayWithErrors);
			
			If MovedItemsInPackageCount = 0 AND VersionsPackage.Count() = VersionsInPackageCount Then
				ProcessingAborted = True; // If you cannot move the whole batch, stop the operation.
				Break;
			EndIf;
			
			MovedFilesCount = MovedFilesCount + MovedItemsInPackageCount;
			VersionsPackage.Clear();
			
		EndIf;
		
		LoopNumber = LoopNumber + 1;
	EndDo;
	
	If VersionsPackage.Count() <> 0 Then
		MovedItemsInPackageCount = MoveVersionsArrayToVolume(VersionsPackage, FilesArrayWithErrors);
		
		If MovedItemsInPackageCount = 0 Then
			ProcessingAborted = True; // If you cannot move the whole batch, stop the operation.
		EndIf;
		
		MovedFilesCount = MovedFilesCount + MovedItemsInPackageCount;
		VersionsPackage.Clear();
	EndIf;
	
	FileVersionsInInfobaseCount = FileVersionsInInfobaseCount();
	VersionsSizeInBaseInBytes = FileVersionsSizeInInfobase();
	FileVersionsSizeInInfobase = VersionsSizeInBaseInBytes / 1048576;
	
	If MovedFilesCount <> 0 Then
		WarningText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Завершен перенос файлов в тома.
			           |Перенесено файлов: %1'; 
			           |en = 'Transferring files to volumes is completed.
			           |Files transferred: %1'; 
			           |pl = 'Przeniesienie plików do woluminów zostało zakończone.
			           |Przeniesione pliki: %1';
			           |es_ES = 'Traslado de archivos para los volúmenes se ha finalizado.
			           |Archivos trasladados: %1';
			           |es_CO = 'Traslado de archivos para los volúmenes se ha finalizado.
			           |Archivos trasladados: %1';
			           |tr = 'Birimlere dosya aktarımı tamamlandı. 
			           |Aktarılan dosyalar:%1';
			           |it = 'Il trasferimento di file ai volumi è stato completato.
			           |File trasferiti: %1';
			           |de = 'Die Dateiübertragung auf die Volumen ist abgeschlossen.
			           |Übertragene Dateien: %1'"),
			MovedFilesCount);
		ShowMessageBox(, WarningText);
	EndIf;
	
	If FilesArrayWithErrors.Count() <> 0 Then
		
		Note = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Количество ошибок при переносе: %1'; en = 'Number of errors on transfer: %1'; pl = 'Liczba błędów w czasie przeniesienia: %1';es_ES = 'Número de errores durante el traslado: %1';es_CO = 'Número de errores durante el traslado: %1';tr = 'Transfer hataların sayısı: %1';it = 'Numero di errori di trasferimento: %1';de = 'Anzahl der Fehler bei der Übertragung: %1'"),
			FilesArrayWithErrors.Count());
			
		If ProcessingAborted Then
			Note = NStr("ru = 'Не удалось перенести ни одного файла из пакета.
			                       |Перенос прерван.'; 
			                       |en = 'Cannot transfer any file from the package.
			                       |Transfer is canceled.'; 
			                       |pl = 'Nie udało się przenieść żadnego pliku z paczki.
			                       |Przerwano przeniesienie.';
			                       |es_ES = 'Ni un archivo del paquete se ha podido trasladar.
			                       |Traslado anulado.';
			                       |es_CO = 'Ni un archivo del paquete se ha podido trasladar.
			                       |Traslado anulado.';
			                       |tr = 'Hiçbir dosya paketten aktarılamadı. 
			                       |Aktarım iptal edildi.';
			                       |it = 'Impossible trasferire file dal pacchetto.
			                       |Trasferimento annullato.';
			                       |de = 'Fehler beim Übertragen einer Datei aus dem Paket.
			                       |Übertragung abgebrochen.'");
		EndIf;
		
		FormParameters = New Structure;
		FormParameters.Insert("Explanation", Note);
		FormParameters.Insert("FilesArrayWithErrors", FilesArrayWithErrors);
		
		OpenForm("DataProcessor.MoveFilesToVolumes.Form.ReportForm", FormParameters);
		
	EndIf;
	
	Close();
	
EndProcedure

&AtServer
Function FileVersionsSizeInInfobase()
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ISNULL(SUM(FilesVersions.Size), 0) AS Size
	|FROM
	|	Catalog.FilesVersions AS FilesVersions
	|WHERE
	|	FilesVersions.FileStorageType = Value(Enum.FileStorageTypes.InInfobase)";
	
	For Each CatalogType In Metadata.DefinedTypes.AttachedFile.Type.Types() Do
		FullCatalogName = Metadata.FindByType(CatalogType).FullName();
		If FullCatalogName <> "Catalog.Files" AND FullCatalogName <> "Catalog.FilesVersions" Then
			Query.Text = Query.Text + 
			"
			|UNION ALL
			|
			|SELECT
			|	ISNULL(SUM(FilesVersions.Size), 0) AS Size
			|FROM
			|	" + FullCatalogName + " AS FilesVersions
			|WHERE
			|	FilesVersions.FileStorageType = VALUE(Enum.FileStorageTypes.InInfobase)";
		EndIf;
	EndDo;
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return 0;
	EndIf;
	
	Selection = Result.Select();
	Selection.Next();
	Return Selection.Size;
	
EndFunction

&AtServer
Function FileVersionsInInfobaseCount()
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	COUNT(*) AS Count
		|FROM
		|	InformationRegister.FilesBinaryData AS FilesBinaryData";
	Query.SetParameter("FileStorageType", Enums.FileStorageTypes.InInfobase);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return 0;
	EndIf;
	
	Selection = Result.Select();
	Selection.Next();
	Return Selection.Count;
	
EndFunction

&AtServer
Function VersionsInBase()
	
	VersionsArray = New Array;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	FilesVersions.Ref AS Ref,
		|	FilesVersions.Description AS FullDescr,
		|	FilesVersions.Size AS Size
		|FROM
		|	Catalog.FilesVersions AS FilesVersions
		|WHERE
		|	FilesVersions.FileStorageType = VALUE(Enum.FileStorageTypes.InInfobase)
		|";
	
	For Each CatalogType In Metadata.DefinedTypes.AttachedFile.Type.Types() Do
		FullCatalogName = Metadata.FindByType(CatalogType).FullName();
		If FullCatalogName <> "Catalog.Files" AND FullCatalogName <> "Catalog.FilesVersions" Then
			Query.Text = Query.Text + 
			"
			|UNION ALL
			|
			|SELECT
			|	FilesVersions.Ref AS Ref,
			|	FilesVersions.Description AS FullDescr,
			|	FilesVersions.Size AS Size
			|FROM
			|	" + FullCatalogName + " AS FilesVersions
			|WHERE
			|	FilesVersions.FileStorageType = VALUE(Enum.FileStorageTypes.InInfobase)";
		EndIf;
	EndDo;
	
	Result = Query.Execute();
	ExportedTable = Result.Unload();
	
	For Each Row In ExportedTable Do
		VersionStructure = New Structure("Ref, Text, Size", 
			Row.Ref, Row.FullDescr, Row.Size);
		VersionsArray.Add(VersionStructure);
	EndDo;
	
	Return VersionsArray;
	
EndFunction

&AtServerNoContext
Function FilesStorageProperties()
	
	FilesStorageProperties = New Structure;
	
	FilesStorageProperties.Insert(
		"FilesStorageTyoe", FilesOperationsInternal.FilesStorageTyoe());
	
	FilesStorageProperties.Insert(
		"HasFileStorageVolumes", FilesOperations.HasFileStorageVolumes());
	
	Return FilesStorageProperties;
	
EndFunction

&AtServer
Function MoveVersionsArrayToVolume(VersionsPackage, FilesArrayWithErrors)
	
	SetPrivilegedMode(True);
	
	ProcessedItemsCount = 0;
	MaxFileSize = FilesOperations.MaxFileSize();
	
	For Each VersionStructure In VersionsPackage Do
		
		If MoveVersionToVolume(VersionStructure, MaxFileSize, FilesArrayWithErrors) Then
			ProcessedItemsCount = ProcessedItemsCount + 1;
		EndIf;
		
	EndDo;
	
	Return ProcessedItemsCount;
	
EndFunction

&AtServer
Function MoveVersionToVolume(VersionStructure, MaxFileSize, FilesArrayWithErrors)
	
	ReturnCode = True;
	
	VersionRef = VersionStructure.Ref;
	If TypeOf(VersionRef) = Type("CatalogRef.FilesVersions") Then
		FileRef = VersionRef.Owner;
	Else
		FileRef = VersionRef;
	EndIf;
	Size = VersionStructure.Size;
	NameForLog = "";
	
	If Size > MaxFileSize Then
		
		NameForLog = VersionStructure.Text;
		WriteLogEvent(NStr("ru = 'Файлы.Ошибка переноса файла в том'; en = 'Files.Cannot transfer the file to the volume'; pl = 'Pliki.Nie można przenieść pliku do woluminu';es_ES = 'Archivos.No se puede trasladar el archivo al volumen';es_CO = 'Archivos.No se puede trasladar el archivo al volumen';tr = 'Dosyalar. Dosya birime aktarılamıyor';it = 'File. Impossibile trasferire il file al volume';de = 'Dateien. Die Datei kann nicht auf das Volumen übertragen werden'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,, FileRef,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'При переносе в том файла
				           |""%1""
				           |возникла ошибка:
				           |""Размер превышает максимальный"".'; 
				           |en = 'An error occurred while transferring file
				           |""%1""
				           |to volume: 
				           |""Exceeds the maximum size"".'; 
				           |pl = 'Podczas przeniesienia do woluminu pliku
				           |""%1""
				           |wystąpił błąd:
				           |""Rozmiar przekracza wartość maksymalną"".';
				           |es_ES = 'Trasladando al volumen de archivos
				           |""%1""
				           |,ha ocurrido un error:
				           |""Tamaño excede el máximo"".';
				           |es_CO = 'Trasladando al volumen de archivos
				           |""%1""
				           |,ha ocurrido un error:
				           |""Tamaño excede el máximo"".';
				           |tr = '
				           |""%1""
				           | dosya birimine aktarılırken bir hata oluştu: 
				           |""Boyut maksimum değerini aşıyor"".';
				           |it = 'Errore durante il trasferimento del file
				           |""%1""
				           |al volume: 
				           |""Superata dimensione massima"".';
				           |de = 'Bei der Übertragung auf das Datei-Volumen
				           |""%1""
				           |ist ein Fehler aufgetreten:
				           |""Größe überschreitet das Maximum"".'"),
				NameForLog));
		
		Return False; // do not report anything
	EndIf;
	
	NameForLog = VersionStructure.Text;
	WriteLogEvent(NStr("ru = 'Файлы.Начат перенос файла в том'; en = 'Files.File transfer to the volume has started'; pl = 'Pliki.Rozpoczęło się przeniesienie plików do woluminu';es_ES = 'Archivos.Traslado de archivos al volumen se ha iniciado';es_CO = 'Archivos.Traslado de archivos al volumen se ha iniciado';tr = 'Dosyalar. Birime dosya aktarımı başladı';it = 'trasferimento Files.File al volume è iniziata';de = 'Dateien. Die Dateiübertragung auf das Volumen wurde gestartet'", CommonClientServer.DefaultLanguageCode()),
		EventLogLevel.Information,, FileRef,
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Начат перенос в том файла
			           |""%1"".'; 
			           |en = 'Transfer of file
			           |""%1"" to the volume is started.'; 
			           |pl = 'Rozpoczęto transfer do woluminu pliku
			           |""%1"".';
			           |es_ES = 'Traslado al volumen de archivos se ha empezado
			           |""%1"".';
			           |es_CO = 'Traslado al volumen de archivos se ha empezado
			           |""%1"".';
			           |tr = 'Dosya birimine aktarma işlemi başladı 
			           |""%1"".';
			           |it = 'Iniziato trasferimento del file
			           |""%1"" al volume.';
			           |de = 'Übertragung in Volume der Datei
			           |""%1""gestartet.'"),
			NameForLog));
	
	Try
		LockDataForEdit(FileRef);
	Except
		Return False; // do not report anything
	EndTry;
	
	Try
		LockDataForEdit(VersionRef);
	Except
		UnlockDataForEdit(FileRef);
		Return False; // do not report anything
	EndTry;
	
	FileStorageType = Common.ObjectAttributeValue(VersionRef, "FileStorageType");
	If FileStorageType <> Enums.FileStorageTypes.InInfobase Then // File is already in the volume.
		UnlockDataForEdit(FileRef);
		UnlockDataForEdit(VersionRef);
		Return False;
	EndIf;
	
	BeginTransaction();
	
	Try
		
		VersionLock = New DataLock;
		DataLockItem = VersionLock.Add(Metadata.FindByType(TypeOf(VersionRef)).FullName());
		DataLockItem.SetValue("Ref", VersionRef);
		VersionLock.Lock();
		
		VersionObject = VersionRef.GetObject();
		FileStorage = FilesOperations.FileFromInfobaseStorage(VersionRef);
		If TypeOf(VersionObject) = Type("CatalogObject.FilesVersions") Then
			FileInfo = FilesOperationsInternal.AddFileToVolume(FileStorage.Get(), VersionObject.UniversalModificationDate, 
				VersionObject.FullDescr, VersionObject.Extension, VersionObject.VersionNumber, FileRef.Encrypted, 
				// To prevent files from getting into one folder for today, inserting the date of file creation.
				VersionObject.UniversalModificationDate);
		Else
			FileInfo = FilesOperationsInternal.AddFileToVolume(FileStorage.Get(), VersionObject.UniversalModificationDate, 
				VersionObject.Description, VersionObject.Extension, , FileRef.Encrypted, 
				// To prevent files from getting into one folder for today, inserting the date of file creation.
				VersionObject.UniversalModificationDate);
		EndIf;
			
		VersionObject.Volume = FileInfo.Volume;
		VersionObject.PathToFile = FileInfo.PathToFile;
		VersionObject.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive;
		VersionObject.StorageFile = New ValueStorage("");
		// To write a previously signed object.
		VersionObject.AdditionalProperties.Insert("WriteSignedObject", True);
		VersionObject.Write();
		
		ObjectLock = New DataLock;
		DataLockItem = ObjectLock.Add(Metadata.FindByType(TypeOf(FileRef)).FullName());
		DataLockItem.SetValue("Ref", FileRef);
		ObjectLock.Lock();
		
		FileObject = FileRef.GetObject();
		// To write a previously signed object.
		FileObject.AdditionalProperties.Insert("WriteSignedObject", True);
		FileObject.Write(); // To move version fields to file.
		
		FilesOperationsInternalServerCall.DeleteRecordFromRegisterOfFilesBinaryData(VersionRef);
		
		WriteLogEvent(
			NStr("ru = 'Файлы.Завершен перенос файла в том'; en = 'Files.File transfer to the volume is completed'; pl = 'Pliki.Rozpoczęło się plików do woluminu zostało zakończone';es_ES = 'Archivos.Traslado de archivos al volumen se ha finalizado';es_CO = 'Archivos.Traslado de archivos al volumen se ha finalizado';tr = 'Dosyalar. Birime dosya aktarımı tamamlandı';it = 'Files.File trasferimento nel volume è completato';de = 'Dateien. Die Dateiübertragung auf das Volumen ist abgeschlossen'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Information,, FileRef,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Завершен перенос в том файла
				           |""%1"".'; 
				           |en = 'Transferring file
				           |""%1"" to the volume is completed.'; 
				           |pl = 'Przeniesienie do woluminu pliku zostało zakończone
				           |""%1"".';
				           |es_ES = 'Traslado al tomo de archivos se ha finalizado
				           |""%1"".';
				           |es_CO = 'Traslado al tomo de archivos se ha finalizado
				           |""%1"".';
				           |tr = 'Dosya birimine aktarma işlemi tamamlandı 
				           |""%1"".';
				           |it = 'Il trasferimento del file
				           |""%1"" al volume è stato completato.';
				           |de = 'Die Übertragung zum Dateivolumen ist abgeschlossen
				           |""%1"".'"), NameForLog));
		
		CommitTransaction();
	Except
		RollbackTransaction();
		ErrorInformation = ErrorInfo();
		
		ErrorStructure = New Structure;
		ErrorStructure.Insert("FileName", NameForLog);
		ErrorStructure.Insert("Error",   BriefErrorDescription(ErrorInformation));
		ErrorStructure.Insert("Version",   VersionRef);
		
		FilesArrayWithErrors.Add(ErrorStructure);
		
		WriteLogEvent(NStr("ru = 'Файлы.Ошибка переноса файла в том'; en = 'Files.Cannot transfer the file to the volume'; pl = 'Pliki.Nie można przenieść pliku do woluminu';es_ES = 'Archivos.No se puede trasladar el archivo al volumen';es_CO = 'Archivos.No se puede trasladar el archivo al volumen';tr = 'Dosyalar. Dosya birime aktarılamıyor';it = 'File. Impossibile trasferire il file al volume';de = 'Dateien. Die Datei kann nicht auf das Volumen übertragen werden'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,, FileRef,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'При переносе в том файла
				           |""%1""
				           |возникла ошибка:
				           |""%2"".'; 
				           |en = 'An error occurred when transferring file
				           |""%1""
				           |to the volume:
				           |""%2"".'; 
				           |pl = 'Podczas transferu do woluminu pliku
				           |""%1""
				           |wystąpił błąd:
				           |""%2"".';
				           |es_ES = 'Al trasladar los archivos en el tomo
				           |""%1""
				           |se ha producido un error:
				           |""%2"".';
				           |es_CO = 'Al trasladar los archivos en el tomo
				           |""%1""
				           |se ha producido un error:
				           |""%2"".';
				           |tr = '
				           |""%1""
				           | dosya birimine aktarılırken bir hata oluştu: 
				           |""%2"".';
				           |it = 'Errore durante il trasferimento del file
				           |""%1""
				           |al volume:
				           |""%2"".';
				           |de = 'Beim Verschieben in das Volume dieser Datei
				           |""%1""
				           |ist ein Fehler aufgetreten:
				           |""%2"".'"),
				NameForLog,
				DetailErrorDescription(ErrorInformation)));
				
		ReturnCode = False;
		
	EndTry;
	
	UnlockDataForEdit(FileRef);
	UnlockDataForEdit(VersionRef);
	
	Return ReturnCode;
	
EndFunction

#EndRegion
