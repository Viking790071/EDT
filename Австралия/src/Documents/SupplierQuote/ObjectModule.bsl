#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
#Region EventsHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Totals = DriveServer.CalculateSubtotalPurchases(Inventory.Unload(), AmountIncludesVAT);
	FillPropertyValues(ThisObject, Totals);
	
	If ValueIsFilled(Counterparty)
	AND Not Counterparty.DoOperationsByContracts
	AND Not ValueIsFilled(Contract) Then
		Contract = Counterparty.ContractByDefault;
	EndIf;
	
EndProcedure

// Procedure - event handler FillingProcessor object.
//
Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.Event") Then
		FillByEvent(FillingData);
	ElsIf TypeOf(FillingData) = Type("Structure") Then
		If FillingData.Property("RequestForQuotation") Then
			FillByRequestForQuotation(FillingData);
		EndIf;
	EndIf;
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData);
	
EndProcedure

Procedure FillByEvent(FillingData)
	
	Event = FillingData.Ref;
	If FillingData.Participants.Count() > 0 AND TypeOf(FillingData.Participants[0].Contact) = Type("CatalogRef.Counterparties") Then
		Counterparty = FillingData.Participants[0].Contact;
		Contract = Counterparty.ContractByDefault;
		SupplierPriceTypes = Contract.SupplierPriceTypes;
	EndIf;
	
	DocumentCurrency = Contract.SettlementsCurrency;
		StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Date, DocumentCurrency, ?(ValueIsFilled(Company), Company, Contract.Company));
		ExchangeRate = StructureByCurrency.Rate;
		Multiplicity = StructureByCurrency.Repetition;
		ContractCurrencyExchangeRate = StructureByCurrency.Rate;
		ContractCurrencyMultiplicity = StructureByCurrency.Repetition;
	
EndProcedure

Procedure FillByRequestForQuotation(FillingData)
	
	RequestForQuotation	= FillingData.RequestForQuotation;
	DocumentAttributes	= Common.ObjectAttributesValues(
		RequestForQuotation, "Company, CompanyVATNumber, DocumentCurrency");
		
	FillPropertyValues(ThisObject, DocumentAttributes);
	
	If FillingData.Property("Supplier") Then
		Counterparty = FillingData.Supplier;
	ElsIf RequestForQuotation.Suppliers.Count() > 0 Then
		SuppliersRowTable = RequestForQuotation.Suppliers[0];
		Counterparty = SuppliersRowTable.Counterparty;
	EndIf;
	
	VATTaxation = DriveServer.CounterpartyVATTaxation(Counterparty,
		DriveServer.VATTaxation(Company, ?(ValueIsFilled(Date), Date, CurrentSessionDate())));
		
	If NOT VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		If VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			DefaultVATRate = Catalogs.VATRates.Exempt;
		Else
			DefaultVATRate = Catalogs.VATRates.ZeroRate;
		EndIf;
		
	Else
		DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(, Company);
	EndIf;
	
	For Each Row In RequestForQuotation.Products Do
		
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, Row);
		NewRow.Products = Row.Products;
		
		ProductVATRate = Common.ObjectAttributeValue(NewRow.Products, "VATRate");
		
		If VATTaxation = Enums.VATTaxationTypes.SubjectToVAT AND ValueIsFilled(ProductVATRate) Then
			NewRow.VATRate = ProductVATRate;
		Else
			NewRow.VATRate = DefaultVATRate;
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Not Counterparty.DoOperationsByContracts Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Company, Date) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
	//Cash flow projection
	Amount = Inventory.Total("Amount");
	VATAmount = Inventory.Total("VATAmount");
	
	PaymentTermsServer.CheckRequiredAttributes(ThisObject, CheckedAttributes, Cancel);
	PaymentTermsServer.CheckCorrectPaymentCalendar(ThisObject, Cancel, Amount, VATAmount);
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	DriveServer.ReflectUsingPaymentTermsInDocuments(Ref, Cancel);
	
	// Recording prices in information register Prices of counterparty products.
	Documents.SupplierQuote.RecordVendorPrices(Ref);
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	// Deleting the prices from information register Prices of counterparty products.
	DriveServer.DeleteVendorPrices(Ref);
	
EndProcedure

#EndRegion

#EndIf