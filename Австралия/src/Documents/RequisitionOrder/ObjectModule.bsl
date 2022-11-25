#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers
	
Procedure OnCopy(CopiedObject)
	
	Event		= Documents.Event.EmptyRef();
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If ReceiptDatePosition = Enums.AttributeStationing.InHeader Then
		For Each TabularSectionRow In Inventory Do
			If TabularSectionRow.ReceiptDate <> ReceiptDate Then
				TabularSectionRow.ReceiptDate = ReceiptDate;
			EndIf;
		EndDo;
	EndIf;
	
	If ReceiptDatePosition = Enums.AttributeStationing.InTabularSection Then
		If Inventory.Count() > 0 Then
			ReceiptDate = Inventory[0].ReceiptDate;
		EndIf;
	EndIf;
	

EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If ReceiptDatePosition = Enums.AttributeStationing.InTabularSection Then
		CheckedAttributes.Delete(CheckedAttributes.Find("ReceiptDate"));
	Else
		CheckedAttributes.Delete(CheckedAttributes.Find("Inventory.ReceiptDate"));
	EndIf;
	
EndProcedure

#EndRegion

#EndIf