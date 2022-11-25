#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.Companies);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion
	
#Region ProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Objects bulk edit.

// Returns the list of attributes
// excluded from the scope of the batch object modification.
//
Function NotEditableInGroupProcessingAttributes() Export
	
	Result = New Array;
	
	Result.Add("Prefix");
	Result.Add("ContactInformation.*");
	
	Return Result
EndFunction

Function FindDefaultVATNumber(Company, VATNumbers) Export 
	
	VATNumber = "";
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	VATNumbers.LineNumber AS LineNumber,
	|	VATNumbers.VATNumber AS VATNumber,
	|	VATNumbers.RegistrationDate AS RegistrationDate,
	|	VATNumbers.RegistrationValidTill AS RegistrationValidTill
	|INTO TT_VATNumbers
	|FROM
	|	&VATNumbers AS VATNumbers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Companies.VATNumber AS VATNumber
	|FROM
	|	Catalog.Companies AS Companies
	|WHERE
	|	NOT Companies.VATNumber = """"
	|	AND Companies.Ref = &Company
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	TT_VATNumbers.VATNumber
	|FROM
	|	TT_VATNumbers AS TT_VATNumbers
	|WHERE
	|	NOT TT_VATNumbers.VATNumber = """"
	|	AND (TT_VATNumbers.RegistrationDate <= &CurrentDate
	|			OR TT_VATNumbers.RegistrationDate = DATETIME(1, 1, 1))
	|	AND (TT_VATNumbers.RegistrationValidTill >= &CurrentDate
	|			OR TT_VATNumbers.RegistrationValidTill = DATETIME(1, 1, 1))";
	
	Query.SetParameter("Company", Company);
	Query.SetParameter("VATNumbers", VATNumbers);
	Query.SetParameter("CurrentDate", BegOfDay(CurrentSessionDate()));
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		VATNumber = Selection.VATNumber;
	EndIf;
	
	Return VATNumber;
	
EndFunction

#Region UseSeveralCompanies

// Returns company by default.
// If there is only one company in the IB which is not marked for
// deletion and is not predetermined, then a ref to this company will be returned, otherwise an empty ref will be returned.
//
// Returns:
//     CatalogRef.Companies - ref to the company.
//
Function CompanyByDefault() Export
	
	Company = Catalogs.Companies.EmptyRef();
	
	SubsidaryCompany = Constants.ParentCompany.Get();
	MainCompanyUserSetting = DriveReUse.GetValueByDefaultUser(Users.AuthorizedUser(), "MainCompany");
	If ValueIsFilled(SubsidaryCompany) Then
		
		Company = SubsidaryCompany;
		
	ElsIf ValueIsFilled(MainCompanyUserSetting) Then
		
		Company = MainCompanyUserSetting;
		
	Else
		
		Query = New Query;
		Query.Text =
		"SELECT ALLOWED TOP 2
		|	Companies.Ref AS Company
		|FROM
		|	Catalog.Companies AS Companies
		|WHERE
		|	NOT Companies.DeletionMark";
		
		Selection = Query.Execute().Select();
		If Selection.Next() AND Selection.Count() = 1 Then
			Company = Selection.Company;
		EndIf;
		
	EndIf;
	
	Return Company;

EndFunction

// Returns quantity of the Companies catalog items.
// Does not consider items that are predefined and marked for deletion.
//
// Returns:
//     Number - companies quantity.
//
Function CompaniesCount() Export
	
	SetPrivilegedMode(True);
	
	Quantity = 0;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	COUNT(*) AS Quantity
	|FROM
	|	Catalog.Companies AS Companies
	|WHERE
	|	NOT Companies.Predefined";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Quantity = Selection.Quantity;
	EndIf;
	
	SetPrivilegedMode(False);
	
	Return Quantity;
	
EndFunction

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID				= "CompanyAttributes";
	PrintCommand.Presentation	= NStr("en = 'Attributes'; ru = 'Реквизиты';pl = 'Dane firmy';es_ES = 'Atributos';es_CO = 'Atributos';tr = 'Öznitelikler';it = 'Attributi';de = 'Attribute'");
	PrintCommand.FormsList		= "ItemForm,ListForm";
	PrintCommand.FormTitle		= NStr("en = 'Print company attributes'; ru = 'Печать реквизитов организации';pl = 'Drukuj dane firmy';es_ES = 'Atributos de la empresa de impresión';es_CO = 'Atributos de la empresa de impresión';tr = 'İş yeri özelliklerini yazdır';it = 'Stampa i requisiti della azienda';de = 'Firmenattribute ausdrucken'");
	PrintCommand.Order			= 1;
	
EndProcedure

// Method returns all companies
Function AllCompanies() Export
	
	Query = New Query("
	|SELECT ALLOWED
	|	Company.Ref AS Company
	|FROM
	|	Catalog.Companies AS Company");
	
	Result = Query.Execute().Unload();
	
	Return Result.UnloadColumn("Company");
EndFunction

#EndRegion

#EndRegion

#Region LibrariesHandlers

// It is called while transferring to SSL version 2.2.1.12.
//
Procedure FillConstantUseSeveralCompanies() Export
	
	If GetFunctionalOption("UseSeveralCompanies") =
			GetFunctionalOption("UseOneCompany") Then
		// Options should have the opposite values.
		// If it is not true, then there were no such options in IB - initialize their values.
		Constants.UseSeveralCompanies.Set(CompaniesCount() > 1);
	EndIf;
	
EndProcedure

// Printing template generation procedure
//
Function GenerateFaxPrintJobAssistant(CompaniesArray, PrintObjects, TemplateName, PrintParams = Undefined)
	
	// MultilingualSupport
	If PrintParams = Undefined Or Not PrintParams.Property("LanguageCode") Then
		LanguageCode = NationalLanguageSupportClientServer.DefaultLanguageCode();
	Else
		LanguageCode = PrintParams.LanguageCode;
	EndIf;
	
	If LanguageCode <> CurrentLanguage().LanguageCode Then 
		SessionParameters.LanguageCodeForOutput = LanguageCode;
	EndIf;
	// End MultilingualSupport
	
	SpreadsheetDocument	= New SpreadsheetDocument;
	Template				= PrintManagement.PrintFormTemplate("Catalog.Companies." + TemplateName, LanguageCode);
	
	For Each Company In CompaniesArray Do 
	
		SpreadsheetDocument.Put(Template.GetArea("FieldsRequired"));
		SpreadsheetDocument.Put(Template.GetArea("Line"));
		SpreadsheetDocument.Put(Template.GetArea("Schema"));
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, 1, PrintObjects, Company);
	
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;

EndFunction

// Procedure of generating preliminary document printing form (sample)
//
// It is called from the "Company" card to view logos placing
//
Function PreviewPrintedFormProformaInvoice(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined) Export
	
	Var Errors;
	
	UseVAT	= GetFunctionalOption("UseVAT");
	
	Company = ObjectsArray[0];
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	DateValue = CurrentSessionDate();
	
	FunctionalCurrency = DriveReUse.GetFunctionalCurrency();
	
	Header = New Structure;
	Header.Insert("Ref",				Company);
	Header.Insert("AmountIncludesVAT",	False);
	Header.Insert("DocumentCurrency",	FunctionalCurrency);
	Header.Insert("Currency",			FunctionalCurrency);
	Header.Insert("DocumentDate",		DateValue);
	Header.Insert("DocumentNumber",		"00000000001");
	Header.Insert("Company",			Company);
	Header.Insert("BankAccount",		Company.BankAccountByDefault);
	Header.Insert("Prefix",				Company.Prefix);
	Header.Insert("CompanyLogoFile",	Company.LogoFile);
	Header.Insert("Counterparty",		NStr("en = 'Field contains customer information: legal name, TIN, legal address, phones.'; ru = 'Поле содержит информацию покупателя: полное наименование, ИНН, юридический адрес, телефоны.';pl = 'Pole zawiera informacje o kliencie: nazwę prawną, numer NIP, adres prawny, telefony.';es_ES = 'Campo contiene la información del cliente: nombre legal, NIF, dirección legal, teléfonos.';es_CO = 'Campo contiene la información del cliente: nombre legal, NIF, dirección legal, teléfonos.';tr = 'Alan müşteri bilgilerini içerir: yasal unvan, VKN, yasal adres, telefonlar.';it = 'Il campo contiene le informazioni dell''acquirente: denominazione, cod.fiscale, sede legale, numeri di telefono.';de = 'Feld enthält Kundeninformationen: offizieller Name, Steuernummer, Geschäftsadresse, Telefone.'"));
	
	Inventory = New Structure;
	Inventory.Insert("LineNumber",				1);
	Inventory.Insert("ProductDescription",		NStr("en = 'Inventory for preview'; ru = 'Запас для предварительного просмотра';pl = 'Zapasy do podglądu';es_ES = 'Inventario para una vista previa';es_CO = 'Inventario para una vista previa';tr = 'Önizleme için stok';it = 'Scorta per l''anteprima';de = 'Bestand für die Vorschau'"));
	Inventory.Insert("SKU",						NStr("en = 'SKU-0000001'; ru = 'АРТ-0000001';pl = 'SKU-0000001';es_ES = 'SKU-0000001';es_CO = 'SKU-0000001';tr = 'SKU-0000001';it = 'ART-0000001';de = 'SKU-0000001'"));
	Inventory.Insert("UnitOfMeasure",			Catalogs.UOMClassifier.pcs);
	Inventory.Insert("Quantity",				1);
	Inventory.Insert("Price",					100);
	Inventory.Insert("Amount",					100);
	Inventory.Insert("TotalVAT",				18);
	Inventory.Insert("Total",					118);
	Inventory.Insert("VATAmount",				NStr("en = 'VAT amount'; ru = 'Сумма НДС';pl = 'Kwota podatku VAT';es_ES = 'Importe del IVA';es_CO = 'Importe del IVA';tr = 'KDV tutarı';it = 'Importo IVA';de = 'USt.-Betrag'"));
	Inventory.Insert("Characteristic",			Catalogs.ProductsCharacteristics.EmptyRef());
	Inventory.Insert("DiscountMarkupPercent",	0);
	
	FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
	
	// MultilingualSupport
	If PrintParams = Undefined Or Not PrintParams.Property("LanguageCode") Then
		LanguageCode = NationalLanguageSupportClientServer.DefaultLanguageCode();
	Else
		LanguageCode = PrintParams.LanguageCode;
	EndIf;
	
	If LanguageCode <> CurrentLanguage().LanguageCode Then 
		SessionParameters.LanguageCodeForOutput = LanguageCode;
	EndIf;
	// End MultilingualSupport
	
	SpreadsheetDocument.PrintParametersName = "PARAMETERS_PRINT_PF_MXL_Quote";
	
	Template = PrintManagement.PrintFormTemplate("DataProcessor.PrintQuote.PF_MXL_Quote", LanguageCode);
	
	#Region PrintQuoteTitleArea
	
	TitleArea = Template.GetArea("Title");
	TitleArea.Parameters.Fill(Header);
	
	If ValueIsFilled(Header.CompanyLogoFile) Then
		
		PictureData = AttachedFiles.GetBinaryFileData(Header.CompanyLogoFile);
		If ValueIsFilled(PictureData) Then
			
			TitleArea.Drawings.Logo.Picture = New Picture(PictureData);
			
		EndIf;
		
	Else
		
		TitleArea.Drawings.Delete(TitleArea.Drawings.Logo);
		
	EndIf;
	
	SpreadsheetDocument.Put(TitleArea);
	
	#EndRegion
	
	#Region PrintQuoteCompanyInfoArea
	
	CompanyInfoArea = Template.GetArea("CompanyInfo");
	
	InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(
		Header.Company,
		Header.DocumentDate,
		,
		Header.BankAccount,
		,
		LanguageCode);
	CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
	
	SpreadsheetDocument.Put(CompanyInfoArea);
	
	#EndRegion
	
	#Region PrintQuoteCounterpartyInfoArea
	
	CounterpartyInfoArea = Template.GetArea("CounterpartyInfo");
	CounterpartyInfoArea.Parameters.Fill(Header);
	
	SpreadsheetDocument.Put(CounterpartyInfoArea);
	
	#EndRegion
	
	#Region PrintQuoteCommentArea
	
	CommentArea = Template.GetArea("Comment");
	CommentArea.Parameters.TermsAndConditions = "";
	
	SpreadsheetDocument.Put(CommentArea);
	
	#EndRegion
	
	#Region PrintQuoteTotalsAreaPrefill
	
	TotalsAreasArray = New Array;
	
	LineTotalArea = Template.GetArea("LineTotal");
	LineTotalArea.Parameters.Fill(Header);
	
	TotalsAreasArray.Add(LineTotalArea);
	
	#EndRegion
	
	#Region PrintQuoteLinesArea
	
	LineHeaderArea = Template.GetArea("LineHeader");
	SpreadsheetDocument.Put(LineHeaderArea);
	
	LineSectionArea	= Template.GetArea("LineSection");
	SeeNextPageArea	= Template.GetArea("SeeNextPage");
	EmptyLineArea	= Template.GetArea("EmptyLine");
	PageNumberArea	= Template.GetArea("PageNumber");
	
	PageNumber = 0;
	
	TabSelection = Inventory;
	
	LineSectionArea.Parameters.Fill(TabSelection);
	
	AreasToBeChecked = New Array;
	AreasToBeChecked.Add(LineSectionArea);
	For Each Area In TotalsAreasArray Do
		AreasToBeChecked.Add(Area);
	EndDo;
	AreasToBeChecked.Add(PageNumberArea);
	
	If Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Then
		
		SpreadsheetDocument.Put(LineSectionArea);
		
	Else
		
		SpreadsheetDocument.Put(SeeNextPageArea);
		
		AreasToBeChecked.Clear();
		AreasToBeChecked.Add(EmptyLineArea);
		AreasToBeChecked.Add(PageNumberArea);
		
		For i = 1 To 50 Do
			
			If Not Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
				Or i = 50 Then
				
				PageNumber = PageNumber + 1;
				PageNumberArea.Parameters.PageNumber = PageNumber;
				SpreadsheetDocument.Put(PageNumberArea);
				Break;
				
			Else
				
				SpreadsheetDocument.Put(EmptyLineArea);
				
			EndIf;
			
		EndDo;
		
		SpreadsheetDocument.PutHorizontalPageBreak();
		SpreadsheetDocument.Put(TitleArea);
		SpreadsheetDocument.Put(LineHeaderArea);
		SpreadsheetDocument.Put(LineSectionArea);
		
	EndIf;
	
	#EndRegion
	
	#Region PrintQuoteTotalsArea
	
	For Each Area In TotalsAreasArray Do
		
		SpreadsheetDocument.Put(Area);
		
	EndDo;
	
	AreasToBeChecked.Clear();
	AreasToBeChecked.Add(EmptyLineArea);
	AreasToBeChecked.Add(PageNumberArea);
	
	For i = 1 To 50 Do
		
		If Not Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
			Or i = 50 Then
			
			PageNumber = PageNumber + 1;
			PageNumberArea.Parameters.PageNumber = PageNumber;
			SpreadsheetDocument.Put(PageNumberArea);
			Break;
			
		Else
			
			SpreadsheetDocument.Put(EmptyLineArea);
			
		EndIf;
		
	EndDo;
	
	#EndRegion
	
	PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
	
	CommonClientServer.ReportErrorsToUser(Errors);
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

// The procedure for the formation of a spreadsheet document with details of companies
//
Function PrintCompanyCard(ObjectsArray, PrintObjects, PrintParams = Undefined)
	
	// MultilingualSupport
	If PrintParams = Undefined Then
		LanguageCode = NationalLanguageSupportClientServer.DefaultLanguageCode();
	Else
		LanguageCode = PrintParams.LanguageCode;
	EndIf;
	
	If LanguageCode <> CurrentLanguage().LanguageCode Then 
		SessionParameters.LanguageCodeForOutput = LanguageCode;
	EndIf;
	// End MultilingualSupport
	
	SpreadsheetDocument = New SpreadsheetDocument;
	Template = PrintManagement.PrintFormTemplate("Catalog.Companies.CompanyAttributes", LanguageCode);
	Separator = Template.GetArea("Separator");
	
	CurrentDate		= CurrentSessionDate();
	FirstDocument	= True;
	
	For Each Company In ObjectsArray Do
	
		If Not FirstDocument Then
			SpreadsheetDocument.Put(Separator);
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		
		FirstDocument	= False;
		RowNumberBegin	= SpreadsheetDocument.TableHeight + 1;
		IsLegalEntity	= Company.LegalEntityIndividual = Enums.CounterpartyType.LegalEntity;
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(
			Company,
			CurrentDate,
			,
			,
			,
			LanguageCode);
		
		Area = Template.GetArea("Description");
		Area.Parameters.DescriptionFull = InfoAboutCompany.FullDescr;
		SpreadsheetDocument.Put(Area);
		
		If ValueIsFilled(InfoAboutCompany.TIN) Then
			Area = Template.GetArea("TIN");
			Area.Parameters.TIN = InfoAboutCompany.TIN;
			SpreadsheetDocument.Put(Area);
		EndIf;
		
		If ValueIsFilled(InfoAboutCompany.RegistrationNumber) Then
			Area = Template.GetArea("RegistrationNumber");
			Area.Parameters.RegistrationNumber = InfoAboutCompany.RegistrationNumber;
			SpreadsheetDocument.Put(Area);
		EndIf;
		
		If ValueIsFilled(InfoAboutCompany.SWIFT)
			AND ValueIsFilled(InfoAboutCompany.Bank)
			AND (ValueIsFilled(InfoAboutCompany.AccountNo)
				OR ValueIsFilled(InfoAboutCompany.IBAN)) Then
			
			Area = Template.GetArea("BankAccount");
			Area.Parameters.AccountNo	= InfoAboutCompany.AccountNo;
			Area.Parameters.IBAN		= InfoAboutCompany.IBAN;
			Area.Parameters.SWIFT		= InfoAboutCompany.SWIFT;
			Area.Parameters.Bank		= InfoAboutCompany.Bank;
			SpreadsheetDocument.Put(Area);
			
		EndIf;
		
		If ValueIsFilled(InfoAboutCompany.LegalAddress) 
			Or ValueIsFilled(InfoAboutCompany.PhoneNumbers) Then
			SpreadsheetDocument.Put(Separator);
		EndIf;
		
		If IsLegalEntity AND ValueIsFilled(InfoAboutCompany.LegalAddress) Then
			Area = Template.GetArea("LegalAddress");
			Area.Parameters.LegalAddress	= InfoAboutCompany.LegalAddress;
			SpreadsheetDocument.Put(Area);
		EndIf;
			
		If Not IsLegalEntity AND ValueIsFilled(InfoAboutCompany.LegalAddress) Then
			Area = Template.GetArea("IndividualAddress");
			Area.Parameters.IndividualAddress	= InfoAboutCompany.LegalAddress;
			SpreadsheetDocument.Put(Area);
		EndIf;
			
		If ValueIsFilled(InfoAboutCompany.PhoneNumbers) Then
			Area = Template.GetArea("Phone");
			Area.Parameters.Phone = InfoAboutCompany.PhoneNumbers;
			SpreadsheetDocument.Put(Area);
		EndIf;
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, RowNumberBegin, PrintObjects, Company);
		
	EndDo;
	
	SpreadsheetDocument.TopMargin		= 20;
	SpreadsheetDocument.BottomMargin	= 20;
	SpreadsheetDocument.LeftMargin		= 20;
	SpreadsheetDocument.RightMargin		= 20;
	
	SpreadsheetDocument.PageOrientation	= PageOrientation.Portrait;
	SpreadsheetDocument.FitToPage		= True;
	
	SpreadsheetDocument.PrintParametersKey = "PrintParameters__Company_CompanyCard";
	
	Return SpreadsheetDocument;

EndFunction

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames    - String    - Names of templates separated
//   by commas ObjectsArray  - Array    - Array of refs to objects that
//   need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   table documents OutputParameters       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray,
				 PrintParameters,
				 PrintFormsCollection,
				 PrintObjects,
				 OutputParameters) Export
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "CompanyAttributes") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"CompanyAttributes",
			NStr("en = 'Company details'; ru = 'Реквизиты организации';pl = 'Dane o firmie';es_ES = 'Detalles de la empresa';es_CO = 'Detalles de la empresa';tr = 'İş yeri ayrıntıları';it = 'Dettagli Azienda';de = 'Firmendetails'"),
			PrintCompanyCard(ObjectsArray, PrintObjects, PrintParameters.Result));
		
	EndIf;
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "PrintFaxPrintWorkAssistant") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"PrintFaxPrintWorkAssistant",
			NStr("en = 'How can I quickly and easily create fax signature and printing?'; ru = 'Как быстро и легко создать факсимильную подпись и печать?';pl = 'Jak mogę szybko i łatwo utworzyć podpis faksu i wydrukować?';es_ES = '¿Cómo puedo crear rápida y fácilmente una firma e impresión de fax?';es_CO = '¿Cómo puedo crear rápida y fácilmente una firma e impresión de fax?';tr = 'Nasıl hızlı ve kolay bir şekilde faks imzası ve çıktı oluşturabilirim?';it = 'Come posso creare in modo facile e veloce firme e stampe fax?';de = 'Wie kann ich Faxsignatur und Faxdruck schnell und einfach erstellen?'"),
			GenerateFaxPrintJobAssistant(ObjectsArray, PrintObjects, "AssistantWorkFaxPrint", PrintParameters.Result));
		
	EndIf;
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "PreviewPrintedFormProformaInvoice") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"PreviewPrintedFormProformaInvoice",
			NStr("en = 'Quote'; ru = 'Коммерческое предложение';pl = 'Oferta cenowa';es_ES = 'Presupuesto';es_CO = 'Presupuesto';tr = 'Teklif';it = 'Preventivo';de = 'Angebot'"),
			PreviewPrintedFormProformaInvoice(ObjectsArray, PrintObjects, "ProformaInvoice", PrintParameters.Result));
		
	EndIf;
	
	
EndProcedure

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#Region ObjectAttributesLock

// StandardSubsystems.ObjectAttributesLock

// See ObjectsAttributesEditBlockedOverridable.OnDefineObjectsWithLockedAttributes. 
Function GetObjectAttributesToLock() Export
	
	AttributesToLock = New Array;
	
	AttributesToLock.Add("DescriptionFull");
	AttributesToLock.Add("LegalEntityIndividual");
	AttributesToLock.Add("LegalForm");
	AttributesToLock.Add("Prefix");
	AttributesToLock.Add("NumberingIndex");
	AttributesToLock.Add("Name");
	AttributesToLock.Add("Patronymic");
	AttributesToLock.Add("Surname");
	AttributesToLock.Add("TIN");
	AttributesToLock.Add("EORI");
	AttributesToLock.Add("RegistrationDate");
	AttributesToLock.Add("RegistrationNumber");
	AttributesToLock.Add("RegistrationCountry");
	AttributesToLock.Add(
		"VATNumbers; VATNumber, RegistrationDate, RegistrationCountry, " 
		+ "SwitchTypeListOfVATNumbers, VATNumbersSetAsDafaultVATNumber");
	AttributesToLock.Add("BusinessCalendar");
	AttributesToLock.Add("PresentationCurrency");
	AttributesToLock.Add("ExchangeRateMethod");
	AttributesToLock.Add("CreditorID");
	AttributesToLock.Add("ExchangeRatesImportProcessor");
	AttributesToLock.Add("PricesPrecision");
	
	Return AttributesToLock;
	
EndFunction

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#EndRegion

#Region InfobaseUpdate

Procedure FillPricesPrecision() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Companies.Ref AS Company
	|FROM
	|	Catalog.Companies AS Companies
	|WHERE
	|	Companies.PricesPrecision = 0";
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		
		Company = Selection.Company.GetObject();
		Company.PricesPrecision = 2;
		
		Try
			
			Company.Write();
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save catalog ""%1"". Details: %2'; ru = 'Не удалось записать справочник ""%1"". Подробнее: %2';pl = 'Nie można zapisać katalogu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el catálogo ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el catálogo ""%1"". Detalles: %2';tr = '""%1"" kataloğu saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare l''anagrafica ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Katalogs ""%1"". Details: %2'"),
				Selection.Company,
				BriefErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				NStr("en = 'Infobase update'; ru = 'Обновление информационной базы';pl = 'Aktualizacja bazy informacyjnej';es_ES = 'Actualización de la infobase';es_CO = 'Actualización de la infobase';tr = 'Infobase güncellemesi';it = 'Aggiornamento del database';de = 'Infobase-Aktualisierung'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				Metadata.Catalogs.Companies,
				,
				ErrorDescription);
				
		EndTry;
			
	EndDo;
	
EndProcedure

#EndRegion

#EndIf
