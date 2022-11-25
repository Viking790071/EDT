
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("OpenMainWorkingPriceList") Then
		
		PriceList = DriveReUse.GetValueOfSetting("MainWorkingPriceList");
		
	Else
		
		Parameters.Property("PriceList", PriceList);
		
	EndIf;
	
	CacheValues = New Structure;
	CacheValues.Insert("MaxAcceptablePictureSizeMb", 				500);
	CacheValues.Insert("ThisIsProgrammaticallySaveBigPriceList",	False);
	CacheValues.Insert("MeasurementID",								Undefined);
	CacheValues.Insert("LongActionParameters",						New Structure);
	CacheValues.LongActionParameters.Insert("FormationResult",		Undefined);
	CacheValues.LongActionParameters.Insert("JobID",				"");
	CacheValues.LongActionParameters.Insert("SaveToFile",			False);
	
	UpdateAddCashValues();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ValueIsFilled(PriceList) Then
		
		PriceListGenerateAtClient();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("CommonForm.SavePrintForm") Then
		
		If SelectedValue <> Undefined AND SelectedValue <> DialogReturnCode.Cancel Then
			
			FileInTempStorage = MoveTableDocumentsToTempStorage(SelectedValue);
			
			If SelectedValue.SavingOption = "SaveToFolder" Then
				
				SavePrintingFormToFolder(FileInTempStorage, SelectedValue.FolderForSaving);
				
			ElsIf SelectedValue.SavingOption = "Join" Then
				
				SavedObjects = AttachPrintingFormsToObject(FileInTempStorage, SelectedValue.ObjectForAttaching);
				
				If SavedObjects.Count() > 0 Then
					
					NotifyChanged(TypeOf(SavedObjects[0]));
					
				EndIf;
				
				ShowUserNotification(, , NStr("en = 'Saved'; ru = 'Запись выполнена';pl = 'Zapisano';es_ES = 'Se ha guardado';es_CO = 'Se ha guardado';tr = 'Kaydedildi';it = 'Salvato';de = 'Gespeichert'"), PictureLib.Information32);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure TableDocumentDetailProcessing(Item, Details, StandardProcessing, AdditionalParameters)
	
	If TypeOf(Details) = Type("Structure") Then
		
		If Details.Property("ThisIsCharacteristic") Then
			
			StandardProcessing = False;
			OpenForm("Catalog.ProductsCharacteristics.ObjectForm", New Structure("Key", Details.Characteristic), ThisObject);
			
		Else
			
			StandardProcessing = False;
			ProcessCellDetails(Details);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PriceListOnChange(Item)
	
	UpdateAddCashValues();
	
EndProcedure

&AtClient
Procedure SearchStringOnChange(Item)
	
	If IsBlankString(SearchString) Then
		
		Return;
		
	EndIf;
	
	SearchRowInTable(True);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Generate(Command)
	
	PriceListGenerateAtClient();
	
EndProcedure

&AtClient
Procedure Save(Command)
	
	SavePrintingForms(False);
	
EndProcedure

&AtClient
Procedure Send(Command)
	
	SentPrintingFormsByEmail();
	
EndProcedure

&AtClient
Procedure Add(Command)
	
	ProcessContextMenuCommand("Add");
	
EndProcedure

&AtClient
Procedure Change(Command)
	
	ProcessContextMenuCommand("Change");
	
EndProcedure

&AtClient
Procedure SearchBack(Command)
	
	SearchRowInTable(False);
	
EndProcedure

&AtClient
Procedure SearchForward(Command)
	
	SearchRowInTable(True);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SearchRowInTable(SearchForward)
	
	If IsBlankString(SearchString) Then
		
		ShowMessageBox(, NStr("en = 'No matches found'; ru = 'Соответствий не найдено';pl = 'Nie znaleziono dopasowań';es_ES = 'No se han encontrado coincidencias';es_CO = 'No se han encontrado coincidencias';tr = 'Eşleşme bulunamadı';it = 'Non sono state trovate corrispondenze';de = 'Kein Treffer gefunden'"));
		CurrentItem = Items.SearchString;
		
		Return;
		
	EndIf;
	
	FoundArea = TableDocument.FindText(TrimAll(SearchString), Items.TableDocument.CurrentArea, , , , SearchForward, True);
	If FoundArea = Undefined Then
		
		FoundArea = TableDocument.FindText(TrimAll(SearchString), , , , , , True);
		If FoundArea = Undefined Then
			
			TextMessage = NStr("en = 'No matches found.'; ru = 'Соответствий не найдено.';pl = 'Nie znaleziono dopasowań.';es_ES = 'No se han encontrado coincidencias.';es_CO = 'No se han encontrado coincidencias.';tr = 'Eşleşme bulunamadı.';it = 'Non sono state trovate corrispondenze.';de = 'Kein Treffer gefunden.'");
			CommonClientServer.MessageToUser(TextMessage, , "SearchString");
			CurrentItem = Items.SearchString;
			
			Return;
			
		EndIf;
		
	EndIf;
	
	CurrentItem = Items.TableDocument;
	
	ArrayAreas = New Array;
	ArrayAreas.Add(FoundArea);
	Items.TableDocument.SetSelectedAreas(ArrayAreas);
	
EndProcedure

&AtServerNoContext
Function ExistRecordAboutPrice(Val DetailsData, CacheValues)
	
	RecordKey = New Structure("Period, PriceType, Products, Characteristic");
	
	If TypeOf(DetailsData) <> Type("Structure") Then
		
		DetailsData = New Structure;
		
	EndIf;
	
	If NOT DetailsData.Property("Period", RecordKey.Period) Then
		
		RecordKey.Period = ?(ValueIsFilled(CacheValues.PricePeriod), CacheValues.PricePeriod, CurrentSessionDate());
		
	EndIf;
	
	If NOT DetailsData.Property("PriceType", RecordKey.PriceType) Then
		
		RecordKey.PriceType = CacheValues.PriceType;
		
	EndIf;
	
	If NOT DetailsData.Property("Products", RecordKey.Products) Then
		
		RecordKey.Products = Catalogs.Products.EmptyRef();
		
	EndIf;
	
	If NOT DetailsData.Property("Characteristic", RecordKey.Characteristic) Тогда
		
		RecordKey.Characteristic =  Catalogs.ProductsCharacteristics.EmptyRef();
		
	EndIf;
	
	Return PriceGenerationServer.ExistRecordAboutPrice(RecordKey);
	
EndFunction

&AtClient
// Procedure opens the recording of the register.
//
Procedure OpenRegisterRecordForm(DetailsData)
	
	RecordKey = ExistRecordAboutPrice(DetailsData, CacheValues);
	
	If RecordKey.ExistRecord Then
		
		RecordKey.Delete("ExistRecord");
		
		OpenForm("Document.Pricing.ObjectForm", New Structure("Key", RecordKey.Recorder), ThisObject);
		
	Else
		
		FillingValues = New Structure;
		If ValueIsFilled(CacheValues.PricePeriod) Then
			
			FillingValues.Insert("Date", CacheValues.PricePeriod);
			
		EndIf;
		
		If ValueIsFilled(CacheValues.PriceType) Then
			
			FillingValues.Insert("PriceKind", CacheValues.PriceType);
			
		EndIf;
		
		OpenParameters = New Structure;
		OpenParameters.Insert("FillingValues", FillingValues);
		
		OpenForm("Document.Pricing.ObjectForm", OpenParameters, ThisObject);
		
	EndIf; 
	
EndProcedure

&AtClient
Procedure ProcessCellDetails(DetailsData)
	
	If DetailsData.Property("PriceType") AND DetailsData.Property("Products") Then
		
		OpenRegisterRecordForm(DetailsData);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AddNewRecordAboutPrice(DetailsData)
	
	OpenRegisterRecordForm(DetailsData);
	
EndProcedure

&AtClient
Procedure ChangeRecordAboutPrice(DetailsData)
	
	OpenRegisterRecordForm(DetailsData);
	
EndProcedure

&AtServer
Function GenerateWritingFileName()
	
	WorkingDate = StrReplace(Format(CurrentSessionDate(), "DLF=DT"), ":", "");
	WorkingDate = StrReplace(WorkingDate, ".", "");
	WorkingDate = StrReplace(WorkingDate, " ", "_");
	
	Return CommonClientServer.ReplaceProhibitedCharsInFileName(PriceList.Description + WorkingDate);
	
EndFunction

&AtClient
Procedure SavePrintingForms(ThisIsProgrammaticallySaveBigPriceList)
	
	CacheValues.ThisIsProgrammaticallySaveBigPriceList = ThisIsProgrammaticallySaveBigPriceList;
	
	PrintingObjects = New ValueList;
	PrintingObjects.Add(PriceList);
	
	SaveParameters = New Structure;
	SaveParameters.Insert("PrintingObjects", PrintingObjects);
	
	OpenForm("CommonForm.SavePrintForm", SaveParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure SentPrintingFormsByEmail()
	
	NotifyDescription = New NotifyDescription("SentPrintingFormsByEmailContinue", ThisObject);
	EmailOperationsClient.CheckAccountForSendingEmailExists(NotifyDescription);
	
EndProcedure

&AtClient
Procedure SentPrintingFormsByEmailContinue(Result, AdditionalParameters) Export
	
	If NOT Result Then
		
		Return;
		
	EndIf;
	
	PriceListName = GenerateWritingFileName();
	
	Attachment = New Structure;
	Attachment.Insert("AddressInTempStorage", PutToTempStorage(TableDocument, UUID));
	Attachment.Insert("Presentation", PriceListName);
	
	SendParameters = EmailOperationsClient.EmailSendOptions();
	SendParameters.Subject = NStr("en = 'Price list'; ru = 'Прайс-лист';pl = 'Cennik';es_ES = 'Lista de precios';es_CO = 'Lista de precios';tr = 'Fiyat listesi';it = 'Listino prezzi';de = 'Preisliste'") + " " + ?(ValueIsFilled(CacheValues.Company), CacheValues.CompanyDescription, "");
	SendParameters.Attachments = CommonClientServer.ValueInArray(Attachment);
	EmailOperationsClient.CreateNewEmailMessage(SendParameters);
	
EndProcedure

&AtServer
Function MoveTableDocumentsToTempStorage(SaveSettings)
	
	Var ZipFileWriter, ArchiveName;
	
	Result			= New Array;
	UsedFileNames	= New Map;
	
	PriceListName = GenerateWritingFileName(); 
	
	// archive preparation
	If SaveSettings.PackToArchive Then
		
		ArchiveName = GetTempFileName();
		ZipFileWriter = New ZipFileWriter(ArchiveName);
		
	EndIf;
	
	// preparing a temporary folder
	TempFolderName = GetTempFileName();
	CreateDirectory(TempFolderName);
	
	SelectedSaveFormats = SaveSettings.SaveFormats;
	TranslateNamesFiles = False;
	TableFormats = PrintManagement.SpreadsheetDocumentSaveFormatsSettings();
	
	// Print form saving
	If CacheValues.ThisIsProgrammaticallySaveBigPriceList Then
		
		ExecuteResult = GetFromTempStorage(CacheValues.LongOperationParameters.FormationResult.ResultAddress);
		PrintForm = ExecuteResult.SpreadsheetDocument;
		
		DeleteFromTempStorage(CacheValues.LongOperationParameters.FormationResult.ResultAddress);
		
	Else
		
		PrintForm = TableDocument;
		
	EndIf;
	
	If PrintForm.Protection Then
		Return Result;
	EndIf;
	
	If PrintForm.TableHeight = 0 Then
		Return Result;
	EndIf;
	
	If TranslateNamesFiles Then
		
		PriceListName = StringFunctionsClientServer.LatinString(PriceListName);
		
	EndIf;
	
	For Each FileType In SelectedSaveFormats Do
		
		If TypeOf(FileType) = Type("String") Then
			
			FileType = SpreadsheetDocumentFileType[FileType];
			
		EndIf;
		
		FormatSettings = TableFormats.FindRows(New Structure("SpreadsheetDocumentFileType", FileType))[0];
		
		FileName = PriceListName + "." + FormatSettings.Extension;
		FullFileName = GetUniqueFileName(CommonClientServer.AddLastPathSeparator(TempFolderName) + FileName);
		PrintForm.Write(FullFileName, FileType);
		
		If FileType = SpreadsheetDocumentFileType.HTML Then
			InsertPictiresInHTML(FullFileName);
		EndIf;
		
		If ZipFileWriter <> Undefined Then
			
			ZipFileWriter.Add(FullFileName);
			
		Else
			
			BinaryData = New BinaryData(FullFileName);
			AddressInTempStorage = PutToTempStorage(BinaryData, ThisObject.UUID);
			
			FileDescription = New Structure;
			FileDescription.Insert("Presentation",			PriceListName);
			FileDescription.Insert("NameWithoutExt",		PriceListName);
			FileDescription.Insert("ExtWithoutPoint",		FormatSettings.Extension);
			FileDescription.Insert("AddressInTempStorage",	AddressInTempStorage);
			
			If FileType = SpreadsheetDocumentFileType.ANSITXT Then
				FileDescription.Insert("Encoding", "windows-1251");
			EndIf;
			
			Result.Add(FileDescription);
			
		EndIf;
		
	EndDo;
	
	// if the archive is prepared, we write it down and put it in temporary storage
	If ZipFileWriter <> Undefined Then
		
		ZipFileWriter.Write();
		
		ArchiveFile = New File(ArchiveName);
		BinaryData = New BinaryData(ArchiveName);
		AddressInTempStorage = PutToTempStorage(BinaryData, ThisObject.UUID);
		
		FileDescription = New Structure;
		FileDescription.Insert("Presentation",			PriceListName);
		FileDescription.Insert("NameWithoutExt",		PriceListName);
		FileDescription.Insert("ExtWithoutPoint",		"zip");
		FileDescription.Insert("AddressInTempStorage",	AddressInTempStorage);
		
		Result.Add(FileDescription);
		
		DeleteFiles(ArchiveName);
		
	EndIf;
	
	DeleteFiles(TempFolderName);
	
	Return Result;
	
EndFunction

&AtServer
Procedure InsertPictiresInHTML(FileNameHTML)
	
	TextDocument = New TextDocument();
	TextDocument.Read(FileNameHTML, TextEncoding.UTF8);
	TextHTML = TextDocument.GetText();
	
	FileHTML = New File(FileNameHTML);
	
	PicturesFolderName = FileHTML.BaseName + "_files";
	PathToPicturesFolder = StrReplace(FileHTML.FullName, FileHTML.Name, PicturesFolderName);
	
	// it is expected that the folder will be only pictures
	PictureFiles = FindFiles(PathToPicturesFolder, "*");
	
	For Each PictureFile In PictureFiles Do
		
		PictureAsText = Base64String(New BinaryData(PictureFile.FullName));
		PictureAsText = "data:image/" + Mid(PictureFile.Extention, 2) + ";base64," + Chars.LF + PictureAsText;
		
		TextHTML = StrReplace(TextHTML, PicturesFolderName + "\" + PictureFile.Name, PictureAsText);
		
	EndDo;
	
	TextDocument.SetText(TextHTML);
	TextDocument.Write(FileNameHTML, TextEncoding.UTF8);
	
EndProcedure

&AtClient
Procedure SavePrintingFormToFolder(FilesListInTempStorage, Val Folder = "")
	
	#If WebClient Or MobileClient Then
		For Each FileForSave In FilesListInTempStorage Do
			GetFile(FileForSave.AddressInTempStorage, FileForSave.NameWithoutExt + "." + FileForSave.ExtWithoutPoint);
		EndDo;
		
		Return;
	#EndIf
	
	Folder = CommonClientServer.AddLastPathSeparator(Folder);
	
	For Each FileForSave In FilesListInTempStorage Do
		BinaryData = GetFromTempStorage(FileForSave.AddressInTempStorage);
		BinaryData.Write(GetUniqueFileName(Folder + FileForSave.NameWithoutExt + "." + FileForSave.ExtWithoutPoint));
	EndDo;
	
	Status(NStr("en = 'Saved'; ru = 'Запись выполнена';pl = 'Zapisano';es_ES = 'Se ha guardado';es_CO = 'Se ha guardado';tr = 'Kaydedildi';it = 'Salvato';de = 'Gespeichert'"), , NStr("en = 'to folder:'; ru = 'в папку:';pl = 'do folderu:';es_ES = 'a la carpeta:';es_CO = 'a la carpeta:';tr = 'klasöre:';it = 'nella cartella:';de = 'zum Ordner:'") + " " + Folder);
	
EndProcedure

&AtServer
Function AttachPrintingFormsToObject(FilesInTempStorage, ObjectForAttach)
	
	Result = New Array;
	
	If Common.SubsystemExists("StandardSubsystems.FileOperations") Then
		
		For Each File In FilesInTempStorage Do
			
			FileParameters = New Structure;
			FileParameters.Insert("FilesOwner",					ObjectForAttach);
			FileParameters.Insert("BaseName",					File.NameWithoutExt);
			FileParameters.Insert("ExtensionWithoutPoint",		File.ExtWithoutPoint);
			FileParameters.Insert("Author",						Users.CurrentUser());
			FileParameters.Insert("ModificationTimeUniversal",	CurrentUniversalDate());
			
			AttachedFile = FilesOperations.AppendFile(FileParameters, File.AddressInTempStorage);
			
			Result.Add(AttachedFile);
			
		EndDo;
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function GetUniqueFileName(FileName)
	
	File = New File(FileName);
	
	NameWithoutExt	= File.BaseName;
	Ext				= File.Extension;
	Folder			= File.Path;
	
	Counter = 1;
	While File.Exist() Do
		Counter = Counter + 1;
		File = New File(Folder + NameWithoutExt + " (" + Counter + ")" + Ext);
	EndDo;
	
	Return File.FullName;
	
EndFunction

&AtServer
Procedure UpdateAddCashValues()
	
	CacheValues.Insert("Company",				PriceList.Company);
	CacheValues.Insert("CompanyDescription",	String(PriceList.Company));
	CacheValues.Insert("DisplayFormationDate",	PriceList.DisplayFormationDate);
	CacheValues.Insert("FormationDate",			PriceList.FormationDate);
	CacheValues.Insert("PricePeriod",			PriceList.PricePeriod);
	
	PriceType = ?(PriceList.PriceTypes.Count() > 0, PriceList.PriceTypes[0].PriceType, Catalogs.PriceTypes.Wholesale);
	CacheValues.Insert("PriceType", PriceType);
	
EndProcedure

&AtClient
Procedure ProcessContextMenuCommand(CommandName)
	
	SelectedAreas = Items.TableDocument.GetSelectedAreas();
	
	If SelectedAreas.Count() > 0 Then
		
		DetailsData = SelectedAreas[0].Details;
		
		If CommandName = "Add" Then
			
			AddNewRecordAboutPrice(DetailsData);
			
		EndIf;
		
		If CommandName = "Change" AND TypeOf(DetailsData) = Type("Structure") Then
			
			ChangeRecordAboutPrice(DetailsData); // Behavior is different from selecting a cell in 2 clicks
			
		EndIf;
		
	EndIf;
	
EndProcedure

#Region TimeConsumingOperations

&AtClient
Procedure PriceListGenerateAtClient()
	
	PriceListGenerateAtServer();
	PriceListAfterGenerate();
	
EndProcedure

&AtClient
Procedure PriceListAfterGenerate()
	
	If CacheValues.LongActionParameters.FormationResult = Undefined Then 
		
		Return;
		
	EndIf;
	
	If CacheValues.LongActionParameters.FormationResult.Status <> "Running" Then 
		
		ProcessResultBackgroundJob(CacheValues.LongActionParameters.FormationResult, Undefined);
		
		Return;
		
	EndIf;
	
	NotifyDescription = New NotifyDescription("ProcessResultBackgroundJob", ThisObject, Undefined);
	
	WaitingParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	WaitingParameters.MessageText = NStr("en = 'Generating.'; ru = 'Создание.';pl = 'Wygenerowanie.';es_ES = 'Generación.';es_CO = 'Generación.';tr = 'Oluşturuluyor.';it = 'Generazione.';de = 'Generieren.'");
	
	TimeConsumingOperationsClient.WaitForCompletion(CacheValues.LongActionParameters.FormationResult,
		NotifyDescription,
		WaitingParameters);
	
EndProcedure

&AtClient
Процедура ProcessResultBackgroundJob(FormationResult, AdditionalParameters) Export
	
	If FormationResult = Undefined Then
		Return;
	ElsIf TypeOf(FormationResult) = Type("DialogReturnCode") Then
		Return;
	EndIf;
	
	CacheValues.LongActionParameters.FormationResult = FormationResult;
	
	Title = NStr("en = 'Generate price list'; ru = 'Сформировать прайс-лист';pl = 'Utwórz cennik';es_ES = 'Generar la lista de precios';es_CO = 'Generar la lista de precios';tr = 'Fiyat listesi oluştur';it = 'Generare listino prezzi';de = 'Preisliste generieren'");
	
	If CacheValues.LongActionParameters.FormationResult.Status = "Completed" Then 
		
		ResultLongActionToFormTableDocument();
		
		If CacheValues.LongActionParameters.SaveToFile Then
			
			DisplayStatusTablDocument(1);
			
			NotifyDescription = New NotifyDescription("AfterCloseMessagesAboutPriceListSize", ThisObject);
			OpenForm("DataProcessor.GenerationPriceLists.Form.FormMessageBox", Undefined, ThisObject, , , , NotifyDescription);
			
		Else
			
			DisplayStatusTablDocument(2);
			ShowUserNotification(NStr("en = 'Price list is generated.'; ru = 'Прайс-лист создан.';pl = 'Trwa wygenerowanie cennika.';es_ES = 'La lista de precios ha sido generada.';es_CO = 'La lista de precios ha sido generada.';tr = 'Fiyat listesi oluşturuldu.';it = 'Il listino prezzi è stato generato.';de = 'Die Preisliste ist generiert.'"), , Title);
			
		EndIf;
		
	ElsIf CacheValues.LongActionParameters.FormationResult.Status = "Error" Then
		
		DisplayStatusTablDocument(0);
		ShowUserNotification(CacheValues.LongActionParameters.FormationResult.DetailedErrorPresentation, , Title);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DisplayStatusTablDocument(Status)
	
	StatePresentation = Items.TableDocument.StatePresentation;
	
	If Status = 0 Then
		
		StatePresentation.Visible = True;
		StatePresentation.AdditionalShowMode	= AdditionalShowMode.DontUse;
		StatePresentation.Picture				= PictureLib.Warning32;
		StatePresentation.Text					= NStr("en = 'Couldn''t generate price list.'; ru = 'Не удалось сформировать прайс-лист.';pl = 'Nie udało się wygenerować cennika.';es_ES = 'No se ha podido generar la lista de precios.';es_CO = 'No se ha podido generar la lista de precios.';tr = 'Fiyat listesi oluşturulamadı.';it = 'Impossibile generare listino prezzi.';de = 'Fehler beim Generieren der Preisliste.'");
		
	ElsIf Status = 1 Then
		
		StatePresentation.Visible = True;
		StatePresentation.AdditionalShowMode	= AdditionalShowMode.DontUse;
		StatePresentation.Picture				= PictureLib.Warning32;
		StatePresentation.Text					= NStr("en = 'Price list size is too big, probably because of images.
			|Price list is saved locally or attached to the price list card.'; 
			|ru = 'Размер прайс-листа слишком велик (возможно, по причине использования рисунков).
			|Прайс-лист был сохранен локально или прикреплен к карточке прайс-листа.';
			|pl = 'Rozmiar cennika jest zbyt duży, możliwe z powodu grafiki.
			|Cennik jest zapisany lokalnie lub załączony do karty cennika.';
			|es_ES = 'El tamaño de la lista de precios es demasiado grande, probablemente debido a las imágenes.
			|La lista de precios se guarda localmente o se ha adjuntado a la tarjeta de lista de precios.';
			|es_CO = 'El tamaño de la lista de precios es demasiado grande, probablemente debido a las imágenes.
			|La lista de precios se guarda localmente o se ha adjuntado a la tarjeta de lista de precios.';
			|tr = 'Fiyat listesi muhtemelen görseller nedeniyle çok büyük.
			|Fiyat listesi yerel olarak kaydedildi veya fiyat listesi kartına eklendi.';
			|it = 'La dimensione del listino prezzi è troppo grande, forse a causa delle immagini.
			|Il listino prezzi è salvato localmente o allegato alla scheda del listino prezzi.';
			|de = 'Die Größe der Preisliste ist zu groß wahrscheinlich wegen Bilder.
			|Die Preisliste wurde lokal gespeichert oder an die Preislistenkarte angehängt.'");
		
	Else
		
		StatePresentation.Visible = Ложь;
		StatePresentation.AdditionalShowMode = AdditionalShowMode.DontUse;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterCloseMessagesAboutPriceListSize(Result, AdditionalParameters) Export
	
	SavePrintingForms(True);
	
EndProcedure

&AtServer
Procedure PriceListGenerateAtServer()
	
	If ValueIsFilled(CacheValues.LongActionParameters.JobID) Then
		
		TimeConsumingOperations.CancelJobExecution(CacheValues.LongActionParameters.JobID);
		CacheValues.LongActionParameters.JobID = Undefined;
		
	EndIf;
	
	TableDocument.Clear();
	CacheValues.LongActionParameters.SaveToFile = False;
	
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("PriceList", PriceList);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Generating'; ru = 'Создание';pl = 'Wygenerowanie';es_ES = 'Generación';es_CO = 'Generación';tr = 'Oluşturuluyor';it = 'Generazione';de = 'Generieren'");
	ExecutionParameters.RunInBackground = True;
	
	JobResult = TimeConsumingOperations.ExecuteInBackground("DataProcessors.GenerationPriceLists.GeneratePriceList",
		ProcedureParameters,
		ExecutionParameters);
		
	CacheValues.LongActionParameters.FormationResult = JobResult;
	CacheValues.LongActionParameters.JobID			 = JobResult.JobID;
	
EndProcedure

&AtServer
Procedure ResultLongActionToFormTableDocument()
	
	ExecutionResult = GetFromTempStorage(CacheValues.LongActionParameters.FormationResult.ResultAddress);
	
	PictureSizeMb = Round(ExecutionResult.PictureSizeByte/1048576, 0);
	
	If PictureSizeMb >= CacheValues.MaxAcceptablePictureSizeMb Then
		
		CacheValues.LongActionParameters.SaveToFile = True;
		
	Else
		
		TableDocument = ExecutionResult.SpreadsheetDocument;
		
		DeleteFromTempStorage(CacheValues.LongActionParameters.FormationResult.ResultAddress);
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion