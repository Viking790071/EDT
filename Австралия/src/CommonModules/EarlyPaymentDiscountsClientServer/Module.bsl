#Region Public

// Generates hyperlink label on Credit note
//
Function CreditNotePresentation(Date, Number) Export
	
	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Credit note No. %1 dated %2'; ru = 'Кредитовое авизо № %1 от %2';pl = 'Nota kredytowa nr %1 z dn. %2';es_ES = 'Nota de crédito No. %1 fechado %2';es_CO = 'Número del haber %1 fechado %2';tr = '%1 numaralı, %2 tarihli alacak dekontu';it = 'Nota di credito No. %1 con data %2';de = 'Gutschrift Nr. %1 datiert %2'"),
		ObjectPrefixationClientServer.GetNumberForPrinting(Number, True, True),
		Format(Date, "DLF=D"));
	
EndFunction
	
// Generates hyperlink label on Debit note
//
Function DebitNotePresentation(Date, Number) Export
	
	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Debit note No. %1 dated %2'; ru = 'Дебетовое авизо № %1 от %2';pl = 'Nota debetowa nr %1 z dn. %2';es_ES = 'Número del debe %1 fechado %2';es_CO = 'Número del debe %1 fechado %2';tr = '%1 numaralı, %2 tarihli borç dekontu';it = 'Nota di debito No. %1 con data %2';de = 'Lastschrift Nr. %1 datiert %2'"),
		ObjectPrefixationClientServer.GetNumberForPrinting(Number, True, True),
		Format(Date, "DLF=D"));
	
EndFunction

Procedure ShiftEarlyPaymentDiscountsDates(Object) Export
	
	For Each EPDRow In Object.EarlyPaymentDiscounts Do
		CalculateDueDateOfEPD(Object.Date, EPDRow);
	EndDo;
	
EndProcedure

Procedure CalculateDueDateOfEPD(DocumentDate, EPDRow) Export
	
	If EPDRow = Undefined Then
		Return;
	EndIf;
	
	EPDRow.DueDate = DocumentDate + EPDRow.Period * 86400;
	
EndProcedure

#EndRegion