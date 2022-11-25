#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then
	
#Region Public

Procedure CheckEnterBasedOnLoanContract(AttributeValues) Export
	
	If AttributeValues.Property("Posted") Then
		If Not AttributeValues.Posted Then
			Raise NStr("en = 'Please select a posted document.'; ru = 'Выберите проведенный документ.';pl = 'Wybierz zatwierdzony dokument.';es_ES = 'Por favor, seleccione un documento enviado.';es_CO = 'Por favor, seleccione un documento enviado.';tr = 'Lütfen, kaydedilmiş bir belge seçin.';it = 'Selezionare un documento pubblicato.';de = 'Bitte wählen Sie ein gebuchtes Dokument aus.'");
		EndIf;
	EndIf;

EndProcedure

Procedure CheckOnPosted(LoanContract, Cancel) Export
	
	If Common.ObjectAttributeValue(LoanContract, "Posted") = False Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Document %1 is not posted'; ru = 'Документ %1 не проведен';pl = 'Dokument %1 nie został zatwierdzony';es_ES = 'Documento %1 no está enviado';es_CO = 'Documento %1 no está enviado';tr = '%1 belgesi kaydedilmedi';it = 'Il documento %1 non è pubblicato';de = 'Dokument %1 ist nicht gebucht'"),
			LoanContract);
			
		CommonClientServer.MessageToUser(MessageText, , , , Cancel);
	
	EndIf;

EndProcedure

#Region InfobaseUpdate

Function FillEmptyCostAccountCommission() Export
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query = New Query;
	Query.Text = "SELECT
	|	LoanContract.Ref AS Ref,
	|	LoanContract.CostAccount AS CostAccount
	|FROM
	|	Document.LoanContract AS LoanContract
	|WHERE
	|	LoanContract.CostAccountCommission = &CostAccountCommission
	|	AND LoanContract.Posted";
	
	Query.SetParameter("CostAccountCommission", ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef());
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		Try
			LoanContractObject = Selection.Ref.GetObject();
			
			LoanContractObject.CostAccountCommission = Selection.CostAccount;
			
			InfobaseUpdate.WriteObject(LoanContractObject);
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save document ""%1"". Details: %2'; ru = 'Не удалось записать документ ""%1"". Подробнее: %2';pl = 'Nie można zapisać dokumentu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Dokuments ""%1"". Details: %2'", DefaultLanguageCode),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.Documents.LoanContract,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndFunction

#EndRegion

#EndRegion

// Function returns the list of key attribute names.
//
Function GetObjectAttributesBeingLocked() Export
	
	Result = New Array;
	Result.Add("SettlementsCurrency");
	
	Return Result;
	
EndFunction

// Initializes value tables containing data of the document tabular sections.
// Saves value tables to properties of the "AdditionalProperties" structure.
Procedure InitializeDocumentData(DocumentRefLoanContract, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	LoanContract.Ref AS LoanContract,
	|	LoanContract.PaymentMethod AS PaymentMethod,
	|	LoanContract.PrincipalItem AS PrincipalItem,
	|	LoanContract.PettyCash AS PettyCash,
	|	LoanContract.BankAccount AS BankAccount,
	|	LoanContract.Order AS Order,
	|	LoanContract.SettlementsCurrency AS SettlementsCurrency,
	|	LoanContract.Company AS Company,
	|	LoanContract.InterestItem AS InterestItem,
	|	LoanContract.LoanKind AS LoanKind,
	|	LoanContract.ChargeFromSalary AS ChargeFromSalary,
	|	LoanContract.Issued AS Issued,
	|	LoanContract.CashAssetType AS CashAssetType,
	|	LoanContract.CommissionItem AS CommissionItem
	|INTO Document
	|FROM
	|	Document.LoanContract AS LoanContract
	|WHERE
	|	LoanContract.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	LoanContractPaymentsAndAccrualsSchedule.Ref AS LoanContract,
	|	LoanContractPaymentsAndAccrualsSchedule.PaymentDate AS Period,
	|	LoanContractPaymentsAndAccrualsSchedule.Principal AS Principal,
	|	LoanContractPaymentsAndAccrualsSchedule.Interest AS Interest,
	|	LoanContractPaymentsAndAccrualsSchedule.Commission AS Commission,
	|	Document.CashAssetType AS CashAssetType,
	|	Document.PaymentMethod AS PaymentMethod
	|FROM
	|	Document AS Document
	|		INNER JOIN Document.LoanContract.PaymentsAndAccrualsSchedule AS LoanContractPaymentsAndAccrualsSchedule
	|		ON Document.LoanContract = LoanContractPaymentsAndAccrualsSchedule.Ref
	|		INNER JOIN Constant.UsePaymentCalendar AS UsePaymentCalendar
	|		ON (UsePaymentCalendar.Value)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	LoanContractPaymentsAndAccrualsSchedule.Ref AS Register,
	|	Document.Issued AS Period,
	|	SUM(CASE
	|			WHEN Document.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
	|				THEN LoanContractPaymentsAndAccrualsSchedule.Principal
	|			WHEN Document.LoanKind = VALUE(Enum.LoanContractTypes.EmployeeLoanAgreement)
	|					OR Document.LoanKind = VALUE(Enum.LoanContractTypes.CounterpartyLoanAgreement)
	|				THEN -LoanContractPaymentsAndAccrualsSchedule.Principal
	|		END) AS Amount,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	Document.PaymentMethod AS PaymentMethod,
	|	CASE
	|		WHEN Document.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
	|				OR Document.LoanKind = VALUE(Enum.LoanContractTypes.CounterpartyLoanAgreement)
	|			THEN Document.PrincipalItem
	|		WHEN Document.LoanKind = VALUE(Enum.LoanContractTypes.EmployeeLoanAgreement)
	|			THEN Document.InterestItem
	|	END AS Item,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	Document.SettlementsCurrency AS Currency,
	|	LoanContractPaymentsAndAccrualsSchedule.Ref AS Quote,
	|	CASE
	|		WHEN Document.CashAssetType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN Document.PettyCash
	|		WHEN Document.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN Document.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccountPettyCash
	|FROM
	|	Document AS Document
	|		INNER JOIN Document.LoanContract.PaymentsAndAccrualsSchedule AS LoanContractPaymentsAndAccrualsSchedule
	|		ON Document.LoanContract = LoanContractPaymentsAndAccrualsSchedule.Ref
	|		INNER JOIN Constant.UsePaymentCalendar AS UsePaymentCalendar
	|		ON (UsePaymentCalendar.Value)
	|			AND (NOT Document.ChargeFromSalary)
	|
	|GROUP BY
	|	Document.SettlementsCurrency,
	|	LoanContractPaymentsAndAccrualsSchedule.Ref,
	|	Document.PaymentMethod,
	|	Document.Issued,
	|	CASE
	|		WHEN Document.CashAssetType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN Document.PettyCash
	|		WHEN Document.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN Document.BankAccount
	|		ELSE UNDEFINED
	|	END,
	|	Document.SettlementsCurrency,
	|	CASE
	|		WHEN Document.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
	|				OR Document.LoanKind = VALUE(Enum.LoanContractTypes.CounterpartyLoanAgreement)
	|			THEN Document.PrincipalItem
	|		WHEN Document.LoanKind = VALUE(Enum.LoanContractTypes.EmployeeLoanAgreement)
	|			THEN Document.InterestItem
	|	END,
	|	LoanContractPaymentsAndAccrualsSchedule.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	LoanContractPaymentsAndAccrualsSchedule.Ref,
	|	LoanContractPaymentsAndAccrualsSchedule.PaymentDate,
	|	CASE
	|		WHEN Document.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
	|			THEN -LoanContractPaymentsAndAccrualsSchedule.PaymentAmount
	|		WHEN Document.LoanKind = VALUE(Enum.LoanContractTypes.EmployeeLoanAgreement)
	|			THEN LoanContractPaymentsAndAccrualsSchedule.PaymentAmount
	|	END,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved),
	|	Document.PaymentMethod,
	|	CASE
	|		WHEN Document.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
	|			THEN Document.InterestItem
	|		WHEN Document.LoanKind = VALUE(Enum.LoanContractTypes.EmployeeLoanAgreement)
	|				OR Document.LoanKind = VALUE(Enum.LoanContractTypes.CounterpartyLoanAgreement)
	|			THEN Document.PrincipalItem
	|	END,
	|	&Company,
	|	&PresentationCurrency,
	|	Document.SettlementsCurrency,
	|	LoanContractPaymentsAndAccrualsSchedule.Ref,
	|	CASE
	|		WHEN Document.CashAssetType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN Document.PettyCash
	|		WHEN Document.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN Document.BankAccount
	|		ELSE UNDEFINED
	|	END
	|FROM
	|	Document AS Document
	|		INNER JOIN Document.LoanContract.PaymentsAndAccrualsSchedule AS LoanContractPaymentsAndAccrualsSchedule
	|		ON Document.LoanContract = LoanContractPaymentsAndAccrualsSchedule.Ref
	|		INNER JOIN Constant.UsePaymentCalendar AS UsePaymentCalendar
	|		ON (UsePaymentCalendar.Value)
	|			AND (NOT Document.ChargeFromSalary)
	|WHERE
	|	NOT Document.LoanKind = VALUE(Enum.LoanContractTypes.CounterpartyLoanAgreement)
	|
	|UNION ALL
	|
	|SELECT
	|	LoanContractPaymentsAndAccrualsSchedule.Ref,
	|	LoanContractPaymentsAndAccrualsSchedule.PaymentDate,
	|	LoanContractPaymentsAndAccrualsSchedule.Principal,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved),
	|	Document.PaymentMethod,
	|	Document.PrincipalItem,
	|	&Company,
	|	&PresentationCurrency,
	|	Document.SettlementsCurrency,
	|	LoanContractPaymentsAndAccrualsSchedule.Ref,
	|	CASE
	|		WHEN Document.CashAssetType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN Document.PettyCash
	|		WHEN Document.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN Document.BankAccount
	|		ELSE UNDEFINED
	|	END
	|FROM
	|	Document AS Document
	|		INNER JOIN Document.LoanContract.PaymentsAndAccrualsSchedule AS LoanContractPaymentsAndAccrualsSchedule
	|		ON Document.LoanContract = LoanContractPaymentsAndAccrualsSchedule.Ref
	|		INNER JOIN Constant.UsePaymentCalendar AS UsePaymentCalendar
	|		ON (UsePaymentCalendar.Value)
	|			AND (NOT Document.ChargeFromSalary)
	|WHERE
	|	Document.LoanKind = VALUE(Enum.LoanContractTypes.CounterpartyLoanAgreement)
	|	AND LoanContractPaymentsAndAccrualsSchedule.Principal > 0
	|
	|UNION ALL
	|
	|SELECT
	|	LoanContractPaymentsAndAccrualsSchedule.Ref,
	|	LoanContractPaymentsAndAccrualsSchedule.PaymentDate,
	|	LoanContractPaymentsAndAccrualsSchedule.Interest,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved),
	|	Document.PaymentMethod,
	|	Document.InterestItem,
	|	&Company,
	|	&PresentationCurrency,
	|	Document.SettlementsCurrency,
	|	LoanContractPaymentsAndAccrualsSchedule.Ref,
	|	CASE
	|		WHEN Document.CashAssetType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN Document.PettyCash
	|		WHEN Document.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN Document.BankAccount
	|		ELSE UNDEFINED
	|	END
	|FROM
	|	Document AS Document
	|		INNER JOIN Document.LoanContract.PaymentsAndAccrualsSchedule AS LoanContractPaymentsAndAccrualsSchedule
	|		ON Document.LoanContract = LoanContractPaymentsAndAccrualsSchedule.Ref
	|		INNER JOIN Constant.UsePaymentCalendar AS UsePaymentCalendar
	|		ON (UsePaymentCalendar.Value)
	|			AND (NOT Document.ChargeFromSalary)
	|WHERE
	|	Document.LoanKind = VALUE(Enum.LoanContractTypes.CounterpartyLoanAgreement)
	|	AND LoanContractPaymentsAndAccrualsSchedule.Interest > 0
	|
	|UNION ALL
	|
	|SELECT
	|	LoanContractPaymentsAndAccrualsSchedule.Ref,
	|	LoanContractPaymentsAndAccrualsSchedule.PaymentDate,
	|	LoanContractPaymentsAndAccrualsSchedule.Commission,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved),
	|	Document.PaymentMethod,
	|	Document.CommissionItem,
	|	&Company,
	|	&PresentationCurrency,
	|	Document.SettlementsCurrency,
	|	LoanContractPaymentsAndAccrualsSchedule.Ref,
	|	CASE
	|		WHEN Document.CashAssetType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN Document.PettyCash
	|		WHEN Document.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN Document.BankAccount
	|		ELSE UNDEFINED
	|	END
	|FROM
	|	Document AS Document
	|		INNER JOIN Document.LoanContract.PaymentsAndAccrualsSchedule AS LoanContractPaymentsAndAccrualsSchedule
	|		ON Document.LoanContract = LoanContractPaymentsAndAccrualsSchedule.Ref
	|		INNER JOIN Constant.UsePaymentCalendar AS UsePaymentCalendar
	|		ON (UsePaymentCalendar.Value)
	|			AND (NOT Document.ChargeFromSalary)
	|WHERE
	|	Document.LoanKind = VALUE(Enum.LoanContractTypes.CounterpartyLoanAgreement)
	|	AND LoanContractPaymentsAndAccrualsSchedule.Commission > 0";
	
	Query.SetParameter("Ref", 					DocumentRefLoanContract);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",  StructureAdditionalProperties.ForPosting.PresentationCurrency);	
	
	ResultArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableLoanRepaymentSchedule", ResultArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", ResultArray[2].Unload());
	
EndProcedure

// Receives the counterparty contract by default considering filter conditions. Main contract, a single contract, or an
// empty reference is returned.
//
// The
//  Counterparty	parameters	- 
//							<CatalogRef.Counterparties> Counterparty whose
//  contract	to	be 
//							received Company - <CatalogRef.Companies> Company
//  whose	contract	to be received LoanKindList - <Array> or <ValueList> 
//							consisting of values of the <EnumRef.LoanKinds> type Necessary contract kinds
//
// Returns:
//   <CatalogRef.CounterpartyContracts> - found contract or null reference
//
Function ReceiveLoanContractByDefaultByCompanyLoanKind(Counterparty, Company, LoanKindList = Undefined) Export
	
	If Not ValueIsFilled(Counterparty) Then
		Return Undefined;
	EndIf;
	
	Query = New Query;
	QueryText = 
	"SELECT ALLOWED
	|	LoanContract.Ref
	|FROM
	|	Document.LoanContract AS LoanContract
	|WHERE
	|	LoanContract.Counterparty = &Counterparty
	|	AND LoanContract.Company = &Company
	|	AND LoanContract.Posted"
	+ ?(LoanKindList <> Undefined,"
	|	AND LoanContract.LoanKind IN (&LoanKindList)","");
	
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Company", Company);
	Query.SetParameter("LoanKindList", LoanKindList);
	
	If TypeOf(Counterparty) = Type("CatalogRef.Employees") Then
		QueryText = StrReplace(QueryText, 
			"LoanContract.Counterparty = &Counterparty", 
			"LoanContract.Employee = &Counterparty");
	EndIf;
	
	Query.Text = QueryText;
	Result = Query.Execute();
	
	Selection = Result.Select();
	If Selection.Count() = 1 
		AND Selection.Next() Then
			LoanContract = Selection.Ref;
	Else
		LoanContract = Undefined;
	EndIf;
	
	Return LoanContract;
	
EndFunction

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

// Defines object settings for the ObjectVersioning subsystem.
//
// Parameters:
//  Settings - Structure - subsystem settings.
Procedure WhenDefiningObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export
	
	Return New Structure();
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	
	If StructureData.TabName = "Header" Then
		If StructureData.LoanKind = Enums.LoanContractTypes.EmployeeLoanAgreement Then
			Result.Insert("CostAccount", "InterestIncomeItem");
		ElsIf StructureData.LoanKind = Enums.LoanContractTypes.CounterpartyLoanAgreement Then
			Result.Insert("CostAccount", "InterestIncomeItem");
			Result.Insert("CommissionGLAccount", "CommissionIncomeItem");
		ElsIf StructureData.LoanKind = Enums.LoanContractTypes.Borrowed Then
			Result.Insert("CostAccount", "InterestExpenseItem");
			Result.Insert("CommissionGLAccount", "CommissionExpenseItem"); 
		EndIf;
	EndIf;

	Return Result;
	
EndFunction

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

// Fills the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see field content in the PrintManagement.CreatePrintCommandCollection function.
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

#EndIf
