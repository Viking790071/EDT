
#Region Public

// The procedure defines the following: if when editing
// a document date, the document numbering period changes,
// the document is assigned a new unique number.
//
// Parameters:
//  DocumentRef - ref to a document from
// which procedure DocumentNewDate is called - new date of
// the DocumentInitialDate document - initial document date 
//
// Returns:
//  Number - dates difference.
//
Function CheckDocumentNumber(DocumentRef, NewDocumentDate, InitialDateOfDocument) Export
	
	DocMetadata = DocumentRef.Metadata();
	
	If DocMetadata.Numerator = Metadata.DocumentNumerators.CustomizableNumbering Then
		
		Return Numbering.GetDateDiff(DocumentRef, NewDocumentDate, InitialDateOfDocument);
		
	Else
		
		// Define number change periodicity assigned for the current documents kind
		NumberChangePeriod = DocumentRef.Metadata().NumberPeriodicity;
		
		// Depending on the set numbers change
		// periodicity define the difference of an old and a new document version dates.
		If NumberChangePeriod = Metadata.ObjectProperties.DocumentNumberPeriodicity.Year Then
			DateDiff = BegOfYear(InitialDateOfDocument) - BegOfYear(NewDocumentDate);
		ElsIf NumberChangePeriod = Metadata.ObjectProperties.DocumentNumberPeriodicity.Quarter Then
			DateDiff = BegOfQuarter(InitialDateOfDocument) - BegOfQuarter(NewDocumentDate);
		ElsIf NumberChangePeriod = Metadata.ObjectProperties.DocumentNumberPeriodicity.Month Then
			DateDiff = BegOfMonth(InitialDateOfDocument) - BegOfMonth(NewDocumentDate);
		ElsIf NumberChangePeriod = Metadata.ObjectProperties.DocumentNumberPeriodicity.Day Then
			DateDiff = InitialDateOfDocument - NewDocumentDate;
		Else
			Return 0;
		EndIf;
		
	EndIf;
	
	Return DateDiff;
	
EndFunction

Function AdvanceInvoicing(DocumentRef) Export
	
	Result = False;
	
	If ValueIsFilled(DocumentRef)
		And (TypeOf(DocumentRef) = Type("DocumentRef.SupplierInvoice")
		Or TypeOf(DocumentRef) = Type("DocumentRef.SalesInvoice")) Then
		
		EnumOperationKind = Common.ObjectAttributeValue(DocumentRef, "OperationKind");
		
		If TypeOf(DocumentRef) = Type("DocumentRef.SupplierInvoice") Then
			
			Result = (EnumOperationKind = Enums.OperationTypesSupplierInvoice.AdvanceInvoice);
			
		ElsIf TypeOf(DocumentRef) = Type("DocumentRef.SalesInvoice") Then
			
			Result = (EnumOperationKind = Enums.OperationTypesSalesInvoice.AdvanceInvoice);
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

// Write the application logout confirmation
// setting for the current user.
// 
// Parameters:
//   Value - Boolean   - setting value.
// 
Procedure SaveExitConfirmationSettings(Value) Export
	
	Common.CommonSettingsStorageSave("UserCommonSettings", "AskConfirmationOnExit", Value);
	
EndProcedure

Function GetCostAmount(StructureData) Export
	
	Return DriveServer.GetCostAmount(StructureData);
	
EndFunction

Function ObjectAttributeValue(Ref, AttributeName, SelectAllowedItems = False) Export
	
	Return Common.ObjectAttributeValue(Ref, AttributeName, SelectAllowedItems);
	
EndFunction

Function GetFunctionalOptionValue(Name) Export
	
	Return GetFunctionalOption(Name);
	
EndFunction

Function EventGetOperationKindMapToForms() Export
	
	Return Documents.Event.GetOperationKindMapToForms();
	
EndFunction

Function AdvancedContactInformationInputContactInformationInputFormName(InformationKind) Export
	
	Return DataProcessors.AdvancedContactInformationInput.ContactInformationInputFormName(InformationKind);
	
EndFunction

Function GetConstant(ConstantName) Export
	
	Constant = Constants[ConstantName].Get();
	Return Constant;
	
EndFunction

Procedure SetConstant(ConstantName, Value) Export
	
	Constants[ConstantName].Set(Value);
	
EndProcedure

Function GetCurrencyRateChoiceList(Currency, PresentationCurrency, DocumentDate, Company) Export
	
	Return DriveServer.GetCurrencyRateChoiceList(Currency, PresentationCurrency, DocumentDate, Company);
	
EndFunction

#Region TaxInvoices

Function TaxInvoiceIssuedGetTitle(OperationKind) Export
	
	Return Documents.TaxInvoiceIssued.GetTitle(OperationKind);
	
EndFunction

Function TaxInvoiceReceivedGetTitle(OperationKind) Export
	
	Return Documents.TaxInvoiceReceived.GetTitle(OperationKind);
	
EndFunction

#EndRegion

// begin Drive.FullVersion

#Region Subcontractors

Function GetNotificationEventName(Ref) Export
	
	If Ref.OperationType = Enums.OperationTypesGoodsIssue.TransferToSubcontractor 
		Or Ref.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractor
		Or Ref.OperationType = Enums.OperationTypesGoodsReceipt.ReturnFromSubcontractor Then
		
		Return "NotificationSubcontractDocumentsChange";
		
	ElsIf Ref.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer 
		Or Ref.OperationType = Enums.OperationTypesGoodsIssue.ReturnToSubcontractingCustomer
		Or Ref.OperationType = Enums.OperationTypesGoodsIssue.TransferToSubcontractingCustomer Then
		
		Return "NotificationSubcontractingServicesDocumentsChange";
		
	Else
		Return "";
	EndIf;
	
EndFunction

#EndRegion

// end Drive.FullVersion 

#Region DesktopManagement

// Determines a default desktop depending on the user access rights.
//
Procedure ConfigureUserDesktop(SettingsModified = False) Export
	
	HomePageSettings = Common.SystemSettingsStorageLoad("Common/HomePageSettings","");
	
	If HomePageSettings = Undefined Then
		
		HomePageSettings = New HomePageSettings;
		FormsContent = HomePageSettings.GetForms();
		
		If IsInRole("FullRights") Then
			
			FoundItem = FormsContent.LeftColumn.Find("CommonForm.GettingStarted");
			If FoundItem = Undefined
				OR Not (Constants.CompanyInformationIsFilled.Get()
					AND Constants.OpeningBalanceIsFilled.Get()) Then
				Return;
			EndIf;
			
			FormsContent.LeftColumn.Delete(FoundItem);
			FormsContent.LeftColumn.Add("DataProcessor.QuickActions.Form.QuickActions");
			FormsContent.LeftColumn.Add("DataProcessor.BusinessPulse.Form.BusinessPulse");
			FormsContent.RightColumn.Add("CommonForms.ToDoList");
		ElsIf IsInRole("UseAnalysisReports") Then
			FormsContent.LeftColumn.Add("DataProcessor.QuickActions.Form.QuickActions");
			FormsContent.LeftColumn.Add("DataProcessor.BusinessPulse.Form.BusinessPulse");
		ElsIf IsInRole("AddEditSalesSubsystem") Then
			FormsContent.LeftColumn.Add("DocumentJournal.SalesDocuments.ListForm");
		ElsIf IsInRole("AddEditPurchasesSubsystem") Then
			FormsContent.LeftColumn.Add("DocumentJournal.PurchaseDocuments.ListForm");
		ElsIf IsInRole("AddEditProductionSubsystem") Then
			FormsContent.LeftColumn.Add("DocumentJournal.ProductionDocuments.ListForm");
		ElsIf IsInRole("AddEditPayrollSubsystem") Then
			FormsContent.LeftColumn.Add("DocumentJournal.PayrollDocuments.ListForm");
		ElsIf IsInRole("AddEditBankSubsystem") Then
			FormsContent.LeftColumn.Add("DocumentJournal.BankDocuments.ListForm");
		ElsIf IsInRole("BasicRightsDriveForExternalUsers") Then
			
			FormsContent.RightColumn.Clear();
			FormsContent.LeftColumn.Clear();
			
			FormsContent.LeftColumn.Add("DataProcessor.ExternalUsersDesktop.Form.BalanceForm");
			FormsContent.LeftColumn.Add("DataProcessor.ExternalUsersDesktop.Form.FinanceDataChartForm");
			
			FormsContent.RightColumn.Add("DataProcessor.ExternalUsersDesktop.Form.CompanyInfoForm");
			If GetFunctionalOption("UseSupportForExternalUsers") Then
				FormsContent.RightColumn.Add("BusinessProcess.Job.Form.ListForm");
			EndIf;
			
		EndIf;
		
		HomePageSettings.SetForms(FormsContent);
		Common.SystemSettingsStorageSave("Common/HomePageSettings","", HomePageSettings);
		
		SettingsModified = True;
		
	ElsIf IsInRole("BasicRightsDriveForExternalUsers") Then
		
		HomePageSettings = New HomePageSettings;
		FormsContent = HomePageSettings.GetForms();
		
		FormsContent.RightColumn.Clear();
		FormsContent.LeftColumn.Clear();
		
		FormsContent.LeftColumn.Add("DataProcessor.ExternalUsersDesktop.Form.BalanceForm");
		FormsContent.LeftColumn.Add("DataProcessor.ExternalUsersDesktop.Form.FinanceDataChartForm");
		
		FormsContent.RightColumn.Add("DataProcessor.ExternalUsersDesktop.Form.CompanyInfoForm");
		If GetFunctionalOption("UseSupportForExternalUsers") Then
			FormsContent.RightColumn.Add("BusinessProcess.Job.Form.ListForm");
		EndIf;
		
		HomePageSettings.SetForms(FormsContent);
		Common.SystemSettingsStorageSave("Common/HomePageSettings","", HomePageSettings);
		
		SettingsModified = True;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Print

Function MessageTemplateAboutUserTemplateUsed() Export
	
	If Not Users.IsFullUser() Then
		Return Undefined;
	EndIf;
	
	Table = New SpreadsheetDocument;
	
	Table.ShowGrid = False;
	Table.ShowHeaders = False;
	Table.PageOrientation = PageOrientation.Landscape;
	Table.FitToPage = True;
	Table.ReadOnly = True;
	
	Template = GetCommonTemplate("WarningAboutUserTemplateUsed");
	Table.Put(Template.GetArea("Header"));
	
	CommonSettingsStorage.Delete("UserTemplateUsed", "" , InfoBaseUsers.CurrentUser().Name);
	
	Return Table;
	
EndFunction

#EndRegion

#EndRegion
