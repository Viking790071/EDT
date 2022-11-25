#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID				= "SEPADirectDebitMandateForm";
	PrintCommand.Presentation	= NStr("en = 'Mandate'; ru = 'Мандат';pl = 'Zlecenie';es_ES = 'Mandato';es_CO = 'Mandato';tr = 'Talimat';it = 'Mandato';de = 'Lastschriftmandat'");
	PrintCommand.FormsList		= "ItemForm,ListForm";
	PrintCommand.Order			= 1;

EndProcedure

Function ComposeDesctiption(Item) Export
	// Compose item description
	Descr = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Mandate from %1 (%2)'; ru = 'Мандат с %1 (%2)';pl = 'Zlecenie od %1 (%2)';es_ES = 'Mandato desde %1 (%2)';es_CO = 'Mandato desde %1 (%2)';tr = '%1 ile başlayarak talimat (%2)';it = 'Mandato per %1 (%2)';de = 'Lastschriftmandat vom %1 (%2)'"),
		Format(Item.MandateDate,NStr("en = 'dd.MM.yyyy'; ru = 'дд.ММ.гггг';pl = 'dd.MM.yyyy';es_ES = 'dd.MM.aaaa';es_CO = 'dd.MM.aaaa';tr = 'gg.AA.yyyy';it = 'dd.MM.yyyy';de = 'dd.MM.yyyy'")),
		Item.MandateStatus);
	Return(Descr)
EndFunction

#Region LibrariesHandlers

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
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "SEPADirectDebitMandateForm") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"SEPADirectDebitMandateForm",
			NStr("en = 'Mandate form'; ru = 'Форма мандата';pl = 'Formularz zlecenia';es_ES = 'Mandato desde';es_CO = 'Mandato desde';tr = 'Talimat formu';it = 'Modulo di mandato';de = 'Lastschriftmandat vom'"),
			PrintSEPADirectDebitMandateForm(ObjectsArray, PrintObjects));
		
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
	
	AttributesToLock.Add("Owner");
	AttributesToLock.Add("Company");
	AttributesToLock.Add("DirectDebitType");
	AttributesToLock.Add("DirectDebitSequenceType");
	AttributesToLock.Add("IBAN");
	AttributesToLock.Add("SWIFT");
	AttributesToLock.Add("MandateID");
	AttributesToLock.Add("MandateDate");
	AttributesToLock.Add("Recurring");
	AttributesToLock.Add("MandateStatus");
	AttributesToLock.Add("MandatePeriodFrom");
	AttributesToLock.Add("MandatePeriodTo");
	AttributesToLock.Add("BankAccount");
	
	Return AttributesToLock;
EndFunction

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#EndRegion

#EndRegion

#Region Private

#Region Print

// The procedure for the formation of a spreadsheet document with details of companies
//
Function PrintSEPADirectDebitMandateForm(ObjectsArray, PrintObjects)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	Template = PrintManagement.PrintFormTemplate("Catalog.DirectDebitMandates.SEPADirectDebitMandateForm");
	Separator = Template.GetArea("Separator");
	
	CurrentDate		= CurrentSessionDate();
	FirstDocument	= True;
	
	For Each Mandate In ObjectsArray Do
	
		If Not FirstDocument Then
			SpreadsheetDocument.Put(Separator);
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		
		FirstDocument	= False;
		RowNumberBegin	= SpreadsheetDocument.TableHeight + 1;
		
		
		Area = Template.GetArea("Main");
		Area.Parameters.CreditorID = Mandate.Company.CreditorID;
		Area.Parameters.MandateID = Mandate.MandateID;
		Area.Parameters.DebitorName = Mandate.Owner.DescriptionFull;
		
		
		InfoAboutCounterparty = DriveServer.InfoAboutLegalEntityIndividual(Mandate.Owner, CurrentDate);
		
		If ValueIsFilled(InfoAboutCounterparty.LegalAddress) Then
			Area.Parameters.DebitorAddress = InfoAboutCounterparty.LegalAddress;
			Area.Parameters.DebitorCity = "";
			Area.Parameters.DebitorCountry = "";
		EndIf;
		
		Area.Parameters.DebitorIBAN = Mandate.BankAccount.IBAN;
		Area.Parameters.DebitorSWIFT = Mandate.BankAccount.Bank.Code;
		
		SpreadsheetDocument.Put(Area);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, RowNumberBegin, PrintObjects, Mandate);
		
	EndDo;
	
	SpreadsheetDocument.TopMargin		= 20;
	SpreadsheetDocument.BottomMargin	= 20;
	SpreadsheetDocument.LeftMargin		= 20;
	SpreadsheetDocument.RightMargin		= 20;
	
	SpreadsheetDocument.PageOrientation	= PageOrientation.Portrait;
	SpreadsheetDocument.FitToPage		= True;
	
	SpreadsheetDocument.PrintParametersKey = "PrintParameters__SEPADirectDebitMandateForm";
	
	Return SpreadsheetDocument;

EndFunction

#EndRegion

#EndRegion

#EndIf

