
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Common.FileInfobase() Then
		Items.WindowsArchivePath.Title = NStr("ru = 'Для сервера 1С:Предприятия под управлением Microsoft Windows'; en = 'For 1C:Enterprise server under Microsoft Windows'; pl = 'Dla serwera 1C:Enterprise w systemie Microsoft Windows';es_ES = 'Para el servidor de la 1C:Empresa bajo Microsoft Windows';es_CO = 'Para el servidor de la 1C:Empresa bajo Microsoft Windows';tr = 'Microsoft Windows sisteminde 1C:Enterprise sunucusu için';it = 'Per server 1C:Enterprise sotto Microsoft Windows';de = 'Für den 1C:Enterprise Server unter Microsoft Windows'"); 
	Else
		Items.WindowsArchivePath.ChoiceButton = False; 
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ArchivePathWindowsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not FilesOperationsInternalClient.FileSystemExtensionAttached() Then
		FilesOperationsInternalClient.ShowFileSystemExtensionRequiredMessageBox(Undefined);
		Return;
	EndIf;
	
	Dialog = New FileDialog(FileDialogMode.Open);
	
	Dialog.Title                    = NStr("ru = 'Выберите файл'; en = 'Select file'; pl = 'Wybierz plik';es_ES = 'Seleccionar un archivo';es_CO = 'Seleccionar un archivo';tr = 'Dosya seç';it = 'Selezione del file';de = 'Datei auswählen'");
	Dialog.FullFileName               = ?(ThisObject.WindowsArchivePath = "", "files.zip", ThisObject.WindowsArchivePath);
	Dialog.Multiselect           = False;
	Dialog.Preview      = False;
	Dialog.CheckFileExist  = True;
	Dialog.Filter                       = NStr("ru = 'Архивы zip(*.zip)|*.zip'; en = 'ZIP archives(*.zip)|*.zip'; pl = 'Archiwa ZIP (*.zip)|*.zip';es_ES = 'Archivos zip(*.zip)|*.zip';es_CO = 'Archivos zip(*.zip)|*.zip';tr = 'Zip arşivleri(*.zip)|*.zip';it = 'Archivi Zip(*.zip)|*.zip';de = 'Zip-Archive(*.zip)|*.zip'");
	
	If Dialog.Choose() Then
		
		ThisObject.WindowsArchivePath = Dialog.FullFileName;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Assign(Command)
	
	ClearMessages();
	
	If IsBlankString(WindowsArchivePath) AND IsBlankString(PathToArchiveLinux) Then
		Text = NStr("ru = 'Укажите полное имя архива с
		                   |файлами начального образа (файл *.zip)'; 
		                   |en = 'Specify a full name of an archive 
		                   |with initial image files (file *.zip)'; 
		                   |pl = 'Wskaż pełną nazwę archiwum z
		                   |plikami obrazu początkowego (plik *.zip)';
		                   |es_ES = 'Especifique el nombre completo del archivo
		                   |con los archivos de la imagen inicial (archivo *.zip)';
		                   |es_CO = 'Especifique el nombre completo del archivo
		                   |con los archivos de la imagen inicial (archivo *.zip)';
		                   |tr = 'Arşivin tam adını 
		                   |ilk görüntü dosyaları (dosya*.zip) ile belirtin';
		                   |it = 'Indicate il nome completo dell''archivio con
		                   |i file dell''immagine iniziale (file *.zip)';
		                   |de = 'Geben Sie den vollständigen Namen des Archivs mit
		                   |den Dateien des Basis-Images (*.zip-Datei) an.'");
		CommonClientServer.MessageToUser(Text, , "WindowsArchivePath");
		Return;
	EndIf;
	
	If Not CommonClient.FileInfobase() Then
	
		If Not IsBlankString(WindowsArchivePath) AND (Left(WindowsArchivePath, 2) <> "\\" OR StrFind(WindowsArchivePath, ":") <> 0) Then
			ErrorText = NStr("ru = 'Путь к архиву с файлами начального образа
			                         |должен быть в формате UNC (\\servername\resource).'; 
			                         |en = 'Path to the archive with initial image files
			                         |must have the UNC format (\\servername\resource).'; 
			                         |pl = 'Ścieżka do archiwum z plikami obrazu początkowego
			                         |musi być w formacie UNC (\\servername\resource).';
			                         |es_ES = 'La ruta al archivo con las imágenes iniciales
			                         |debe ser en el formato UNC (\\servername\resource).';
			                         |es_CO = 'La ruta al archivo con las imágenes iniciales
			                         |debe ser en el formato UNC (\\servername\resource).';
			                         |tr = 'İlk görüntü dosya arşivinin 
			                         |kısayolu UNC biçiminde olmalı (\\servername\resource).';
			                         |it = 'Il percorso dell''archivio con i file dell''immagine iniziale
			                         | deve essere in formato UNC (\servername\resource).';
			                         |de = 'Der Pfad zum Dateiarchiv des Basis-Images 
			                         |muss im UNC-Format (\\servername\resource) vorliegen.'");
			CommonClientServer.MessageToUser(ErrorText, , "WindowsArchivePath");
			Return;
		EndIf;
	
	EndIf;
	
	AddFilesToVolumes();
	
	NotificationText = NStr("ru = 'Размещение файлов из архива с файлами
		|начального образа успешно завершено.'; 
		|en = 'Placement of files from archive
		|with initial images succeeded.'; 
		|pl = 'Umieszczanie plików z archiwum
		|z plikami początkowych obrazów zostało pomyślnie zakończone.';
		|es_ES = 'Colocación del archivo del archivo
		|con los archivos de la imagen inicial se ha finalizado con éxito.';
		|es_CO = 'Colocación del archivo del archivo
		|con los archivos de la imagen inicial se ha finalizado con éxito.';
		|tr = 'İlk görüntü dosyaları ile 
		|arşivden dosya yerleştirme başarıyla tamamlandı.';
		|it = 'Posizionamento file da archivio
		|con immagini iniziali riuscito.';
		|de = 'Der Speicherort der Dateien aus dem Archiv
		|mit den Dateien des Basis-Images wurde erfolgreich abgeschlossen.'");
	ShowUserNotification(NStr("ru = 'Размещение файлов'; en = 'File placement'; pl = 'Umieszczenie pliku';es_ES = 'Ubicación del archivo';es_CO = 'Ubicación del archivo';tr = 'Dosya yerleştirme';it = 'Collocazione dei file';de = 'Ablegen der Datei'"),, NotificationText);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure AddFilesToVolumes()
	
	FilesOperationsInternal.AddFilesToVolumes(WindowsArchivePath, PathToArchiveLinux);
	
EndProcedure

#EndRegion
