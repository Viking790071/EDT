#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	NotCheckedAttributes = New Array;
	
	// begin Drive.FullVersion
	If Not GetFunctionalOption("UseProductionSubsystem") Then
	// end Drive.FullVersion
	
		NotCheckedAttributes.Add("ManufacturingOverheadsAllocationMethod");
		NotCheckedAttributes.Add("UnderOverAllocatedOverheadsSetting");
		
	// begin Drive.FullVersion	
	EndIf;
	// end Drive.FullVersion
	
	Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, NotCheckedAttributes);
	
EndProcedure

Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	MAX(AccountingPolicy.RegisteredForVAT) AS RegisteredForVAT,
	|	MAX(AccountingPolicy.RegisteredForSalesTax) AS RegisteredForSalesTax,
	|	MAX(NOT AccountingPolicy.PostVATEntriesBySourceDocuments) AS PostVATEntriesBySourceDocuments,
	|	MAX(NOT AccountingPolicy.PostAdvancePaymentsBySourceDocuments) AS PostAdvancePaymentsBySourceDocuments,
	|	MAX(AccountingPolicy.UseGoodsReturnFromCustomer) AS UseGoodsReturnFromCustomer,
	|	MAX(AccountingPolicy.UseGoodsReturnToSupplier) AS UseGoodsReturnToSupplier,
	|	FunctionalOptionUseVAT.Value AS CommonVAT,
	|	FunctionalOptionUseSalesTax.Value AS CommonSalesTax,
	|	UseTaxInvoices.Value AS CommonTaxInvoice,
	|	FunctionalOptionUseGoodsReturnFromCustomer.Value AS CommonGoodsReturnFromCustomer,
	|	FunctionalOptionUseGoodsReturnToSupplier.Value AS CommonGoodsReturnToSupplier
	|FROM
	|	InformationRegister.AccountingPolicy AS AccountingPolicy
	|		LEFT JOIN Constant.FunctionalOptionUseVAT AS FunctionalOptionUseVAT
	|		ON (TRUE)
	|		LEFT JOIN Constant.UseTaxInvoices AS UseTaxInvoices
	|		ON (TRUE)
	|		LEFT JOIN Constant.UseGoodsReturnFromCustomer AS FunctionalOptionUseGoodsReturnFromCustomer
	|		ON (TRUE)
	|		LEFT JOIN Constant.UseGoodsReturnToSupplier AS FunctionalOptionUseGoodsReturnToSupplier
	|		ON (TRUE)
	|		LEFT JOIN Constant.UseSalesTax AS FunctionalOptionUseSalesTax
	|		ON (TRUE)
	|
	|GROUP BY
	|	FunctionalOptionUseVAT.Value,
	|	FunctionalOptionUseSalesTax.Value,
	|	UseTaxInvoices.Value,
	|	FunctionalOptionUseGoodsReturnFromCustomer.Value,
	|	FunctionalOptionUseGoodsReturnToSupplier.Value";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		RegisteredForVAT		= Selection.RegisteredForVAT;
		RegisteredForSalesTax	= Selection.RegisteredForSalesTax;
		UseTaxInvoices			= Selection.PostVATEntriesBySourceDocuments Or Selection.PostAdvancePaymentsBySourceDocuments;
		
		UseGoodsReturnFromCustomer	= Selection.UseGoodsReturnFromCustomer;
		UseGoodsReturnToSupplier	= Selection.UseGoodsReturnToSupplier;
		
	Else
		
		RegisteredForVAT		= False;
		RegisteredForSalesTax	= False;
		UseTaxInvoices			= False;
		
		UseGoodsReturnFromCustomer	= False;
		UseGoodsReturnToSupplier	= False;
		
	EndIf;
	
	If Selection.CommonGoodsReturnFromCustomer <> UseGoodsReturnFromCustomer Then
		Constants.UseGoodsReturnFromCustomer.Set(UseGoodsReturnFromCustomer);
	EndIf;
	
	If Selection.CommonGoodsReturnToSupplier <> UseGoodsReturnToSupplier Then
		Constants.UseGoodsReturnToSupplier.Set(UseGoodsReturnToSupplier);
	EndIf;
	
	If Selection.CommonVAT <> RegisteredForVAT Then
		Constants.FunctionalOptionUseVAT.Set(RegisteredForVAT);
	EndIf;
	
	If Selection.CommonSalesTax <> RegisteredForSalesTax Then
		Constants.UseSalesTax.Set(RegisteredForSalesTax);
	EndIf;
	
	If Selection.CommonTaxInvoice <> UseTaxInvoices Then
		Constants.UseTaxInvoices.Set(UseTaxInvoices);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf