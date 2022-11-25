
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	TooBigFiles = Parameters.TooBigFiles;
	
	MaxFileSize = Int(FilesOperations.MaxFileSize() / (1024 * 1024));
	
	Message = StringFunctionsClientServer.SubstituteParametersToString(
	    NStr("ru = 'Некоторые файлы превышают предельный размер (%1 Мб) и не будут добавлены в хранилище.
	               |Продолжить импорт?'; 
	               |en = 'Some files exceed the file size limit (%1 MB) and will not be added to the storage.
	               |Continue import?'; 
	               |pl = 'Niektóre pliki przekraczają limit rozmiaru (%1 Mb) i nie zostaną dodane do pamięci.
	               |Czy chcesz kontynuować?';
	               |es_ES = 'Algunos de los archivos exceden el límite de tamaño (%1Mb) y no se añadirán al almacenamiento.
	               |¿Continuar la importación?';
	               |es_CO = 'Algunos de los archivos exceden el límite de tamaño (%1Mb) y no se añadirán al almacenamiento.
	               |¿Continuar la importación?';
	               |tr = 'Bazı dosyalar boyut sınırını (%1Mb) aşıyor ve depolama alanına eklenmeyecek.
	               | İçe aktarmaya devam et?';
	               |it = 'Alcuni file superano il limite di dimensione massima (%1 MB) e non verranno aggiunti all''archivio.
	               |Continuare l''importazione?';
	               |de = 'Einige der Dateien überschreiten die Größenbeschränkung (%1 MB) und werden dem Speicher nicht hinzugefügt.
	               |Import fortsetzen?'"),
	    String(MaxFileSize) );
	
	Title = Parameters.Title;
	
EndProcedure

#EndRegion
