
#Region Public

Function CalculateDocumentAmountVATAmountTotals(Object, Parameters = Undefined) Export
	
	If Parameters = Undefined Then
		Parameters = SetParametersForCalculatingPaymentCalendar(Object);
	EndIf;
	
	Totals = New Structure("Amount, VATAmount", 0, 0);
	
	If TypeOf(Parameters) = Type("Structure") Then
		
		If Parameters.Property("TabularSections") Then
			
			If TypeOf(Parameters.TabularSections) = Type("Array") Then
				TabularSections = Parameters.TabularSections;
			ElsIf TypeOf(Parameters.TabularSections) = Type("String") Then
				TabularSections = StringFunctionsClientServer.SplitStringIntoSubstringsArray(Parameters.TabularSections, , False, True);
			Else
				Return Totals;
			EndIf;
			
			For Each TabularSection In TabularSections Do
				
				If Object[TabularSection].Count() = 0 Then
					Continue;
				EndIf;
				
				If CommonClientServer.HasAttributeOrObjectProperty(Object[TabularSection][0], "Amount") Then
					Totals.Amount = Totals.Amount + Object[TabularSection].Total("Amount");
				EndIf;
				
				If CommonClientServer.HasAttributeOrObjectProperty(Object[TabularSection][0], "VATAmount") Then
					Totals.VATAmount = Totals.VATAmount + Object[TabularSection].Total("VATAmount");
				EndIf;
				
			EndDo;
			
		ElsIf Parameters.Property("SpecialSetting") Then
			
			If Parameters.SpecialSetting = "AccountSales" Then
				Totals = CalculateAccountSalesAmountVATAmountTotals(Object);
			ElsIf Parameters.SpecialSetting = "Quote" Then
				Totals = CalculateQuoteAmountVATAmountTotals(Object);
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Totals;
	
EndFunction

Procedure CalculateAmountsInThePaymentCalendar(Object) Export
		
	If Object.SetPaymentTerms
		AND Object.PaymentCalendar.Count() > 0 Then
		
		Totals = CalculateDocumentAmountVATAmountTotals(Object);
		
		AmountForCorrectBalance = 0;
		VATForCorrectBalance = 0;
		
		For Each Line In Object.PaymentCalendar Do
			
			Line.PaymentAmount = Round(Totals.Amount * Line.PaymentPercentage / 100, 2, RoundMode.Round15as20);
			Line.PaymentVATAmount = Round(Totals.VATAmount * Line.PaymentPercentage / 100, 2, RoundMode.Round15as20);
			
			AmountForCorrectBalance = AmountForCorrectBalance + Line.PaymentAmount;
			VATForCorrectBalance = VATForCorrectBalance + Line.PaymentVATAmount;
			
		EndDo;
		
		// correct balance
		Line.PaymentAmount = Line.PaymentAmount + (Totals.Amount - AmountForCorrectBalance);
		Line.PaymentVATAmount = Line.PaymentVATAmount + (Totals.VATAmount - VATForCorrectBalance);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Internal

Function GetCustomsDeclarationTabAmount(Object) Export
	
	IncludedAmount = 0;
	
	For Each Row In Object.CustomsDeclaration Do
		IncludedAmount = ?(Row.IncludeToCurrentInvoice, IncludedAmount + Row.Amount, IncludedAmount);
	EndDo;
	
	Return IncludedAmount;
	
EndFunction

#EndRegion

#Region Private

Function SetParametersForCalculatingPaymentCalendar(Object)
	
	// Use "TabularSections" structure key only if all of them contain "Amount" and "VATAmount" columns
	
	RefType = TypeOf(Object.Ref);
	
	If RefType = Type("DocumentRef.AccountSalesFromConsignee") Then
		Return New Structure("SpecialSetting", "AccountSales");
		
	ElsIf RefType = Type("DocumentRef.AccountSalesToConsignor") Then
		Return New Structure("SpecialSetting", "AccountSales");
		
	ElsIf RefType = Type("DocumentRef.AdditionalExpenses") Then
		CustomsDeclarationTab = PaymentTermsClientServer.GetCustomsDeclarationTabAmount(Object) > 0;
		Return New Structure("TabularSections", "Expenses" + ?(CustomsDeclarationTab, ", CustomsDeclaration", ""));
		
	ElsIf RefType = Type("DocumentRef.PurchaseOrder") Then
		Return New Structure("TabularSections", "Inventory");
		
	ElsIf RefType = Type("DocumentRef.Quote") Then
		Return New Structure("SpecialSetting", "Quote");
		
	ElsIf RefType = Type("DocumentRef.SalesInvoice") Then
		Return New Structure("TabularSections", "Inventory, SalesTax");
		
	ElsIf RefType = Type("DocumentRef.SalesOrder") Then
		Return New Structure("TabularSections", "Inventory, SalesTax");
		
	ElsIf RefType = Type("DocumentRef.SubcontractorInvoiceReceived") Then
		Return New Structure("TabularSections", "Products");
	
	ElsIf RefType = Type("DocumentRef.SupplierInvoice") Then
		Return New Structure("TabularSections", "Inventory, Expenses");
		
	ElsIf RefType = Type("DocumentRef.SupplierQuote") Then
		Return New Structure("TabularSections", "Inventory");
		
	ElsIf RefType = Type("DocumentRef.WorkOrder") Then
		Return New Structure("TabularSections", "Inventory, Works, SalesTax");	
		
	// begin Drive.FullVersion
	
	ElsIf RefType = Type("DocumentRef.SubcontractorInvoiceIssued") Then
		Return New Structure("TabularSections", "Products");
		
	ElsIf RefType = Type("DocumentRef.SubcontractorOrderReceived") Then
		Return New Structure("TabularSections", "Products");
		
	// end Drive.FullVersion 
		
	EndIf;
	
	Return New Structure;
	
EndFunction

Function CalculateAccountSalesAmountVATAmountTotals(Object)
		
	Totals = New Structure("Amount, VATAmount", 0, 0);
	
	If Object.KeepBackCommissionFee Then
		
		InventoryTotal = Object.Inventory.Total("Total");
		InventoryVATAmount = Object.Inventory.Total("VATAmount");
		InventoryBrokerageVATAmount = Object.Inventory.Total("BrokerageVATAmount");
			
		Totals.Amount = Round(InventoryTotal - (Object.CommissionFeePercent * InventoryTotal / 100)
			- (InventoryVATAmount - InventoryBrokerageVATAmount), 2);
		Totals.VATAmount = InventoryVATAmount - InventoryBrokerageVATAmount;
		
	Else
		Totals = CalculateDocumentAmountVATAmountTotals(
			Object, New Structure("TabularSections", "Inventory"));
	EndIf;
	
	Return Totals;
	
EndFunction

Function CalculateQuoteAmountVATAmountTotals(Object)
	
	Amount = 0;
	VATAmount = 0;
	Discount = 0;
	
	If Object.VariantsCount < 2 Then
		
		InventoryRows = Object.Inventory;
		SalesTaxRows = Object.SalesTax;
		
	Else
		
		InventoryRows = Object.Inventory.FindRows(New Structure("Variant", Object.PreferredVariant));
		SalesTaxRows = Object.SalesTax.FindRows(New Structure("Variant", Object.PreferredVariant));
		
	EndIf;
	
	For Each InventoryRow In InventoryRows Do
		
		Amount = Amount + InventoryRow.Amount;
		VATAmount = VATAmount + InventoryRow.VATAmount;
		Discount = Discount + InventoryRow.Price * InventoryRow.Quantity - InventoryRow.Amount;
		
	EndDo;
	
	For Each SalesTaxRow In SalesTaxRows Do
		Amount = Amount + SalesTaxRow.Amount;
	EndDo;
	
	Return New Structure("Amount, VATAmount, Discount", Amount, VATAmount, Discount);
	
EndFunction

#EndRegion 
