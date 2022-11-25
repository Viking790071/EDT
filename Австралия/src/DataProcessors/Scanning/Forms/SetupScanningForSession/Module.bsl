
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Permission = Parameters.Permission;
	Chromaticity = Parameters.Chromaticity;
	Rotation = Parameters.Rotation;
	PaperSize = Parameters.PaperSize;
	DuplexScanning = Parameters.DuplexScanning;
	UseImageMagickToConvertToPDF = Parameters.UseImageMagickToConvertToPDF;
	ShowScannerDialog = Parameters.ShowScannerDialog;
	ScannedImageFormat = Parameters.ScannedImageFormat;
	JPGQuality = Parameters.JPGQuality;
	TIFFDeflation = Parameters.TIFFDeflation;
	SinglePageStorageFormat = Parameters.SinglePageStorageFormat;
	MultipageStorageFormat = Parameters.MultipageStorageFormat;
	
	Items.Rotation.Visible = Parameters.RotationAvailable;
	Items.PaperSize.Visible = Parameters.PaperSizeAvailable;
	Items.DuplexScanning.Visible = Parameters.DuplexScanningAvailable;
	
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
	
	Items.MultipageStorageFormat.Enabled = UseImageMagickToConvertToPDF;
	SinglePageStorageFormatPrevious = SinglePageStorageFormat;
	
	If NOT UseImageMagickToConvertToPDF Then
		Items.ScannedImageFormat.Title = NStr("ru = 'Формат'; en = 'Format'; pl = 'Format';es_ES = 'Formato';es_CO = 'Formato';tr = 'Format';it = 'Formato';de = 'Format'");
	Else
		Items.ScannedImageFormat.Title = NStr("ru = 'Тип'; en = 'Type'; pl = 'Typ';es_ES = 'Tipo';es_CO = 'Tipo';tr = 'Tür';it = 'Tipo';de = 'Typ'");
	EndIf;
	
	StandardSubsystemsServer.SetGroupTitleRepresentation(ThisObject,
		"SinglePageStorageFormatGroup,MultiPageStorageFormatGroup,MainGroup");
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

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
Procedure SinglePageStorageFormatOnChange(Item)
	
	ProcessChangesSinglePageStorageFormat();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	ClearMessages();
	If Not CheckFilling() Then 
		Return;
	EndIf;
	
	SelectionResult = New Structure;
	SelectionResult.Insert("ShowScannerDialog",  ShowScannerDialog);
	SelectionResult.Insert("Permission",               Permission);
	SelectionResult.Insert("Chromaticity",                Chromaticity);
	SelectionResult.Insert("Rotation",                  Rotation);
	SelectionResult.Insert("PaperSize",             PaperSize);
	SelectionResult.Insert("DuplexScanning", DuplexScanning);
	
	SelectionResult.Insert("UseImageMagickToConvertToPDF",
		UseImageMagickToConvertToPDF);
	
	SelectionResult.Insert("ScannedImageFormat", ScannedImageFormat);
	SelectionResult.Insert("JPGQuality",                     JPGQuality);
	SelectionResult.Insert("TIFFDeflation",                      TIFFDeflation);
	SelectionResult.Insert("SinglePageStorageFormat",    SinglePageStorageFormat);
	SelectionResult.Insert("MultipageStorageFormat",   MultipageStorageFormat);
	
	NotifyChoice(SelectionResult);
	
EndProcedure

#EndRegion

#Region Private

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
