#Region Variables

&AtClient
Var GrowingImageNumber;

&AtClient
Var InsertionPosition;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	Items.FilesTable.Visible = False;
	Items.FormAcceptAllAsSingleFile.Visible = False;
	Items.FormAcceptAllAsSeparateFiles.Visible = False;
	
	If Parameters.Property("FileOwner") Then
		FileOwner = Parameters.FileOwner;
	EndIf;
	
	OneFileOnly = Parameters.OneFileOnly;
	
	If Parameters.Property("IsFile") Then
		IsFile = Parameters.IsFile;
	EndIf;
	
	ClientID = Parameters.ClientID;
	
	If Parameters.Property("DontOpenCardAfterCreateFromFIle") Then
		DontOpenCardAfterCreateFromFIle = Parameters.DontOpenCardAfterCreateFromFIle;
	EndIf;
	
	FileNumber = FilesOperationsInternalServerCall.GetNewNumberToScan(FileOwner);
	FileName = FilesOperationsInternalClientServer.ScannedFileName(FileNumber, "");

	ScannedImageFormat = Common.CommonSettingsStorageLoad(
		"ScanningSettings/ScannedImageFormat", 
		ClientID, Enums.ScannedImageFormats.PNG);
	
	SinglePageStorageFormat = Common.CommonSettingsStorageLoad(
		"ScanningSettings/SinglePageStorageFormat", 
		ClientID, Enums.SinglePageFileStorageFormats.PNG);
	
	MultipageStorageFormat = Common.CommonSettingsStorageLoad(
		"ScanningSettings/MultipageStorageFormat", 
		ClientID, Enums.MultipageFileStorageFormats.TIF);
	
	ResolutionEnum = Common.CommonSettingsStorageLoad(
		"ScanningSettings/Permission", 
		ClientID);
	
	ColorDepthEnum = Common.CommonSettingsStorageLoad(
		"ScanningSettings/Chromaticity", 
		ClientID);
	
	RotationEnum = Common.CommonSettingsStorageLoad(
		"ScanningSettings/Rotation", 
		ClientID);
	
	PaperSizeEnum = Common.CommonSettingsStorageLoad(
		"ScanningSettings/PaperSize", 
		ClientID);
	
	DuplexScanning = Common.CommonSettingsStorageLoad(
		"ScanningSettings/DuplexScanning", 
		ClientID);
	
	UseImageMagickToConvertToPDF = Common.CommonSettingsStorageLoad(
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
	
	ShowScannerDialogBoxImport = Common.CommonSettingsStorageLoad(
		"ScanningSettings/ShowScannerDialog", 
		ClientID, True);
	
	ShowScannerDialog = ShowScannerDialogBoxImport;
	
	DeviceName = Common.CommonSettingsStorageLoad(
		"ScanningSettings/DeviceName", 
		ClientID, "");
	
	ScannerName = DeviceName;
	
	If UseImageMagickToConvertToPDF Then
		If SinglePageStorageFormat = Enums.SinglePageFileStorageFormats.PDF Then
			PictureFormat = String(ScannedImageFormat);
		Else	
			PictureFormat = String(SinglePageStorageFormat);
		EndIf;
	Else	
		PictureFormat = String(ScannedImageFormat);
	EndIf;
	
	JPGFormat = Enums.ScannedImageFormats.JPG;
	TIFFormat = Enums.ScannedImageFormats.TIF;
	
	TransformCalculationsToParametersAndGetPresentation();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not ChecksOnOpenExecuted Then
		Cancel = True;
		StandardSubsystemsClient.SetFormStorage(ThisObject, True);
		AttachIdleHandler("BeforeOpen", 0.1, True);
	EndIf;
	
	InsertionPosition = Undefined;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("DataProcessor.Scanning.Form.SetupScanningForSession") Then
		
		If TypeOf(SelectedValue) <> Type("Structure") Then
			Return;
		EndIf;
		
		ResolutionEnum   = SelectedValue.Permission;
		ColorDepthEnum    = SelectedValue.Chromaticity;
		RotationEnum      = SelectedValue.Rotation;
		PaperSizeEnum = SelectedValue.PaperSize;
		DuplexScanning = SelectedValue.DuplexScanning;
		
		UseImageMagickToConvertToPDF = SelectedValue.UseImageMagickToConvertToPDF;
		
		ShowScannerDialog         = SelectedValue.ShowScannerDialog;
		ScannedImageFormat = SelectedValue.ScannedImageFormat;
		JPGQuality                     = SelectedValue.JPGQuality;
		TIFFDeflation                      = SelectedValue.TIFFDeflation;
		SinglePageStorageFormat    = SelectedValue.SinglePageStorageFormat;
		MultipageStorageFormat   = SelectedValue.MultipageStorageFormat;
		
		TransformCalculationsToParametersAndGetPresentation();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	DeleteTempFiles(FilesTable);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersFilesTable

&AtClient
Procedure FilesTableOnActivateRow(Item)
#If NOT WebClient AND NOT MobileClient Then
	If Items.FilesTable.CurrentData = Undefined Then
		Return;
	EndIf;

	CurrentRowNumber = Items.FilesTable.CurrentRow;
	TableRow = Items.FilesTable.RowData(CurrentRowNumber);
	
	If PathToSelectedFile <> TableRow.PathToFile Then
		
		PathToSelectedFile = TableRow.PathToFile;
		
		If IsBlankString(TableRow.PictureAddress) Then
			BinaryData = New BinaryData(PathToSelectedFile);
			TableRow.PictureAddress = PutToTempStorage(BinaryData, UUID);
		EndIf;
		
		PictureAddress = TableRow.PictureAddress;
		
	EndIf;
	
#EndIf
EndProcedure

&AtClient
Procedure FilesTableBeforeDelete(Item, Cancel)
	
	If FilesTable.Count() < 2 Then
		Cancel = True;
		Return;
	EndIf;
	
	CurrentRowNumber = Items.FilesTable.CurrentRow;
	TableRow = Items.FilesTable.RowData(CurrentRowNumber);
	DeleteFiles(TableRow.PathToFile);
	
	If FilesTable.Count() = 2 Then
		Items.FilesTableContextMenuDelete.Enabled = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

// The "Rescan" button replaces the selected picture (or the only picture if there are no more 
//  pictures, or adds new pictures to the end if nothing is selected) with a new image (images).
&AtClient
Procedure Rescan(Command)
	
	If FilesTable.Count() = 1 Then
		DeleteTempFiles(FilesTable);
		InsertionPosition = 0;
	ElsIf FilesTable.Count() > 1 Then
		
		CurrentRowNumber = Items.FilesTable.CurrentRow;
		TableRow = Items.FilesTable.RowData(CurrentRowNumber);
		InsertionPosition = FilesTable.IndexOf(TableRow);
		DeleteFiles(TableRow.PathToFile);
		FilesTable.Delete(TableRow);
		
	EndIf;
	
	If PictureAddress <> "" Then
		DeleteFromTempStorage(PictureAddress);
	EndIf;	
	PictureAddress = "";
	PathToSelectedFile = "";
	
	ShowDialogBox = ShowScannerDialog;
	SelectedDevice = ScannerName;
	DeflateParameter = ?(Upper(PictureFormat) = "JPG", JPGQuality, TIFFCompressionNumber);
	
	Twain = ApplicationParameters["StandardSubsystems.TwainComponent"];
	Twain.BeginScan(
		ShowDialogBox, SelectedDevice, PictureFormat, 
		Permission, Chromaticity, Rotation, PaperSize, 
		DeflateParameter,
		DuplexScanning);
		
EndProcedure

&AtClient
Procedure Save(Command)
	
	ExecutionParameters = New Structure;
	ExecutionParameters.Insert("FileArrayCopy", New Array);
	ExecutionParameters.Insert("ResultFile", "");
	
	Result = ScanningResult();
	
	For Each Row In FilesTable Do
		ExecutionParameters.FileArrayCopy.Add(New Structure("PathToFile", Row.PathToFile));
	EndDo;
	
	// Working with one file here.
	TableRow = FilesTable.Get(0);
	PathToFileLocal = TableRow.PathToFile;
	
	FilesTable.Clear(); // Not to delete files in OnClose.
	
	ResultExtension = String(SinglePageStorageFormat);
	ResultExtension = Lower(ResultExtension); 
	
	If ResultExtension = "pdf" Then
		
		#If NOT WebClient AND NOT MobileClient Then
			ExecutionParameters.ResultFile = GetTempFileName("pdf");
		#EndIf
		
		AllPathsString = PathToFileLocal;
		Twain = ApplicationParameters["StandardSubsystems.TwainComponent"];
		Twain.MergeIntoMultipageFile(
			AllPathsString, ExecutionParameters.ResultFile, PathToConverterApplication);
		
		ObjectResultFile = New File(ExecutionParameters.ResultFile);
		If NOT ObjectResultFile.Exist() Then
			MessageText = MessageTextOfTransformToPDFError(ExecutionParameters.ResultFile);
			ShowMessageBox(, MessageText);
			DeleteFiles(PathToFileLocal);
			
			Result.ErrorText = MessageText;
			AcceptCompletion(Result, ExecutionParameters);
			Return;
		EndIf;
		
		DeleteFiles(PathToFileLocal);
		PathToFileLocal = ExecutionParameters.ResultFile;
		
	EndIf;
	
	If NOT IsBlankString(PathToFileLocal) Then
		Handler = New NotifyDescription("AcceptCompletion", ThisObject, ExecutionParameters);
		
		AddingOptions = New Structure;
		AddingOptions.Insert("ResultHandler", Handler);
		AddingOptions.Insert("FullFileName", PathToFileLocal);
		AddingOptions.Insert("FileOwner", FileOwner);
		AddingOptions.Insert("OwnerForm", ThisObject);
		AddingOptions.Insert("NameOfFileToCreate", FileName);
		AddingOptions.Insert("DontOpenCardAfterCreateFromFIle", DontOpenCardAfterCreateFromFIle);
		AddingOptions.Insert("FormID", UUID);
		AddingOptions.Insert("IsFile", IsFile);
		
		FilesOperationsInternalClient.AddFormFileSystemWithExtension(AddingOptions);
		
		Return;
	EndIf;
	
	Result.ErrorText = NStr("ru='Не удалось сохранить отсканированный файл.'; en = 'Cannot save the scanned file.'; pl = 'Nie udało się zapisać zeskanowany plik.';es_ES = 'No se ha podido guardar el archivo escaneado.';es_CO = 'No se ha podido guardar el archivo escaneado.';tr = 'Taranmış dosya kaydedilemedi.';it = 'Impossibile salvare il file scansionato.';de = 'Die gescannte Datei konnte nicht gespeichert werden.'");
	AcceptCompletion(Result, ExecutionParameters);
EndProcedure

&AtClient
Procedure Setting(Command)
	
	DuplexScanningNumber = FilesOperationsInternalClient.GetSetting(
		ScannerName, "DUPLEX");
	
	DuplexScanningAvailable = (DuplexScanningNumber <> -1);
	
	FormParameters = New Structure;
	FormParameters.Insert("ShowScannerDialog",  ShowScannerDialog);
	FormParameters.Insert("Permission",               ResolutionEnum);
	FormParameters.Insert("Chromaticity",                ColorDepthEnum);
	FormParameters.Insert("Rotation",                  RotationEnum);
	FormParameters.Insert("PaperSize",             PaperSizeEnum);
	FormParameters.Insert("DuplexScanning", DuplexScanning);
	
	FormParameters.Insert(
		"UseImageMagickToConvertToPDF", UseImageMagickToConvertToPDF);
	
	FormParameters.Insert("RotationAvailable",       RotationAvailable);
	FormParameters.Insert("PaperSizeAvailable",  PaperSizeAvailable);
	
	FormParameters.Insert("DuplexScanningAvailable", DuplexScanningAvailable);
	FormParameters.Insert("ScannedImageFormat",     ScannedImageFormat);
	FormParameters.Insert("JPGQuality",                         JPGQuality);
	FormParameters.Insert("TIFFDeflation",                          TIFFDeflation);
	FormParameters.Insert("SinglePageStorageFormat",        SinglePageStorageFormat);
	FormParameters.Insert("MultipageStorageFormat",       MultipageStorageFormat);
	
	OpenForm("DataProcessor.Scanning.Form.SetupScanningForSession", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure SaveAllAsSingleFile(Command)
	
	ExecutionParameters = New Structure;
	ExecutionParameters.Insert("FileArrayCopy", New Array);
	ExecutionParameters.Insert("ResultFile", "");
	
	Result = ScanningResult();
	
	For Each Row In FilesTable Do
		ExecutionParameters.FileArrayCopy.Add(New Structure("PathToFile", Row.PathToFile));
	EndDo;
	
	FilesTable.Clear(); // Not to delete files in OnClose.
	
	// Working with all pictures here. Uniting them in one multi-page file.
	AllPathsString = "";
	For Each Row In ExecutionParameters.FileArrayCopy Do
		AllPathsString = AllPathsString + "*";
		AllPathsString = AllPathsString + Row.PathToFile;
	EndDo;
	
	#If NOT WebClient AND NOT MobileClient Then
		ResultExtension = String(MultipageStorageFormat);
		ResultExtension = Lower(ResultExtension); 
		ExecutionParameters.ResultFile = GetTempFileName(ResultExtension);
	#EndIf
	Twain = ApplicationParameters["StandardSubsystems.TwainComponent"];
	Twain.MergeIntoMultipageFile(
		AllPathsString, ExecutionParameters.ResultFile, PathToConverterApplication);
	
	ObjectResultFile = New File(ExecutionParameters.ResultFile);
	If NOT ObjectResultFile.Exist() Then
		MessageText = MessageTextOfTransformToPDFError(ExecutionParameters.ResultFile);
		ExecutionParameters.ResultFile        = "";
		Result.ErrorText = MessageText;
		ShowMessageBox(, MessageText);
		AcceptAllAsOneFileCompletion(Result, ExecutionParameters);
		Return;
	EndIf;
	
	If NOT IsBlankString(ExecutionParameters.ResultFile) Then
		
		Handler = New NotifyDescription("AcceptAllAsOneFileCompletion", ThisObject, ExecutionParameters);
		
		AddingOptions = New Structure;
		AddingOptions.Insert("ResultHandler", Handler);
		AddingOptions.Insert("FileOwner", FileOwner);
		AddingOptions.Insert("OwnerForm", ThisObject);
		AddingOptions.Insert("FullFileName", ExecutionParameters.ResultFile);
		AddingOptions.Insert("NameOfFileToCreate", FileName);
		AddingOptions.Insert("DontOpenCardAfterCreateFromFIle", DontOpenCardAfterCreateFromFIle);
		AddingOptions.Insert("FormID", UUID);
		AddingOptions.Insert("UUID", UUID);
		AddingOptions.Insert("IsFile", IsFile);
		
		FilesOperationsInternalClient.AddFormFileSystemWithExtension(AddingOptions);
		
		Return;
	EndIf;
	
	AcceptAllAsOneFileCompletion(Result, ExecutionParameters);
	
EndProcedure

&AtClient
Procedure SaveAllAsSeparateFiles(Command)
	
	FileArrayCopy = New Array;
	For Each Row In FilesTable Do
		FileArrayCopy.Add(New Structure("PathToFile", Row.PathToFile));
	EndDo;
	ScannedFiles = New Array;
	
	FilesTable.Clear(); // Not to delete files in OnClose.
	
	ResultExtension = String(SinglePageStorageFormat);
	ResultExtension = Lower(ResultExtension); 
	
	AddingOptions = New Structure;
	AddingOptions.Insert("FileOwner", FileOwner);
	AddingOptions.Insert("UUID", UUID);
	AddingOptions.Insert("FormID", UUID);
	AddingOptions.Insert("OwnerForm", ThisObject);
	AddingOptions.Insert("DontOpenCardAfterCreateFromFIle", True);
	AddingOptions.Insert("FullFileName", "");
	AddingOptions.Insert("NameOfFileToCreate", "");
	AddingOptions.Insert("IsFile", IsFile);
	
	FullTextOfAllErrors = "";
	ErrorsCount = 0;
	
	// Working with all pictures here. Accepting each as a separate file.
	For Each Row In FileArrayCopy Do
		
		PathToFileLocal = Row.PathToFile;
		
		ResultFile = "";
		If ResultExtension = "pdf" Then
			
#If NOT WebClient AND NOT MobileClient Then
			ResultFile = GetTempFileName("pdf");
#EndIf
			
			AllPathsString = PathToFileLocal;
			Twain = ApplicationParameters["StandardSubsystems.TwainComponent"];
			Twain.MergeIntoMultipageFile(
				AllPathsString, ResultFile, PathToConverterApplication);
			
			ObjectResultFile = New File(ResultFile);
			If NOT ObjectResultFile.Exist() Then
				ErrorText = MessageTextOfTransformToPDFError(ResultFile);
				If FullTextOfAllErrors <> "" Then
					FullTextOfAllErrors = FullTextOfAllErrors + Chars.LF + Chars.LF + "---" + Chars.LF + Chars.LF;
				EndIf;
				FullTextOfAllErrors = FullTextOfAllErrors + ErrorText;
				ErrorsCount = ErrorsCount + 1;
				ResultFile = "";
			EndIf;
			
			PathToFileLocal = ResultFile;
			
		EndIf;
		
		If NOT IsBlankString(PathToFileLocal) Then
			AddingOptions.FullFileName = PathToFileLocal;
			AddingOptions.NameOfFileToCreate = FileName;
			Result = FilesOperationsInternalClient.AddFromFileSystemWithExtensionSynchronous(AddingOptions);
			If Not Result.FileAdded Then
				If ValueIsFilled(Result.ErrorText) Then
					ShowMessageBox(, Result.ErrorText);
					Return;
				EndIf;
			Else
				ScannedFiles.Add(Result);
			EndIf;
		EndIf;
		
		If NOT IsBlankString(ResultFile) Then
			DeleteFiles(ResultFile);
		EndIf;
		
		FileNumber = FileNumber + 1;
		FileName = FilesOperationsInternalClientServer.ScannedFileName(FileNumber, "");
		
	EndDo;
	
	FilesOperationsInternalServerCall.EnterMaxNumberToScan(
		FileOwner, FileNumber - 1);
	
	DeleteTempFiles(FileArrayCopy);
	
	If ErrorsCount > 0 Then
		If ErrorsCount = 1 Then
			WarningText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не удалось сохранить файл по причине:
					|%1'; 
					|en = 'Cannot save the file due to:
					|%1'; 
					|pl = 'Nie udało się zapisać plik z powodu:
					|%1';
					|es_ES = 'No se ha podido guardar el archivo a causa de:
					|%1';
					|es_CO = 'No se ha podido guardar el archivo a causa de:
					|%1';
					|tr = 'Dosya 
					|%1 nedeniyle kaydedilemedi.';
					|it = 'Impossibile salvare il file a causa di:
					|%1';
					|de = 'Die Datei konnte aus diesem Grund nicht gespeichert werden:
					|%1'"),
				FullTextOfAllErrors);
		Else
			WarningText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не удалось сохранить некоторые файлы (%1):
					|%2'; 
					|en = 'Cannot save some files (%1):
					|%2'; 
					|pl = 'Nie udało się zapisać niektóre pliki (%1):
					|%2';
					|es_ES = 'No se ha podido guardar algunos archivos (%1):
					|%2';
					|es_CO = 'No se ha podido guardar algunos archivos (%1):
					|%2';
					|tr = 'Bazı dosyalar (%1) kaydedilemedi: 
					|%2';
					|it = 'Non è stato possibile salvare alcuni file (%1):
					|%2';
					|de = 'Einige Dateien konnten nicht gespeichert werden (%1):
					|%2'"),
				String(ErrorsCount), FullTextOfAllErrors);
		EndIf;
		StandardSubsystemsClient.ShowQuestionToUser(Undefined, WarningText, QuestionDialogMode.OK);
	EndIf;
	
	Close(ScannedFiles);
	
EndProcedure

&AtClient
Procedure Scan(Command)
	
	ShowDialogBox = ShowScannerDialog;
	SelectedDevice = ScannerName;
	PathToConverterApplication = "convert.exe";
	DeflateParameter = ?(Upper(PictureFormat) = "JPG", JPGQuality, TIFFCompressionNumber);
	
	InsertionPosition = Undefined;
	
	Twain = ApplicationParameters["StandardSubsystems.TwainComponent"];
	Twain.BeginScan(
		ShowDialogBox, SelectedDevice, PictureFormat, 
		Permission, Chromaticity, Rotation, PaperSize, 
		DeflateParameter,
		DuplexScanning);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure BeforeOpen()
	
	StandardSubsystemsClient.SetFormStorage(ThisObject, False);
	
	// Initial initialization of the machine (call from OnOpen ()).
	OpeningParameters = New Structure;
	OpeningParameters.Insert("CurrentStep", 1);
	OpeningParameters.Insert("ShowDialogBox", Undefined);
	OpeningParameters.Insert("SelectedDevice", Undefined);
	BeforeOpenMachine(Undefined, OpeningParameters);
EndProcedure

&AtClient
Procedure BeforeOpenMachine(Result, OpeningParameters) Export
	// Secondary initialization of the machine (call from the dialog box opened by the machine).
	If OpeningParameters.CurrentStep = 2 Then
		If TypeOf(Result) = Type("String") AND Not IsBlankString(Result) Then
			OpeningParameters.SelectedDevice = Result;
			ScannerName = OpeningParameters.SelectedDevice;
		EndIf;
		OpeningParameters.CurrentStep = 3;
	EndIf;
	
	If OpeningParameters.CurrentStep = 1 Then
		If Not FilesOperationsInternalClient.InitAddIn() Then
			Return;
		EndIf;
		
		// It is called here, because the call ApplicationParameters["StandardSubsystems.TwainAddIn"].
		// HasDevices() takes a very long time (more, than UpdateCachedValues()).
		If Not FilesOperationsInternalClient.ScanCommandAvailable() Then
			RefreshReusableValues();
			Return;
		EndIf;
		
		OpeningParameters.CurrentStep = 2;
	EndIf;
	
	If OpeningParameters.CurrentStep = 2 Then
		OpeningParameters.ShowDialogBox = ShowScannerDialog;
		OpeningParameters.SelectedDevice = ScannerName;
		
		If OpeningParameters.SelectedDevice = "" Then
			Handler = New NotifyDescription("BeforeOpenMachine", ThisObject, OpeningParameters);
			OpenForm("DataProcessor.Scanning.Form.ScanningDeviceChoice", , ThisObject, , , , Handler, FormWindowOpeningMode.LockWholeInterface);
			Return;
		EndIf;
		
		OpeningParameters.CurrentStep = 3;
	EndIf;
	
	If OpeningParameters.CurrentStep = 3 Then
		If OpeningParameters.SelectedDevice = "" Then 
			Return; // Do not open the form.
		EndIf;
		
		If Permission = -1 OR Chromaticity = -1 OR Rotation = -1 OR PaperSize = -1 Then
			
			Permission = FilesOperationsInternalClient.GetSetting(
				OpeningParameters.SelectedDevice,
				"XRESOLUTION");
			
			Chromaticity = FilesOperationsInternalClient.GetSetting(
				OpeningParameters.SelectedDevice,
				"PIXELTYPE");
			
			Rotation = FilesOperationsInternalClient.GetSetting(
				OpeningParameters.SelectedDevice,
				"ROTATION");
			
			PaperSize = FilesOperationsInternalClient.GetSetting(
				OpeningParameters.SelectedDevice,
				"SUPPORTEDSIZES");
			
			DuplexScanningNumber = FilesOperationsInternalClient.GetSetting(
				OpeningParameters.SelectedDevice,
				"DUPLEX");
			
			RotationAvailable = (Rotation <> -1);
			PaperSizeAvailable = (PaperSize <> -1);
			DuplexScanningAvailable = (DuplexScanningNumber <> -1);
			
			SystemInfo = New SystemInfo();
			ClientID = SystemInfo.ClientID;
			
			SaveScannerParameters(Permission, Chromaticity, ClientID);
		Else
			
			RotationAvailable = Not RotationEnum.IsEmpty();
			PaperSizeAvailable = Not PaperSizeEnum.IsEmpty();
			DuplexScanningAvailable = True;
			
		EndIf;
		
		PictureFileName = "";
		Items.Save.Enabled = False;
		
		DeflateParameter = ?(Upper(PictureFormat) = "JPG", JPGQuality, TIFFCompressionNumber);
		
		If Not IsOpen() Then
			ChecksOnOpenExecuted = True;
			Open();
			ChecksOnOpenExecuted = False;
		EndIf;
		
		Twain = ApplicationParameters["StandardSubsystems.TwainComponent"];
		Twain.BeginScan(
			OpeningParameters.ShowDialogBox,
			OpeningParameters.SelectedDevice,
			PictureFormat,
			Permission,
			Chromaticity,
			Rotation,
			PaperSize,
			DeflateParameter,
			DuplexScanning);
	EndIf;
	
EndProcedure

&AtClient
Procedure AcceptCompletion(Result, ExecutionParameters) Export
	
	DeleteTempFiles(ExecutionParameters.FileArrayCopy);
	If NOT IsBlankString(ExecutionParameters.ResultFile) Then
		DeleteFiles(ExecutionParameters.ResultFile);
	EndIf;
	
	Close(Result);
	
EndProcedure

&AtClient
Procedure AcceptAllAsOneFileCompletion(Result, ExecutionParameters) Export
	DeleteTempFiles(ExecutionParameters.FileArrayCopy);
	DeleteFiles(ExecutionParameters.ResultFile);
	
	Close(Result);
	
EndProcedure

&AtServer
Procedure TransformCalculationsToParametersAndGetPresentation()
		
	Permission = -1;
	If ResolutionEnum = Enums.ScannedImageResolutions.dpi200 Then
		Permission = 200; 
	ElsIf ResolutionEnum = Enums.ScannedImageResolutions.dpi300 Then
		Permission = 300;
	ElsIf ResolutionEnum = Enums.ScannedImageResolutions.dpi600 Then
		Permission = 600;
	ElsIf ResolutionEnum = Enums.ScannedImageResolutions.dpi1200 Then
		Permission = 1200;
	EndIf;
	
	Chromaticity = -1;
	If ColorDepthEnum = Enums.ImageColorDepths.Monochrome Then
		Chromaticity = 0;
	ElsIf ColorDepthEnum = Enums.ImageColorDepths.Grayscale Then
		Chromaticity = 1;
	ElsIf ColorDepthEnum = Enums.ImageColorDepths.Color Then
		Chromaticity = 2;
	EndIf;
	
	Rotation = 0;
	If RotationEnum = Enums.PictureRotationOptions.NoRotation Then
		Rotation = 0;
	ElsIf RotationEnum = Enums.PictureRotationOptions.Right90 Then
		Rotation = 90;
	ElsIf RotationEnum = Enums.PictureRotationOptions.Right180 Then
		Rotation = 180;
	ElsIf RotationEnum = Enums.PictureRotationOptions.Left90 Then
		Rotation = 270;
	EndIf;
	
	PaperSize = 0;
	If PaperSizeEnum = Enums.PaperSizes.NotDefined Then
		PaperSize = 0;
	ElsIf PaperSizeEnum = Enums.PaperSizes.A3 Then
		PaperSize = 11;
	ElsIf PaperSizeEnum = Enums.PaperSizes.A4 Then
		PaperSize = 1;
	ElsIf PaperSizeEnum = Enums.PaperSizes.A5 Then
		PaperSize = 5;
	ElsIf PaperSizeEnum = Enums.PaperSizes.B4 Then
		PaperSize = 6;
	ElsIf PaperSizeEnum = Enums.PaperSizes.B5 Then
		PaperSize = 2;
	ElsIf PaperSizeEnum = Enums.PaperSizes.B6 Then
		PaperSize = 7;
	ElsIf PaperSizeEnum = Enums.PaperSizes.C4 Then
		PaperSize = 14;
	ElsIf PaperSizeEnum = Enums.PaperSizes.C5 Then
		PaperSize = 15;
	ElsIf PaperSizeEnum = Enums.PaperSizes.C6 Then
		PaperSize = 16;
	ElsIf PaperSizeEnum = Enums.PaperSizes.USLetter Then
		PaperSize = 3;
	ElsIf PaperSizeEnum = Enums.PaperSizes.USLegal Then
		PaperSize = 4;
	ElsIf PaperSizeEnum = Enums.PaperSizes.USExecutive Then
		PaperSize = 10;
	EndIf;
	
	TIFFCompressionNumber = 6; // NoCompression
	If TIFFDeflation = Enums.TIFFCompressionTypes.LZW Then
		TIFFCompressionNumber = 2;
	ElsIf TIFFDeflation = Enums.TIFFCompressionTypes.RLE Then
		TIFFCompressionNumber = 5;
	ElsIf TIFFDeflation = Enums.TIFFCompressionTypes.NoCompression Then
		TIFFCompressionNumber = 6;
	ElsIf TIFFDeflation = Enums.TIFFCompressionTypes.CCITT3 Then
		TIFFCompressionNumber = 3;
	ElsIf TIFFDeflation = Enums.TIFFCompressionTypes.CCITT4 Then
		TIFFCompressionNumber = 4;
		
	EndIf;
	
	Presentation = "";
	// Informational inscription of the kind:
	// "Storage format: PDF. Scanning format: JPG. Quality: 75. Multi-page storage format: PDF. Permission:
	// 200. Colored";
	
	If UseImageMagickToConvertToPDF Then
		If SinglePageStorageFormat = Enums.SinglePageFileStorageFormats.PDF Then
			PictureFormat = String(ScannedImageFormat);
			
			Presentation = Presentation + NStr("ru = 'Формат хранения:'; en = 'Storage format:'; pl = 'Format przechowywania:';es_ES = 'Formato de almacenamiento:';es_CO = 'Formato de almacenamiento:';tr = 'Depolama biçimi:';it = 'Gormato di archiviazione:';de = 'Speicherformat:'") + " ";
			Presentation = Presentation + "PDF";
			Presentation = Presentation + ". ";
			Presentation = Presentation + NStr("ru = 'Формат сканирования:'; en = 'Scanning format:'; pl = 'Format skanowania:';es_ES = 'Formato de escaneo:';es_CO = 'Formato de escaneo:';tr = 'Tarama biçimi:';it = 'Formato di scansione:';de = 'Scan-Format:'") + " ";
			Presentation = Presentation + PictureFormat;
			Presentation = Presentation + ". ";
		Else	
			PictureFormat = String(SinglePageStorageFormat);
			Presentation = Presentation + NStr("ru = 'Формат хранения:'; en = 'Storage format:'; pl = 'Format przechowywania:';es_ES = 'Formato de almacenamiento:';es_CO = 'Formato de almacenamiento:';tr = 'Depolama biçimi:';it = 'Gormato di archiviazione:';de = 'Speicherformat:'") + " ";
			Presentation = Presentation + PictureFormat;
			Presentation = Presentation + ". ";
		EndIf;
	Else	
		PictureFormat = String(ScannedImageFormat);
		Presentation = Presentation + NStr("ru = 'Формат хранения:'; en = 'Storage format:'; pl = 'Format przechowywania:';es_ES = 'Formato de almacenamiento:';es_CO = 'Formato de almacenamiento:';tr = 'Depolama biçimi:';it = 'Gormato di archiviazione:';de = 'Speicherformat:'") + " ";
		Presentation = Presentation + PictureFormat;
		Presentation = Presentation + ". ";
	EndIf;

	If Upper(PictureFormat) = "JPG" Then
		Presentation = Presentation +  NStr("ru = 'Качество:'; en = 'Quality:'; pl = 'Jakość:';es_ES = 'Calidad:';es_CO = 'Calidad:';tr = 'Kalite:';it = 'Qualità:';de = 'Qualität:'") + " " + String(JPGQuality) + ". ";
	EndIf;	
	
	If Upper(PictureFormat) = "TIF" Then
		Presentation = Presentation +  NStr("ru = 'Сжатие:'; en = 'Deflation:'; pl = 'Kompresja:';es_ES = 'Compresión:';es_CO = 'Compresión:';tr = 'Sıkıştırma:';it = 'Deflazione';de = 'Komprimierung:'") + " " + String(TIFFDeflation) + ". ";
	EndIf;
	
	Presentation = Presentation + NStr("ru = 'Формат хранения многостраничный:'; en = 'Multi-page storage format:'; pl = 'Wielostronicowy format przechowywania:';es_ES = 'Formato de almacenamiento de páginas múltiples:';es_CO = 'Formato de almacenamiento de páginas múltiples:';tr = 'Çok sayfalı depolama biçimi:';it = 'Multi-pagina formato di archiviazione:';de = 'Mehrseitiges Speicherformat:'") + " ";
	Presentation = Presentation + String(MultipageStorageFormat);
	Presentation = Presentation + ". ";
	
	Presentation = Presentation + StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Разрешение: %1 dpi. %2.'; en = 'Resolution: %1 dpi. %2.'; pl = 'Rozdzielczość: %1 dpi. %2.';es_ES = 'Resolución: %1 dpi. %2.';es_CO = 'Resolución: %1 dpi. %2.';tr = 'Çözünürlük: %1 dpi. %2.';it = 'Risoluzione: %1 dpi. %2.';de = 'Auflösung: %1 dpi. %2.'") + " ",
		String(Permission), String(ColorDepthEnum));
	
	If NOT RotationEnum.IsEmpty() Then
		Presentation = Presentation +  NStr("ru = 'Поворот:'; en = 'Rotation:'; pl = 'Obrót:';es_ES = 'Rotación:';es_CO = 'Rotación:';tr = 'Dönme';it = 'Rotazione:';de = 'Rotation:'")+ " " + String(RotationEnum) + ". ";
	EndIf;	
	
	If NOT PaperSizeEnum.IsEmpty() Then
		Presentation = Presentation +  NStr("ru = 'Размер бумаги:'; en = 'Paper size:'; pl = 'Rozmiar papieru:';es_ES = 'Tamaño de papel:';es_CO = 'Tamaño de papel:';tr = 'Kağıt boyutu:';it = 'Formato carta:';de = 'Papiergröße:'") + " " + String(PaperSizeEnum) + ". ";
	EndIf;	
	
	If DuplexScanning = True Then
		Presentation = Presentation +  NStr("ru = 'Двустороннее сканирование'; en = 'Scan both sides'; pl = 'Skanowanie dwustronne';es_ES = 'Escanear a doble cara';es_CO = 'Escanear a doble cara';tr = 'Çift taraflı tarama';it = 'Acquisire entrambi i lati';de = 'Beide Seiten scannen'") + ". ";
	EndIf;	
	
	SettingsText = Presentation;
	
	Items.SettingsTextChange.Title = SettingsText + "Change";
	
EndProcedure

&AtClient
Procedure ExternalEvent(Source, Event, Data)
	
#If NOT WebClient AND NOT MobileClient Then
		
	If Source = "TWAIN" AND Event = "ImageAcquired" Then
		
		PictureFileName = Data;
		Items.Save.Enabled = True;
		
		RowsNumberBeforeAdd = FilesTable.Count();
		
		TableRow = Undefined;
		
		If InsertionPosition = Undefined Then
			TableRow = FilesTable.Add();
		Else
			TableRow = FilesTable.Insert(InsertionPosition);
			InsertionPosition = InsertionPosition + 1;
		EndIf;
		
		TableRow.PathToFile = PictureFileName;
		
		If GrowingImageNumber = Undefined Then
			GrowingImageNumber = 1;
		EndIf;
			
		TableRow.Presentation = "Picture" + String(GrowingImageNumber);
		GrowingImageNumber = GrowingImageNumber + 1;
		
		If RowsNumberBeforeAdd = 0 Then
			PathToSelectedFile = TableRow.PathToFile;
			BinaryData = New BinaryData(PathToSelectedFile);
			PictureAddress = PutToTempStorage(BinaryData, UUID);
			TableRow.PictureAddress = PictureAddress;
		EndIf;
		
		If OneFileOnly Then
			Items.FormScanAgain.Visible = (FilesTable.Count() = 0);
		ElsIf FilesTable.Count() > 1 AND Items.FilesTable.Visible = False Then
			Items.FilesTable.Visible = True;
			Items.FormAcceptAllAsSingleFile.Visible = True;
			Items.FormAcceptAllAsSingleFile.DefaultButton = True;
			Items.FormAcceptAllAsSeparateFiles.Visible = True;
			Items.Save.Visible = False;
		EndIf;
		
		If FilesTable.Count() > 1 Then
			Items.FilesTableContextMenuDelete.Enabled = True;
		EndIf;
		
	ElsIf Source = "TWAIN" AND Event = "EndBatch" Then
		
		If FilesTable.Count() <> 0 Then
			RowID = FilesTable[FilesTable.Count() - 1].GetID();
			Items.FilesTable.CurrentRow = RowID;
		EndIf;
		
	ElsIf Source = "TWAIN" AND Event = "UserPressedCancel" Then	
		If ThisObject.IsOpen() Then
			Close();
		EndIf;
	EndIf;
	
#EndIf

EndProcedure

&AtClient
Procedure DeleteTempFiles(FilesValueTable)
	
	For Each Row In FilesValueTable Do
		DeleteFiles(Row.PathToFile);
	EndDo;
	
	FilesValueTable.Clear();
	InsertionPosition = Undefined;
	
EndProcedure

&AtClient
Function MessageTextOfTransformToPDFError(ResultFile)
	
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Не найден файл ""%1"".
		           |Проверьте, что установлена программа ImageMagick и
		           |указан правильный путь к программе преобразования в
		           |PDF в форме настроек сканирования.'; 
		           |en = 'File ""%1"" is not found.
		           |Check that the ImageMagick application is installed, and
		           |the correct path to
		           |the PDF conversion application is specified in the form of scan settings.'; 
		           |pl = 'Nie znaleziono pliku ""%1"".
		           |Sprawdź, aby był zainstalowany program ImageMagick i 
		           |podano prawidłową ścieżkę do programu konwersji do 
		           |PDF w formie ustawień skanowania.';
		           |es_ES = 'No se ha encontrado archivo ""%1"".
		           |Compruebe que el programa ImageMagick esté instalado y
		           |esté indicada una ruta correcta al programa de exportación en
		           |PDF en el formulario de ajustes de escaneo.';
		           |es_CO = 'No se ha encontrado archivo ""%1"".
		           |Compruebe que el programa ImageMagick esté instalado y
		           |esté indicada una ruta correcta al programa de exportación en
		           |PDF en el formulario de ajustes de escaneo.';
		           |tr = '""%1"" Dosyası bulunamadı. ImageMagick uygulamasının yüklü olup olmadığını ve 
		           |PDF dönüştürme uygulamasına doğru bir yolun tarama ayarları
		           |formunda belirtilip belirtilmediğini kontrol edin.
		           |';
		           |it = 'File ""%1"" non trovato.
		           |Verificare che l''applicazione ImageMagick sia installata e
		           |che il percorso corretto
		           |all''applicazione di conversione PDF sia stato indicato nel modulo di impostazioni di scansione.';
		           |de = 'Die Datei ""%1"" wurde nicht gefunden.
		           |Stellen Sie sicher, dass ImageMagick installiert ist und
		           |der richtige Pfad zum
		           |PDF-Konvertierungsprogramm in Form von Scaneinstellungen angegeben ist.'"),
		ResultFile);
		
	Return MessageText;
	
EndFunction

&AtServerNoContext
Procedure SaveScannerParameters(PermissionNumber, ChromaticityNumber, ClientID) 
	
	Result = FilesOperationsInternal.ScannerParametersInEnumerations(PermissionNumber, ChromaticityNumber, 0, 0);
	Common.CommonSettingsStorageSave("ScanningSettings/Permission", ClientID, Result.Permission);
	Common.CommonSettingsStorageSave("ScanningSettings/Chromaticity", ClientID, Result.Chromaticity);
	
EndProcedure

&AtClient
Function ScanningResult()
	
	Var Result;
	
	Result = New Structure();
	Result.Insert("ErrorText", "");
	Result.Insert("FileAdded", False);
	Result.Insert("FileRef");
	Return Result;

EndFunction

#EndRegion
