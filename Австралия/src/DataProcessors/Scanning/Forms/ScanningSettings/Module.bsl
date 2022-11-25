
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	ClientID = Parameters.ClientID;
	
	ShowScannerDialog = Common.CommonSettingsStorageLoad(
		"ScanningSettings/ShowScannerDialog", 
		ClientID, True);
	
	DeviceName = Common.CommonSettingsStorageLoad(
		"ScanningSettings/DeviceName", 
		ClientID, "");
	
	ScannedImageFormat = Common.CommonSettingsStorageLoad(
		"ScanningSettings/ScannedImageFormat", 
		ClientID, Enums.ScannedImageFormats.PNG);
	
	SinglePageStorageFormat = Common.CommonSettingsStorageLoad(
		"ScanningSettings/SinglePageStorageFormat", 
		ClientID, Enums.SinglePageFileStorageFormats.PNG);
	
	MultipageStorageFormat = Common.CommonSettingsStorageLoad(
		"ScanningSettings/MultipageStorageFormat", 
		ClientID, Enums.MultipageFileStorageFormats.TIF);
	
	Permission = Common.CommonSettingsStorageLoad(
		"ScanningSettings/Permission", 
		ClientID);
	
	Chromaticity = Common.CommonSettingsStorageLoad(
		"ScanningSettings/Chromaticity", 
		ClientID);
	
	Rotation = Common.CommonSettingsStorageLoad(
		"ScanningSettings/Rotation", 
		ClientID);
	
	PaperSize = Common.CommonSettingsStorageLoad(
		"ScanningSettings/PaperSize", 
		ClientID);
	
	DuplexScanning = Common.CommonSettingsStorageLoad(
		"ScanningSettings/DuplexScanning", 
		ClientID);
	
	UseImageMagickToConvertToPDF =  Common.CommonSettingsStorageLoad(
		"ScanningSettings/UseImageMagickToConvertToPDF", 
		ClientID);
	
	JPGQuality = Common.CommonSettingsStorageLoad(
		"ScanningSettings/JPGQuality", 
		ClientID, 100);
	
	TIFFDeflation = Common.CommonSettingsStorageLoad(
		"ScanningSettings/TIFFDeflation", 
		ClientID, Enums.TIFFCompressionTypes.NoCompression);
	
	PathToConverterApplication = Common.CommonSettingsStorageLoad(
		"ScanningSettings/PathToConverterApplication", 
		ClientID, "convert.exe"); // ImageMagick
	
	JPGFormat = Enums.ScannedImageFormats.JPG;
	TIFFormat = Enums.ScannedImageFormats.TIF;
	
	MultiPageTIFFormat = Enums.MultipageFileStorageFormats.TIF;
	SinglePagePDFFormat = Enums.SinglePageFileStorageFormats.PDF;
	SinglePageJPGFormat = Enums.SinglePageFileStorageFormats.JPG;
	SinglePageTIFFormat = Enums.SinglePageFileStorageFormats.TIF;
	SinglePagePNGFormat = Enums.SinglePageFileStorageFormats.PNG;
	
	If NOT UseImageMagickToConvertToPDF Then
		MultipageStorageFormat = MultiPageTIFFormat;
	EndIf;
	
	Items.StorageFormatGroup.Visible = UseImageMagickToConvertToPDF;
	
	If UseImageMagickToConvertToPDF Then
		If SinglePageStorageFormat = SinglePagePDFFormat Then
			Items.JPGQuality.Visible = (ScannedImageFormat = JPGFormat);
			Items.TIFFDeflation.Visible = (ScannedImageFormat = TIFFormat);
		Else	
			Items.JPGQuality.Visible = (SinglePageStorageFormat = SinglePageJPGFormat);
			Items.TIFFDeflation.Visible = (SinglePageStorageFormat = SinglePageTIFFormat);
		EndIf;
	Else	
		Items.JPGQuality.Visible = (ScannedImageFormat = JPGFormat);
		Items.TIFFDeflation.Visible = (ScannedImageFormat = TIFFormat);
	EndIf;
	
	DecorationsVisible = (UseImageMagickToConvertToPDF AND (SinglePageStorageFormat = SinglePagePDFFormat));
	Items.SinglePageStorageFormatDecoration.Visible = DecorationsVisible;
	Items.ScannedImageFormatDecoration.Visible = DecorationsVisible;
	
	ScanningFormatVisibility = (UseImageMagickToConvertToPDF AND (SinglePageStorageFormat = SinglePagePDFFormat)) OR (NOT UseImageMagickToConvertToPDF);
	Items.ScanningFormatGroup.Visible = ScanningFormatVisibility;
	
	Items.PathToConverterApplication.Enabled = UseImageMagickToConvertToPDF;
	
	Items.MultipageStorageFormat.Enabled = UseImageMagickToConvertToPDF;
	
	SinglePageStorageFormatPrevious = SinglePageStorageFormat;
	
	If NOT UseImageMagickToConvertToPDF Then
		Items.ScannedImageFormat.Title = NStr("ru = 'Формат'; en = 'Format'; pl = 'Format';es_ES = 'Formato';es_CO = 'Formato';tr = 'Format';it = 'Formato';de = 'Format'");
	Else
		Items.ScannedImageFormat.Title = NStr("ru = 'Тип'; en = 'Type'; pl = 'Typ';es_ES = 'Tipo';es_CO = 'Tipo';tr = 'Tür';it = 'Tipo';de = 'Typ'");
	EndIf;
	
	StandardSubsystemsServer.SetGroupTitleRepresentation(ThisObject,
		"SinglePageStorageFormatGroup,MultiPageStorageFormatGroup,ScanningParametersGroup");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	UpdateState();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DeviceNameOnChange(Item)
	ReadScannerSettings();
EndProcedure

&AtClient
Procedure DeviceNameChoiceProcessing(Item, ValueSelected, StandardProcessing)
	If DeviceName = ValueSelected Then // If nothing has changed, do not do anything.
		StandardProcessing = False;
	EndIf;	
EndProcedure

&AtClient
Procedure ScannedImageFormatOnChange(Item)
	
	If UseImageMagickToConvertToPDF Then
		If SinglePageStorageFormat = SinglePagePDFFormat Then
			Items.JPGQuality.Visible = (ScannedImageFormat = JPGFormat);
			Items.TIFFDeflation.Visible = (ScannedImageFormat = TIFFormat);
		Else	
			Items.JPGQuality.Visible = (SinglePageStorageFormat = SinglePageJPGFormat);
			Items.TIFFDeflation.Visible = (SinglePageStorageFormat = SinglePageTIFFormat);
		EndIf;
	Else	
		Items.JPGQuality.Visible = (ScannedImageFormat = JPGFormat);
		Items.TIFFDeflation.Visible = (ScannedImageFormat = TIFFormat);
	EndIf;
	
EndProcedure

&AtClient
Procedure PathToConverterApplicationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	If NOT FilesOperationsInternalClient.FileSystemExtensionAttached() Then
		Return;
	EndIf;
		
	OpenFileDialog = New FileDialog(FileDialogMode.Open);
	OpenFileDialog.FullFileName = PathToConverterApplication;
	Filter = NStr("ru = 'Исполняемые файлы(*.exe)|*.exe'; en = 'Executable files(*.exe)|*.exe'; pl = 'Wykonywane pliki (*.exe)|*.exe';es_ES = 'Archivos ejecutables(*.exe)|*.exe';es_CO = 'Archivos ejecutables(*.exe)|*.exe';tr = 'Yürütülebilir dosyalar (*.exe)|*.exe';it = 'File eseguibili (* .exe.) | * .exe';de = 'Ausführbare Dateien (*.exe)| *.exe'");
	OpenFileDialog.Filter = Filter;
	OpenFileDialog.Multiselect = False;
	OpenFileDialog.Title = NStr("ru = 'Выберите файл для преобразования в PDF'; en = 'Select a file to convert to PDF'; pl = 'Wybierz plik do konwersji w PDF';es_ES = 'Seleccionar un archivo para convertir en PDF';es_CO = 'Seleccionar un archivo para convertir en PDF';tr = 'PDF''ye dönüştürülecek bir dosya seçin';it = 'Selezionare un file da convertire in PDF';de = 'Wählen Sie eine Datei aus, die in PDF konvertiert werden soll'");
	If OpenFileDialog.Choose() Then
		PathToConverterApplication = OpenFileDialog.FullFileName;
	EndIf;
	
EndProcedure

&AtClient
Procedure SinglePageStorageFormatOnChange(Item)
	
	ProcessChangesSinglePageStorageFormat();
	
EndProcedure

&AtClient
Procedure UseImageMagickToConvertToPDFOnChange(Item)
	
	ProcessChangesUseImageMagick();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	ClearMessages();
	If Not CheckFilling() Then 
		Return;
	EndIf;
	
	StructuresArray = New Array;
	
	SystemInfo = New SystemInfo();
	ClientID = SystemInfo.ClientID;
	
	StructuresArray.Add (GenerateSetting("ShowScannerDialog", ShowScannerDialog, ClientID));
	StructuresArray.Add (GenerateSetting("DeviceName", DeviceName, ClientID));
	
	StructuresArray.Add (GenerateSetting("ScannedImageFormat", ScannedImageFormat, ClientID));
	StructuresArray.Add (GenerateSetting("SinglePageStorageFormat", SinglePageStorageFormat, ClientID));
	StructuresArray.Add (GenerateSetting("MultipageStorageFormat", MultipageStorageFormat, ClientID));
	StructuresArray.Add (GenerateSetting("Permission", Permission, ClientID));
	StructuresArray.Add (GenerateSetting("Chromaticity", Chromaticity, ClientID));
	StructuresArray.Add (GenerateSetting("Rotation", Rotation, ClientID));
	StructuresArray.Add (GenerateSetting("PaperSize", PaperSize, ClientID));
	StructuresArray.Add (GenerateSetting("DuplexScanning", DuplexScanning, ClientID));
	StructuresArray.Add (GenerateSetting("UseImageMagickToConvertToPDF", UseImageMagickToConvertToPDF, ClientID));
	StructuresArray.Add (GenerateSetting("JPGQuality", JPGQuality, ClientID));
	StructuresArray.Add (GenerateSetting("TIFFDeflation", TIFFDeflation, ClientID));
	StructuresArray.Add (GenerateSetting("PathToConverterApplication", PathToConverterApplication, ClientID));
	
	CommonServerCall.CommonSettingsStorageSaveArray(StructuresArray, True);
	Close();
	
EndProcedure

&AtClient
Procedure SetStandardSettings(Command)
	ReadScannerSettings();
EndProcedure

&AtClient
Procedure OpenScannedFilesNumbers(Command)
	OpenForm("InformationRegister.ScannedFilesNumbers.ListForm");
EndProcedure

#EndRegion

#Region Private

&AtClient
Function GenerateSetting(Name, Value, ClientID)
	
	Item = New Structure;
	Item.Insert("Object", "ScanningSettings/" + Name);
	Item.Insert("Settings", ClientID);
	Item.Insert("Value", Value);
	Return Item;
	
EndFunction	

&AtClient
Procedure UpdateState()
	
	Items.DeviceName.Enabled = False;
	Items.DeviceName.ChoiceList.Clear();
	Items.DeviceName.ListChoiceMode = False;
	Items.ScannedImageFormat.Enabled = False;
	Items.Permission.Enabled = False;
	Items.Chromaticity.Enabled = False;
	Items.Rotation.Enabled = False;
	Items.PaperSize.Enabled = False;
	Items.DuplexScanning.Enabled = False;
	Items.SetStandardSettings.Enabled = False;
	
	If Not FilesOperationsInternalClient.InitAddIn() Then
		Items.DeviceName.Enabled = False;
		Return;
	EndIf;
		
	If Not FilesOperationsInternalClient.ScanCommandAvailable() Then
		Items.DeviceName.Enabled = False;
		Return;
	EndIf;
		
	DeviceArray = FilesOperationsInternalClient.EnumDevices();
	For Each Row In DeviceArray Do
		Items.DeviceName.ChoiceList.Add(Row);
	EndDo;
	Items.DeviceName.Enabled = True;
	Items.DeviceName.ListChoiceMode = True;
	
	If IsBlankString(DeviceName) Then
		Return;
	EndIf;
	
	Items.ScannedImageFormat.Enabled = True;
	Items.Permission.Enabled = True;
	Items.Chromaticity.Enabled = True;
	Items.SetStandardSettings.Enabled = True;
	
	DuplexScanningNumber = FilesOperationsInternalClient.GetSetting(
		DeviceName, "DUPLEX");
	
	Items.DuplexScanning.Enabled = (DuplexScanningNumber <> -1);
	
	If Not Permission.IsEmpty() AND Not Chromaticity.IsEmpty() Then
		Items.Rotation.Enabled = Not Rotation.IsEmpty();
		Items.PaperSize.Enabled = Not PaperSize.IsEmpty();
		Return;
	EndIf;
	
	PermissionNumber = FilesOperationsInternalClient.GetSetting(DeviceName, "XRESOLUTION");
	ChromaticityNumber  = FilesOperationsInternalClient.GetSetting(DeviceName, "PIXELTYPE");
	RotationNumber = FilesOperationsInternalClient.GetSetting(DeviceName, "ROTATION");
	PaperSizeNumber  = FilesOperationsInternalClient.GetSetting(DeviceName, "SUPPORTEDSIZES");
	
	Items.Rotation.Enabled = (RotationNumber <> -1);
	Items.PaperSize.Enabled = (PaperSizeNumber <> -1);
	
	DuplexScanning = ? ((DuplexScanningNumber = 1), True, False);
	SaveToSettingsScannerParameters(PermissionNumber, ChromaticityNumber, RotationNumber, PaperSizeNumber);
	
EndProcedure

&AtServer
Procedure SaveToSettingsScannerParameters(PermissionNumber, ChromaticityNumber, RotationNumber, PaperSizeNumber) 
	
	ConvertScannerParametersToEnums(PermissionNumber, ChromaticityNumber, RotationNumber, PaperSizeNumber);
			
	StructuresArray = New Array;
	
	SystemInfo = New SystemInfo();
	ClientID = SystemInfo.ClientID;
	
	Item = New Structure;
	Item.Insert("Object", "ScanningSettings/Permission");
	Item.Insert("Settings", ClientID);
	Item.Insert("Value", Permission);
	StructuresArray.Add(Item);
	
	Item = New Structure;
	Item.Insert("Object", "ScanningSettings/Chromaticity");
	Item.Insert("Settings", ClientID);
	Item.Insert("Value", Chromaticity);
	StructuresArray.Add(Item);
	
	Item = New Structure;
	Item.Insert("Object", "ScanningSettings/Rotation");
	Item.Insert("Settings", ClientID);
	Item.Insert("Value", Rotation);
	StructuresArray.Add(Item);
	
	Item = New Structure;
	Item.Insert("Object", "ScanningSettings/PaperSize");
	Item.Insert("Settings", ClientID);
	Item.Insert("Value", PaperSize);
	StructuresArray.Add(Item);
	
	Common.CommonSettingsStorageSaveArray(StructuresArray);
	
EndProcedure

&AtClient
Procedure ReadScannerSettings()
	
	Items.ScannedImageFormat.Enabled = Not IsBlankString(DeviceName);
	Items.Permission.Enabled = Not IsBlankString(DeviceName);
	Items.Chromaticity.Enabled = Not IsBlankString(DeviceName);
	Items.DuplexScanning.Enabled = False;
	Items.SetStandardSettings.Enabled = Not IsBlankString(DeviceName);
	
	If IsBlankString(DeviceName) Then
		Items.Rotation.Enabled = False;
		Items.PaperSize.Enabled = False;
		Return;
	EndIf;
	
	PermissionNumber = FilesOperationsInternalClient.GetSetting(
		DeviceName, "XRESOLUTION");
	
	ChromaticityNumber = FilesOperationsInternalClient.GetSetting(
		DeviceName, "PIXELTYPE");
	
	RotationNumber = FilesOperationsInternalClient.GetSetting(
		DeviceName, "ROTATION");
	
	PaperSizeNumber = FilesOperationsInternalClient.GetSetting(
		DeviceName, "SUPPORTEDSIZES");
	
	DuplexScanningNumber = FilesOperationsInternalClient.GetSetting(
		DeviceName, "DUPLEX");
	
	Items.Rotation.Enabled = (RotationNumber <> -1);
	Items.PaperSize.Enabled = (PaperSizeNumber <> -1);
	
	Items.DuplexScanning.Enabled = (DuplexScanningNumber <> -1);
	DuplexScanning = ? ((DuplexScanningNumber = 1), True, False);
	
	ConvertScannerParametersToEnums(
		PermissionNumber, ChromaticityNumber, RotationNumber, PaperSizeNumber);
		
EndProcedure

&AtServer
Procedure ConvertScannerParametersToEnums(PermissionNumber, ChromaticityNumber, RotationNumber, PaperSizeNumber) 
	
	Result = FilesOperationsInternal.ScannerParametersInEnumerations(PermissionNumber, ChromaticityNumber, RotationNumber, PaperSizeNumber);
	Permission = Result.Permission;
	Chromaticity = Result.Chromaticity;
	Rotation = Result.Rotation;
	PaperSize = Result.PaperSize;
	
EndProcedure

&AtServer
Function ConvertScanningFormatToStorageFormat(ScanningFormat)
	
	If ScanningFormat = Enums.ScannedImageFormats.BMP Then
		Return Enums.SinglePageFileStorageFormats.BMP;
	ElsIf ScanningFormat = Enums.ScannedImageFormats.GIF Then
		Return Enums.SinglePageFileStorageFormats.GIF;
	ElsIf ScanningFormat = Enums.ScannedImageFormats.JPG Then
		Return Enums.SinglePageFileStorageFormats.JPG;
	ElsIf ScanningFormat = Enums.ScannedImageFormats.PNG Then
		Return Enums.SinglePageFileStorageFormats.PNG; 
	ElsIf ScanningFormat = Enums.ScannedImageFormats.TIF Then
		Return Enums.SinglePageFileStorageFormats.TIF;
	EndIf;
	
	Return Enums.SinglePageFileStorageFormats.PNG; 
	
EndFunction	

&AtServer
Function ConvertStorageFormatToScanningFormat(StorageFormat)
	
	If StorageFormat = Enums.SinglePageFileStorageFormats.BMP Then
		Return Enums.ScannedImageFormats.BMP;
	ElsIf StorageFormat = Enums.SinglePageFileStorageFormats.GIF Then
		Return Enums.ScannedImageFormats.GIF;
	ElsIf StorageFormat = Enums.SinglePageFileStorageFormats.JPG Then
		Return Enums.ScannedImageFormats.JPG;
	ElsIf StorageFormat = Enums.SinglePageFileStorageFormats.PNG Then
		Return Enums.ScannedImageFormats.PNG; 
	ElsIf StorageFormat = Enums.SinglePageFileStorageFormats.TIF Then
		Return Enums.ScannedImageFormats.TIF;
	EndIf;
	
	Return ScannedImageFormat; 
	
EndFunction	

&AtServer
Procedure ProcessChangesUseImageMagick()
	
	If NOT UseImageMagickToConvertToPDF Then
		MultipageStorageFormat = MultiPageTIFFormat;
		ScannedImageFormat = ConvertStorageFormatToScanningFormat(SinglePageStorageFormat);
		Items.ScannedImageFormat.Title = NStr("ru = 'Формат'; en = 'Format'; pl = 'Format';es_ES = 'Formato';es_CO = 'Formato';tr = 'Format';it = 'Formato';de = 'Format'");
	Else
		SinglePageStorageFormat = ConvertScanningFormatToStorageFormat(ScannedImageFormat);
		Items.ScannedImageFormat.Title = NStr("ru = 'Тип'; en = 'Type'; pl = 'Typ';es_ES = 'Tipo';es_CO = 'Tipo';tr = 'Tür';it = 'Tipo';de = 'Typ'");
	EndIf;	
	
	DecorationsVisible = (UseImageMagickToConvertToPDF AND (SinglePageStorageFormat = SinglePagePDFFormat));
	Items.SinglePageStorageFormatDecoration.Visible = DecorationsVisible;
	Items.ScannedImageFormatDecoration.Visible = DecorationsVisible;
	
	ScanningFormatVisibility = (UseImageMagickToConvertToPDF AND (SinglePageStorageFormat = SinglePagePDFFormat)) OR (NOT UseImageMagickToConvertToPDF);
	Items.ScanningFormatGroup.Visible = ScanningFormatVisibility;
	
	Items.PathToConverterApplication.Enabled = UseImageMagickToConvertToPDF;
	Items.MultipageStorageFormat.Enabled = UseImageMagickToConvertToPDF;
	Items.StorageFormatGroup.Visible = UseImageMagickToConvertToPDF;	
	
EndProcedure

&AtServer
Procedure ProcessChangesSinglePageStorageFormat()
	
	Items.ScanningFormatGroup.Visible = (SinglePageStorageFormat = SinglePagePDFFormat);
	
	If SinglePageStorageFormat = SinglePagePDFFormat Then
		ScannedImageFormat = ConvertStorageFormatToScanningFormat(SinglePageStorageFormatPrevious);
	EndIf;	
	
	DecorationsVisible = (UseImageMagickToConvertToPDF AND (SinglePageStorageFormat = SinglePagePDFFormat));
	Items.SinglePageStorageFormatDecoration.Visible = DecorationsVisible;
	Items.ScannedImageFormatDecoration.Visible = DecorationsVisible;
	
	If UseImageMagickToConvertToPDF Then
		If SinglePageStorageFormat = SinglePagePDFFormat Then
			Items.JPGQuality.Visible = (ScannedImageFormat = JPGFormat);
			Items.TIFFDeflation.Visible = (ScannedImageFormat = TIFFormat);
		Else	
			Items.JPGQuality.Visible = (SinglePageStorageFormat = SinglePageJPGFormat);
			Items.TIFFDeflation.Visible = (SinglePageStorageFormat = SinglePageTIFFormat);
		EndIf;
	Else	
		Items.JPGQuality.Visible = (ScannedImageFormat = JPGFormat);
		Items.TIFFDeflation.Visible = (ScannedImageFormat = TIFFormat);
	EndIf;
	
	SinglePageStorageFormatPrevious = SinglePageStorageFormat;
	
EndProcedure

#EndRegion
