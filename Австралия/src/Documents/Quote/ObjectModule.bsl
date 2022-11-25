#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
#Region EventHandlers

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	SalesTaxServer.CalculateInventorySalesTaxAmount(Inventory, SalesTax.Total("Amount"), PreferredVariant);
	Totals = PaymentTermsClientServer.CalculateDocumentAmountVATAmountTotals(ThisObject);
	
	DocumentAmount = Totals.Amount + ?(AmountIncludesVAT, 0, Totals.VATAmount);
	DocumentTax = Totals.VATAmount;
	Discount = Totals.Discount;
	DocumentSubtotal = DocumentAmount - DocumentTax + Discount;
	
	If ValueIsFilled(Counterparty) Then
		CounterpartyData = Common.ObjectAttributesValues(Counterparty, "DoOperationsByContracts, ContractByDefault");
		If Not CounterpartyData.DoOperationsByContracts And Not ValueIsFilled(Contract) Then
			Contract = Counterparty.ContractByDefault;
		EndIf;
	EndIf;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, "FillingHandler");
	
	If TypeOf(FillingData) = Type("CatalogRef.Counterparties") Then
		
		SalesRep = Common.ObjectAttributeValue(FillingData, "SalesRep");
		
		PaymentTermsServer.FillPaymentCalendarFromContract(ThisObject);
		
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// 100% discount.
	AreManualDiscounts		= GetFunctionalOption("UseManualDiscounts");
	AreAutomaticDiscounts	= GetFunctionalOption("UseAutomaticDiscounts"); // AutomaticDiscounts
	If AreManualDiscounts OR AreAutomaticDiscounts Then
		For Each StringInventory In Inventory Do
			// AutomaticDiscounts
			CurAmount = StringInventory.Price * StringInventory.Quantity;
			CurAmountManualDiscount		= ?(AreManualDiscounts, Round(CurAmount * StringInventory.DiscountMarkupPercent / 100, 2), 0);
			CurAmountAutomaticDiscount	= ?(AreAutomaticDiscounts, StringInventory.AutomaticDiscountAmount, 0);
			CurAmountDiscount			= CurAmountManualDiscount + CurAmountAutomaticDiscount;
			If StringInventory.DiscountMarkupPercent <> 100 AND CurAmountDiscount < CurAmount
				AND Not ValueIsFilled(StringInventory.Amount) Then
				MessageText = NStr("en = 'The ""Amount"" column is not populated in the %Number% line of the ""Inventory"" list.'; ru = 'Не заполнена колонка ""Сумма"" в строке %Number% списка ""Запасы"".';pl = 'Nie wypełniono kolumny ""Kwota"" w wierszu %Number% listy ""Zapasy"".';es_ES = 'La columna ""Importe"" no está poblada en la línea %Number% de la lista ""Inventario"".';es_CO = 'La columna ""Importe"" no está poblada en la línea %Number% de la lista ""Inventario"".';tr = '""Tutar"" sütunu, ""Stok"" listesinin %Number% satırında gösterilmez.';it = 'La colonna ""Importo"" non è compilata nella linea %Number% dell''elenco ""Scorte"".';de = 'Die Spalte ""Betrag"" ist nicht in der %Number% Zeile der Liste ""Bestand"" eingetragen.'");
				MessageText = StrReplace(MessageText, "%Number%", StringInventory.LineNumber);
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Inventory",
					StringInventory.LineNumber,
					"Amount",
					Cancel
				);
			EndIf;
		EndDo;
	EndIf;
	
	If Not Counterparty.DoOperationsByContracts Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Company, Date) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
	//Cash flow projection
	Totals = PaymentTermsClientServer.CalculateDocumentAmountVATAmountTotals(ThisObject);
	
	PaymentTermsServer.CheckRequiredAttributes(ThisObject, CheckedAttributes, Cancel);
	PaymentTermsServer.CheckCorrectPaymentCalendar(ThisObject, Cancel, Totals.Amount, Totals.VATAmount);
	
	// Bundles
	BundlesServer.CheckTableFilling(ThisObject, "Inventory", Cancel);
	// End Bundles
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.Quote.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);

	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);
	DriveServer.ReflectUsingPaymentTermsInDocuments(Ref, Cancel);
	DriveServer.ReflectQuotations(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);
	
EndProcedure

#EndRegion

#Region Private

Procedure FillingHandler(FillingData) Export
	
	If Not ValueIsFilled(FillingData) Or Not Common.RefTypeValue(FillingData) Then
		Return;
	EndIf;
	
EndProcedure

Procedure RecalculateSalesTax(Val Variant = Undefined) Export
	
	If Variant = Undefined Then
		Variant = PreferredVariant;
	EndIf;
	
	If ValueIsFilled(SalesTaxRate) Then
		
		If VariantsCount < 2 Then
			SalesTax.Clear();
		Else
			SalesTaxRows = SalesTax.FindRows(New Structure("Variant", Variant));
			For Each SalesTaxRow In SalesTaxRows Do
				SalesTax.Delete(SalesTaxRow);
			EndDo;
		EndIf;
		
		InventoryTaxable	= Inventory.Unload(New Structure("Variant,Taxable", Variant, True));
		AmountTaxable		= InventoryTaxable.Total("Total");
		
		If AmountTaxable <> 0 Then
			
			Combined = Common.ObjectAttributeValue(SalesTaxRate, "Combined");
			
			If Combined Then
				
				Query = New Query;
				Query.Text =
				"SELECT
				|	&Variant AS Variant,
				|	SalesTaxRatesTaxComponents.Component AS SalesTaxRate,
				|	SalesTaxRatesTaxComponents.Rate AS SalesTaxPercentage,
				|	CAST(&AmountTaxable * SalesTaxRatesTaxComponents.Rate / 100 AS NUMBER(15, 2)) AS Amount
				|FROM
				|	Catalog.SalesTaxRates.TaxComponents AS SalesTaxRatesTaxComponents
				|WHERE
				|	SalesTaxRatesTaxComponents.Ref = &Ref";
				
				Query.SetParameter("Ref", SalesTaxRate);
				Query.SetParameter("AmountTaxable", AmountTaxable);
				Query.SetParameter("Variant", Variant);
				
				SalesTaxTable = Query.Execute().Unload();
				For Each Row In SalesTaxTable Do
					FillPropertyValues(SalesTax.Add(), Row);
				EndDo;
				
			Else
				
				NewRow = SalesTax.Add();
				NewRow.Variant = Variant;
				NewRow.SalesTaxRate = SalesTaxRate;
				NewRow.SalesTaxPercentage = SalesTaxPercentage;
				NewRow.Amount = Round(AmountTaxable * SalesTaxPercentage / 100, 2, RoundMode.Round15as20);
				
			EndIf;
			
		EndIf;
		
	Else
		SalesTax.Clear();
	EndIf;
	
	SalesTaxTable = SalesTax.Unload(New Structure("Variant", Variant), "Amount");
	
	SalesTaxServer.CalculateInventorySalesTaxAmount(Inventory, SalesTaxTable.Total("Amount"), Variant);
	
EndProcedure

#EndRegion

#EndIf