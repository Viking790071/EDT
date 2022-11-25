
#Region ProgramInterface 

Function GetSubordinateTaxInvoice(BasisDocument, Received = False,  Advance = False) Export
	Return WorkWithVAT.GetSubordinateTaxInvoice(BasisDocument, Received,  Advance);
EndFunction

Function CheckForTaxInvoiceUse(Date, Company, Cancel = False) Export
	
	Policy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	If Policy.PostVATEntriesBySourceDocuments Then
		CommonClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Company %1 doesn''t use tax invoices at %2 (specify this option in accounting policy)'; ru = 'Организация %1 не использует налоговые инвойсы на %2 (укажите данную опцию в учетной политике)';pl = 'Firma %1 nie stosuje faktur VAT do %2 (określ tę opcję w zasadach rachunkowości)';es_ES = 'Empresa %1 no utiliza las facturas de impuestos en %2 (especificar esta opción en la política de contabilidad)';es_CO = 'Empresa %1 no utiliza las facturas fiscales en %2 (especificar esta opción en la política de contabilidad)';tr = '%1 iş yeri %2 tarihinde vergi faturaları kullanmıyor (muhasebe politikasında bu seçeneği belirtin)';it = 'L''azienda %1 non utilizza fatture fiscali a %2 (specificare questa opzione nella politica contabile)';de = 'Die Firma %1 verwendet keine Steuerrechnungen bei %2 (diese Option in der Bilanzierungsrichtlinie angeben)'"),
				Company,
				Format(Date, "DLF=D")),,,,
			Cancel);
	EndIf;
	
EndFunction

// Check the ability to enter the Advance payment invoice
//
// Parameters:
//	Date - Date - Check date
//	Company - CatalogRef.Companies - Company for check
//	Cancel - Boolean - For cancel posting document
//	
Procedure CheckForAdvancePaymentInvoiceUse(Date, Company, Cancel = False) Export
	
	Policy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	If Policy.PostAdvancePaymentsBySourceDocuments Then
		CommonClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Company %1 doesn''t use Advance payment invoices at %2 (specify this option in accounting policy)'; ru = 'Организация %1 не использует инвойсы на %2 (укажите данную опцию в учетной политике)';pl = 'Firma %1 nie stosuje faktur zaliczkowych %2 (określ tę opcję w zasadach rachunkowości)';es_ES = 'Empresa %1 no utiliza las facturas de Pagos Anticipados en %2 (especificar esta opción en la política de contabilidad)';es_CO = 'Empresa %1 no utiliza las facturas de Pagos Anticipados en %2 (especificar esta opción en la política de contabilidad)';tr = '%1 İş yerinin %2 bölümünde Avans ödeme faturalarını kullanmayın (muhasebe politikası için bu seçeneği belirleyin)';it = 'L''azienda %1 non utilizza fatture fiscali in %2 (specificare questa opzione nella politica contabile)';de = 'Die Firma %1 verwendet keine Vorauszahlungsrechnungen bei %2 (diese Option in der Bilanzierungsrichtlinie angeben)'"),
				Company,
				Format(Date, "DLF=D")),,,,
			Cancel);
	EndIf;
	
EndProcedure

Function CompanyIsRegisteredForVAT(Company, Date, UseException = True) Export
	
	Policy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company, UseException);
	
	Return Policy.RegisteredForVAT;
	
EndFunction

Function MultipleVATNumbersAreUsed() Export 
	Return GetFunctionalOption("UseMultipleVATNumbers");
EndFunction

#EndRegion