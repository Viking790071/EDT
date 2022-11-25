#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Procedure distributes expenses by quantity.
//
Procedure DistributeTabSectExpensesByQuantity() Export
	
	SrcAmount = 0;
	
	DistributionBaseQuantity = 0;
	
	For Each InventoryRow In Inventory Do
		
		Factor = 1;
		If TypeOf(InventoryRow.MeasurementUnit) = Type("CatalogRef.UOM") Then
			Factor = Common.ObjectAttributeValue(InventoryRow.MeasurementUnit, "Factor");
		EndIf;
		
		DistributionBaseQuantity = DistributionBaseQuantity + InventoryRow.Quantity * Factor;
		
	EndDo;
	
	TotalExpenses = ExpensesAmountToBeAllocated();
	
	For Each StringInventory In Inventory Do
		
		Factor = 1;
		If TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOM") Then
			Factor = Common.ObjectAttributeValue(StringInventory.MeasurementUnit, "Factor");
		EndIf;
		
		StringInventory.AmountExpense = ?(DistributionBaseQuantity <> 0,
			Round((TotalExpenses - SrcAmount) * (StringInventory.Quantity * Factor)/ DistributionBaseQuantity, 2, 1),
			0);
		
		CalculateReverseChargeVATAmount(StringInventory);
		
		DistributionBaseQuantity = DistributionBaseQuantity - StringInventory.Quantity * Factor;
		SrcAmount = SrcAmount + StringInventory.AmountExpense;
		
	EndDo;
	
EndProcedure

// Procedure distributes expenses by amount.
//
Procedure DistributeTabSectExpensesByAmount() Export
	
	SrcAmount = 0;
	
	ReserveAmount = Inventory.Total("Total");
	
	TotalExpenses = ExpensesAmountToBeAllocated();
	
	For Each StringInventory In Inventory Do
		
		StringInventory.AmountExpense = ?(ReserveAmount <> 0, Round((TotalExpenses - SrcAmount) * StringInventory.Total / ReserveAmount, 2, 1),0);
		CalculateReverseChargeVATAmount(StringInventory);
		
		ReserveAmount = ReserveAmount - StringInventory.Total;
		SrcAmount = SrcAmount + StringInventory.AmountExpense;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region EventHandlers

Procedure OnCopy(CopiedObject)
	
	IncomingDocumentNumber = "";
	IncomingDocumentDate = "";
	
	Prepayment.Clear();
	PrepaymentVAT.Clear();
	
	SerialNumbers.Clear();
	
	For Each InventoryLine In Inventory Do
		InventoryLine.SerialNumbers = "";
		InventoryLine.Ownership = "";
	EndDo;
	
	ForOpeningBalancesOnly = False;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	FillingStrategy = New Map;
	FillingStrategy[Type("Structure")]					= "FillByStructure";
	FillingStrategy[Type("DocumentRef.PurchaseOrder")]	= "FillByPurchaseOrder";
	FillingStrategy[Type("DocumentRef.SupplierQuote")]	= "FillBySupplierQuote";
	FillingStrategy[Type("DocumentRef.SalesSlip")]		= "FillBySalesSlip";
	FillingStrategy[Type("DocumentRef.GoodsReceipt")]	= "FillByGoodsReceipt";
	
	ExcludingProperties					= "Order";
	IsStructureAndArrayOfPurchaseOrders	= False;
	
	If TypeOf(FillingData) = Type("Structure")
		And FillingData.Property("ArrayOfPurchaseOrders") Then
		
		ExcludingProperties = ExcludingProperties + ", AmountIncludesVAT";
		IsStructureAndArrayOfPurchaseOrders = True;
		
	EndIf;
	
	IsNotPermission = False;
	
	If TypeOf(FillingData) = Type("DocumentRef.PurchaseOrder")
		Or IsStructureAndArrayOfPurchaseOrders Then
		
		CurrentOperationKind	= OperationKind;
		TextRaise				= "";
		Documents.SupplierInvoice.CheckPermissionToGenerateInvoiceBasedOnOrder(FillingData, IsNotPermission, TextRaise, CurrentOperationKind);
		
	EndIf;
	
	If IsNotPermission Then
		Raise TextRaise;
	EndIf;
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy, ExcludingProperties);
	
	RegisterVendorPrices = ValueIsFilled(SupplierPriceTypes);
	
	If Not OperationKind = Enums.OperationTypesSupplierInvoice.AdvanceInvoice Then
		
		If VATTaxation = Enums.VATTaxationTypes.ForExport Then
			
			OperationKind = Enums.OperationTypesSupplierInvoice.AdvanceInvoice;
			
		EndIf;
		
	EndIf;
	
	If TypeOf(FillingData) = Type("CatalogRef.Counterparties") Then
		
		PaymentTermsServer.FillPaymentCalendarFromContract(ThisObject);
		
	EndIf;
	
	If Not ValueIsFilled(OperationKind) Then
		
		OperationKind = Enums.OperationTypesSupplierInvoice.Invoice;
		
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If PurchaseOrderPosition = Enums.AttributeStationing.InHeader Then
		For Each TabularSectionRow In Inventory Do
			TabularSectionRow.Order = Order;
		EndDo;
		If Counterparty.DoOperationsByOrders Then
			For Each TabularSectionRow In Prepayment Do
				TabularSectionRow.Order = Order;
			EndDo;
		EndIf;
	EndIf;
	
	InventoryTotals = DriveServer.CalculateSubtotalPurchases(Inventory.Unload(), AmountIncludesVAT);
	ExpensesTotals = DriveServer.CalculateSubtotalPurchases(Expenses.Unload(), AmountIncludesVAT);
	
	If Inventory.Count() > 0
		Or Expenses.Count() > 0
		Or Not ForOpeningBalancesOnly Then
		
		DocumentAmount = InventoryTotals.DocumentAmount + ExpensesTotals.DocumentAmount;
		
	EndIf;
	
	DocumentTax = InventoryTotals.DocumentTax + ExpensesTotals.DocumentTax;
	DocumentSubtotal = InventoryTotals.DocumentSubtotal + ExpensesTotals.DocumentSubtotal;
	
	If Not Constants.UseSeveralLinesOfBusiness.Get() And Not IncludeExpensesInCostPrice Then
		
		For Each RowsExpenses In Expenses Do
			
			If RowsExpenses.ExpenseItem.IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses Then
				RowsExpenses.BusinessLine = Catalogs.LinesOfBusiness.MainLine;
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If ValueIsFilled(Counterparty)
		And Not Counterparty.DoOperationsByContracts
		And Not ValueIsFilled(Contract) Then
		Contract = Counterparty.ContractByDefault;
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
	InventoryOwnershipServer.FillMainTableColumn(ThisObject, WriteMode, Cancel);
	
	If Not AdjustedReserved Then
		InventoryReservationServer.FillReservationTable(ThisObject, WriteMode, Cancel);
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If ForOpeningBalancesOnly Then
		CheckedAttributes.Clear();
		Return;
	EndIf;
	
	// Check existence of retail prices.
	CheckExistenceOfRetailPrice(Cancel);
	
	If Inventory.Count() > 0 Then
		
		CheckedAttributes.Add("StructuralUnit");
		
	EndIf;
	
	If Not IncludeExpensesInCostPrice Then
		
		For Each RowsExpenses In Expenses Do
			
			If Constants.UseSeveralDepartments.Get()
				And (RowsExpenses.ExpenseItem.IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.ManufacturingOverheads
					Or RowsExpenses.ExpenseItem.IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses)
				And Not ValueIsFilled(RowsExpenses.StructuralUnit) Then
				
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The ""Department"" attribute must be filled in for the ""%1"" products specified in the %2 line of the ""Services"" list.'; ru = 'Для номенклатуры ""%1"" указанной в строке %2 списка ""Услуги"", должен быть заполнен реквизит ""Подразделение"".';pl = 'Dla pozycji ""%1"" określonej w %2 wierszu listy ""Usługi"" należy wypełnić atrybut ""Dział"".';es_ES = 'El atributo ""Departamento"" tiene que rellenarse para los productos ""%1"" especificados en la línea %2 de la lista ""Servicios"".';es_CO = 'El atributo ""Departamento"" tiene que rellenarse para los productos ""%1"" especificados en la línea %2 de la lista ""Servicios"".';tr = '""Hizmetler"" listesinin %2 satırında belirtilen ""%1"" ürünleri için ""Bölüm"" özniteliği doldurulmalı.';it = 'L''attributo ""Reparto"" deve essere compilato per gli articoli ""%1"" specificati nella linea %2 dell''elenco ""Servizi"".';de = 'Für die in der %2 Zeile der Liste ""Dienstleistungen"" angegebenen ""%1"" Produkte muss das Attribut ""Abteilung"" ausgefüllt werden.'"),
					TrimAll(String(RowsExpenses.Products)),
					String(RowsExpenses.LineNumber));
					
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Expenses",
					RowsExpenses.LineNumber,
					"StructuralUnit",
					Cancel);
				
			EndIf;
			
			If RowsExpenses.RegisterExpense And Not ValueIsFilled(RowsExpenses.ExpenseItem) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'On the Services tab, in line #%2, an expense item is required for ""%1"".'; ru = 'На вкладке ""Услуги"" в строке %2 требуется указать статью расходов для ""%1"".';pl = 'Na karcie Usługi, w wierszu nr %2, pozycja rozchodów jest wymagana dla ""%1"".';es_ES = 'En la pestaña Servicios, en la línea #%2, se requiere un artículo de gastos para ""%1"".';es_CO = 'En la pestaña Servicios, en la línea #%2, se requiere un artículo de gastos para ""%1"".';tr = 'Hizmetler sekmesinin %2 nolu satırında ""%1"" için gider kalemi gerekli.';it = 'Nella scheda Servizi, nella riga #%2, è richiesta una voce di uscita per ""%1"".';de = 'Eine Position von Ausgaben ist für ""%1"" in der Zeile Nr. %2 auf der Registerkarte Dienstleistungen erforderlich.'"),
					TrimAll(String(RowsExpenses.Products)),
					String(RowsExpenses.LineNumber));
					
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Expenses",
					RowsExpenses.LineNumber,
					"ExpenseItem",
					Cancel);
				EndIf;
				
		EndDo;
		
	EndIf;
	
	If IncludeExpensesInCostPrice And Inventory.Total("AmountExpense") <> ExpensesAmountToBeAllocated() Then
			
		MessageText = NStr(
			"en = 'Amount of services is not equal to the amount allocated by inventory.'; ru = 'Сумма услуг не равна распределенной сумме по запасам!';pl = 'Kwota usług nie jest równa kwocie przydzielonej według zapasów.';es_ES = 'Cantidad de servicios no es igual a la cantidad asignada por el inventario.';es_CO = 'Cantidad de servicios no es igual a la cantidad asignada por el inventario.';tr = 'Hizmet tutarı, stok tarafından dağıtılan tutar kadar değildir.';it = 'L''importo dei servizi non è uguale all''importo assegnato per le scorte.';de = 'Die Menge der Dienstleistungen entspricht nicht der Menge, die von dem Bestand verteilt wurde.'");
		
		DriveServer.ShowMessageAboutError(
			,
			MessageText,
			Undefined,
			Undefined,
			Undefined,
			Cancel);
		
	EndIf;
	
	OrderReceptionInHeader = PurchaseOrderPosition = Enums.AttributeStationing.InHeader;
	
	TableInventory = Inventory.Unload(, "Order, Total");
	TableInventory.GroupBy("Order", "Total");
	
	TableExpenses = Expenses.Unload(, "PurchaseOrder, Total");
	TableExpenses.GroupBy("PurchaseOrder", "Total");
	
	TablePrepayment = Prepayment.Unload(, "Order, PaymentAmount");
	TablePrepayment.GroupBy("Order", "PaymentAmount");
	
	If OrderReceptionInHeader Then
		For Each StringInventory In TableInventory Do
			StringInventory.Order = Order;
		EndDo;
		If Counterparty.DoOperationsByOrders Then
			For Each RowPrepayment In TablePrepayment Do
				RowPrepayment.Order = Order;
			EndDo;
		EndIf;
	EndIf;
	
	QuantitySalesInvoices = Inventory.Count() + Expenses.Count();
	
	For Each String In TablePrepayment Do
		
		FoundStringExpenses = Undefined;
		FoundStringInventory = Undefined;
		
		If Counterparty.DoOperationsByOrders
			And String.Order <> Undefined
			And String.Order <> Documents.PurchaseOrder.EmptyRef() Then
			
			FoundStringInventory = TableInventory.Find(String.Order, "Order");
			FoundStringExpenses = TableExpenses.Find(String.Order, "PurchaseOrder");
			Total = 0 + ?(FoundStringInventory = Undefined, 0, FoundStringInventory.Total)
				+ ?(FoundStringExpenses = Undefined, 0, FoundStringExpenses.Total);
			
		ElsIf Counterparty.DoOperationsByOrders Then
			
			FoundStringInventory = TableInventory.Find(Undefined, "Order");
			FoundStringInventory = ?(FoundStringInventory = Undefined,
				TableInventory.Find(Documents.PurchaseOrder.EmptyRef(), "Order"),
				FoundStringInventory);
			FoundStringExpenses = TableExpenses.Find(Undefined, "PurchaseOrder");
			FoundStringExpenses = ?(FoundStringExpenses = Undefined,
				TableExpenses.Find(Documents.PurchaseOrder.EmptyRef(), "PurchaseOrder"),
				FoundStringExpenses);
			Total = 0 + ?(FoundStringInventory = Undefined, 0, FoundStringInventory.Total)
				+ ?(FoundStringExpenses = Undefined, 0, FoundStringExpenses.Total);
			
		Else
			
			Total = Inventory.Total("Total") + Expenses.Total("Total");
			
		EndIf;
		
		If FoundStringInventory = Undefined
			And FoundStringExpenses = Undefined
			And QuantitySalesInvoices > 0
			And Counterparty.DoOperationsByOrders Then
			
			MessageText = NStr("en = 'Advance of order that is different from the one specified
				|in tabular sections ""Inventory"" or ""Services"" cannot be set off.'; 
				|ru = 'Нельзя зачесть аванс по заказу, отсутствующему
				|в табличных частях ""Запасы"" или ""Услуги"".';
				|pl = 'Zaliczka na zamówienie inna niż określona
				| w sekcji tabelarycznej ""Zapasy"" lub ""Usługi"" nie może być zaliczona.';
				|es_ES = 'Anticipo del orden, que es diferente de aquel especificado 
				|en las secciones tabulares ""Inventario"" o ""Servicios"", no puede amortizarse.';
				|es_CO = 'Anticipo del orden, que es diferente de aquel especificado 
				|en las secciones tabulares ""Inventario"" o ""Servicios"", no puede amortizarse.';
				|tr = '""Stok"" veya ""Hizmetler"" tablo bölümlerinde belirtilenden
				|farklı bir siparişin avansı mahsup edilemez.';
				|it = 'Non è possibile compensare un anticipo d''ordine diverso da quello specificato
				|nelle sezioni tabellari ""Inventario"" o ""Servizi"".';
				|de = 'Die Vorauszahlung der Bestellung, die sich von der in den Tabellenabschnitten ""Bestand"" oder Zeile der Liste ""Dienstleistungen"" angegebenen unterscheidet
				|, kann nicht aufgehoben werden.'");
			DriveServer.ShowMessageAboutError(
				,
				MessageText,
				Undefined,
				Undefined,
				"PrepaymentTotalSettlementsAmountCurrency",
				Cancel);
			
		EndIf;
		
	EndDo;
	
	If Not Counterparty.DoOperationsByContracts Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Company, Date) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
	If Not VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Inventory.ReverseChargeVATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Expenses.ReverseChargeVATRate");
	EndIf;
	
	// Serial numbers
	If OperationKind = Enums.OperationTypesSupplierInvoice.Invoice Then
		WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnit, ThisObject);
		BatchesServer.CheckFilling(ThisObject, Cancel);
	EndIf;
	
	CheckPermissionToChangeWarehouseAndAdvanceInvoicing(Cancel);
	
	//Cash flow projection
	Amount = Inventory.Total("Amount") + Expenses.Total("Amount");
	VATAmount = Inventory.Total("VATAmount") + Expenses.Total("VATAmount");
	
	PaymentTermsServer.CheckRequiredAttributes(ThisObject, CheckedAttributes, Cancel);
	PaymentTermsServer.CheckCorrectPaymentCalendar(ThisObject, Cancel, Amount, VATAmount);
	
	// Advances
	If OperationKind = Enums.OperationTypesSupplierInvoice.AdvanceInvoice And Not IsNew() Then
		AdvanceInvoicingDateCheck(Cancel);
	EndIf;
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	If GetFunctionalOption("UseDefaultTypeOfAccounting") And AccountingPolicy.ContinentalMethod Then
		DiscrepancyGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PurchaseCostDiscrepancies");
		If Not ValueIsFilled(DiscrepancyGLAccount) Then
			Cancel = True;
		EndIf;
	EndIf;
	
	// Zero invoice
	If OperationKind = Enums.OperationTypesSupplierInvoice.ZeroInvoice Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Inventory.Price");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Inventory.Amount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Inventory.Quantity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Inventory.MeasurementUnit");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Inventory.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Inventory.ReverseChargeVATRate");
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Expenses.Price");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Expenses.Amount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Expenses.Quantity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Expenses.MeasurementUnit");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Expenses.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Expenses.ReverseChargeVATRate");
		
	EndIf;
	
	// Drop shipping
	If OperationKind = Enums.OperationTypesSupplierInvoice.DropShipping Then
		
		MessageText = NStr(
			"en = 'The specified order is inapplicable. 
			|The Invoice type is Drop shipping. 
			|For this invoice, select an order whose Operation is Drop shipping.'; 
			|ru = 'Указанный заказ неприменим. 
			|Тип инвойса – Дропшиппинг. 
			|Для этого инвойса выберите заказ с операцией Дропшиппинг.';
			|pl = 'Określone zamówienie nie ma zastosowania. 
			|Typ faktury jest Dropshipping. 
			|Dla tej faktury, wybierz zamówienie z operacją Dropshipping.';
			|es_ES = 'El pedido especificado no es aplicable. 
			|El tipo de factura es Envío directo. 
			|Para esta factura, seleccione un pedido cuya operación es Envío directo.';
			|es_CO = 'El pedido especificado no es aplicable. 
			|El tipo de factura es Envío directo. 
			|Para esta factura, seleccione un pedido cuya operación es Envío directo.';
			|tr = 'Belirtilen sipariş uygulanamaz. 
			|Fatura türü ""Stoksuz satış""tır. 
			|Bu fatura için, ""Stoksuz satış"" işlemli bir sipariş seçin.';
			|it = 'L''ordine specificato non è applicabile. 
			|Il tipo di fattura è Dropshipping. 
			|Per questa fattura, selezionare un ordine la cui Operazione è Dropshipping.';
			|de = 'Der angegebene Auftrag ist nicht anwendbar. 
			|Der Rechnungstyp ist Streckengeschäft. 
			|Für diese Rechnung wählen Sie einen Auftrag mit Operation Streckengeschäft aus.'");
		
		If PurchaseOrderPosition = Enums.AttributeStationing.InHeader Then
			OperationPO = Common.ObjectAttributeValue(Order, "OperationKind");
			If OperationPO <> Enums.OperationTypesPurchaseOrder.OrderForDropShipping Then
				DriveServer.ShowMessageAboutError(
					,
					MessageText,
					Undefined,
					Undefined,
					"Order",
					Cancel);
			EndIf;
		Else 
			For Each ItemInvetory In Inventory Do
				OperationPO = Common.ObjectAttributeValue(ItemInvetory.Order, "OperationKind");
				If OperationPO <> Enums.OperationTypesPurchaseOrder.OrderForDropShipping Then
					DriveServer.ShowMessageAboutError(
						,
						MessageText,
						"Inventory",
						ItemInvetory.LineNumber,
						Undefined,
						Cancel);
				EndIf;
			EndDo;
		EndIf;
		
		For Each ItemInvetory In Inventory Do
			
			If ItemInvetory.GoodsReceipt = Documents.GoodsReceipt.EmptyRef() Then
				Continue;
			EndIf;
			
			OperationGR = Common.ObjectAttributeValue(ItemInvetory.GoodsReceipt, "OperationType");
			If OperationGR <> Enums.OperationTypesGoodsReceipt.DropShipping Then
				DriveServer.ShowMessageAboutError(
					,
					MessageText,
					"Inventory",
					ItemInvetory.LineNumber,
					Undefined,
					Cancel);
				EndIf;
			EndDo;
		
	EndIf;
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	If ForOpeningBalancesOnly Then
		Return;
	EndIf;
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	// Document data initialization.
	Documents.SupplierInvoice.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	//Limit Exceed Control
	DriveServer.CheckLimitsExceed(ThisObject, False, Cancel);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectBackorders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectReservedProducts(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPurchases(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectGoodsAwaitingCustomsClearance(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPurchaseOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectGoodsReceivedNotInvoiced(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectGoodsInvoicedNotReceived(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPOSSummary(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectStockTransferredToThirdParties(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.ReflectUsingPaymentTermsInDocuments(Ref, Cancel);
	
	// Serial numbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
	
	//VAT
	DriveServer.ReflectVATIncurred(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectVATInput(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectVATOutput(AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.ReflectTaxesSettlements(AdditionalProperties, RegisterRecords, Cancel);
	
	// Offline registers
	DriveServer.ReflectInventoryCostLayer(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Subordinate tax invoice
	If Not Cancel
		And OperationKind <> Enums.OperationTypesSupplierInvoice.ZeroInvoice Then
		
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.Posting, Ref, DeletionMark);
		
	EndIf;
	
	// Control of occurrence of a negative balance.
	Documents.SupplierInvoice.RunControl(Ref, AdditionalProperties, Cancel);
	
	// Recording prices in information register Prices of counterparty products.
	Documents.SupplierInvoice.RecordVendorPrices(Ref);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	// Subordinate documents
	If Not Cancel Then
		
		If OperationKind <> Enums.OperationTypesSupplierInvoice.ZeroInvoice Then
			WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.Posting, Ref, DeletionMark);
		EndIf;
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref,
			DocumentWriteMode.Posting,
			DeletionMark,
			Company,
			Date,
			AdditionalProperties);
		
	EndIf;
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	If ForOpeningBalancesOnly Then
		Return;
	EndIf;
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Subordinate documents
	If Not Cancel Then
		
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.UndoPosting, Ref, DeletionMark);
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
	
	// Control of occurrence of a negative balance.
	Documents.SupplierInvoice.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	// Deleting the prices from information register Prices of counterparty products.
	DriveServer.DeleteVendorPrices(Ref);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);
	
	If Not Cancel Then
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
	EndIf;
	
	InventoryReservationServer.ClearReserves(ThisObject);
	
EndProcedure

// Procedure checks the existence of retail price.
//
Procedure CheckExistenceOfRetailPrice(Cancel)
	
	If StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
		Or StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
		
		Query = New Query;
		Query.SetParameter("Date", Date);
		Query.SetParameter("DocumentTable", Inventory);
		Query.SetParameter("RetailPriceKind", StructuralUnit.RetailPriceKind);
		Query.SetParameter("ListProducts", Inventory.UnloadColumn("Products"));
		Query.SetParameter("ListCharacteristic", Inventory.UnloadColumn("Characteristic"));
		
		Query.Text =
		"SELECT
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.Products AS Products,
		|	DocumentTable.Characteristic AS Characteristic,
		|	DocumentTable.Batch AS Batch
		|INTO InventoryTransferInventory
		|FROM
		|	&DocumentTable AS DocumentTable
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	InventoryTransferInventory.LineNumber AS LineNumber,
		|	PRESENTATION(InventoryTransferInventory.Products) AS ProductsPresentation,
		|	PRESENTATION(InventoryTransferInventory.Characteristic) AS CharacteristicPresentation,
		|	PRESENTATION(InventoryTransferInventory.Batch) AS BatchPresentation
		|FROM
		|	InventoryTransferInventory AS InventoryTransferInventory
		|		LEFT JOIN InformationRegister.Prices.SliceLast(
		|				&Date,
		|				PriceKind = &RetailPriceKind
		|					AND Products IN (&ListProducts)
		|					AND Characteristic IN (&ListCharacteristic)) AS PricesSliceLast
		|		ON InventoryTransferInventory.Products = PricesSliceLast.Products
		|			AND InventoryTransferInventory.Characteristic = PricesSliceLast.Characteristic
		|WHERE
		|	ISNULL(PricesSliceLast.Price, 0) = 0";
		
		SelectionOfQueryResult = Query.Execute().Select();
		
		While SelectionOfQueryResult.Next() Do
			
			MessageText = NStr("en = 'For products %ProductsPresentation% in string %LineNumber% of list ""Inventory"" retail price is not set.'; ru = 'Для номенклатуры %ProductsPresentation% в строке %LineNumber% списка ""Запасы"" не установлена розничная цена.';pl = 'Nie ustawiono ceny detalicznej dla produktu %ProductsPresentation% w wierszu %LineNumber% listy ""Zapasy"".';es_ES = 'Para productos %ProductsPresentation% en la línea %LineNumber% de la lista ""Inventario"" el precio de la venta al por menor no está establecido.';es_CO = 'Para productos %ProductsPresentation% en la línea %LineNumber% de la lista ""Inventario"" el precio de la venta al por menor no está establecido.';tr = '""Stok"" listesinin %LineNumber% dizisindeki %ProductsPresentation% ürünleri için satış fiyatı belirlenmedi.';it = 'Per gli articoli %ProductsPresentation% nella stringa %LineNumber% del elenco ""Scorte"" il prezzo al dettaglio non è impostato.';de = 'Für Produkte %ProductsPresentation% in Zeichenfolge %LineNumber% der Liste ""Bestand"" ist der Verkaufspreis nicht festgelegt.'");
			MessageText = StrReplace(MessageText, "%LineNumber%", String(SelectionOfQueryResult.LineNumber));
			MessageText = StrReplace(MessageText, "%ProductsPresentation%",  DriveServer.PresentationOfProducts(SelectionOfQueryResult.ProductsPresentation, SelectionOfQueryResult.CharacteristicPresentation, SelectionOfQueryResult.BatchPresentation));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Inventory",
				SelectionOfQueryResult.LineNumber,
				"Products",
				Cancel);
			
		EndDo;
	 
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DriveServer.CheckDocumentsReposting(Ref, AdditionalProperties.Posted, Cancel);
	
	// Subordinate documents
	If Not Cancel And AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		
		WorkWithVAT.SubordinatedTaxInvoiceControl(AdditionalProperties.WriteMode, Ref, DeletionMark);
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref,
			DocumentWriteMode.Write,
			DeletionMark,
			Company,
			Date,
			AdditionalProperties);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Internal

Procedure FillByStructure(FillingData) Export
	
	If FillingData.Property("ArrayOfPurchaseOrders") Then
		FillByPurchaseOrder(FillingData);
	ElsIf FillingData.Property("GoodsReceiptArray") Then
		FillByGoodsReceipt(FillingData);
	EndIf;
	
EndProcedure

// Procedure fills advances.
//
Procedure FillPrepayment() Export
	
	OrderInHeader = (PurchaseOrderPosition = Enums.AttributeStationing.InHeader);
	ParentCompany = DriveServer.GetCompany(Company);
	
	OrdersTable = New ValueTable;
	OrdersTable.Columns.Add("Order");
	OrdersTable.Columns.Add("Total");
	OrdersTable.Columns.Add("TotalCalc");
	
	ExchangeRateMethod = DriveServer.GetExchangeMethod(Company);
	If ValueIsFilled(Counterparty) Then
		DoOperationsByOrders = Common.ObjectAttributeValue(Counterparty, "DoOperationsByOrders");
	Else
		DoOperationsByOrders = False;
	EndIf;
	
	For Each CurRow In Inventory Do
		NewRow = OrdersTable.Add();
		If Not DoOperationsByOrders Then
			NewRow.Order = Undefined;
		ElsIf OrderInHeader Then
			NewRow.Order = Order;
		Else
			NewRow.Order = ?(CurRow.Order = Documents.PurchaseOrder.EmptyRef(), Undefined, CurRow.Order);
		EndIf;
		NewRow.Total = CurRow.Total;
		NewRow.TotalCalc = DriveServer.RecalculateFromCurrencyToCurrency(
			NewRow.Total,
			ExchangeRateMethod,
			ExchangeRate,
			ContractCurrencyExchangeRate,
			Multiplicity,
			ContractCurrencyMultiplicity);
	EndDo;
	
	For Each CurRow In Expenses Do
		NewRow = OrdersTable.Add();
		If Not DoOperationsByOrders Then
			NewRow.Order = Undefined;
		ElsIf OrderInHeader Then
			NewRow.Order = Order;
		Else
			NewRow.Order = ?(CurRow.PurchaseOrder = Documents.PurchaseOrder.EmptyRef(), Undefined, CurRow.PurchaseOrder);
		EndIf;
		NewRow.Total = CurRow.Total;
		NewRow.TotalCalc = DriveServer.RecalculateFromCurrencyToCurrency(
			NewRow.Total,
			ExchangeRateMethod,
			ExchangeRate,
			ContractCurrencyExchangeRate,
			Multiplicity,
			ContractCurrencyMultiplicity);
	EndDo;
	OrdersTable.GroupBy("Order", "Total, TotalCalc");
	OrdersTable.Sort("Order Asc");
	
	SetPrivilegedMode(True);
	
	// Filling prepayment details.
	Query = New Query;
	
	QueryText =
	"SELECT
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.DocumentDate AS DocumentDate,
	|	AccountsPayableBalances.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	SUM(AccountsPayableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsPayableBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableAccountsPayableBalances
	|FROM
	|	(SELECT
	|		AccountsPayableBalances.Contract AS Contract,
	|		AccountsPayableBalances.Document AS Document,
	|		AccountsPayableBalances.Document.Date AS DocumentDate,
	|		AccountsPayableBalances.Order AS Order,
	|		AccountsPayableBalances.AmountBalance AS AmountBalance,
	|		AccountsPayableBalances.AmountCurBalance AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsPayable.Balance(
	|				&Period,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					AND Contract = &Contract
	|					AND Order IN (&Order)
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsPayableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsVendorSettlements.Contract,
	|		DocumentRegisterRecordsVendorSettlements.Document,
	|		DocumentRegisterRecordsVendorSettlements.Document.Date,
	|		DocumentRegisterRecordsVendorSettlements.Order,
	|		CASE
	|			WHEN DocumentRegisterRecordsVendorSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -DocumentRegisterRecordsVendorSettlements.Amount
	|			ELSE DocumentRegisterRecordsVendorSettlements.Amount
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsVendorSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -DocumentRegisterRecordsVendorSettlements.AmountCur
	|			ELSE DocumentRegisterRecordsVendorSettlements.AmountCur
	|		END
	|	FROM
	|		AccumulationRegister.AccountsPayable AS DocumentRegisterRecordsVendorSettlements
	|	WHERE
	|		DocumentRegisterRecordsVendorSettlements.Recorder = &Ref
	|		AND DocumentRegisterRecordsVendorSettlements.Company = &Company
	|		AND DocumentRegisterRecordsVendorSettlements.Counterparty = &Counterparty
	|		AND DocumentRegisterRecordsVendorSettlements.Contract = &Contract
	|		AND DocumentRegisterRecordsVendorSettlements.Order IN(&Order)
	|		AND DocumentRegisterRecordsVendorSettlements.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsPayableBalances
	|
	|GROUP BY
	|	AccountsPayableBalances.Document,
	|	AccountsPayableBalances.Order,
	|	AccountsPayableBalances.DocumentDate,
	|	AccountsPayableBalances.Contract.SettlementsCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.DocumentDate AS DocumentDate,
	|	AccountsPayableBalances.SettlementsCurrency AS SettlementsCurrency,
	|	-AccountsPayableBalances.AmountCurBalance AS SettlementsAmount,
	|	-AccountsPayableBalances.AmountBalance AS PaymentAmount,
	|	CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN CASE
	|					WHEN AccountsPayableBalances.AmountBalance <> 0
	|						THEN AccountsPayableBalances.AmountCurBalance / AccountsPayableBalances.AmountBalance
	|					ELSE 1
	|				END
	|		ELSE CASE
	|				WHEN AccountsPayableBalances.AmountCurBalance <> 0
	|					THEN AccountsPayableBalances.AmountBalance / AccountsPayableBalances.AmountCurBalance
	|				ELSE 1
	|			END
	|	END AS ExchangeRate,
	|	1 AS Multiplicity
	|FROM
	|	TemporaryTableAccountsPayableBalances AS AccountsPayableBalances
	|WHERE
	|	AccountsPayableBalances.AmountCurBalance < 0
	|
	|ORDER BY
	|	DocumentDate";
	
	Query.SetParameter("Order", OrdersTable.UnloadColumn("Order"));
	Query.SetParameter("Company", ParentCompany);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Contract", Contract);
	Query.SetParameter("Period", EndOfDay(Date) + 1);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("ExchangeRateMethod", ExchangeRateMethod);
	
	Query.Text = QueryText;
	
	Prepayment.Clear();
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	SetPrivilegedMode(False);
	
	While SelectionOfQueryResult.Next() Do
		
		FoundString = OrdersTable.Find(SelectionOfQueryResult.Order, "Order");
		
		If FoundString.TotalCalc = 0 Then
			Continue;
		EndIf;
		
		If SelectionOfQueryResult.SettlementsAmount <= FoundString.TotalCalc Then // balance amount is less or equal than it is necessary to distribute
			
			NewRow = Prepayment.Add();
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			FoundString.TotalCalc = FoundString.TotalCalc - SelectionOfQueryResult.SettlementsAmount;
			
		Else // Balance amount is greater than it is necessary to distribute
			
			NewRow = Prepayment.Add();
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			NewRow.SettlementsAmount = FoundString.TotalCalc;
			NewRow.PaymentAmount = DriveServer.RecalculateFromCurrencyToCurrency(
				NewRow.SettlementsAmount,
				ExchangeRateMethod,
				SelectionOfQueryResult.ExchangeRate,
				1,
				SelectionOfQueryResult.Multiplicity,
				1);
			FoundString.TotalCalc = 0;
			
		EndIf;
		
		NewRow.AmountDocCur = DriveServer.RecalculateFromCurrencyToCurrency(
			NewRow.SettlementsAmount,
			ExchangeRateMethod,
			ContractCurrencyExchangeRate,
			ExchangeRate,
			ContractCurrencyMultiplicity,
			Multiplicity);
		
	EndDo;
	
	WorkWithVAT.FillPrepaymentVATFromVATInput(ThisObject);
	
EndProcedure

// Procedure of document filling based on purchase order.
//
// Parameters:
// FillingData - Structure - Document filling data
//	
Procedure FillByPurchaseOrder(FillingData) Export
	
	// Document basis and document setting.
	If TypeOf(FillingData) = Type("Structure") And FillingData.Property("ArrayOfPurchaseOrders") Then
		OrdersArray = FillingData.ArrayOfPurchaseOrders;
		If FillingData.Property("DropShipping") And FillingData.DropShipping And OrdersArray.Count() = 1 Then
			PurchaseOrderPosition = Enums.AttributeStationing.InHeader;
			Order = FillingData.ArrayOfPurchaseOrders[0];
		Else
			PurchaseOrderPosition = Enums.AttributeStationing.InTabularSection;
		EndIf;
	Else
		OrdersArray = New Array;
		OrdersArray.Add(FillingData);
		PurchaseOrderPosition = DriveReUse.GetValueOfSetting("PurchaseOrderPositionInReceiptDocuments");
		If Not ValueIsFilled(PurchaseOrderPosition) Then
			PurchaseOrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
		If PurchaseOrderPosition = Enums.AttributeStationing.InHeader Then
			Order = FillingData;
		EndIf;
	EndIf;
	
	// Header filling.
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	PurchaseOrder.Ref AS BasisRef,
	|	PurchaseOrder.Posted AS BasisPosted,
	|	PurchaseOrder.Closed AS Closed,
	|	PurchaseOrder.OrderState AS OrderState,
	|	PurchaseOrder.StructuralUnit AS StructuralUnitExpense,
	|	PurchaseOrder.Company AS Company,
	|	PurchaseOrder.CompanyVATNumber AS CompanyVATNumber,
	|	PurchaseOrder.Counterparty AS Counterparty,
	|	PurchaseOrder.Contract AS Contract,
	|	Contracts.ProvideEPD AS ProvideEPD,
	|	PurchaseOrder.DocumentCurrency AS DocumentCurrency,
	|	PurchaseOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	PurchaseOrder.IncludeVATInPrice AS IncludeVATInPrice,
	|	PurchaseOrder.VATTaxation AS VATTaxation,
	|	CASE
	|		WHEN PurchaseOrder.SupplierPriceTypes = VALUE(Catalog.SupplierPriceTypes.EmptyRef)
	|			THEN PurchaseOrder.Contract.SupplierPriceTypes
	|		ELSE PurchaseOrder.SupplierPriceTypes
	|	END AS SupplierPriceTypes,
	|	TRUE AS RegisterVendorPrices,
	|	DC_Rates.Rate AS ExchangeRate,
	|	DC_Rates.Repetition AS Multiplicity,
	|	CC_Rates.Rate AS ContractCurrencyExchangeRate,
	|	CC_Rates.Repetition AS ContractCurrencyMultiplicity,
	|	PurchaseOrder.Warehouse AS StructuralUnit,
	|	PurchaseOrder.PettyCash AS PettyCash,
	|	PurchaseOrder.BankAccount AS BankAccount,
	|	PurchaseOrder.PaymentMethod AS PaymentMethod,
	|	PurchaseOrder.CashAssetType AS CashAssetType,
	|	PurchaseOrder.DiscountType AS DiscountType,
	|	PurchaseOrder.ApprovalStatus AS ApprovalStatus
	|INTO TT_PurchaseOrders
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON PurchaseOrder.Contract = Contracts.Ref
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS DC_Rates
	|		ON PurchaseOrder.DocumentCurrency = DC_Rates.Currency
	|			AND PurchaseOrder.Company = DC_Rates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS CC_Rates
	|		ON (Contracts.SettlementsCurrency = CC_Rates.Currency)
	|			AND PurchaseOrder.Company = CC_Rates.Company
	|WHERE
	|	PurchaseOrder.Ref IN(&OrdersArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_PurchaseOrders.BasisRef AS BasisRef,
	|	TT_PurchaseOrders.BasisPosted AS BasisPosted,
	|	TT_PurchaseOrders.Closed AS Closed,
	|	TT_PurchaseOrders.OrderState AS OrderState,
	|	TT_PurchaseOrders.StructuralUnitExpense AS StructuralUnitExpense,
	|	TT_PurchaseOrders.Company AS Company,
	|	TT_PurchaseOrders.CompanyVATNumber AS CompanyVATNumber,
	|	TT_PurchaseOrders.Counterparty AS Counterparty,
	|	TT_PurchaseOrders.Contract AS Contract,
	|	TT_PurchaseOrders.ProvideEPD AS ProvideEPD,
	|	TT_PurchaseOrders.DocumentCurrency AS DocumentCurrency,
	|	TT_PurchaseOrders.AmountIncludesVAT AS AmountIncludesVAT,
	|	TT_PurchaseOrders.IncludeVATInPrice AS IncludeVATInPrice,
	|	TT_PurchaseOrders.VATTaxation AS VATTaxation,
	|	TT_PurchaseOrders.SupplierPriceTypes AS SupplierPriceTypes,
	|	TT_PurchaseOrders.RegisterVendorPrices AS RegisterVendorPrices,
	|	TT_PurchaseOrders.ExchangeRate AS ExchangeRate,
	|	TT_PurchaseOrders.Multiplicity AS Multiplicity,
	|	TT_PurchaseOrders.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	TT_PurchaseOrders.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	TT_PurchaseOrders.StructuralUnit AS StructuralUnit,
	|	TT_PurchaseOrders.PettyCash AS PettyCash,
	|	TT_PurchaseOrders.BankAccount AS BankAccount,
	|	TT_PurchaseOrders.PaymentMethod AS PaymentMethod,
	|	TT_PurchaseOrders.CashAssetType AS CashAssetType,
	|	TT_PurchaseOrders.DiscountType AS DiscountType,
	|	TT_PurchaseOrders.ApprovalStatus AS ApprovalStatus,
	|	UsePurchaseOrderApproval.Value AS UsePurchaseOrderApproval
	|FROM
	|	TT_PurchaseOrders AS TT_PurchaseOrders
	|		LEFT JOIN Constant.UsePurchaseOrderApproval AS UsePurchaseOrderApproval
	|		ON (TRUE)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	GoodsReceivedNotInvoiced.GoodsReceipt AS GoodsReceipt
	|FROM
	|	TT_PurchaseOrders AS TT_PurchaseOrders
	|		INNER JOIN AccumulationRegister.GoodsReceivedNotInvoiced AS GoodsReceivedNotInvoiced
	|		ON TT_PurchaseOrders.BasisRef = GoodsReceivedNotInvoiced.PurchaseOrder";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	
	QueryResults = Query.ExecuteBatch();
	
	Selection = QueryResults[1].Select();
	While Selection.Next() Do
		VerifiedAttributesValues = New Structure("OrderState, Closed, Posted");
		FillPropertyValues(VerifiedAttributesValues, Selection);
		VerifiedAttributesValues.Insert("Posted", Selection.BasisPosted);
		
		Documents.PurchaseOrder.CheckEnteringAbilityOnTheBasisOfVendorOrder(Selection.BasisRef, VerifiedAttributesValues);
	EndDo;
	
	FillPropertyValues(ThisObject, Selection);
	
	If TypeOf(FillingData) = Type("Structure") 
		And FillingData.Property("DropShipping")
		And FillingData.DropShipping Then
		
		OperationKind = Enums.OperationTypesSupplierInvoice.DropShipping;
		
	EndIf;
	
	If OrdersArray.Count() = 1 Then
		BasisDocument = OrdersArray[0];
	EndIf;
	
	DocumentData = New Structure;
	DocumentData.Insert("Ref",					Ref);
	DocumentData.Insert("Company",				Company);
	DocumentData.Insert("StructuralUnit",		StructuralUnit);
	DocumentData.Insert("AmountIncludesVAT",	AmountIncludesVAT);
	DocumentData.Insert("VATTaxation",			VATTaxation);
	
	Documents.SupplierInvoice.FillByPurchaseOrders(DocumentData, New Structure("OrdersArray", OrdersArray), Inventory, Expenses);
	
	GoodsReceiptsArray = QueryResults[2].Unload().UnloadColumn("GoodsReceipt");
	If GoodsReceiptsArray.Count() Then
		
		ReceivedInventory = Inventory.UnloadColumns();
		
		FilterData = New Structure("ArrayOfGoodsReceipts, Contract", GoodsReceiptsArray, Contract);
		Documents.SupplierInvoice.FillByGoodsReceipts(DocumentData, FilterData, ReceivedInventory, Expenses);
		
		For Each ReceivedProductsRow In ReceivedInventory Do
			If Not OrdersArray.Find(ReceivedProductsRow.Order) = Undefined Then
				FillPropertyValues(Inventory.Add(), ReceivedProductsRow);
			EndIf;
		EndDo;
		
	EndIf;
	
	If Inventory.Count() = 0 Then
		If OrdersArray.Count() = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 has already been invoiced.'; ru = 'Для %1 уже зарегистрирован инвойс.';pl = '%1 został już zafakturowany.';es_ES = '%1 ha sido facturado ya.';es_CO = '%1 ha sido facturado ya.';tr = '%1 zaten faturalandırıldı.';it = '%1 è stato già fatturato.';de = '%1 wurde bereits in Rechnung gestellt.'"),
				OrdersArray[0]);
		Else
			MessageText = NStr("en = 'The selected orders have already been invoiced.'; ru = 'Выбранные заказы уже отражены в учете.';pl = 'Wybrane zamówienia zostały już zafakturowane.';es_ES = 'Las facturas seleccionadas han sido facturadas ya.';es_CO = 'Las facturas seleccionadas han sido facturadas ya.';tr = 'Seçilen siparişler zaten faturalandırıldı';it = 'Gli ordini selezionati sono già stati fatturati.';de = 'Die ausgewählten Aufträge wurden bereits in Rechnung gestellt.'");
		EndIf;
		CommonClientServer.MessageToUser(MessageText, Ref);
	EndIf;
	
	// Cash flow projection
	PaymentTermsServer.FillPaymentCalendarFromDocument(ThisObject, OrdersArray);
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(ThisObject);
	EarlyPaymentDiscountsServer.FillEarlyPaymentDiscounts(ThisObject, Enums.ContractType.WithVendor);
	
EndProcedure

Procedure FillByGoodsReceipt(FillingData) Export
	
	// Document basis and document setting.
	GoodsReceiptArray = New Array;
	Contract = Undefined;
	
	If TypeOf(FillingData) = Type("Structure")
		AND FillingData.Property("GoodsReceiptArray") Then
		
		For Each ArrayItem In FillingData.GoodsReceiptArray Do
			Contract = ArrayItem.Contract;
			GoodsReceiptArray.Add(ArrayItem.Ref);
		EndDo;
		
		GoodsReceipt = GoodsReceiptArray[0];
		
	Else
		GoodsReceiptArray.Add(FillingData.Ref);
		GoodsReceipt = FillingData;
	EndIf;
	
	// Header filling.
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	GoodsReceipt.Ref AS BasisRef,
	|	GoodsReceipt.Posted AS BasisPosted,
	|	GoodsReceipt.Company AS Company,
	|	GoodsReceipt.CompanyVATNumber AS CompanyVATNumber,
	|	GoodsReceipt.StructuralUnit AS StructuralUnit,
	|	GoodsReceipt.Contract AS Contract,
	|	GoodsReceipt.Order AS Order,
	|	GoodsReceipt.Counterparty AS Counterparty,
	|	GoodsReceipt.Cell AS Cell,
	|	GoodsReceipt.OperationType AS OperationType,
	|	GoodsReceipt.DocumentCurrency AS DocumentCurrency,
	|	GoodsReceipt.VATTaxation AS VATTaxation,
	|	GoodsReceipt.AmountIncludesVAT AS AmountIncludesVAT,
	|	GoodsReceipt.IncludeVATInPrice AS IncludeVATInPrice,
	|	GoodsReceipt.DiscountType AS DiscountType
	|INTO GoodsReceiptHeader
	|FROM
	|	Document.GoodsReceipt AS GoodsReceipt
	|WHERE
	|	GoodsReceipt.Ref IN(&ArrayOfGoodsReceipts)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	GoodsReceiptHeader.BasisRef AS BasisRef,
	|	GoodsReceiptHeader.BasisPosted AS BasisPosted,
	|	GoodsReceiptHeader.Company AS Company,
	|	GoodsReceiptHeader.CompanyVATNumber AS CompanyVATNumber,
	|	GoodsReceiptHeader.StructuralUnit AS StructuralUnit,
	|	GoodsReceiptHeader.Counterparty AS Counterparty,
	|	CASE
	|		WHEN GoodsReceiptProducts.Contract <> VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|			THEN GoodsReceiptProducts.Contract
	|		ELSE GoodsReceiptHeader.Contract
	|	END AS Contract,
	|	CASE
	|		WHEN GoodsReceiptProducts.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN GoodsReceiptProducts.Order
	|		ELSE GoodsReceiptHeader.Order
	|	END AS Order,
	|	GoodsReceiptHeader.Cell AS Cell,
	|	GoodsReceiptHeader.OperationType AS OperationType,
	|	GoodsReceiptHeader.DocumentCurrency AS DocumentCurrency,
	|	GoodsReceiptHeader.VATTaxation AS VATTaxation,
	|	GoodsReceiptHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	GoodsReceiptHeader.IncludeVATInPrice AS IncludeVATInPrice,
	|	GoodsReceiptHeader.DiscountType AS DiscountType
	|INTO GIFiltred
	|FROM
	|	GoodsReceiptHeader AS GoodsReceiptHeader
	|		LEFT JOIN Document.GoodsReceipt.Products AS GoodsReceiptProducts
	|		ON GoodsReceiptHeader.BasisRef = GoodsReceiptProducts.Ref
	|WHERE
	|	(GoodsReceiptProducts.Contract = &Contract
	|			OR &Contract = VALUE(Catalog.CounterpartyContracts.EmptyRef))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	GIFiltred.BasisRef AS BasisRef,
	|	GIFiltred.BasisPosted AS BasisPosted,
	|	GIFiltred.Company AS Company,
	|	GIFiltred.CompanyVATNumber AS CompanyVATNumber,
	|	GIFiltred.StructuralUnit AS StructuralUnit,
	|	GIFiltred.Counterparty AS Counterparty,
	|	GIFiltred.Contract AS Contract,
	|	GIFiltred.Order AS Order,
	|	CASE
	|		WHEN GIFiltred.DocumentCurrency = VALUE(Catalog.Currencies.EmptyRef)
	|			THEN PurchaseOrder.DocumentCurrency
	|		ELSE GIFiltred.DocumentCurrency
	|	END AS DocumentCurrency,
	|	CASE
	|		WHEN GIFiltred.VATTaxation = VALUE(Enum.VATTaxationTypes.EmptyRef)
	|			THEN PurchaseOrder.VATTaxation
	|		ELSE GIFiltred.VATTaxation
	|	END AS VATTaxation,
	|	CASE
	|		WHEN GIFiltred.VATTaxation = VALUE(Enum.VATTaxationTypes.EmptyRef)
	|			THEN PurchaseOrder.AmountIncludesVAT
	|		ELSE GIFiltred.AmountIncludesVAT
	|	END AS AmountIncludesVAT,
	|	CASE
	|		WHEN GIFiltred.VATTaxation = VALUE(Enum.VATTaxationTypes.EmptyRef)
	|			THEN PurchaseOrder.IncludeVATInPrice
	|		ELSE GIFiltred.IncludeVATInPrice
	|	END AS IncludeVATInPrice,
	|	DC_Rates.Rate AS ExchangeRate,
	|	DC_Rates.Repetition AS Multiplicity,
	|	CC_Rates.Rate AS ContractCurrencyExchangeRate,
	|	CC_Rates.Repetition AS ContractCurrencyMultiplicity,
	|	PurchaseOrder.PaymentMethod AS PaymentMethod,
	|	PurchaseOrder.CashAssetType AS CashAssetType,
	|	PurchaseOrder.PettyCash AS PettyCash,
	|	PurchaseOrder.SetPaymentTerms AS SetPaymentTerms,
	|	PurchaseOrder.BankAccount AS BankAccount,
	|	GIFiltred.Cell AS Cell,
	|	GIFiltred.OperationType AS OperationType,
	|	GIFiltred.DiscountType AS DiscountType
	|FROM
	|	GIFiltred AS GIFiltred
	|		LEFT JOIN Document.PurchaseOrder AS PurchaseOrder
	|		ON GIFiltred.Order = PurchaseOrder.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON GIFiltred.Contract = Contracts.Ref
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS DC_Rates
	|		ON (CASE
	|				WHEN GIFiltred.DocumentCurrency = VALUE(Catalog.Currencies.EmptyRef)
	|					THEN PurchaseOrder.DocumentCurrency
	|				ELSE GIFiltred.DocumentCurrency
	|			END = DC_Rates.Currency)
	|			AND GIFiltred.Company = DC_Rates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS CC_Rates
	|		ON (Contracts.SettlementsCurrency = CC_Rates.Currency)
	|			AND GIFiltred.Company = CC_Rates.Company";
	
	Query.SetParameter("ArrayOfGoodsReceipts",	GoodsReceiptArray);
	Query.SetParameter("DocumentDate",			?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("Contract",				Contract);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Documents.GoodsReceipt.CheckAbilityOfEnteringByGoodsReceipt(ThisObject, Selection.BasisRef, Selection.BasisPosted, Selection.OperationType);
	EndDo;
	
	FillPropertyValues(ThisObject, Selection);
	
	If TypeOf(FillingData) = Type("Structure") 
		And FillingData.Property("DropShipping")
		And FillingData.DropShipping Then
		
		OperationKind = Enums.OperationTypesSupplierInvoice.DropShipping;
		
	EndIf;
	
	If GoodsReceiptArray.Count() = 1 Then
		BasisDocument = GoodsReceiptArray[0];
	EndIf;
	
	DocumentData = New Structure;
	DocumentData.Insert("Ref",					Ref);
	DocumentData.Insert("Company",				Company);
	DocumentData.Insert("StructuralUnit",		StructuralUnit);
	DocumentData.Insert("AmountIncludesVAT",	AmountIncludesVAT);
	DocumentData.Insert("VATTaxation",			VATTaxation);

	Documents.SupplierInvoice.FillByGoodsReceipts(DocumentData, New Structure("ArrayOfGoodsReceipts, Contract", GoodsReceiptArray, Contract), Inventory, Expenses);

	OrdersTable = Inventory.Unload(, "Order, GoodsReceipt");
	OrdersTable.GroupBy("Order, GoodsReceipt");
	If OrdersTable.Count() > 1 Then
		PurchaseOrderPosition = Enums.AttributeStationing.InTabularSection;
	Else
		
		PurchaseOrderPosition = DriveReUse.GetValueOfSetting("PurchaseOrderPositionInReceiptDocuments");
		If Not ValueIsFilled(PurchaseOrderPosition) Then
			PurchaseOrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
		
	EndIf;

	If PurchaseOrderPosition = Enums.AttributeStationing.InTabularSection Then
		Order = Undefined;
	ElsIf Not ValueIsFilled(Order) AND GoodsReceiptArray.Count() > 0 Then
		Order = GoodsReceiptArray[0].Order;
	EndIf;
	
	If Inventory.Count() = 0 Then
		If GoodsReceiptArray.Count() = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 has already been invoiced.'; ru = 'Для %1 уже зарегистрирован инвойс.';pl = '%1 został już zafakturowany.';es_ES = '%1 ha sido facturado ya.';es_CO = '%1 ha sido facturado ya.';tr = '%1 zaten faturalandırıldı.';it = '%1 è stato già fatturato.';de = '%1 wurde bereits in Rechnung gestellt.'"),
				GoodsReceiptArray[0]);
		Else
			MessageText = NStr("en = 'The selected goods receipts have already been invoiced.'; ru = 'Выбранные документы ""Поступление товаров"" уже отражены в учете.';pl = 'Wybrane wpływy kasowe, dotyczące towarów, zostały już zafakturowane.';es_ES = 'Las recepciones de los productos seleccionados han sido facturadas ya.';es_CO = 'Las recepciones de los productos seleccionados han sido facturadas ya.';tr = 'Seçilen Ambar girişleri zaten faturalandırıldı.';it = 'Le merci ricevute selezionate sono già state fatturate.';de = 'Die ausgewählten Wareneingänge wurden bereits in Rechnung gestellt.'");
		EndIf;
		CommonClientServer.MessageToUser(MessageText, Ref);
	EndIf;
	
	IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInDocument(ThisObject, GoodsReceiptArray);
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, GoodsReceiptArray);
	EndIf;
	
	// Cash flow projection
	OrdersArray = OrdersTable.UnloadColumn("Order");
	
	PaymentTermsServer.FillPaymentCalendarFromDocument(ThisObject, OrdersArray);
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(ThisObject);
	EarlyPaymentDiscountsServer.FillEarlyPaymentDiscounts(ThisObject, Enums.ContractType.WithVendor);
	
EndProcedure

// Procedure of document filling based on purchase order.
//
// Parameters:
// FillingData - Structure - Document filling data
//	
Procedure FillBySupplierQuote(FillingData) Export
	
	// Filling out a document header.
	BasisDocument = FillingData.Ref;
	
	Order = Undefined;
	
	Company = FillingData.Company;
	CompanyVATNumber = FillingData.CompanyVATNumber;
	Counterparty = FillingData.Counterparty;
	Contract = FillingData.Contract;
	DocumentCurrency = FillingData.DocumentCurrency;
	AmountIncludesVAT = FillingData.AmountIncludesVAT;
	VATTaxation = FillingData.VATTaxation;
	DiscountType = FillingData.DiscountType;
	SupplierPriceTypes = FillingData.SupplierPriceTypes;
	If Not ValueIsFilled(SupplierPriceTypes) Then
		SupplierPriceTypes = Contract.SupplierPriceTypes;
	EndIf;
	Department = FillingData.Department;
	
	RegisterVendorPrices = ValueIsFilled(SupplierPriceTypes);
	
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Date, DocumentCurrency, Company);
	ExchangeRate = StructureByCurrency.Rate;
	Multiplicity = StructureByCurrency.Repetition;
	SettlementsCurrency = Common.ObjectAttributeValue(Contract, "SettlementsCurrency");
	If DocumentCurrency = SettlementsCurrency Then
		ContractCurrencyExchangeRate = ExchangeRate;
		ContractCurrencyMultiplicity = Multiplicity;
	Else
		StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Date, SettlementsCurrency, Company);
		ContractCurrencyExchangeRate = StructureByCurrency.Rate;
		ContractCurrencyMultiplicity = StructureByCurrency.Repetition;
	EndIf;
	
	// Filling document tabular section.
	Inventory.Clear();
	Expenses.Clear();
	
	For Each TabularSectionRow In FillingData.Inventory Do
		
		AttributeArray = New Array;
		AttributeArray.Add("ProductsType");
		AttributeArray.Add("VATRate");
		
		If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
			AttributeArray.Add("ExpensesGLAccount");
		EndIf;
		
		ProductsData = Common.ObjectAttributesValues(TabularSectionRow.Products, StrConcat(AttributeArray, ","));
		
		If ProductsData.ProductsType = Enums.ProductsTypes.InventoryItem Then
			
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, TabularSectionRow);
			
		ElsIf ProductsData.ProductsType = Enums.ProductsTypes.Service Then
			
			NewRow = Expenses.Add();
			FillPropertyValues(NewRow, TabularSectionRow);
			
			TypePaymentExpenses = Common.ObjectAttributeValue(ProductsData.ExpensesGLAccount, "TypeOfAccount");
			If Not GetFunctionalOption("UseDefaultTypeOfAccounting")
				Or TypePaymentExpenses = Enums.GLAccountsTypes.Expenses
				Or TypePaymentExpenses = Enums.GLAccountsTypes.Revenue
				Or TypePaymentExpenses = Enums.GLAccountsTypes.WorkInProgress
				Or TypePaymentExpenses = Enums.GLAccountsTypes.IndirectExpenses Then
				
				NewRow.StructuralUnit = FillingData.Department;
				
			Else
				
				NewRow.Order = Undefined;
				NewRow.StructuralUnit = Undefined;
				
			EndIf;
			
		EndIf;
		
		DataStructure = New Structure("Amount, VATRate, VATAmount, AmountIncludesVAT, Total");
		DataStructure.Amount = NewRow.Total;
		DataStructure.VATRate = ProductsData.VATRate;
		DataStructure.VATAmount = 0;
		DataStructure.AmountIncludesVAT = False;
		DataStructure.Total = 0;
		
		DataStructure = DriveServer.GetTabularSectionRowSum(DataStructure);
		
		NewRow.ReverseChargeVATRate = DataStructure.VATRate;
		NewRow.ReverseChargeVATAmount = DataStructure.VATAmount;
		
	EndDo;
	
	// Cash flow projection
	FillPropertyValues(ThisObject, FillingData, "PaymentMethod, BankAccount, PettyCash");
	
	PaymentTermsServer.FillPaymentCalendarFromDocument(ThisObject, FillingData);
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(ThisObject);
	
	EarlyPaymentDiscountsServer.FillEarlyPaymentDiscounts(ThisObject, Enums.ContractType.WithVendor);
	
EndProcedure

Procedure FillTabularSectionBySpecification(NodesBillsOfMaterialstack, NodesTable = Undefined) Export
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.LineNumber AS LineNumber,
	|	TableInventory.Quantity AS Quantity,
	|	TableInventory.Factor AS Factor,
	|	TableInventory.Specification AS Specification
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|WHERE
	|	TableInventory.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef)";
	
	If NodesTable = Undefined Then
		Materials.Clear();
		TableInventory = Inventory.Unload();
		Array = New Array();
		Array.Add(Type("Number"));
		TypeDescriptionC = New TypeDescription(Array, , ,New NumberQualifiers(10,3));
		TableInventory.Columns.Add("Factor", TypeDescriptionC);
		For Each StringProducts In TableInventory Do
			If ValueIsFilled(StringProducts.MeasurementUnit)
				AND TypeOf(StringProducts.MeasurementUnit) = Type("CatalogRef.UOM") Then
				StringProducts.Factor = StringProducts.MeasurementUnit.Factor;
			Else
				StringProducts.Factor = 1;
			EndIf;
		EndDo;
		NodesTable = TableInventory.CopyColumns("LineNumber,Quantity,Factor,Specification");
		Query.SetParameter("TableInventory", TableInventory);
	Else
		Query.SetParameter("TableInventory", NodesTable);
	EndIf;
	
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS ProductionLineNumber,
	|	TableInventory.Specification AS ProductionSpecification,
	|	MIN(TableMaterials.LineNumber) AS StructureLineNumber,
	|	TableMaterials.ContentRowType AS ContentRowType,
	|	TableMaterials.Products AS Products,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(TableMaterials.Quantity / TableMaterials.Ref.Quantity * TableInventory.Factor * TableInventory.Quantity) AS Quantity,
	|	TableMaterials.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN TableMaterials.ContentRowType = VALUE(Enum.BOMLineType.Node)
	|				AND VALUETYPE(TableMaterials.MeasurementUnit) = TYPE(Catalog.UOM)
	|				AND TableMaterials.MeasurementUnit <> VALUE(Catalog.UOM.EmptyRef)
	|			THEN TableMaterials.MeasurementUnit.Factor
	|		ELSE 1
	|	END AS Factor,
	|	TableMaterials.CostPercentage AS CostPercentage,
	|	TableMaterials.Specification AS Specification
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
	|		ON (TableMaterials.ContentRowType = VALUE(Enum.BOMLineType.Material))
	|			AND TableInventory.Specification = TableMaterials.Ref,
	|	Constant.UseCharacteristics AS UseCharacteristics
	|WHERE
	|	TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	TableInventory.Specification,
	|	TableMaterials.ContentRowType,
	|	TableMaterials.Products,
	|	TableMaterials.MeasurementUnit,
	|	CASE
	|		WHEN TableMaterials.ContentRowType = VALUE(Enum.BOMLineType.Node)
	|				AND VALUETYPE(TableMaterials.MeasurementUnit) = TYPE(Catalog.UOM)
	|				AND TableMaterials.MeasurementUnit <> VALUE(Catalog.UOM.EmptyRef)
	|			THEN TableMaterials.MeasurementUnit.Factor
	|		ELSE 1
	|	END,
	|	TableMaterials.CostPercentage,
	|	TableMaterials.Specification,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END
	|
	|ORDER BY
	|	ProductionLineNumber,
	|	StructureLineNumber";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If Selection.ContentRowType = Enums.BOMLineType.Node Then
			NodesTable.Clear();
			If Not NodesBillsOfMaterialstack.Find(Selection.Specification) = Undefined Then
				MessageText = NStr("en = 'During filling in of the Specification materials
				                   |tabular section a recursive item occurrence was found'; 
				                   |ru = 'При попытке заполнить табличную
				                   |часть Материалы по спецификации, обнаружено рекурсивное вхождение элемента';
				                   |pl = 'Podczas wypełniania sekcji tabelarycznej
				                   |""Specyfikacja materiałowa"", wykryto rekursywne włączenie elementu';
				                   |es_ES = 'Rellenando la sección tabular
				                   |de Materiales de Especificación, una ocurrencia del artículo recursivo se ha encontrado';
				                   |es_CO = 'Rellenando la sección tabular
				                   |de Materiales de Especificación, una ocurrencia del artículo recursivo se ha encontrado';
				                   |tr = 'Spesifikasyon materyalleri sekme kısmının doldurulması sırasında
				                   |, tekrarlamalı bir öğe oluşumu bulundu.';
				                   |it = 'Durante la compilazione delle Distinte Base dei materiali
				                   |sono stati trovati elementi ricorsivi nella sezione tabellare';
				                   |de = 'Beim Ausfüllen des
				                   |Tabellenbereichs Spezifikationsmaterialien wurde ein rekursives Element gefunden'")+" "+Selection.Products+" "+NStr("en = 'in BOM'; ru = 'в спецификации';pl = 'w zestawieniu materiałowym';es_ES = 'en BOM';es_CO = 'en BOM';tr = 'ürün reçetesinde';it = 'in Distinta Base';de = 'in der Stückliste'")+" "+Selection.ProductionSpecification+"
									|The operation failed.";
				Raise MessageText;
			EndIf;
			NodesBillsOfMaterialstack.Add(Selection.Specification);
			NewRow = NodesTable.Add();
			FillPropertyValues(NewRow, Selection);
			FillTabularSectionBySpecification(NodesBillsOfMaterialstack, NodesTable);
		Else
			NewRow = Materials.Add();
			FillPropertyValues(NewRow, Selection);
		EndIf;
	EndDo;
	
	NodesBillsOfMaterialstack.Clear();
	Materials.GroupBy("Products, Characteristic, MeasurementUnit", "Quantity");
	
EndProcedure

Procedure FillTabularSectionByGoodsBalance() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	StockTransferredToThirdParties.Products AS Products,
	|	StockTransferredToThirdParties.Characteristic AS Characteristic,
	|	StockTransferredToThirdParties.Batch AS Batch,
	|	StockTransferredToThirdParties.QuantityBalance AS Quantity,
	|	ISNULL(StockTransferredToThirdParties.Products.MeasurementUnit, VALUE(Catalog.UOM.EmptyRef)) AS MeasurementUnit
	|FROM
	|	AccumulationRegister.StockTransferredToThirdParties.Balance(
	|			,
	|			Company = &Company
	|				AND Counterparty = &Counterparty) AS StockTransferredToThirdParties
	|		LEFT JOIN Catalog.Products AS ProductsTable
	|		ON StockTransferredToThirdParties.Products = ProductsTable.Ref";
	
	Query.SetParameter("Company",		Company);
	Query.SetParameter("Counterparty",	Counterparty);
	
	Materials.Load(Query.Execute().Unload());
	
EndProcedure

#EndRegion 

#Region Private

Procedure CalculateReverseChargeVATAmount(TabularSectionRow)
	
	If VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT Then
		
		VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.ReverseChargeVATRate);
		TabularSectionRow.ReverseChargeVATAmount = (TabularSectionRow.Total + TabularSectionRow.AmountExpense) * VATRate / 100;
		
	EndIf;
	
EndProcedure

Function ExpensesAmountToBeAllocated()
	
	TotalExpenses = Expenses.Total("Total");
	If VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		TotalExpenses = TotalExpenses - Expenses.Total("VATAmount");
	EndIf;
	
	Return TotalExpenses;
	
EndFunction

Procedure CheckPermissionToChangeWarehouseAndAdvanceInvoicing(Cancel)
	
	If IsNew() Then
		
		Return;
		
	EndIf;
	
	Query = New Query;
	
	Query.Text =
	"SELECT ALLOWED DISTINCT
	|	CustomsDeclarationInventory.Ref AS Ref,
	|	CustomsDeclarationInventory.StructuralUnit AS StructuralUnit,
	|	CustomsDeclarationInventory.AdvanceInvoicing AS AdvanceInvoicing
	|INTO TT_CD
	|FROM
	|	Document.CustomsDeclaration.Inventory AS CustomsDeclarationInventory
	|WHERE
	|	CustomsDeclarationInventory.Invoice = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ISNULL(MAX(TT_CD.StructuralUnit <> &StructuralUnit
	|				AND NOT &IsAdvanceInvoice), FALSE) AS WarehouseHasChanged,
	|	ISNULL(MAX(TT_CD.AdvanceInvoicing <> &IsAdvanceInvoice), FALSE) AS AdvanceInvoicingHasChanged
	|FROM
	|	TT_CD AS TT_CD
	|		INNER JOIN Document.CustomsDeclaration AS CustomsDeclaration
	|		ON TT_CD.Ref = CustomsDeclaration.Ref
	|WHERE
	|	CustomsDeclaration.Posted";
	
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("StructuralUnit", StructuralUnit);
	Query.SetParameter("IsAdvanceInvoice", OperationKind = Enums.OperationTypesSupplierInvoice.AdvanceInvoice);
	
	Sel = Query.Execute().Select();
	
	If Sel.Next() Then
		If Sel.WarehouseHasChanged Then
			MessageText = NStr(
				"en = 'You can''t change the warehouse, because landed costs have already been allocated by the Customs declaration.
				|Please clear posting of the subordinate Customs declaration and try again.'; 
				|ru = 'Невозможно изменить склад – дополнительные расходы уже были распределены в таможенной декларации.
				|Отмените проведение подчиненной таможенной декларации и попробуйте снова.';
				|pl = 'Nie możesz zmienić magazynu, ponieważ koszty własne zostały już przydzielone przez deklarację celną.
				|Prosimy o wyraźne umieszczenie podporządkowanej deklaracji celnej i ponowienie próby.';
				|es_ES = 'Usted no puede cambiar el almacén porque los costes de entrega ya se han asignado por la declaración de la aduana.
				|Por favor, eliminar el envío de la declaración de la aduana subordinada e intentar de nuevo.';
				|es_CO = 'Usted no puede cambiar el almacén porque los costes en destino ya se han asignado por la declaración de Aduanas.
				|Por favor, eliminar el envío de la declaración de Aduanas subordinada e intentar de nuevo.';
				|tr = 'Depoyu değiştiremezsiniz, çünkü Varış yeri maliyetleri Gümrük beyannamesi ile zaten dağıtılmış. 
				| Lütfen alt Gümrük beyannamesi kayıtlarını silin ve tekrar deneyin.';
				|it = 'Non potete modificare il magazzino perchè il costo di scarico è già stato allocato con la dichiarazione doganale.
				|Si prega di cancellare la pubblicazione della Dichiarazione Doganale subordinata e provare nuovamente.';
				|de = 'Das Lager kann nicht geändert werden, da die Wareneinstandspreise bereits durch die Zollanmeldung zugeordnet wurden.
				|Bitte löschen Sie die Buchung der untergeordneten Zollanmeldung und versuchen Sie es erneut.'");
			DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "StructuralUnit", Cancel);
		EndIf;
		If Sel.AdvanceInvoicingHasChanged Then
			MessageText = NStr(
				"en = 'Cannot change the invoice type. 
				|For this invoice, a Customs declaration has already been posted to allocate the landed costs.
				|To be able to change the invoice type, clear posting of this Customs declaration.'; 
				|ru = 'Невозможно изменить тип инвойса. 
				|Для этого инвойса уже проведена таможенная декларация для распределения поступления дополнительных расходов.
				|Для того, чтобы изменить тип инвойса, удалите проведение таможенной декларации.';
				|pl = 'Nie można zmienić typu faktury. 
				|Dla tej faktury, Deklaracja celna jest już zatwierdzona do przydzielenia kosztów wyładunku.
				|Aby mieć możliwość zmienić typ faktury, oczyść zatwierdzenie tej Deklaracji celnej.';
				|es_ES = 'No se puede cambiar el tipo de factura.
				|Para esta factura, ya se ha enviado una Declaración de la aduana para asignar los precios de entrega. 
				|Para poder modificar el tipo de factura, se debe borrar el envío de esta Declaración de la aduana.';
				|es_CO = 'No se puede cambiar el tipo de factura.
				|Para esta factura, ya se ha enviado una Declaración de Aduanas para asignar los precios de entrega. 
				|Para poder modificar el tipo de factura, se debe borrar el envío de esta Declaración de Aduanas.';
				|tr = 'Fatura türü değiştirilemiyor. 
				|Bu fatura için Gümrük beyannamesi varış yeri maliyetlerinin dağıtımı için zaten kaydedildi.
				|Fatura türünü değiştirebilmek için bu Gümrük beyannamesinin kaydını silin.';
				|it = 'Impossibile modificare il tipo di fattura. 
				|Per questa fattura è già stata pubblicata una Dichiarazione doganale per allocare i costi di scarico. 
				|Per modificare il tipo di fattura, cancellare la pubblicazione di questa Dichiarazione doganale.';
				|de = 'Der Rechnungstyp kann nicht geändert werden. 
				|Für diese Rechnung wurde bereits eine Zollanmeldung gebucht, um die Wareneinstandspreise zuzuordnen.
				|Um die Rechnungsart ändern zu können, verbuchen Sie diese Zollanmeldung.'");
			DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "OperationKind", Cancel);
		EndIf;
	EndIf;
	
EndProcedure

Procedure AdvanceInvoicingDateCheck(Cancel)
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	MIN(GoodsInvoicedNotReceived.Period) AS Period
	|FROM
	|	AccumulationRegister.GoodsInvoicedNotReceived AS GoodsInvoicedNotReceived
	|WHERE
	|	GoodsInvoicedNotReceived.SupplierInvoice = &Ref
	|	AND GoodsInvoicedNotReceived.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND GoodsInvoicedNotReceived.Period <= &Date";
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Date", Date);
	
	Sel = Query.Execute().Select();
	If Sel.Next() And ValueIsFilled(Sel.Period) Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'An advance invoice must be dated earlier than its subordinate goods recepts are (%1).'; ru = 'Дата инвойса-фактуры на аванс должна быть меньше, чем даты связанных с ним документов ""Приемка товара"" (%1).';pl = 'Faktura zaliczkowa musi być opatrzona datą wcześniejszą, niż jej podrzędne wpływy kasowe, dot. towarów (%1).';es_ES = 'La factura avanzada debe ser fechada más temprano que las recepciones de los productos subordinadas son (%1).';es_CO = 'La factura Anticipada debe ser fechada más temprano que las recepciones de los productos subordinadas son (%1).';tr = 'Bir avans faturası, alt mal reçetelerinin tarihinden (%1) daha önce tarihli olmalıdır.';it = 'Una fattura di anticipo deve avere una data antecedente alla ricevuto di merci subordinata (%1).';de = 'Eine Rechnung per Vorkasse muss früher datiert sein als ihre untergeordneten Wareneingänge (%1).'"),
			Sel.Period);
		
		CommonClientServer.MessageToUser(MessageText, ThisObject, "Date", , Cancel);
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf