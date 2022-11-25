#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	IsNewRecord		= Record.SourceRecordKey.IsEmpty();
	PeriodInitial	= Record.SourceRecordKey.Period;
	
	If Parameters.Property("Company") Then
		Record.Company = Parameters.Company;
		Items.Company.Visible = False;
	EndIf;
	
	If Parameters.Property("Period") Then
		Record.Period = Parameters.Period;
	ElsIf IsNewRecord Then
		Record.Period = GetInitialDate();
	EndIf; 
	
	If Parameters.Property("CompanyDescription") Then
		CompanyDescription = Parameters.CompanyDescription;
	Else
		CompanyDescription = Common.ObjectAttributeValue(Company, "Description");
	EndIf;
	
	If Parameters.Property("VATNumberIsFilled") Then
		VATNumberIsFilled = Parameters.VATNumberIsFilled;
	EndIf;
	
	If Not ValueIsFilled(Record.Company) Then
		Record.Company = DriveReUse.GetValueOfSetting("MainCompany");
	EndIf;
	
	If Not ValueIsFilled(Record.Company) Then
		Record.Company = Catalogs.Companies.MainCompany;
	EndIf;
	
	If Parameters.Property("RecordSetTempStorageAddress") Then
		RecordSetData = GetFromTempStorage(Parameters.RecordSetTempStorageAddress);
		If RecordSetData.Count() Then
			FillPropertyValues(Record, RecordSetData[0]);
		EndIf;
		Items.FormWrite.Visible = False;
	EndIf;
	
	UseVAT = Constants.FunctionalOptionUseVAT.Get();
	
	EnabledSalesTaxAndVAT();
	Items.PostExpensesOnInventoryConsumedByWorkOrder.Visible = GetFunctionalOption("UseWorkOrders");
	
	FillSpecifiedPropertyValues(, Record);
	
	RegisteredForVAT	= Record.RegisteredForVAT;
	
	PostAdvancePaymentsBySourceDocuments = Record.PostAdvancePaymentsBySourceDocuments;
	PostVATEntriesBySourceDocuments = Record.PostVATEntriesBySourceDocuments;
	
	SetIssueAutomaticallyAgainstSales();
	
	LoadTypesOfAccountingTable(Company, Period);
	
	IsClosedPeriod	= CheckPeriodOnClosingDates(Period);
	PeriodPrevious	= Period;
	CompanyPrevious	= Company;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetRestrictionsForTypesOfAccounting();
	FillConditionalAppearance();
	FormManagement();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	ClearMessages();
	
	If CheckPeriodOnClosingDates() Then
		
		TemplateMessage = MessagesToUserClientServer.GetAccountingPolicyEffectiveDateErrorText();
		
		CommonClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(TemplateMessage, Format(Period, "DLF=DD")),
		,
		"Period",
		,
		Cancel);
		Return;
		
	EndIf;
	
	If TypeOf(FormOwner) = Type("ClientApplicationForm")
		And FormOwner.FormName = "CommonForm.CompanyInformationFillingWizard"
		And DriveClientServer.YesNoToBoolean(FormOwner.IsNewCompany)
		And CheckFilling() Then
		
		Cancel = True;
		Notify("Write_AccountingPolicy", PutDataToTempStorage(FormOwner.UUID), Undefined);
		Modified = False;
		Close();
		
	EndIf;
	
	If Not Cancel Then
		CheckFillingTypesOfAccountingTable(Cancel);
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// New parameters
	Record.PostAdvancePaymentsBySourceDocuments = PostAdvancePaymentsBySourceDocuments;
	Record.PostVATEntriesBySourceDocuments = PostVATEntriesBySourceDocuments;
	
	FillSpecifiedPropertyValues(Record);
	
	// Matching
	CompanyWasChanged	= CurrentObject.Company <> Record.Company;
	PeriodWasChanged	= CurrentObject.Period <> Record.Period;
	UseGoodsReturnFromCustomerWasChanged	= CurrentObject.UseGoodsReturnFromCustomer <> Record.UseGoodsReturnFromCustomer;
	UseGoodsReturnToSupplierWasChanged		= CurrentObject.UseGoodsReturnToSupplier <> Record.UseGoodsReturnToSupplier;
	InventoryValuationMethodWasChanged		= CurrentObject.InventoryValuationMethod <> Record.InventoryValuationMethod;
	StockTransactionsMethodologyWasChanged	= CurrentObject.StockTransactionsMethodology <> Record.StockTransactionsMethodology;
	PostExpensesByWorkOrderWasChanged		= CurrentObject.PostExpensesByWorkOrder <> Record.PostExpensesByWorkOrder;
	RegisterDeliveryDateWasChanged			= CurrentObject.RegisterDeliveryDateInInvoices <> Record.RegisterDeliveryDateInInvoices;
	InventoryDispatchingStrategyWasChanged	= CurrentObject.InventoryDispatchingStrategy <> Record.InventoryDispatchingStrategy;
	
	// Check
	If CompanyWasChanged
		Or PeriodWasChanged
		Or UseGoodsReturnFromCustomerWasChanged
		Or UseGoodsReturnToSupplierWasChanged 
		Or StockTransactionsMethodologyWasChanged
		Or InventoryValuationMethodWasChanged 
		Or PostExpensesByWorkOrderWasChanged 
		Or RegisterDeliveryDateWasChanged
		Or InventoryDispatchingStrategyWasChanged Then
		
		Companies = New Array;
		Companies.Add(Record.Company);
		
		If Record.SourceRecordKey.IsEmpty() Then
			MinPeriod = Record.Period;
		Else
			MinPeriod = Min(CurrentObject.Period, Record.Period);
			Companies.Add(CurrentObject.Company);
		EndIf;
		
		ParametersData = New Structure;
		ParametersData.Insert("Companies", Companies);
		ParametersData.Insert("Period", MinPeriod);
		
		If InformationRegisters.AccountingPolicy.ModifyDeleteIsAllowed(ParametersData) Then
			
			FillSpecifiedPropertyValues(CurrentObject, Record);
			
		Else
			
			CommonClientServer.MessageToUser(
				MessagesToUserClientServer.GetAccountingPolicyDocumentsExistErrorText()
				,,,,
				Cancel);
			
			FillSpecifiedPropertyValues(Record, CurrentObject);
			
		EndIf;
		
	EndIf;
	
	If Not Cancel Then // Duplicated rows could exist, so, no need to other checks.
		
		CheckTypesOfAccountingDuplicates(Cancel);
		
	EndIf;
	
	If Not Cancel Then // Periods could be incorrect, so no need to save data to information register.
		
		CheckStartDateTypesOfAccounting(Cancel);
		CheckEndDateTypesOfAccounting(Cancel);
		CheckEntriesPostingOptionTypesOfAccounting(Cancel);
		CheckAddedTypesOfAccounting(Cancel);
		
	EndIf;
	
	If Not Cancel Then
		
		TypesOfAccountingArray = New Array;
		InformationRegisters.CompaniesTypesOfAccounting.SaveTypesOfAccountingTable(
			TypesOfAccounting.Unload(),
			Company,
			Period,
			Record.SourceRecordKey.Period,
			TypesOfAccountingToDelete,
			TypesOfAccountingArray,
			Cancel);
			
		MessageTemplate = MessagesToUserClientServer.GetAccountingPolicyAlredyAppliedTemplateErrorText();
		FieldTemplate = "TypesOfAccounting[%1].TypeOfAccounting";
		
		For Each TypesOfAccountingStructure In TypesOfAccountingArray Do
			
			CurrentData = TypesOfAccounting.FindRows(
				New Structure("TypeOfAccounting", TypesOfAccountingStructure.TypeOfAccounting));
			
			CommonClientServer.MessageToUser(
				StringFunctionsClientServer.SubstituteParametersToString(
					MessageTemplate,
					TypesOfAccountingStructure.TypeOfAccounting,
					Format(TypesOfAccountingStructure.StartDate, "DLF=D"),
					Format(TypesOfAccountingStructure.EndDate, "DLF=D; DE=...")),
					,
					StringFunctionsClientServer.SubstituteParametersToString(FieldTemplate, 
						TypesOfAccounting.IndexOf(CurrentData[0])));
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	IsNewRecord = Record.SourceRecordKey.IsEmpty();
	
	If RegisteredForVAT <> Record.RegisteredForVAT 
		Or PostVATEntriesBySourceDocuments <> Record.PostVATEntriesBySourceDocuments
		Or UseGoodsReturnFromCustomer <> Record.UseGoodsReturnFromCustomer
		Or UseGoodsReturnToSupplier <> Record.UseGoodsReturnToSupplier Then
		
		RefreshInterface();
		
		Notify("Write_AccountingPolicy", Undefined, Undefined);
		
	EndIf;
	
	If UseTemplateBasedTypesOfAccounting() Then
		
		LoadTypesOfAccountingTable(Company, Period);
		TypesOfAccountingWithoutSourceDocs = FindAccountingSourceDocuments(Period, Company);
			
		For Each Row In TypesOfAccounting Do
			
			If TypesOfAccountingWithoutSourceDocs.Find(Row.TypeOfAccounting) = Undefined Then
				Continue;
			EndIf;
			
			TypesOfAccountingArray = New Array();
			TypesOfAccountingArray.Add(Row.TypeOfAccounting);
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("TypesOfAccounting"	, TypesOfAccountingArray);
			AdditionalParameters.Insert("Period"			, Row.StartDate);
			AdditionalParameters.Insert("Company"			, Company);
			
			WorkWithArbitraryParametersClient.InputAccountingSourceDocuments(AdditionalParameters);
			
		EndDo;
		
	EndIf;
	
	TypesOfAccountingModified = False;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	OnCloseAtServer();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PeriodOnChange(Item)
	
	ClearMessages();
	
	If PeriodPrevious <> Period And TypesOfAccountingModified Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ParameterOnChange"	, "Period");
		AdditionalParameters.Insert("MethodToContinue"	, "PeriodOnChangeEnding");
		
		Notification = New NotifyDescription("OnChangeEnding", ThisObject, AdditionalParameters);
		
		PeriodPresentation = NStr("en = 'Effective date'; ru = 'От';pl = 'Data wejścia w życie';es_ES = 'Fecha efectiva';es_CO = 'Fecha efectiva';tr = 'Yürürlük tarihi';it = 'Data effettiva';de = 'Stichtag'");
		
		MessageTemplate = MessagesToUserClientServer.GetAccountingPolicyDataChangedQuestion();
		MessageText 	= StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, PeriodPresentation);
		
		ShowQueryBox(Notification, MessageText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
		
		Return;
		
	EndIf;
	
	PeriodOnChangeEnding();
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	ClearMessages();
	
	If CompanyPrevious <> Company And TypesOfAccountingModified Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ParameterOnChange"	, "Company");
		AdditionalParameters.Insert("MethodToContinue"	, "CompanyOnChangeEnding");
		
		Notification = New NotifyDescription("OnChangeEnding", ThisObject, AdditionalParameters);
		
		MessageTemplate = MessagesToUserClientServer.GetAccountingPolicyDataChangedQuestion();
		MessageText 	= StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, "Company");
		
		ShowQueryBox(Notification, MessageText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
		
		Return;
		
	EndIf;
	
	CompanyOnChangeEnding();
	
EndProcedure

&AtClient
Procedure RegisteredForVATOnChange(Item)
	
	ChangeRegisteredForVATAtServer();
	
	EnabledSalesTaxAndVAT();
	
	If Record.RegisteredForVAT
		And Not UseVAT Then
		RefreshInterface();
	EndIf;
	
EndProcedure

&AtClient
Procedure PostVATEntriesBySourceDocumentsOnChange(Item)
	PostVATEntriesBySourceDocumentsAtServer();
	SetIssueAutomaticallyAgainstSales();
EndProcedure

&AtClient
Procedure PostAdvancePaymentsBySourceDocumentsOnChange(Item)
	PostAdvancePaymentsBySourceDocumentsAtServer();
EndProcedure

&AtClient
Procedure RegisteredForSalesTaxOnChange(Item)
	
	EnabledSalesTaxAndVAT();
	
EndProcedure

&AtClient
Procedure RegisterDeliveryDateInInvoicesOnChange(Item) 
	
	If Record.RegisterDeliveryDateInInvoices Then
		TextMessage = MessagesToUserClientServer.GetAccountingPolicySalesInvoiceWarningText();
		ShowMessageBox(Undefined, TextMessage);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function CheckPeriodOnClosingDates(Date = Undefined) 
	
	If Date = Undefined Then
		Date = Period;
	EndIf;
	
	Return InformationRegisters.AccountingPolicy.CheckPeriodOnClosingDates(Company, Date)
	
EndFunction

&AtServer
Function FillConditionalAppearance()
	
	PrestationTemplate = MessagesToUserClientServer.GetAccountingPolicyItemPresentationText();
	
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.Use = True;
	ConditionalAppearanceItem.Presentation = StringFunctionsClientServer.SubstituteParametersToString(PrestationTemplate, "");
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("TypesOfAccounting.LockedRow"); 
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = True;
	FilterItem.Use = True;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("ReadOnly", True);
	
	FieldItem = ConditionalAppearanceItem.Fields.Items.Add();
	FieldItem.Field = New DataCompositionField("TypesOfAccountingChartOfAccounts");
	FieldItem.Use = True;
	
	FieldItem = ConditionalAppearanceItem.Fields.Items.Add();
	FieldItem.Field = New DataCompositionField("TypesOfAccountingChartOfAccountsTypeOfEntries");
	FieldItem.Use = True;
	
	FieldItem = ConditionalAppearanceItem.Fields.Items.Add();
	FieldItem.Field = New DataCompositionField("TypesOfAccountingTypeOfAccounting");
	FieldItem.Use = True;
	
	FieldItem = ConditionalAppearanceItem.Fields.Items.Add();
	FieldItem.Field = New DataCompositionField("TypesOfAccountingPeriod");
	FieldItem.Use = True;
	
	PrestationTemplate = MessagesToUserClientServer.GetAccountingPolicyItemPresentationText();
	
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.Use			= True;
	ConditionalAppearanceItem.Presentation	= StringFunctionsClientServer.SubstituteParametersToString(PrestationTemplate, NStr("en = 'of Inactive'; ru = 'неактивных';pl = 'Bezczynnej';es_ES = 'de Inactivo';es_CO = 'de Inactivo';tr = 'inaktif';it = 'di Inattivo';de = 'von Inaktiv'"));
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue		= New DataCompositionField("TypesOfAccounting.Inactive");
	FilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	FilterItem.RightValue		= True;
	FilterItem.Use				= True;
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue		= New DataCompositionField("TypesOfAccounting.EndDate");
	FilterItem.ComparisonType	= DataCompositionComparisonType.NotEqual;
	FilterItem.RightValue		= New DataCompositionField("TypesOfAccounting.PeriodForEndDates");
	FilterItem.Use				= True;
	
	FieldItem = ConditionalAppearanceItem.Fields.Items.Add();
	FieldItem.Field	= New DataCompositionField("TypesOfAccountingInactive");
	FieldItem.Use	= True;
	ConditionalAppearanceItem.Appearance.SetParameterValue("ReadOnly", True);
	
EndFunction

&AtServer
Function PutDataToTempStorage(OwnerFormUUID)
	
	RecordSet = InformationRegisters.AccountingPolicy.CreateRecordSet();
	FillPropertiesByGeneralFormAttributes(Record);
	FillPropertyValues(RecordSet.Add(), Record);
	
	Return PutToTempStorage(RecordSet.Unload(), OwnerFormUUID);
	
EndFunction

&AtServer
Procedure SetIssueAutomaticallyAgainstSales()
	
	Items.IssueAutomaticallyAgainstSales.Enabled = Not PostVATEntriesBySourceDocuments;
	
	If PostVATEntriesBySourceDocuments
		And AccessRight("Update", Metadata.InformationRegisters.AccountingPolicy) Then
		Record.IssueAutomaticallyAgainstSales = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure ChangeRegisteredForVATAtServer()
	
	Option = New Structure("Name, Synonym",
		"RegisteredForVAT",
		Metadata.InformationRegisters.AccountingPolicy.Resources.RegisteredForVAT.Synonym);
		
	CheckCompanyVATNumber(Option);
	
	If Not UseVAT Then
		Constants.FunctionalOptionUseVAT.Set(Record.RegisteredForVAT);
	EndIf;
	
	CheckVATRecords(Option);
	
	If Not Record.RegisteredForVAT Then
		Record.IssueAutomaticallyAgainstSales = False;
		Record.PostAdvancePaymentsBySourceDocuments = True;
		Record.PostVATEntriesBySourceDocuments = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure PostVATEntriesBySourceDocumentsAtServer()
	
	Record.PostVATEntriesBySourceDocuments = PostVATEntriesBySourceDocuments;
	
	Option = New Structure("Name, Synonym",
		"PostVATEntriesBySourceDocuments",
		Metadata.InformationRegisters.AccountingPolicy.Resources.PostVATEntriesBySourceDocuments.Synonym);
		
	CheckVATRecords(Option);
	
	PostVATEntriesBySourceDocuments = Record.PostVATEntriesBySourceDocuments;
	
EndProcedure

&AtServer
Procedure CheckCompanyVATNumber(Option)
	
	If Record.RegisteredForVAT
		And Not VATNumberIsFilled Then
		
		VATNumber = Catalogs.Companies.FindDefaultVATNumber(Company, Company.VATNumbers);
		If IsBlankString(VATNumber) Then
			
			Record.RegisteredForVAT = False;
			
			TextMessage = MessagesToUserClientServer.GetAccountingPolicyVATNumberErrorText();
			CommonClientServer.MessageToUser(TextMessage);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CheckVATRecords(Option)
	
	Query = New Query(
	"SELECT
	|	&MaxDate AS AfterDate,
	|	&Period AS BeforeDate,
	|	&Company AS Company
	|INTO CurrentPolicy
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	MIN(Policy.Period) AS AfterDate,
	|	&MaxDate AS BeforeDate,
	|	Policy.Company AS Company
	|INTO VATPeriod
	|FROM
	|	InformationRegister.AccountingPolicy AS Policy
	|WHERE
	|	Policy.Period > &Period
	|	AND Policy.Company = &Company
	|	AND TRUE
	|
	|GROUP BY
	|	Policy.Company
	|
	|UNION ALL
	|
	|SELECT
	|	&MinDate,
	|	MAX(Policy.Period),
	|	Policy.Company
	|FROM
	|	InformationRegister.AccountingPolicy AS Policy
	|WHERE
	|	Policy.Period < &Period
	|	AND Policy.Company = &Company
	|	AND TRUE
	|
	|GROUP BY
	|	Policy.Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(ISNULL(Boundary.AfterDate, CurrentPolicy.AfterDate)) AS End,
	|	MAX(ISNULL(Boundary.BeforeDate, CurrentPolicy.BeforeDate)) AS Start,
	|	CurrentPolicy.Company AS Company
	|INTO Boundary
	|FROM
	|	CurrentPolicy AS CurrentPolicy
	|		LEFT JOIN VATPeriod AS Boundary
	|		ON (TRUE)
	|
	|GROUP BY
	|	CurrentPolicy.Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	1
	|FROM
	|	AccumulationRegister.VATIncurred AS VATIncurred
	|		INNER JOIN Boundary AS Boundary
	|		ON VATIncurred.Company = Boundary.Company
	|			AND VATIncurred.Period >= Boundary.Start
	|			AND VATIncurred.Period <= Boundary.End
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	1
	|FROM
	|	AccumulationRegister.VATInput AS VATInput
	|		INNER JOIN Boundary AS Boundary
	|		ON VATInput.Company = Boundary.Company
	|			AND VATInput.Period >= Boundary.Start
	|			AND VATInput.Period <= Boundary.End
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	1
	|FROM
	|	AccumulationRegister.VATOutput AS VATOutput
	|		INNER JOIN Boundary AS Boundary
	|		ON VATOutput.Company = Boundary.Company
	|			AND VATOutput.Period >= Boundary.Start
	|			AND VATOutput.Period <= Boundary.End");
	
	Query.Text = StrReplace(Query.Text, "AND TRUE", "AND Policy." + Option.Name);
	
	Query.SetParameter("MinDate", Date("00010101"));
	Query.SetParameter("MaxDate", Date("39991231"));
	Query.SetParameter("Period", Record.Period);
	Query.SetParameter("Company", Record.Company);
	
	If Query.Execute().IsEmpty() Then
		Modified = True;
	Else
		
		TextMessage = StringFunctionsClientServer.SubstituteParametersToString(
			MessagesToUserClientServer.GetAccountingPolicyVATOptionTemplateErrorText(),
			Option.Synonym);
			
		CommonClientServer.MessageToUser(TextMessage);
			
		// Return the previous value
		Record[Option.Name] = Not Record[Option.Name];
		
	EndIf;

EndProcedure

&AtServer
Procedure PostAdvancePaymentsBySourceDocumentsAtServer()
	
	Record.PostAdvancePaymentsBySourceDocuments = PostAdvancePaymentsBySourceDocuments;
	
	Option = New Structure("Name, Synonym",
		"PostAdvancePaymentsBySourceDocuments",
		Metadata.InformationRegisters.AccountingPolicy.Resources.PostAdvancePaymentsBySourceDocuments.Synonym);
		
	CheckVATRecords(Option);
	
	PostAdvancePaymentsBySourceDocuments = Record.PostAdvancePaymentsBySourceDocuments;
	
EndProcedure

&AtServer
Procedure FillSpecifiedPropertyValues(Receiver = Undefined, Source = Undefined)
	
	If Receiver = Undefined And Source = Undefined Then
		Return;
	ElsIf Receiver = Undefined Then
		FillGeneralFormAttributesByProperties(Source);
	ElsIf Source = Undefined Then
		FillPropertiesByGeneralFormAttributes(Receiver);
	Else
		FillPropertyValues(Receiver, Source);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillGeneralFormAttributesByProperties(Source)
	
	Period = Source.Period;
	Company = Source.Company;
		
	UseGoodsReturnFromCustomer = ?(Source.UseGoodsReturnFromCustomer, Enums.YesNo.Yes, Enums.YesNo.No);
	UseGoodsReturnToSupplier = ?(Source.UseGoodsReturnToSupplier, Enums.YesNo.Yes, Enums.YesNo.No);
	
	InventoryValuationMethod = Source.InventoryValuationMethod;
	
	If ValueIsFilled(Source.StockTransactionsMethodology) Then
		StockTransactionsMethodology = Source.StockTransactionsMethodology;
	Else
		StockTransactionsMethodology = Enums.StockTransactionsMethodology.AngloSaxon;
	EndIf;
	
	PostExpensesByWorkOrder = ?(Source.PostExpensesByWorkOrder, Enums.YesNo.Yes, Enums.YesNo.No);
	
	InventoryDispatchingStrategy = Source.InventoryDispatchingStrategy;
	
	InvoiceTotalDue		= (Record.InvoiceTotalDue	= Enums.UseOfOptionalPrintSections.Use);
	AccountBalance		= (Record.AccountBalance	= Enums.UseOfOptionalPrintSections.Use);
	Overdue				= (Record.Overdue			= Enums.UseOfOptionalPrintSections.Use);
	
EndProcedure

&AtServer
Procedure FillPropertiesByGeneralFormAttributes(Receiver)
	
	Receiver.Period = Period;
	Receiver.Company = Company;
		
	Receiver.UseGoodsReturnFromCustomer = (UseGoodsReturnFromCustomer = Enums.YesNo.Yes);
	Receiver.UseGoodsReturnToSupplier = (UseGoodsReturnToSupplier = Enums.YesNo.Yes);
	
	Receiver.InventoryValuationMethod = InventoryValuationMethod;
	Receiver.StockTransactionsMethodology = StockTransactionsMethodology;
	
	Receiver.PostExpensesByWorkOrder = (PostExpensesByWorkOrder = Enums.YesNo.Yes);
	
	Receiver.InventoryDispatchingStrategy = InventoryDispatchingStrategy;
	
	Receiver.InvoiceTotalDue = ?(InvoiceTotalDue, Enums.UseOfOptionalPrintSections.Use, Enums.UseOfOptionalPrintSections.DoNotUse);
	Receiver.AccountBalance	 = ?(AccountBalance, Enums.UseOfOptionalPrintSections.Use, Enums.UseOfOptionalPrintSections.DoNotUse);
	Receiver.Overdue		 = ?(Overdue, Enums.UseOfOptionalPrintSections.Use, Enums.UseOfOptionalPrintSections.DoNotUse);
	
EndProcedure

&AtServer
Procedure EnabledSalesTaxAndVAT()
	
	Items.RegisteredForVAT.Enabled = Not Record.RegisteredForSalesTax;
	Items.RegisteredForSalesTax.Enabled = Not Record.RegisteredForVAT;
	
	Items.GroupVATOptionsRight.Enabled = Record.RegisteredForVAT;
	Items.GroupDefaultVAT.Enabled = Record.RegisteredForVAT;
	
EndProcedure

#Region TypesOfAccountingTable

&AtClient
Procedure TypesOfAccountingInactiveOnChange(Item)
	
	CurrentData = Items.TypesOfAccounting.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.Inactive And CurrentData.PeriodForEndDates < CurrentData.StartDate Then
		
		CurrentData.Inactive = False;
		MessageTemplate = MessagesToUserClientServer.GetAccountingPolicyApliedSamePolicyTemplateErrorText();
		FieldTemplate = "TypesOfAccounting[%1].Inactive";
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, CurrentData.TypeOfAccounting);
		FieldText	= StringFunctionsClientServer.SubstituteParametersToString(FieldTemplate, TypesOfAccounting.IndexOf(CurrentData));
		CommonClientServer.MessageToUser(MessageText, ,FieldText);
		
	ElsIf CurrentData.Inactive Then
		
		CurrentData.EndDate = CurrentData.PeriodForEndDates;
		
	ElsIf CurrentData.EndDate = CurrentData.PeriodForEndDates Then
		
		CurrentData.EndDate = Undefined;
		
		CurrentData.EntriesPostingOptionBeforeEditing = GetEntriesPostingOptionBeforeEditing(
			CurrentData.PeriodForEndDates,
			Company,
			CurrentData.TypeOfAccounting,
			CurrentData.StartDate);
		
	Else
		
		CurrentData.Inactive = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TypesOfAccountingBeforeDeleteRow(Item, Cancel)
	
	CurrentData = Item.CurrentData;
	
	If Not CurrentData.LockedRow Then
		Return;
	EndIf;
	
	If CheckTypeOfAccountingForEntries(Company, CurrentData.TypeOfAccounting) Then
		
		Cancel = True;
		
		TemplateError	= MessagesToUserClientServer.GetAccountingPolicyTypeOfAccountngDeleteErrorText();
		TextMessage		= StringFunctionsClientServer.SubstituteParametersToString(TemplateError, CurrentData.TypeOfAccounting);
		ShowMessageBox(Undefined, TextMessage);
		
		Return;
		
	ElsIf CurrentData.StartDate <> Period Then
		
		TemplateError	= MessagesToUserClientServer.GetAccountingPolicyPeroidDeleteErrorText();
		TextMessage		= StringFunctionsClientServer.SubstituteParametersToString(TemplateError, CurrentData.StartDate);
		ShowMessageBox(Undefined, TextMessage);
		
		Cancel = True;
		Return;
		
	ElsIf CurrentData.StartDate = Period Then
		
		NewRow = TypesOfAccountingToDelete.Add();
		FillPropertyValues(NewRow, CurrentData);
		
		NewRow.StartDate = PeriodInitial;
		
	EndIf;
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure TypesOfAccountingOnStartEdit(Item, NewRow, Clone)
	
	If NewRow Then
		
		CurrentData = Item.CurrentData;
		
		CurrentData.Inactive			= False;
		CurrentData.LockedRow			= False;
		CurrentData.StartDate			= Period;
		CurrentData.PeriodForEndDates	= Period - 86400;
		
	EndIf;
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure TypesOfAccountingOnEditEnd(Item, NewRow, CancelEdit)
	TypesOfAccounting.Sort("StartDate, EndDate, TypeOfAccountingDescription");
EndProcedure

&AtClient
Procedure TypesOfAccountingOnChange(Item)
	TypesOfAccountingModified = True;
EndProcedure

&AtServer
Function TypesOfAccountingTypeOfAccountingOnChangeAtServer(TypeOfAccounting)
	Return TypeOfAccounting.Description;
EndFunction

&AtClient
Procedure TypesOfAccountingTypeOfAccountingOnChange(Item)
	
	CurrentData = Items.TypesOfAccounting.CurrentData;
	CurrentData.TypeOfAccountingDescription = TypesOfAccountingTypeOfAccountingOnChangeAtServer(CurrentData.TypeOfAccounting);
	
EndProcedure

&AtClient
Procedure SetRestrictionsForTypesOfAccounting()

	Items.PageTypesOfAccounting.Visible = UseTemplateBasedTypesOfAccounting();
	
EndProcedure

&AtClient
Procedure CheckFillingTypesOfAccountingTable(Cancel)
	
	For Each Row In TypesOfAccounting Do
		
		RowIndex = TypesOfAccounting.IndexOf(Row);
		
		CheckFillingTypesOfAccountingRow(Row, RowIndex, "ChartOfAccounts"		, NStr("en = 'Chart of accounts'; ru = 'План счетов';pl = 'Plan kont';es_ES = 'Diagrama primario de las cuentas';es_CO = 'Diagrama primario de las cuentas';tr = 'Hesap planı';it = 'Piano dei conti';de = 'Kontenplan'")		, Cancel);
		CheckFillingTypesOfAccountingRow(Row, RowIndex, "EntriesPostingOption"	, NStr("en = 'Entries posting option'; ru = 'Вариант формирования проводок';pl = 'Opcja zatwierdzenia wpisów';es_ES = 'Variante de contabilización de entradas de diario';es_CO = 'Variante de contabilización de entradas de diario';tr = 'Giriş kaydetme seçeneği';it = 'Opzione di pubblicazione delle voci';de = 'Buchungsoption'")	, Cancel);
		CheckFillingTypesOfAccountingRow(Row, RowIndex, "TypeOfAccounting"		, NStr("en = 'Type of accounting'; ru = 'Тип бухгалтерского учета';pl = 'Typ rachunkowości';es_ES = 'Tipo de contabilidad';es_CO = 'Tipo de contabilidad';tr = 'Muhasebe türü';it = 'Tipo di contabilità';de = 'Typ der Buchhaltung'")		, Cancel);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure CheckFillingTypesOfAccountingRow(Row, RowIndex, FieldName, FieldSinonym, Cancel)
	
	If Not ValueIsFilled(Row[FieldName]) Then
		
		TemplateError	 = MessagesToUserClientServer.GetAccountingPolicyFieldIsRequierdErrorText();
		ErrMessage		 = StringFunctionsClientServer.SubstituteParametersToString(TemplateError, FieldSinonym, RowIndex + 1);
		MessageFieldName = StringFunctionsClientServer.SubstituteParametersToString("TypesOfAccounting[%1].%2",
			RowIndex,
			FieldName);
		
		CommonClientServer.MessageToUser(ErrMessage, , MessageFieldName, , Cancel);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CheckStartDateTypesOfAccounting(Cancel)
	
	FormatString = StringFunctionsClientServer.SubstituteParametersToString("DLF=DD; DE='%1'", NStr("en = 'Empty date'; ru = 'Пустая дата';pl = 'Pusta data';es_ES = 'Fecha vacía';es_CO = 'Fecha vacía';tr = 'Boş tarih';it = 'Data vuota';de = 'Leeres Datum'"));
	
	For Each Row In TypesOfAccounting Do
		
		CurrentPeriod	= Row.StartDate;
		PreviousPeriod	= ?(ValueIsFilled(Row.StartDateBeforeEditing), Row.StartDateBeforeEditing, Row.StartDate);
		
		If CurrentPeriod <> Period Or CurrentPeriod = PreviousPeriod Then
			Continue;
		EndIf;
		
		CurrentPeriodIsProhibitedPeriod = CheckPeriodOnClosingDates(CurrentPeriod);
		RowIndex = TypesOfAccounting.IndexOf(Row);
		
		If CurrentPeriod > PreviousPeriod
			And Not CurrentPeriodIsProhibitedPeriod
			And CheckTypeOfAccountingForEntries(Company, Row.TypeOfAccounting, PreviousPeriod, CurrentPeriod) Then
			
			TemplateError = MessagesToUserClientServer.GetAccountingPolicyAlredyRecordedAccountingErrorText();
			
			TextMessage = StringFunctionsClientServer.SubstituteParametersToString(TemplateError,
				Row.TypeOfAccounting,
				Format(PreviousPeriod	, FormatString),
				Format(CurrentPeriod	, FormatString),
				Format(Min(PreviousPeriod, CurrentPeriod)	, FormatString),
				Format(Max(PreviousPeriod, CurrentPeriod)	, FormatString),
				NStr("en = 'Start date'; ru = 'Дата начала';pl = 'Data rozpoczęcia';es_ES = 'Fecha de inicio';es_CO = 'Fecha de inicio';tr = 'Başlangıç tarihi';it = 'Data di avvio';de = 'Startdatum'"));
			
			MessageFieldName = StringFunctionsClientServer.SubstituteParametersToString("TypesOfAccounting[%1].StartDate", RowIndex);
			
			CommonClientServer.MessageToUser(TextMessage, , MessageFieldName, , Cancel);
			
		ElsIf CurrentPeriod < PreviousPeriod
			And Not CurrentPeriodIsProhibitedPeriod 
			And CheckTypeOfAccountingForPostedDocuments(Company, Row.ChartOfAccounts, CurrentPeriod, PreviousPeriod) Then
			
			TemplateError = MessagesToUserClientServer.GetAccountingPolicyAlredyPostedDocumentsErrorText();
			TextMessage = StringFunctionsClientServer.SubstituteParametersToString(TemplateError,
				Row.TypeOfAccounting,
				Format(PreviousPeriod	, FormatString),
				Format(CurrentPeriod	, FormatString),
				Format(Min(PreviousPeriod, CurrentPeriod)	, FormatString),
				Format(Max(PreviousPeriod, CurrentPeriod)	, FormatString),
				NStr("en = 'Start date'; ru = 'Дата начала';pl = 'Data rozpoczęcia';es_ES = 'Fecha de inicio';es_CO = 'Fecha de inicio';tr = 'Başlangıç tarihi';it = 'Data di avvio';de = 'Startdatum'"));
			
			MessageFieldName = StringFunctionsClientServer.SubstituteParametersToString("TypesOfAccounting[%1].StartDate", RowIndex);
			
			CommonClientServer.MessageToUser(TextMessage, , MessageFieldName);
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure CheckEndDateTypesOfAccounting(Cancel)
	
	FormatString	= StringFunctionsClientServer.SubstituteParametersToString("DLF=DD; DE='%1'", NStr("en = 'Empty date'; ru = 'Пустая дата';pl = 'Pusta data';es_ES = 'Fecha vacía';es_CO = 'Fecha vacía';tr = 'Boş tarih';it = 'Data vuota';de = 'Leeres Datum'"));
	OneDay			= 86400;
	
	For Each Row In TypesOfAccounting Do
		
		CurrentEndDate	= ?(ValueIsFilled(Row.EndDate), Row.EndDate, Date(3999, 12, 31));
		PreviousEndDate	= ?(ValueIsFilled(Row.EndDateBeforeEditing), Row.EndDateBeforeEditing, Date(3999, 12, 31));
		
		If CurrentEndDate <> Period - OneDay Or CurrentEndDate = PreviousEndDate Then
			Continue;
		EndIf;
		
		CurrentEndDateIsProhibitedPeriod = CheckPeriodOnClosingDates(CurrentEndDate);
		RowIndex = TypesOfAccounting.IndexOf(Row);
		
		If CurrentEndDate < PreviousEndDate
			And Not CurrentEndDateIsProhibitedPeriod
			And CheckTypeOfAccountingForEntries(Company, Row.TypeOfAccounting, CurrentEndDate + OneDay, PreviousEndDate) Then
			
			If ValueIsFilled(Row.EndDateBeforeEditing) Then
				
				TemplateError = MessagesToUserClientServer.GetAccountingPolicyAlredyRecordedAccountingErrorText();
				
				TextMessage = StringFunctionsClientServer.SubstituteParametersToString(TemplateError,
					Row.TypeOfAccounting,
					Format(PreviousEndDate			, FormatString),
					Format(CurrentEndDate + OneDay	, FormatString),
					Format(Min(PreviousEndDate, CurrentEndDate + OneDay)	, FormatString),
					Format(Max(PreviousEndDate, CurrentEndDate + OneDay)	, FormatString),
					NStr("en = 'End date'; ru = 'Дата окончания';pl = 'Data zakończenia';es_ES = 'Fecha final';es_CO = 'Fecha final';tr = 'Bitiş tarihi';it = 'Data di fine';de = 'Enddatum'"));
				
			Else
				
				TemplateError = MessagesToUserClientServer.GetAccountingPolicyAlredyRecordedAccountingInOpenPeriodErrorText();
				TextMessage = StringFunctionsClientServer.SubstituteParametersToString(TemplateError,
					Row.TypeOfAccounting,
					Format(CurrentEndDate			, FormatString),
					Format(CurrentEndDate + OneDay	, FormatString),
					NStr("en = 'End date'; ru = 'Дата окончания';pl = 'Data zakończenia';es_ES = 'Fecha final';es_CO = 'Fecha final';tr = 'Bitiş tarihi';it = 'Data di fine';de = 'Enddatum'"));
				
			EndIf;
			
			MessageFieldName = StringFunctionsClientServer.SubstituteParametersToString("TypesOfAccounting[%1].EndDate", RowIndex);
			
			CommonClientServer.MessageToUser(TextMessage, , MessageFieldName, , Cancel);
			
		ElsIf CurrentEndDate > PreviousEndDate
			And Not CurrentEndDateIsProhibitedPeriod
			And CheckTypeOfAccountingForPostedDocuments(Company, Row.ChartOfAccounts, PreviousEndDate + OneDay, CurrentEndDate) Then
			
			TemplateError = MessagesToUserClientServer.GetAccountingPolicyAlredyPostedDocumentsErrorText();
			TextMessage = StringFunctionsClientServer.SubstituteParametersToString(TemplateError,
				Row.TypeOfAccounting,
				Format(CurrentEndDate + OneDay	, FormatString),
				Format(PreviousEndDate			, FormatString),
				Format(Min(PreviousEndDate, CurrentEndDate + OneDay)	, FormatString),
				Format(Max(PreviousEndDate, CurrentEndDate + OneDay)	, FormatString),
				NStr("en = 'End date'; ru = 'Дата окончания';pl = 'Data zakończenia';es_ES = 'Fecha final';es_CO = 'Fecha final';tr = 'Bitiş tarihi';it = 'Data di fine';de = 'Enddatum'"));
			
			MessageFieldName = StringFunctionsClientServer.SubstituteParametersToString("TypesOfAccounting[%1].EndDate", RowIndex);
			
			CommonClientServer.MessageToUser(TextMessage, , MessageFieldName);
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure CheckEntriesPostingOptionTypesOfAccounting(Cancel)
	
	FormatString	= StringFunctionsClientServer.SubstituteParametersToString("DLF=DD; DE='%1'", NStr("en = 'Empty date'; ru = 'Пустая дата';pl = 'Pusta data';es_ES = 'Fecha vacía';es_CO = 'Fecha vacía';tr = 'Boş tarih';it = 'Data vuota';de = 'Leeres Datum'"));
	StartDate		= Min(Period, ?(ValueIsFilled(Record.SourceRecordKey.Period), Record.SourceRecordKey.Period, Period));
	FormatStartDate = Format(StartDate, FormatString);
	
	For Each Row In TypesOfAccounting Do
		
		PreviousOption	= Row.EntriesPostingOptionBeforeEditing;
		CurrentOption	= Row.EntriesPostingOption;
		
		If Not ValueIsFilled(PreviousOption) Or CurrentOption = PreviousOption Then
			Continue;
		EndIf;
		
		If CurrentOption <> PreviousOption
			And CheckTypeOfAccountingForEntries(Company, Row.TypeOfAccounting, StartDate, Row.EndDate) Then
			
			TemplateError = MessagesToUserClientServer.GetAccountingPolicyAlredyRecordedAccountingFromDateErrorText();
			TextMessage	  = StringFunctionsClientServer.SubstituteParametersToString(TemplateError,Row.TypeOfAccounting, FormatStartDate);
			
			MessageFieldName = StringFunctionsClientServer.SubstituteParametersToString("TypesOfAccounting[%1].EntriesPostingOption", TypesOfAccounting.IndexOf(Row));
			
			CommonClientServer.MessageToUser(TextMessage, , MessageFieldName, , Cancel);
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure CheckAddedTypesOfAccounting(Cancel)
	
	FormatString = StringFunctionsClientServer.SubstituteParametersToString("DLF=DD; DE='%1'", NStr("en = 'Empty date'; ru = 'Пустая дата';pl = 'Pusta data';es_ES = 'Fecha vacía';es_CO = 'Fecha vacía';tr = 'Boş tarih';it = 'Data vuota';de = 'Leeres Datum'"));
	
	For Each Row In TypesOfAccounting Do
		
		If Row.LockedRow Then
			Continue;
		EndIf;
		
		If CheckTypeOfAccountingForPostedDocuments(Company, Row.ChartOfAccounts, Period, Row.EndDate) Then
			
			TemplateMessage = MessagesToUserClientServer.GetAccountingPolicyAlredyPostedDocumentsTemplateError(Row.EntriesPostingOption);
			
			ErrorMessage	 = StringFunctionsClientServer.SubstituteParametersToString(TemplateMessage, Format(Period, FormatString));
			MessageFieldName = StringFunctionsClientServer.SubstituteParametersToString("TypesOfAccounting[%1].TypeOfAccounting", TypesOfAccounting.IndexOf(Row));
			
			CommonClientServer.MessageToUser(ErrorMessage, , MessageFieldName);
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure LoadTypesOfAccountingTable(CompanyToFill, PeriodToFill, SaveUserChanges = False, PeriodModified = False)
	
	If Not UseTemplateBasedTypesOfAccounting() Then
		Return;
	EndIf;
	
	RecordSourceRecordKeyPeriod = Record.SourceRecordKey.Period;
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	CompaniesTypesOfAccountingSliceLast.TypeOfAccounting AS TypeOfAccounting,
	|	CompaniesTypesOfAccountingSliceLast.StartDate AS StartDate,
	|	CompaniesTypesOfAccountingSliceLast.ChartOfAccounts AS ChartOfAccounts,
	|	CompaniesTypesOfAccountingSliceLast.EntriesPostingOption AS EntriesPostingOption,
	|	CompaniesTypesOfAccountingSliceLast.Inactive AS Inactive,
	|	CompaniesTypesOfAccountingSliceLast.EndDate AS EndDate
	|INTO TypesOfAccountingForCurrentPeriod
	|FROM
	|	InformationRegister.CompaniesTypesOfAccounting.SliceLast(
	|			&Period,
	|			Company = &Company
	|				AND StartDate <= &Period) AS CompaniesTypesOfAccountingSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CompaniesTypesOfAccounting.TypeOfAccounting AS TypeOfAccounting,
	|	CompaniesTypesOfAccounting.StartDate AS StartDate,
	|	CompaniesTypesOfAccounting.ChartOfAccounts AS ChartOfAccounts,
	|	CompaniesTypesOfAccounting.EntriesPostingOption AS EntriesPostingOption,
	|	CompaniesTypesOfAccounting.Inactive AS Inactive,
	|	CompaniesTypesOfAccounting.EndDate AS EndDate
	|INTO TypesOfAccountingForSavedPeriod
	|FROM
	|	InformationRegister.CompaniesTypesOfAccounting AS CompaniesTypesOfAccounting
	|WHERE
	|	CompaniesTypesOfAccounting.Period = &SavedPeriod
	|	AND CompaniesTypesOfAccounting.Company = &Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ISNULL(TypesOfAccountingForCurrentPeriod.TypeOfAccounting, TypesOfAccountingForSavedPeriod.TypeOfAccounting) AS TypeOfAccounting,
	|	ISNULL(TypesOfAccountingForCurrentPeriod.StartDate, TypesOfAccountingForSavedPeriod.StartDate) AS StartDate,
	|	CASE
	|		WHEN TypesOfAccountingForSavedPeriod.ChartOfAccounts IS NULL
	|			THEN TypesOfAccountingForCurrentPeriod.ChartOfAccounts
	|		ELSE TypesOfAccountingForSavedPeriod.ChartOfAccounts
	|	END AS ChartOfAccounts,
	|	CASE
	|		WHEN TypesOfAccountingForSavedPeriod.EntriesPostingOption IS NULL
	|			THEN TypesOfAccountingForCurrentPeriod.EntriesPostingOption
	|		ELSE TypesOfAccountingForSavedPeriod.EntriesPostingOption
	|	END AS EntriesPostingOption,
	|	CASE
	|		WHEN TypesOfAccountingForSavedPeriod.Inactive IS NULL
	|			THEN TypesOfAccountingForCurrentPeriod.Inactive
	|		ELSE TypesOfAccountingForSavedPeriod.Inactive
	|	END AS Inactive,
	|	CASE
	|		WHEN TypesOfAccountingForSavedPeriod.EndDate IS NULL
	|			THEN TypesOfAccountingForCurrentPeriod.EndDate
	|		ELSE TypesOfAccountingForSavedPeriod.EndDate
	|	END AS EndDate
	|INTO UpdatedTypesOfAccounting
	|FROM
	|	TypesOfAccountingForCurrentPeriod AS TypesOfAccountingForCurrentPeriod
	|		FULL JOIN TypesOfAccountingForSavedPeriod AS TypesOfAccountingForSavedPeriod
	|		ON TypesOfAccountingForCurrentPeriod.TypeOfAccounting = TypesOfAccountingForSavedPeriod.TypeOfAccounting
	|			AND TypesOfAccountingForCurrentPeriod.StartDate = TypesOfAccountingForSavedPeriod.StartDate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	UpdatedTypesOfAccounting.StartDate AS StartDateBeforeEditing,
	|	UpdatedTypesOfAccounting.StartDate AS StartDate,
	|	CompaniesTypesOfAccountingSliceLast.Inactive AS Inactive,
	|	TRUE AS LockedRow,
	|	CompaniesTypesOfAccountingSliceLast.EndDate AS EndDate,
	|	CompaniesTypesOfAccountingSliceLast.EndDate AS EndDateBeforeEditing,
	|	UpdatedTypesOfAccounting.TypeOfAccounting AS TypeOfAccounting,
	|	UpdatedTypesOfAccounting.ChartOfAccounts AS ChartOfAccounts,
	|	UpdatedTypesOfAccounting.EntriesPostingOption AS EntriesPostingOption,
	|	UpdatedTypesOfAccounting.EntriesPostingOption AS EntriesPostingOptionBeforeEditing,
	|	TypesOfAccounting.Description AS TypeOfAccountingDescription
	|FROM
	|	UpdatedTypesOfAccounting AS UpdatedTypesOfAccounting
	|		INNER JOIN Catalog.TypesOfAccounting AS TypesOfAccounting
	|		ON UpdatedTypesOfAccounting.TypeOfAccounting = TypesOfAccounting.Ref
	|		LEFT JOIN InformationRegister.CompaniesTypesOfAccounting.SliceLast(
	|				,
	|				Company = &Company
	|					AND (StartDate <= &Period
	|						OR StartDate = &SavedPeriod)) AS CompaniesTypesOfAccountingSliceLast
	|		ON UpdatedTypesOfAccounting.TypeOfAccounting = CompaniesTypesOfAccountingSliceLast.TypeOfAccounting
	|			AND UpdatedTypesOfAccounting.StartDate = CompaniesTypesOfAccountingSliceLast.StartDate
	|WHERE
	|	(NOT CompaniesTypesOfAccountingSliceLast.Inactive
	|			OR CompaniesTypesOfAccountingSliceLast.EndDate > &EndPeriod
	|			OR CompaniesTypesOfAccountingSliceLast.EndDate = &SavedEndPeriod)";
	
	SavedEndPeriod	= RecordSourceRecordKeyPeriod;
	QueryEndPeriod	= PeriodToFill;
	Query.SetParameter("Company"		, ?(ValueIsFilled(CompanyToFill), CompanyToFill, Company));
	Query.SetParameter("Period"			, PeriodToFill);
	Query.SetParameter("SavedPeriod"	, RecordSourceRecordKeyPeriod);
	Query.SetParameter("EndPeriod"		, QueryEndPeriod - 86400);
	Query.SetParameter("SavedEndPeriod"	, SavedEndPeriod - 86400);
	
	QueryResult = Query.Execute();
	
	RowsToRemain = New ValueTable;
	If SaveUserChanges Then
		
		RowsToRemain	= TypesOfAccounting.Unload(New Structure("EndDate"		, PeriodPrevious - 86400));
		AddedRows		= TypesOfAccounting.Unload(New Structure("StartDate"	, PeriodPrevious));
		
		For Each Row In AddedRows Do
			
			NewRow = RowsToRemain.Add();
			FillPropertyValues(NewRow, Row);
			
		EndDo;
		
	EndIf;
	
	TypesOfAccounting.Clear();
	
	Selection = QueryResult.Select();
	FilterStructure = New Structure("TypeOfAccounting, ChartOfAccounts, EntriesPostingOption");
	While Selection.Next() Do
		
		If SaveUserChanges Then
			FillPropertyValues(FilterStructure, Selection);
			FoundRows = RowsToRemain.FindRows(FilterStructure);
			If FoundRows.Count() = 0 Then
				FillPropertyValues(TypesOfAccounting.Add(), Selection);
			EndIf;
		Else
			FillPropertyValues(TypesOfAccounting.Add(), Selection);
		EndIf;
		
	EndDo;
	
	For Each Row In RowsToRemain Do
		FillPropertyValues(TypesOfAccounting.Add(), Row);
	EndDo;
	
	For Each Row In TypesOfAccounting Do
		Row.PeriodForEndDates = Period - 86400;
	EndDo;
	
	TypesOfAccounting.Sort("StartDate, EndDate, TypeOfAccountingDescription");
	
	TypesOfAccountingModified = False;
	
EndProcedure

&AtServer
Procedure RefillPeriodInTypesOfAccounting()
	
	NewPeriod	= Period;
	OldPeriod	= Record.SourceRecordKey.Period;
	OneDay		= 86400;
	EndDatePeriod = Record.SourceRecordKey.Period - OneDay;
	
	For Each Row In TypesOfAccounting Do
		
		If Not Row.LockedRow Or Row.StartDate = OldPeriod And Not IsNewRecord Then
			
			If Row.Inactive And NewPeriod > Row.EndDate Then
				Continue;
			EndIf;
			
			Row.StartDate = NewPeriod;
			
		EndIf;
		
		If Row.Inactive And Row.EndDate = EndDatePeriod Then
			
			Row.EndDate = NewPeriod - OneDay;
			
		EndIf;
		
		Row.PeriodForEndDates = NewPeriod - OneDay;
		
	EndDo;
	
	Modified = True;
	
EndProcedure

&AtServer
Procedure CheckTypesOfAccountingDuplicates(Cancel)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	TypesOfAccountingTable.TypeOfAccounting AS TypeOfAccounting
	|INTO TableTypesOfAccounting
	|FROM
	|	&TypesOfAccountingTable AS TypesOfAccountingTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableTypesOfAccounting.TypeOfAccounting AS TypeOfAccounting
	|FROM
	|	TableTypesOfAccounting AS TableTypesOfAccounting
	|
	|GROUP BY
	|	TableTypesOfAccounting.TypeOfAccounting
	|
	|HAVING
	|	COUNT(1) > 1";

	Query.SetParameter("TypesOfAccountingTable", TypesOfAccounting.Unload( ,"TypeOfAccounting"));
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		FilterRows = New Structure("TypeOfAccounting", SelectionDetailRecords.TypeOfAccounting);
		TypesAccRows = TypesOfAccounting.FindRows(FilterRows);
		
		RowIndex = TypesOfAccounting.IndexOf(TypesAccRows[TypesAccRows.Count() - 1]);

		TemplateError = MessagesToUserClientServer.GetAccountingPolicyDuplicateItems();
		ErrMessage = StringFunctionsClientServer.SubstituteParametersToString(TemplateError,SelectionDetailRecords.TypeOfAccounting);
		
		MessageFieldName = StringFunctionsClientServer.SubstituteParametersToString("TypesOfAccounting[%1].TypeOfAccounting", RowIndex);
		
		CommonClientServer.MessageToUser(ErrMessage, , MessageFieldName, , Cancel);

	EndDo;

EndProcedure

&AtServerNoContext
Function FindAccountingSourceDocuments(Period, Company)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	CompaniesTypesOfAccounting.TypeOfAccounting AS TypeOfAccounting
	|INTO TT_TypesOfAccounting
	|FROM
	|	InformationRegister.CompaniesTypesOfAccounting.SliceLast(&Period, Company = &Company) AS CompaniesTypesOfAccounting
	|WHERE
	|	NOT CompaniesTypesOfAccounting.Inactive
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_TypesOfAccounting.TypeOfAccounting AS TypeOfAccounting
	|FROM
	|	TT_TypesOfAccounting AS TT_TypesOfAccounting
	|		LEFT JOIN InformationRegister.AccountingSourceDocuments.SliceLast(&Period, Company = &Company) AS AccountingSourceDocumentsSliceLast
	|		ON TT_TypesOfAccounting.TypeOfAccounting = AccountingSourceDocumentsSliceLast.TypeOfAccounting
	|
	|GROUP BY
	|	TT_TypesOfAccounting.TypeOfAccounting
	|
	|HAVING
	|	COUNT(AccountingSourceDocumentsSliceLast.DocumentType) = 0";
	
	Query.SetParameter("Company", Company);
	Query.SetParameter("Period"	, Period);
	
	QueryResult = Query.Execute().Unload();
	Return QueryResult.UnloadColumn("TypeOfAccounting");
		
EndFunction

&AtServerNoContext
Function UseTemplateBasedTypesOfAccounting()
	
	Return Constants.AccountingModuleSettings.UseTemplatesIsEnabled();
	
EndFunction

&AtServerNoContext
Function CheckTypeOfAccountingForEntries(Company, TypeOfAccounting, StartDate = '00010101', Val EndDate = '00010101')
	
	If Not ValueIsFilled(EndDate) Then
		EndDate = Date(3999, 12, 31);
	EndIf;
	
	UsePeriodFilter = ValueIsFilled(StartDate) And ValueIsFilled(EndDate);
	
	Query = New Query;
	Query.SetParameter("Company"			, Company);
	Query.SetParameter("TypeOfAccounting"	, TypeOfAccounting);
	Query.SetParameter("StartDate"			, ?(UsePeriodFilter, BegOfDay(StartDate), StartDate));
	Query.SetParameter("EndDate"			, ?(UsePeriodFilter, EndOfDay(EndDate), EndDate));
	Query.SetParameter("UsePeriodFilter"	, UsePeriodFilter);
	
	Query.Text =
	"SELECT TOP 1
	|	AccountingJournal.Recorder AS Recorder
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS AccountingJournal
	|WHERE
	|	AccountingJournal.TypeOfAccounting = &TypeOfAccounting
	|	AND AccountingJournal.Company = &Company
	|	AND CASE
	|			WHEN &UsePeriodFilter
	|				THEN AccountingJournal.Period BETWEEN &StartDate AND &EndDate
	|			ELSE TRUE
	|		END
	|	AND AccountingJournal.Active
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	AccountingJournal.Recorder
	|FROM
	|	AccountingRegister.AccountingJournalEntriesSimple AS AccountingJournal
	|WHERE
	|	AccountingJournal.TypeOfAccounting = &TypeOfAccounting
	|	AND AccountingJournal.Company = &Company
	|	AND CASE
	|			WHEN &UsePeriodFilter
	|				THEN AccountingJournal.Period BETWEEN &StartDate AND &EndDate
	|			ELSE TRUE
	|		END
	|	AND AccountingJournal.Active
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	AccountingJournal.Recorder
	|FROM
	|	AccountingRegister.AccountingJournalEntriesCompound AS AccountingJournal
	|WHERE
	|	AccountingJournal.TypeOfAccounting = &TypeOfAccounting
	|	AND AccountingJournal.Company = &Company
	|	AND CASE
	|			WHEN &UsePeriodFilter
	|				THEN AccountingJournal.Period BETWEEN &StartDate AND &EndDate
	|			ELSE TRUE
	|		END
	|	AND AccountingJournal.Active";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

&AtServer
Function CheckTypeOfAccountingForPostedDocuments(Company, ChartOfAccounts, StartDate, Val EndDate)
	
	If EndDate = Date(1, 1, 1) Then
		EndDate = GetEndDate(StartDate, Company);
	EndIf;
	
	QueryTemplate = 
	"SELECT TOP 1
	|	DocumentTable.Ref AS Ref
	|FROM
	|	#DocumentTypeFullName# AS DocumentTable
	|WHERE
	|	DocumentTable.Date BETWEEN &StartDate AND &EndDate
	|	AND DocumentTable.Company = &Company
	|	AND DocumentTable.Posted";
	
	QueryTextArray = New Array;
	
	If ChartOfAccounts.TypeOfEntries = Enums.ChartsOfAccountsTypesOfEntries.Simple Then
		RegisterMetadata = Metadata.AccountingRegisters.AccountingJournalEntriesSimple;
	Else
		RegisterMetadata = Metadata.AccountingRegisters.AccountingJournalEntriesCompound;
	EndIf;
	
	RegisterRecorders = RegisterMetadata.StandardAttributes.Recorder.Type.Types();
	
	For Each RecorderType In RegisterRecorders Do
		
		DocumentMetadata = Metadata.FindByType(RecorderType);
		
		If DocumentMetadata = Undefined Then
			Continue;
		EndIf;
		
		DocumentFullName = DocumentMetadata.FullName();
		
		QueryTextForSourceDocument = StrReplace(QueryTemplate, "#DocumentTypeFullName#", DocumentFullName);
		QueryTextArray.Add(QueryTextForSourceDocument);
		
	EndDo;
	
	QueryText = StrConcat(QueryTextArray, DriveClientServer.GetQueryUnion());
	
	Query = New Query;
	
	Query.SetParameter("Company"	, Company);
	Query.SetParameter("StartDate"	, StartDate);
	Query.SetParameter("EndDate"	, ?(ValueIsFilled(EndDate), EndDate, CurrentSessionDate()));
	
	Query.Text = QueryText;
	
	SetPrivilegedMode(True);
	QueryResult = Query.Execute();
	SetPrivilegedMode(False);
	
	PostedDocuments = Not QueryResult.IsEmpty();
	
	Return PostedDocuments;
	
EndFunction

&AtServer
Function GetEndDate(StartDate, Company)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccountingPolicySliceFirst.Company AS Company,
	|	AccountingPolicySliceFirst.Period AS Period
	|FROM
	|	InformationRegister.AccountingPolicy.SliceFirst(&StartDate, Company = &Company) AS AccountingPolicySliceFirst";
	
	Query.SetParameter("Company"	, Company);
	Query.SetParameter("StartDate"	, StartDate + 1);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		
		EndDate = Date(3999, 12, 31);
		
	Else
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		EndDate = Selection.Period;
		
	EndIf;
	
	Return EndDate;
	
EndFunction

#EndRegion

&AtServer
Function NewPeriodExists()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AccountingPolicy.Company AS Company
	|FROM
	|	InformationRegister.AccountingPolicy AS AccountingPolicy
	|WHERE
	|	AccountingPolicy.Period = &Period
	|	AND AccountingPolicy.Company = &Company
	|	AND AccountingPolicy.Period <> &RecordPeriod";
	
	Query.SetParameter("Company"		, Company);
	Query.SetParameter("Period"			, Period);
	Query.SetParameter("RecordPeriod"	, Record.SourceRecordKey.Period);
	
	QueryResult = Query.Execute();
	
	Return Not QueryResult.IsEmpty();
	
EndFunction

&AtClient
Procedure FormManagement()
	
	Items.TypesOfAccounting.ReadOnly = IsClosedPeriod;
	
EndProcedure

&AtServer
Function GetInitialDate()
	
	If ValueIsFilled(Period) Then
		Result = Period;
	Else
		Result = BegOfDay(CurrentSessionDate());
	EndIf;
	
	If ValueIsFilled(Company) Then
		ParameterCompany = Company;
	Else
		ParameterCompany = Record.Company;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AccountingPolicy.Period AS Period
	|FROM
	|	InformationRegister.AccountingPolicy AS AccountingPolicy
	|WHERE
	|	AccountingPolicy.Company = &Company
	|	AND AccountingPolicy.Period >= &Period
	|
	|ORDER BY
	|	Period";
	
	Query.SetParameter("Company", ParameterCompany);
	Query.SetParameter("Period"	, Result);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If Result = SelectionDetailRecords.Period Then
			Result = Result + 86400;
		Else
			Break;
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

&AtClient
Procedure OnChangeEnding(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		Execute(StringFunctionsClientServer.SubstituteParametersToString("%1()", AdditionalParameters.MethodToContinue));
	Else
		ThisObject[AdditionalParameters.ParameterOnChange] = ThisObject[StringFunctionsClientServer.SubstituteParametersToString("%1Previous", AdditionalParameters.ParameterOnChange)];
	EndIf;
	
EndProcedure

&AtClient
Procedure PeriodOnChangeEnding()
	
	If NewPeriodExists() Then
		
		TemplateError = MessagesToUserClientServer.GetAccountingPolicyEffectiveDateAlredyExistsErrorText();
		ErrorMessage  = StringFunctionsClientServer.SubstituteParametersToString(TemplateError, Format(Period, "DLF=DD"));
		CommonClientServer.MessageToUser(ErrorMessage, , "Period");
		Period = PeriodPrevious;
		Return;
	EndIf;
	
	Record.Period = Period;
	
	If CheckPeriodOnClosingDates(Period) Then
		
		TemplateError = MessagesToUserClientServer.GetAccountingPolicyEffectiveDateClosedPeriodErrorText();
		TextMessage   = StringFunctionsClientServer.SubstituteParametersToString(TemplateError,Period);
		ShowMessageBox(Undefined, TextMessage);
		
	EndIf;
	
	LoadTypesOfAccountingTable(Company, Period, False);
	RefillPeriodInTypesOfAccounting();
	PeriodPrevious = Period;
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure CompanyOnChangeEnding()
	
	Period			= GetInitialDate();
	Record.Period	= Period;
	PeriodPrevious	= Period;
	CompanyPrevious	= Company;
	LoadTypesOfAccountingTable(Company, Period, False);
	
EndProcedure

&AtServerNoContext
Function GetEntriesPostingOptionBeforeEditing(Period, Company, TypeOfAccounting, StartDate)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	CompaniesTypesOfAccountingSliceLast.EntriesPostingOption AS EntriesPostingOption
	|FROM
	|	InformationRegister.CompaniesTypesOfAccounting.SliceLast(
	|			&Period,
	|			Company = &Company
	|				AND TypeOfAccounting = &TypeOfAccounting
	|				AND StartDate = &StartDate) AS CompaniesTypesOfAccountingSliceLast";
	
	Query.SetParameter("Company"			, Company);
	Query.SetParameter("Period"				, Period);
	Query.SetParameter("StartDate"			, StartDate);
	Query.SetParameter("TypeOfAccounting"	, TypeOfAccounting);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	Result = Undefined;
	While SelectionDetailRecords.Next() Do
		Result = SelectionDetailRecords.EntriesPostingOption;
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Procedure OnCloseAtServer()
	
	If Not UseVAT
		And Record.RegisteredForVAT
		And Modified Then
		Constants.FunctionalOptionUseVAT.Set(False);
	EndIf;
	
EndProcedure

#EndRegion