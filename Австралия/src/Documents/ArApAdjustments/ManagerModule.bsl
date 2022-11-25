#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefArApAdjustments, StructureAdditionalProperties) Export
	
	Query = New Query;
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Ref",								DocumentRefArApAdjustments);
	Query.SetParameter("PointInTime",						New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ArApAdjustments",					NStr("en = 'Setoff'; ru = 'Взаимозачет';pl = 'Rozliczenia wzajemne';es_ES = 'Compensación';es_CO = 'Compensación';tr = 'Mahsuplaştırma';it = 'Setoff';de = 'Aufrechnung'", MainLanguageCode));
	Query.SetParameter("Novation",							NStr("en = 'Debt assignment'; ru = 'Переуступка долга';pl = 'Przeniesienie długu';es_ES = 'Asignación de la deuda';es_CO = 'Asignación de la deuda';tr = 'Borç tahsisi';it = 'Assegnazione del debito';de = 'Schuldenzuordnung'", MainLanguageCode));
	Query.SetParameter("DebtAdjustment",					NStr("en = 'AR/AP Adjustments'; ru = 'Корректировка дебиторской/кредиторской задолженности';pl = 'Korekty Wn/Ma';es_ES = 'Modificaciones de las cuentas a cobrar/las cuentas a pagar';es_CO = 'Modificaciones de las cuentas a cobrar/las cuentas a pagar';tr = 'Alacak/Borç hesapları düzeltmeleri';it = 'Correzioni contabili';de = 'Offene Posten Debitoren/Kreditoren-Korrekturen'", MainLanguageCode));
	Query.SetParameter("CustomerAdvanceClearing",			NStr("en = 'Customer advance clearing'; ru = 'Зачет аванса покупателя';pl = 'Rozliczanie zaliczki nabywcy';es_ES = 'Compensación de pago anticipado del cliente';es_CO = 'Liquidación de anticipo del cliente';tr = 'Müşteri avans mahsubu';it = 'Compensazione anticipi cliente';de = 'Kundenvorschussverrechnung'"));
	Query.SetParameter("UseDefaultTypeOfAccounting",		StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.Text =
	"SELECT
	|	DocumentTable.AdvanceFlag AS AdvanceFlag,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordType,
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Ref.OperationKind AS OperationKind,
	|	DocumentTable.Ref.CounterpartySource AS Counterparty,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByContracts AS DoOperationsByContracts,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByOrders AS DoOperationsByOrders,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.Contract.SettlementsCurrency AS Currency,
	|	DocumentTable.Order AS Order,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS Correspondence,
	|	FALSE AS RegisterExpense,
	|	FALSE AS RegisterIncome,
	|	DocumentTable.ExpenseItem AS ExpenseItem,
	|	DocumentTable.IncomeItem AS IncomeItem,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.AdvancesReceivedGLAccount
	|		ELSE DocumentTable.AccountsReceivableGLAccount
	|	END AS GLAccount,
	|	DocumentTable.Ref.Date AS Date,
	|	SUM(DocumentTable.SettlementsAmount) AS SettlementsAmount,
	|	SUM(DocumentTable.AccountingAmount) AS AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN SUM(DocumentTable.SettlementsAmount)
	|		ELSE -SUM(DocumentTable.SettlementsAmount)
	|	END AS SettlementsAmountBalance,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN SUM(DocumentTable.AccountingAmount)
	|		ELSE -SUM(DocumentTable.AccountingAmount)
	|	END AS AccountingAmountBalance,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN &ArApAdjustments
	|		ELSE &Novation
	|	END AS ContentOfAccountingRecord
	|INTO TemporaryTableCustomers
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment))
	|
	|GROUP BY
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	DocumentTable.Document,
	|	DocumentTable.Ref,
	|	DocumentTable.Contract,
	|	DocumentTable.Order,
	|	DocumentTable.AdvanceFlag,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.CounterpartySource,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.AdvancesReceivedGLAccount
	|		ELSE DocumentTable.AccountsReceivableGLAccount
	|	END,
	|	DocumentTable.Ref.Date,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.Correspondence.TypeOfAccount
	|		ELSE VALUE(Enum.GLAccountsTypes.EmptyRef)
	|	END,
	|	DocumentTable.ExpenseItem,
	|	DocumentTable.IncomeItem,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByContracts,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByOrders
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.AdvanceFlag,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterExpense
	|			THEN VALUE(AccumulationRecordType.Expense)
	|		ELSE VALUE(AccumulationRecordType.Receipt)
	|	END,
	|	MAX(DocumentTable.LineNumber),
	|	CASE
	|		WHEN DocumentTable.Document = UNDEFINED
	|			THEN &Ref
	|		ELSE DocumentTable.Document
	|	END,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.CounterpartySource,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByContracts,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByOrders,
	|	DocumentTable.Contract,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	DocumentTable.Order,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	DocumentTable.Ref.RegisterExpense,
	|	DocumentTable.Ref.RegisterIncome,
	|	DocumentTable.ExpenseItem,
	|	DocumentTable.IncomeItem,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.AdvancesReceivedGLAccount
	|		ELSE DocumentTable.AccountsReceivableGLAccount
	|	END,
	|	DocumentTable.Ref.Date,
	|	SUM(DocumentTable.SettlementsAmount),
	|	SUM(DocumentTable.AccountingAmount),
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterIncome
	|			THEN SUM(DocumentTable.SettlementsAmount)
	|		ELSE -SUM(DocumentTable.SettlementsAmount)
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterIncome
	|			THEN SUM(DocumentTable.AccountingAmount)
	|		ELSE -SUM(DocumentTable.AccountingAmount)
	|	END,
	|	&DebtAdjustment
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAdjustment)
	|
	|GROUP BY
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	DocumentTable.AdvanceFlag,
	|	DocumentTable.IncomeItem,
	|	DocumentTable.Document,
	|	DocumentTable.Ref,
	|	DocumentTable.Contract,
	|	DocumentTable.Order,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.CounterpartySource,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	DocumentTable.ExpenseItem,
	|	DocumentTable.Ref.Date,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	DocumentTable.Ref.RegisterExpense,
	|	DocumentTable.Ref.RegisterIncome,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByContracts,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByOrders,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.AdvancesReceivedGLAccount
	|		ELSE DocumentTable.AccountsReceivableGLAccount
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.AdvanceFlag,
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN VALUE(Enum.SettlementsTypes.Advance)
	|					ELSE VALUE(Enum.SettlementsTypes.Debt)
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN VALUE(Enum.SettlementsTypes.Advance)
	|				ELSE VALUE(Enum.SettlementsTypes.Debt)
	|			END
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN VALUE(AccumulationRecordType.Expense)
	|					ELSE VALUE(AccumulationRecordType.Receipt)
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN VALUE(AccumulationRecordType.Expense)
	|				ELSE VALUE(AccumulationRecordType.Receipt)
	|			END
	|	END,
	|	MAX(DocumentTable.LineNumber),
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN &Ref
	|		ELSE DocumentTable.Ref.AccountsDocument
	|	END,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.Counterparty,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Ref.Contract,
	|	DocumentTable.Ref.Contract.SettlementsCurrency,
	|	DocumentTable.Ref.Order,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	FALSE,
	|	FALSE,
	|	DocumentTable.ExpenseItem,
	|	DocumentTable.IncomeItem,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.AdvancesReceivedGLAccount
	|		ELSE DocumentTable.AccountsReceivableGLAccount
	|	END,
	|	DocumentTable.Ref.Date,
	|	CAST(SUM(CASE
	|			WHEN DocumentTable.Ref.AccountingAmount = 0
	|				THEN 0
	|			ELSE DocumentTable.AccountingAmount / DocumentTable.Ref.AccountingAmount * DocumentTable.Ref.SettlementsAmount
	|		END) AS NUMBER(15, 2)),
	|	SUM(DocumentTable.AccountingAmount),
	|	CAST(CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN -1
	|					ELSE 1
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN -1
	|				ELSE 1
	|			END
	|	END * SUM(CASE
	|			WHEN DocumentTable.Ref.AccountingAmount = 0
	|				THEN 0
	|			ELSE DocumentTable.AccountingAmount / DocumentTable.Ref.AccountingAmount * DocumentTable.Ref.SettlementsAmount
	|		END) AS NUMBER(15, 2)),
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN -SUM(DocumentTable.AccountingAmount)
	|					ELSE SUM(DocumentTable.AccountingAmount)
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN -SUM(DocumentTable.AccountingAmount)
	|				ELSE SUM(DocumentTable.AccountingAmount)
	|			END
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN &ArApAdjustments
	|		ELSE &Novation
	|	END
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment)
	|
	|GROUP BY
	|	DocumentTable.AdvanceFlag,
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN VALUE(Enum.SettlementsTypes.Advance)
	|					ELSE VALUE(Enum.SettlementsTypes.Debt)
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN VALUE(Enum.SettlementsTypes.Advance)
	|				ELSE VALUE(Enum.SettlementsTypes.Debt)
	|			END
	|	END,
	|	DocumentTable.Document,
	|	DocumentTable.Ref,
	|	DocumentTable.Contract,
	|	DocumentTable.Order,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.Counterparty,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.AdvancesReceivedGLAccount
	|		ELSE DocumentTable.AccountsReceivableGLAccount
	|	END,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Ref.Contract,
	|	DocumentTable.Ref.Contract.SettlementsCurrency,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN &Ref
	|		ELSE DocumentTable.Ref.AccountsDocument
	|	END,
	|	DocumentTable.ExpenseItem,
	|	DocumentTable.IncomeItem,
	|	DocumentTable.Ref.Order,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN VALUE(AccumulationRecordType.Expense)
	|					ELSE VALUE(AccumulationRecordType.Receipt)
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN VALUE(AccumulationRecordType.Expense)
	|				ELSE VALUE(AccumulationRecordType.Receipt)
	|			END
	|	END,
	|	DocumentTable.Ref.AdvanceFlag,
	|	DocumentTable.Ref.AccountsDocument
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.AdvanceFlag,
	|	VALUE(Enum.SettlementsTypes.Advance),
	|	VALUE(AccumulationRecordType.Receipt),
	|	MAX(DocumentTable.LineNumber),
	|	CASE
	|		WHEN DocumentTable.Document = UNDEFINED
	|			THEN &Ref
	|		ELSE DocumentTable.Document
	|	END,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.CounterpartySource,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByContracts,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByOrders,
	|	DocumentTable.Contract,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	DocumentTable.Order,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	FALSE,
	|	FALSE,
	|	DocumentTable.ExpenseItem,
	|	DocumentTable.IncomeItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	DocumentTable.Ref.Date,
	|	SUM(DocumentTable.SettlementsAmount),
	|	SUM(DocumentTable.AccountingAmount),
	|	SUM(DocumentTable.SettlementsAmount),
	|	SUM(DocumentTable.AccountingAmount),
	|	&CustomerAdvanceClearing
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerAdvanceClearing)
	|
	|GROUP BY
	|	DocumentTable.AdvanceFlag,
	|	DocumentTable.Document,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.CounterpartySource,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByContracts,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByOrders,
	|	DocumentTable.Contract,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	DocumentTable.Order,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	DocumentTable.ExpenseItem,
	|	DocumentTable.IncomeItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	DocumentTable.Ref.Date
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.AdvanceFlag,
	|	VALUE(Enum.SettlementsTypes.Debt),
	|	VALUE(AccumulationRecordType.Expense),
	|	MAX(DocumentTable.LineNumber),
	|	CASE
	|		WHEN DocumentTable.Document = UNDEFINED
	|			THEN &Ref
	|		ELSE DocumentTable.Document
	|	END,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.CounterpartySource,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByContracts,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByOrders,
	|	DocumentTable.Contract,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	DocumentTable.Order,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	FALSE,
	|	FALSE,
	|	DocumentTable.ExpenseItem,
	|	DocumentTable.IncomeItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	DocumentTable.Ref.Date,
	|	SUM(DocumentTable.SettlementsAmount),
	|	SUM(DocumentTable.AccountingAmount),
	|	SUM(DocumentTable.SettlementsAmount),
	|	SUM(DocumentTable.AccountingAmount),
	|	&CustomerAdvanceClearing
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerAdvanceClearing)
	|
	|GROUP BY
	|	DocumentTable.AdvanceFlag,
	|	DocumentTable.Document,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.CounterpartySource,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByContracts,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByOrders,
	|	DocumentTable.Contract,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	DocumentTable.Order,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	DocumentTable.ExpenseItem,
	|	DocumentTable.IncomeItem,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.AdvanceFlag AS AdvanceFlag,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordType,
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Ref.OperationKind AS OperationKind,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN DocumentTable.Ref.Counterparty
	|		ELSE DocumentTable.Ref.CounterpartySource
	|	END AS Counterparty,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN DocumentTable.Ref.Counterparty.DoOperationsByContracts
	|		ELSE DocumentTable.Ref.CounterpartySource.DoOperationsByContracts
	|	END AS DoOperationsByContracts,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN DocumentTable.Ref.Counterparty.DoOperationsByOrders
	|		ELSE DocumentTable.Ref.CounterpartySource.DoOperationsByOrders
	|	END AS DoOperationsByOrders,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.Contract.SettlementsCurrency AS Currency,
	|	DocumentTable.Order AS Order,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS Correspondence,
	|	FALSE AS RegisterExpense,
	|	FALSE AS RegisterIncome,
	|	DocumentTable.ExpenseItem AS ExpenseItem,
	|	DocumentTable.IncomeItem AS IncomeItem,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.AdvancesPaidGLAccount
	|		ELSE DocumentTable.AccountsPayableGLAccount
	|	END AS GLAccount,
	|	DocumentTable.Ref.Date AS Date,
	|	SUM(DocumentTable.SettlementsAmount) AS SettlementsAmount,
	|	SUM(DocumentTable.AccountingAmount) AS AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN SUM(DocumentTable.SettlementsAmount)
	|		ELSE -SUM(DocumentTable.SettlementsAmount)
	|	END AS SettlementsAmountBalance,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN SUM(DocumentTable.AccountingAmount)
	|		ELSE -SUM(DocumentTable.AccountingAmount)
	|	END AS AccountingAmountBalance,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN &ArApAdjustments
	|		ELSE &Novation
	|	END AS ContentOfAccountingRecord
	|INTO TemporaryTableVendors
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor))
	|
	|GROUP BY
	|	DocumentTable.AdvanceFlag,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	DocumentTable.Document,
	|	DocumentTable.Ref,
	|	DocumentTable.Contract,
	|	DocumentTable.Order,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	DocumentTable.ExpenseItem,
	|	DocumentTable.IncomeItem,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.AdvancesPaidGLAccount
	|		ELSE DocumentTable.AccountsPayableGLAccount
	|	END,
	|	DocumentTable.Ref.Date,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN DocumentTable.Ref.Counterparty
	|		ELSE DocumentTable.Ref.CounterpartySource
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.Correspondence.TypeOfAccount
	|		ELSE VALUE(Enum.GLAccountsTypes.EmptyRef)
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN DocumentTable.Ref.Counterparty.DoOperationsByContracts
	|		ELSE DocumentTable.Ref.CounterpartySource.DoOperationsByContracts
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN DocumentTable.Ref.Counterparty.DoOperationsByOrders
	|		ELSE DocumentTable.Ref.CounterpartySource.DoOperationsByOrders
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.AdvanceFlag,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterExpense
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END,
	|	MAX(DocumentTable.LineNumber),
	|	CASE
	|		WHEN DocumentTable.Document = UNDEFINED
	|			THEN &Ref
	|		ELSE DocumentTable.Document
	|	END,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.Counterparty,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Contract,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	DocumentTable.Order,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	DocumentTable.Ref.RegisterExpense,
	|	DocumentTable.Ref.RegisterIncome,
	|	DocumentTable.ExpenseItem,
	|	DocumentTable.IncomeItem,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.AdvancesPaidGLAccount
	|		ELSE DocumentTable.AccountsPayableGLAccount
	|	END,
	|	DocumentTable.Ref.Date,
	|	SUM(DocumentTable.SettlementsAmount),
	|	SUM(DocumentTable.AccountingAmount),
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterIncome
	|			THEN -SUM(DocumentTable.SettlementsAmount)
	|		ELSE SUM(DocumentTable.SettlementsAmount)
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterIncome
	|			THEN -SUM(DocumentTable.AccountingAmount)
	|		ELSE SUM(DocumentTable.AccountingAmount)
	|	END,
	|	&DebtAdjustment
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.VendorDebtAdjustment)
	|	AND DocumentTable.SettlementsAmount <> 0
	|
	|GROUP BY
	|	DocumentTable.AdvanceFlag,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	DocumentTable.IncomeItem,
	|	DocumentTable.Document,
	|	DocumentTable.Ref,
	|	DocumentTable.Contract,
	|	DocumentTable.Order,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	DocumentTable.Ref.RegisterExpense,
	|	DocumentTable.Ref.RegisterIncome,
	|	DocumentTable.ExpenseItem,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.AdvancesPaidGLAccount
	|		ELSE DocumentTable.AccountsPayableGLAccount
	|	END,
	|	DocumentTable.Ref.Date,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN DocumentTable.Ref.Counterparty
	|		ELSE DocumentTable.Ref.CounterpartySource
	|	END,
	|	DocumentTable.Ref.Counterparty,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.AdvanceFlag,
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN VALUE(Enum.SettlementsTypes.Advance)
	|					ELSE VALUE(Enum.SettlementsTypes.Debt)
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN VALUE(Enum.SettlementsTypes.Advance)
	|				ELSE VALUE(Enum.SettlementsTypes.Debt)
	|			END
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN VALUE(AccumulationRecordType.Expense)
	|					ELSE VALUE(AccumulationRecordType.Receipt)
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN VALUE(AccumulationRecordType.Receipt)
	|				ELSE VALUE(AccumulationRecordType.Expense)
	|			END
	|	END,
	|	MAX(DocumentTable.LineNumber),
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN &Ref
	|		ELSE DocumentTable.Ref.AccountsDocument
	|	END,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.Counterparty,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Ref.Contract,
	|	DocumentTable.Ref.Contract.SettlementsCurrency,
	|	DocumentTable.Ref.Order,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	FALSE,
	|	FALSE,
	|	DocumentTable.ExpenseItem,
	|	DocumentTable.IncomeItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN DocumentTable.AdvancesPaidGLAccount
	|					ELSE DocumentTable.AccountsPayableGLAccount
	|				END
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	DocumentTable.Ref.Date,
	|	CAST(SUM(CASE
	|			WHEN DocumentTable.Ref.AccountingAmount = 0
	|				THEN 0
	|			ELSE DocumentTable.AccountingAmount / DocumentTable.Ref.AccountingAmount * DocumentTable.Ref.SettlementsAmount
	|		END) AS NUMBER(15, 2)),
	|	SUM(DocumentTable.AccountingAmount),
	|	CAST(CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN -1
	|					ELSE 1
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN -1
	|				ELSE 1
	|			END
	|	END * SUM(CASE
	|			WHEN DocumentTable.Ref.AccountingAmount = 0
	|				THEN 0
	|			ELSE DocumentTable.AccountingAmount / DocumentTable.Ref.AccountingAmount * DocumentTable.Ref.SettlementsAmount
	|		END) AS NUMBER(15, 2)),
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN -SUM(DocumentTable.AccountingAmount)
	|					ELSE SUM(DocumentTable.AccountingAmount)
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN -SUM(DocumentTable.AccountingAmount)
	|				ELSE SUM(DocumentTable.AccountingAmount)
	|			END
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN &ArApAdjustments
	|		ELSE &Novation
	|	END
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor)
	|
	|GROUP BY
	|	DocumentTable.AdvanceFlag,
	|	DocumentTable.Ref.AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN VALUE(Enum.SettlementsTypes.Advance)
	|					ELSE VALUE(Enum.SettlementsTypes.Debt)
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN VALUE(Enum.SettlementsTypes.Advance)
	|				ELSE VALUE(Enum.SettlementsTypes.Debt)
	|			END
	|	END,
	|	DocumentTable.Contract,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.Counterparty,
	|	DocumentTable.ExpenseItem,
	|	DocumentTable.IncomeItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN DocumentTable.AdvancesPaidGLAccount
	|					ELSE DocumentTable.AccountsPayableGLAccount
	|				END
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Ref.Contract,
	|	DocumentTable.Ref.Contract.SettlementsCurrency,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.Correspondence.TypeOfAccount
	|		ELSE VALUE(Enum.GLAccountsTypes.EmptyRef)
	|	END,
	|	DocumentTable.Ref.Order,
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN &Ref
	|		ELSE DocumentTable.Ref.AccountsDocument
	|	END,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Ref.AdvanceFlag,
	|	DocumentTable.Ref.AccountsDocument
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.AdvanceFlag,
	|	VALUE(Enum.SettlementsTypes.Debt),
	|	VALUE(AccumulationRecordType.Expense),
	|	MAX(DocumentTable.LineNumber),
	|	CASE
	|		WHEN DocumentTable.Document = UNDEFINED
	|			THEN &Ref
	|		ELSE DocumentTable.Document
	|	END,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.CounterpartySource,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByContracts,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByOrders,
	|	DocumentTable.Contract,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	ISNULL(DocumentTable.Order, VALUE(Document.PurchaseOrder.EmptyRef)),
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	FALSE,
	|	FALSE,
	|	DocumentTable.ExpenseItem,
	|	DocumentTable.IncomeItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN Counterparties.VendorAdvancesGLAccount
	|					ELSE Counterparties.GLAccountVendorSettlements
	|				END
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	DocumentTable.Ref.Date,
	|	SUM(DocumentTable.SettlementsAmount),
	|	SUM(DocumentTable.AccountingAmount),
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterIncome
	|			THEN -SUM(DocumentTable.SettlementsAmount)
	|		ELSE SUM(DocumentTable.SettlementsAmount)
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterIncome
	|			THEN -SUM(DocumentTable.AccountingAmount)
	|		ELSE SUM(DocumentTable.AccountingAmount)
	|	END,
	|	&DebtAdjustment
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|	LEFT JOIN Document.ArApAdjustments AS DocArApAdjustments
	|		ON DocumentTable.Ref = DocArApAdjustments.Ref
	|	LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON (DocArApAdjustments.Counterparty = Counterparties.Ref)
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.SupplierAdvanceClearing)
	|	AND DocumentTable.SettlementsAmount <> 0
	|
	|GROUP BY
	|	DocumentTable.AdvanceFlag,
	|	DocumentTable.IncomeItem,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.CounterpartySource,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByContracts,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByOrders,
	|	DocumentTable.Ref.RegisterExpense,
	|	DocumentTable.Ref.RegisterIncome,
	|	DocumentTable.Contract,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	DocumentTable.Order,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	DocumentTable.ExpenseItem,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Document,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN Counterparties.VendorAdvancesGLAccount
	|					ELSE Counterparties.GLAccountVendorSettlements
	|				END
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.AdvanceFlag,
	|	VALUE(Enum.SettlementsTypes.Advance),
	|	VALUE(AccumulationRecordType.Receipt),
	|	MAX(DocumentTable.LineNumber),
	|	CASE
	|		WHEN DocumentTable.Document = UNDEFINED
	|			THEN &Ref
	|		ELSE DocumentTable.Document
	|	END,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.CounterpartySource,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByContracts,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByOrders,
	|	DocumentTable.Contract,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	ISNULL(DocumentTable.Order, VALUE(Document.PurchaseOrder.EmptyRef)),
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	FALSE,
	|	FALSE,
	|	DocumentTable.ExpenseItem,
	|	DocumentTable.IncomeItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN Counterparties.VendorAdvancesGLAccount
	|					ELSE Counterparties.GLAccountVendorSettlements
	|				END
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	DocumentTable.Ref.Date,
	|	SUM(DocumentTable.SettlementsAmount),
	|	SUM(DocumentTable.AccountingAmount),
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterIncome
	|			THEN -SUM(DocumentTable.SettlementsAmount)
	|		ELSE SUM(DocumentTable.SettlementsAmount)
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterIncome
	|			THEN -SUM(DocumentTable.AccountingAmount)
	|		ELSE SUM(DocumentTable.AccountingAmount)
	|	END,
	|	&DebtAdjustment
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|	LEFT JOIN Document.ArApAdjustments AS DocArApAdjustments
	|		ON DocumentTable.Ref = DocArApAdjustments.Ref
	|	LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON (DocArApAdjustments.Counterparty = Counterparties.Ref)
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.SupplierAdvanceClearing)
	|	AND DocumentTable.SettlementsAmount <> 0
	|
	|GROUP BY
	|	DocumentTable.AdvanceFlag,
	|	DocumentTable.IncomeItem,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.CounterpartySource,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByContracts,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByOrders,
	|	DocumentTable.Ref.RegisterExpense,
	|	DocumentTable.Ref.RegisterIncome,
	|	DocumentTable.Contract,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	DocumentTable.Order,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	DocumentTable.ExpenseItem,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Document,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN Counterparties.VendorAdvancesGLAccount
	|					ELSE Counterparties.GLAccountVendorSettlements
	|				END
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END";
	
	Query.ExecuteBatch();
	
	// Register record table creation by account sections.
	GenerateTableCustomerAccounts(DocumentRefArApAdjustments, StructureAdditionalProperties);
	GenerateTableAccountsPayable(DocumentRefArApAdjustments, StructureAdditionalProperties);
	GenerateTableInvoicesAndOrdersPayment(DocumentRefArApAdjustments, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefArApAdjustments, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefArApAdjustments, StructureAdditionalProperties);
	GenerateTableUnallocatedExpenses(DocumentRefArApAdjustments, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefArApAdjustments, StructureAdditionalProperties);
	GenerateTableAccountingEntriesData(DocumentRefArApAdjustments, StructureAdditionalProperties);
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefArApAdjustments, StructureAdditionalProperties);

	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRefArApAdjustments, StructureAdditionalProperties);
	EndIf;
	
	FinancialAccounting.FillExtraDimensions(DocumentRefArApAdjustments, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefArApAdjustments, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefArApAdjustments, StructureAdditionalProperties);
		
	EndIf;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefArApAdjustments, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables contain records, it is
	// necessary to execute negative balance control.
	If StructureTemporaryTables.RegisterRecordsAccountsReceivableChange
		Or StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsAccountsReceivableChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.PresentationCurrency) AS PresentationCurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Contract.SettlementsCurrency) AS CurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Document) AS DocumentPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.SettlementsType) AS CalculationsTypesPresentation,
		|	RegisterRecordsAccountsReceivableChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountChange AS AmountChange,
		|	RegisterRecordsAccountsReceivableChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange + ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS DebtBalanceAmount,
		|	-(RegisterRecordsAccountsReceivableChange.SumCurChange + ISNULL(AccountsReceivableBalances.AmountCurBalance, 0)) AS AmountOfOutstandingAdvances,
		|	ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsAccountsReceivableChange.SettlementsType AS SettlementsType
		|FROM
		|	RegisterRecordsAccountsReceivableChange AS RegisterRecordsAccountsReceivableChange
		|		LEFT JOIN AccumulationRegister.AccountsReceivable.Balance(
		|				&ControlTime,
		|				(Company, PresentationCurrency, Counterparty, Contract, Document, Order, SettlementsType) In
		|					(SELECT
		|						RegisterRecordsAccountsReceivableChange.Company AS Company,
		|						RegisterRecordsAccountsReceivableChange.PresentationCurrency AS PresentationCurrency,
		|						RegisterRecordsAccountsReceivableChange.Counterparty AS Counterparty,
		|						RegisterRecordsAccountsReceivableChange.Contract AS Contract,
		|						RegisterRecordsAccountsReceivableChange.Document AS Document,
		|						RegisterRecordsAccountsReceivableChange.Order AS Order,
		|						RegisterRecordsAccountsReceivableChange.SettlementsType AS SettlementsType
		|					FROM
		|						RegisterRecordsAccountsReceivableChange AS RegisterRecordsAccountsReceivableChange)) AS AccountsReceivableBalances
		|		ON RegisterRecordsAccountsReceivableChange.Company = AccountsReceivableBalances.Company
		|			AND RegisterRecordsAccountsReceivableChange.PresentationCurrency = AccountsReceivableBalances.PresentationCurrency
		|			AND RegisterRecordsAccountsReceivableChange.Counterparty = AccountsReceivableBalances.Counterparty
		|			AND RegisterRecordsAccountsReceivableChange.Contract = AccountsReceivableBalances.Contract
		|			AND RegisterRecordsAccountsReceivableChange.Document = AccountsReceivableBalances.Document
		|			AND RegisterRecordsAccountsReceivableChange.Order = AccountsReceivableBalances.Order
		|			AND RegisterRecordsAccountsReceivableChange.SettlementsType = AccountsReceivableBalances.SettlementsType
		|WHERE
		|	CASE
		|			WHEN RegisterRecordsAccountsReceivableChange.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|				THEN ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) > 0
		|			ELSE ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) < 0
		|		END
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsSuppliersSettlementsChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.PresentationCurrency) AS PresentationCurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Contract.SettlementsCurrency) AS CurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Document) AS DocumentPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.SettlementsType) AS CalculationsTypesPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsSuppliersSettlementsChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsSuppliersSettlementsChange.AmountChange AS AmountChange,
		|	RegisterRecordsSuppliersSettlementsChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurChange + ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS DebtBalanceAmount,
		|	-(RegisterRecordsSuppliersSettlementsChange.SumCurChange + ISNULL(AccountsPayableBalances.AmountCurBalance, 0)) AS AmountOfOutstandingAdvances,
		|	ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsSuppliersSettlementsChange.SettlementsType AS SettlementsType
		|FROM
		|	RegisterRecordsSuppliersSettlementsChange AS RegisterRecordsSuppliersSettlementsChange
		|		LEFT JOIN AccumulationRegister.AccountsPayable.Balance(
		|				&ControlTime,
		|				(Company, PresentationCurrency, Counterparty, Contract, Document, Order, SettlementsType) In
		|					(SELECT
		|						RegisterRecordsSuppliersSettlementsChange.Company AS Company,
		|						RegisterRecordsSuppliersSettlementsChange.PresentationCurrency AS PresentationCurrency,
		|						RegisterRecordsSuppliersSettlementsChange.Counterparty AS Counterparty,
		|						RegisterRecordsSuppliersSettlementsChange.Contract AS Contract,
		|						RegisterRecordsSuppliersSettlementsChange.Document AS Document,
		|						RegisterRecordsSuppliersSettlementsChange.Order AS Order,
		|						RegisterRecordsSuppliersSettlementsChange.SettlementsType AS SettlementsType
		|					FROM
		|						RegisterRecordsSuppliersSettlementsChange AS RegisterRecordsSuppliersSettlementsChange)) AS AccountsPayableBalances
		|		ON RegisterRecordsSuppliersSettlementsChange.Company = AccountsPayableBalances.Company
		|			AND RegisterRecordsSuppliersSettlementsChange.PresentationCurrency = AccountsPayableBalances.PresentationCurrency
		|			AND RegisterRecordsSuppliersSettlementsChange.Counterparty = AccountsPayableBalances.Counterparty
		|			AND RegisterRecordsSuppliersSettlementsChange.Contract = AccountsPayableBalances.Contract
		|			AND RegisterRecordsSuppliersSettlementsChange.Document = AccountsPayableBalances.Document
		|			AND RegisterRecordsSuppliersSettlementsChange.Order = AccountsPayableBalances.Order
		|			AND RegisterRecordsSuppliersSettlementsChange.SettlementsType = AccountsPayableBalances.SettlementsType
		|WHERE
		|	CASE
		|			WHEN RegisterRecordsSuppliersSettlementsChange.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|				THEN ISNULL(AccountsPayableBalances.AmountCurBalance, 0) > 0
		|			ELSE ISNULL(AccountsPayableBalances.AmountCurBalance, 0) < 0
		|		END
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			Or Not ResultsArray[1].IsEmpty() Then
			DocumentObjectArApAdjustments = DocumentRefArApAdjustments.GetObject()
		EndIf;
		
		// Negative balance on accounts receivable.
		If Not ResultsArray[0].IsEmpty() Then
			
			ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
			MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'Cannot record customer balance'; ru = 'Не удалось записать остаток покупателя';pl = 'Nie można zarejestrować salda nabywcy';es_ES = 'No se puede registrar el saldo del cliente';es_CO = 'No se puede registrar el saldo del cliente';tr = 'Müşteri bakiyesi kaydedilemiyor';it = 'Impossibile registrare il saldo cliente';de = 'Kundensaldo kann nicht aufgezeichnet werden'");
			DriveServer.ShowMessageAboutError(
				DocumentObjectArApAdjustments,
				MessageTitleText,
				Undefined,
				Undefined,
				"",
				Cancel);
			
			QueryResultSelection = ResultsArray[0].Select();
			While QueryResultSelection.Next() Do
				If QueryResultSelection.SettlementsType = Enums.SettlementsTypes.Debt Then
					MessageText = NStr("en = '%CounterpartyPresentation% - customer debt balance by billing document is less than written amount.
										|Written-off amount: %SumCurOnWrite% %CurrencyPresentation%.
										|Remaining customer debt: %RemainingDebtAmount% %CurrencyPresentation%.'; 
										|ru = '%CounterpartyPresentation% - остаток задолженности покупателя по документу расчетов меньше списываемой суммы.
										|Списываемая сумма: %SumCurOnWrite% %CurrencyPresentation%.
										|Остаток задолженности покупателя: %RemainingDebtAmount% %CurrencyPresentation%.';
										|pl = '%CounterpartyPresentation% - saldo zadłużenia klienta według dokumentu fakturowania jest mniejsze niż kwota spisania.
										|Kwota spisania: %SumCurOnWrite% %CurrencyPresentation%.
										|Pozostały dług klienta: %RemainingDebtAmount% %CurrencyPresentation%.';
										|es_ES = '%CounterpartyPresentation% - saldo de la deuda del cliente por el documento de facturación es inferior al importe grabado.
										|Importe amortizado: %SumCurOnWrite% %CurrencyPresentation%.
										|Deuda del cliente restante: %RemainingDebtAmount% %CurrencyPresentation%.';
										|es_CO = '%CounterpartyPresentation% - saldo de la deuda del cliente por el documento de facturación es inferior al importe grabado.
										|Importe amortizado: %SumCurOnWrite% %CurrencyPresentation%.
										|Deuda del cliente restante: %RemainingDebtAmount% %CurrencyPresentation%.';
										|tr = '%CounterpartyPresentation%- Faturalama belgesine göre müşteri borç bakiyesi yazılı tutardan az. 
										| Silinen tutar: %SumCurOnWrite% %CurrencyPresentation%. 
										| Kalan müşteri borcu: %RemainingDebtAmount% %CurrencyPresentation%.';
										|it = '%CounterpartyPresentation% - il bilancio del debito cliente per documento di fattura è inferiore all''importo scritto.
										|Importo stornato: %SumCurOnWrite% %CurrencyPresentation%.
										|Debito cliente rimasto: %RemainingDebtAmount% %CurrencyPresentation%.';
										|de = '%CounterpartyPresentation% - der Kundenschuldenstand nach Abrechnungsbeleg ist kleiner als der geschriebene Betrag.
										|Ausbuchungsbetrag: %SumCurOnWrite% %CurrencyPresentation%.
										|Restschuld des Kunden: %RemainingDebtAmount% %CurrencyPresentation%.'");
				EndIf;
				If QueryResultSelection.SettlementsType = Enums.SettlementsTypes.Advance Then
					If QueryResultSelection.AmountOfOutstandingAdvances = 0 Then
						MessageText = NStr("en = '%CounterpartyPresentation% - perhaps the advances of the customer have not been received or they have been completely set off in the trade documents.'; ru = '%CounterpartyPresentation% - возможно, авансов от покупателя не было или они уже полностью зачтены в товарных документах.';pl = '%CounterpartyPresentation% – być może zaliczki od nabywcy nie zostały otrzymane lub były w całości zaliczone w dokumentach handlowych.';es_ES = '%CounterpartyPresentation% - probablemente los anticipos del cliente no se han recibido, o se han completamente compensado en los documentos comerciales.';es_CO = '%CounterpartyPresentation% - probablemente los anticipos del cliente no se han recibido, o se han completamente compensado en los documentos comerciales.';tr = '%CounterpartyPresentation% - müşterinin avansları alınmamış veya ticaret belgelerinde tamamen mahsup edilmiş olabilir.';it = '%CounterpartyPresentation% - probabilmente gli anticipi del cliente non sono stati ricevuti o non sono stati completamente compensati nei documenti commerciali.';de = '%CounterpartyPresentation% - vielleicht sind die Vorschüsse des Kunden nicht eingegangen oder wurden in den Handelsdokumenten vollständig verrechnet.'");
					Else
						MessageText = NStr("en = '%CounterpartyPresentation% - advances received from customer are already partially set off in commercial documents.
											|Balance of non-offset advances: %UnpaidAdvancesAmount% %CurrencyPresentation%.'; 
											|ru = '%CounterpartyPresentation% - полученные авансы от покупателя уже частично зачтены в товарных документах.
											|Остаток незачтенных авансов: %UnpaidAdvancesAmount% %CurrencyPresentation%.';
											|pl = '%CounterpartyPresentation% - zaliczki otrzymane od nabywcy, zostały częściowo zaliczone w dokumentach handlowych.
											|Saldo zaliczek, niezaliczonych zaliczek: %UnpaidAdvancesAmount% %CurrencyPresentation%.';
											|es_ES = '%CounterpartyPresentation% - anticipos recibidos del cliente ya se han compensado en parte en los documentos comerciales.
											|Saldo de los anticipos no compensados: %UnpaidAdvancesAmount% %CurrencyPresentation%.';
											|es_CO = '%CounterpartyPresentation% - anticipos recibidos del cliente ya se han compensado en parte en los documentos comerciales.
											|Saldo de los anticipos no compensados: %UnpaidAdvancesAmount% %CurrencyPresentation%.';
											|tr = '%CounterpartyPresentation% - müşteriden alınan avanslar, ticari belgelerde kısmen mahsup edilmiştir. 
											|Mahsup edilmeyen avansların bakiyesi:%UnpaidAdvancesAmount% %CurrencyPresentation%';
											|it = '%CounterpartyPresentation% - anticipi ricevuti dai clienti sono già in parte compensati nei documenti commerciali."
"Saldo degli anticipi non compensati:%UnpaidAdvancesAmount% %CurrencyPresentation%.';
											|de = '%CounterpartyPresentation% - erhaltene Vorzahlungen von Kunden sind bereits teilweise in Handelsdokumenten verrechnet.
											|Saldo der nicht verrechneten Vorauszahlungen: %UnpaidAdvancesAmount% %CurrencyPresentation%.'");
						MessageText = StrReplace(MessageText, "%UnpaidAdvancesAmount%", String(QueryResultSelection.AmountOfOutstandingAdvances));
					EndIf;
				EndIf;
				MessageText = StrReplace(MessageText, "%CounterpartyPresentation%", DriveServer.CounterpartyPresentation(QueryResultSelection.CounterpartyPresentation, QueryResultSelection.ContractPresentation, QueryResultSelection.DocumentPresentation, QueryResultSelection.OrderPresentation, QueryResultSelection.CalculationsTypesPresentation));
				MessageText = StrReplace(MessageText, "%CurrencyPresentation%", QueryResultSelection.CurrencyPresentation);
				MessageText = StrReplace(MessageText, "%SumCurOnWrite%", String(QueryResultSelection.SumCurOnWrite));
				MessageText = StrReplace(MessageText, "%RemainingDebtAmount%", String(QueryResultSelection.DebtBalanceAmount));
				DriveServer.ShowMessageAboutError(
					DocumentObjectArApAdjustments,
					MessageText,
					Undefined,
					Undefined,
					"",
					Cancel);
			EndDo;
		EndIf;
		
		// Negative balance on accounts payable.
		If Not ResultsArray[1].IsEmpty() Then
			
			ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
			MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'Cannot record supplier balance'; ru = 'Не удалось записать баланс поставщика';pl = 'Nie można zarejestrować salda dostawcy';es_ES = 'No se puede registrar el saldo del proveedor';es_CO = 'No se puede registrar el saldo del proveedor';tr = 'Tedarikçi bakiyesi kaydedilemiyor';it = 'Impossibile registrare il saldo fornitore';de = 'Lieferantensaldo kann nicht aufgezeichnet werden'");
			DriveServer.ShowMessageAboutError(
				DocumentObjectArApAdjustments,
				MessageTitleText,
				Undefined,
				Undefined,
				"",
				Cancel);
			
			QueryResultSelection = ResultsArray[1].Select();
			While QueryResultSelection.Next() Do
				If QueryResultSelection.SettlementsType = Enums.SettlementsTypes.Debt Then
					MessageText = NStr("en = '%CounterpartyPresentation% - debt to vendor balance by billing document is less than written amount.
										|Written-off amount: %SumCurOnWrite% %CurrencyPresentation%.
										|Debt before the balance provider:%RemainingDebtAmount% %CurrencyPresentation%.'; 
										|ru = '%CounterpartyPresentation% - остаток задолженности перед поставщиком по документу расчетов меньше списываемой суммы.
										|Списываемая сумма: %SumCurOnWrite% %CurrencyPresentation%.
										|Остаток задолженности перед поставщиком: %RemainingDebtAmount% %CurrencyPresentation%.';
										|pl = '%CounterpartyPresentation% – saldo zobowiązania do dostawcy według dokumentu fakturowania jest mniejsze niż niż wartość spisania.
										|Wartość spisania: %SumCurOnWrite% %CurrencyPresentation%.
										| Saldo zadłużenia wobec dostawcy.%RemainingDebtAmount% %CurrencyPresentation%.';
										|es_ES = '%CounterpartyPresentation% - saldo de la deuda al vendedor por el documento de facturación es inferior al importe grabado.
										|Importe amortizado: %SumCurOnWrite% %CurrencyPresentation%.
										|Deuda frente el proveedor del saldo: %RemainingDebtAmount%%CurrencyPresentation%.';
										|es_CO = '%CounterpartyPresentation% - saldo de la deuda al vendedor por el documento de facturación es inferior al importe grabado.
										|Importe amortizado: %SumCurOnWrite% %CurrencyPresentation%.
										|Deuda frente el proveedor del saldo: %RemainingDebtAmount%%CurrencyPresentation%.';
										|tr = '%CounterpartyPresentation% - Faturalama belgesi ile satıcı bakiyesi borcu yazılı tutardan az.
										| Mahsup edilen meblağ:%SumCurOnWrite% %CurrencyPresentation%. 
										|Bakiye sağlayıcıdan önceki borç:%RemainingDebtAmount%%CurrencyPresentation%.';
										|it = '%CounterpartyPresentation% - il saldo del debito al fornitore secondo i documenti contabili è inferiore all''importo registrato.
										|Importo registrato: %SumCurOnWrite% %CurrencyPresentation%.
										|Debito prima del saldo:%RemainingDebtAmount% %CurrencyPresentation%.';
										|de = '%CounterpartyPresentation% - Die Verbindlichkeit gegenüber dem Lieferantensaldo nach Abrechnungsbeleg ist kleiner als der geschriebene Betrag.
										|Ausbuchungsbetrag: %SumCurOnWrite% %CurrencyPresentation%.
										|Schuld vor dem Bilanzanbieter %RemainingDebtAmount% %CurrencyPresentation%.'");
				EndIf;
				If QueryResultSelection.SettlementsType = Enums.SettlementsTypes.Advance Then
					If QueryResultSelection.AmountOfOutstandingAdvances = 0 Then
						MessageText = NStr("en = '%CounterpartyPresentation% - perhaps the vendor didn''t get the advances or they have been completely set off in the trade documents.'; ru = '%CounterpartyPresentation% - возможно, авансов поставщику не было или они уже полностью зачтены в товарных документах.';pl = '%CounterpartyPresentation% - być może dostawca nie otrzymał zaliczek lub były one w całości zaliczone w dokumentach handlowych.';es_ES = '%CounterpartyPresentation% - probablemente el vendedor no ha recibido los anticipos o se han completamente compensado en los documentos comerciales.';es_CO = '%CounterpartyPresentation% - probablemente el vendedor no ha recibido los anticipos o se han completamente compensado en los documentos comerciales.';tr = '%CounterpartyPresentation% - satıcılar avans alamamış ya da ticaret belgelerinde bu avanslar tamamen mahsup edilmiş olabilir.';it = '%CounterpartyPresentation% - probabilmente il venditore non ha ricevuto i pagamenti anticipati o sono stati completamente inseriti nei documenti commerciali.';de = '%CounterpartyPresentation% - vielleicht hat der Verkäufer die Vorschüsse nicht erhalten, oder sie wurden vollständig in den Handelsdokumenten verrechnet.'");
					Else
						MessageText = NStr("en = '%CounterpartyPresentation% - advances issued to vendors are already partially set off in commercial documents.
											|Balance of non-offset advances: %RemainingDebtAmount% %CurrencyPresentation%.'; 
											|ru = '%CounterpartyPresentation% - выданные авансы поставщику уже частично зачтены в товарных документах.
											|Остаток незачтенных авансов: %RemainingDebtAmount% %CurrencyPresentation%.';
											|pl = '%CounterpartyPresentation% - zaliczki wypłacone dostawcom, zostały częściowo zaliczone w dokumentach handlowych.
											|Saldo zaliczek, niezaliczonych zaliczek: %RemainingDebtAmount% %CurrencyPresentation%.';
											|es_ES = '%CounterpartyPresentation% - anticipos emitidos a los vendedores ya se han compensado en parte en los documentos comerciales.
											|Saldo de los anticipos no compensados: %RemainingDebtAmount% %CurrencyPresentation%.';
											|es_CO = '%CounterpartyPresentation% - anticipos emitidos a los vendedores ya se han compensado en parte en los documentos comerciales.
											|Saldo de los anticipos no compensados: %RemainingDebtAmount% %CurrencyPresentation%.';
											|tr = '%CounterpartyPresentation% - tedarikçilere verilen avanslar, ticari belgelerde kısmen mahsup edilmiştir. 
											|Mahsup edilmeyen avansların bakiyesi: %RemainingDebtAmount%%CurrencyPresentation%.';
											|it = '%CounterpartyPresentation% - gli anticipi rilasciati a fornitori sono già  stati parzialmente compensate nei documenti commerciali.
											|Saldo degli anticipi non compensati: %RemainingDebtAmount% %CurrencyPresentation%.';
											|de = '%CounterpartyPresentation% - Vorschüsse, die an Lieferanten ausgegeben werden, sind bereits teilweise in Handelsdokumenten verrechnet.
											|Bilanz von nicht verrechneten Vorschüssen: %RemainingDebtAmount% %CurrencyPresentation%.'");
						MessageText = StrReplace(MessageText, "%UnpaidAdvancesAmount%", String(QueryResultSelection.AmountOfOutstandingAdvances));
					EndIf;
				EndIf;
				MessageText = StrReplace(MessageText, "%CounterpartyPresentation%", DriveServer.CounterpartyPresentation(QueryResultSelection.CounterpartyPresentation, QueryResultSelection.ContractPresentation, QueryResultSelection.DocumentPresentation, QueryResultSelection.OrderPresentation, QueryResultSelection.CalculationsTypesPresentation));
				MessageText = StrReplace(MessageText, "%CurrencyPresentation%", QueryResultSelection.CurrencyPresentation);
				MessageText = StrReplace(MessageText, "%SumCurOnWrite%", String(QueryResultSelection.SumCurOnWrite));
				MessageText = StrReplace(MessageText, "%RemainingDebtAmount%", String(QueryResultSelection.DebtBalanceAmount));
				DriveServer.ShowMessageAboutError(
					DocumentObjectArApAdjustments,
					MessageText,
					Undefined,
					Undefined,
					"",
					Cancel);
			EndDo;
		EndIf;
		
	EndIf;
	
EndProcedure

Function DocumentVATRate(DocumentRef) Export
	
	Return Catalogs.VATRates.EmptyRef();
	
EndFunction

#EndRegion

#Region Private

#Region TableGeneration

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCustomerAccounts(DocumentRefArApAdjustments, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Ref",					DocumentRefArApAdjustments);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("ExchangeDifference",	NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("PresentationCurrency",	StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod",	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("SettlementTypeDebt",	Enums.SettlementsTypes.Debt);
	Query.SetParameter("IsAdvanceClearing",		DocumentRefArApAdjustments.OperationKind = Enums.OperationTypesArApAdjustments.CustomerAdvanceClearing);
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.RecordType AS RecordType,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.Currency AS Currency,
	|	DocumentTable.Document AS Document,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND DocumentTable.Order <> VALUE(Document.WOrkOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	DocumentTable.SettlementsType AS SettlementsType,
	|	DocumentTable.GLAccount AS GLAccount,
	|	DocumentTable.Date AS Date,
	|	SUM(DocumentTable.AccountingAmount) AS Amount,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountCur,
	|	SUM(CASE
	|			WHEN DocumentTable.SettlementsType = &SettlementTypeDebt
	|					AND &IsAdvanceClearing
	|				THEN -DocumentTable.AccountingAmountBalance
	|			ELSE DocumentTable.AccountingAmountBalance
	|		END) AS AmountForBalance,
	|	SUM(CASE
	|			WHEN DocumentTable.SettlementsType = &SettlementTypeDebt
	|					AND &IsAdvanceClearing
	|				THEN -DocumentTable.SettlementsAmountBalance
	|			ELSE DocumentTable.SettlementsAmountBalance
	|		END) AS AmountCurForBalance,
	|	SUM(DocumentTable.AccountingAmount) AS AmountForPayment,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountForPaymentCur
	|INTO TemporaryTableAccountsReceivable
	|FROM
	|	TemporaryTableCustomers AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.ContentOfAccountingRecord,
	|	DocumentTable.RecordType,
	|	DocumentTable.Counterparty,
	|	DocumentTable.Contract,
	|	DocumentTable.Currency,
	|	DocumentTable.SettlementsType,
	|	DocumentTable.GLAccount,
	|	DocumentTable.Date,
	|	DocumentTable.Document,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND DocumentTable.Order <> VALUE(Document.WOrkOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	Counterparty,
	|	Contract,
	|	Currency,
	|	Document,
	|	Order,
	|	SettlementsType,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting the exclusive lock for the controlled balances of accounts payable.
	Query.Text =
	"SELECT
	|	TemporaryTableAccountsReceivable.Company AS Company,
	|	TemporaryTableAccountsReceivable.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableAccountsReceivable.Counterparty AS Counterparty,
	|	TemporaryTableAccountsReceivable.Contract AS Contract,
	|	TemporaryTableAccountsReceivable.Document AS Document,
	|	TemporaryTableAccountsReceivable.Order AS Order,
	|	TemporaryTableAccountsReceivable.SettlementsType AS SettlementsType
	|FROM
	|	TemporaryTableAccountsReceivable";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AccountsReceivable");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextCurrencyExchangeRateAccountsReceivable(Query.TempTablesManager, False, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsReceivable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountsPayable(DocumentRefArApAdjustments, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Ref",							DocumentRefArApAdjustments);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("PresentationCurrency",			StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod",			StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("SettlementTypeDebt",			Enums.SettlementsTypes.Debt);
	Query.SetParameter("IsAdvanceClearing",				DocumentRefArApAdjustments.OperationKind = Enums.OperationTypesArApAdjustments.SupplierAdvanceClearing);
	Query.SetParameter("UseDefaultTypeOfAccounting",	StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.RecordType AS RecordType,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.Currency AS Currency,
	|	DocumentTable.Document AS Document,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	DocumentTable.SettlementsType AS SettlementsType,
	|	DocumentTable.GLAccount AS GLAccount,
	|	DocumentTable.Date AS Date,
	|	SUM(DocumentTable.AccountingAmount) AS Amount,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountCur,
	|	SUM(CASE
	|			WHEN DocumentTable.SettlementsType = &SettlementTypeDebt
	|					AND &IsAdvanceClearing
	|				THEN -DocumentTable.AccountingAmountBalance
	|			ELSE DocumentTable.AccountingAmountBalance
	|		END) AS AmountForBalance,
	|	SUM(CASE
	|			WHEN DocumentTable.SettlementsType = &SettlementTypeDebt
	|					AND &IsAdvanceClearing
	|				THEN -DocumentTable.SettlementsAmountBalance
	|			ELSE DocumentTable.SettlementsAmountBalance
	|		END) AS AmountCurForBalance,
	|	SUM(DocumentTable.AccountingAmount) AS AmountForPayment,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountForPaymentCur
	|INTO TemporaryTableAccountsPayable
	|FROM
	|	TemporaryTableVendors AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.ContentOfAccountingRecord,
	|	DocumentTable.RecordType,
	|	DocumentTable.Counterparty,
	|	DocumentTable.Contract,
	|	DocumentTable.Currency,
	|	DocumentTable.SettlementsType,
	|	DocumentTable.GLAccount,
	|	DocumentTable.Date,
	|	DocumentTable.Document,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	Counterparty,
	|	Contract,
	|	Currency,
	|	Document,
	|	Order,
	|	SettlementsType,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting the exclusive lock for the controlled balances of accounts payable.
	Query.Text =
	"SELECT
	|	TemporaryTableAccountsPayable.Company AS Company,
	|	TemporaryTableAccountsPayable.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableAccountsPayable.Counterparty AS Counterparty,
	|	TemporaryTableAccountsPayable.Contract AS Contract,
	|	TemporaryTableAccountsPayable.Document AS Document,
	|	TemporaryTableAccountsPayable.Order AS Order,
	|	TemporaryTableAccountsPayable.SettlementsType AS SettlementsType
	|FROM
	|	TemporaryTableAccountsPayable";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AccountsPayable");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesAccountsPayable(Query.TempTablesManager, False, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsPayable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInvoicesAndOrdersPayment(DocumentRefPaymentReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Order AS Order,
	|	SUM(CASE
	|			WHEN NOT DocumentTable.AdvanceFlag
	|					AND NOT DocumentTable.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerAdvanceClearing)
	|				THEN 0
	|			ELSE DocumentTable.SettlementsAmount
	|		END) * CASE
	|		WHEN DocumentTable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -1
	|		ELSE 1
	|	END AS AdvanceAmount,
	|	SUM(CASE
	|			WHEN DocumentTable.AdvanceFlag
	|					OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerAdvanceClearing)
	|				THEN 0
	|			ELSE DocumentTable.SettlementsAmount
	|		END) * CASE
	|		WHEN DocumentTable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -1
	|		ELSE 1
	|	END AS PaymentAmount
	|FROM
	|	TemporaryTableCustomers AS DocumentTable
	|WHERE
	|	VALUETYPE(DocumentTable.Order) = TYPE(Document.SalesOrder)
	|	AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Order,
	|	DocumentTable.RecordType
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	&Company,
	|	DocumentTable.Order,
	|	SUM(CASE
	|			WHEN NOT DocumentTable.AdvanceFlag
	|				THEN 0
	|			ELSE DocumentTable.SettlementsAmount
	|		END) * CASE
	|		WHEN DocumentTable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -1
	|		ELSE 1
	|	END,
	|	SUM(CASE
	|			WHEN DocumentTable.AdvanceFlag
	|				THEN 0
	|			ELSE DocumentTable.SettlementsAmount
	|		END) * CASE
	|		WHEN DocumentTable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -1
	|		ELSE 1
	|	END
	|FROM
	|	TemporaryTableVendors AS DocumentTable
	|WHERE
	|	VALUETYPE(DocumentTable.Order) = TYPE(Document.PurchaseOrder)
	|	AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Order,
	|	DocumentTable.RecordType
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInvoicesAndOrdersPayment", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefArApAdjustments, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", 									DocumentRefArApAdjustments);
	Query.SetParameter("Company", 								StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", 					StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	UNDEFINED AS BusinessLine,
	|	DocumentTable.Document.Item AS Item,
	|	0 AS AmountIncome,
	|	-DocumentTable.AccountingAmount AS AmountExpense
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor))
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	UNDEFINED,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor),
	|	0,
	|	DocumentTable.AccountingAmount
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor))
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	UNDEFINED,
	|	DocumentTable.Document.Item,
	|	0,
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterExpense
	|			THEN -DocumentTable.AccountingAmount
	|		ELSE DocumentTable.AccountingAmount
	|	END
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.VendorDebtAdjustment)
	|	AND DocumentTable.AdvanceFlag
	|	AND (DocumentTable.Ref.RegisterExpense
	|			OR DocumentTable.Ref.RegisterIncome)
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	UNDEFINED,
	|	DocumentTable.Document.Item,
	|	-DocumentTable.AccountingAmount,
	|	0
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor))
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	5,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	UNDEFINED,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor),
	|	DocumentTable.AccountingAmount,
	|	0
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor))
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	6,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	UNDEFINED,
	|	DocumentTable.Document.Item,
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterExpense
	|			THEN DocumentTable.AccountingAmount
	|		ELSE -DocumentTable.AccountingAmount
	|	END,
	|	0
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAdjustment)
	|	AND DocumentTable.AdvanceFlag
	|	AND (DocumentTable.Ref.RegisterExpense
	|			OR DocumentTable.Ref.RegisterIncome)
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	RecordsTable = Query.Execute().Unload();
	
	If DocumentRefArApAdjustments.OperationKind = Enums.OperationTypesArApAdjustments.CustomerAdvanceClearing
		Or DocumentRefArApAdjustments.OperationKind = Enums.OperationTypesArApAdjustments.SupplierAdvanceClearing Then
		
		If DocumentRefArApAdjustments.OperationKind = Enums.OperationTypesArApAdjustments.CustomerAdvanceClearing Then
			BalanceAttribute = "AmountIncome";
		Else
			BalanceAttribute = "AmountExpense";
		EndIf;
		
		TableRetained = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpensesRetained.Copy();
		TableUnallocated = StructureAdditionalProperties.TableForRegisterRecords.TableUnallocatedExpenses.Copy();
		For Each RetainedRow In TableRetained Do
			
			If RetainedRow[BalanceAttribute] = 0 Then
				Continue;
			EndIf;
			
			For Each UnallocatedRow In TableUnallocated Do
				
				If RetainedRow[BalanceAttribute] = 0 Then
					Break;
				ElsIf TableUnallocated[BalanceAttribute] = 0 Then
					Continue;
				ElsIf RetainedRow[BalanceAttribute] < TableUnallocated[BalanceAttribute] Then
					
					NewRecordsRow1 = RecordsTable.Add();
					FillPropertyValues(NewRecordsRow1, RetainedRow);
					NewRecordsRow1.Item = TableUnallocated.Item;
					
					NewRecordsRow2 = RecordsTable.Add();
					FillPropertyValues(NewRecordsRow2, NewRecordsRow1);
					NewRecordsRow2.BusinessLine = Catalogs.LinesOfBusiness.EmptyRef();
					NewRecordsRow2[BalanceAttribute] = -NewRecordsRow2[BalanceAttribute];
					
					TableUnallocated[BalanceAttribute] = TableUnallocated[BalanceAttribute] - RetainedRow[BalanceAttribute];
					RetainedRow[BalanceAttribute] = 0;
					
				ElsIf RetainedRow[BalanceAttribute] >= TableUnallocated[BalanceAttribute] Then
					
					NewRecordsRow1 = RecordsTable.Add();
					FillPropertyValues(NewRecordsRow1, TableUnallocated);
					NewRecordsRow1.BusinessLine = RetainedRow.BusinessLine;
					
					NewRecordsRow2 = RecordsTable.Add();
					FillPropertyValues(NewRecordsRow2, NewRecordsRow1);
					NewRecordsRow2.BusinessLine = Catalogs.LinesOfBusiness.EmptyRef();
					NewRecordsRow2[BalanceAttribute] = -NewRecordsRow2[BalanceAttribute];
					
					RetainedRow[BalanceAttribute] = RetainedRow[BalanceAttribute] - TableUnallocated[BalanceAttribute];
					TableUnallocated[BalanceAttribute] = 0;
					
				EndIf;
			EndDo;
			
		EndDo;
		
	EndIf;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", RecordsTable);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableUnallocatedExpenses(DocumentRefArApAdjustments, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", 									DocumentRefArApAdjustments);
	Query.SetParameter("Company", 								StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", 					StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("DocumentDate", 							StructureAdditionalProperties.ForPosting.Date);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Document.Item AS Item,
	|	0 AS AmountIncome,
	|	DocumentTable.AccountingAmount AS AmountExpense
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor))
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	&Ref,
	|	DocumentTable.Document.Item,
	|	0,
	|	DocumentTable.AccountingAmount
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor))
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	DocumentTable.Document,
	|	DocumentTable.Document.Item,
	|	DocumentTable.AccountingAmount,
	|	0
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor))
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	&Ref,
	|	DocumentTable.Document.Item,
	|	DocumentTable.AccountingAmount,
	|	0
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor))
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	5,
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	DocumentTable.Document,
	|	DocumentTable.Document.Item,
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterExpense
	|			THEN DocumentTable.AccountingAmount
	|		WHEN DocumentTable.Ref.RegisterIncome
	|			THEN -DocumentTable.AccountingAmount
	|		ELSE 0
	|	END,
	|	0
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAdjustment)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	6,
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	DocumentTable.Document,
	|	DocumentTable.Document.Item,
	|	0,
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterExpense
	|			THEN -DocumentTable.AccountingAmount
	|		WHEN DocumentTable.Ref.RegisterIncome
	|			THEN DocumentTable.AccountingAmount
	|		ELSE 0
	|	END
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.VendorDebtAdjustment)
	|	AND DocumentTable.AdvanceFlag
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	7 AS Ordering,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	DocumentTable.Ref.OperationKind AS OperationKind,
	|	DocumentTable.Document AS Document,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.CashFlowItems.PaymentFromCustomers) AS CashFlowItem,
	|	DocumentTable.SettlementsAmount AS SettlementAmount
	|INTO TT_DebitorAdvances
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerAdvanceClearing)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	8,
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Document,
	|	&Company,
	|	&PresentationCurrency,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor),
	|	DocumentTable.SettlementsAmount
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.SupplierAdvanceClearing)
	|	AND DocumentTable.AdvanceFlag
	|
	|INDEX BY
	|	Document";
	
	QueryResult = Query.ExecuteBatchWithIntermediateData();
	
	If DocumentRefArApAdjustments.OperationKind <> Enums.OperationTypesArApAdjustments.CustomerAdvanceClearing 
		And DocumentRefArApAdjustments.OperationKind <> Enums.OperationTypesArApAdjustments.SupplierAdvanceClearing Then
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableUnallocatedExpenses", QueryResult[0].Unload());
		Return;
	EndIf;
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.UnallocatedExpenses");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult[1];
	LockItem.UseFromDataSource("Company", 				"Company");
	LockItem.UseFromDataSource("PresentationCurrency", 	"PresentationCurrency");
	LockItem.UseFromDataSource("Document", 				"Document");
	LockItem.UseFromDataSource("OperationKind", 		"OperationKind");
	Block.Lock();
	
	TableAmountForWriteOff = QueryResult[1].Unload();
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	UnallocatedExpensesBalances.Company AS Company,
	|	UnallocatedExpensesBalances.PresentationCurrency AS PresentationCurrency,
	|	UnallocatedExpensesBalances.Document AS Document,
	|	UnallocatedExpensesBalances.Item AS Item,
	|	UnallocatedExpensesBalances.AmountIncomeBalance AS AmountIncomeBalance,
	|	UnallocatedExpensesBalances.AmountExpenseBalance AS AmountExpenseBalance
	|INTO TT_Data
	|FROM
	|	TT_DebitorAdvances AS TT_DebitorAdvances
	|		INNER JOIN AccumulationRegister.UnallocatedExpenses.Balance AS UnallocatedExpensesBalances
	|		ON TT_DebitorAdvances.Company = UnallocatedExpensesBalances.Company
	|			AND TT_DebitorAdvances.Document = UnallocatedExpensesBalances.Document
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	UnallocatedExpenses.Company,
	|	UnallocatedExpenses.PresentationCurrency,
	|	UnallocatedExpenses.Document,
	|	UnallocatedExpenses.Item,
	|	CASE
	|		WHEN UnallocatedExpenses.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -UnallocatedExpenses.AmountIncome
	|		ELSE UnallocatedExpenses.AmountIncome
	|	END,
	|	CASE
	|		WHEN UnallocatedExpenses.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -UnallocatedExpenses.AmountExpense
	|		ELSE UnallocatedExpenses.AmountExpense
	|	END
	|FROM
	|	TT_DebitorAdvances AS TT_DebitorAdvances
	|		INNER JOIN AccumulationRegister.UnallocatedExpenses AS UnallocatedExpenses
	|		ON TT_DebitorAdvances.Company = UnallocatedExpenses.Company
	|			AND TT_DebitorAdvances.Document = UnallocatedExpenses.Document
	|			AND (UnallocatedExpenses.Recorder = &Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	&DocumentDate AS Period,
	|	TT_Data.Company AS Company,
	|	TT_Data.PresentationCurrency AS PresentationCurrency,
	|	TT_Data.Document AS Document,
	|	TT_Data.Item AS Item,
	|	0 AS AmountIncome,
	|	0 AS AmountExpense,
	|	SUM(TT_Data.AmountIncomeBalance) AS AmountIncomeBalance,
	|	SUM(TT_Data.AmountExpenseBalance) AS AmountExpenseBalance
	|FROM
	|	TT_Data AS TT_Data
	|
	|GROUP BY
	|	TT_Data.Item,
	|	TT_Data.Company,
	|	TT_Data.PresentationCurrency,
	|	TT_Data.Document";
	
	QueryResult = Query.ExecuteBatchWithIntermediateData();
	TableAmountsBalance = QueryResult[1].Unload();
	TableAmountsBalance.Indexes.Add("Document");
	
	If DocumentRefArApAdjustments.OperationKind = Enums.OperationTypesArApAdjustments.CustomerAdvanceClearing Then
		BalanceAttribute = "AmountIncome";
	Else
		BalanceAttribute = "AmountExpense";
	EndIf;
	
	For Each WriteOffAmountRow In TableAmountForWriteOff Do
		Filter = New Structure("Document", WriteOffAmountRow.Document);
		ArrayAmountsBalance = TableAmountsBalance.FindRows(Filter);
		For Each AmountsBalanceRow In ArrayAmountsBalance Do
			If WriteOffAmountRow.SettlementAmount = 0 Then
				Continue;
			EndIf;
			If AmountsBalanceRow[BalanceAttribute+"Balance"] < WriteOffAmountRow.SettlementAmount Then
				AmountsBalanceRow[BalanceAttribute] = AmountsBalanceRow[BalanceAttribute+"Balance"];
				WriteOffAmountRow.SettlementAmount = WriteOffAmountRow.SettlementAmount - AmountsBalanceRow[BalanceAttribute+"Balance"];
			Else
				AmountsBalanceRow[BalanceAttribute] = WriteOffAmountRow.SettlementAmount;
				WriteOffAmountRow.SettlementAmount = 0;
			EndIf;
		EndDo;
	EndDo;
	
	TableUnallocatedExpenses = TableAmountsBalance.CopyColumns();
	
	PossibleToAllocate = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpensesRetained.Total(BalanceAttribute);
	
	For Each CurrentRow Из TableAmountsBalance Do
		If PossibleToAllocate = 0 Then
			Break;
		EndIf;
		If CurrentRow[BalanceAttribute] <> 0 Then
			If PossibleToAllocate > CurrentRow[BalanceAttribute] Then
				NewRow = TableUnallocatedExpenses.Add();
				FillPropertyValues(NewRow, CurrentRow);
				PossibleToAllocate = PossibleToAllocate - CurrentRow[BalanceAttribute];
			Else
				NewRow = TableUnallocatedExpenses.Add();
				FillPropertyValues(NewRow, CurrentRow);
				NewRow[BalanceAttribute] = PossibleToAllocate;
				PossibleToAllocate = 0;
			EndIf;
		EndIf;
	EndDo;
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	1 AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.AmountIncome AS AmountIncome,
	|	DocumentTable.AmountExpense AS AmountExpense
	|INTO TableUnallocatedExpenses
	|FROM
	|	&DocumentTable AS DocumentTable";
	
	Query.SetParameter("DocumentTable", TableUnallocatedExpenses);
	Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableUnallocatedExpenses", TableUnallocatedExpenses);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefArApAdjustments, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", 									DocumentRefArApAdjustments);
	Query.SetParameter("Company", 								StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", 					StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	Query.SetParameter("Period", 								StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("DocumentArray", 						StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	// Generating the table with charge amounts.
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Ref.OperationKind AS OperationKind,
	|	SUM(DocumentTable.AccountingAmount) AS AmountToBeWrittenOff
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment)
	|	AND NOT DocumentTable.AdvanceFlag
	|
	|GROUP BY
	|	DocumentTable.Document,
	|	DocumentTable.Ref,
	|	DocumentTable.Ref.OperationKind
	|
	|UNION ALL
	|
	|SELECT
	|	&Company,
	|	&PresentationCurrency,
	|	DocumentTable.Document,
	|	DocumentTable.Ref.OperationKind,
	|	SUM(DocumentTable.AccountingAmount)
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerAdvanceClearing)
	|	AND NOT DocumentTable.AdvanceFlag
	|
	|GROUP BY
	|	DocumentTable.Document,
	|	DocumentTable.Ref,
	|	DocumentTable.Ref.OperationKind";
	
	QueryResult = Query.Execute();
	
	// Setting of the exclusive lock of the cash funds controlled balances.
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.IncomeAndExpensesRetained");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	LockItem.UseFromDataSource("Company", 				"Company");
	LockItem.UseFromDataSource("PresentationCurrency", 	"PresentationCurrency");
	LockItem.UseFromDataSource("Document", 				"Document");
	LockItem.UseFromDataSource("OperationKind", 		"OperationKind");
	Block.Lock();
	
	TableAmountForWriteOff = QueryResult.Unload();
	
	// Generating the table with remaining balance.
	Query.Text =
	"SELECT
	|	&Period AS Period,
	|	IncomeAndExpensesRetainedBalances.Company AS Company,
	|	IncomeAndExpensesRetainedBalances.PresentationCurrency AS PresentationCurrency,
	|	IncomeAndExpensesRetainedBalances.Document AS Document,
	|	IncomeAndExpensesRetainedBalances.BusinessLine AS BusinessLine,
	|	0 AS AmountIncome,
	|	0 AS AmountExpense,
	|	SUM(IncomeAndExpensesRetainedBalances.AmountIncomeBalance) AS AmountIncomeBalance,
	|	SUM(IncomeAndExpensesRetainedBalances.AmountExpenseBalance) AS AmountExpenseBalance
	|FROM
	|	(SELECT
	|		IncomeAndExpensesRetainedBalances.Company AS Company,
	|		IncomeAndExpensesRetainedBalances.PresentationCurrency AS PresentationCurrency,
	|		IncomeAndExpensesRetainedBalances.Document AS Document,
	|		IncomeAndExpensesRetainedBalances.BusinessLine AS BusinessLine,
	|		IncomeAndExpensesRetainedBalances.AmountIncomeBalance AS AmountIncomeBalance,
	|		IncomeAndExpensesRetainedBalances.AmountExpenseBalance AS AmountExpenseBalance
	|	FROM
	|		AccumulationRegister.IncomeAndExpensesRetained.Balance(
	|				,
	|				Company = &Company
	|					AND Document In
	|						(SELECT
	|							DocumentTable.Document
	|						FROM
	|							Document.ArApAdjustments.Debitor AS DocumentTable
	|						WHERE
	|							DocumentTable.Ref = &Ref
	|				
	|						UNION ALL
	|				
	|						SELECT
	|							DocumentTable.Document
	|						FROM
	|							Document.ArApAdjustments.Creditor AS DocumentTable
	|						WHERE
	|							DocumentTable.Ref = &Ref)) AS IncomeAndExpensesRetainedBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsOfIncomeAndExpensesPending.Company,
	|		DocumentRegisterRecordsOfIncomeAndExpensesPending.PresentationCurrency,
	|		DocumentRegisterRecordsOfIncomeAndExpensesPending.Document,
	|		DocumentRegisterRecordsOfIncomeAndExpensesPending.BusinessLine,
	|		CASE
	|			WHEN DocumentRegisterRecordsOfIncomeAndExpensesPending.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsOfIncomeAndExpensesPending.AmountIncome, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsOfIncomeAndExpensesPending.AmountIncome, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsOfIncomeAndExpensesPending.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsOfIncomeAndExpensesPending.AmountExpense, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsOfIncomeAndExpensesPending.AmountExpense, 0)
	|		END
	|	FROM
	|		AccumulationRegister.IncomeAndExpensesRetained AS DocumentRegisterRecordsOfIncomeAndExpensesPending
	|	WHERE
	|		DocumentRegisterRecordsOfIncomeAndExpensesPending.Recorder = &Ref) AS IncomeAndExpensesRetainedBalances
	|
	|GROUP BY
	|	IncomeAndExpensesRetainedBalances.Company,
	|	IncomeAndExpensesRetainedBalances.PresentationCurrency,
	|	IncomeAndExpensesRetainedBalances.Document,
	|	IncomeAndExpensesRetainedBalances.BusinessLine
	|
	|ORDER BY
	|	Document";
	
	TableSumBalance = Query.Execute().Unload();
	
	TableSumBalance.Indexes.Add("Document");
	
	// Calculation of the write-off amounts.
	For Each StringSumToBeWrittenOff In TableAmountForWriteOff Do
		AmountToBeWrittenOff = StringSumToBeWrittenOff.AmountToBeWrittenOff;
		Filter = New Structure("Document", StringSumToBeWrittenOff.Document);
		RowsArrayAmountsBalances = TableSumBalance.FindRows(Filter);
		For Each AmountRowBalances In RowsArrayAmountsBalances Do
			If AmountToBeWrittenOff = 0 Then
				Continue
			ElsIf AmountRowBalances.AmountIncomeBalance < AmountToBeWrittenOff Then
				AmountRowBalances.AmountIncome = AmountRowBalances.AmountIncomeBalance;
				AmountToBeWrittenOff = AmountToBeWrittenOff - AmountRowBalances.AmountIncomeBalance;
			ElsIf AmountRowBalances.AmountIncomeBalance >= AmountToBeWrittenOff Then
				AmountRowBalances.AmountIncome = AmountToBeWrittenOff;
				AmountToBeWrittenOff = 0;
			EndIf;
		EndDo;
	EndDo;
	
	// Generating the table with charge amounts.
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Ref.OperationKind AS OperationKind,
	|	SUM(DocumentTable.AccountingAmount) AS AmountToBeWrittenOff
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor)
	|	AND Not DocumentTable.AdvanceFlag
	|
	|GROUP BY
	|	DocumentTable.Document,
	|	DocumentTable.Ref,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Document"; 
	
	TableAmountForWriteOff = Query.Execute().Unload();
	
	For Each StringSumToBeWrittenOff In TableAmountForWriteOff Do
		AmountToBeWrittenOff = StringSumToBeWrittenOff.AmountToBeWrittenOff;
		Filter = New Structure("Document", StringSumToBeWrittenOff.Document);
		RowsArrayAmountsBalances = TableSumBalance.FindRows(Filter);
		For Each AmountRowBalances In RowsArrayAmountsBalances Do
			If AmountToBeWrittenOff = 0 Then
				Continue
			ElsIf AmountRowBalances.AmountExpenseBalance < AmountToBeWrittenOff Then
				AmountRowBalances.AmountExpense = AmountRowBalances.AmountExpenseBalance;
				AmountToBeWrittenOff = AmountToBeWrittenOff - AmountRowBalances.AmountExpenseBalance;
			ElsIf AmountRowBalances.AmountExpenseBalance >= AmountToBeWrittenOff Then
				AmountRowBalances.AmountExpense = AmountToBeWrittenOff;
				AmountToBeWrittenOff = 0;
			EndIf;
		EndDo;
	EndDo;

	
	// Generating a temporary table with amounts,
	// items and directions of activities. Required to generate movements of income
	// and expenses by cash method.
	Query.Text =
	"SELECT
	|	Table.Period AS Period,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Document AS Document,
	|	Table.AmountIncome AS AmountIncome,
	|	Table.AmountExpense AS AmountExpense,
	|	Table.BusinessLine AS BusinessLine
	|INTO TemporaryTableTableDeferredIncomeAndExpenditure
	|FROM
	|	&Table AS Table
	|WHERE
	|	(Table.AmountIncome > 0
	|			OR Table.AmountExpense > 0)";
	
	Query.SetParameter("Table", TableSumBalance);
	
	Query.Execute();
	
	// Generating the table for recording in the register.
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	Table.Period AS Period,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Document AS Document,
	|	Table.AmountIncome AS AmountIncome,
	|	Table.AmountExpense AS AmountExpense,
	|	Table.BusinessLine AS BusinessLine
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	Table.Period,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	&Ref,
	|	Table.AmountIncome,
	|	Table.AmountExpense,
	|	Table.BusinessLine
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesRetained", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefArApAdjustments, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	UNDEFINED AS StructuralUnit,
	|	UNDEFINED AS SalesOrder,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &FXExpenseItem
	|		ELSE &FXIncomeItem
	|	END AS IncomeAndExpenseItem,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &NegativeExchangeDifferenceAccountOfAccounting
	|		ELSE &PositiveExchangeDifferenceGLAccount
	|	END AS GLAccount,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END AS AmountIncome,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &FXIncomeItem
	|		ELSE &FXExpenseItem
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &PositiveExchangeDifferenceGLAccount
	|		ELSE &NegativeExchangeDifferenceAccountOfAccounting
	|	END,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	FALSE
	|FROM
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	UNDEFINED,
	|	DocumentTable.Order,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	CASE
	|		WHEN DocumentTable.RegisterIncome
	|			THEN DocumentTable.IncomeItem
	|		ELSE DocumentTable.ExpenseItem
	|	END,
	|	DocumentTable.Correspondence,
	|	&DebtAdjustment,
	|	CASE
	|		WHEN DocumentTable.RegisterIncome
	|			THEN DocumentTable.AccountingAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.RegisterExpense
	|			THEN DocumentTable.AccountingAmount
	|		ELSE 0
	|	END,
	|	FALSE
	|FROM
	|	TemporaryTableCustomers AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAdjustment)
	|	AND (DocumentTable.RegisterExpense
	|			OR DocumentTable.RegisterIncome)
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	UNDEFINED,
	|	DocumentTable.Order,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	CASE
	|		WHEN DocumentTable.RegisterIncome
	|			THEN DocumentTable.IncomeItem
	|		ELSE DocumentTable.ExpenseItem
	|	END,
	|	DocumentTable.Correspondence,
	|	&DebtAdjustment,
	|	CASE
	|		WHEN DocumentTable.RegisterIncome
	|			THEN DocumentTable.AccountingAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.RegisterExpense
	|			THEN DocumentTable.AccountingAmount
	|		ELSE 0
	|	END,
	|	FALSE
	|FROM
	|	TemporaryTableVendors AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.VendorDebtAdjustment)
	|	AND (DocumentTable.RegisterExpense
	|			OR DocumentTable.RegisterIncome)
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Ref",											DocumentRefArApAdjustments);
	Query.SetParameter("Company",										StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime",									New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("DebtAdjustment",								NStr("en = 'AR/AP Adjustments'; ru = 'Корректировка дебиторской/кредиторской задолженности';pl = 'Korekty Wn/Ma';es_ES = 'Modificaciones de las cuentas a cobrar/las cuentas a pagar';es_CO = 'Modificaciones de las cuentas a cobrar/las cuentas a pagar';tr = 'Alacak/Borç hesapları düzeltmeleri';it = 'Correzioni contabili';de = 'Offene Posten Debitoren/Kreditoren-Korrekturen'", MainLanguageCode));
	Query.SetParameter("FXIncomeItem",									Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXIncome"));
	Query.SetParameter("FXExpenseItem",									Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXExpenses"));
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("PresentationCurrency",                          StructureAdditionalProperties.ForPosting.PresentationCurrency);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefArApAdjustments, StructureAdditionalProperties)
	
	If Not StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Ref",							DocumentRefArApAdjustments);
	Query.SetParameter("ArApAdjustments",				NStr("en = 'AR/AP Adjustments'; ru = 'Корректировка дебиторской/кредиторской задолженности';pl = 'Korekty Wn/Ma';es_ES = 'Modificaciones de las cuentas a cobrar/las cuentas a pagar';es_CO = 'Modificaciones de las cuentas a cobrar/las cuentas a pagar';tr = 'Alacak/Borç hesapları düzeltmeleri';it = 'Correzioni contabili';de = 'Offene Posten Debitoren/Kreditoren-Korrekturen'", MainLanguageCode));
	Query.SetParameter("Novation",						NStr("en = 'Novation'; ru = 'Обновление';pl = 'Nowacja';es_ES = 'Novación';es_CO = 'Novación';tr = 'Yenileme';it = 'Novazione';de = 'Neuerung'", MainLanguageCode));
	Query.SetParameter("DebtAdjustment",				NStr("en = 'AR/AP Adjustments'; ru = 'Корректировка дебиторской/кредиторской задолженности';pl = 'Korekty Wn/Ma';es_ES = 'Modificaciones de las cuentas a cobrar/las cuentas a pagar';es_CO = 'Modificaciones de las cuentas a cobrar/las cuentas a pagar';tr = 'Alacak/Borç hesapları düzeltmeleri';it = 'Correzioni contabili';de = 'Offene Posten Debitoren/Kreditoren-Korrekturen'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("AdvancePaymentClearing",		NStr("en = 'Advance payment clearing'; ru = 'Зачет аванса';pl = 'Rozliczanie zaliczki';es_ES = 'Amortización de pagos anticipados';es_CO = 'Amortización de pagos anticipados';tr = 'Avans ödeme mahsuplaştırılması';it = 'Annullamento del pagamento anticipato';de = 'Verrechnung der Vorauszahlung'", MainLanguageCode));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Counterparty.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|	DocumentTable.Counterparty.CustomerAdvancesGLAccount.Currency AS CustomerAdvancesGLAccountCurrency,
	|	DocumentTable.Counterparty.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	DocumentTable.Counterparty.GLAccountCustomerSettlements.Currency AS GLAccountCustomerSettlementsCurrency,
	|	DocumentTable.Currency AS SettlementsCurrency,
	|	DocumentTable.SettlementsAmount AS SettlementsAmount,
	|	DocumentTable.AccountingAmount AS AccountingAmount
	|INTO TemporaryTableCustomersAdvanceClearing
	|FROM
	|	TemporaryTableCustomers AS DocumentTable
	|WHERE
	|	DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerAdvanceClearing)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Ordering,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Counterparty.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|	DocumentTable.Counterparty.VendorAdvancesGLAccount.Currency AS VendorAdvancesGLAccountCurrency,
	|	DocumentTable.Counterparty.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	DocumentTable.Counterparty.GLAccountVendorSettlements.Currency AS GLAccountVendorSettlementsCurrency,
	|	DocumentTable.Currency AS SettlementsCurrency,
	|	DocumentTable.SettlementsAmount AS SettlementsAmount,
	|	DocumentTable.AccountingAmount AS AccountingAmount
	|INTO TemporaryTableSuppliersAdvanceClearing
	|FROM
	|	TemporaryTableVendors AS DocumentTable
	|WHERE
	|	DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.SupplierAdvanceClearing)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.Period AS Period,
	|	DocumentTable.LineNumber AS LineNumber,
	|	&Company AS Company,
	|	DocumentTable.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|	DocumentTable.CustomerAdvancesGLAccountCurrency AS CustomerAdvancesGLAccountCurrency,
	|	DocumentTable.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	DocumentTable.GLAccountCustomerSettlementsCurrency AS GLAccountCustomerSettlementsCurrency,
	|	DocumentTable.SettlementsCurrency AS SettlementsCurrency,
	|	SUM(DocumentTable.SettlementsAmount) AS SettlementsAmount,
	|	SUM(DocumentTable.AccountingAmount) AS AccountingAmount
	|INTO SignificantCustomersAdvanceAmounts
	|FROM
	|	TemporaryTableCustomersAdvanceClearing AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.LineNumber,
	|	DocumentTable.CustomerAdvancesGLAccount,
	|	DocumentTable.CustomerAdvancesGLAccountCurrency,
	|	DocumentTable.GLAccountCustomerSettlements,
	|	DocumentTable.GLAccountCustomerSettlementsCurrency,
	|	DocumentTable.SettlementsCurrency
	|
	|HAVING
	|	(SUM(DocumentTable.AccountingAmount) >= 0.005
	|		OR SUM(DocumentTable.AccountingAmount) <= -0.005
	|		OR SUM(DocumentTable.SettlementsAmount) >= 0.005
	|		OR SUM(DocumentTable.SettlementsAmount) <= -0.005)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.Period AS Period,
	|	DocumentTable.LineNumber AS LineNumber,
	|	&Company AS Company,
	|	DocumentTable.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|	DocumentTable.VendorAdvancesGLAccountCurrency AS VendorAdvancesGLAccountCurrency,
	|	DocumentTable.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	DocumentTable.GLAccountVendorSettlementsCurrency AS GLAccountVendorSettlementsCurrency,
	|	DocumentTable.SettlementsCurrency AS SettlementsCurrency,
	|	SUM(DocumentTable.SettlementsAmount) AS SettlementsAmount,
	|	SUM(DocumentTable.AccountingAmount) AS AccountingAmount
	|INTO SignificantSuppliersAdvanceAmounts
	|FROM
	|	TemporaryTableSuppliersAdvanceClearing AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.LineNumber,
	|	DocumentTable.VendorAdvancesGLAccount,
	|	DocumentTable.VendorAdvancesGLAccountCurrency,
	|	DocumentTable.GLAccountVendorSettlements,
	|	DocumentTable.GLAccountVendorSettlementsCurrency,
	|	DocumentTable.SettlementsCurrency
	|
	|HAVING
	|	(SUM(DocumentTable.AccountingAmount) >= 0.005
	|		OR SUM(DocumentTable.AccountingAmount) <= -0.005
	|		OR SUM(DocumentTable.SettlementsAmount) >= 0.005
	|		OR SUM(DocumentTable.SettlementsAmount) <= -0.005)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Ordering,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&FundsTransfersBeingProcessed AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	DocumentTable.AccountsReceivableGLAccount AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.AccountsReceivableGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.AccountsReceivableGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	DocumentTable.AccountingAmount AS Amount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN &ArApAdjustments
	|		ELSE &Novation
	|	END AS Content,
	|	FALSE AS Offlinerecord
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|	AND NOT DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.AdvancesReceivedGLAccount,
	|	CASE
	|		WHEN DocumentTable.AdvancesReceivedGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AdvancesReceivedGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	&FundsTransfersBeingProcessed,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN &ArApAdjustments
	|		ELSE &Novation
	|	END,
	|	FALSE
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	ArApAdjustments.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN ArApAdjustments.RegisterExpense
	|			THEN ArApAdjustments.Correspondence
	|		ELSE DocumentTable.AccountsReceivableGLAccount
	|	END,
	|	CASE
	|		WHEN NOT ArApAdjustments.RegisterExpense
	|				AND ArApAdjustments.Correspondence.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN ArApAdjustments.RegisterExpense 
	|			AND ArApAdjustments.Correspondence.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN ArApAdjustments.RegisterExpense
	|			THEN DocumentTable.AccountsReceivableGLAccount
	|		ELSE ArApAdjustments.Correspondence
	|	END,
	|	CASE
	|		WHEN ArApAdjustments.RegisterExpense
	|				AND DocumentTable.AccountsReceivableGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN ArApAdjustments.RegisterExpense
	|				AND DocumentTable.AccountsReceivableGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	&DebtAdjustment,
	|	FALSE
	|FROM
	|	Document.ArApAdjustments AS ArApAdjustments
	|		INNER JOIN Document.ArApAdjustments.Debitor AS DocumentTable
	|		ON ArApAdjustments.Ref = DocumentTable.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON ArApAdjustments.CounterpartySource = Counterparties.Ref
	|WHERE
	|	ArApAdjustments.Ref = &Ref
	|	AND ArApAdjustments.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAdjustment)
	|	AND NOT DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterExpense
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE DocumentTable.AdvancesReceivedGLAccount
	|	END,
	|	CASE
	|		WHEN NOT DocumentTable.Ref.RegisterExpense
	|				AND DocumentTable.AdvancesReceivedGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN NOT DocumentTable.Ref.RegisterExpense
	|				AND DocumentTable.AdvancesReceivedGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterExpense
	|			THEN DocumentTable.AdvancesReceivedGLAccount
	|		ELSE DocumentTable.Ref.Correspondence
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterExpense
	|				AND DocumentTable.AdvancesReceivedGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterExpense
	|				AND DocumentTable.AdvancesReceivedGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	&DebtAdjustment,
	|	FALSE
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAdjustment)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	5,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.AccountsPayableGLAccount,
	|	CASE
	|		WHEN DocumentTable.AccountsPayableGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AccountsPayableGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	&FundsTransfersBeingProcessed,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN &ArApAdjustments
	|		ELSE &Novation
	|	END,
	|	FALSE
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|	AND NOT DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterExpense
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE DocumentTable.AccountsPayableGLAccount
	|	END,
	|	CASE
	|		WHEN NOT DocumentTable.Ref.RegisterExpense
	|				AND DocumentTable.AccountsPayableGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN NOT DocumentTable.Ref.RegisterExpense
	|				AND DocumentTable.AccountsPayableGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterExpense
	|			THEN DocumentTable.AccountsPayableGLAccount
	|		ELSE DocumentTable.Ref.Correspondence
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterExpense
	|				AND DocumentTable.AccountsPayableGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterExpense
	|				AND DocumentTable.AccountsPayableGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	&DebtAdjustment,
	|	FALSE
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.VendorDebtAdjustment)
	|	AND NOT DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterExpense
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE DocumentTable.AdvancesPaidGLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterExpense
	|				AND DocumentTable.AdvancesPaidGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterExpense
	|				AND DocumentTable.AdvancesPaidGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterExpense
	|			THEN DocumentTable.AdvancesPaidGLAccount
	|		ELSE DocumentTable.Ref.Correspondence
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterExpense
	|				AND DocumentTable.AdvancesPaidGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.RegisterExpense
	|				AND DocumentTable.AdvancesPaidGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	&DebtAdjustment,
	|	FALSE
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.VendorDebtAdjustment)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	6,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&FundsTransfersBeingProcessed,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.AdvancesPaidGLAccount,
	|	CASE
	|		WHEN DocumentTable.AdvancesPaidGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AdvancesPaidGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN &ArApAdjustments
	|		ELSE &Novation
	|	END,
	|	FALSE
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	7,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.AccountsReceivableGLAccount,
	|	CASE
	|		WHEN DocumentTable.AccountsReceivableGLAccount.Currency
	|			THEN DocumentTable.Ref.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AccountsReceivableGLAccount.Currency
	|			THEN DocumentTable.AccountingAmount / DocumentTable.Ref.AccountingAmount * DocumentTable.Ref.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountsReceivableGLAccount,
	|	CASE
	|		WHEN DocumentTable.AccountsReceivableGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AccountsReceivableGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN &ArApAdjustments
	|		ELSE &Novation
	|	END,
	|	FALSE
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment)
	|	AND NOT DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	8,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.AdvancesReceivedGLAccount,
	|	CASE
	|		WHEN DocumentTable.AdvancesReceivedGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AdvancesReceivedGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AdvancesReceivedGLAccount,
	|	CASE
	|		WHEN DocumentTable.AdvancesReceivedGLAccount.Currency
	|			THEN DocumentTable.Ref.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AdvancesReceivedGLAccount.Currency
	|			THEN DocumentTable.AccountingAmount / DocumentTable.Ref.AccountingAmount * DocumentTable.Ref.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN &ArApAdjustments
	|		ELSE &Novation
	|	END,
	|	FALSE
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	9,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.AccountsPayableGLAccount,
	|	CASE
	|		WHEN DocumentTable.AccountsPayableGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AccountsPayableGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountsPayableGLAccount,
	|	CASE
	|		WHEN DocumentTable.AccountsPayableGLAccount.Currency
	|			THEN DocumentTable.Ref.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AccountsPayableGLAccount.Currency
	|			THEN DocumentTable.AccountingAmount / DocumentTable.Ref.AccountingAmount * DocumentTable.Ref.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN &ArApAdjustments
	|		ELSE &Novation
	|	END,
	|	FALSE
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor)
	|	AND NOT DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	10,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.AccountsPayableGLAccount,
	|	CASE
	|		WHEN DocumentTable.AccountsPayableGLAccount.Currency
	|			THEN DocumentTable.Ref.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AccountsPayableGLAccount.Currency
	|			THEN DocumentTable.AccountingAmount / DocumentTable.Ref.AccountingAmount * DocumentTable.Ref.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountsPayableGLAccount,
	|	CASE
	|		WHEN DocumentTable.AccountsPayableGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AccountsPayableGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN &ArApAdjustments
	|		ELSE &Novation
	|	END,
	|	FALSE
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	11,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	12,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeLoss
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE &ForeignCurrencyExchangeGain
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	13,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.CustomerAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.CustomerAdvancesGLAccountCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.CustomerAdvancesGLAccountCurrency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN DocumentTable.GLAccountCustomerSettlementsCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccountCustomerSettlementsCurrency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	&AdvancePaymentClearing,
	|	FALSE
	|FROM
	|	SignificantCustomersAdvanceAmounts AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	14,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.VendorAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccountVendorSettlementsCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccountVendorSettlementsCurrency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.GLAccountVendorSettlements,
	|	CASE
	|		WHEN DocumentTable.VendorAdvancesGLAccountCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.VendorAdvancesGLAccountCurrency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	&AdvancePaymentClearing,
	|	FALSE
	|FROM
	|	SignificantSuppliersAdvanceAmounts AS DocumentTable
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";

	Query.SetParameter("FundsTransfersBeingProcessed", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("FundsTransfersBeingProcessed"));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

#EndRegion

#EndRegion

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export
	
	IncomeAndExpenseStructure = New Structure;
	
	If StructureData.TabName = "Debitor" Or StructureData.TabName = "Creditor" Then
		
		If StructureData.ObjectParameters.RegisterExpense Then
			IncomeAndExpenseStructure.Insert("ExpenseItem", StructureData.ExpenseItem);
		ElsIf StructureData.ObjectParameters.RegisterIncome Then
			IncomeAndExpenseStructure.Insert("IncomeItem", StructureData.IncomeItem);
		EndIf;
		
	EndIf;
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	If (StructureData.TabName = "Debitor" Or StructureData.TabName = "Creditor")
		And (StructureData.ObjectParameters.OperationKind = Enums.OperationTypesArApAdjustments.CustomerDebtAdjustment
			Or StructureData.ObjectParameters.OperationKind = Enums.OperationTypesArApAdjustments.VendorDebtAdjustment) Then
		
		Array = New Array;
		Array.Add("ExpenseItem");
		Array.Add("IncomeItem");
		Result.Insert("Correspondence", Array);

	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	ObjectParameters = StructureData.ObjectParameters;
	GLAccountsForFilling = New Structure;
	
	If StructureData.Property("CounterpartyGLAccounts") Then
		
		If StructureData.TabName = "Debitor" Then
			
			GLAccountsForFilling.Insert("AccountsReceivableGLAccount", StructureData.AccountsReceivableGLAccount);
			GLAccountsForFilling.Insert("AdvancesReceivedGLAccount", StructureData.AdvancesReceivedGLAccount);
			
		ElsIf StructureData.TabName = "Creditor" Then
			
			GLAccountsForFilling.Insert("AccountsPayableGLAccount", StructureData.AccountsPayableGLAccount);
			GLAccountsForFilling.Insert("AdvancesPaidGLAccount", StructureData.AdvancesPaidGLAccount);
			
		ElsIf StructureData.TabName = "Header" Then
			
			If ObjectParameters.OperationKind = Enums.OperationTypesArApAdjustments.CustomerDebtAssignment Then
				
				GLAccountsForFilling.Insert("AccountsReceivableGLAccount", ObjectParameters.AccountsReceivableGLAccount);
				GLAccountsForFilling.Insert("AdvancesReceivedGLAccount", ObjectParameters.AdvancesReceivedGLAccount);
				
			ElsIf ObjectParameters.OperationKind = Enums.OperationTypesArApAdjustments.DebtAssignmentToVendor Then
				
				GLAccountsForFilling.Insert("AccountsPayableGLAccount", ObjectParameters.AccountsPayableGLAccount);
				GLAccountsForFilling.Insert("AdvancesPaidGLAccount", ObjectParameters.AdvancesPaidGLAccount);
				
			EndIf;
			
		EndIf;
			
	EndIf;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#EndRegion

#Region Internal

#Region AutomaticDiscounts

Function EntryTypes() Export 
	
	EntryTypes = New Array;
	
	Return EntryTypes;
	
EndFunction

Function AccountingFields() Export 
	
	AccountingFields = New Map;
	
	Return AccountingFields;
	
EndFunction

#EndRegion

#EndRegion

#EndIf