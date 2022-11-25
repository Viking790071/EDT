
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Filter") And Parameters.Filter.Property("BankAccount") Then
		
		Items.Company.Visible = False;
		Items.BankAccount.Visible = False;
		
		AccountAttributes = Common.ObjectAttributesValues(Parameters.Filter.BankAccount, "Owner, UseOverdraft");
		If TypeOf(AccountAttributes.Owner) = Type("CatalogRef.Counterparties") 
			Or Not AccountAttributes.UseOverdraft Then
			
			Items.List.ReadOnly = True;
			
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ListOnChange(Item)
	Notify("OvedraftsChangedBankAccounts");
EndProcedure

#EndRegion