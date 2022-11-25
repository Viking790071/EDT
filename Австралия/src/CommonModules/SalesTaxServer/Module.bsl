#Region Public

Procedure CalculateInventorySalesTaxAmount(Inventory, SalesTaxAmount, Variant = Undefined) Export
	
	If Inventory.Count() > 0 Then
		
		If Variant <> Undefined Then
			InventoryTaxable	= Inventory.Unload(New Structure("Variant,Taxable", Variant, True));
			InventoryRows		= Inventory.FindRows(New Structure("Variant", Variant));
		Else
			InventoryTaxable	= Inventory.Unload(New Structure("Taxable", True));
			InventoryRows		= Inventory;
		EndIf;
		
		TaxableAmount			= InventoryTaxable.Total("Total");
		LastTaxableRow			= Undefined;
		InventorySalesTaxAmount	= 0;
		
		For Each Row In InventoryRows Do
			
			If Row.Taxable And (Variant = Undefined Or Row.Variant = Variant) And TaxableAmount <> 0 Then
				Row.SalesTaxAmount		= Round(SalesTaxAmount * Row.Total / TaxableAmount, 2, RoundMode.Round15as20);
				LastTaxableRow			= Row;
				InventorySalesTaxAmount	= InventorySalesTaxAmount + Row.SalesTaxAmount;
			Else
				Row.SalesTaxAmount = 0;
			EndIf;
			
		EndDo;
		
		If LastTaxableRow <> Undefined And SalesTaxAmount <> InventorySalesTaxAmount Then
			LastTaxableRow.SalesTaxAmount = LastTaxableRow.SalesTaxAmount + SalesTaxAmount - InventorySalesTaxAmount;
		EndIf;
		
	EndIf;
	
EndProcedure

// Check usage the option "Registered for Sales tax".
//
// Parameters:
//  Date - Date - Date for check
//  Company - CatalogRef.Companies - Company for check
//
// Returned value:
//  Boolean - shows the option value
//
Function GetUseSalesTax(Date, Company) Export
	
	Policy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	
	Return Policy.RegisteredForSalesTax;
	
EndFunction

#EndRegion