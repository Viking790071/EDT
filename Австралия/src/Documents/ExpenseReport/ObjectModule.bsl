#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure FillInEmployeeGLAccounts(ByEmployee = True, ByDefault = True) Export
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	If ByEmployee And ValueIsFilled(Employee) Then
		EmployeeAttributes = Common.ObjectAttributesValues(Employee, "AdvanceHoldersGLAccount, OverrunGLAccount");
		AdvanceHoldersReceivableGLAccount = EmployeeAttributes.AdvanceHoldersGLAccount;
		AdvanceHoldersPayableGLAccount = EmployeeAttributes.OverrunGLAccount;
	EndIf;
	
	If ByDefault Then
		
		If Not ValueIsFilled(AdvanceHoldersReceivableGLAccount) Then
			AdvanceHoldersReceivableGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHolders");
		EndIf;
		
		If Not ValueIsFilled(AdvanceHoldersPayableGLAccount) Then
			AdvanceHoldersPayableGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHoldersPayable");
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlers

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("DocumentRef.CashVoucher") Then
		FillByCashVoucher(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.PaymentExpense") Then
		FillByPaymentExpense(FillingData);
	EndIf;
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, , "AutomaticVATCalculation");
	
	FillInEmployeeGLAccounts(False);
	
	WorkWithVAT.ForbidReverseChargeTaxationTypeDocumentGeneration(ThisObject);
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If ForOpeningBalancesOnly Then
		CheckedAttributes.Clear();
		Return;
	EndIf;
	
	AdvancesPaidTotal = AdvancesPaid.Total("Amount");
	InventoryTotal = Inventory.Total("Total");
	ExpencesTotal = Expenses.Total("Total");
	PaymentsTotals = Payments.Total("PaymentAmount");
	
	If AdvancesPaidTotal > InventoryTotal + ExpencesTotal + PaymentsTotals Then
		MessageText = NStr("en = 'Cannot post the document. Total amount of issued advances exceeds total amount of expenses'; ru = '???? ?????????????? ???????????????? ????????????????. ?????????? ?????????? ???????????????? ?????????????? ?????????????????? ?????????? ?????????? ????????????????';pl = 'Nie mo??na zatwierdzi?? dokumentu. ????czna warto???? wydanych zaliczek przekracza ????czn?? warto???? rozchod??w';es_ES = 'No se puede enviar el documento. El importe total de los anticipos emitidos excede el importe total de los gastos';es_CO = 'No se puede enviar el documento. El importe total de los anticipos emitidos excede el importe total de los gastos';tr = 'Belge kaydedilemiyor. D??zenlenen avans tutar??, toplam masraf tutar??n?? a????yor';it = 'Impossibile pubblicare il documento. L''importo totale dei pagamenti anticipati emessi supera l''importo totale delle spese';de = 'Das Dokument kann nicht gebucht werden. Der Gesamtbetrag der ausgegebenen Vorsch??sse ??bersteigt den Gesamtbetrag der Ausgaben'");
		DriveServer.ShowMessageAboutError(ThisObject,
			MessageText,
			"AdvancesPaid",
			1,
			"Amount",
			Cancel);
	EndIf;
	
	For Each PaymentRow In Payments Do
		If Not PaymentRow.AdvanceFlag AND Not ValueIsFilled(PaymentRow.Document) Then
			MessageText = NStr("en = 'The ""Settlement document"" column is not populated in the %LineNumber% line of the ""Payments"" list.'; ru = '???? ?????????????????? ?????????????? ""???????????????? ????????????????"" ?? ???????????? %LineNumber% ???????????? ""????????????"".';pl = 'W wierszu %LineNumber% listy ""P??atno??ci"" nie wype??niono kolumny ""Dokument rozlicze??"".';es_ES = 'La columna ""Documento de liquidaciones"" no est?? poblado en la l??nea %LineNumber% de la lista ""Pagos"".';es_CO = 'La columna ""Documento de liquidaciones"" no est?? poblado en la l??nea %LineNumber% de la lista ""Pagos"".';tr = '""??deme belgesi"" s??tunu ""??demeler"" listesinin %LineNumber% sat??r??nda doldurulmad??.';it = 'La colonna ""Documento di pagamento"" non viene popolato nella linea %LineNumber% dell''elenco ""Pagamenti"".';de = 'Die Spalte ""Abrechnungsbeleg"" wird in der Zeile der %LineNumber% Liste ""Zahlungen"" nicht gef??llt.'");
			MessageText = StrReplace(MessageText, "%LineNumber%", String(PaymentRow.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Payments",
				PaymentRow.LineNumber,
				"Document",
				Cancel
			);
		EndIf;
	EndDo;
	
	For Each RowsExpenses In Expenses Do
		
		If GetFunctionalOption("UseSeveralDepartments")
		   AND (RowsExpenses.Products.ExpensesGLAccount.TypeOfAccount = Enums.GLAccountsTypes.WorkInProgress
		 OR RowsExpenses.Products.ExpensesGLAccount.TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses
		 OR RowsExpenses.Products.ExpensesGLAccount.TypeOfAccount = Enums.GLAccountsTypes.Revenue
		 OR RowsExpenses.Products.ExpensesGLAccount.TypeOfAccount = Enums.GLAccountsTypes.Expenses)
		 AND Not ValueIsFilled(RowsExpenses.StructuralUnit) Then
			MessageText = NStr("en = 'The ""Department"" attribute must be filled in for the %Products%"" products in the %LineNumber% line of the ""Expenses"" list.'; ru = '?????? ???????????????????????? ""%Products%"" ?????????????????? ?? ???????????? %LineNumber% ???????????? ""??????????????"", ???????????? ???????? ???????????????? ???????????????? ""??????????????????????????"".';pl = 'Dla pozycji %Products% w wierszu %LineNumber% listy ""Koszty"" nale??y wype??ni?? atrybut ""Dzia??"".';es_ES = 'El atributo ""Departamento"" tiene que estar rellenado para los productos %Products% en la l??nea %LineNumber% de la lista de ""Gastos.';es_CO = 'El atributo ""Departamento"" tiene que estar rellenado para los productos %Products% en la l??nea %LineNumber% de la lista de ""Gastos.';tr = '""B??l??m"" ??zniteli??i ""Giderler"" listesinin %LineNumber% sat??r??ndaki ""%Products%"" ??r??nler i??in doldurulmal??d??r.';it = 'L''attributo ""Reparto"" deve essere compilato per l''articolo %Products% nella linea %LineNumber% dell''elenco ""Spese"".';de = 'Das Attribut ""Abteilung"" muss f??r die %Products%"" Produkte in der %LineNumber%Zeile der Liste ""Ausgaben"" ausgef??llt werden.'");
			MessageText = StrReplace(MessageText, "%Products%", TrimAll(String(RowsExpenses.Products))); 
			MessageText = StrReplace(MessageText, "%LineNumber%",String(RowsExpenses.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Expenses",
				RowsExpenses.LineNumber,
				"StructuralUnit",
				Cancel
			);
		EndIf;
		
		If RowsExpenses.DeductibleTax And Not ValueIsFilled(RowsExpenses.Supplier) Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'On the Services tab, the supplier is required in line #%1.'; ru = '???? ?????????????? ???????????? ?? ???????????? %1 ?????????????????? ?????????????? ????????????????????.';pl = 'Na karcie Us??ugi, wymagany jest dostawca w wierszu nr %1.';es_ES = 'En la pesta??a de Servicios, se requiere que el proveedor est?? en l??nea #%1.';es_CO = 'En la pesta??a de Servicios, se requiere que el proveedor est?? en l??nea #%1.';tr = 'Hizmetler sekmesinin %1 sat??r??nda tedarik??i gerekli.';it = 'Nella scheda Servizi il fornitore ?? richiesto nella riga #%1.';de = 'Auf der Registerkarte ???Dienstleistungen??? ist der Lieferant in Zeile Nr.%1 erforderlich.'"), 
				RowsExpenses.LineNumber);
			
			DriveServer.ShowMessageAboutError(ThisObject,
				MessageText,
				"Expenses",
				RowsExpenses.LineNumber,
				"Supplier",
				Cancel);
			
		EndIf;
		
	EndDo;
	
	For Each RowInventory In Inventory Do
		
		If RowInventory.DeductibleTax And Not ValueIsFilled(RowInventory.Supplier) Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'On the Products tab, the supplier is required in line #%1.'; ru = '???? ?????????????? ???????????????????????? ?? ???????????? %1 ?????????????????? ?????????????? ????????????????????.';pl = 'Na karcie Produkty, wymagany jest dostawca w wierszu nr %1.';es_ES = 'En la pesta??a Productos, se requiere que el proveedor est?? en l??nea #%1.';es_CO = 'En la pesta??a Productos, se requiere que el proveedor est?? en l??nea #%1.';tr = '??r??nler sekmesinin %1. sat??r??nda tedarik??i gerekli.';it = 'Nella scheda Articoli, il fornitore ?? richiesto nella riga #%1.';de = 'Auf der Registerkarte ???Produkte???, ist der Lieferant in Zeile Nr.%1 erforderlich.'"), 
				RowInventory.LineNumber);
			
			DriveServer.ShowMessageAboutError(ThisObject,
				MessageText,
				"Inventory",
				RowInventory.LineNumber,
				"Supplier",
				Cancel);
			
		EndIf;
		
	EndDo;
	
	BatchesServer.CheckFilling(ThisObject, Cancel);
	
	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Company, Date) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
	If ValueIsFilled(BeginOfPeriod) And BeginOfPeriod > Date Then
		MessageText = NStr("en = 'The period start date is later than the document date.'; ru = '???????? ???????????? ?????????????? ????????????, ?????? ???????? ??????????????????.';pl = 'Data rozpocz??cia okresu jest p????niejsza ni?? data dokumentu.';es_ES = 'La fecha de inicio del per??odo es posterior a la fecha del documento.';es_CO = 'La fecha de inicio del per??odo es posterior a la fecha del documento.';tr = 'D??nem ba??lang???? tarihi, belge tarihinden daha ileri.';it = 'La data di inizio del periodo ?? successiva alla data del documento.';de = 'Das Startdatum des Zeitraums liegt nach dem Dokumentendatum.'");
		DriveServer.ShowMessageAboutError(ThisObject,
			MessageText,
			,
			,
			"BeginOfPeriod",
			Cancel);
	EndIf;
	
	If ValueIsFilled(EndOfPeriod) And EndOfPeriod > Date Then
		MessageText = NStr("en = 'The period end date is later than the document date.'; ru = '???????? ?????????????????? ?????????????? ????????????, ?????? ???????? ??????????????????.';pl = 'Data zako??czenia okresu jest p????niejsza ni?? data dokumentu.';es_ES = 'La fecha final del per??odo es posterior a la fecha del documento.';es_CO = 'La fecha final del per??odo es posterior a la fecha del documento.';tr = 'D??nem sonu tarihi, belge tarihinden daha ileri.';it = 'La data di fine del periodo ?? successiva alla data del documento.';de = 'Das Startdatum des Zeitraums liegt nach dem Dokumentendatum.'");
		DriveServer.ShowMessageAboutError(ThisObject,
			MessageText,
			,
			,
			"EndOfPeriod",
			Cancel);
	EndIf;
	
	If ValueIsFilled(BeginOfPeriod) And ValueIsFilled(EndOfPeriod) And BeginOfPeriod > EndOfPeriod Then
		MessageText = NStr("en = 'The period start date is later than the end date.'; ru = '???????? ???????????? ?????????????? ????????????, ?????? ???????? ??????????????????.';pl = 'Data rozpocz??cia okresu jest p????niejsza ni?? data zako??czenia.';es_ES = 'La fecha de inicio del per??odo es posterior a la fecha final.';es_CO = 'La fecha de inicio del per??odo es posterior a la fecha final.';tr = 'D??nem ba??lang???? tarihi, biti?? tarihinden ileri.';it = 'La data di inizio del periodo ?? successiva alla data di fine.';de = 'Das Startdatum des Zeitraums liegt nach dem Enddatum.'");
		DriveServer.ShowMessageAboutError(ThisObject,
			MessageText,
			,
			,
			"BeginOfPeriod",
			Cancel);
	EndIf;
	
	For Each Row In Expenses Do
		If Row.RegisterExpense And Not ValueIsFilled(Row.ExpenseItem) Then
			DriveServer.ShowMessageAboutError(
				ThisObject,
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'On the Services tab, in line #%1, an expense item is required.'; ru = '???? ?????????????? ""????????????"" ?? ???????????? %1 ?????????????????? ?????????????? ???????????? ????????????????.';pl = 'Na karcie Us??ugi, w wierszu nr %1, pozycja rozchod??w jest wymagana.';es_ES = 'En la pesta??a Servicios, en la l??nea #%1, se requiere un art??culo de gastos para.';es_CO = 'En la pesta??a Servicios, en la l??nea #%1, se requiere un art??culo de gastos para.';tr = 'Hizmetler sekmesinin %1 nolu sat??r??nda gider kalemi gerekli.';it = 'Nella scheda Servizi, nella riga #%1, ?? richiesta una voce di uscita.';de = 'Eine Position von Ausgaben ist in der Zeile Nr. %1 auf der Registerkarte Dienstleistungen erforderlich.'"),
					Row.LineNumber),
				"Expenses",
				Row.LineNumber,
				"ExpenseItem",
				Cancel);
		EndIf;
	EndDo;
	
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Inventory.Count() > 0
		Or Expenses.Count() > 0
		Or Payments.Count() > 0
		Or Not ForOpeningBalancesOnly Then
		
		DocumentAmount = Inventory.Total("Total") + Expenses.Total("Total") + Payments.Total("PaymentAmount");
		
	EndIf;
	
	If Not Constants.UseSeveralLinesOfBusiness.Get() Then
		
		For Each RowsExpenses In Expenses Do
			
			If RowsExpenses.Products.ExpensesGLAccount.TypeOfAccount = Enums.GLAccountsTypes.Expenses Then
				
				RowsExpenses.BusinessLine = Catalogs.LinesOfBusiness.MainLine;
				
			Else
				
				RowsExpenses.BusinessLine = Undefined;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	For Each TSRow In Payments Do
		If ValueIsFilled(TSRow.Counterparty)
		AND Not TSRow.Counterparty.DoOperationsByContracts
		AND Not ValueIsFilled(TSRow.Contract) Then
			TSRow.Contract = TSRow.Counterparty.ContractByDefault;
		EndIf;
	EndDo;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
	InventoryOwnershipServer.FillMainTableColumn(ThisObject, WriteMode, Cancel);
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	If ForOpeningBalancesOnly Then
		Return;
	EndIf;
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;

	// Document data initialization.
	Documents.ExpenseReport.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAdvanceHolders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPurchases(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Offline registers
	DriveServer.ReflectInventoryCostLayer(AdditionalProperties, RegisterRecords, Cancel);
	
	// VAT
	DriveServer.ReflectVATIncurred(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectVATInput(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.ExpenseReport.RunControl(Ref, AdditionalProperties, Cancel);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate tax invoice
	If Not Cancel Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.Posting, Ref, DeletionMark);
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);

	EndIf;
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	If ForOpeningBalancesOnly Then
		Return;
	EndIf;
	
	// Initialization of additional properties to undo document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Subordinate tax invoice
	If Not Cancel Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.UndoPosting, Ref, DeletionMark);
	EndIf;
	
	// Control of occurrence of a negative balance.
	Documents.ExpenseReport.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
			
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
		
	EndIf;
		
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DriveServer.CheckDocumentsReposting(Ref, AdditionalProperties.Posted, Cancel);
	
	// Subordinate tax invoice
	If Not Cancel And AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(AdditionalProperties.WriteMode, Ref, DeletionMark);
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, AdditionalProperties.WriteMode, DeletionMark, Company, Date, AdditionalProperties);

	EndIf;
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	ForOpeningBalancesOnly = False;
	
EndProcedure

#EndRegion

#Region Private

// Procedure of document filling on the basis of the cash payment.
//
// Parameters:
//  BasisDocument - DocumentRef.CashInflowForecast - Planned payment
//  FillingData - Structure - Document filling data
//	
Procedure FillByCashVoucher(FillingData)
	
	If FillingData.OperationKind <> Enums.OperationTypesCashVoucher.ToAdvanceHolder Then
		Raise NStr("en = 'Please select a cash voucher with ""To advance holder"" operation.'; ru = '???????????????? ?????????????????? ???????????????? ?????????? ?? ?????????????????? ""????????????????????????"".';pl = 'Wybierz dow??d kasowy KW z operacj?? ""Do zaliczkobiorcy"".';es_ES = 'Por favor, seleccione un vale de efectivo con la operaci??n ""Al titular de anticipo"".';es_CO = 'Por favor, seleccione un vale de efectivo con la operaci??n ""Al titular de anticipo"".';tr = 'L??tfen, ""Avans sahibi"" i??lemli bir kasa fi??i se??in.';it = 'Si prega di selezionare una uscita di cassa con una operazione ""Alla persona che ha anticipato"".';de = 'Bitte w??hlen Sie einen Kassenbeleg mit der Operation ""F??r die abrechnungspflichtige Person"" aus.'");
	EndIf;
	
	Company = FillingData.Company;
	CompanyVATNumber = FillingData.CompanyVATNumber;
	BasisDocument = FillingData.Ref;
	Employee = FillingData.AdvanceHolder;
	DocumentCurrency = FillingData.CashCurrency;
	AdvanceHoldersReceivableGLAccount = FillingData.AdvanceHoldersReceivableGLAccount;
	AdvanceHoldersPayableGLAccount = FillingData.AdvanceHoldersPayableGLAccount;
	
	If Not ValueIsFilled(AdvanceHoldersReceivableGLAccount)
		Or Not ValueIsFilled(AdvanceHoldersPayableGLAccount) Then
		FillInEmployeeGLAccounts();
	EndIf;
	
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Date, DocumentCurrency, Company);
	ExchangeRate = ?(StructureByCurrency.Rate = 0, 1, StructureByCurrency.Rate);
	Multiplicity = ?(StructureByCurrency.Repetition = 0, 1, StructureByCurrency.Repetition);
	
	AdvancesPaid.Clear();
	NewRow = AdvancesPaid.Add();
	NewRow.Document = FillingData.Ref;
	NewRow.Amount = FillingData.DocumentAmount;
	
EndProcedure

// Procedure of document filling based on the bank payment.
//
// Parameters:
//  BasisDocument - DocumentRef.CashInflowForecast - Planned payment 
//  FillingData - Structure - Document filling data
//	
Procedure FillByPaymentExpense(FillingData)
	
	If FillingData.OperationKind <> Enums.OperationTypesPaymentExpense.ToAdvanceHolder Then
		Raise NStr("en = 'Please select a bank payment with ""To advance holder"" operation.'; ru = '???????????????? ???????????????? ???? ?????????? ?? ?????????? ???????????????? ""????????????????????????"".';pl = 'Wybierz p??atno???? bankow?? z operacj?? ""Do zaliczkobiorcy"".';es_ES = 'Por favor, seleccione un pago bancario con la operaci??n ""Al titular del anticipo"".';es_CO = 'Por favor, seleccione un pago bancario con la operaci??n ""Al titular del anticipo"".';tr = '""Avans sahibine"" i??lemi ile birlikte bir banka ??demesi se??in.';it = 'Selezionare un bonifico bancario con l''operazione ""Alla persona che ha anticipato"".';de = 'Bitte w??hlen Sie eine ??berweisung mit der Operation ""An die abrechnungspflichtige Person"" aus.'");
	EndIf;
	
	Company = FillingData.Company;
	CompanyVATNumber = FillingData.CompanyVATNumber;
	BasisDocument = FillingData.Ref;
	Employee = FillingData.AdvanceHolder;
	DocumentCurrency = FillingData.CashCurrency;
	AdvanceHoldersReceivableGLAccount = FillingData.AdvanceHoldersReceivableGLAccount;
	AdvanceHoldersPayableGLAccount = FillingData.AdvanceHoldersPayableGLAccount;
	
	If Not ValueIsFilled(AdvanceHoldersReceivableGLAccount)
		Or Not ValueIsFilled(AdvanceHoldersPayableGLAccount) Then
		FillInEmployeeGLAccounts();
	EndIf;
	
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Date, DocumentCurrency, Company);
	ExchangeRate = ?(StructureByCurrency.Rate = 0, 1, StructureByCurrency.Rate);
	Multiplicity = ?(StructureByCurrency.Repetition = 0, 1, StructureByCurrency.Repetition);
	
	AdvancesPaid.Clear();
	NewRow = AdvancesPaid.Add();
	NewRow.Document = FillingData.Ref;
	NewRow.Amount = FillingData.DocumentAmount;
	
EndProcedure

#EndRegion

#EndIf
