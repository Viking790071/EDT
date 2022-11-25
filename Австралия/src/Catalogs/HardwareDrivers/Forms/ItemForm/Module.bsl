
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Parameters.Property("FullFileName") Then
		ExportDriverFileName = Parameters.FullFileName;
	EndIf;
	
	AdditionalInformation = "";
	ProvidedApplication = Object.Predefined;
	
	If Not ValueIsFilled(Object.Ref) Then
		Object.SuppliedAsDistribution = True;
	EndIf;
	
	If Not ProvidedApplication AND Not IsBlankString(Object.DriverFileName) Then
		DriverLink = GetURL(Object.Ref, "ExportedDriver");
		DriverFileName = Object.DriverFileName;
	EndIf;
	
	Items.DriverFileName.Visible = Not ProvidedApplication;
	Items.DriverTemplateName.Visible = ProvidedApplication;
	Items.EquipmentType.ReadOnly = ProvidedApplication;
	Items.Description.ReadOnly = ProvidedApplication;
	Items.ObjectID.ReadOnly = ProvidedApplication;
	Items.ObjectID.InputHint = ?(ProvidedApplication, NStr("en = '<Not specified>'; ru = '<Не указано>';pl = '<Nieokreślono>';es_ES = '<No especificado>';es_CO = '<No especificado>';tr = '<Belirtilmedi>';it = '<Non specificato>';de = '<Nicht eingegeben>'"), 
		NStr("en = '<component ProgID is not entered>'; ru = '<ProgID компонент не введен>';pl = '<nie wprowadzono komponentu ProgID>';es_ES = '<componente ProgID no introducido>';es_CO = '<componente ProgID no introducido>';tr = '<bileşen ProgID girilmedi>';it = '<Componente ProgID non viene inserita>';de = '<Komponente ProgID wurde nicht eingegeben>'"));
	Items.DriverTemplateName.InputHint = ?(ProvidedApplication, NStr("en = '<Not specified>'; ru = '<Не указано>';pl = '<Nieokreślono>';es_ES = '<No especificado>';es_CO = '<No especificado>';tr = '<Belirtilmedi>';it = '<Non specificato>';de = '<Nicht eingegeben>'"), "");
	
	Items.Save.Visible = Not ProvidedApplication;
	Items.WriteAndClose.Visible = Not ProvidedApplication;
	Items.FormClose.Visible =ProvidedApplication;
	Items.FormClose.DefaultButton = Items.FormClose.Visible;
		 
	// Import and install the driver from the available list layouts.
	For Each DriverLayout In Metadata.CommonTemplates Do
		If Find(DriverLayout.Name, "Driver") > 0 Then
			Items.DriverTemplateName.ChoiceList.Add(DriverLayout.Name);
		EndIf;
	EndDo;  
	
	TextColor = StyleColors.FormTextColor;
	InstallationColor = StyleColors.FieldSelectionBackColor;
	ErrorColor = StyleColors.NegativeTextColor;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not IsBlankString(ExportDriverFileName) Then
	#If Not WebClient Then
		ImportDriverFile(ExportDriverFileName);
	#EndIf
	Else
		UpdateItemsState();
	EndIf;
	
	If Not IsBlankString(Object.Ref) Then
		RefreshDriverStatus();
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Get the file from storage and put it into object.
	If IsTempStorageURL(DriverLink) Then
		BinaryData = GetFromTempStorage(DriverLink);
		CurrentObject.ExportedDriver = New ValueStorage(BinaryData, New Deflation(5));
		CurrentObject.DriverFileName = DriverFileName;
	EndIf;

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	If Not IsBlankString(Object.DriverFileName) Then
		DriverLink = GetURL(Object.Ref, "ExportedDriver");
		DriverFileName = Object.DriverFileName;
	EndIf;
	
	UpdateItemsState();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If IsBlankString(Object.EquipmentType) Then 
		Cancel = True;
		CommonClientServer.MessageToUser(NStr("en = 'Equipment type is not specified.'; ru = 'Тип оборудования не указан.';pl = 'Typ urządzenia nie został określony.';es_ES = 'Tipo de equipamiento no especificado.';es_CO = 'Tipo de equipamiento no especificado.';tr = 'Ekipman tipi belirtilmedi.';it = 'Il tipo di apparecchiatura non è specificato.';de = 'Gerätetyp ist nicht angegeben.'")); 
		Return;
	EndIf;
	
	If IsBlankString(Object.Description) Then 
		Cancel = True;
		CommonClientServer.MessageToUser(NStr("en = 'Name is not specified.'; ru = 'Наименование не указано.';pl = 'Nie określono nazwy.';es_ES = 'Nombre no está especificado.';es_CO = 'Nombre no está especificado.';tr = 'İsim belirtilmedi.';it = 'Nome non specificato.';de = 'Name ist nicht angegeben.'")); 
		Return;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ExportDriverFileCommand(Command)
	
	If ProvidedApplication Then
		
		If IsBlankString(Object.DriverTemplateName) Then
			CommonClientServer.MessageToUser(NStr("en = 'Driver template name is not specified.'; ru = 'Имя макета драйвера не указано.';pl = 'Nazwa szablonu sterownika nie została określona.';es_ES = 'Nombre del modelo del driver no está especificado.';es_CO = 'Nombre del modelo del driver no está especificado.';tr = 'Sürücü şablon adı belirtilmedi.';it = 'Nome del modello del driver non specificato.';de = 'Der Name der Treiber- Vorlage wurde nicht angegeben.'"));
			Return;
		Else
			ExportDriverLayout();
		EndIf;
		
	Else 
		
		If IsBlankString(Object.DriverFileName) Then
			CommonClientServer.MessageToUser(NStr("en = 'Driver file is not imported.'; ru = 'Файл драйвера не загружен.';pl = 'Plik sterownika nie został zaimportowany.';es_ES = 'Archivo del driver no se ha importado.';es_CO = 'Archivo del driver no se ha importado.';tr = 'Sürücü dosyası içe aktarılmadı.';it = 'File del driver non importato.';de = 'Die Treiber- Datei wird nicht importiert.'"));
			Return;
		EndIf;
		
		If Modified Then
			Text = NStr("en = 'You can continue only after the data is saved.
			            |Write data and continue?'; 
			            |ru = 'Продолжение операции возможно только после записи данных.
			            |Записать данные и продолжить?';
			            |pl = 'Możesz kontynuować tylko po zapisaniu danych.
			            |Zapisać dane i kontynuować?';
			            |es_ES = 'Usted puede continuar solo después de haber guardado los datos.
			            |¿Inscribir los datos y continuar?';
			            |es_CO = 'Usted puede continuar solo después de haber guardado los datos.
			            |¿Inscribir los datos y continuar?';
			            |tr = 'Sadece veriler kaydedildikten sonra devam edebilirsiniz.
			            | Veri yaz ve devam et?';
			            |it = 'Il proseguimento dell''operazione è possibile solo dopo la registrazione dei dati.
			            |Registrare i dati e continuare?';
			            |de = 'Sie können erst fortfahren, nachdem die Daten gespeichert wurden.
			            |Daten speichern und fortsetzen?'");
			Notification = New NotifyDescription("ExportDriverFileEnd", ThisObject);
			ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo);
		Else
			ExportDriverFile();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportDriverFileEnd(Result, Parameters)Export 
	
	If Result = DialogReturnCode.Yes Then
		If Modified AND Not Write() Then
			Return;
		EndIf;
		ExportDriverFile();
	EndIf;  
	
EndProcedure

&AtClient
Procedure ImportDriverFileCommand(Command)
	
	#If WebClient Then
		ShowMessageBox(, NStr("en = 'This functionality is available only in the thin and thick client mode.'; ru = 'Данный функционал доступен только в режиме тонкого и толстого клиента.';pl = 'Ta funkcja jest dostępna tylko w trybie cienkiego i grubego klienta.';es_ES = 'Esta funcionalidad está disponible solo en el modo de cliente ligero y el cliente pesado.';es_CO = 'Esta funcionalidad está disponible solo en el modo de cliente ligero y el cliente pesado.';tr = 'Bu işlevsellik yalnızca ince ve kalın istemci modunda kullanılabilir.';it = 'Questa funzionalità è disponibile solo in modalità client thin e thick.';de = 'Diese Funktionalität ist nur im Thin- und Thick-Client-Modus verfügbar.'"));
		Return;
	#EndIf
	
	Notification = New NotifyDescription("DriverFileChoiceEnd", ThisObject);
	EquipmentManagerClient.StartDriverFileSelection(Notification);
	
EndProcedure

&AtClient
Procedure InstallDriverCommand(Command)
	
	If Modified Then
		Text = NStr("en = 'You can continue only after the data is saved.
		            |Write data and continue?'; 
		            |ru = 'Продолжение операции возможно только после записи данных.
		            |Записать данные и продолжить?';
		            |pl = 'Możesz kontynuować tylko po zapisaniu danych.
		            |Zapisać dane i kontynuować?';
		            |es_ES = 'Usted puede continuar solo después de haber guardado los datos.
		            |¿Inscribir los datos y continuar?';
		            |es_CO = 'Usted puede continuar solo después de haber guardado los datos.
		            |¿Inscribir los datos y continuar?';
		            |tr = 'Sadece veriler kaydedildikten sonra devam edebilirsiniz.
		            | Veri yaz ve devam et?';
		            |it = 'Il proseguimento dell''operazione è possibile solo dopo la registrazione dei dati.
		            |Registrare i dati e continuare?';
		            |de = 'Sie können erst fortfahren, nachdem die Daten gespeichert wurden.
		            |Daten speichern und fortsetzen?'");
		Notification = New NotifyDescription("SetupDriverEnd", ThisObject);
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo);
	Else
		SetupDriver();
	EndIf
	
EndProcedure

&AtClient
Procedure SetupDriverEnd(Result, Parameters) Export 
	
	If Result = DialogReturnCode.Yes Then
		If Modified AND Not Write() Then
			Return;
		EndIf;
		SetupDriver();
	EndIf;  
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure ReadInformationAboutDriver(FileInformation)
	
	XMLReader = New XMLReader;
	XMLReader.SetString(FileInformation);
	XMLReader.MoveToContent();
	
	If XMLReader.Name = "drivers" AND XMLReader.NodeType = XMLNodeType.StartElement Then  
		While XMLReader.Read() Do 
			If XMLReader.Name = "component" AND XMLReader.NodeType = XMLNodeType.StartElement Then  
				Object.ObjectID = XMLReader.AttributeValue("progid");
				Object.Description = XMLReader.AttributeValue("name");
				Object.DriverVersion = XMLReader.AttributeValue("version");
				TempEquipmentType = XMLReader.AttributeValue("type");
				If Not IsBlankString(TempEquipmentType) Then
					Object.EquipmentType = EquipmentManagerServerCall.GetEquipmentType(TempEquipmentType);
				EndIf;
			EndIf;
		EndDo;  
	EndIf;
	XMLReader.Close(); 
	
EndProcedure

&AtClient
Procedure ImportDriverFileWhenFinished(PlacedFiles, FileName) Export 
	
	If PlacedFiles.Count() > 0 Then
		DriverFileName = FileName;
		DriverLink = PlacedFiles[0].Location;
		UpdateItemsState();
	EndIf;
	
EndProcedure

#If Not WebClient Then

&AtClient
Procedure DriverFileChoiceEnd(FullFileName, Parameters) Export
	
	If Not IsBlankString(FullFileName) Then
		ImportDriverFile(FullFileName);
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportDriverFile(FullFileName)
	
	TempDriverFile = New File(FullFileName);
	
	If GetDriverInformationByFile(FullFileName) Then
		Notification = New NotifyDescription("ImportDriverFileWhenFinished", ThisObject, TempDriverFile.Name);
		BeginPuttingFiles(Notification, Undefined, TempDriverFile.FullName, False) 
	EndIf;
	
EndProcedure

&AtClient
Function GetDriverInformationByFile(FullFileName) 
	
	Result = False;
	
	DriverFile = New File(FullFileName);
	FileExtension = Upper(DriverFile.Extension);
	
	If Not EquipmentManagerClientReUse.IsLinuxClient() AND FileExtension = ".EXE" Then
		
		// Driver file comes with distribution.
		Object.SuppliedAsDistribution = True; 
		Result = True;
		Return Result;
		
	ElsIf FileExtension = ".ZIP" Then
		
		DriverArchive = New ZipFileReader();
		DriverArchive.Open(FullFileName);
		
		For Each ArchiveItem In DriverArchive.Items Do
			ManifestFound = False;
			
			// Check if there is manifest file.
			If Upper(ArchiveItem.Name) = "MANIFEST.XML" Then
				Object.SuppliedAsDistribution = False; 
				ManifestFound = True;
				Result = True;
			EndIf;
			
			// Check if there is information file.
			If Upper(ArchiveItem.Name) = "INFO.XML" Then
				TemporaryDirectory = TempFilesDir() + "cel\";
				DriverArchive.Extract(ArchiveItem, TemporaryDirectory);
				InformationFile = New TextReader(TemporaryDirectory + "INFO.XML", TextEncoding.UTF8);
				ReadInformationAboutDriver(InformationFile.Read());
				InformationFile.Close(); 
				BeginDeletingFiles(, TemporaryDirectory + "INFO.XML");
			EndIf;
			
			// Driver comes packaged in distribution archive.
			If Not EquipmentManagerClientReUse.IsLinuxClient() AND Not ManifestFound Then
				If (Upper(ArchiveItem.Name) = "SETUP.EXE" Or Upper(ArchiveItem.Name) = Upper(DriverFile.BaseName) + ".EXE") Then
					Object.SuppliedAsDistribution = True; 
					Result = True;
				EndIf;
			EndIf;
			
		EndDo;
		
		If IsBlankString(Object.ObjectID) Then
			Object.ObjectID = "AddIn.None";
		EndIf;
		
		Return Result;
		
	Else
		ShowMessageBox(, NStr("en = 'Invalid file extension.'; ru = 'Неверное расширение файла.';pl = 'Nieprawidłowe rozszerzenie pliku.';es_ES = 'Extensión de archivos inválido.';es_CO = 'Extensión de archivos inválido.';tr = 'Geçersiz dosya uzantısı.';it = 'Estensione del file non valida.';de = 'Ungültige Dateiendung.'"));
		Return Result;
	EndIf;

EndFunction

#EndIf

&AtClient
Procedure RefreshDriverCurrentStatus()
	
	If NewArchitecture AND IntegrationLibrary Then
		DriverCurrentStatus = NStr("en = 'Integration library is installed.'; ru = 'Установлена интеграционная библиотека.';pl = 'Zainstalowano bibliotekę integracji.';es_ES = 'Biblioteca de integración está instalada.';es_CO = 'Biblioteca de integración está instalada.';tr = 'Entegrasyon kütüphanesi yüklü.';it = 'La libreria di integrazione è installata.';de = 'Integrationsbibliothek ist installiert.'");
		DriverCurrentStatus = DriverCurrentStatus + ?(MainDriverIsSet, NStr("en = 'Main driver supply is installed.'; ru = 'Установлена основная поставка драйвера.';pl = 'Zainstalowano główny sterownik.';es_ES = 'Soporte del driver principal está instalado.';es_CO = 'Soporte del driver principal está instalado.';tr = 'Ana sürücü kaynağı yüklendi.';it = 'Installata fornitura principale del driver.';de = 'Die Haupttreiberversorgung ist installiert.'"),
																					 NStr("en = 'Main driver supply is not installed.'; ru = 'Основная поставка драйвера не установлена.';pl = 'Nie zainstalowano głównego sterownika.';es_ES = 'Soporte del driver principal no está instalado.';es_CO = 'Soporte del driver principal no está instalado.';tr = 'Ana sürücü kaynağı yüklü değil.';it = 'La fornitura del driver principale non è installata.';de = 'Die Haupttreiberversorgung ist nicht installiert.'")); 
	Else
		DriverCurrentStatus = NStr("en = 'Installed on the current computer.'; ru = 'Установлен на текущем компьютере.';pl = 'Zainstalowano na bieżącym komputerze.';es_ES = 'Instalado en el ordenador actual.';es_CO = 'Instalado en el ordenador actual.';tr = 'Mevcut bilgisayara yüklendi.';it = 'Installato sul computer corrente.';de = 'Auf dem aktuellen Computer installiert.'");
	EndIf;
	If Not IsBlankString(CurrentVersion) Then
		DriverCurrentStatus = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 (Version: %2)'; ru = '%1 (Версия: %2)';pl = '%1 (Wersja: %2)';es_ES = '%1 (Versión: %2)';es_CO = '%1 (Versión: %2)';tr = '%1 (Sürüm: %2)';it = '%1 (Versione: %2)';de = '%1 (Version: %2)'"), DriverCurrentStatus, CurrentVersion);
	EndIf;
	
EndProcedure

&AtClient
Procedure GetVersionNumberEnd(ResultOfCall, CallParameters, AdditionalParameters) Export;
	
	If Not IsBlankString(ResultOfCall) Then
		CurrentVersion = ResultOfCall;
		RefreshDriverCurrentStatus();
	EndIf;
	
EndProcedure

&AtClient
Procedure GetDescriptionEnd(ResultOfCall, CallParameters, AdditionalParameters) Export;
	
	NewArchitecture = True;
	DriverDescription = CallParameters[0];
	DetailsDriver     = CallParameters[1];
	EquipmentType      = CallParameters[2]; 
	AuditInterface    = CallParameters[3];
	IntegrationLibrary  = CallParameters[4];
	MainDriverIsSet = CallParameters[5];
	URLExportDriver       = CallParameters[6];
	RefreshDriverCurrentStatus();
	
EndProcedure

&AtClient
Procedure GettingDriverObjectEnd(DriverObject, Parameters) Export
	
	If IsBlankString(Object.ObjectID) AND ProvidedApplication Then
		DriverCurrentStatus = NStr("en = 'Driver installation is not required.'; ru = 'Установка драйвера не требуется.';pl = 'Instalacja sterownika nie jest wymagana.';es_ES = 'Instalación del driver no se requiere.';es_CO = 'Instalación del driver no se requiere.';tr = 'Sürücü kurulumu gerekli değildir.';it = 'Non è richiesta l''installazione del driver.';de = 'Die Treiberinstallation ist nicht erforderlich.'");
	ElsIf IsBlankString(DriverObject) Then
		DriverCurrentStatus = NStr("en = 'Not installed on the current computer. Type is not defined:'; ru = 'Не установлен на текущем компьютере. Не определен тип:';pl = 'Nie zainstalowano na bieżącym komputerze. Typ nie jest zdefiniowany:';es_ES = 'No instalado en el ordenador actual. Tipo no está definido:';es_CO = 'No instalado en el ordenador actual. Tipo no está definido:';tr = 'Mevcut bilgisayarda yüklü değil. Tür tanımlanmamış:';it = 'Non installato nel computer corrente. Tipo non definito:';de = 'Nicht auf dem aktuellen Computer installiert. Typ ist nicht definiert:'") + Chars.NBSp + Object.ObjectID;
		Items.DriverCurrentStatus.TextColor = ErrorColor;
	Else
		Items.FormSetupDriver.Enabled = False;
		Items.DriverCurrentStatus.TextColor = InstallationColor;
		CurrentVersion = "";
		Try
			MethodNotification = New NotifyDescription("GetVersionNumberEnd", ThisObject);
			DriverObject.StartCallGetVersionNumber(MethodNotification);
		Except
		EndTry;
		
		Try
			NewArchitecture          = False;
			DriverDescription      = "";
			DetailsDriver          = "";
			EquipmentType           = "";
			IntegrationLibrary  = False;
			MainDriverIsSet = False;
			AuditInterface         = 1012;
			URLExportDriver       = "";
			MethodNotification = New NotifyDescription("GetDescriptionEnd", ThisObject);
			DriverObject.StartCallGetDescription(MethodNotification, DriverDescription, DetailsDriver, EquipmentType, AuditInterface, 
											IntegrationLibrary, MainDriverIsSet, URLExportDriver);
		Except
			RefreshDriverCurrentStatus()
		EndTry;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshDriverStatus();
	
	DriverData = New Structure();
	DriverData.Insert("HardwareDriver"       , Object.Ref);
	DriverData.Insert("AsConfigurationPart"      , Object.Predefined);
	DriverData.Insert("ObjectID"      , Object.ObjectID);
	DriverData.Insert("SuppliedAsDistribution" , Object.SuppliedAsDistribution);
	DriverData.Insert("DriverTemplateName"         , Object.DriverTemplateName);
	DriverData.Insert("DriverFileName"          , Object.DriverFileName);
	
	Items.DriverCurrentStatus.TextColor = TextColor;
	
	Notification = New NotifyDescription("GettingDriverObjectEnd", ThisObject);
	EquipmentManagerClient.StartReceivingDriverObject(Notification, DriverData);
	
EndProcedure

&AtClient
Procedure UpdateItemsState();
	
	If ProvidedApplication AND IsBlankString(Object.DriverTemplateName) Then
		VisibleExportFile = False;
	ElsIf Not ProvidedApplication AND IsBlankString(DriverFileName) Then
		VisibleExportFile = False;
	Else
		VisibleExportFile = Not IsBlankString(Object.Ref);
	EndIf;
		
	Items.FormExportDriverFile.Visible = VisibleExportFile;
	Items.FormSetupDriver.Visible     = VisibleExportFile;
	Items.FormExportDriverFile.Visible = Not ProvidedApplication;
	
	If Not IsBlankString(DriverFileName) Or ProvidedApplication Then
		If IsBlankString(Object.ObjectID) Then
			AdditionalInformation = NStr("en = 'ProgID of the component is not specified or driver installation is not required.'; ru = 'Не указан ProgID компоненты или установка драйвера не требуется.';pl = 'ProgID komponentu nie jest określony lub instalacja sterownika nie jest wymagana.';es_ES = 'ProgID del componente no está especificado o la instalación del driver no se ha requerido.';es_CO = 'ProgID del componente no está especificado o la instalación del driver no se ha requerido.';tr = 'Bileşenin progID''si belirtilmemiş veya sürücü yüklemesi gerekli değil.';it = 'ProgID della componente non è specificato o l''installazione del driver non è richiesta.';de = 'ProgID der Komponente ist nicht angegeben oder Treiberinstallation ist nicht erforderlich.'");
		ElsIf Object.SuppliedAsDistribution Then
			AdditionalInformation = NStr("en = 'Driver is supplied as a supplier distribution.'; ru = 'Драйвер поставляется в виде дистрибутива поставщика.';pl = 'Sterownik jest dostarczany w postaci dystrybutora dostawcy.';es_ES = 'Driver está proporcionado como una distribución del proveedor.';es_CO = 'Driver está proporcionado como una distribución del proveedor.';tr = 'Sürücü bir tedarikçi dağıtımı olarak sağlanır.';it = 'Il driver viene fornito come distribuzione del fornitore.';de = 'Driver ist als Lieferant Distribution erhältlich.'");
		Else
			AdditionalInformation = NStr("en = 'Driver is supplied as a component in the archive.'; ru = 'Драйвер поставляется в виде компоненты в архиве.';pl = 'Sterownik jest dostarczany jako składnik archiwum.';es_ES = 'Driver está proporcionado como un componente en el archivo.';es_CO = 'Driver está proporcionado como un componente en el archivo.';tr = 'Sürücü, arşivde bir bileşen olarak sağlanır.';it = 'Il driver viene fornito come componente nell''archivio.';de = 'Der Treiber wird als Komponente im Archiv bereitgestellt.'") +
				?(IsBlankString(Object.DriverVersion), "", Chars.LF + NStr("en = 'Component version in the archive:'; ru = 'Версия компоненты в архиве:';pl = 'Wersja komponentu w archiwum:';es_ES = 'Versión del componente en el archivo:';es_CO = 'Versión del componente en el archivo:';tr = 'Arşivdeki bileşen sürümü:';it = 'Versione della componente nell''archivio:';de = 'Version von Komponenten im Archive:'") + Chars.NBSp + Object.DriverVersion);
		EndIf;
	Else
		AdditionalInformation = NStr("en = 'Connection of the installed driver on local computers.'; ru = 'Подключение установленного драйвера на локальных компьютерах.';pl = 'Podłączenie zainstalowanego sterownika na komputerach lokalnych.';es_ES = 'Conexión del driver instalado en los ordenadores locales.';es_CO = 'Conexión del driver instalado en los ordenadores locales.';tr = 'Yüklü sürücünün yerel bilgisayarlara bağlanması.';it = 'Collegamento del driver installato nei computer locali.';de = 'Verbindung des installierten Treibers auf lokalen Computern.'");
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportDriverLayout()
	
	FileTempName = ?(IsBlankString(Object.DriverFileName), Object.DriverTemplateName + ".zip", Object.DriverFileName);
	If Upper(Right(FileTempName, 4)) = ".EXE" Then  
		FileTempName = Left(FileTempName, StrLen(FileTempName) - 4) + ".zip";  
	EndIf;
	FileReference = EquipmentManagerServerCall.GetTemplateFromServer(Object.DriverTemplateName);
	GetFile(FileReference, FileTempName); 
	
EndProcedure

&AtClient
Procedure ExportDriverFile()
	
	FileReferenceWIB = GetURL(Object.Ref, "ExportedDriver");
	GetFile(FileReferenceWIB, Object.DriverFileName); 
	
EndProcedure

&AtClient
Procedure SetDriverFromArchiveOnEnd(Result) Export 
	
	CommonClientServer.MessageToUser(NStr("en = 'Driver is installed.'; ru = 'Установка драйвера завершена.';pl = 'Sterownik jest zainstalowany.';es_ES = 'Driver está instalado.';es_CO = 'Driver está instalado.';tr = 'Sürücü yüklendi.';it = 'Il driver è installato.';de = 'Der Treiber ist installiert.'")); 
	RefreshDriverStatus();
	
EndProcedure

&AtClient
Procedure SettingDriverFromDistributionOnEnd(Result, Parameters) Export 
	
	If Result Then
		CommonClientServer.MessageToUser(NStr("en = 'Driver is installed.'; ru = 'Установка драйвера завершена.';pl = 'Sterownik jest zainstalowany.';es_ES = 'Driver está instalado.';es_CO = 'Driver está instalado.';tr = 'Sürücü yüklendi.';it = 'Il driver è installato.';de = 'Der Treiber ist installiert.'")); 
		RefreshDriverStatus();
	Else
		CommonClientServer.MessageToUser(NStr("en = 'An error occurred when installing the driver from distribution.'; ru = 'При установке драйвера из дистрибутива произошла ошибка.';pl = 'Wystąpił błąd podczas instalowania sterownika z dystrybucji.';es_ES = 'Ha ocurrido un error al instalar el driver desde la distribución.';es_CO = 'Ha ocurrido un error al instalar el driver desde la distribución.';tr = 'Sürücü dağıtımdan yüklenirken bir hata oluştu.';it = 'Si è verificato un errore durante l''installazione del driver dal distributore.';de = 'Bei der Installation des Treibers aus der Distribution ist ein Fehler aufgetreten.'")); 
	EndIf;

EndProcedure

&AtClient
Procedure SetupDriver()
	
	ClearMessages();
	
	NotificationsDriverFromDistributionOnEnd = New NotifyDescription("SettingDriverFromDistributionOnEnd", ThisObject);
	NotificationsDriverFromArchiveOnEnd = New NotifyDescription("SetDriverFromArchiveOnEnd", ThisObject);
	
	EquipmentManagerClient.SetupDriver(Object.Ref, NotificationsDriverFromDistributionOnEnd, NotificationsDriverFromArchiveOnEnd);
	
EndProcedure

#EndRegion
