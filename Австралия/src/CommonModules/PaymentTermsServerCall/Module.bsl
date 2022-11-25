
#Region Public

Procedure FillPaymentTypeAttributes(Company, CashAssetType, BankAccount, PettyCash) Export
	
	If CashAssetType = Enums.CashAssetTypes.Noncash Then
		BankAccount = Common.ObjectAttributeValue(Company, "BankAccountByDefault");
	ElsIf CashAssetType = Enums.CashAssetTypes.Cash Then
		PettyCash = Common.ObjectAttributeValue(Company, "PettyCashByDefault");
	EndIf;
	
EndProcedure

#EndRegion 