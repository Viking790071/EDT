#Region Public

// See PeriodClosingDatesOverridable.InterfaceSetup
//
Procedure InterfaceSetup(InterfaceSettings) Export
	InterfaceSettings.UseExternalUsers = False;
EndProcedure

// See PeriodClosingDatesOverridable.OnFillChangeProhibitionDateSections
//
Procedure OnFillChangeProhibitionDateSections(Sections) Export
	
	Section = Sections.Add();
	Section.Name  = "ManagementAccounting";
	Section.ID = New UUID("482c72cb-8577-4a26-81bd-76fc1a2af321");
	Section.Presentation = NStr("en = 'Companies'; ru = 'Организации';pl = 'Firmy';es_ES = 'Empresas';es_CO = 'Empresas';tr = 'İş yerleri';it = 'Aziende';de = 'Firmen'", CommonClientServer.DefaultLanguageCode());
	Section.ObjectsTypes.Add(Type("CatalogRef.Companies"));
	
EndProcedure

// See PeriodClosingDatesOverridable.FillDataSourcesForPeriodEndClosingCheck
//
Procedure FillDataSourcesForPeriodEndClosingCheck(DataSources) Export
	
	FillDataSourcesForDocuments(DataSources);
	FillDataSourcesForRegisters(DataSources);
	
EndProcedure

// See PeriodClosingDatesOverridable.BeforeCheckPeriodEndClosing
//
Procedure BeforeCheckPeriodEndClosing(Object,
                                         PeriodEndClosingCheck,
                                         ImportRestrictionCheckNode,
                                         ObjectVersion) Export
	
EndProcedure

#EndRegion

#Region Private

Procedure FillDataSourcesForDocuments(DataSources)
	
	PeriodClosingDates.AddRow(DataSources, "Document.AccountSalesFromConsignee", "Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.AccountSalesToConsignor", 	"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.AccountingTransaction", 	"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.ActualSalesVolume", 		"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.AdditionalExpenses", 		"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.ArApAdjustments", 			"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.BankReconciliation", 		"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.Budget",  					"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.BulkMail", 				"Date", "ManagementAccounting", "");
	PeriodClosingDates.AddRow(DataSources, "Document.CashInflowForecast", 		"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.CashReceipt", 				"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.CashTransfer", 			"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.CashTransferPlan", 		"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.CashVoucher", 				"Date", "ManagementAccounting", "Company");
	// begin Drive.FullVersion
	PeriodClosingDates.AddRow(DataSources, "Document.CostAllocation", 			"Date", "ManagementAccounting", "Company");
	// end Drive.FullVersion
	PeriodClosingDates.AddRow(DataSources, "Document.CreditNote", 				"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.CustomsDeclaration", 		"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.DebitNote", 				"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.DirectDebit", 				"Date", "ManagementAccounting", "Company");
	// begin Drive.FullVersion
	PeriodClosingDates.AddRow(DataSources, "Document.EmployeeTask", 			"Date", "ManagementAccounting", "Company");
	// end Drive.FullVersion
	PeriodClosingDates.AddRow(DataSources, "Document.EmploymentContract", 		"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.Event", 					"Date", "ManagementAccounting", "");
	PeriodClosingDates.AddRow(DataSources, "Document.ExpenditureRequest", 		"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.ExpenseReport", 			"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.FixedAssetDepreciationChanges", "Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.FixedAssetRecognition", 	"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.FixedAssetSale", 			"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.FixedAssetsDepreciation", 	"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.FixedAssetUsage", 			"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.FixedAssetWriteOff", 		"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.ForeignCurrencyExchange", 	"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.GoodsIssue", 				"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.GoodsReceipt", 			"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.IntraWarehouseTransfer", 	"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.InventoryIncrease", 		"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.InventoryReservation", 	"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.InventoryTransfer", 		"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.InventoryWriteOff", 		"Date", "ManagementAccounting", "Company");
	// begin Drive.FullVersion
	PeriodClosingDates.AddRow(DataSources, "Document.JobSheet", 				"Date", "ManagementAccounting", "Company");
	// end Drive.FullVersion
	PeriodClosingDates.AddRow(DataSources, "Document.KitOrder", 				"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.LetterOfAuthority", 		"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.LoanContract", 			"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.LoanInterestCommissionAccruals", "Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.MonthEndClosing", 			"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.OnlinePayment", 			"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.OnlineReceipt", 			"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.OpeningBalanceEntry", 		"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.Operation", 				"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.OtherExpenses", 			"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.PackingSlip", 				"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.PaymentExpense", 			"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.PaymentReceipt", 			"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.Payroll", 					"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.PayrollSheet", 			"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.Pricing", 					"Date", "ManagementAccounting", "Company");
	// begin Drive.FullVersion
	PeriodClosingDates.AddRow(DataSources, "Document.Production",					"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.Manufacturing",				"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.ManufacturingOperation",		"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.ManufacturingOverheadsRates",	"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.ProductionOrder",				"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.ProductionTask",				"Date", "ManagementAccounting", "Company");
	// end Drive.FullVersion
	PeriodClosingDates.AddRow(DataSources, "Document.ProductReturn", 			"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.PurchaseOrder", 			"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.Quote", 					"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.ReconciliationStatement", 	"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.RegistersCorrection", 		"Date", "ManagementAccounting", "");
	PeriodClosingDates.AddRow(DataSources, "Document.RequestForQuotation", 		"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.RequisitionOrder", 		"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.RetailRevaluation", 		"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.RMARequest", 				"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.SalesInvoice", 			"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.SalesOrder", 				"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.SalesSlip", 				"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.SalesTarget", 				"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.ShiftClosure", 			"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.Stocktaking", 				"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.SubcontractorOrderIssued",	"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.SubcontractorInvoiceReceived",	"Date", "ManagementAccounting", "Company");
	// begin Drive.FullVersion
	PeriodClosingDates.AddRow(DataSources, "Document.SubcontractorInvoiceIssued", "Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.SubcontractorOrderReceived", "Date", "ManagementAccounting", "Company");
	// end Drive.FullVersion 
	PeriodClosingDates.AddRow(DataSources, "Document.SupplierInvoice", 			"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.SupplierQuote", 			"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.TaxAccrual", 				"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.TaxInvoiceIssued", 		"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.TaxInvoiceReceived", 		"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.TerminationOfEmployment", 	"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.Timesheet", 				"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.TransferAndPromotion", 	"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.TransferOrder", 			"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.Transformation",			"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.VATInvoiceForICT",			"Date", "ManagementAccounting", "Company");
	// begin Drive.FullVersion
	PeriodClosingDates.AddRow(DataSources, "Document.WeeklyTimesheet", 			"Date", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "Document.WorkcentersAvailability",	"Date", "ManagementAccounting", "");
	// end Drive.FullVersion
	PeriodClosingDates.AddRow(DataSources, "Document.WorkOrder", 				"Date", "ManagementAccounting", "Company");
	
EndProcedure

Procedure FillDataSourcesForRegisters(DataSources)
	
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.AccountsPayable", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.AccountsReceivable", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.AdvanceHolders", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.AutomaticDiscountsApplied", "Period", "ManagementAccounting", "");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.Backorders", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.BankCharges", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.BankReconciliation", "Period", "ManagementAccounting", "BankAccount.Owner");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.CashAssets", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.CashBudget", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.CashInCashRegisters", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.EarningsAndDeductions", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.EmployeeTasks", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.FinancialResult", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.FinancialResultForecast", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.FixedAssets", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.FixedAssetUsage", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.GoodsAwaitingCustomsClearance", "Period", "ManagementAccounting", "Company");
	// begin Drive.FullVersion
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.GoodsConsumedToDeclare", "Period", "ManagementAccounting", "Company");
	// end Drive.FullVersion
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.GoodsInvoicedNotReceived", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.GoodsInvoicedNotShipped", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.GoodsReceivedNotInvoiced", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.GoodsShippedNotInvoiced", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.IncomeAndExpenses", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.IncomeAndExpensesBudget", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.IncomeAndExpensesCashMethod", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.IncomeAndExpensesRetained", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.Inventory", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.InventoryCostLayer", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.InventoryDemand", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.InventoryFlowCalendar", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.InventoryInWarehouses", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.InvoicesAndOrdersPayment", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.LandedCosts", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.LoanSettlements", "Period", "ManagementAccounting", "Company");
	// begin Drive.FullVersion
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.ManufacturingProcessSupply", "Period", "ManagementAccounting", "Reference.Company");
	// end Drive.FullVersion
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.MiscellaneousPayable", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.PackedOrders", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.PaymentCalendar", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.Payroll", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.POSSummary", "Period", "ManagementAccounting", "Company");
	// begin Drive.FullVersion
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.ProductionAccomplishment", "Period", "ManagementAccounting", "WorkInProgress.Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.ProductionOrders", "Period", "ManagementAccounting", "Company");
	// end Drive.FullVersion
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.ProductRelease", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.PurchaseOrders", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.Purchases", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.Quotations", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.ReservedProducts", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.Sales", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.SalesOrders", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.SalesTarget", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.SalesWithCardBasedDiscounts", "Period", "ManagementAccounting", "");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.SerialNumbers", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.StockReceivedFromThirdParties", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.StockTransferredToThirdParties", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.SubcontractComponents", "Period", "ManagementAccounting", "SubcontractorOrder.Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.SubcontractorOrdersIssued", "Period", "ManagementAccounting", "Company");
	// begin Drive.FullVersion
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.SubcontractorOrdersReceived", "Period", "ManagementAccounting", "Company");
	// end Drive.FullVersion
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.TaxPayable", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.Timesheet", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.TransferOrders", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.UnallocatedExpenses", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.VATIncurred", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.VATInput", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.VATOutput", "Period", "ManagementAccounting", "Company");
	// begin Drive.FullVersion
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.WorkInProgress", "Period", "ManagementAccounting", "Company");
	// end Drive.FullVersion
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.Workload", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccumulationRegister.WorkOrders", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccountingRegister.AccountingJournalEntries", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccountingRegister.AccountingJournalEntriesCompound", "Period", "ManagementAccounting", "Company");
	PeriodClosingDates.AddRow(DataSources, "AccountingRegister.AccountingJournalEntriesSimple", "Period", "ManagementAccounting", "Company");
	
	PeriodClosingDates.AddRow(DataSources, "InformationRegister.AccountingPolicy", "Period", "ManagementAccounting", "Company");

EndProcedure

#EndRegion