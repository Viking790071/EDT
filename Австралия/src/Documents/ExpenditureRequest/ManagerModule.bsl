#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Cash flow projection table formation procedure.
//
// Parameters:
// DocumentRef - DocumentRef.CashInflowForecast - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTablePaymentCalendar(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", 					DocumentRef);
	Query.SetParameter("Company", 				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", 	StructureAdditionalProperties.ForPosting.PresentationCurrency);
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.CashFlowItem AS Item,
	|	DocumentTable.PaymentMethod AS PaymentMethod,
	|	DocumentTable.PaymentConfirmationStatus AS PaymentConfirmationStatus,
	|	CASE
	|		WHEN DocumentTable.CashAssetType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCash
	|		WHEN DocumentTable.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN DocumentTable.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccountPettyCash,
	|	&Ref AS Quote,
	|	DocumentTable.DocumentCurrency AS Currency,
	|	-DocumentTable.DocumentAmount AS Amount
	|FROM
	|	Document.ExpenditureRequest AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure

// Creates a document data table.
//
// Parameters:
// DocumentRef - DocumentRef.CashInflowForecast - Current
// document StructureAdditionalProperties - AdditionalProperties - Additional properties of the document
//	
Procedure InitializeDocumentData(DocumentRef, StructureAdditionalProperties) Export
	
	GenerateTablePaymentCalendar(DocumentRef, StructureAdditionalProperties);
	
EndProcedure

#Region LibrariesHandlers

#Region PrintInterface

// Procedure forms and displays a printable document form by the specified layout.
//
// Parameters:
// SpreadsheetDocument - TabularDocument in which
// 			   printing form will be displayed.
//  TemplateName    - String, printing form layout name.
//
Procedure GenerateExpenditureRequestning(SpreadsheetDocument, ObjectsArray, PrintObjects, PrintParams = Undefined)
	
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
	
	FirstDocument = True;
	SpreadsheetDocument.PrintParametersName = "PARAMETERS_PRINT_ExpenditureRequest_ExpenditureRequestning";
	Template = PrintManagement.PrintFormTemplate("Document.ExpenditureRequest.PF_MXL_ExpenditureRequestning", LanguageCode);
	
	FillStructureSection = New Structure;
	For Each CurrentDocument In ObjectsArray Do
		
		If Not FirstDocument Then
			
			SpreadsheetDocument.PutHorizontalPageBreak();
			
		EndIf;
		
		FirstDocument = False;
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	CAOutflowPlan.Ref,
		|	CAOutflowPlan.Number AS Number,
		|	CAOutflowPlan.Date AS DocumentDate,
		|	CAOutflowPlan.Company AS Company,
		|	CAOutflowPlan.Company.Prefix AS Prefix,
		|	CAOutflowPlan.DocumentAmount AS Amount,
		|	CAOutflowPlan.DocumentCurrency AS Currency,
		|	PRESENTATION(CAOutflowPlan.CashFlowItem) AS CFItem,
		|	CAST(CAOutflowPlan.Comment AS String(1000)) AS Comment,
		|	CAOutflowPlan.BankAccount.Code AS BANumber,
		|	CAOutflowPlan.PettyCash AS PettyCash,
		|	PRESENTATION(CAOutflowPlan.BasisDocument) AS DescriptionBases,
		|	CASE 
		|		WHEN CAOutflowPlan.Posted AND CAOutflowPlan.PaymentConfirmationStatus = Value(Enum.PaymentApprovalStatuses.Approved) THEN True
		|		ELSE False
		|	END AS ApplicationApproved,
		|	CAOutflowPlan.IncomingDocumentNumber,
		|	CAOutflowPlan.IncomingDocumentDate,
		|	CAOutflowPlan.Counterparty AS Counterparty,
		|	CAOutflowPlan.Contract AS Contract,
		|	CAOutflowPlan.Author AS Author,
		|	CAOutflowPlan.CashAssetType AS CashAssetType
		|FROM
		|	Document.ExpenditureRequest AS CAOutflowPlan
		|WHERE
		|	CAOutflowPlan.Ref = &CurrentDocument";
		Query.SetParameter("CurrentDocument", CurrentDocument);
		DocumentData = Query.Execute().Select();
		DocumentData.Next();
		
		// :::Approved, indent
		TemplateArea = Template.GetArea(?(DocumentData.ApplicationApproved, "Approved", "Indent"));
		SpreadsheetDocument.Put(TemplateArea);
		
		// :::Header
		TemplateArea = Template.GetArea("Header");
		FillStructureSection.Clear();
		
		DocumentNumber = DriveServer.GetNumberForPrintingConsideringDocumentDate(DocumentData.DocumentDate, DocumentData.Number, DocumentData.Prefix);
		DocumentDate = Format(DocumentData.DocumentDate, "DLF=D");
		Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Planning of the cash assets outflow #%1, %2'; ru = 'Планирование расхода денежных средств № %1, %2';pl = 'Planowanie aktywy rozchód środków pieniężnych nr #%1, %2';es_ES = 'Programación de la salida de los activos en efectivo #%1, %2';es_CO = 'Programación de la salida de los activos en efectivo #%1, %2';tr = '# %1, %2 Nakit varlık çıkışı planlaması';it = 'Pianificazione del flusso in uscito di liquidità #%1, %2';de = 'Planung des Kassenbestandsabflusses Nr. %1, %2'", LanguageCode),
			DocumentNumber,
			DocumentDate);
		FillStructureSection.Insert("Title", Title);
		TemplateArea.Parameters.Fill(FillStructureSection);
		SpreadsheetDocument.Put(TemplateArea);
		
		// :::String
		TemplateArea = Template.GetArea("String");
		FillStructureSection.Clear();
		
		FillStructureSection.Insert("CFItem", DocumentData.CFItem);
		FillStructureSection.Insert("Comment", DocumentData.Comment);
		FillStructureSection.Insert("DescriptionAmount", Format(DocumentData.Amount, "ND=15; NFD=2; NDS=.") + ", " + DocumentData.Currency);
		
		TemplateArea.Parameters.Fill(FillStructureSection);
		SpreadsheetDocument.Put(TemplateArea);
		
		// :::Footer
		TemplateArea = Template.GetArea("Footer");
		FillStructureSection.Clear();
		
		FillStructureSection.Insert("AmountInWords", CurrencyRateOperations.GenerateAmountInWords(DocumentData.Amount, DocumentData.Currency));
		FillStructureSection.Insert("DescriptionBases", DocumentData.DescriptionBases);
		FillStructureSection.Insert("CounterpartyDescription", DocumentData.Counterparty);
		
		FundingSourceDescription = "";
		If DocumentData.CashAssetType = Enums.CashAssetTypes.Noncash Then
			
			FundingSourceDescription = NStr("en = 'company settlement account #'; ru = 'расчетный счет организации №';pl = 'konto rozliczeniowe organizacji nr';es_ES = 'cuenta de liquidaciones de la empresa #';es_CO = 'cuenta de liquidaciones de la empresa #';tr = 'iş yeri uzlaşma hesabı #';it = 'Conto aziendale di pagamento №';de = 'Firmenverrechnungskonto Nr.'", LanguageCode) + DocumentData.BANumber;
			
		ElsIf DocumentData.CashAssetType = Enums.CashAssetTypes.Cash Then
			
			FundingSourceDescription = NStr("en = 'Organisation''s cash'; ru = 'касса организации';pl = 'Kasa organizacji';es_ES = 'Efectivo de la organización';es_CO = 'Efectivo de la organización';tr = 'Kuruluşun nakit parası';it = 'Cassa dell''organizzazione';de = 'Barmittel der Organisation'", LanguageCode) + " " + DocumentData.PettyCash;
			
		EndIf;
		FillStructureSection.Insert("FundingSourceDescription", FundingSourceDescription);
		
		TemplateArea.Parameters.Fill(FillStructureSection);
		SpreadsheetDocument.Put(TemplateArea);
		
		// :::Signature
		TemplateArea = Template.GetArea("Signature");
		FillStructureSection.Clear();
		
		ResponsiblePersons = DriveServer.OrganizationalUnitsResponsiblePersons(DocumentData.Company, DocumentData.DocumentDate);
		FillStructureSection.Insert("HeadPosition", ResponsiblePersons.HeadPosition);
		FillStructureSection.Insert("ChiefAccountantPosition", ResponsiblePersons.ChiefAccountantPosition);
		FillStructureSection.Insert("HeadNameAndSurname", ResponsiblePersons.HeadDescriptionFull);
		FillStructureSection.Insert("ChiefAccountantNameAndSurname", ResponsiblePersons.ChiefAccountantNameAndSurname);
		
		TemplateArea.Parameters.Fill(FillStructureSection);
		SpreadsheetDocument.Put(TemplateArea);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument.Ref);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
EndProcedure

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames    - String    - Names of layouts separated
//   by commas ObjectsArray  - Array    - Array of refs to objects that
//   need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   table documents OutputParameters       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	SpreadsheetDocument = New SpreadsheetDocument;
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "ExpenditureRequestning") Then
		
		GenerateExpenditureRequestning(SpreadsheetDocument, ObjectsArray, PrintObjects, PrintParameters.Result);
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection, 
			"ExpenditureRequestning",
			NStr("en = 'Cash outflow planning'; ru = 'Планирование оттока денежных средств';pl = 'Planowanie rozchodów środków pieniężnych';es_ES = 'Planificación de salida de caja';es_CO = 'Planificación de salida de caja';tr = 'Nakit çıkışı planlama';it = 'Pianificazione cassa in uscita';de = 'Mittelabflussplanung'"),
			SpreadsheetDocument);
		
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendOptions, ObjectsArray, PrintFormsCollection);

EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "ExpenditureRequestning";
	PrintCommand.Presentation = NStr("en = 'Cash expense planning'; ru = 'Планирование расходов ДС';pl = 'Planowanie wydatków gotówkowych';es_ES = 'Planificación de los gastos en efectivo';es_CO = 'Planificación de los gastos en efectivo';tr = 'Nakit harcama planlaması';it = 'Pianificazione del flusso di spese';de = 'Barmittelaufwandsplanung'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
EndProcedure

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#EndRegion

#EndIf