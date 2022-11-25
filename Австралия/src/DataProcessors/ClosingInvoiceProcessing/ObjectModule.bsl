#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Not SetPaymentTerms Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentMethod");
	EndIf;
	If Not SetPaymentTerms Or (PaymentMethod <> Catalogs.PaymentMethods.Electronic
		And PaymentMethod <> Catalogs.PaymentMethods.DirectDebit) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankAccount");
	EndIf;
	If Not SetPaymentTerms Or PaymentMethod <> Catalogs.PaymentMethods.Cash Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PettyCash");
	EndIf;
	If Not SetPaymentTerms Or PaymentMethod <> Catalogs.PaymentMethods.DirectDebit Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "DirectDebitMandate");
	EndIf;
	
	PaymentTermsServer.CheckCorrectPaymentCalendar(ThisObject, Cancel, 0, 0);
	
EndProcedure

#EndRegion

#EndIf