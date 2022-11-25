
#Region Public

// Generates hyperlink label on Sales invoice note
//
Function TaxInvoicePresentation(Date, Number) Export

	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Tax invoice No. %1 dated %2'; ru = 'Налоговый инвойс №%1 от %2 г.';pl = 'Faktura VAT nr %1 z dn. %2';es_ES = 'Número de la factura de impuestos %1 fechada %2';es_CO = 'Número de la factura fiscal %1 fechada %2';tr = 'Vergi faturası No. %1 tarih %2';it = 'Fattura fiscale No. %1 con data %2';de = 'Steuerrechnungsnummer %1 datiert %2'"),
		ObjectPrefixationClientServer.GetNumberForPrinting(Number, True, True),
		Format(Date, "DLF=D"));

EndFunction
	
// Generates hyperlink label on documents
//
Function AdvancePaymentInvoicePresentation(Date, Number) Export

	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Advance payment invoice No. %1 dated %2'; ru = 'Инвойс на аванс №%1 от %2 г.';pl = 'Faktura zaliczkowa nr %1 z dn. %2';es_ES = 'Número de la factura del pago anticipado %1 fechada %2';es_CO = 'Número de la factura del pago anticipado %1 fechada %2';tr = 'Avans ödeme faturası No. %1 tarih %2';it = 'Fattura di pagamento anticipato No. %1 con data %2';de = 'Vorauszahlungsrechnungsnummer %1 datiert %2'"),
		ObjectPrefixationClientServer.GetNumberForPrinting(Number, True, True),
		Format(Date, "DLF=D"));

EndFunction

#EndRegion